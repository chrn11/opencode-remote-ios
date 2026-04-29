// OpenCode Remote - 动态 JSON 值
// 创建时间：2026-04-29

import Foundation

/// 任意 Codable JSON 值
enum CodableValue: Codable, Sendable {
  case string(String)
  case int(Int)
  case double(Double)
  case bool(Bool)
  case object([String: CodableValue])
  case array([CodableValue])
  case null

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
      return
    }

    if let value = try? container.decode(String.self) {
      self = .string(value)
      return
    }
    if let value = try? container.decode(Int.self) {
      self = .int(value)
      return
    }
    if let value = try? container.decode(Double.self) {
      self = .double(value)
      return
    }
    if let value = try? container.decode(Bool.self) {
      self = .bool(value)
      return
    }
    if let value = try? container.decode([String: CodableValue].self) {
      self = .object(value)
      return
    }
    if let value = try? container.decode([CodableValue].self) {
      self = .array(value)
      return
    }

    self = .null
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value): try container.encode(value)
    case .int(let value): try container.encode(value)
    case .double(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    case .object(let value): try container.encode(value)
    case .array(let value): try container.encode(value)
    case .null: try container.encodeNil()
    }
  }

  var stringValue: String? {
    if case .string(let value) = self { return value }
    return nil
  }

  var intValue: Int? {
    if case .int(let value) = self { return value }
    return nil
  }

  var boolValue: Bool? {
    if case .bool(let value) = self { return value }
    return nil
  }

  var arrayValue: [CodableValue]? {
    if case .array(let value) = self { return value }
    return nil
  }

  var objectValue: [String: CodableValue]? {
    if case .object(let value) = self { return value }
    return nil
  }
}
