// OpenCodeRemote - 聊天输入栏
// 创建时间：2026-04-29

import SwiftUI

/// 底部输入栏，包含输入框、发送和中止按钮
struct ChatInputBar: View {
  @ObservedObject var sessionStore: SessionStore
  @State private var inputText: String = ""
  @FocusState private var isFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      Divider()
      HStack(alignment: .bottom, spacing: AppSpacing.sm) {
        // 输入框
        TextField("发送指令...", text: $inputText, axis: .vertical)
          .textFieldStyle(.plain)
          .padding(.horizontal, AppSpacing.md)
          .padding(.vertical, AppSpacing.sm)
          .background(Color(.systemGray6))
          .cornerRadius(20)
          .focused($isFocused)
          .lineLimit(1...5)

        // 发送按钮
        Button {
          let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
          guard !text.isEmpty else { return }
          inputText = ""
          isFocused = false
          Task { _ = await sessionStore.sendPrompt(message: text) }
        } label: {
          Image(systemName: AppIcons.send)
            .font(.title2)
            .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : AppColors.accent)
        }
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        // 中止按钮（仅运行或思考中显示）
        if sessionStore.isSelectedSessionRunning {
          Button {
            Task { await sessionStore.abort() }
          } label: {
            Image(systemName: AppIcons.abort)
              .font(.title2)
              .foregroundColor(AppColors.error)
          }
        }
      }
      .padding(.horizontal, AppSpacing.md)
      .padding(.vertical, AppSpacing.sm)
    }
    .background(.bar)
  }
}
