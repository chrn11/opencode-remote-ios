// OpenCode Remote - 消息模型
// 基于 OpenCode 源码 packages/opencode/src/session/message-v2.ts
// 创建时间：2026-04-29

import Foundation

/// 消息角色
enum MessageRole: String, Codable, Sendable {
  case user
  case assistant
}

/// 用户消息
struct UserMessageInfo: Codable, Sendable {
  let id: MessageID
  let sessionID: SessionID
  let role: MessageRole
  let time: MessageCreatedTime
  let format: OutputFormat?
  let summary: UserMessageSummary?
  let agent: String
  let model: UserModelInfo
  let system: String?
  let tools: [String: Bool]?
  let variant: String?
}

/// 助手消息
struct AssistantMessageInfo: Codable, Sendable {
  let id: MessageID
  let sessionID: SessionID
  let role: MessageRole
  let time: MessageTimeRange
  let error: AssistantError?
  let parentID: MessageID
  let modelID: ModelID
  let providerID: ProviderID
  let mode: String
  let agent: String
  let path: MessagePath
  let summary: Bool?
  let cost: Double
  let tokens: MessageTokens
  let structured: CodableValue?
  let variant: String?
  let finish: String?
}

/// 消息信息联合类型
enum MessageInfo: Codable, Sendable {
  case user(UserMessageInfo)
  case assistant(AssistantMessageInfo)

  private enum CodingKeys: String, CodingKey {
    case role
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let role = try container.decode(String.self, forKey: .role)
    switch role {
    case "user":
      self = .user(try UserMessageInfo(from: decoder))
    case "assistant":
      self = .assistant(try AssistantMessageInfo(from: decoder))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .role,
        in: container,
        debugDescription: "未知消息角色：\(role)",
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    switch self {
    case .user(let info):
      try info.encode(to: encoder)
    case .assistant(let info):
      try info.encode(to: encoder)
    }
  }

  var id: MessageID {
    switch self {
    case .user(let info): return info.id
    case .assistant(let info): return info.id
    }
  }

  var sessionID: SessionID {
    switch self {
    case .user(let info): return info.sessionID
    case .assistant(let info): return info.sessionID
    }
  }
}

/// 完整消息（info + parts）
struct MessageWithParts: Codable, Identifiable, Sendable {
  var id: MessageID { info.id }

  let info: MessageInfo
  var parts: [Part]

  private enum CodingKeys: String, CodingKey {
    case info
    case parts
  }

  init(info: MessageInfo, parts: [Part]) {
    self.info = info
    self.parts = parts
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.info = try container.decode(MessageInfo.self, forKey: .info)
    self.parts = try container.decode([Part].self, forKey: .parts)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(info, forKey: .info)
    try container.encode(parts, forKey: .parts)
  }
}

/// 兼容旧代码：Message 即完整消息
typealias Message = MessageWithParts

extension MessageWithParts {
  var role: MessageRole {
    switch info {
    case .user(let value): return value.role
    case .assistant(let value): return value.role
    }
  }
}

extension MessageInfo {
  var role: MessageRole {
    switch self {
    case .user(let value): return value.role
    case .assistant(let value): return value.role
    }
  }
}
