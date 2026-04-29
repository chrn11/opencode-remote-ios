// OpenCodeRemote - 本地调试日志
// 创建时间：2026-04-29

import Foundation

/// 环形内存日志器，记录最近 200 条日志，支持一键导出
final class DebugLogger: @unchecked Sendable {
  static let shared = DebugLogger()

  private let queue = DispatchQueue(label: "com.opencode.debuglogger")
  private var entries: [LogEntry] = []
  private let maxEntries = 200

  /// 日志条目
  struct LogEntry: Codable, Identifiable, Sendable {
    var id: String { "\(timestamp.timeIntervalSince1970)-\(category)" }
    let timestamp: Date
    let level: LogLevel
    let category: String
    let metadata: [String: String]

    /// 格式化时间戳
    var formattedTime: String {
      let formatter = DateFormatter()
      formatter.dateFormat = "HH:mm:ss.SSS"
      return formatter.string(from: timestamp)
    }
  }

  /// 日志等级
  enum LogLevel: String, Codable, Sendable {
    case info, warn, error

    var displayName: String {
      switch self {
      case .info: "信息"
      case .warn: "警告"
      case .error: "错误"
      }
    }

    var symbolName: String {
      switch self {
      case .info: "info.circle"
      case .warn: "exclamationmark.triangle"
      case .error: "xmark.octagon"
      }
    }
  }

  /// 记录信息日志
  func info(_ category: String, _ metadata: [String: String] = [:]) {
    log(.info, category, metadata)
  }

  /// 记录警告日志
  func warn(_ category: String, _ metadata: [String: String] = [:]) {
    log(.warn, category, metadata)
  }

  /// 记录错误日志
  func error(_ category: String, _ metadata: [String: String] = [:]) {
    log(.error, category, metadata)
  }

  // MARK: - 私有日志方法

  private func log(_ level: LogLevel, _ category: String, _ metadata: [String: String]) {
    queue.async { [weak self] in
      guard let self else { return }

      // 脱敏处理：不记录密码和完整 prompt
      var safeMeta = metadata
      safeMeta.removeValue(forKey: "password")
      safeMeta.removeValue(forKey: "prompt")

      let entry = LogEntry(
        timestamp: Date(),
        level: level,
        category: category,
        metadata: safeMeta
      )

      self.entries.append(entry)
      if self.entries.count > self.maxEntries {
        let overflow = self.entries.count - self.maxEntries
        self.entries.removeFirst(overflow)
      }
    }
  }

  /// 导出为文本格式（适合分享）
  func exportAsText() -> String {
    queue.sync {
      entries.map { entry in
        "[\(entry.level.rawValue.uppercased())] \(entry.formattedTime) \(entry.category)\n" +
        entry.metadata.map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
      }.joined(separator: "\n---\n")
    }
  }

  /// 获取最新日志（线程安全）
  var latestEntries: [LogEntry] {
    queue.sync { Array(entries) }
  }
}
