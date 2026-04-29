// OpenCodeRemote - 轻量级 Markdown 渲染
// 创建时间：2026-04-29

import SwiftUI

/// 轻量级 AttributedString Markdown 渲染器
/// 不使用 WebView，避免性能开销
enum MarkdownRenderer {
  /// 将 Markdown 文本转换为 AttributedString
  static func render(_ text: String) -> AttributedString {
    do {
      // 预处理：将代码块标记为等宽字体友好格式
      var processed = text
      // 处理行内代码 `code`
      // 处理代码块 ```code```
      var attributed = try AttributedString(
        markdown: processed,
        options: AttributedString.MarkdownParsingOptions(
          allowsExtendedAttributes: true,
          interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
      )

      // 设置基础字体
      attributed.font = .system(.body, design: .default)
      return attributed
    } catch {
      // Markdown 解析失败时降级为纯文本
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
