// OpenCodeRemote - 消息气泡组件
// 创建时间：2026-04-29

import SwiftUI

/// 消息气泡视图
struct MessageBubbleView: View {
  let message: Message

  var body: some View {
    VStack(alignment: message.role == .user ? .trailing : .leading, spacing: AppSpacing.sm) {
      Text(roleDisplayName)
        .font(AppTypography.caption)
        .foregroundColor(.secondary)

      VStack(alignment: .leading, spacing: AppSpacing.sm) {
        ForEach(message.parts.indices, id: \.self) { index in
          partView(for: message.parts[index])
        }
      }
      .padding(AppSpacing.md)
      .background(bubbleBackground)
      .cornerRadius(AppSpacing.lg)
    }
    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    .padding(.horizontal, AppSpacing.md)
    .padding(.vertical, AppSpacing.xs)
  }

  @ViewBuilder
  private func partView(for part: Part) -> some View {
    switch part {
    case .text(let textPart):
      Text(textPart.text)
        .textSelection(.enabled)

    case .reasoning(let reasoningPart):
      ReasoningCardView(content: reasoningPart.text)

    case .tool(let toolPart):
      ToolCallCardView(toolPart: toolPart)

    case .file(let filePart):
      FileCardView(filePart: filePart)

    case .stepFinish(let stepPart):
      Text("消耗: ¥\(String(format: "%.4f", stepPart.cost))")
        .font(AppTypography.caption)
        .foregroundColor(.secondary)

    case .unknown(let unknownPart):
      HStack {
        Image(systemName: "questionmark.square.dashed")
        Text("未知内容类型: \(unknownPart.type)")
      }
      .font(AppTypography.caption)
      .foregroundColor(.secondary)

    default:
      EmptyView()
    }
  }

  private var bubbleBackground: some View {
    Group {
      switch message.role {
      case .user: AppColors.userBubble
      case .assistant: AppColors.assistantBg
      }
    }
  }

  private var roleDisplayName: String {
    switch message.role {
    case .user: "你"
    case .assistant: "OpenCode"
    }
  }
}
