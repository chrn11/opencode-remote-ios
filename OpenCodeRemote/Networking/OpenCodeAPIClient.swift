// OpenCode Remote - REST API 客户端
// 基于 OpenCode 源码会话和全局路由
// 创建时间：2026-04-29

import Foundation

/// OpenCode REST API 客户端，actor 隔离
actor OpenCodeAPIClient {
  static let requestTimeout: TimeInterval = 30

  private let session: URLSession
  private let decoder: JSONDecoder
  private let encoder: JSONEncoder

  private var baseURL: URL?
  private var authToken: String?
  private var credentials: (username: String, password: String)?
  private var directory: String?

  init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = Self.requestTimeout
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
    if let authToken, !authToken.isEmpty {
      items.append(URLQueryItem(name: "auth_token", value: authToken))
    }
    if !items.isEmpty {
      let existing = components.queryItems ?? []
      components.queryItems = existing + items
    }

    guard let finalURL = components.url else {
      throw NetworkError.invalidURL
    }

    var request = URLRequest(url: finalURL)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")

    if let authToken, !authToken.isEmpty {
      request.setValue(authToken, forHTTPHeaderField: "Authorization")
    } else if let credentials {
      let auth = Data("\(credentials.username):\(credentials.password)".utf8).base64EncodedString()
      request.setValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
    }

    if let directory, !directory.isEmpty {
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

  private func performData(for request: URLRequest) async throws -> (Data, URLResponse) {
    do {
      return try await session.data(for: request)
    } catch {
      throw mapNetworkError(error)
    }
  }

  private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    do {
      return try decoder.decode(T.self, from: data)
    } catch {
      throw NetworkError.decodeFailed(error)
    }
  }

  private func mapNetworkError(_ error: Error) -> NetworkError {
    if let networkError = error as? NetworkError {
      return networkError
    }

    if let urlError = error as? URLError {
      switch urlError.code {
      case .timedOut:
        return .timeout
      case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .networkConnectionLost,
           .notConnectedToInternet, .callIsActive, .dataNotAllowed, .internationalRoamingOff:
        return .connectionFailed(urlError)
      default:
        return .connectionFailed(urlError)
      }
    }

    return .connectionFailed(error)
  }

  // MARK: - 业务端点

  /// 健康检查 → { healthy: true, version: "..." }
  func healthCheck() async throws -> HealthResponse {
    let request = try makeRequest("global/health")
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decodeResponse(HealthResponse.self, from: data)
  }

  /// 获取会话列表
  func fetchSessions(limit: Int? = nil) async throws -> [SessionInfo] {
    var items: [URLQueryItem] = []
    if let limit { items.append(URLQueryItem(name: "limit", value: "\(limit)")) }

    let request = try makeRequest("session", queryItems: items)
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decodeResponse([SessionInfo].self, from: data)
  }

  /// 创建新会话
  func createSession(title: String?) async throws -> SessionDetail {
    let body = SessionCreateInput(parentID: nil, title: title, permission: nil, workspaceID: nil)
    let request = try makeRequest("session", method: "POST", body: body)
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data, expectedStatus: 200)
    return try decodeResponse(SessionDetail.self, from: data)
  }

  /// 获取会话详情
  func fetchSession(_ id: String) async throws -> SessionDetail {
    let request = try makeRequest("session/\(id)")
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decodeResponse(SessionDetail.self, from: data)
  }

  /// 删除会话
  func deleteSession(_ id: String) async throws {
    let request = try makeRequest("session/\(id)", method: "DELETE")
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)
  }

  /// 获取会话状态映射
  func fetchSessionStatus() async throws -> [String: SessionStatusInfo] {
    let request = try makeRequest("session/status")
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decodeResponse([String: SessionStatusInfo].self, from: data)
  }

  /// 获取会话消息列表（支持分页）
  func fetchMessages(sessionId: String, limit: Int = 50, before: String? = nil) async throws -> (messages: [Message], nextCursor: String?) {
    var items = [URLQueryItem(name: "limit", value: "\(limit)")]
    if let before { items.append(URLQueryItem(name: "before", value: before)) }

    let request = try makeRequest("session/\(sessionId)/message", queryItems: items)
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)

    let messages = try decodeResponse([Message].self, from: data)
    let nextCursor = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "X-Next-Cursor")
    return (messages, nextCursor)
  }

  /// 发送 Prompt（流式消息创建由服务端处理，响应为消息数据）
  func sendPrompt(sessionId: String, message: String, requestId: String) async throws -> Message {
    let body = PromptRequest(message: message, requestId: requestId, attachments: nil)
    let request = try makeRequest("session/\(sessionId)/message", method: "POST", body: body)
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decodeResponse(Message.self, from: data)
  }

  /// 异步发送 Prompt，服务端返回 204
  /// 对齐 OpenCode PromptPayload schema：model 为对象 { providerID, modelID }
  func sendPromptAsync(
    sessionId: String, text: String,
    reasoningEffort: String? = nil,
    agent: String? = nil,
    model: String? = nil,
    variant: String? = nil
  ) async throws {
    let parts: [[String: String]] = [["type": "text", "text": text]]
    var body: [String: CodableValue] = [
      "parts": CodableValue.array(parts.map { CodableValue.object($0.mapValues { CodableValue.string($0) }) })
    ]
    if let reasoningEffort {
      body["reasoning_effort"] = CodableValue.string(reasoningEffort)
    }
    if let agent, !agent.isEmpty {
      body["agent"] = CodableValue.string(agent)
    }
    // model: 如果格式为 "providerID/modelID"，拆分为对象
    if let model, !model.isEmpty {
      let comps = model.split(separator: "/", maxSplits: 1).map(String.init)
      if comps.count == 2 {
        body["model"] = CodableValue.object([
          "providerID": CodableValue.string(comps[0]),
          "modelID": CodableValue.string(comps[1])
        ])
      }
    }
    if let variant, !variant.isEmpty {
      body["variant"] = CodableValue.string(variant)
    }
    let request = try makeRequest("session/\(sessionId)/prompt_async", method: "POST", body: CodableValue.object(body))
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data, expectedStatus: 204)
  }

  /// 中止运行中的任务
  func abort(sessionId: String) async throws -> Bool {
    let request = try makeRequest("session/\(sessionId)/abort", method: "POST")
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)
    let result = try decodeResponse([String: Bool].self, from: data)
    return result["aborted"] ?? false
  }

  /// 响应权限请求（旧会话权限路由，兼容保留）
  func respondToPermission(sessionId: String, permissionId: String, action: PermissionAction, reason: String? = nil) async throws -> PermissionResult {
    let body = PermissionResponse(action: action, reason: reason)
    let request = try makeRequest("session/\(sessionId)/permissions/\(permissionId)", method: "POST", body: body)
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decodeResponse(PermissionResult.self, from: data)
  }

  /// 获取独立权限请求列表
  func fetchPermissions() async throws -> [PermissionRequest] {
    let request = try makeRequest("permission")
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decodeResponse([PermissionRequest].self, from: data)
  }

  /// 回复独立权限请求
  func replyPermission(requestID: String, body: PermissionReplyBody) async throws {
    let request = try makeRequest("permission/\(requestID)/reply", method: "POST", body: body)
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)
  }

  // MARK: - 获取 Agent 列表

  /// 获取可用 Agent 列表（GET /agent）
  func fetchAgents() async throws -> [AgentInfo] {
    let request = try makeRequest("agent")
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decodeResponse([AgentInfo].self, from: data)
  }

  // MARK: - 获取可用模型列表

  /// 获取已连接的 Provider 列表及其模型
  func fetchProviders() async throws -> ProviderListResponse {
    let request = try makeRequest("provider")
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decodeResponse(ProviderListResponse.self, from: data)
  }

  /// 获取全局配置（含默认模型、agent 等）
  func fetchGlobalConfig() async throws -> GlobalConfig {
    let request = try makeRequest("global/config")
    let (data, response) = try await performData(for: request)
    try HTTPValidator.validate(response, data: data)
    return try decodeResponse(GlobalConfig.self, from: data)
  }
}

