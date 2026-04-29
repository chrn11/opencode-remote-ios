// OpenCode Remote - 网络错误模型
// 创建时间：2026-04-29

import Foundation

/// 网络错误统一模型
enum NetworkError: LocalizedError {
  case notConfigured
  case invalidURL
  case invalidResponse
  case unauthorized
  case notFound
  case conflict(String?)
  case serverError(Int)
  case unexpectedStatus(Int)
  case timeout
  case connectionFailed(Error)
  case decodeFailed(Error)

  var errorDescription: String? {
    switch self {
    case .notConfigured: return "未配置服务器连接"
    case .invalidURL: return "服务器地址无效"
    case .invalidResponse: return "服务器响应无效"
    case .unauthorized: return "认证失败，请检查凭据"
    case .notFound: return "请求的资源不存在"
    case .conflict(let msg): return "操作冲突" + (msg.map { ": \($0)" } ?? "")
    case .serverError(let code): return "服务器错误 (\(code))"
    case .unexpectedStatus(let code): return "意外响应 (\(code))"
    case .timeout: return "请求超时"
    case .connectionFailed: return "连接失败，请检查网络和服务器地址"
    case .decodeFailed: return "数据解析失败"
    }
  }

  /// 是否可重试
  var isRetryable: Bool {
    switch self {
    case .serverError, .timeout, .connectionFailed: return true
    default: return false
    }
  }
}

/// HTTP 状态验证工具
enum HTTPValidator {
  /// 验证响应状态码，不符合预期时抛出 NetworkError
  static func validate(_ response: URLResponse, data: Data, expectedStatus: Int = 200) throws {
    guard let http = response as? HTTPURLResponse else {
      throw NetworkError.invalidResponse
    }

    switch http.statusCode {
    case expectedStatus: return
    case 204 where expectedStatus == 204: return
    case 202 where expectedStatus == 202: return
    case 201 where expectedStatus == 201: return
    case 401: throw NetworkError.unauthorized
    case 404: throw NetworkError.notFound
    case 409: throw NetworkError.conflict(String(data: data, encoding: .utf8))
    case 500...599: throw NetworkError.serverError(http.statusCode)
    default: throw NetworkError.unexpectedStatus(http.statusCode)
    }
  }
}
