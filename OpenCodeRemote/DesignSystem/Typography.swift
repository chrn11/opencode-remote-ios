// OpenCodeRemote - 全局字体定义
// 创建时间：2026-04-29

import SwiftUI

/// 全局字体规范，遵循 Dynamic Type
enum AppTypography {
  static let title = Font.title2.bold()
  static let headline = Font.headline
  static let body = Font.body
  static let caption = Font.caption
  static let mono = Font.system(.body, design: .monospaced)
  static let monoSmall = Font.system(.caption, design: .monospaced)
}
