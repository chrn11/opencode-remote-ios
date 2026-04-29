// OpenCode Remote - 会话模型
// 基于 OpenCode 源码 packages/opencode/src/session/index.ts
// 创建时间：2026-04-29

import Foundation

/// 文件差异
struct FileDiff: Codable, Sendable {
  let file: String
  let additions: Int
  let deletions: Int
}

/// 会话摘要信息
struct SessionInfo: Codable, Identifiable, Sendable {
  let id: SessionID
  let slug: String
  let projectID: String
  let workspaceID: String?
  let directory: String
  let parentID: SessionID?
  let title: String
  let version: String
  let summary: SessionSummary?
  let share: SessionShare?
  let permission: [PermissionRule]?
  let revert: SessionRevert?
  let time: SessionTime

  var messageCount: Int { summary?.files ?? 0 }
  var updatedAt: Date { Date(timeIntervalSince1970: time.updated / 1000) }
}

/// 会话统计摘要
struct SessionSummary: Codable, Sendable {
  let additions: Int
  let deletions: Int
  let files: Int
  let diffs: [FileDiff]?

  var title: String? { nil }
  var status: SessionStatus { .idle }
  var messageCount: Int { files }
  var updatedAt: Date { Date() }
}

/// 会话分享信息
struct SessionShare: Codable, Sendable {
  let url: String
}

/// 会话回退信息
struct SessionRevert: Codable, Sendable {
  let messageID: MessageID
  let partID: PartID?
  let snapshot: String?
  let diff: String?
}

/// 会话时间信息
struct SessionTime: Codable, Sendable {
  let created: TimeInterval
  let updated: TimeInterval
  let compacting: TimeInterval?
  let archived: TimeInterval?
}

/// 项目信息（GlobalInfo 使用）
struct SessionProjectInfo: Codable, Sendable {
  let id: String
  let name: String?
  let worktree: String
}

/// 全局会话信息
struct GlobalSessionInfo: Codable, Sendable {
  let session: SessionInfo
  let project: SessionProjectInfo?
}

/// 兼容旧命名：SessionDetail 即 SessionInfo
typealias SessionDetail = SessionInfo

/// 会话状态（兼容列表与 SSE）
enum SessionStatus: String, Codable, Sendable {
  case idle
  case running
  case thinking
  case error
  case unknown

  var iconName: String {
    switch self {
    case .idle: return "circle"
    case .running: return "play.circle.fill"
    case .thinking: return "brain.head.profile"
    case .error: return "exclamationmark.triangle.fill"
    case .unknown: return "questionmark.circle"
    }
  }

  var displayName: String {
    switch self {
    case .idle: return "空闲"
    case .running: return "运行中"
    case .thinking: return "思考中"
    case .error: return "错误"
    case .unknown: return "未知"
    }
  }
}

/// 创建会话请求
struct SessionCreateInput: Codable, Sendable {
  let parentID: SessionID?
  let title: String?
  let permission: [PermissionRule]?
  let workspaceID: String?
}

/// Fork 会话请求
struct SessionForkInput: Codable, Sendable {
  let messageID: MessageID?
}

/// 设置归档时间请求
struct SessionArchiveInput: Codable, Sendable {
  let sessionID: SessionID
  let time: TimeInterval?
}

/// 设置权限请求
struct SessionPermissionInput: Codable, Sendable {
  let sessionID: SessionID
  let permission: [PermissionRule]
}

/// 设置摘要请求
struct SessionSummaryInput: Codable, Sendable {
  let sessionID: SessionID
  let summary: SessionSummary
}

/// 设置回退信息请求
struct SessionRevertInput: Codable, Sendable {
  let sessionID: SessionID
  let revert: SessionRevert?
  let summary: SessionSummary?
}
