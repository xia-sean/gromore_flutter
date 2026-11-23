import Flutter
import UIKit
import XCTest
import BUAdSDK
import AVFoundation


@testable import gromore_flutter

private class VideoActionTarget: NSObject {
  var actions: [String] = []
  @objc func play() { actions.append("play") }
  @objc func pause() { actions.append("pause") }
  @objc func stop() { actions.append("stop") }
}

class RunnerTests: XCTestCase {
  func testRewardConfirmationCancelAndAcceptDismissOnlyTheAlert() {
    for accepted in [false, true] {
      let root = UIViewController()
      let window = UIWindow(frame: UIScreen.main.bounds)
      window.rootViewController = root
      window.makeKeyAndVisible()
      let ad = UIViewController()
      let shown = expectation(description: "ad shown")
      root.present(ad, animated: false) { shown.fulfill() }
      wait(for: [shown], timeout: 2)
      var results: [Bool] = []
      let answered = expectation(description: "alert dismissed before answer")
      let prompt = GromoreRewardConfirmation(title: "奖励已收到", message: "导出次数已到账",
        cancelLabel: "取消", confirmLabel: "确定", controller: { ad }, isValid: { true },
        isForeground: { true }) { value in
          results.append(value)
          XCTAssertNil(ad.presentedViewController)
          XCTAssertTrue(root.presentedViewController === ad)
          answered.fulfill()
        }
      prompt.present()
      let alertShown = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
        ad.presentedViewController is UIAlertController && !ad.presentedViewController!.isBeingPresented
      }, object: nil)
      wait(for: [alertShown], timeout: 2)
      XCTAssertTrue(prompt.alert?.presentingViewController === ad)
      XCTAssertEqual(prompt.alert?.actions.map { $0.title ?? "" }, ["取消", "确定"])
      prompt.choose(confirmed: accepted)
      wait(for: [answered], timeout: 2)
      prompt.cancel()
      XCTAssertEqual(results, [accepted], "通道结果只完成一次")
      root.dismiss(animated: false)
      window.isHidden = true
    }
  }

  func testRewardConfirmationWaitsForForegroundAndCancelsStaleRequest() {
    var foreground = false
    var valid = true
    let answered = expectation(description: "stale confirmation cancelled")
    let prompt = GromoreRewardConfirmation(title: "Reward", message: "Credited",
      cancelLabel: "Cancel", confirmLabel: "OK", controller: { nil }, isValid: { valid },
      isForeground: { foreground }) { accepted in
        XCTAssertFalse(accepted)
        answered.fulfill()
      }
    prompt.present()
    XCTAssertNil(prompt.alert?.presentingViewController)
    foreground = true
    valid = false
    prompt.present()
    wait(for: [answered], timeout: 2)
    XCTAssertNil(prompt.alert)
  }

  func testDisposingRewardCancelsQueuedConfirmationAndRejectsDuplicates() throws {
    let holder = GromoreAdManager.RewardAdHolder(adId: "reward", placementId: "slot")
    let manager = GromoreAdManager(emitAdEvent: { _ in }, emitLog: { _, _, _ in },
      adHolders: ["reward": holder])
    let args = ["adId": "reward", "title": "Reward", "message": "Credited",
      "cancelLabel": "Cancel", "confirmLabel": "OK"]
    let answered = expectation(description: "confirmation cancelled")
    try manager.showRewardConfirmation(args: args) { accepted in
      XCTAssertFalse(accepted)
      answered.fulfill()
    }
    XCTAssertThrowsError(try manager.showRewardConfirmation(args: args) { _ in })
    let disposed = expectation(description: "dispose completed after cancellation")
    manager.disposeAd(adId: "reward") { disposed.fulfill() }
    wait(for: [answered, disposed], timeout: 2)
    XCTAssertThrowsError(try manager.showRewardConfirmation(args: args) { _ in })
  }

  func testRewardPlaybackTraceKeepsCompletionRewardAndCloseSeparate() throws {
    let center = NotificationCenter()
    let holder = GromoreAdManager.RewardAdHolder(adId: "reward", placementId: "placement")
    var events: [[String: Any]] = []
    var logs: [[String: Any]] = []
    let manager = GromoreAdManager(emitAdEvent: { events.append($0) }, emitLog: { _, message, _ in
      let prefix = "reward playback: "
      guard message.hasPrefix(prefix),
            let data = String(message.dropFirst(prefix.count)).data(using: .utf8),
            let log = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
      logs.append(log)
    }, adHolders: ["reward": holder], notificationCenter: center)
    let delegate = GromoreAdManager.RewardDelegate(manager: manager, adId: "reward", placementId: "placement")
    let ad = BUNativeExpressRewardedVideoAd(slotID: "placement", rewardedVideoModel: BURewardedVideoModel())
    delegate.nativeExpressRewardedVideoAdDidVisible(ad)
    delegate.nativeExpressRewardedVideoAdDidPlayFinish(ad, didFailWithError: nil)
    delegate.nativeExpressRewardedVideoAdServerRewardDidSucceed(ad, verify: false)
    center.post(name: UIApplication.willResignActiveNotification, object: nil)
    center.post(name: AVAudioSession.interruptionNotification, object: nil, userInfo: [
      AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
    ])
    let drained = expectation(description: "reward callbacks delivered")
    DispatchQueue.main.async {
      XCTAssertEqual(events.compactMap { $0["eventType"] as? String }, ["shown", "completed", "rewarded"])
      XCTAssertEqual((events.last?["data"] as? [String: Any])?["verify"] as? Bool, false)
      XCTAssertTrue(logs.contains { $0["event"] as? String == "app_will_resign_active" })
      let interruption = logs.first { $0["event"] as? String == "audio_interruption" }
      XCTAssertEqual(interruption?["videoCompleted"] as? Bool, true)
      XCTAssertEqual(interruption?["rewardCallbackReceived"] as? Bool, true)
      XCTAssertEqual(interruption?["rewardVerify"] as? Bool, false)
      XCTAssertEqual(interruption?["interruptionType"] as? UInt, AVAudioSession.InterruptionType.began.rawValue)
      drained.fulfill()
    }
    wait(for: [drained], timeout: 2)
    delegate.nativeExpressRewardedVideoAdDidClose(ad)
    let countAfterClose = logs.count
    center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    XCTAssertEqual(logs.count, countAfterClose, "关闭后停止监听原生生命周期")
    manager.disposeAd(adId: "reward")
  }

  func testDisposingRewardStopsPlaybackTraceObservers() {
    let center = NotificationCenter()
    let holder = GromoreAdManager.RewardAdHolder(adId: "reward", placementId: "placement")
    var logs: [String] = []
    let manager = GromoreAdManager(emitAdEvent: { _ in }, emitLog: { _, message, _ in logs.append(message) },
      adHolders: ["reward": holder], notificationCenter: center)
    let delegate = GromoreAdManager.RewardDelegate(manager: manager, adId: "reward", placementId: "placement")
    let ad = BUNativeExpressRewardedVideoAd(slotID: "placement", rewardedVideoModel: BURewardedVideoModel())
    delegate.nativeExpressRewardedVideoAdDidVisible(ad)
    manager.disposeAd(adId: "reward")
    let countAfterDispose = logs.count
    center.post(name: UIApplication.didBecomeActiveNotification, object: nil)
    XCTAssertEqual(logs.count, countAfterDispose)
  }

  func testDisposeDismissesOnlyRecordedAdPresentation() throws {
    let root = UIViewController()
    let window = UIWindow(frame: UIScreen.main.bounds)
    window.rootViewController = root
    window.makeKeyAndVisible()
    defer { window.isHidden = true }
    let modal = UIViewController()
    let presented = expectation(description: "ad presentation completed")
    root.present(modal, animated: false) { presented.fulfill() }
    wait(for: [presented], timeout: 2)
    XCTAssertTrue(root.presentedViewController === modal)
    let holder = GromoreAdManager.FullScreenAdHolder(adId: "ad", placementId: "full", adType: "interstitial")
    let manager = GromoreAdManager(emitAdEvent: { _ in }, emitLog: { _, _, _ in },
      adHolders: ["ad": holder])
    holder.presentationRoot = root
    holder.presentedAdController = modal
    manager.disposeAd(adId: "ad")
    let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      root.presentedViewController == nil
    }, object: nil)
    wait(for: [dismissed], timeout: 2)
    XCTAssertNil(root.presentedViewController)
    XCTAssertNil(holder.presentedAdController)
    XCTAssertThrowsError(try manager.adState(adId: "ad"))
    // 宿主自身的弹层从未记录为广告，释放其他实例不能误关它。
    let hostModal = UIViewController()
    let hostPresented = expectation(description: "host presentation completed")
    root.present(hostModal, animated: false) { hostPresented.fulfill() }
    wait(for: [hostPresented], timeout: 2)
    let other = GromoreAdManager.RewardAdHolder(adId: "other", placementId: "reward")
    other.presentationRoot = root
    let otherManager = GromoreAdManager(emitAdEvent: { _ in }, emitLog: { _, _, _ in },
      adHolders: ["other": other])
    otherManager.disposeAd(adId: "other")
    XCTAssertTrue(root.presentedViewController === hostModal)
    root.dismiss(animated: false)
  }

  func testReleasingOldPlatformViewDoesNotDetachNewContainerForSameAd() {
    for type in ["banner", "native", "draw_native"] {
      let holder = GromoreAdManager.FeedAdHolder(adId: "ad", placementId: "feed", adType: type)
      let manager = GromoreAdManager(emitAdEvent: { _ in }, emitLog: { _, _, _ in },
        adHolders: ["ad": holder])
      let frame = CGRect(x: 0, y: 0, width: 320, height: 250)
      var oldView: GromoreAdPlatformView? = GromoreAdPlatformView(frame: frame,
        adId: "ad", adType: type, adManager: manager)
      let oldContainer = oldView!.view()
      let newView = GromoreAdPlatformView(frame: frame, adId: "ad", adType: type, adManager: manager)
      let content = UIView(frame: frame)
      newView.view().addSubview(content)
      XCTAssertTrue(holder.container === newView.view())
      oldView = nil
      XCTAssertTrue(oldContainer.subviews.isEmpty)
      XCTAssertTrue(holder.container === newView.view(), "旧视图释放不能解绑新视图")
      XCTAssertTrue(content.superview === newView.view(), "新广告内容不能被旧视图清空")
    }
  }

  func testRepeatedBannerLoadFailuresDeliverOneCodecSafeDiagnosticEvent() {
    let holder = GromoreAdManager.BannerAdHolder(adId: "ad", placementId: "banner")
    var events: [[String: Any]] = []
    let manager = GromoreAdManager(emitAdEvent: { events.append($0) }, emitLog: { _, _, _ in },
      adHolders: ["ad": holder])
    let delegate = GromoreAdManager.BannerDelegate(manager: manager, adId: "ad",
      placementId: "banner")
    let view = BUNativeExpressBannerView(slotID: "banner",
      rootViewController: UIViewController(), adSize: CGSize(width: 320, height: 50))
    let error = NSError(domain: "test.banner", code: 10086,
      userInfo: [NSLocalizedDescriptionKey: "all networks failed"])
    delegate.nativeExpressBannerAdView(view, didLoadFailWithError: error)
    delegate.nativeExpressBannerAdView(view, didLoadFailWithError: error)
    let drained = expectation(description: "banner errors delivered")
    DispatchQueue.main.async {
      XCTAssertEqual(events.count, 1)
      guard let event = events.first, let data = event["data"] as? [String: Any] else {
        XCTFail("Missing failure diagnostics")
        drained.fulfill()
        return
      }
      XCTAssertEqual(event["errorCode"] as? String, "10086")
      XCTAssertEqual(data["phase"] as? String, "load")
      XCTAssertEqual((data["loadInfo"] as? [Any])?.count, 0)
      XCTAssertEqual((data["waterfallFillFailMessages"] as? [Any])?.count, 0)
      // 失败详情必须可以通过 Flutter 标准通道编码。
      let codec = FlutterStandardMessageCodec.sharedInstance()
      XCTAssertNotNil(codec.encode(event))
      drained.fulfill()
    }
    wait(for: [drained], timeout: 2)
  }

  func testVideoActionsCheckRuntimeSupportBeforeCallingSdkObject() {
    let unsupported = UIView()
    let supported = VideoActionTarget()
    for action in ["pause", "play", "stop"] {
      XCTAssertFalse(GromoreAdManager.performVideoAction(on: nil, action: action))
      XCTAssertFalse(GromoreAdManager.performVideoAction(on: unsupported, action: action))
      XCTAssertTrue(GromoreAdManager.performVideoAction(on: supported, action: action))
    }
    XCTAssertEqual(supported.actions, ["pause", "play", "stop"])
    XCTAssertFalse(GromoreAdManager.performVideoAction(on: supported, action: "unknown"))
    let media = VideoActionTarget()
    XCTAssertTrue(GromoreAdManager.performVideoAction(on: unsupported, action: "stop", fallbackTarget: media))
    XCTAssertEqual(media.actions, ["pause"])
  }

  func testManualVideoActionSurvivesMountAndRemount() throws {
    for adType in ["native", "draw_native"] {
      for action in ["pause", "stop"] {
        let holder = GromoreAdManager.FeedAdHolder(adId: "ad", placementId: "feed", adType: adType)
        let manager = GromoreAdManager(emitAdEvent: { _ in }, emitLog: { _, _, _ in },
          adHolders: ["ad": holder])
        try manager.operation("controlVideo", args: ["adId": "ad", "action": action])
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
        manager.attachAdView(adId: "ad", adType: adType, container: container, width: 320, height: 100)
        manager.detachAdView(adId: "ad")
        manager.attachAdView(adId: "ad", adType: adType, container: container, width: 320, height: 100)
        XCTAssertEqual(holder.videoAction, action)
        try manager.operation("controlVideo", args: ["adId": "ad", "action": "resume"])
        manager.detachAdView(adId: "ad")
        XCTAssertEqual(holder.videoAction, "play")
      }
    }
  }

  func testRepeatedNativeRenderCallbacksDeliverOneEvent() {
    let holder = GromoreAdManager.FeedAdHolder(adId: "ad", placementId: "feed")
    var events: [[String: Any]] = []
    let manager = GromoreAdManager(emitAdEvent: { events.append($0) }, emitLog: { _, _, _ in },
      adHolders: ["ad": holder])
    let delegate = GromoreAdManager.FeedDelegate(manager: manager, adId: "ad",
      adType: "native", placementId: "feed")
    let slot = BUAdSlot()
    slot.id = "feed"
    let nativeAd = BUNativeAd(slot: slot)
    delegate.nativeAdExpressViewRenderSuccess(nativeAd)
    delegate.nativeAdExpressViewRenderSuccess(nativeAd)
    let container = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 100))
    manager.attachAdView(adId: "ad", adType: "native", container: container, width: 320, height: 100)
    let drained = expectation(description: "render callbacks delivered")
    DispatchQueue.main.async {
      XCTAssertEqual(events.filter { $0["eventType"] as? String == "rendered" }.count, 1)
      drained.fulfill()
    }
    wait(for: [drained], timeout: 2)
  }

  func testNativeRenderFailureKeepsSdkErrorAndRenderPhase() {
    let holder = GromoreAdManager.FeedAdHolder(adId: "ad", placementId: "feed")
    let failed = expectation(description: "render failure delivered")
    let manager = GromoreAdManager(emitAdEvent: { event in
      XCTAssertEqual(event["eventType"] as? String, "failed")
      XCTAssertEqual(event["errorCode"] as? String, "42")
      XCTAssertEqual((event["data"] as? [String: Any])?["phase"] as? String, "render")
      failed.fulfill()
    }, emitLog: { _, _, _ in }, adHolders: ["ad": holder])
    let delegate = GromoreAdManager.FeedDelegate(manager: manager, adId: "ad",
      adType: "native", placementId: "feed")
    let slot = BUAdSlot()
    slot.id = "feed"
    delegate.nativeAdExpressViewRenderFail(BUNativeAd(slot: slot),
      error: NSError(domain: "test.render", code: 42))
    wait(for: [failed], timeout: 2)
  }

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
    XCTAssertTrue((model.extra ?? "").isEmpty)
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
