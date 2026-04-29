// OpenCode Remote - REST API 客户端
// 基于 OpenCode 源码会话和全局路由
// 创建时间：2026-04-29

import Foundation

/// OpenCode REST API 客户端，actor 隔离
actor OpenCodeAPIClient {
  private let session: URLSession
  private let decoder: JSONDecoder
  private let encoder: JSONEncoder

  private var baseURL: URL?
  private var authToken: String?
  private var credentials: (username: String, password: String)?
  private var directory: String?

  init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 60
    config.waitsForConnectivity = true
    self.session = URLSession(configuration: config)

    self.decoder = JSONDecoder()
    self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    self.decoder.dateDecodingStrategy = .iso8601

    self.encoder = JSONEncoder()
    self.encoder.keyEncodingStrategy = .convertToSnakeCase
    self.encoder.dateEncodingStrategy = .iso8601
  }

  /// 配置服务器连接信息（OpenCode token 模式）
  func configure(baseURL: URL, authToken: String, directory: String? = nil) {
    self.baseURL = baseURL
    self.authToken = authToken
    self.credentials = nil
    self.directory = directory
  }

  /// 兼容旧调用：用户名/密码模式
  func configure(baseURL: URL, username: String, password: String, directory: String? = nil) {
    self.baseURL = baseURL
    self.authToken = nil
    self.credentials = (username, password)
    self.directory = directory
  }

  /// 清除连接配置
  func clear() {
    baseURL = nil
    authToken = nil
    credentials = nil
    directory = nil
  }

  // MARK: - 通用请求构建

  private func makeRequest(
    _ path: String,
    method: String = "GET",
    queryItems: [URLQueryItem] = [],
    body: (any Encodable)? = nil
  ) throws -> URLRequest {
    guard let baseURL else {
      throw NetworkError.notConfigured
    }

    guard var components = URLComponents(url: appendingPathComponents(baseURL, path: path), resolvingAgainstBaseURL: false) else {
      throw NetworkError.invalidURL
    }

    var items = queryItems
    if let authToken {
      items.append(URLQueryItem(name: "auth_token", value: authToken))
    }
    if !items.isEmpty {
      components.queryItems = (components.queryItems ?? []) + items
    }

    guard let finalURL = components.url else {
      throw NetworkError.invalidURL
    }

    var request = URLRequest(url: finalURL)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    if let authToken {
      request.setValue(authToken, forHTTPHeaderField: "Authorization")
    } else if let credentials {
      let auth = Data("\(credentials.username):\(credentials.password)".utf8).base64EncodedString()
      request.setValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
    }

    if let directory {
      request.setValue(directory, forHTTPHeaderField: "x-opencode-directory")
    }

    if let body {
      request.httpBody = try encoder.encode(AnyEncodable(body))
    }
    return request
  }

  private func appendingPathComponents(_ baseURL: URL, path: String) -> URL {
    path.split(separator: "/", omittingEmptySubsequences: true).reduce(baseURL) { url, component in
      url.appendingPathComponent(String(component))
    }
  }

  // MARK: - 业务端点

  /// 健康检查 → { healthy: true, version: "..." }
  func healthCheck() async throws -> HealthResponse {
    let request = try makeRequest("global/health")
    let (data, response) = try await session.data(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decoder.decode(HealthResponse.self, from: data)
  }

  /// 获取会话列表
  func fetchSessions(limit: Int? = nil) async throws -> [SessionInfo] {
    var items: [URLQueryItem] = []
    if let limit { items.append(URLQueryItem(name: "limit", value: "\(limit)")) }

    let request = try makeRequest("session", queryItems: items)
    let (data, response) = try await session.data(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decoder.decode([SessionInfo].self, from: data)
  }

  /// 创建新会话
  func createSession(title: String?, cwd: String?) async throws -> SessionDetail {
    let body = CreateSessionRequest(title: title, cwd: cwd)
    let request = try makeRequest("session", method: "POST", body: body)
    let (data, response) = try await session.data(for: request)
    try HTTPValidator.validate(response, data: data, expectedStatus: 201)
    return try decoder.decode(SessionDetail.self, from: data)
  }

  /// 获取会话详情
  func fetchSession(_ id: String) async throws -> SessionDetail {
    let request = try makeRequest("session/\(id)")
    let (data, response) = try await session.data(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decoder.decode(SessionDetail.self, from: data)
  }

  /// 删除会话
  func deleteSession(_ id: String) async throws {
    let request = try makeRequest("session/\(id)", method: "DELETE")
    let (data, response) = try await session.data(for: request)
    try HTTPValidator.validate(response, data: data)
  }

  /// 获取会话状态映射
  func fetchSessionStatus() async throws -> [String: SessionStatusInfo] {
    let request = try makeRequest("session/status")
    let (data, response) = try await session.data(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decoder.decode([String: SessionStatusInfo].self, from: data)
  }

  /// 获取会话消息列表（支持分页）
  func fetchMessages(sessionId: String, limit: Int = 50, before: String? = nil) async throws -> (messages: [Message], nextCursor: String?) {
    var items = [URLQueryItem(name: "limit", value: "\(limit)")]
    if let before { items.append(URLQueryItem(name: "before", value: before)) }

    let request = try makeRequest("session/\(sessionId)/message", queryItems: items)
    let (data, response) = try await session.data(for: request)
    try HTTPValidator.validate(response, data: data)

    let messages = try decoder.decode([Message].self, from: data)
    let nextCursor = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Next-Cursor")
    return (messages, nextCursor)
  }

  /// 发送 Prompt（流式消息创建由服务端处理，响应为消息数据）
  func sendPrompt(sessionId: String, message: String, requestId: String) async throws -> Message {
    let body = PromptRequest(message: message, requestId: requestId, attachments: nil)
    let request = try makeRequest("session/\(sessionId)/message", method: "POST", body: body)
    let (data, response) = try await session.data(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decoder.decode(Message.self, from: data)
  }

  /// 异步发送 Prompt，服务端返回 204
  func sendPromptAsync(sessionId: String, message: String, requestId: String) async throws {
    let body = PromptRequest(message: message, requestId: requestId, attachments: nil)
    let request = try makeRequest("session/\(sessionId)/prompt_async", method: "POST", body: body)
    let (data, response) = try await session.data(for: request)
    try HTTPValidator.validate(response, data: data, expectedStatus: 204)
  }

  /// 中止运行中的任务
  func abort(sessionId: String) async throws -> Bool {
    let request = try makeRequest("session/\(sessionId)/abort", method: "POST")
    let (data, response) = try await session.data(for: request)
    try HTTPValidator.validate(response, data: data)
    let result = try decoder.decode([String: Bool].self, from: data)
    return result["aborted"] ?? false
  }

  /// 响应权限请求（旧会话权限路由，兼容保留）
  func respondToPermission(sessionId: String, permissionId: String, action: PermissionAction, reason: String? = nil) async throws -> PermissionResult {
    let body = PermissionResponse(action: action, reason: reason)
    let request = try makeRequest("session/\(sessionId)/permissions/\(permissionId)", method: "POST", body: body)
    let (data, response) = try await session.data(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decoder.decode(PermissionResult.self, from: data)
  }

  /// 获取独立权限请求列表
  func fetchPermissions() async throws -> [PermissionRequest] {
    let request = try makeRequest("permission")
    let (data, response) = try await session.data(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decoder.decode([PermissionRequest].self, from: data)
  }

  /// 回复独立权限请求
  func replyPermission(requestID: String, body: PermissionReplyBody) async throws {
    let request = try makeRequest("permission/\(requestID)/reply", method: "POST", body: body)
    let (data, response) = try await session.data(for: request)
    try HTTPValidator.validate(response, data: data)
  }
}

// MARK: - 临时类型（不依赖外部模块）

struct HealthResponse: Codable, Sendable {
  let healthy: Bool
  let version: String
}

struct SessionStatusInfo: Codable, Sendable {
  let status: String
}

struct PromptRequest: Codable, Sendable {
  let message: String
  let requestId: String
  let attachments: [String]?
}

struct PermissionResponse: Codable, Sendable {
  let action: PermissionAction
  let reason: String?
}

private struct AnyEncodable: Encodable {
  private let encodeImpl: (Encoder) throws -> Void

  init(_ value: any Encodable) {
    self.encodeImpl = { encoder in
      try value.encode(to: encoder)
    }
  }

  func encode(to encoder: Encoder) throws {
    try encodeImpl(encoder)
  }
}
