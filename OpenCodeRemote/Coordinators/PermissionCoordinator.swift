// OpenCodeRemote - 权限审批协调器
// 创建时间：2026-04-29

import SwiftUI

/// 权限审批协调器，管理权限请求的展示和响应
@MainActor
final class PermissionCoordinator: ObservableObject {
  /// 当前待处理的权限请求
  @Published var pendingPermission: PermissionRequest?
  /// 是否显示权限审批 Sheet
  @Published var isShowingPermissionSheet = false
  /// 最近一条权限处理结果
  @Published var lastResult: PermissionResult?

  private let sessionStore: SessionStore

  init(sessionStore: SessionStore) {
    self.sessionStore = sessionStore
    setupNotificationObservers()
  }

  /// 允许权限（仅本次）
  func allow(permissionId: String) async {
    await sessionStore.respondToPermission(permissionId: permissionId, action: .allow)
    dismissSheet()
  }

  /// 始终允许
  func allowAlways(permissionId: String) async {
    await sessionStore.respondToPermission(permissionId: permissionId, action: .allowAlways)
    dismissSheet()
  }

  /// 拒绝权限
  func deny(permissionId: String, reason: String? = nil) async {
    await sessionStore.respondToPermission(permissionId: permissionId, action: .deny, reason: reason)
    dismissSheet()
  }

  // MARK: - 通知处理

  private func setupNotificationObservers() {
    NotificationCenter.default.addObserver(
      forName: .permissionRequestReceived,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self, let perm = notification.userInfo?["permission"] as? PermissionRequest else { return }
      self.pendingPermission = perm
      self.isShowingPermissionSheet = true
    }

    NotificationCenter.default.addObserver(
      forName: .permissionResolved,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      // 权限已处理后关闭 Sheet
      if let status = notification.userInfo?["status"] as? PermissionStatus, status.isResolved {
        self?.dismissSheet()
      }
    }
  }

  private func dismissSheet() {
    isShowingPermissionSheet = false
  }
}

extension Notification.Name {
  static let permissionRequestReceived = Notification.Name("permissionRequestReceived")
  static let permissionResolved = Notification.Name("permissionResolved")
}
