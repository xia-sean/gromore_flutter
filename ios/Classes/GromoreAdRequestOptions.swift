import BUAdSDK
import UIKit

struct GromoreAdRequestOptions {
  let request: [String: Any]

  func value(_ key: String) -> Any? {
    let iosExtra = request["iosExtra"] as? [String: Any] ?? [:]
    let extra = request["extra"] as? [String: Any] ?? [:]
    for source in [request, iosExtra, extra] {
      if let value = source[key], !(value is NSNull) {
        return value
      }
    }
    return nil
  }

  func string(_ key: String) -> String? {
    return value(key) as? String
  }

  func int(_ key: String, fallback: Int) -> Int {
    if let number = value(key) as? NSNumber { return number.intValue }
    if let string = value(key) as? String { return Int(string) ?? fallback }
    return fallback
  }

  func bool(_ key: String) -> Bool? {
    if let number = value(key) as? NSNumber { return number.boolValue }
    if let string = value(key) as? String {
      switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
      case "true", "1": return true
      case "false", "0": return false
      default: return nil
      }
    }
    return nil
  }

  func rewardModel() -> BURewardedVideoModel {
    let model = BURewardedVideoModel()
    model.userId = string("userId") ?? ""
    model.rewardName = string("rewardName") ?? ""
    model.rewardAmount = int("rewardAmount", fallback: 0)
    model.extra = string("customData")
    return model
  }

  func splashSize(fallback: CGSize) -> CGSize {
    let width = int("width", fallback: Int(fallback.width))
    let height = int("height", fallback: Int(fallback.height))
    return CGSize(
      width: width > 0 ? CGFloat(width) : fallback.width,
      height: height > 0 ? CGFloat(height) : fallback.height
    )
  }

  func configureSplashAd(_ splashAd: BUSplashAd) {
    let timeout = int("splashTimeout", fallback: 0)
    if timeout > 0 {
      splashAd.tolerateTimeout = TimeInterval(timeout) / 1000
    }
  }
}
