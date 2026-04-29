// OpenCode Remote - Part 模型
// 基于 OpenCode 源码 packages/opencode/src/session/message-v2.ts
// 创建时间：2026-04-29

import Foundation

/// Part 基础字段
protocol PartBase: Identifiable, Codable, Sendable {
  var id: PartID { get }
  var sessionID: SessionID { get }
  var messageID: MessageID { get }
}

/// 文本片段时间
struct PartTimeRange: Codable, Sendable {
  let start: TimeInterval
  let end: TimeInterval?
}

/// 文件/符号/资源来源中的文本片段
struct FilePartSourceText: Codable, Sendable {
  let value: String
  let start: Int
  let end: Int
}

/// LSP 位置
struct SourcePosition: Codable, Sendable {
  let line: Int
  let character: Int
}

/// LSP 范围
struct SourceRange: Codable, Sendable {
  let start: SourcePosition
  let end: SourcePosition
}

// MARK: - 1. Text Part

struct TextPart: PartBase {
  let id: PartID
  let sessionID: SessionID
  let messageID: MessageID
  let type: String
  let text: String
  let synthetic: Bool?
  let ignored: Bool?
  let time: PartTimeRange?
  let metadata: [String: CodableValue]?

  var content: String { text }
}

// MARK: - 2. Reasoning Part

struct ReasoningPart: PartBase {
  let id: PartID
  let sessionID: SessionID
  let messageID: MessageID
  let type: String
  let text: String
  let metadata: [String: CodableValue]?
  let time: PartTimeRange

  var content: String { text }
}

// MARK: - 3. File Part

struct FileSource: Codable, Sendable {
  let type: String
  let path: String
  let text: FilePartSourceText
}

struct SymbolSource: Codable, Sendable {
  let type: String
  let path: String
  let text: FilePartSourceText
  let range: SourceRange
  let name: String
  let kind: Int
}

struct ResourceSource: Codable, Sendable {
  let type: String
  let clientName: String
  let uri: String
  let text: FilePartSourceText
}

enum FilePartSource: Codable, Sendable {
  case file(FileSource)
  case symbol(SymbolSource)
  case resource(ResourceSource)

  private enum CodingKeys: String, CodingKey {
    case type
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "file":
      self = .file(try FileSource(from: decoder))
    case "symbol":
      self = .symbol(try SymbolSource(from: decoder))
    case "resource":
      self = .resource(try ResourceSource(from: decoder))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .type,
        in: container,
        debugDescription: "未知文件来源类型：\(type)",
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    switch self {
    case .file(let source): try source.encode(to: encoder)
    case .symbol(let source): try source.encode(to: encoder)
    case .resource(let source): try source.encode(to: encoder)
    }
  }
}

struct FilePart: PartBase {
  let id: PartID
  let sessionID: SessionID
  let messageID: MessageID
  let type: String
  let mime: String
  let filename: String?
  let url: String
  let source: FilePartSource?
}

// MARK: - 4. Tool Part

struct ToolStatePending: Codable, Sendable {
  let status: String
  let input: [String: CodableValue]
  let raw: String
}

struct ToolStateRunning: Codable, Sendable {
  let status: String
  let input: [String: CodableValue]
  let title: String?
  let metadata: [String: CodableValue]?
  let time: ToolRunningTime
}

struct ToolRunningTime: Codable, Sendable {
  let start: TimeInterval
}

struct ToolStateCompleted: Codable, Sendable {
  let status: String
  let input: [String: CodableValue]
  let output: String
  let title: String
  let metadata: [String: CodableValue]
  let time: ToolCompletedTime
  let attachments: [FilePart]?
}

struct ToolCompletedTime: Codable, Sendable {
  let start: TimeInterval
  let end: TimeInterval
  let compacted: TimeInterval?
}

struct ToolStateError: Codable, Sendable {
  let status: String
  let input: [String: CodableValue]
  let error: String
  let metadata: [String: CodableValue]?
  let time: ToolEndTime
}

struct ToolEndTime: Codable, Sendable {
  let start: TimeInterval
  let end: TimeInterval
}

enum ToolState: Codable, Sendable {
  case pending(ToolStatePending)
  case running(ToolStateRunning)
  case completed(ToolStateCompleted)
  case error(ToolStateError)

  private enum CodingKeys: String, CodingKey {
    case status
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let status = try container.decode(String.self, forKey: .status)
    switch status {
    case "pending": self = .pending(try ToolStatePending(from: decoder))
    case "running": self = .running(try ToolStateRunning(from: decoder))
    case "completed": self = .completed(try ToolStateCompleted(from: decoder))
    case "error": self = .error(try ToolStateError(from: decoder))
    default:
      throw DecodingError.dataCorruptedError(
        forKey: .status,
        in: container,
        debugDescription: "未知工具状态：\(status)",
      )
    }
  }

  func encode(to encoder: Encoder) throws {
    switch self {
    case .pending(let state): try state.encode(to: encoder)
    case .running(let state): try state.encode(to: encoder)
    case .completed(let state): try state.encode(to: encoder)
    case .error(let state): try state.encode(to: encoder)
    }
  }
}

struct ToolPart: PartBase {
  let id: PartID
  let sessionID: SessionID
  let messageID: MessageID
  let type: String
  let callID: String
  let tool: String
  let state: ToolState
  let metadata: [String: CodableValue]?
}

/// 兼容旧代码：工具调用/结果类型
typealias ToolCallPart = ToolPart
typealias ToolResultPart = ToolPart

/// 兼容旧代码：工具状态
enum ToolStatus: String, Codable, Sendable {
  case pending
  case running
  case completed
  case error
}

