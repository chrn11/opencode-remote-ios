// OpenCode Remote - SSE 事件类型与解析器
// 创建时间：2026-04-29

import Foundation

/// 交互问题（/question 路由）
struct InteractQuestion: Codable, Identifiable, Sendable {
  let id: String
  let sessionID: String
  let header: String
  let question: String
  let options: [QuestionOption]
}

struct QuestionOption: Codable, Sendable {
  let label: String
  let description: String?
}

/// SSE 事件（单行 JSON）
enum SSEEvent: Sendable {
  case serverConnected
  case serverHeartbeat

  case sessionCreated(sessionID: String, info: SessionInfo)
  case sessionUpdated(sessionID: String, info: SessionInfo)
  case sessionStatusUpdated(sessionID: String, status: SessionStatusInfo)
  case sessionDeleted(sessionID: String, info: SessionInfo)

  case messageUpdated(sessionID: String, info: MessageInfo)
  case messageRemoved(sessionID: String, messageID: String)
  case messagePartUpdated(sessionID: String, part: MessagePart)

  case permissionAsked(PermissionRequest)
  case permissionReplied(sessionID: String, requestID: String, reply: PermissionReply)

  case questionAsked(question: InteractQuestion)
  case questionAnswered(questionID: String, answer: String)

  case unknown(type: String, raw: [String: CodableValue])
}

/// SSE 事件解析器（单行 JSON）
actor SSEEventParser {
  static let shared = SSEEventParser()

  private let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.keyDecodingStrategy = .convertFromSnakeCase
    return d
  }()

  func parse(dataLine: String) -> SSEEvent? {
    let line = dataLine.hasPrefix("data: ") ? String(dataLine.dropFirst(6)) : dataLine
    guard let data = line.data(using: .utf8),
          let envelope = try? decoder.decode(SSEEnvelope.self, from: data) else {
      DebugLogger.shared.error("sse_parse", ["错误": "无效JSON", "行": String(line.prefix(200))])
      return nil
    }

    switch envelope.type {
    case "server.connected":
      return .serverConnected
    case "server.heartbeat":
      return .serverHeartbeat

    case "session.created":
      guard let sid = envelope.properties?["sessionID"]?.stringValue,
            let info = decode(SessionInfo.self, envelope.properties?["info"]) else { return nil }
      return .sessionCreated(sessionID: sid, info: info)

    case "session.updated":
      guard let sid = envelope.properties?["sessionID"]?.stringValue,
            let info = decode(SessionInfo.self, envelope.properties?["info"]) else { return nil }
      return .sessionUpdated(sessionID: sid, info: info)

    case "session.status.updated":
      guard let sid = sessionIdentifier(from: envelope.properties),
            let status = decodeStatus(from: envelope.properties) else { return nil }
      return .sessionStatusUpdated(sessionID: sid, status: status)

    case "session.deleted":
      guard let sid = envelope.properties?["sessionID"]?.stringValue,
            let info = decode(SessionInfo.self, envelope.properties?["info"]) else { return nil }
      return .sessionDeleted(sessionID: sid, info: info)

    case "message.updated":
      guard let sid = envelope.properties?["sessionID"]?.stringValue,
            let info = decode(MessageInfo.self, envelope.properties?["info"]) else { return nil }
      return .messageUpdated(sessionID: sid, info: info)

    case "message.removed":
      guard let sid = envelope.properties?["sessionID"]?.stringValue,
            let mid = envelope.properties?["messageID"]?.stringValue else { return nil }
      return .messageRemoved(sessionID: sid, messageID: mid)

    case "message.part.updated":
      guard let sid = envelope.properties?["sessionID"]?.stringValue,
            let part = decode(MessagePart.self, envelope.properties?["part"]) else { return nil }
      return .messagePartUpdated(sessionID: sid, part: part)

    case "permission.asked":
      guard let perm = decode(PermissionRequest.self, envelope.properties) else { return nil }
      return .permissionAsked(perm)

    case "permission.replied":
      guard let sid = envelope.properties?["sessionID"]?.stringValue,
            let rid = envelope.properties?["requestID"]?.stringValue,
            let raw = envelope.properties?["reply"]?.stringValue,
            let reply = PermissionReply(rawValue: raw) else { return nil }
      return .permissionReplied(sessionID: sid, requestID: rid, reply: reply)

    case "question.asked":
      guard let q = decode(InteractQuestion.self, envelope.properties) else { return nil }
      return .questionAsked(question: q)

    case "question.answered":
      guard let qid = envelope.properties?["questionID"]?.stringValue,
            let answer = envelope.properties?["answer"]?.stringValue else { return nil }
      return .questionAnswered(questionID: qid, answer: answer)

    default:
      if let statusEvent = parseSessionStateEvent(type: envelope.type, properties: envelope.properties) {
        return statusEvent
      }
      return .unknown(type: envelope.type, raw: envelope.properties ?? [:])
    }
  }

  private func parseSessionStateEvent(type: String, properties: [String: CodableValue]?) -> SSEEvent? {
    guard type.hasPrefix("session."),
          let sid = sessionIdentifier(from: properties) else {
      return nil
    }

    let status = type.replacingOccurrences(of: "session.", with: "")
    let supported = ["idle", "running", "thinking", "error", "retry"]
    guard supported.contains(status) else {
      return nil
    }

    return .sessionStatusUpdated(sessionID: sid, status: SessionStatusInfo(status: status, message: nil))
  }

  private func sessionIdentifier(from properties: [String: CodableValue]?) -> String? {
    properties?["sessionID"]?.stringValue
      ?? properties?["sessionId"]?.stringValue
      ?? properties?["id"]?.stringValue
  }

  private func decodeStatus(from properties: [String: CodableValue]?) -> SessionStatusInfo? {
    if let info = decode(SessionStatusInfo.self, properties?["info"]) {
      return info
    }
    if let status = properties?["status"]?.stringValue {
      let message = properties?["message"]?.stringValue
      return SessionStatusInfo(status: status, message: message)
    }
    return nil
  }

  private func decode<T: Decodable>(_ type: T.Type, _ value: CodableValue?) -> T? {
    guard let value,
          let data = try? JSONEncoder().encode(value) else { return nil }
    return try? decoder.decode(T.self, from: data)
  }

  private func decode<T: Decodable>(_ type: T.Type, _ object: [String: CodableValue]?) -> T? {
    guard let object,
          let data = try? JSONEncoder().encode(CodableValue.object(object)) else { return nil }
    return try? decoder.decode(T.self, from: data)
  }
}

private struct SSEEnvelope: Codable {
  let type: String
  let properties: [String: CodableValue]?
}
