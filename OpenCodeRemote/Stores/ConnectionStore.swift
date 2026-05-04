// OpenCode Remote - 连接状态管理
// 创建时间：2026-04-29

import Foundation
import Combine
import SwiftUI

/// 服务器连接配置和状态
@MainActor
final class ConnectionStore: ObservableObject {
  static let timeoutSeconds = Int(OpenCodeAPIClient.requestTimeout)

  @Published var serverURL: String = ""
  @Published var authToken: String = ""
  @Published var status: ConnectionStatus = .disconnected
  @Published var lastError: String?
  @Published var serverInfo: HealthInfo?
  @Published var connectionHint: String?

  struct HealthInfo {
    let version: String
    let url: String
  }

  enum ConnectionStatus: String {
    case disconnected, connecting, connected, error
  }

  private let credentialStore = CredentialStore()
  private let apiClient: OpenCodeAPIClient
  private let defaultsKey = "com.opencode.remote.serverURL"

  init(apiClient: OpenCodeAPIClient) {
    self.apiClient = apiClient
    if let saved = UserDefaults.standard.string(forKey: defaultsKey) {
      serverURL = saved
    }
    if let token = credentialStore.read() {
      authToken = token
    }
  }

  func connect() async -> Bool {
    guard !serverURL.isEmpty else {
      status = .error
      lastError = "请填写服务器地址"
      return false
    }

    var urlString = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
    if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
      urlString = "http://" + urlString
    }
    guard let url = URL(string: urlString) else {
      status = .error
      lastError = "服务器地址格式无效"
      return false
    }

    status = .connecting
    lastError = nil
    connectionHint = "正在尝试连接服务器，超时阈值为 \(Self.timeoutSeconds) 秒"

    do {
      await apiClient.configure(baseURL: url, authToken: authToken)
      let health = try await apiClient.healthCheck()
      status = .connected
      serverURL = urlString
      connectionHint = nil

      serverInfo = HealthInfo(version: health.version, url: urlString)
      UserDefaults.standard.set(urlString, forKey: defaultsKey)
      _ = credentialStore.save(token: authToken)
      return true
    } catch {
      status = .error
      if let networkError = error as? NetworkError, case .timeout = networkError {
        lastError = "连接超时（\(Self.timeoutSeconds) 秒），请检查服务器地址、Tailscale/局域网连通性，或稍后重试"
        connectionHint = "连接请求已超时，你可以确认服务器在线后重新连接"
      } else {
        lastError = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
        connectionHint = nil
      }
      return false
    }
  }

  func disconnect() {
    status = .disconnected
    serverInfo = nil
    connectionHint = nil
  }

  func clear() {
    disconnect()
    _ = credentialStore.delete()
    serverURL = ""
    authToken = ""
    lastError = nil
    connectionHint = nil
    UserDefaults.standard.removeObject(forKey: defaultsKey)
  }
}
