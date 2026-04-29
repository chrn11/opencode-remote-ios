// OpenCode Remote - App 入口
// 对齐 OpenCode 源码 app.tsx 路由：/ → Home, /:dir/session/:id → Session
// 创建时间：2026-04-29

import SwiftUI

@main
struct OpenCodeRemoteApp: App {
  @StateObject private var connectionStore: ConnectionStore
  @StateObject private var sessionStore: SessionStore

  init() {
    let api = OpenCodeAPIClient()
    let eventStream = EventStreamClient()
    let conn = ConnectionStore(apiClient: api)
    let sess = SessionStore(apiClient: api, eventStreamClient: eventStream, connectionStore: conn)
    _connectionStore = StateObject(wrappedValue: conn)
    _sessionStore = StateObject(wrappedValue: sess)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(connectionStore)
        .environmentObject(sessionStore)
    }
  }
}
