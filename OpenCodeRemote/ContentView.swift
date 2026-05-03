// OpenCode Remote - 根视图路由
// 对齐 OpenCode 源码 app.tsx + home.tsx + session.tsx
// 创建时间：2026-04-29

import SwiftUI

struct ContentView: View {
  @EnvironmentObject var conn: ConnectionStore
  @EnvironmentObject var store: SessionStore
  @State private var path = NavigationPath()

  var body: some View {
    if conn.status == .connected {
      NavigationStack(path: $path) {
        HomeScreen()
          .navigationDestination(for: String.self) { sessionId in
            ChatScreen()
              .task {
                if store.selectedSession?.id != sessionId {
                  await store.selectSession(sessionId)
                }
              }
          }
      }
      .onChange(of: conn.status) { _, status in
        if status != .connected {
          path = NavigationPath()
        }
      }
    } else {
      NavigationStack {
        ConnectScreen()
      }
    }
  }
}

// MARK: - 连接页面

struct ConnectScreen: View {
  @EnvironmentObject var conn: ConnectionStore
  @EnvironmentObject var store: SessionStore

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      // Logo
      Text("OpenCode")
        .font(.system(size: 36, weight: .bold, design: .rounded))
        .foregroundStyle(.secondary.opacity(0.3))

      // 表单
      VStack(spacing: 12) {
        TextField("服务器地址 (192.168.1.4:4096)", text: $conn.serverURL)
          .textFieldStyle(.roundedBorder)
          .keyboardType(.URL)
          .autocapitalization(.none)
        SecureField("密码", text: $conn.authToken)
          .textFieldStyle(.roundedBorder)
      }
      .padding(.horizontal, 32)

      // 错误
      if conn.status == .error, let err = conn.lastError {
        Text(err)
          .font(.caption)
          .foregroundColor(.red)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)
      }

      // 连接按钮
      Button {
        Task {
          if await conn.connect() {
            await store.refreshSessions()
          }
        }
      } label: {
        Group {
          if conn.status == .connecting {
            ProgressView().tint(.white)
          } else {
            Text("连接").frame(maxWidth: .infinity)
          }
        }
        .padding(.vertical, 10)
      }
      .buttonStyle(.borderedProminent)
      .disabled(conn.status == .connecting)
      .padding(.horizontal, 32)

      Spacer()
    }
    .navigationTitle("OpenCode Remote")
  }
}

// MARK: - 首页（对齐 home.tsx）

struct HomeScreen: View {
  @EnvironmentObject var conn: ConnectionStore
  @EnvironmentObject var store: SessionStore
  @State private var searchText = ""

  var body: some View {
    VStack(spacing: 0) {
      TextField("搜索会话", text: $searchText)
        .textFieldStyle(.roundedBorder)
        .padding(.horizontal, 20)
        .padding(.top, 20)

      // Logo 区
      Text("OpenCode")
        .font(.system(size: 56, weight: .bold, design: .rounded))
        .foregroundStyle(.secondary.opacity(0.12))
        .padding(.top, 80)

      // 服务器状态
      Button {
        // 服务器选择器（暂未实现）
      } label: {
        HStack(spacing: 6) {
          Circle()
            .fill(conn.status == .connected ? Color.green : Color.gray)
            .frame(width: 8, height: 8)
          Text(conn.serverInfo?.url ?? conn.serverURL)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .padding(.top, 8)

      // 会话列表（对齐 source 中 recent projects）
      if store.sessions.isEmpty && !store.isLoading {
        emptyState
          .padding(.top, 60)
      } else {
        sessionList
          .padding(.top, 40)
      }
    }
    .refreshable { await store.refreshSessions() }
    .task {
      if store.sessions.isEmpty { await store.refreshSessions() }
    }
    .onAppear { store.subscribeToEvents() }
    .onDisappear { store.unsubscribeEvents() }
  }

  // 对齐 home.tsx empty state
  private var emptyState: some View {
    VStack(spacing: 12) {
      Image(systemName: "folder.badge.plus")
        .font(.system(size: 40))
        .foregroundColor(.secondary)
      Text("暂无会话")
        .font(.headline)
        .foregroundColor(.secondary)
      Text("在终端启动 OpenCode 后，会话将显示在这里")
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  // 对齐 home.tsx 项目列表
  private var sessionList: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(store.sessions.prefix(20)) { session in
          NavigationLink(value: session.id) {
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                  .font(.system(.body, design: .monospaced))
                  .lineLimit(1)
                  .foregroundColor(.primary)
                Text(session.directory)
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
              Spacer()
              Text(Date(timeIntervalSince1970: session.time.updated / 1000).rel)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
          }
          Divider().padding(.leading, 20)
        }
      }
    }
  }
}

// MARK: - 聊天页面（对齐 session.tsx）

struct ChatScreen: View {
  @EnvironmentObject var store: SessionStore
  @State private var input = ""
  @FocusState private var focused: Bool

