// OpenCodeRemote - SF Symbols 图标名称映射
// 创建时间：2026-04-29

import SwiftUI

/// SF Symbols 名称映射，统一管理图标
enum AppIcons {
  static let server = "network"
  static let session = "bubble.left.and.bubble.right"
  static let send = "arrow.up.circle.fill"
  static let abort = "stop.circle.fill"
  static let permission = "hand.raised"
  static let settings = "gearshape"
  static let debug = "ladybug"
  static let health = "heart.text.square"
  static let disconnect = "xmark.circle"
  static let copy = "doc.on.doc"
  static let expand = "chevron.down"
  static let collapse = "chevron.up"
  static let refresh = "arrow.clockwise"

  /// 根据风险等级返回对应图标
  static func forRisk(_ risk: PermissionRisk) -> String {
    switch risk {
    case .low, .medium: return "checkmark.shield"
    case .high: return "exclamationmark.shield"
    case .critical: return "xmark.shield"
    }
  }
}
