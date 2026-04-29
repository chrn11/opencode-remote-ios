// OpenCode Remote - 连接状态管理
// 创建时间：2026-04-29

import Foundation
import Combine
import SwiftUI

/// 服务器连接配置和状态
@MainActor
final class ConnectionStore: ObservableObject {
  @Published var serverURL: String = ""
  @Published var authToken: String = ""
  @Published var status: ConnectionStatus = .disconnected
  @Published var lastError: String?
  @Published var serverInfo: HealthInfo?

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
    guard !serverURL.isEmpty, !authToken.isEmpty else {
      status = .error
      lastError = "请填写服务器地址和认证令牌"
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

    do {
      await apiClient.configure(baseURL: url, authToken: authToken)
      let health = try await apiClient.healthCheck()
      status = .connected
      serverURL = urlString

      serverInfo = HealthInfo(version: health.version, url: urlString)
      UserDefaults.standard.set(urlString, forKey: defaultsKey)
      _ = credentialStore.save(token: authToken)
      return true
    } catch {
      status = .error
      lastError = (error as? NetworkError)?.errorDescription ?? error.localizedDescription
      return false
    }
  }

  func disconnect() {
    status = .disconnected
    serverInfo = nil
  }

  func clear() {
    disconnect()
    _ = credentialStore.delete()
    serverURL = ""
    authToken = ""
    lastError = nil
    UserDefaults.standard.removeObject(forKey: defaultsKey)
  }
}
