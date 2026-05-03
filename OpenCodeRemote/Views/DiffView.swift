// OpenCode Remote - Diff 差异渲染视图
// 解析 unified diff 格式并着色显示
// 创建时间：2026-05-03

import SwiftUI

// MARK: - Diff 行模型

/// 解析后的单行 diff 数据
struct DiffLine: Identifiable {
  let id: Int
  let content: String
  let kind: Kind

  enum Kind {
    case addition    // + 开头
    case deletion   // - 开头
    case hunkHeader // @@ ... @@ 头
    case context    // 普通上下文行
    case fileHeader // --- a/file 或 +++ b/file
  }
}

// MARK: - Diff 解析器

/// 将 unified diff 文本解析为 DiffLine 数组
enum DiffParser {
  static func parse(_ text: String) -> [DiffLine] {
    var lines: [DiffLine] = []
    let raw = text.split(separator: "\n", omittingEmptySubsequences: false)
    for (i, line) in raw.enumerated() {
      let s = String(line)
      let kind: DiffLine.Kind
      if s.hasPrefix("@@") {
        kind = .hunkHeader
      } else if s.hasPrefix("+++") || s.hasPrefix("---") {
        kind = .fileHeader
      } else if s.hasPrefix("+") {
        kind = .addition
      } else if s.hasPrefix("-") {
        kind = .deletion
      } else {
        kind = .context
      }
      lines.append(DiffLine(id: i, content: s, kind: kind))
    }
    return lines
  }
}

// MARK: - Diff 行视图

/// 单行 diff 渲染
struct DiffLineView: View {
  let line: DiffLine

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      Text(line.content)
        .font(.system(.caption2, design: .monospaced))
        .textSelection(.enabled)
      Spacer()
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 1)
    .background(backgroundColor)
  }

  private var backgroundColor: Color {
    switch line.kind {
    case .addition:   return AppColors.diffAdd
    case .deletion:   return AppColors.diffRemove
    case .hunkHeader: return Color(.systemTeal).opacity(0.1)
    case .fileHeader: return Color(.systemGray6)
    case .context:    return AppColors.diffContext
    }
  }
}

// MARK: - Diff 整体视图

/// 完整 diff 渲染，带折叠功能
struct DiffView: View {
  let lines: [DiffLine]
  @State private var isExpanded: Bool

  /// 从原始 diff 文本创建
  init(text: String, initiallyExpanded: Bool = false) {
    self.lines = DiffParser.parse(text)
    self._isExpanded = State(initialValue: initiallyExpanded)
  }

  /// 从已解析行创建
  init(lines: [DiffLine], initiallyExpanded: Bool = false) {
    self.lines = lines
    self._isExpanded = State(initialValue: initiallyExpanded)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 折叠/展开按钮
      Button {
        withAnimation(.easeInOut(duration: 0.2)) {
          isExpanded.toggle()
        }
      } label: {
        HStack(spacing: 4) {
          Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.caption2)
          Text("Diff (\(additionCount) 增 / \(deletionCount) 删)")
            .font(.caption)
          Spacer()
        }
        .foregroundColor(.secondary)
      }
      .buttonStyle(.plain)

      if isExpanded {
        ScrollView(.horizontal, showsIndicators: false) {
          LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(lines) { line in
              DiffLineView(line: line)
            }
          }
        }
        .frame(maxHeight: 400)
        .clipShape(RoundedRectangle(cornerRadius: 6))
      }
    }
    .padding(6)
    .background(Color(.systemGray6))
    .cornerRadius(6)
  }

  private var additionCount: Int {
    lines.filter { $0.kind == .addition }.count
  }

  private var deletionCount: Int {
    lines.filter { $0.kind == .deletion }.count
  }
}