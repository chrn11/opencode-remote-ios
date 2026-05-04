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
        HomeScreen(path: $path)
          .navigationDestination(for: String.self) { sessionId in
            ChatScreen()
              .task {
                if store.selectedSession?.id != sessionId {
                  await store.selectSession(sessionId)
                }
              }
          }
      }
      .onChange(of: conn.status) { status in
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

      if conn.status == .connecting || conn.connectionHint != nil {
        HStack(spacing: 8) {
          if conn.status == .connecting {
            ProgressView()
              .scaleEffect(0.85)
          }
          Text(conn.connectionHint ?? "连接前会自动等待网络恢复")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
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
  @Binding var path: NavigationPath
  @State private var searchText = ""
  @State private var showSettings = false

  /// 过滤后的会话列表
  private var filteredSessions: [SessionInfo] {
    guard !searchText.isEmpty else { return store.sessions }
    let keyword = searchText.lowercased()
    return store.sessions.filter {
      $0.title.lowercased().contains(keyword) || $0.directory.lowercased().contains(keyword)
    }
  }

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
      HStack(spacing: 6) {
        Circle()
          .fill(conn.status == .connected ? Color.green : Color.gray)
          .frame(width: 8, height: 8)
        Text(conn.serverInfo?.url ?? conn.serverURL)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.top, 8)

      // 会话列表（对齐 source 中 recent projects）
      if filteredSessions.isEmpty && !store.isLoading {
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
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button {
          showSettings = true
        } label: {
          Image(systemName: AppIcons.settings)
        }
      }
      ToolbarItem(placement: .navigationBarTrailing) {
        Button {
          Task {
            await store.createSession { sessionId in
              path.append(sessionId)
            }
          }
        } label: {
          Image(systemName: "plus.circle.fill")
        }
      }
    }
    .sheet(isPresented: $showSettings) {
      SettingsScreen()
    }
    .navigationTitle("OpenCode")
    .navigationBarTitleDisplayMode(.inline)
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
        ForEach(Array(filteredSessions.prefix(50))) { session in
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
          .contextMenu {
            Button(role: .destructive) {
              Task { await store.deleteSession(session.id) }
            } label: {
              Label("删除会话", systemImage: "trash")
            }
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
  @State private var isLoadingMore = false
  @FocusState private var focused: Bool
  @State private var showConfigSheet = false

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
            // 加载更多按钮
            if store.hasMoreMessages {
              Button {
                isLoadingMore = true
                Task {
                  await store.loadMoreMessages()
                  isLoadingMore = false
                }
              } label: {
                if isLoadingMore {
                  ProgressView()
                    .padding(.vertical, 12)
                } else {
                  Text("加载更多消息")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
                }
              }
              .id("load-more")
            }

            ForEach(store.messages) { msg in
              MessageRow(msg: msg)
                .id(msg.id)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
          }
        }
        .task {
          // 打开会话后滚动到最底部
          try? await Task.sleep(nanoseconds: 300_000_000)
          withAnimation {
            if let last = store.messages.last {
              proxy.scrollTo(last.id, anchor: .bottom)
            }
          }
        }
        .onChange(of: store.messages.count) { _ in
          if !store.messages.isEmpty {
            proxy.scrollTo(store.messages.last!.id, anchor: .bottom)
          }
        }
      }

      Divider()

      // 底部输入区
      VStack(spacing: 6) {
        // 错误提示
        if let error = store.error {
          HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundColor(.red)
              .font(.caption)
            Text(error)
              .font(.caption)
              .foregroundColor(.red)
              .lineLimit(2)
            Spacer()
            Button { store.error = nil } label: {
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red.opacity(0.6))
                .font(.caption)
            }
          }
          .padding(.horizontal, 16)
        }

        // 状态行
        if let session = store.selectedSession {
          HStack(spacing: 6) {
            statusIcon(store.statusForSession(session.id))
            Text(statusText(store.statusForSession(session.id)))
              .font(.caption)
              .foregroundColor(.secondary)
            Spacer()
            // Thinking Level 选择器
            if store.currentModelSupportsReasoning {
              HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                  .font(.caption2)
                  .foregroundColor(.secondary)
                Picker("思考程度", selection: $store.reasoningEffort) {
                  Text("低").tag("low")
                  Text("中").tag("medium")
                  Text("高").tag("high")
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
              }
            }
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

        // 底部配置栏（对齐 OpenCode TUI 风格：Agent · Provider/Model · Thinking Level）
        HStack(spacing: 16) {
          // Agent 选择器
          Menu {
            if !store.availableAgents.isEmpty {
              ForEach(store.availableAgents) { agent in
                Button {
                  store.activeAgent = agent.name
                } label: {
                  HStack {
                    Text(agent.name)
                    if let desc = agent.description, !desc.isEmpty {
                      Text("— \(desc)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                  }
                }
              }
            } else {
              Text("加载中…")
            }
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "person.crop.circle")
                .font(.caption2)
                .foregroundColor(.accentColor)
              Text(store.activeAgentDisplayName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
              Image(systemName: "chevron.down")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
            }
          }

          Divider().frame(height: 12)

          // Provider/Model 选择器（打开配置面板）
          Button { showConfigSheet = true } label: {
            HStack(spacing: 4) {
              Image(systemName: "cpu")
                .font(.caption2)
                .foregroundColor(.accentColor)
              Text(store.activeModelDisplayName)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
              Image(systemName: "chevron.up")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.6))
            }
          }
          .buttonStyle(.plain)

          Divider().frame(height: 12)

          // Thinking Level 选择器（仅支持推理的模型显示）
          if store.currentModelSupportsReasoning {
            Menu {
              Button("低") { store.reasoningEffort = "low" }
              Button("中") { store.reasoningEffort = "medium" }
              Button("高") { store.reasoningEffort = "high" }
            } label: {
              HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                  .font(.caption2)
                  .foregroundColor(.orange)
                Text(store.reasoningEffort == "low" ? "低" : store.reasoningEffort == "high" ? "高" : "中")
                  .font(.caption2)
                  .foregroundColor(.secondary)
                Image(systemName: "chevron.down")
                  .font(.caption2)
                  .foregroundColor(.secondary.opacity(0.6))
              }
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)

        // 状态行 + 中止按钮
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
    .sheet(isPresented: $showConfigSheet) {
      ConfigSheet()
        .environmentObject(store)
    }
  }

  private func statusIcon(_ status: String) -> some View {
    switch status {
    case "running": return Image(systemName: "play.circle.fill").foregroundColor(.green)
    case "thinking": return Image(systemName: "brain.head.profile").foregroundColor(.orange)
    case "error": return Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
    case "retry": return Image(systemName: "arrow.clockwise.circle.fill").foregroundColor(.yellow)
    default: return Image(systemName: "circle").foregroundColor(.secondary)
    }
  }

  private func statusText(_ s: String) -> String {
    switch s {
    case "running": "运行中"
    case "thinking": "思考中"
    case "error": "错误"
    case "retry": "重试中"
    default: "空闲"
    }
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
      Text(MarkdownRenderer.render(t.text))
        .textSelection(.enabled)

    case .reasoning(let r):
      DisclosureGroup("思考过程") {
        Text(MarkdownRenderer.render(r.text))
          .font(.caption)
          .italic()
          .foregroundColor(.secondary)
          .padding(.leading, 8)
          .padding(.vertical, 4)
      }
      .font(.caption)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color(.systemGray5))
      .overlay(
        Rectangle()
          .fill(Color.accentColor)
          .frame(width: 3)
          .padding(.vertical, 0)
        , alignment: .leading
      )
      .cornerRadius(8)
      .padding(.leading, 2)

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

    case .snapshot(let s):
      VStack(alignment: .leading, spacing: 2) {
        Label("快照", systemImage: "camera")
          .font(.caption.bold())
        Text(s.snapshot.prefix(100))
          .font(.caption2.monospaced())
          .lineLimit(3)
          .foregroundColor(.secondary)
      }
      .padding(6)
      .background(Color(.systemGray6))
      .cornerRadius(6)

    case .patch(let p):
      VStack(alignment: .leading, spacing: 2) {
        Label("补丁 \(p.hash)", systemImage: "doc.text")
          .font(.caption.bold())
        ForEach(p.files.prefix(5), id: \.self) { file in
          Text(file)
            .font(.caption2.monospaced())
            .foregroundColor(.secondary)
        }
        if p.files.count > 5 {
          Text("…还有 \(p.files.count - 5) 个文件")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
      .padding(6)
      .background(Color(.systemGray6))
      .cornerRadius(6)

    case .agent(let a):
      HStack(spacing: 4) {
        Image(systemName: "person.crop.circle")
          .font(.caption)
        Text(a.name)
          .font(.caption.bold())
      }
      .padding(.vertical, 2)
      .padding(.horizontal, 8)
      .background(Color.accentColor.opacity(0.12))
      .cornerRadius(10)

    case .compaction(let c):
      HStack(spacing: 4) {
        Image(systemName: "arrow.triangle.2.circlepath")
          .font(.caption2)
        Text(c.auto ? "自动压缩" : "手动压缩")
          .font(.caption2)
        if c.overflow == true {
          Text("(溢出)")
            .font(.caption2)
            .foregroundColor(.orange)
        }
      }
      .foregroundColor(.secondary)
      .padding(.vertical, 2)

    case .subtask(let s):
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Image(systemName: "arrowshape.turn.down.right")
            .font(.caption2)
          Text(s.description)
            .font(.caption.bold())
            .lineLimit(1)
        }
        Text(s.agent)
          .font(.caption2)
          .foregroundColor(.secondary)
        if let model = s.model {
          Text("\(model.providerID)/\(model.modelID)")
            .font(.caption2.monospaced())
            .foregroundColor(.secondary)
        }
      }
      .padding(6)
      .background(Color(.systemGray6))
      .cornerRadius(6)

    case .retry(let r):
      HStack(spacing: 4) {
        Image(systemName: "arrow.clockwise")
          .font(.caption2)
          .foregroundColor(.orange)
        Text("第 \(r.attempt) 次重试")
          .font(.caption2)
          .foregroundColor(.orange)
      }
      .padding(.vertical, 2)

    case .unknown(let u):
      Text("[未知类型: \(u.rawType)]")
        .font(.caption2)
        .foregroundColor(.secondary)
        .italic()
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
        if looksLikeDiff(s.output) {
          DiffView(text: s.output)
        } else {
          Text(s.output)
            .font(.caption2.monospaced())
            .lineLimit(8)
            .textSelection(.enabled)
        }
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
    let texts = msg.parts.compactMap { p in
      switch p {
      case .text(let t): return t.text
      case .reasoning(let r): return r.text
      default: return nil
      }
    }
    let joined = texts.joined(separator: "\n")
    return joined.isEmpty ? nil : joined
  }

  /// 检测输出是否包含 unified diff 格式
  private func looksLikeDiff(_ text: String) -> Bool {
    text.contains("@@ -") && text.contains("+") && text.contains("-")
  }
}

// MARK: - 配置面板（对齐 OpenCode TUI 的 DialogModel/DialogAgent/DialogVariant）

struct ConfigSheet: View {
  @EnvironmentObject var store: SessionStore
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      Form {
        Section("模型") {
          if store.providers.isEmpty {
            if let providerLoadError = store.providerLoadError {
              VStack(alignment: .leading, spacing: 6) {
                Text("模型列表加载失败")
                  .font(.subheadline.weight(.medium))
                Text(providerLoadError)
                  .font(.caption)
                  .foregroundColor(.secondary)
                Button("重新加载") {
                  Task { await store.refreshProviderConfigurationIfNeeded(force: true) }
                }
              }
            } else {
              HStack(spacing: 10) {
                ProgressView()
                Text("正在加载 Provider 与模型列表…")
                  .font(.subheadline)
              }
            }
          } else {
            Picker("Provider", selection: Binding(
              get: { store.selectedProviderID ?? store.providers.first?.id ?? "" },
              set: { store.setActiveProvider($0) }
            )) {
              ForEach(store.providers) { provider in
                Text(store.connectedProviderIDs.contains(provider.id) ? "\(provider.name) · 已连接" : provider.name)
                  .tag(provider.id)
              }
            }

            if let provider = store.selectedProvider {
              Picker("模型", selection: Binding(
                get: { store.selectedModelID ?? provider.sortedModels.first?.id ?? "" },
                set: { store.setActiveModel(providerID: provider.id, modelID: $0) }
              )) {
                ForEach(provider.sortedModels, id: \.id) { model in
                  Text(model.info.displayName).tag(model.id)
                }
              }

              if let selectedModelInfo = store.selectedModelInfo, let selectedModelID = store.selectedModelID {
                VStack(alignment: .leading, spacing: 4) {
                  Text("当前模型: \(selectedModelID)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                  HStack(spacing: 10) {
                    if let contextWindow = selectedModelInfo.contextWindow {
                      Text("上下文 \(contextWindow)")
                    }
                    if selectedModelInfo.supportsReasoning {
                      Text("支持推理")
                    }
                    if selectedModelInfo.supportsAttachments {
                      Text("支持附件")
                    }
                  }
                  .font(.caption2)
                  .foregroundColor(.secondary)
                }
              }
            }
          }

          if let defaultModel = store.globalConfig?.model {
            Text("服务器默认: \(defaultModel)")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }

        if store.currentModelSupportsReasoning {
          Section("思考程度") {
            Picker("思考程度", selection: $store.reasoningEffort) {
              Text("低").tag("low")
              Text("中").tag("medium")
              Text("高").tag("high")
            }
            .pickerStyle(.segmented)
          }
        } else {
          Section("思考程度") {
            Label("当前模型不支持推理强度调整", systemImage: "info.circle")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }
      .task {
        await store.refreshProviderConfigurationIfNeeded()
      }
      .navigationTitle("发送配置")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") { dismiss() }
        }
      }
    }
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
