// OpenCode Remote - 设置页面
// 服务器信息、连接管理、调试日志、关于
// 创建时间：2026-04-29

import SwiftUI

/// 设置页面
struct SettingsScreen: View {
  @EnvironmentObject var conn: ConnectionStore
  @EnvironmentObject var store: SessionStore
  @State private var showDisconnectConfirm = false

  var body: some View {
    NavigationStack {
      List {
        // 服务器信息
        Section("服务器") {
          LabeledContent("地址", value: conn.serverURL)
          LabeledContent("状态", value: statusText)
          if let info = conn.serverInfo {
            LabeledContent("版本", value: info.version)
          }
        }

        // 连接管理
        Section("连接") {
          Button(role: .destructive) {
            showDisconnectConfirm = true
          } label: {
            Label("断开连接", systemImage: AppIcons.disconnect)
          }
          .disabled(conn.status != .connected)
        }

        // 调试
        Section("调试") {
          NavigationLink {
            DebugLogScreen()
          } label: {
            Label("调试日志", systemImage: AppIcons.debug)
          }
        }

        // 关于
        Section("关于") {
          LabeledContent("应用", value: "OpenCode Remote")
          LabeledContent("版本", value: "1.0.0")
          if let url = URL(string: "https://github.com/chrn11/opencode-remote-ios") {
            Link("GitHub 仓库", destination: url)
          }
        }
      }
      .navigationTitle("设置")
      .confirmationDialog("确认断开连接？", isPresented: $showDisconnectConfirm) {
        Button("断开", role: .destructive) {
          store.unsubscribeEvents()
          conn.disconnect()
        }
        Button("取消", role: .cancel) {}
      }
    }
  }

  private var statusText: String {
    switch conn.status {
    case .connected: return "已连接"
    case .connecting: return "连接中"
    case .disconnected: return "未连接"
    case .error: return "连接失败"
    }
  }
}

/// 调试日志页面
struct DebugLogScreen: View {
  @State private var logs = DebugLogger.shared.latestEntries
  @State private var showExport = false

  var body: some View {
    Group {
      if logs.isEmpty {
        VStack(spacing: AppSpacing.md) {
          Image(systemName: "doc.text.magnifyingglass")
            .font(.system(size: 48))
            .foregroundColor(.secondary)
          Text("暂无日志")
            .font(AppTypography.headline)
            .foregroundColor(.secondary)
        }
      } else {
        List(logs) { entry in
          debugEntryRow(entry)
        }
      }
    }
    .navigationTitle("调试日志")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarTrailing) {
        Button("导出") {
          showExport = true
        }
        .disabled(logs.isEmpty)
      }
      ToolbarItem(placement: .navigationBarLeading) {
        Button("刷新") {
          logs = DebugLogger.shared.latestEntries
        }
      }
    }
    .sheet(isPresented: $showExport) {
      ShareSheet(items: [DebugLogger.shared.exportAsText()])
    }
  }

  private func debugEntryRow(_ entry: DebugLogger.LogEntry) -> some View {
    VStack(alignment: .leading, spacing: AppSpacing.xs) {
      HStack {
        Image(systemName: entry.level.symbolName)
          .foregroundColor(levelColor(entry.level))
        Text("[\(entry.level.displayName)] \(entry.formattedTime)")
          .font(AppTypography.caption.bold())
      }
      Text(entry.category)
        .font(AppTypography.monoSmall)
      if !entry.metadata.isEmpty {
        Text(entry.metadata.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
          .font(AppTypography.monoSmall)
          .foregroundColor(.secondary)
      }
    }
    .padding(.vertical, AppSpacing.xs)
  }

  private func levelColor(_ level: DebugLogger.LogLevel) -> Color {
    switch level {
    case .info: return .secondary
    case .warn: return AppColors.thinking
    case .error: return AppColors.error
    }
  }
}

/// 分享 Sheet（UIKit bridge）
struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}