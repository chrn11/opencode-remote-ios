// OpenCodeRemote - 轻量级 Markdown 渲染
// 创建时间：2026-04-29

import SwiftUI

/// 轻量级 AttributedString Markdown 渲染器
/// 不使用 WebView，避免性能开销
enum MarkdownRenderer {
  /// 将 Markdown 文本转换为 AttributedString
  static func render(_ text: String) -> AttributedString {
    do {
      let processed = text
      var attributed = try AttributedString(
        markdown: processed,
        options: AttributedString.MarkdownParsingOptions(
          allowsExtendedAttributes: true,
          interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
      )

      attributed.font = .system(.body, design: .default)

      for run in attributed.runs {
        if run.inlinePresentationIntent?.contains(.code) == true {
          attributed[run.range].font = .system(.body, design: .monospaced)
          attributed[run.range].backgroundColor = Color(.systemGray6)
          attributed[run.range].foregroundColor = .primary
        }
      }

      return attributed
    } catch {
      return AttributedString(text)
    }
  }

  /// 渲染代码内容（保留换行和缩进，不解析 Markdown）
  static func renderCode(_ code: String) -> String {
    code
  }
}

// MARK: - SwiftUI View 扩展

extension View {
  /// 便捷 Markdown 文本渲染 View Modifier
  func markdownText(_ text: String) -> some View {
    Text(MarkdownRenderer.render(text))
      .textSelection(.enabled)
  }
}
