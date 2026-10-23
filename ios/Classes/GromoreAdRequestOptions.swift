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

  /// Flutter 逻辑像素在 iOS 对应 pt，保留小数，不乘屏幕 scale。
  func dimension(_ key: String, fallback: CGFloat) -> CGFloat {
    let number: Double?
    if let raw = value(key) as? NSNumber { number = raw.doubleValue }
    else if let raw = value(key) as? String { number = Double(raw) }
    else { number = nil }
    guard let number = number, number.isFinite else { return fallback }
    return CGFloat(number)
  }

  func configureSlot(_ slot: BUAdSlot) {
    if let muted = bool("muted") { slot.mediation.mutedIfCan = muted }
    if let scenario = string("scenarioId") { slot.mediation.scenarioID = scenario }
    if let bidNotify = bool("bidNotify") { slot.mediation.bidNotify = bidNotify }
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
    let width = dimension("width", fallback: fallback.width)
    let height = dimension("height", fallback: fallback.height)
    return CGSize(
      width: width > 0 ? width : fallback.width,
      height: height > 0 ? height : fallback.height
    )
  }

  func configureSplashAd(_ splashAd: BUSplashAd) {
    let timeout = int("splashTimeout", fallback: 0)
    if timeout > 0 {
      splashAd.tolerateTimeout = TimeInterval(timeout) / 1000
    }
  }
}
