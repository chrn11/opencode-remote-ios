// OpenCodeRemote - 服务器连接页面
// 创建时间：2026-04-29

import SwiftUI

/// 服务器连接配置页面
struct ConnectionScreen: View {
  @ObservedObject var connectionStore: ConnectionStore
  @ObservedObject var sessionStore: SessionStore
  var onConnected: () -> Void

  var body: some View {
    NavigationStack {
      VStack(spacing: AppSpacing.xl) {
        // 顶部标题区
        headerSection

        // 表单区
        formSection

        // 错误信息
        if connectionStore.status == .error, let error = connectionStore.lastError {
          errorBanner(error)
        }

        Spacer()

        // 操作按钮
        actionButtons
      }
      .padding(AppSpacing.lg)
      .navigationTitle("OpenCode 远程")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            onConnected()
          } label: {
            Label("跳过", systemImage: "arrow.forward")
          }
          .disabled(connectionStore.status != .connected)
        }
      }
    }
  }

  // MARK: - 子视图

  private var headerSection: some View {
    VStack(spacing: AppSpacing.sm) {
      Image(systemName: AppIcons.server)
        .font(.system(size: 48))
        .foregroundColor(AppColors.accent)
      Text("连接到 OpenCode 服务器")
        .font(AppTypography.title)
        .foregroundColor(.primary)
      Text("输入服务器地址和凭据，开始远程控制")
        .font(AppTypography.caption)
        .foregroundColor(.secondary)
    }
  }

  private var formSection: some View {
    VStack(spacing: AppSpacing.md) {
      TextField("服务器地址 (例: 192.168.1.100:4096)", text: $connectionStore.serverURL)
        .textFieldStyle(.roundedBorder)
        .keyboardType(.URL)
        .autocapitalization(.none)
        .disableAutocorrection(true)

      SecureField("认证令牌", text: $connectionStore.authToken)
        .textFieldStyle(.roundedBorder)

      Button {
        connectionStore.clear()
      } label: {
        Label("清除凭据", systemImage: "trash")
          .font(AppTypography.caption)
      }
      .foregroundColor(.secondary)
      .frame(maxWidth: .infinity, alignment: .trailing)
    }
  }

  private func errorBanner(_ error: String) -> some View {
    HStack(spacing: AppSpacing.sm) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundColor(AppColors.error)
      Text(error)
        .font(AppTypography.caption)
        .foregroundColor(AppColors.error)
        .multilineTextAlignment(.leading)
    }
    .padding(AppSpacing.md)
    .background(AppColors.error.opacity(0.1))
    .cornerRadius(AppSpacing.sm)
  }

  private var actionButtons: some View {
    VStack(spacing: AppSpacing.md) {
      Button {
        Task {
          let success = await connectionStore.connect()
          if success {
            await sessionStore.refreshSessions()
            onConnected()
          }
        }
      } label: {
        Group {
          if connectionStore.status == .connecting {
            ProgressView()
              .tint(.white)
          } else {
            Label("连接服务器", systemImage: AppIcons.health)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
      }
      .buttonStyle(.borderedProminent)
      .disabled(connectionStore.status == .connecting)

      if connectionStore.status == .connected {
        Text("已连接到 \(connectionStore.serverInfo?.url ?? "")")
          .font(AppTypography.caption)
          .foregroundColor(.secondary)
      }
    }
  }
}