  enum ActiveSheet: Identifiable {
    case permission(PermissionRequest)
    case question(InteractQuestion)
    var id: String {
      switch self {
      case .permission(let r): return "perm-\(r.id)"
      case .question(let q): return "q-\(q.id)"
      }
    }
  }

  private var activeSheet: ActiveSheet? {
    if let perm = store.pendingPermissions.first {
      return .permission(perm)
    }
    if let question = store.activeQuestions.first {
      return .question(question)
    }
    return nil
  }

  var body: some View {
    VStack(spacing: 0) {
      // 消息时间线
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(store.messages) { msg in
              MessageRow(msg: msg)
                .id(msg.id)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
          }
        }
        .onChange(of: store.messages.count) { _, _ in
          if !store.messages.isEmpty {
            proxy.scrollTo(store.messages.last!.id, anchor: .bottom)
          }
        }
        .gesture(
          DragGesture().onChanged { _ in }
            .onEnded { _ in }
        )
      }

      Divider()

      // 底部输入区
      VStack(spacing: 6) {
        // 状态行
        if let session = store.selectedSession {
          HStack(spacing: 6) {
            statusIcon(store.statusForSession(session.id))
            Text(statusText(store.statusForSession(session.id)))
              .font(.caption)
              .foregroundColor(.secondary)
            Spacer()
            if store.isSelectedSessionRunning {
              Button { Task { await store.abort() } } label: {
                Image(systemName: "stop.circle.fill")
                  .foregroundColor(.red)
                  .font(.title3)
              }
            }
          }
          .padding(.horizontal, 16)
        }

        // 输入框
        HStack(spacing: 8) {
          TextField("输入指令...", text: $input, axis: .vertical)
            .focused($focused)
            .lineLimit(1...4)

          Button {
            let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            input = ""
            Task { await store.sendMessage(text: t) }
          } label: {
            Image(systemName: "arrow.up.circle.fill")
              .font(.title2)
              .foregroundColor(input.isEmpty ? .secondary : .accentColor)
          }
          .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(20)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
      }
      .padding(.vertical, 4)
      .background(.bar)
    }
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text(store.selectedSession?.title ?? "会话")
          .font(.headline)
          .lineLimit(1)
      }
    }
    .onDisappear {
      store.selectedSession = nil
    }
    .sheet(item: Binding<ActiveSheet?>(
      get: {
        if let perm = store.pendingPermissions.first { return .permission(perm) }
        if let q = store.activeQuestions.first { return .question(q) }
        return nil
      },
      set: { _ in }
    )) { sheet in
      switch sheet {
      case .permission(let request):
        PermissionSheet(request: request) { reply in
          Task { await store.replyPermission(requestID: request.id, reply: reply) }
        }
      case .question(let question):
        QuestionSheet(question: question) { answer in
          store.respondToQuestion(questionID: question.id, answer: answer)
        }
      }
    }
  }

  private func statusIcon(_ status: String) -> some View {
    switch status {
    case "running": return Image(systemName: "play.circle.fill").foregroundColor(.green)
    case "thinking": return Image(systemName: "brain.head.profile").foregroundColor(.orange)
    default: return Image(systemName: "circle").foregroundColor(.secondary)
    }
  }

  private func statusText(_ s: String) -> String {
    switch s { case "running": "运行中"; case "thinking": "思考中"; default: "空闲" }
  }
}

