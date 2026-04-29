// OpenCodeRemote - 字符串截断和显示工具
// 创建时间：2026-04-29

import Foundation

extension String {
  /// 截断字符串到指定字符数，超出部分显示省略号和"显示更多"提示
  func truncated(limit: Int = 500) -> (display: String, isTruncated: Bool) {
    if count <= limit {
      return (self, false)
    }
    return (String(prefix(limit)) + "\n... (内容过长，点击展开)", true)
  }

  /// 从命令字符串中提取可执行程序名
  var commandName: String {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    guard let firstSpace = trimmed.firstIndex(of: " ") else {
      return trimmed
    }
    return String(trimmed[..<firstSpace])
  }

  /// 判断是否为二进制类内容（避免在 UI 中暴力展示）
  var looksLikeBinary: Bool {
    let sample = prefix(200)
    let controlChars = sample.filter { $0.asciiValue.map { $0 < 32 && $0 != 9 && $0 != 10 && $0 != 13 } ?? false }
    return controlChars.count > sample.count / 3
  }
}
