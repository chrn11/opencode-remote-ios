// OpenCode Remote - 错误模型
// 基于 OpenCode 源码 packages/opencode/src/session/message-v2.ts
// 创建时间：2026-04-29

import Foundation

/// 认证错误
struct AuthErrorInfo: Codable, Sendable {
  let name: String
  let providerID: String
  let message: String
}

/// 输出长度超限错误
struct OutputLengthErrorInfo: Codable, Sendable {
  let name: String
}

/// 终止错误
struct AbortedErrorInfo: Codable, Sendable {
  let name: String
  let message: String
}

/// 结构化输出错误
struct StructuredOutputErrorInfo: Codable, Sendable {
  let name: String
  let message: String
  let retries: Int
}

/// 上下文溢出错误
struct ContextOverflowErrorInfo: Codable, Sendable {
  let name: String
  let message: String
  let responseBody: String?
}

/// API 错误
struct APIErrorInfo: Codable, Sendable {
  let name: String
  let message: String
  let statusCode: Int?
  let isRetryable: Bool
  let responseHeaders: [String: String]?
  let responseBody: String?
  let metadata: [String: String]?
}

/// 未知错误
struct UnknownErrorInfo: Codable, Sendable {
  let name: String
  let message: String
}

/// 助手消息错误联合类型
enum AssistantError: Codable, Sendable {
  case auth(AuthErrorInfo)
  case outputLength(OutputLengthErrorInfo)
  case aborted(AbortedErrorInfo)
  case structuredOutput(StructuredOutputErrorInfo)
  case contextOverflow(ContextOverflowErrorInfo)
  case api(APIErrorInfo)
  case unknown(UnknownErrorInfo)

  private enum CodingKeys: String, CodingKey {
    case name
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let name = try container.decode(String.self, forKey: .name)
    switch name {
    case "ProviderAuthError": self = .auth(try AuthErrorInfo(from: decoder))
    case "MessageOutputLengthError": self = .outputLength(try OutputLengthErrorInfo(from: decoder))
    case "MessageAbortedError": self = .aborted(try AbortedErrorInfo(from: decoder))
    case "StructuredOutputError": self = .structuredOutput(try StructuredOutputErrorInfo(from: decoder))
    case "ContextOverflowError": self = .contextOverflow(try ContextOverflowErrorInfo(from: decoder))
    case "APIError": self = .api(try APIErrorInfo(from: decoder))
    default:
      let message = (try? decoder.singleValueContainer().decode(String.self)) ?? name
      self = .unknown(UnknownErrorInfo(name: name, message: message))
    }
  }

  func encode(to encoder: Encoder) throws {
    switch self {
    case .auth(let value): try value.encode(to: encoder)
    case .outputLength(let value): try value.encode(to: encoder)
    case .aborted(let value): try value.encode(to: encoder)
    case .structuredOutput(let value): try value.encode(to: encoder)
    case .contextOverflow(let value): try value.encode(to: encoder)
    case .api(let value): try value.encode(to: encoder)
    case .unknown(let value): try value.encode(to: encoder)
    }
  }

  /// 中文显示文本
  var displayMessage: String {
    switch self {
    case .auth(let value): return "认证失败：\(value.message)"
    case .outputLength: return "输出长度超限"
    case .aborted(let value): return "任务已中止：\(value.message)"
    case .structuredOutput(let value): return "结构化输出失败：\(value.message)"
    case .contextOverflow(let value): return "上下文溢出：\(value.message)"
    case .api(let value): return "API 错误：\(value.message)"
    case .unknown(let value): return "未知错误：\(value.message)"
    }
  }
}
