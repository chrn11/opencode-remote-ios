// OpenCodeRemote - 工具与辅助卡片
// 创建时间：2026-04-29

import SwiftUI

/// 工具调用卡片（简化版）
struct ToolCallCardView: View {
  let toolPart: ToolPart
  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
      } label: {
        HStack {
          Image(systemName: "wrench")
            .foregroundColor(statusColor)
          Text(toolPart.tool)
            .font(AppTypography.body.bold())
          Spacer()
          Text(toolPart.state.statusText)
            .font(AppTypography.caption)
          Image(systemName: isExpanded ? AppIcons.collapse : AppIcons.expand)
            .font(AppTypography.caption)
            .foregroundColor(.secondary)
        }
      }
      .buttonStyle(.plain)

      if isExpanded {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
          if let output = toolOutput {
            ScrollView(.horizontal) {
              Text(output)
                .font(AppTypography.monoSmall)
                .textSelection(.enabled)
            }
          } else {
            Text("暂无输出")
              .font(AppTypography.caption)
              .foregroundColor(.secondary)
          }
        }
      }
    }
    .padding(AppSpacing.md)
    .background(AppColors.toolCard)
    .cornerRadius(AppSpacing.sm)
  }

  private var toolOutput: String? {
    if case .completed(let state) = toolPart.state { return state.output }
    if case .error(let state) = toolPart.state { return state.error }
    return nil
  }

  private var statusColor: Color {
    switch toolPart.state {
    case .pending, .running: return AppColors.thinking
    case .completed: return AppColors.running
    case .error: return AppColors.error
    }
  }
}

/// 推理过程卡片
struct ReasoningCardView: View {
  let content: String
  @State private var isExpanded = false

  var body: some View {
    VStack(alignment: .leading, spacing: AppSpacing.xs) {
      Button {
        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
      } label: {
        HStack {
          Image(systemName: "brain")
            .foregroundColor(AppColors.thinking)
          Text("思考过程")
            .font(AppTypography.caption.bold())
          Spacer()
          Text(isExpanded ? "收起" : "展开")
            .font(AppTypography.caption)
            .foregroundColor(.secondary)
        }
      }
      .buttonStyle(.plain)

      if isExpanded {
        Text(MarkdownRenderer.render(content))
          .font(AppTypography.caption)
          .textSelection(.enabled)
      }
    }
    .padding(AppSpacing.md)
    .background(Color.orange.opacity(0.06))
    .cornerRadius(AppSpacing.sm)
  }
}

/// 文件卡片
struct FileCardView: View {
  let filePart: FilePart

  var body: some View {
    HStack(spacing: AppSpacing.sm) {
      Image(systemName: "doc")
        .foregroundColor(.secondary)
      VStack(alignment: .leading, spacing: 2) {
        Text(filePart.filename ?? filePart.mime)
          .font(AppTypography.caption.bold())
        Text(filePart.mime)
          .font(AppTypography.caption)
          .foregroundColor(.secondary)
      }
      Spacer()
    }
    .padding(AppSpacing.md)
    .background(AppColors.toolCard)
    .cornerRadius(AppSpacing.sm)
  }
}
