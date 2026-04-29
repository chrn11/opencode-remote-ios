// OpenCodeRemote - 会话列表行
// 创建时间：2026-04-29

import SwiftUI

/// 会话列表行组件
struct SessionRowView: View {
  let session: SessionInfo

  var body: some View {
    HStack(spacing: AppSpacing.md) {
      // 状态图标
      Image(systemName: session.status.iconName)
        .font(.title3)
        .foregroundColor(statusColor)
        .frame(width: 32)

      // 标题和信息
      VStack(alignment: .leading, spacing: AppSpacing.xs) {
        Text(session.title)
          .font(AppTypography.headline)
          .lineLimit(1)

        HStack(spacing: AppSpacing.sm) {
          Text(session.status.displayName)
            .font(AppTypography.caption)
            .foregroundColor(statusColor)
          Text("·")
            .font(AppTypography.caption)
            .foregroundColor(.secondary)
          Text("\(session.messageCount) 条消息")
            .font(AppTypography.caption)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      // 时间
      Text(session.updatedAt.relativeDescription)
        .font(AppTypography.caption)
        .foregroundColor(.secondary)
    }
    .padding(.vertical, AppSpacing.xs)
  }

  private var statusColor: Color {
    switch session.status {
    case .running: return AppColors.running
    case .thinking: return AppColors.thinking
    case .idle: return AppColors.idle
    case .error: return AppColors.error
    case .unknown: return AppColors.idle
    }
  }
}
