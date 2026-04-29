// OpenCodeRemote - 聊天详情页面
// 创建时间：2026-04-29

import SwiftUI

/// 聊天页面，含消息列表和输入栏
struct ChatScreen: View {
  @ObservedObject var sessionStore: SessionStore
  @ObservedObject var permissionCoordinator: PermissionCoordinator

  @State private var scrollProxy: ScrollViewProxy?

  var body: some View {
    VStack(spacing: 0) {
      // 会话标题栏
      if let session = sessionStore.selectedSession {
        sessionHeader(session)
      }

      // 消息列表
      Group {
        if sessionStore.isLoading && sessionStore.messages.isEmpty {
          loadingView
        } else if let error = sessionStore.error, sessionStore.messages.isEmpty {
          errorView(error)
        } else if sessionStore.messages.isEmpty {
          emptyView
        } else {
          messageScrollView
        }
      }

      // 输入栏（固定在底部）
      ChatInputBar(sessionStore: sessionStore)
    }
    .navigationBarTitleDisplayMode(.inline)
    .task {
      sessionStore.subscribeToEvents()
    }
    .onDisappear {
      sessionStore.unsubscribeEvents()
    }
    .sheet(isPresented: $permissionCoordinator.isShowingPermissionSheet) {
      if let perm = permissionCoordinator.pendingPermission {
        PermissionSheet(
          permission: perm,
          coordinator: permissionCoordinator
        )
      }
    }
  }

  // MARK: - 子视图

  private func sessionHeader(_ session: SessionDetail) -> some View {
    let status = SessionStatus(rawValue: sessionStore.statusForSession(session.id)) ?? .idle
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(session.title)
          .font(AppTypography.headline)
        HStack(spacing: AppSpacing.sm) {
          Image(systemName: status.iconName)
            .font(AppTypography.caption)
          Text(status.displayName)
            .font(AppTypography.caption)
            .foregroundColor(.secondary)
        }
      }
      Spacer()
    }
    .padding(.horizontal, AppSpacing.lg)
    .padding(.vertical, AppSpacing.sm)
    .background(.bar)
    Divider()
  }

  private var messageScrollView: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 0) {
          ForEach(sessionStore.messages) { message in
            MessageBubbleView(message: message)
              .id(message.id)
          }
        }
        .padding(.bottom, AppSpacing.sm)
      }
      .onAppear {
        scrollProxy = proxy
        if let lastId = sessionStore.messages.last?.id {
          proxy.scrollTo(lastId, anchor: .bottom)
        }
      }
      .onChange(of: sessionStore.messages.count) { _, _ in
        if let lastId = sessionStore.messages.last?.id {
          withAnimation {
            proxy.scrollTo(lastId, anchor: .bottom)
          }
        }
      }
    }
  }

  private var loadingView: some View {
    VStack(spacing: AppSpacing.md) {
      ProgressView()
      Text("加载消息...")
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
      Button("重试") {
        Task {
          if let id = sessionStore.selectedSession?.id {
            await sessionStore.selectSession(id)
          }
        }
      }
      .buttonStyle(.bordered)
    }
  }

  private var emptyView: some View {
    VStack(spacing: AppSpacing.md) {
      Image(systemName: "bubble.left")
        .font(.system(size: 48))
        .foregroundColor(.secondary)
      Text("发送第一条指令开始对话")
        .font(AppTypography.headline)
        .foregroundColor(.secondary)
    }
  }
}
