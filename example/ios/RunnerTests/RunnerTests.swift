import Flutter
import UIKit
import XCTest
import BUAdSDK


@testable import gromore_flutter

class RunnerTests: XCTestCase {
  func testRewardParametersReachSdkFromEverySupportedContainer() {
    let parameters: [String: Any] = [
      "userId": "test_user", "rewardName": "金币", "rewardAmount": 1,
      "customData": "{\"orderId\":\"order-123\"}"
    ]
    for request in [parameters, ["extra": parameters], ["iosExtra": parameters]] {
      let model = GromoreAdRequestOptions(request: request).rewardModel()
      XCTAssertEqual(model.userId, "test_user")
      XCTAssertEqual(model.rewardName, "金币")
      XCTAssertEqual(model.rewardAmount, 1)
      XCTAssertEqual(model.extra, parameters["customData"] as? String)
    }
  }

  func testParameterPrecedenceAndNullFallback() {
    let options = GromoreAdRequestOptions(request: [
      "userId": NSNull(), "muted": false,
      "iosExtra": ["userId": "platform-user", "muted": true, "scenarioId": NSNull()],
      "extra": ["userId": "extra-user", "scenarioId": "extra-scene", "rewardAmount": "3"]
    ])
    XCTAssertEqual(options.rewardModel().userId, "platform-user")
    XCTAssertEqual(options.rewardModel().rewardAmount, 3)
    XCTAssertEqual(options.bool("muted"), false)
    XCTAssertEqual(options.string("scenarioId"), "extra-scene")
  }

  func testSplashSizeAndTimeoutReachSdk() {
    let options = GromoreAdRequestOptions(request: [
      "extra": ["width": 320, "height": 480, "splashTimeout": 2500]
    ])
    let size = options.splashSize(fallback: CGSize(width: 375, height: 667))
    XCTAssertEqual(size, CGSize(width: 320, height: 480))
    let slot = BUAdSlot()
    slot.id = "splash-placement"
    let ad = BUSplashAd(slot: slot, adSize: size)
    options.configureSplashAd(ad)
    XCTAssertEqual(ad.tolerateTimeout, 2.5)
  }

  func testInvalidSplashSizeFallsBack() {
    let options = GromoreAdRequestOptions(request: ["width": 0, "height": -1])
    let fallback = CGSize(width: 375, height: 667)
    XCTAssertEqual(options.splashSize(fallback: fallback), fallback)
  }

  func testArbitraryExtraMapIsNotUploadedAsCustomData() {
    let model = GromoreAdRequestOptions(request: [
      "extra": ["userId": "test_user", "orderId": "private-order"]
    ]).rewardModel()
    XCTAssertNil(model.extra)
  }

  func testLegacyAndOtherPlatformContainersAreNotRead() {
    let options = GromoreAdRequestOptions(request: [
      "iosOptions": ["userId": "legacy-user"],
      "androidOptions": ["userId": "legacy-android-user"],
      "androidExtra": ["userId": "android-user"]
    ])
    XCTAssertNil(options.string("userId"))
  }

  func testPreviewToolReadsNestedAndLegacyArguments() {
    let arguments: [String: Any] = ["rit": "reward-placement", "info": ["test": "value"]]
    for payload in [arguments, ["method": "openTestTool", "args": arguments]] {
      let info = GromoreFlutterPlugin.previewInfo(from: payload)
      XCTAssertEqual(info["rit"] as? String, "reward-placement")
      XCTAssertEqual(info["test"] as? String, "value")
    }
  }
}
