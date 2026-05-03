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
      sessionStatus = status
    } catch {
      self.error = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
    }
    isLoading = false
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
      let requestID = UUID().uuidString
      try await apiClient.sendPromptAsync(sessionId: sid, text: text, requestId: requestID)
    } catch {
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
    do { _ = try await apiClient.abort(sessionId: sid) }
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
      recordSeenKey("sess-created-\(id)")

    case .sessionUpdated(let id, let info):
      if let idx = sessions.firstIndex(where: { $0.id == id }) { sessions[idx] = info }
      recordSeenKey("sess-updated-\(id)")

    case .sessionDeleted(let id, _):
      sessions.removeAll { $0.id == id }

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
  /// 会话状态摘要
  func statusForSession(_ id: SessionID) -> String {
    sessionStatus[id]?.status ?? "idle"
  }

  var isSelectedSessionRunning: Bool {
    guard let sid = selectedSession?.id else { return false }
    let st = sessionStatus[sid]?.status ?? "idle"
    return st == "running" || st == "thinking"
  }
}
