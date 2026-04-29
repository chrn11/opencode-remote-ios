// OpenCodeRemote - 权限审批 Sheet
// 创建时间：2026-04-29

import SwiftUI

/// 权限审批界面
struct PermissionSheet: View {
  let permission: PermissionRequest
  @ObservedObject var coordinator: PermissionCoordinator

  @State private var denyReason: String = ""

  var body: some View {
    NavigationStack {
      VStack(spacing: AppSpacing.xl) {
        // 风险评估
        riskSection

        Divider()

        // 请求详情
        detailSection

        Spacer()

        // 操作按钮
        actionButtons
      }
      .padding(AppSpacing.lg)
      .navigationTitle("权限请求")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("取消") {
            coordinator.isShowingPermissionSheet = false
          }
        }
      }
    }
    .presentationDetents([.medium, .large])
  }

  // MARK: - 子视图

  private var riskSection: some View {
    VStack(spacing: AppSpacing.sm) {
      Image(systemName: AppIcons.forRisk(permission.risk))
        .font(.system(size: 40))

      Text("风险等级：\(riskDisplayName)")
        .font(AppTypography.title)

      Text(riskDescription)
        .font(AppTypography.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  private var detailSection: some View {
    VStack(alignment: .leading, spacing: AppSpacing.sm) {
      LabeledContent("工具", value: permission.permission)
        .font(AppTypography.body)

      if let command = permission.command {
        LabeledContent("命令", value: command)
          .font(AppTypography.body)
          .lineLimit(3)
      }

      if let filePath = permission.filePath {
        LabeledContent("文件", value: filePath)
          .font(AppTypography.body)
          .lineLimit(2)
      }

      if let description = permission.description {
        LabeledContent("说明", value: description)
          .font(AppTypography.body)
          .lineLimit(5)
      }
    }
    .padding(AppSpacing.md)
    .background(Color(.systemGroupedBackground))
    .cornerRadius(AppSpacing.sm)
  }

  private var actionButtons: some View {
    VStack(spacing: AppSpacing.md) {
      // 允许
      Button {
        Task { await coordinator.allow(permissionId: permission.id) }
      } label: {
        Label("允许（仅本次）", systemImage: "checkmark.shield")
          .frame(maxWidth: .infinity)
          .padding(.vertical, AppSpacing.md)
      }
      .buttonStyle(.borderedProminent)
      .tint(AppColors.running)

      // 始终允许
      Button {
        Task { await coordinator.allowAlways(permissionId: permission.id) }
      } label: {
        Label("始终允许", systemImage: "checkmark.shield.fill")
          .frame(maxWidth: .infinity)
          .padding(.vertical, AppSpacing.md)
      }
      .buttonStyle(.bordered)

      // 拒绝
      GroupBox("拒绝原因（可选）") {
        TextField("输入拒绝原因...", text: $denyReason)
          .font(AppTypography.caption)
      }

      Button {
        let reason = denyReason.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
          await coordinator.deny(
            permissionId: permission.id,
            reason: reason.isEmpty ? nil : reason
          )
        }
      } label: {
        Label("拒绝", systemImage: "xmark.shield")
          .frame(maxWidth: .infinity)
          .padding(.vertical, AppSpacing.md)
      }
      .buttonStyle(.bordered)
      .tint(AppColors.error)
    }
  }

  // MARK: - 辅助计算

  private var riskDisplayName: String {
    switch permission.risk {
    case .low: "低"
    case .medium: "中"
    case .high: "高"
    case .critical: "严重"
    }
  }

  private var riskDescription: String {
    switch permission.risk {
    case .low: return "此操作风险较低，通常安全"
    case .medium: return "此操作涉及系统交互，请留意"
    case .high: return "此操作可能修改系统或文件"
    case .critical: return "⚠️ 此操作可能造成不可逆影响"
    }
  }
}
