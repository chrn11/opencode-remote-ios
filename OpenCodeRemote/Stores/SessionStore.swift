// OpenCode Remote - 会话数据管理（Single Source of Truth）
// 创建时间：2026-04-29

import Foundation
import Combine
import SwiftUI

/// 唯一数据源，管理所有会话和消息
@MainActor
final class SessionStore: ObservableObject {
  @Published var sessions: [SessionInfo] = []
  @Published var sessionStatus: [SessionID: SessionStatusInfo] = [:]
  @Published var selectedSession: SessionInfo?
  @Published var messages: [MessageWithParts] = []
  @Published var isLoading = false
  @Published var error: String?

  // 分页
  private var nextCursor: String?
  @Published var hasMoreMessages = false

  // 去重
  private var seenKeys = Set<String>(minimumCapacity: 500)
  private let maxSeenKeys = 500

  // 权限
  @Published var pendingPermissions: [PermissionRequest] = []
  @Published var activeQuestions: [InteractQuestion] = []

  // 当前会话配置（用户可覆盖，发送消息时携带）
  @Published var reasoningEffort: String = "medium" // low / medium / high
  @Published var activeAgent: String = ""
  @Published var activeModel: String = ""
  @Published var activeVariant: String = ""

  // 可用 Provider/Model 列表（从服务器获取）
  @Published var providers: [ProviderInfo] = []
  @Published var providerDefaults: [String: String] = [:]
  @Published var connectedProviderIDs = Set<String>()
  @Published var globalConfig: GlobalConfig?
  @Published var providerLoadError: String?

  private let apiClient: OpenCodeAPIClient
  private let eventStreamClient: EventStreamClient
  private let connectionStore: ConnectionStore
  private var isSubscribed = false

  init(apiClient: OpenCodeAPIClient, eventStreamClient: EventStreamClient, connectionStore: ConnectionStore) {
    self.apiClient = apiClient
    self.eventStreamClient = eventStreamClient
    self.connectionStore = connectionStore
  }

  private func recordSeenKey(_ key: String) {
    seenKeys.insert(key)
    if seenKeys.count > maxSeenKeys {
      let sorted = seenKeys.sorted()
      seenKeys = Set(sorted.suffix(maxSeenKeys / 2))
    }
  }

  // MARK: - 会话

  func refreshSessions(search: String? = nil) async {
    isLoading = true; error = nil
    defer { isLoading = false }

    do {
      let fetched = try await apiClient.fetchSessions(limit: nil)
      if let search, !search.isEmpty {
        let keyword = search.lowercased()
        sessions = fetched.filter { session in
          session.title.lowercased().contains(keyword) || session.directory.lowercased().contains(keyword)
        }
      } else {
        sessions = fetched
      }
      let status = try await apiClient.fetchSessionStatus()
      sessionStatus = status.mapValues { SessionStatusInfo(status: $0.normalizedStatus, message: $0.message) }
    } catch {
      self.error = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }

    await refreshProviderConfigurationIfNeeded()
  }

