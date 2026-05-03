// OpenCode Remote - SSE 事件流客户端
// 基于 OpenCode 源码 /event SSE endpoint
// 创建时间：2026-04-29

import Foundation

/// SSE 事件流客户端，管理连接、重连和事件回调
actor EventStreamClient {
  private var task: Task<Void, Never>?
  private var baseURL: URL?
  private var authToken: String?
  private var credentials: (username: String, password: String)?
  private var directory: String?
  private var sessionId: String?

  private var retryCount = 0
  private let maxRetryDelay: TimeInterval = 60
  private let baseRetryDelay: TimeInterval = 1

  /// 事件回调，由 SessionStore 注册
  nonisolated(unsafe) private var onEvent: ((SSEEvent) -> Void)?

  /// 是否正在运行
  private var isRunning = false

  /// 配置 SSE 连接参数（token 模式）
  func configure(
    baseURL: URL,
    authToken: String,
    directory: String? = nil,
    onEvent: @escaping (SSEEvent) -> Void
  ) {
    self.baseURL = baseURL
    self.authToken = authToken
    self.credentials = nil
    self.directory = directory
    self.sessionId = nil
    self.onEvent = onEvent
  }

  /// 兼容旧调用：用户名/密码模式
  func configure(
    baseURL: URL,
    username: String,
    password: String,
    sessionId: String? = nil,
    onEvent: @escaping (SSEEvent) -> Void
  ) {
    self.baseURL = baseURL
    self.authToken = nil
    self.credentials = (username, password)
    self.directory = nil
    self.sessionId = sessionId
    self.onEvent = onEvent
  }

  /// 开始连接
  func connect() {
    task?.cancel()
    retryCount = 0
    isRunning = true
    task = Task { await runEventLoop() }
  }

  /// 断开连接
  func disconnect() {
    task?.cancel()
    task = nil
    isRunning = false
  }

  // MARK: - 事件循环

  private func runEventLoop() async {
    guard let baseURL else {
      DebugLogger.shared.error("sse_not_configured")
      return
    }

    while !Task.isCancelled {
      do {
        let requestURL = appendingPathComponents(baseURL, path: "event")
        var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false)
        var items: [URLQueryItem] = []
        if let authToken {
          items.append(URLQueryItem(name: "auth_token", value: authToken))
        }
        if let sessionId {
          items.append(URLQueryItem(name: "session_id", value: sessionId))
        }
        if !items.isEmpty {
          let existing = components?.queryItems ?? []
          components?.queryItems = existing + items
        }
        guard let finalURL = components?.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: finalURL)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.timeoutInterval = .infinity

        if let authToken, !authToken.isEmpty {
          request.setValue(authToken, forHTTPHeaderField: "Authorization")
        } else if let credentials {
          let auth = Data("\(credentials.username):\(credentials.password)".utf8).base64EncodedString()
          request.setValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        }
        if let directory {
          request.setValue(directory, forHTTPHeaderField: "x-opencode-directory")
        }

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
          throw NetworkError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        retryCount = 0
        isRunning = true
        DebugLogger.shared.info("sse_connected")

        // 逐行解析：每行是 `data: {"type":"...","properties":{...}}`
        for try await line in bytes.lines {
          if Task.isCancelled { break }
          if line.isEmpty { continue }
          if let event = await SSEEventParser.shared.parse(dataLine: line) {
            onEvent?(event)
          }
        }
      } catch {
        if Task.isCancelled { break }

        isRunning = false
        let delay = min(baseRetryDelay * pow(2.0, Double(retryCount)), maxRetryDelay)
        retryCount += 1
        DebugLogger.shared.warn("sse_retry", ["尝试": "\(retryCount)", "延迟": "\(delay.rounded())s", "错误": error.localizedDescription])
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
    }
    isRunning = false
    DebugLogger.shared.info("sse_disconnected")
  }

  private func appendingPathComponents(_ baseURL: URL, path: String) -> URL {
    path.split(separator: "/", omittingEmptySubsequences: true).reduce(baseURL) { url, component in
      url.appendingPathComponent(String(component))
    }
  }
}
