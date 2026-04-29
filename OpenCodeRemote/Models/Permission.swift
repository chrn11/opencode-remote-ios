// OpenCode Remote - 权限模型
// 基于 OpenCode 源码 packages/opencode/src/permission/index.ts
// 创建时间：2026-04-29

import Foundation

/// 权限动作
enum PermissionAction: String, Codable, Sendable {
  case allow
  case allowAlways
  case deny
  case ask
}

/// 权限规则
struct PermissionRule: Codable, Sendable {
  let permission: String
  let pattern: String
  let action: PermissionAction
}

/// 权限规则集
typealias PermissionRuleset = [PermissionRule]

/// 权限请求里的工具引用
struct PermissionToolRef: Codable, Sendable {
  let messageID: MessageID
  let callID: String
}

/// 权限请求
struct PermissionRequest: Codable, Identifiable, Sendable {
  let id: PermissionID
  let sessionID: SessionID
  let permission: String
  let patterns: [String]
  let metadata: [String: CodableValue]
  let always: [String]
  let tool: PermissionToolRef?

  var risk: PermissionRisk { .medium }
  var command: String? { metadata["command"]?.stringValue }
  var filePath: String? { metadata["filePath"]?.stringValue }
  var description: String? { metadata["description"]?.stringValue }
}

/// 权限回复
enum PermissionReply: String, Codable, Sendable {
  case once
  case always
  case reject
}

/// 权限风险等级（兼容权限弹窗）
enum PermissionRisk: Sendable {
  case low
  case medium
  case high
  case critical
}

/// 权限状态（兼容旧 UI / SSE 事件）
enum PermissionStatus: String, Codable, Sendable {
  case ask
  case allow
  case allowAlways
  case deny

  var isResolved: Bool {
    self != .ask
  }
}

/// 权限处理结果（兼容旧 UI）
struct PermissionResult: Codable, Sendable {
  let id: PermissionID
  let status: PermissionStatus
  let action: String?
}

/// 权限回复请求体
struct PermissionReplyBody: Codable, Sendable {
  let reply: PermissionReply
  let message: String?
}
