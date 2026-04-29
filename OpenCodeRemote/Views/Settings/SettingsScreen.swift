// OpenCodeRemote - 设置页面
// 创建时间：2026-04-29

import SwiftUI

/// 设置页面（占位，后续扩展）
struct SettingsScreen: View {
  var body: some View {
    NavigationStack {
      List {
        Section("连接") {
          Label("Tailscale 连接提示", systemImage: "point.3.connected.trianglepath.dotted")
            .font(AppTypography.body)
        }
        Section("通知") {
          Label("未配置通知渠道", systemImage: "bell.slash")
            .foregroundColor(.secondary)
        }
        Section("调试") {
          NavigationLink {
            DebugLogScreen()
          } label: {
            Label("调试日志", systemImage: AppIcons.debug)
          }
        }
        Section("关于") {
          Label("OpenCode Remote v0.1.0", systemImage: "info.circle")
            .foregroundColor(.secondary)
        }
      }
      .navigationTitle("设置")
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
