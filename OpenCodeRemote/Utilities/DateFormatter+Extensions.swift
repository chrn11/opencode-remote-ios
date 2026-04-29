// OpenCodeRemote - 日期格式化扩展
// 创建时间：2026-04-29

import Foundation

extension DateFormatter {
  /// 会话列表使用的相对时间格式化器
  static let relativeSession: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    return formatter
  }()
}

extension Date {
  /// 相对于当前时间的中文描述
  var relativeDescription: String {
    let interval = Date().timeIntervalSince(self)
    if interval < 60 {
      return "刚刚"
    } else if interval < 3600 {
      return "\(Int(interval / 60)) 分钟前"
    } else if interval < 86400 {
      return "\(Int(interval / 3600)) 小时前"
    } else if interval < 604800 {
      return "\(Int(interval / 86400)) 天前"
    } else {
      let formatter = DateFormatter.relativeSession
      formatter.dateFormat = "MM-dd HH:mm"
      return formatter.string(from: self)
    }
  }

  /// 完整时间格式
  var fullFormat: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
    return formatter.string(from: self)
  }
}