/// 兼容旧代码：工具输入
struct ToolInput: Sendable {
  let command: String?
  let filePath: String?
}

extension ToolPart {
  var status: ToolStatus {
    switch state {
    case .pending: return .pending
    case .running: return .running
    case .completed: return .completed
    case .error: return .error
    }
  }

  var input: ToolInput? {
    let command = metadata?["command"]?.stringValue
    let filePath = metadata?["filePath"]?.stringValue
    if command == nil && filePath == nil { return nil }
    return ToolInput(command: command, filePath: filePath)
  }

  var output: String? {
    if case .completed(let state) = state { return state.output }
    return nil
  }

  var error: String? {
    if case .error(let state) = state { return state.error }
    return nil
  }
}

// MARK: - 5. 其他 Part

struct SnapshotPart: PartBase {
  let id: PartID
  let sessionID: SessionID
  let messageID: MessageID
  let type: String
  let snapshot: String
}

struct PatchPart: PartBase {
  let id: PartID
  let sessionID: SessionID
  let messageID: MessageID
  let type: String
  let hash: String
  let files: [String]
}

struct AgentSource: Codable, Sendable {
  let value: String
  let start: Int
  let end: Int
}

struct AgentPart: PartBase {
  let id: PartID
  let sessionID: SessionID
  let messageID: MessageID
  let type: String
  let name: String
  let source: AgentSource?
}

struct CompactionPart: PartBase {
  let id: PartID
  let sessionID: SessionID
  let messageID: MessageID
  let type: String
  let auto: Bool
  let overflow: Bool?
}

struct SubtaskModel: Codable, Sendable {
  let providerID: ProviderID
  let modelID: ModelID
}

struct SubtaskPart: PartBase {
  let id: PartID
  let sessionID: SessionID
  let messageID: MessageID
  let type: String
  let prompt: String
  let description: String
  let agent: String
  let model: SubtaskModel?
  let command: String?
}

struct RetryTime: Codable, Sendable {
  let created: TimeInterval
}

struct RetryPart: PartBase {
  let id: PartID
  let sessionID: SessionID
  let messageID: MessageID
  let type: String
  let attempt: Int
  let error: APIErrorInfo
  let time: RetryTime
}

struct StepStartPart: PartBase {
  let id: PartID
  let sessionID: SessionID
  let messageID: MessageID
  let type: String
  let snapshot: String?
}

struct StepFinishTokens: Codable, Sendable {
  let total: Int?
  let input: Int
  let output: Int
  let reasoning: Int
  let cache: MessageCacheTokens
}

struct StepFinishPart: PartBase {
  let id: PartID
  let sessionID: SessionID
  let messageID: MessageID
  let type: String
  let reason: String
  let snapshot: String?
  let cost: Double
  let tokens: StepFinishTokens
}

struct UnknownPart: PartBase {
  let id: PartID
  let sessionID: SessionID
  let messageID: MessageID
  let type: String

  var rawType: String { type }
}

/// Part 联合类型
enum Part: Codable, Sendable {
  case text(TextPart)
  case reasoning(ReasoningPart)
  case file(FilePart)
  case tool(ToolPart)
  case snapshot(SnapshotPart)
  case patch(PatchPart)
  case agent(AgentPart)
  case compaction(CompactionPart)
  case subtask(SubtaskPart)
  case retry(RetryPart)
  case stepStart(StepStartPart)
  case stepFinish(StepFinishPart)
  case unknown(UnknownPart)

  private enum CodingKeys: String, CodingKey {
    case type
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let type = try container.decode(String.self, forKey: .type)
    switch type {
    case "text": self = .text(try TextPart(from: decoder))
    case "reasoning": self = .reasoning(try ReasoningPart(from: decoder))
    case "file": self = .file(try FilePart(from: decoder))
    case "tool": self = .tool(try ToolPart(from: decoder))
    case "snapshot": self = .snapshot(try SnapshotPart(from: decoder))
    case "patch": self = .patch(try PatchPart(from: decoder))
    case "agent": self = .agent(try AgentPart(from: decoder))
    case "compaction": self = .compaction(try CompactionPart(from: decoder))
    case "subtask": self = .subtask(try SubtaskPart(from: decoder))
    case "retry": self = .retry(try RetryPart(from: decoder))
    case "step-start": self = .stepStart(try StepStartPart(from: decoder))
    case "step-finish": self = .stepFinish(try StepFinishPart(from: decoder))
    default:
      self = .unknown(try UnknownPart(from: decoder))
    }
  }

  func encode(to encoder: Encoder) throws {
    switch self {
    case .text(let part): try part.encode(to: encoder)
    case .reasoning(let part): try part.encode(to: encoder)
    case .file(let part): try part.encode(to: encoder)
    case .tool(let part): try part.encode(to: encoder)
    case .snapshot(let part): try part.encode(to: encoder)
    case .patch(let part): try part.encode(to: encoder)
    case .agent(let part): try part.encode(to: encoder)
    case .compaction(let part): try part.encode(to: encoder)
    case .subtask(let part): try part.encode(to: encoder)
    case .retry(let part): try part.encode(to: encoder)
    case .stepStart(let part): try part.encode(to: encoder)
    case .stepFinish(let part): try part.encode(to: encoder)
    case .unknown(let part): try part.encode(to: encoder)
    }
  }
}

/// 兼容旧代码：MessagePart 即 Part
typealias MessagePart = Part

extension ToolState {
  var statusText: String {
    switch self {
    case .pending: return "等待中"
    case .running: return "运行中"
    case .completed: return "已完成"
    case .error: return "失败"
    }
  }
}
