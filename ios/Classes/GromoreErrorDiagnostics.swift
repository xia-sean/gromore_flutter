import Foundation

/// 只跨通道传递标准 NSError 字段，不遍历任意 userInfo/请求参数。
enum GromoreErrorDiagnostics {
  static func fields(error: Error?, splashErrorCode: Int? = nil) -> [String: Any] {
    var fields: [String: Any] = [:]
    if let code = splashErrorCode { fields["splashErrorCode"] = code }
    if let error = error {
      var visited = Set<ObjectIdentifier>()
      fields["nativeError"] = snapshot(error as NSError, depth: 0, visited: &visited)
    }
    return fields
  }

  private static func snapshot(_ error: NSError, depth: Int,
                               visited: inout Set<ObjectIdentifier>) -> [String: Any] {
    visited.insert(ObjectIdentifier(error))
    var result: [String: Any] = [
      "code": error.code,
      "domain": String(error.domain.prefix(128)),
      "message": String(error.localizedDescription.prefix(512))
    ]
    if let reason = error.localizedFailureReason {
      result["failureReason"] = String(reason.prefix(512))
    }
    if depth < 3, let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError,
       !visited.contains(ObjectIdentifier(underlying)) {
      result["underlyingError"] = snapshot(underlying, depth: depth + 1, visited: &visited)
    }
    return result
  }
}
