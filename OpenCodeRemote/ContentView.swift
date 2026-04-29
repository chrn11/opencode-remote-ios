// OpenCode Remote - 根视图路由
// 创建时间：2026-04-29

import SwiftUI

struct ContentView: View {
  @EnvironmentObject var connectionStore: ConnectionStore
  @EnvironmentObject var sessionStore: SessionStore
  @State private var input = ""
  @State private var showingChat = false

  var body: some View {
    Group {
      if connectionStore.status == .connected {
        if UIDevice.current.userInterfaceIdiom == .pad {
          NavigationSplitView {
            RootSessionListView
          } detail: {
            RootDetailView
          }
        } else {
          NavigationStack {
            RootSessionListView
              .navigationDestination(isPresented: $showingChat) {
                RootChatView
              }
          }
        }
      } else {
        RootConnectionView
      }
    }
  }

  private var RootSessionListView: some View {
    List {
      ForEach(sessionStore.sessions) { session in
        Button {
          if UIDevice.current.userInterfaceIdiom != .pad {
            showingChat = true
          }
          Task { await sessionStore.selectSession(session.id) }
        } label: {
          RootSessionRowView(session: session)
        }
      }
    }
    .navigationTitle("会话")
    .refreshable { await sessionStore.refreshSessions() }
    .task {
      if sessionStore.sessions.isEmpty { await sessionStore.refreshSessions() }
    }
    .onAppear { sessionStore.subscribeToEvents() }
  }

  @ViewBuilder
  private var RootDetailView: some View {
    if sessionStore.selectedSession != nil {
      RootChatView
    } else {
      VStack(spacing: 16) {
        Image(systemName: "rectangle.and.hand.point.up.left")
          .font(.system(size: 48))
          .foregroundColor(.secondary)
        Text("选择一个会话查看详情")
          .foregroundColor(.secondary)
      }
    }
  }

  private var RootConnectionView: some View {
    NavigationStack {
      VStack(spacing: 20) {
        Image(systemName: "network")
          .font(.system(size: 48))
          .foregroundColor(.accentColor)
        Text("连接到 OpenCode")
          .font(.title2)

        TextField("服务器地址 (例如: 192.168.1.100:4096)", text: $connectionStore.serverURL)
          .textFieldStyle(.roundedBorder)
          .keyboardType(.URL)
        SecureField("认证令牌", text: $connectionStore.authToken)
          .textFieldStyle(.roundedBorder)

        if connectionStore.status == .error, let err = connectionStore.lastError {
          Text(err)
            .font(.caption)
            .foregroundColor(.red)
        }

        Button {
          Task { _ = await connectionStore.connect() }
        } label: {
          if connectionStore.status == .connecting {
            ProgressView()
          } else {
            Text("连接")
              .frame(maxWidth: .infinity)
          }
        }
        .buttonStyle(.borderedProminent)
        .disabled(connectionStore.status == .connecting)
      }
      .padding()
      .navigationTitle("OpenCode Remote")
    }
  }

  private var RootChatView: some View {
    VStack(spacing: 0) {
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack {
            ForEach(sessionStore.messages) { msg in
              RootMessageCardView(message: msg)
            }
          }
          .padding()
        }
        .onChange(of: sessionStore.messages.count) { _, _ in
          if let last = sessionStore.messages.last {
            proxy.scrollTo(last.id)
          }
        }
      }
      Divider()
      HStack {
        TextField("输入指令...", text: $input)
          .textFieldStyle(.roundedBorder)
        Button {
          let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !text.isEmpty else { return }
          input = ""
          Task { await sessionStore.sendMessage(text: text) }
        } label: {
          Image(systemName: "arrow.up.circle.fill")
            .font(.title2)
        }
        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if sessionStore.isSelectedSessionRunning {
          Button {
            Task { await sessionStore.abort() }
          } label: {
            Image(systemName: "stop.circle.fill")
              .font(.title2)
              .foregroundColor(.red)
          }
        }
      }
      .padding(.horizontal)
      .padding(.vertical, 8)
      .background(.bar)
    }
    .onDisappear {
      if UIDevice.current.userInterfaceIdiom != .pad {
        showingChat = false
      }
    }
  }
}

struct RootSessionRowView: View {
  let session: SessionInfo

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(session.title)
          .font(.headline)
          .lineLimit(1)
        Text(session.directory)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      Spacer()
      Text(Date(timeIntervalSince1970: session.time.updated / 1000).relativeDescription)
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .padding(.vertical, 4)
  }
}

struct RootMessageCardView: View {
  let message: MessageWithParts

  var body: some View {
    VStack(alignment: message.info.role == .user ? .trailing : .leading, spacing: 4) {
      Text(message.info.role == .user ? "你" : "OpenCode")
        .font(.caption)
        .foregroundColor(.secondary)
      ForEach(message.parts.indices, id: \.self) { idx in
        partView(message.parts[idx])
      }
    }
    .frame(maxWidth: .infinity, alignment: message.info.role == .user ? .trailing : .leading)
    .padding(.vertical, 4)
  }

  @ViewBuilder
  func partView(_ part: Part) -> some View {
    switch part {
    case .text(let p):
      Text(p.text).textSelection(.enabled)
    case .reasoning(let p):
      GroupBox("思考") { Text(p.text).font(.caption).textSelection(.enabled) }
    case .tool(let p):
      GroupBox("工具: \(p.tool)") {
        Text(p.state.statusText).font(.caption)
        if case .completed(let s) = p.state {
          Text(s.output)
            .font(.caption2.monospaced())
            .lineLimit(10)
            .textSelection(.enabled)
        }
      }
    case .stepFinish(let p):
      Text("消耗: ¥\(String(format: "%.4f", p.cost))")
        .font(.caption2)
        .foregroundColor(.secondary)
    case .file(let p):
      Label(p.filename ?? p.mime, systemImage: "doc")
    default:
      EmptyView()
    }
  }
}

extension Date {
  var relativeDescription: String {
    let interval = Date().timeIntervalSince(self)
    if interval < 60 { return "刚刚" }
    if interval < 3600 { return "\(Int(interval / 60))m" }
    if interval < 86400 { return "\(Int(interval / 3600))h" }
    return "\(Int(interval / 86400))d"
  }
}