  func refreshProviderConfigurationIfNeeded(force: Bool = false) async {
    guard force || providers.isEmpty || globalConfig == nil else {
      normalizeActiveSelections()
      return
    }

    do {
      async let providerResponse = apiClient.fetchProviders()
      async let configResponse = apiClient.fetchGlobalConfig()

      let (catalog, config) = try await (providerResponse, configResponse)
      providers = catalog.all.sorted { lhs, rhs in
        let lhsConnected = catalog.connected.contains(lhs.id)
        let rhsConnected = catalog.connected.contains(rhs.id)
        if lhsConnected != rhsConnected {
          return lhsConnected && !rhsConnected
        }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
      providerDefaults = catalog.defaultModels
      connectedProviderIDs = Set(catalog.connected)
      globalConfig = config
      providerLoadError = nil
      normalizeActiveSelections()
    } catch {
      providerLoadError = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
  }

  func selectSession(_ id: SessionID) async {
    isLoading = true; error = nil
    do {
      selectedSession = try await apiClient.fetchSession(id)
      // 加载第一页消息
      let result = try await apiClient.fetchMessages(sessionId: id, limit: 50)
      messages = result.messages
      nextCursor = result.nextCursor
      hasMoreMessages = result.nextCursor != nil

      // 加载待审批权限
      pendingPermissions = try await apiClient.fetchPermissions()
    } catch {
      self.error = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
    isLoading = false
  }

  func loadMoreMessages() async {
    guard let sid = selectedSession?.id, hasMoreMessages, let cursor = nextCursor else { return }
    do {
      let result = try await apiClient.fetchMessages(sessionId: sid, limit: 50, before: cursor)
      messages.insert(contentsOf: result.messages, at: 0)
      nextCursor = result.nextCursor
      hasMoreMessages = result.nextCursor != nil
    } catch {
      self.error = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
  }

  // MARK: - 操作

  func sendMessage(text: String) async {
    guard let sid = selectedSession?.id else { error = "未选择会话"; return }
    error = nil
    do {
      updateSessionStatus(sessionID: sid, status: "running")
      try await apiClient.sendPromptAsync(
        sessionId: sid, text: text,
        reasoningEffort: currentModelSupportsReasoning ? reasoningEffort : nil,
        agent: activeAgent.isEmpty ? nil : activeAgent,
        model: activeModel.isEmpty ? nil : activeModel,
        variant: activeVariant.isEmpty ? nil : activeVariant
      )
    } catch {
      updateSessionStatus(sessionID: sid, status: "error")
      self.error = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
  }

  /// 兼容旧调用：发送 Prompt
  func sendPrompt(message: String) async -> Bool {
    await sendMessage(text: message)
    return error == nil
  }

  func abort() async {
    guard let sid = selectedSession?.id else { error = "未选择会话"; return }
    error = nil
    do {
      _ = try await apiClient.abort(sessionId: sid)
      updateSessionStatus(sessionID: sid, status: "idle")
    }
    catch { self.error = (error as? NetworkError)?.errorDescription ?? error.localizedDescription }
  }

  // MARK: - 会话管理

  /// 创建新会话并导航
  func createSession(title: String? = nil, navigate: @escaping (String) -> Void) async {
    error = nil
    do {
      let detail = try await apiClient.createSession(title: title)
      await refreshSessions()
      navigate(detail.id)
    } catch {
      self.error = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
  }

  /// 删除会话
  func deleteSession(_ id: String) async {
    error = nil
    do {
      try await apiClient.deleteSession(id)
      sessions.removeAll { $0.id == id }
      if selectedSession?.id == id {
        selectedSession = nil
        messages = []
      }
    } catch {
      self.error = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
  }

  // MARK: - 权限

  func replyPermission(requestID: PermissionID, reply: PermissionReply) async {
    error = nil
    do {
      try await apiClient.replyPermission(requestID: requestID, body: PermissionReplyBody(reply: reply, message: nil))
      pendingPermissions.removeAll { $0.id == requestID }
    } catch {
      self.error = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
  }

  /// 回复交互式问题
  func respondToQuestion(questionID: String, answer: String) {
    activeQuestions.removeAll { $0.id == questionID }
  }

  /// 兼容旧调用：响应权限请求
  func respondToPermission(permissionId: String, action: PermissionAction, reason: String? = nil) async {
    let reply: PermissionReply
    switch action {
    case .allow:
      reply = .once
    case .allowAlways:
      reply = .always
    case .deny:
      reply = .reject
    case .ask:
      reply = .once
    }
    await replyPermission(requestID: permissionId, reply: reply)
  }

  // MARK: - SSE

  func subscribeToEvents() {
    guard !isSubscribed else { return }
    isSubscribed = true

    var urlString = connectionStore.serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
    if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
      urlString = "http://" + urlString
    }
    guard let url = URL(string: urlString) else {
      isSubscribed = false
      return
    }

    Task {
      await eventStreamClient.configure(baseURL: url, authToken: connectionStore.authToken) { [weak self] event in
        Task { @MainActor in self?.handleSSEEvent(event) }
      }
      await eventStreamClient.connect()
    }
  }

  func unsubscribeEvents() {
    guard isSubscribed else { return }
    isSubscribed = false
    Task { await eventStreamClient.disconnect() }
  }

  // MARK: - 事件处理

  private func handleSSEEvent(_ event: SSEEvent) {
    switch event {
    case .serverConnected, .serverHeartbeat:
      break

    case .sessionCreated(let id, let info):
      sessions.insert(info, at: 0)
      if sessionStatus[id] == nil {
        sessionStatus[id] = SessionStatusInfo(status: "idle")
      }
      recordSeenKey("sess-created-\(id)")

    case .sessionUpdated(let id, let info):
      if let idx = sessions.firstIndex(where: { $0.id == id }) { sessions[idx] = info }
      recordSeenKey("sess-updated-\(id)")

    case .sessionStatusUpdated(let id, let status):
      updateSessionStatus(sessionID: id, status: status.normalizedStatus, message: status.message)

    case .sessionDeleted(let id, _):
      sessions.removeAll { $0.id == id }
      sessionStatus.removeValue(forKey: id)

    case .messageUpdated(_, let info):
      if let idx = messages.firstIndex(where: { $0.id == info.id }) {
        // 保留现有 parts，更新 info
        messages[idx] = MessageWithParts(info: info, parts: messages[idx].parts)
      } else {
        messages.append(MessageWithParts(info: info, parts: []))
      }

    case .messageRemoved(_, let msgID):
      messages.removeAll { $0.id == msgID }

    case .messagePartUpdated(_, let part):
      // 通过 part 中内嵌的 messageID 定位消息，update 或 append
      let msgID: MessageID
      let partID: PartID
      switch part {
      case .text(let p):    msgID = p.messageID; partID = p.id
      case .tool(let p):    msgID = p.messageID; partID = p.id
      case .reasoning(let p): msgID = p.messageID; partID = p.id
      case .file(let p):    msgID = p.messageID; partID = p.id
      case .snapshot(let p): msgID = p.messageID; partID = p.id
      case .patch(let p):   msgID = p.messageID; partID = p.id
      case .agent(let p):   msgID = p.messageID; partID = p.id
      case .compaction(let p): msgID = p.messageID; partID = p.id
      case .subtask(let p): msgID = p.messageID; partID = p.id
      case .retry(let p):   msgID = p.messageID; partID = p.id
      case .stepStart(let p): msgID = p.messageID; partID = p.id
      case .stepFinish(let p): msgID = p.messageID; partID = p.id
      case .unknown: return
      }
      if let idx = messages.firstIndex(where: { $0.id == msgID }) {
        var parts = messages[idx].parts
        if let pIdx = parts.firstIndex(where: { $0.id == partID }) {
          parts[pIdx] = part
        } else {
          parts.append(part)
        }
        messages[idx] = MessageWithParts(info: messages[idx].info, parts: parts)
      }

    case .permissionAsked(let perm):
      pendingPermissions.append(perm)

    case .permissionReplied(_, let id, _):
      pendingPermissions.removeAll { $0.id == id }

    case .questionAsked(let q):
      activeQuestions.append(q)

    case .questionAnswered(let id, _):
      activeQuestions.removeAll { $0.id == id }

    case .unknown(let type, _):
      DebugLogger.shared.warn("sse_unknown_event", ["类型": type])
    }
  }
}

extension SessionStore {
  var selectedProviderID: String? {
    activeModel.split(separator: "/", maxSplits: 1).first.map(String.init)
  }

  var selectedModelID: String? {
    let components = activeModel.split(separator: "/", maxSplits: 1).map(String.init)
    guard components.count == 2 else { return nil }
    return components[1]
  }

  var selectedProvider: ProviderInfo? {
    guard let selectedProviderID else { return nil }
    return providers.first(where: { $0.id == selectedProviderID })
  }

  var selectedModelInfo: ModelInfo? {
    guard let selectedProvider, let selectedModelID else { return nil }
    return selectedProvider.models[selectedModelID]
  }

  var currentModelSupportsReasoning: Bool {
    // 1. 服务器显式标记支持推理
    if selectedModelInfo?.supportsReasoning == true {
      return true
    }
    let normalized = activeModel.lowercased()
    // 2. 排除已知不支持推理的模型类型
    if normalized.contains("embed") || normalized.contains("whisper") || normalized.contains("tts") {
      return false
    }
    // 3. 模型名包含推理相关关键词
    if normalized.contains("reasoning") || normalized.contains("thinking") || normalized.contains("r1") {
      return true
    }
    // 4. 默认：不假设模型支持推理
    return false
  }

  /// 可用 Agent 列表（从全局配置读取）
  var availableAgents: [String] {
    guard let agentMap = globalConfig?.agent else { return [] }
    return Array(agentMap.keys).sorted()
  }

  /// 当前 Agent 显示名称
  var activeAgentDisplayName: String {
    activeAgent.isEmpty ? (globalConfig?.defaultAgent ?? "默认") : activeAgent
  }

  var currentModelSupportsAttachments: Bool {
    selectedModelInfo?.supportsAttachments == true
  }

  var activeModelDisplayName: String {
    guard let selectedModelInfo else {
      return activeModel.isEmpty ? "默认模型" : activeModel
    }
    return selectedModelInfo.displayName
  }

  var activeProviderDisplayName: String? {
    selectedProvider?.name
  }

  func setActiveProvider(_ providerID: String) {
    guard let provider = providers.first(where: { $0.id == providerID }) else { return }
    let preferredModelID = preferredModelID(for: provider)
      ?? provider.sortedModels.first?.id
    if let preferredModelID {
      setActiveModel(providerID: providerID, modelID: preferredModelID)
    }
  }

  func setActiveModel(providerID: String, modelID: String) {
    activeModel = "\(providerID)/\(modelID)"
    if !currentModelSupportsReasoning {
      reasoningEffort = "medium"
    }
  }

  /// 会话状态摘要
  func statusForSession(_ id: SessionID) -> String {
    sessionStatus[id]?.normalizedStatus ?? "idle"
  }

  var isSelectedSessionRunning: Bool {
    guard let sid = selectedSession?.id else { return false }
    let st = sessionStatus[sid]?.normalizedStatus ?? "idle"
    return st == "running" || st == "thinking" || st == "retry"
  }

  private func normalizeActiveSelections() {
    if activeModel.isEmpty, let defaultModel = globalConfig?.model, isValidModelIdentifier(defaultModel) {
      activeModel = defaultModel
    }

    if activeModel.isEmpty || !isValidModelIdentifier(activeModel) {
      activeModel = firstAvailableModelIdentifier() ?? activeModel
    }

    if let providerID = selectedProviderID, let modelID = selectedModelID,
       providers.first(where: { $0.id == providerID })?.models[modelID] == nil {
      setActiveProvider(providerID)
    }

    if !currentModelSupportsReasoning {
      reasoningEffort = "medium"
    }
  }

  private func isValidModelIdentifier(_ identifier: String) -> Bool {
    let parts = identifier.split(separator: "/", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { return false }
    return providers.first(where: { $0.id == parts[0] })?.models[parts[1]] != nil
  }

  private func preferredModelID(for provider: ProviderInfo) -> String? {
    if let modelID = providerDefaults[provider.id], provider.models[modelID] != nil {
      return modelID
    }
    if let globalModel = globalConfig?.model {
      let parts = globalModel.split(separator: "/", maxSplits: 1).map(String.init)
      if parts.count == 2, parts[0] == provider.id, provider.models[parts[1]] != nil {
        return parts[1]
      }
    }
    return nil
  }

  private func firstAvailableModelIdentifier() -> String? {
    for provider in providers {
      if let preferred = preferredModelID(for: provider) {
        return "\(provider.id)/\(preferred)"
      }
      if let first = provider.sortedModels.first?.id {
        return "\(provider.id)/\(first)"
      }
    }
    return nil
  }

  private func updateSessionStatus(sessionID: SessionID, status: String, message: String? = nil) {
    let info = SessionStatusInfo(status: status, message: message)
    sessionStatus[sessionID] = SessionStatusInfo(status: info.normalizedStatus, message: message)
  }
}
