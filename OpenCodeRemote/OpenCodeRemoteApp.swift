// OpenCode Remote - App 入口
// 创建时间：2026-04-29

import SwiftUI

/// App 入口，注入全局依赖
@main
struct OpenCodeRemoteApp: App {
  @StateObject private var connectionStore: ConnectionStore
  @StateObject private var sessionStore: SessionStore
  @StateObject private var permissionCoordinator: PermissionCoordinator

  init() {
    let api = OpenCodeAPIClient()
    let eventStream = EventStreamClient()
    let connStore = ConnectionStore(apiClient: api)
    let sessStore = SessionStore(apiClient: api, eventStreamClient: eventStream, connectionStore: connStore)
    let coordinator = PermissionCoordinator(sessionStore: sessStore)
    _connectionStore = StateObject(wrappedValue: connStore)
    _sessionStore = StateObject(wrappedValue: sessStore)
    _permissionCoordinator = StateObject(wrappedValue: coordinator)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(connectionStore)
        .environmentObject(sessionStore)
        .environmentObject(permissionCoordinator)
    }
  }
}
