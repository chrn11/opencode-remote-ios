// OpenCodeRemote - 全局颜色定义
// 创建时间：2026-04-29

import SwiftUI

/// 全局颜色常量，使用系统语义色保持原生感
enum AppColors {
  /// 主色调（仅用于关键操作和状态）
  static let accent = Color.accentColor

  /// 运行中状态色
  static let running = Color.green
  /// 思考中状态色
  static let thinking = Color.orange
  /// 空闲状态色
  static let idle = Color.secondary
  /// 错误状态色
  static let error = Color.red

  /// 用户消息气泡
  static let userBubble = Color.blue.opacity(0.12)
  /// 助手消息背景
  static let assistantBg = Color(.systemGroupedBackground)
  /// 工具调用卡片背景
  static let toolCard = Color(.secondarySystemGroupedBackground)
  /// 权限审批卡片背景
  static let permissionCard = Color.yellow.opacity(0.1)

  /// Diff 行颜色
  static let diffAdd = Color.green.opacity(0.15)
  static let diffRemove = Color.red.opacity(0.15)
  static let diffContext = Color.clear
}
