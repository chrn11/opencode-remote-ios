// OpenCode Remote - 凭据存储
// 创建时间：2026-04-29

import Foundation
import Security

/// Keychain 凭据管理器，存储 auth token
final class CredentialStore: @unchecked Sendable {
  private let service = "com.opencode.remote"
  private let account = "auth_token"
  private let queue = DispatchQueue(label: "com.opencode.credentialstore")

  func save(token: String) -> Bool {
    queue.sync {
      _ = Self.delete(service: service, account: account)
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecValueData as String: Data(token.utf8)
      ]
      let status = SecItemAdd(query as CFDictionary, nil)
      if status != errSecSuccess {
        DebugLogger.shared.error("credential_save", ["错误": "\(status)"])
        return false
      }
      return true
    }
  }

  func read() -> String? {
    queue.sync {
      let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
      ]
      var result: AnyObject?
      let status = SecItemCopyMatching(query as CFDictionary, &result)
      guard status == errSecSuccess, let data = result as? Data else { return nil }
      return String(data: data, encoding: .utf8)
    }
  }

  func delete() -> Bool {
    queue.sync { Self.delete(service: service, account: account) }
  }

  private static func delete(service: String, account: String) -> Bool {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
    let status = SecItemDelete(query as CFDictionary)
    return status == errSecSuccess || status == errSecItemNotFound
  }
}
