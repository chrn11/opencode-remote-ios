// OpenCode Remote - 消息子类型
// 基于 OpenCode 源码 packages/opencode/src/session/message-v2.ts
// 创建时间：2026-04-29

import Foundation

/// 用户消息时间
struct MessageCreatedTime: Codable, Sendable {
  let created: TimeInterval
}

/// 助手消息时间
struct MessageTimeRange: Codable, Sendable {
  let created: TimeInterval
  let completed: TimeInterval?
}

/// 输出格式
enum OutputFormat: Codable, Sendable {
  case text
  case jsonSchema(schema: [String: CodableValue], retryCount: Int)

  private enum CodingKeys: String, CodingKey {
    case type
    case schema
    case retryCount
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "text":
      self = .text
    case "json_schema":
      let schema = try container.decode([String: CodableValue].self, forKey: .schema)
      let retryCount = (try? container.decode(Int.self, forKey: .retryCount)) ?? 2
      self = .jsonSchema(schema: schema, retryCount: retryCount)
    default:
      self = .text
    }
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .text:
      try container.encode("text", forKey: .type)
    case .jsonSchema(let schema, let retryCount):
      try container.encode("json_schema", forKey: .type)
      try container.encode(schema, forKey: .schema)
      try container.encode(retryCount, forKey: .retryCount)
    }
  }
}

/// 用户模型信息
struct UserModelInfo: Codable, Sendable {
  let providerID: ProviderID
  let modelID: ModelID
}

/// 用户消息摘要
struct UserMessageSummary: Codable, Sendable {
  let title: String?
  let body: String?
  let diffs: [FileDiff]
}

/// 消息路径信息
struct MessagePath: Codable, Sendable {
  let cwd: String
  let root: String
}

/// 缓存 token
struct MessageCacheTokens: Codable, Sendable {
  let read: Int
  let write: Int
}

/// Token 统计
struct MessageTokens: Codable, Sendable {
  let total: Int?
  let input: Int
  let output: Int
  let reasoning: Int
  let cache: MessageCacheTokens
}