// MARK: - 临时类型（不依赖外部模块）

struct HealthResponse: Codable, Sendable {
  let healthy: Bool
  let version: String
}

struct SessionStatusInfo: Codable, Sendable {
  let status: String
  let message: String?

  init(status: String, message: String? = nil) {
    self.status = status
    self.message = message
  }

  var normalizedStatus: String {
    switch status {
    case "idle", "running", "thinking", "error", "retry":
      return status
    default:
      return "idle"
    }
  }
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

// MARK: - 全局配置

struct GlobalConfig: Codable, Sendable {
  let model: String?
  let smallModel: String?
  let defaultAgent: String?
  let agent: [String: CodableValue]?
  let provider: [String: CodableValue]?
  let plugin: CodableValue?
  let mcp: [String: CodableValue]?
  let `default`: [String: String]?
  let connected: [String]?
}

// MARK: - Provider 信息

struct ProviderListResponse: Codable, Sendable {
  let all: [ProviderInfo]
  let defaultModels: [String: String]
  let connected: [String]

  private enum CodingKeys: String, CodingKey {
    case all
    case defaultModels = "default"
    case connected
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    all = try container.decodeIfPresent([ProviderInfo].self, forKey: .all) ?? []
    connected = try container.decodeIfPresent([String].self, forKey: .connected) ?? []

