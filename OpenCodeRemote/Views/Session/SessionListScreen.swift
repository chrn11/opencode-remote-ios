// OpenCodeRemote - 会话列表页面
// 创建时间：2026-04-29

import SwiftUI

/// 会话列表页面
struct SessionListScreen: View {
  @ObservedObject var sessionStore: SessionStore
  var onSelectSession: (String) -> Void

  @State private var showingSettings = false

  var body: some View {
    NavigationStack {
      Group {
        if sessionStore.isLoading && sessionStore.sessions.isEmpty {
          loadingView
        } else if let error = sessionStore.error, sessionStore.sessions.isEmpty {
          errorView(error)
        } else if sessionStore.sessions.isEmpty {
          emptyView
        } else {
          sessionList
        }
      }
      .navigationTitle("会话")
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            showingSettings = true
          } label: {
            Image(systemName: AppIcons.settings)
          }
        }
        ToolbarItem(placement: .navigationBarLeading) {
          Button {
            Task { await sessionStore.refreshSessions() }
          } label: {
            Image(systemName: AppIcons.refresh)
          }
        }
      }
      .sheet(isPresented: $showingSettings) {
        SettingsScreen()
      }
      .refreshable {
        await sessionStore.refreshSessions()
      }
      .task {
        if sessionStore.sessions.isEmpty {
          await sessionStore.refreshSessions()
        }
      }
    }
  }

  // MARK: - 子视图

  private var sessionList: some View {
    List(sessionStore.sessions) { session in
      Button {
        onSelectSession(session.id)
      } label: {
        SessionRowView(session: session)
      }
      .buttonStyle(.plain)
    }
    .listStyle(.plain)
  }

  private var loadingView: some View {
    VStack(spacing: AppSpacing.md) {
      ProgressView()
      Text("加载会话列表...")
        .font(AppTypography.caption)
        .foregroundColor(.secondary)
    }
  }

  private func errorView(_ error: String) -> some View {
    VStack(spacing: AppSpacing.md) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 48))
        .foregroundColor(AppColors.error)
      Text("加载失败")
        .font(AppTypography.headline)
      Text(error)
        .font(AppTypography.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
      Button("重试") {
        Task { await sessionStore.refreshSessions() }
      }
      .buttonStyle(.bordered)
    }
    .padding()
  }

  private var emptyView: some View {
    VStack(spacing: AppSpacing.md) {
      Image(systemName: "bubble.left")
        .font(.system(size: 48))
        .foregroundColor(.secondary)
      Text("暂无会话")
        .font(AppTypography.headline)
        .foregroundColor(.secondary)
      Text("在电脑上通过 OpenCode 开始编码后，会话将出现在这里")
        .font(AppTypography.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
  }
}