// MARK: - 消息行（对齐 MessageTimeline）

struct MessageRow: View {
  let msg: MessageWithParts

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      // 角色标签
      HStack {
        Text(roleLabel)
          .font(.caption)
          .foregroundColor(.secondary)
        Spacer()
      }

      // Parts
      ForEach(msg.parts.indices, id: \.self) { i in
        partView(msg.parts[i])
      }

      // 错误
      if case .assistant(let a) = msg.info, let err = a.error {
        Text(err.displayMessage)
          .font(.caption)
          .foregroundColor(.red)
          .padding(8)
          .background(Color.red.opacity(0.08))
          .cornerRadius(8)
      }
    }
    .padding(12)
    .background(msg.info.role == .user
      ? Color.accentColor.opacity(0.06)
      : Color(.secondarySystemGroupedBackground))
    .cornerRadius(12)
    .contextMenu {
      if let text = msgText() {
        Button { UIPasteboard.general.string = text } label: {
          Label("复制", systemImage: "doc.on.doc")
        }
      }
    }
  }

  @ViewBuilder
  private func partView(_ p: Part) -> some View {
    switch p {
    case .text(let t):
      Text(t.text)
        .textSelection(.enabled)

    case .reasoning(let r):
      DisclosureGroup("思考过程") {
        Text(r.text)
          .font(.caption)
          .textSelection(.enabled)
      }
      .font(.caption)

    case .tool(let t):
      toolCallView(t)

    case .stepStart:
      EmptyView()

    case .stepFinish(let f):
      Text("\(String(format: "%.0f", f.tokens.input))→\(String(format: "%.0f", f.tokens.output)) tokens · ¥\(String(format: "%.4f", f.cost))")
        .font(.caption2)
        .foregroundColor(.secondary)

    case .file(let f):
      Label(f.filename ?? f.url, systemImage: "doc")

    default:
      EmptyView()
    }
  }

  @ViewBuilder
  private func toolCallView(_ t: ToolPart) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Image(systemName: t.tool == "bash" ? "terminal" : "wrench")
          .font(.caption)
        Text(t.tool)
          .font(.caption.bold())
        Spacer()
        Text(t.state.statusText)
          .font(.caption2)
          .foregroundColor(statusColor(t.state))
      }

      if case .completed(let s) = t.state, !s.output.isEmpty {
        Text(s.output)
          .font(.caption2.monospaced())
          .lineLimit(8)
          .textSelection(.enabled)
      }
      if case .error(let s) = t.state {
        Text(s.error)
          .font(.caption2)
          .foregroundColor(.red)
          .lineLimit(4)
      }
    }
    .padding(8)
    .background(Color(.systemGray6))
    .cornerRadius(8)
  }

  private func statusColor(_ s: ToolState) -> Color {
    switch s { case .pending: .secondary; case .running: .orange; case .completed: .green; case .error: .red }
  }

  private var roleLabel: String {
    switch msg.info.role { case .user: "你"; case .assistant: "OpenCode" }
  }

  private func msgText() -> String? {
    msg.parts.compactMap { p in
      switch p {
      case .text(let t): return t.text
      case .reasoning(let r): return r.text
      default: return nil
      }
    }.joined(separator: "\n").nilIfEmpty
  }
}

// MARK: - 工具

extension Date {
  var rel: String {
    let d = Date().timeIntervalSince(self)
    if d < 60 { return "刚刚" }
    if d < 3600 { return "\(Int(d/60))m" }
    if d < 86400 { return "\(Int(d/3600))h" }
    return "\(Int(d/86400))d"
  }
}

extension String {
  var nilIfEmpty: String? { isEmpty ? nil : self }
}
