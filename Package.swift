// swift-tools-version: 5.9
// OpenCode Remote — Swift Package 定义（CI 编译用）
// 创建时间：2026-04-29

import PackageDescription

let package = Package(
  name: "OpenCodeRemote",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "OpenCodeRemote", targets: ["OpenCodeRemote"]),
  ],
  targets: [
    .target(
      name: "OpenCodeRemote",
      dependencies: [],
      path: "OpenCodeRemote",
      sources: [
        "Models/Schema.swift",
        "Models/CodableValue.swift",
        "Models/Session.swift",
        "Models/Error.swift",
        "Models/Permission.swift",
        "Models/MessageSubtypes.swift",
        "Models/Message.swift",
        "Models/Part.swift",
        "Networking/NetworkError.swift",
        "Networking/OpenCodeAPIClient.swift",
        "Networking/SSEEvent.swift",
        "Networking/EventStreamClient.swift",
        "Stores/CredentialStore.swift",
        "Stores/ConnectionStore.swift",
        "Stores/SessionStore.swift",
        "Utilities/DebugLogger.swift",
        "Utilities/DateFormatter+Extensions.swift",
        "Utilities/String+Truncation.swift",
        "Utilities/MarkdownRenderer.swift",
        "DesignSystem/Colors.swift",
        "DesignSystem/Typography.swift",
        "DesignSystem/Spacing.swift",
        "DesignSystem/Icons.swift",
        "ContentView.swift",
        "OpenCodeRemoteApp.swift",
      ]
    ),
  ]
)