    if let mapping = try? container.decode([String: String].self, forKey: .defaultModels) {
      defaultModels = mapping
    } else if let modelIDs = try? container.decode([String].self, forKey: .defaultModels) {
      defaultModels = Dictionary(uniqueKeysWithValues: modelIDs.map { ($0, $0) })
    } else {
      defaultModels = [:]
    }
  }
}

struct ProviderInfo: Codable, Identifiable, Sendable {
  let id: String
  let name: String
  let source: String?
  let env: [String]
  let api: String?
  let npm: String?
  let key: String?
  let options: [String: CodableValue]?
  let models: [String: ModelInfo]

  var sortedModels: [(id: String, info: ModelInfo)] {
    models
      .map { ($0.key, $0.value) }
      .sorted { lhs, rhs in
        lhs.info.displayName.localizedCaseInsensitiveCompare(rhs.info.displayName) == .orderedAscending
      }
  }
}

struct ModelInfo: Codable, Sendable {
  let id: String?
  let name: String?
  let family: String?
  let releaseDate: String?
  let attachment: Bool?
  let reasoning: Bool?
  let temperature: Bool?
  let toolCall: Bool?
  let interleaved: CodableValue?
  let cost: ModelCost?
  let limit: ModelLimit?
  let modalities: ModelModalities?
  let experimental: Bool?
  let status: String?
  let provider: ModelProviderMeta?
  let options: [String: CodableValue]?
  let headers: [String: String]?
  let variants: [String: [String: CodableValue]]?

  var displayName: String { name ?? id ?? "未命名模型" }
  var supportsReasoning: Bool { reasoning == true }
  var supportsAttachments: Bool { attachment == true }
  var contextWindow: Int? { limit?.context }
  var defaultMaxTokens: Int? { limit?.output }
  var costPer1MIn: Double? { cost?.input }
  var costPer1MOut: Double? { cost?.output }
}

struct ModelCost: Codable, Sendable {
  let input: Double?
  let output: Double?
  let cacheRead: Double?
  let cacheWrite: Double?
}

struct ModelLimit: Codable, Sendable {
  let context: Int?
  let input: Int?
  let output: Int?
}

struct ModelModalities: Codable, Sendable {
  let input: [String]?
  let output: [String]?
}

struct ModelProviderMeta: Codable, Sendable {
  let npm: String?
  let api: String?
}

// MARK: - Agent 信息

/// Agent 信息（对齐 OpenCode Agent.Info schema）
struct AgentInfo: Codable, Identifiable, Sendable {
  let name: String
  let description: String?
  let mode: String?        // "primary" | "subagent" | "all"
  let native: Bool?
  let hidden: Bool?
  let topP: Double?
  let temperature: Double?
  let color: String?
  let model: AgentModelRef?
  let variant: String?
  let prompt: String?
  let steps: Int?

  var id: String { name }

  /// 是否应在底部栏显示（排除 hidden 和纯 subagent）
  var visibleInBar: Bool {
    hidden != true && mode != "subagent"
  }
}

struct AgentModelRef: Codable, Sendable {
  let providerID: String
  let modelID: String
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
