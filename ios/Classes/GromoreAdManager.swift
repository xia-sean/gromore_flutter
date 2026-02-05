import Foundation
import UIKit
import BUAdSDK

/// GroMore 广告管理器（iOS）
final class GromoreAdManager: NSObject {
  /// 广告事件回调
  private let emitAdEvent: ([String: Any]) -> Void
  /// 日志回调
  private let emitLog: (String, String, String) -> Void
  /// 广告实例缓存
  private var adHolders: [String: GromoreAdHolder] = [:]

  /// 构建广告管理器
  ///
  /// - Parameters:
  ///   - emitAdEvent: 广告事件回调
  ///   - emitLog: 日志回调
  init(
    emitAdEvent: @escaping ([String: Any]) -> Void,
    emitLog: @escaping (String, String, String) -> Void
  ) {
    self.emitAdEvent = emitAdEvent
    self.emitLog = emitLog
  }

  /// 生成新的广告实例 ID
  func newAdId() -> String {
    return UUID().uuidString
  }

  /// 加载广告
  ///
  /// - Parameters:
  ///   - adId: 广告实例 ID
  ///   - adType: 广告类型
  ///   - placementId: 代码位
  ///   - request: 请求参数
  func loadAd(adId: String, adType: String, placementId: String, request: [String: Any]) {
    emitLog("info", "loadAd start: \(adType), placementId=\(placementId), adId=\(adId)", "ad")
    switch adType {
    case "splash":
      loadSplashAd(adId: adId, placementId: placementId, request: request)
    case "rewardVideo":
      loadRewardAd(adId: adId, placementId: placementId, request: request)
    case "fullscreenVideo", "interstitial":
      loadFullScreenAd(adId: adId, adType: adType, placementId: placementId, request: request)
    case "banner":
      loadBannerAd(adId: adId, placementId: placementId, request: request)
    case "native":
      loadFeedAd(adId: adId, adType: adType, placementId: placementId, request: request)
    case "draw_native":
      loadFeedAd(adId: adId, adType: adType, placementId: placementId, request: request)
    default:
      emitAdError(adId: adId, adType: adType, placementId: placementId, errorCode: "unknown_ad_type", errorMessage: "Unknown adType: \(adType)")
    }
  }

  /// 展示广告
  ///
  /// - Parameter adId: 广告实例 ID
  func showAd(adId: String) {
    guard let holder = adHolders[adId] else {
      emitLog("error", "showAd failed: adId not found: \(adId)", "ad")
      return
    }
    switch holder {
    case let splash as SplashAdHolder:
      showSplashAd(holder: splash)
    case let reward as RewardAdHolder:
      showRewardAd(holder: reward)
    case let full as FullScreenAdHolder:
      showFullScreenAd(holder: full)
    case is BannerAdHolder:
      emitLog("info", "showAd for banner handled by view", "ad")
    case is FeedAdHolder:
      emitLog("info", "showAd for feed handled by view", "ad")
    default:
      emitLog("warn", "showAd unsupported ad type", "ad")
    }
  }

  /// 销毁广告
  ///
  /// - Parameter adId: 广告实例 ID
  func disposeAd(adId: String) {
    guard let holder = adHolders.removeValue(forKey: adId) else { return }
    switch holder {
    case let splash as SplashAdHolder:
      splash.splashAd?.mediation?.destoryAd()
    case let reward as RewardAdHolder:
      reward.rewardedAd = nil
    case let full as FullScreenAdHolder:
      full.fullscreenAd = nil
    case let banner as BannerAdHolder:
      banner.bannerView?.removeFromSuperview()
      banner.bannerView = nil
    case let feed as FeedAdHolder:
      feed.nativeAd?.unregisterView()
      feed.adsManager?.mediation?.destory()
      feed.nativeAd = nil
      feed.adsManager = nil
    default:
      break
    }
    holder.container?.subviews.forEach { $0.removeFromSuperview() }
    holder.container = nil
    emitLog("info", "disposeAd: \(adId)", "ad")
  }

  /// 清理全部广告实例
  func clearAll() {
    let keys = Array(adHolders.keys)
    keys.forEach { disposeAd(adId: $0) }
  }

  /// 绑定平台视图容器
  ///
  /// - Parameters:
  ///   - adId: 广告实例 ID
  ///   - adType: 广告类型
  ///   - container: 容器视图
  ///   - width: 视图宽度
  ///   - height: 视图高度
  func attachAdView(adId: String, adType: String?, container: UIView, width: CGFloat, height: CGFloat) {
    guard let holder = adHolders[adId] else {
      emitLog("warn", "attachAdView failed: adId not found: \(adId)", "ad")
      return
    }
    holder.container = container
    switch holder {
    case let banner as BannerAdHolder:
      attachBannerView(holder: banner, width: width, height: height)
    case let feed as FeedAdHolder:
      attachFeedView(holder: feed, width: width, height: height)
    default:
      emitLog("warn", "attachAdView unsupported for adType=\(adType ?? "-")", "ad")
    }
  }

  /// 解除平台视图容器绑定
  ///
  /// - Parameter adId: 广告实例 ID
  func detachAdView(adId: String) {
    guard let holder = adHolders[adId] else { return }
    holder.container?.subviews.forEach { $0.removeFromSuperview() }
    holder.container = nil
  }

  // MARK: - 广告加载实现

  private func loadSplashAd(adId: String, placementId: String, request: [String: Any]) {
    let slot = BUAdSlot()
    slot.id = placementId
    let size = UIScreen.main.bounds.size

    let splashAd = BUSplashAd(slot: slot, adSize: size)
    let delegate = SplashDelegate(manager: self, adId: adId, placementId: placementId)
    splashAd.delegate = delegate
    splashAd.cardDelegate = delegate

    let holder = SplashAdHolder(adId: adId, placementId: placementId)
    holder.splashAd = splashAd
    holder.delegate = delegate
    adHolders[adId] = holder

    splashAd.loadData()
  }

  private func loadRewardAd(adId: String, placementId: String, request: [String: Any]) {
    let slot = BUAdSlot()
    slot.id = placementId
    if let muted = readBool(request: request, key: "muted") {
      slot.mediation.mutedIfCan = muted
    }
    if let scenarioId = readString(request: request, key: "scenarioId") {
      slot.mediation.scenarioID = scenarioId
    }
    let model = BURewardedVideoModel()
    model.userId = readString(request: request, key: "userId") ?? ""
    model.rewardName = readString(request: request, key: "rewardName") ?? ""
    model.rewardAmount = readInt(request: request, key: "rewardAmount", fallback: 0)

    let rewardedAd = BUNativeExpressRewardedVideoAd(slot: slot, rewardedVideoModel: model)
    let delegate = RewardDelegate(manager: self, adId: adId, placementId: placementId)
    rewardedAd.delegate = delegate

    let holder = RewardAdHolder(adId: adId, placementId: placementId)
    holder.rewardedAd = rewardedAd
    holder.delegate = delegate
    adHolders[adId] = holder

    rewardedAd.loadData()
  }

  /// 加载插全屏广告
  ///
  /// - Parameters:
  ///   - adId: 广告实例 ID
  ///   - adType: 广告类型（fullscreenVideo/interstitial）
  ///   - placementId: 代码位
  ///   - request: 请求参数
  private func loadFullScreenAd(adId: String, adType: String, placementId: String, request: [String: Any]) {
    let slot = BUAdSlot()
    slot.id = placementId
    if let muted = readBool(request: request, key: "muted") {
      slot.mediation.mutedIfCan = muted
    }
    let fullscreenAd = BUNativeExpressFullscreenVideoAd(slot: slot)
    let delegate = FullscreenDelegate(manager: self, adId: adId, placementId: placementId)
    fullscreenAd.delegate = delegate

    let holder = FullScreenAdHolder(adId: adId, placementId: placementId, adType: adType)
    holder.fullscreenAd = fullscreenAd
    holder.delegate = delegate
    adHolders[adId] = holder

    fullscreenAd.loadData()
  }

  private func loadBannerAd(adId: String, placementId: String, request: [String: Any]) {
    let width = CGFloat(readInt(request: request, key: "width", fallback: 320))
    let height = CGFloat(readInt(request: request, key: "height", fallback: 150))
    let slot = BUAdSlot()
    slot.id = placementId
    if let muted = readBool(request: request, key: "muted") {
      slot.mediation.mutedIfCan = muted
    }

    guard let rootVC = topViewController() else {
      emitAdError(adId: adId, adType: "banner", placementId: placementId, errorCode: "no_root_view_controller", errorMessage: "Banner rootViewController is nil.")
      return
    }
    let bannerView = BUNativeExpressBannerView(slot: slot, rootViewController: rootVC, adSize: CGSize(width: width, height: height))
    let delegate = BannerDelegate(manager: self, adId: adId, placementId: placementId)
    bannerView.delegate = delegate

    let holder = BannerAdHolder(adId: adId, placementId: placementId)
    holder.bannerView = bannerView
    holder.delegate = delegate
    holder.adSize = CGSize(width: width, height: height)
    adHolders[adId] = holder

    bannerView.loadAdData()
  }

  private func loadFeedAd(adId: String, adType: String, placementId: String, request: [String: Any]) {
    let width = CGFloat(readInt(request: request, key: "width", fallback: Int(UIScreen.main.bounds.size.width)))
    let height = CGFloat(readInt(request: request, key: "height", fallback: 400))
    let count = readInt(request: request, key: "adCount", fallback: 1)
    let slot = BUAdSlot()
    slot.id = placementId
    slot.adSize = CGSize(width: width, height: height)
    if let muted = readBool(request: request, key: "muted") {
      slot.mediation.mutedIfCan = muted
    }

    let adsManager = BUNativeAdsManager(slot: slot)
    let delegate = FeedDelegate(manager: self, adId: adId, adType: adType, placementId: placementId)
    adsManager.delegate = delegate
    adsManager.mediation?.rootViewController = topViewController()

    let holder = FeedAdHolder(adId: adId, placementId: placementId, adType: adType)
    holder.adsManager = adsManager
    holder.delegate = delegate
    adHolders[adId] = holder

    adsManager.loadAdData(withCount: count)
  }

  // MARK: - 展示实现

  private func showSplashAd(holder: SplashAdHolder) {
    guard let ad = holder.splashAd else { return }
    guard let rootVC = topViewController() else {
      emitLog("error", "showSplashAd failed: rootViewController is nil", "ad")
      return
    }
    ad.showSplashView(inRootViewController: rootVC)
  }

  private func showRewardAd(holder: RewardAdHolder) {
    guard let ad = holder.rewardedAd else { return }
    guard let rootVC = topViewController() else {
      emitLog("error", "showRewardAd failed: rootViewController is nil", "ad")
      return
    }
    _ = ad.show(fromRootViewController: rootVC)
  }

  private func showFullScreenAd(holder: FullScreenAdHolder) {
    guard let ad = holder.fullscreenAd else { return }
    guard let rootVC = topViewController() else {
      emitLog("error", "showFullScreenAd failed: rootViewController is nil", "ad")
      return
    }
    _ = ad.show(fromRootViewController: rootVC)
  }

  private func attachBannerView(holder: BannerAdHolder, width: CGFloat, height: CGFloat) {
    guard let bannerView = holder.bannerView, let container = holder.container else { return }
    bannerView.frame = container.bounds
    bannerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.subviews.forEach { $0.removeFromSuperview() }
    container.addSubview(bannerView)
  }

  private func attachFeedView(holder: FeedAdHolder, width: CGFloat, height: CGFloat) {
    guard let nativeAd = holder.nativeAd else { return }
    if nativeAd.mediation?.isExpressAd != true {
      emitLog("warn", "feed ad is native render, current plugin only supports express by default", "ad")
      return
    }
    guard let container = holder.container else { return }
    guard let canvasView = nativeAd.mediation?.canvasView else { return }
    canvasView.frame = container.bounds
    canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.subviews.forEach { $0.removeFromSuperview() }
    container.addSubview(canvasView)
  }

  // MARK: - 事件上报

  private func emitAdLoaded(adId: String, adType: String, placementId: String, data: [String: Any]? = nil) {
    var payload: [String: Any] = [
      "adId": adId,
      "adType": adType,
      "eventType": "loaded",
      "placementId": placementId
    ]
    var mergedData = data ?? [:]
    if let ecpmInfo = buildEcpmInfo(adId: adId) {
      mergedData["ecpmInfo"] = ecpmInfo
    }
    if !mergedData.isEmpty {
      payload["data"] = mergedData
    }
    postAdEvent(payload)
  }

  private func emitAdShown(adId: String, adType: String, placementId: String, data: [String: Any]? = nil) {
    var payload: [String: Any] = [
      "adId": adId,
      "adType": adType,
      "eventType": "shown",
      "placementId": placementId
    ]
    var mergedData = data ?? [:]
    if let ecpmInfo = buildEcpmInfo(adId: adId) {
      mergedData["ecpmInfo"] = ecpmInfo
    }
    if !mergedData.isEmpty {
      payload["data"] = mergedData
    }
    postAdEvent(payload)
  }

  private func emitAdClicked(adId: String, adType: String, placementId: String) {
    postAdEvent([
      "adId": adId,
      "adType": adType,
      "eventType": "clicked",
      "placementId": placementId
    ])
  }

  private func emitAdClosed(adId: String, adType: String, placementId: String, data: [String: Any]? = nil) {
    var payload: [String: Any] = [
      "adId": adId,
      "adType": adType,
      "eventType": "closed",
      "placementId": placementId
    ]
    if let data = data { payload["data"] = data }
    postAdEvent(payload)
  }

  private func emitAdRewarded(adId: String, adType: String, placementId: String, data: [String: Any]? = nil) {
    var payload: [String: Any] = [
      "adId": adId,
      "adType": adType,
      "eventType": "rewarded",
      "placementId": placementId
    ]
    if let data = data { payload["data"] = data }
    postAdEvent(payload)
  }

  private func emitAdError(adId: String, adType: String, placementId: String, errorCode: String?, errorMessage: String?) {
    postAdEvent([
      "adId": adId,
      "adType": adType,
      "eventType": "failed",
      "placementId": placementId,
      "errorCode": errorCode as Any,
      "errorMessage": errorMessage as Any
    ])
  }

  /// 获取广告展示 Ecpm 信息
  ///
  /// - Parameter adId: 广告实例 ID
  private func buildEcpmInfo(adId: String) -> [String: Any]? {
    guard let holder = adHolders[adId] else { return nil }
    let info: BUMRitInfo?
    switch holder {
    case let splash as SplashAdHolder:
      info = splash.splashAd?.mediation?.getShowEcpmInfo()
    case let reward as RewardAdHolder:
      info = reward.rewardedAd?.mediation?.getShowEcpmInfo()
    case let full as FullScreenAdHolder:
      info = full.fullscreenAd?.mediation?.getShowEcpmInfo()
    case let banner as BannerAdHolder:
      info = banner.bannerView?.mediation?.getShowEcpmInfo()
    case let feed as FeedAdHolder:
      info = feed.nativeAd?.mediation?.getShowEcpmInfo()
    default:
      info = nil
    }
    return buildEcpmInfo(info)
  }

  /// 将 Ecpm 信息转为 Map
  ///
  /// - Parameter info: Ecpm 信息对象
  private func buildEcpmInfo(_ info: BUMRitInfo?) -> [String: Any]? {
    guard let info = info else { return nil }
    let subChannel = info.value(forKey: "sub_channel")
    return [
      "sdkName": info.adnName,
      "customSdkName": info.customAdnName as Any,
      "slotId": info.slotID,
      "ecpm": info.ecpm as Any,
      "reqBiddingType": info.biddingType.rawValue,
      "levelTag": info.levelTag as Any,
      "errorMsg": info.errorMsg as Any,
      "requestId": info.requestID as Any,
      "creativeId": info.creativeID as Any,
      "ritType": info.adRitType as Any,
      "abTestId": info.abtestId as Any,
      "segmentId": info.segmentId as Any,
      "channel": info.channel as Any,
      "subChannel": subChannel as Any,
      "scenarioId": info.scenarioId as Any,
      "subRitType": info.subRitType as Any
    ]
  }

  /// 发送广告事件（切到主线程）
  private func postAdEvent(_ payload: [String: Any]) {
    DispatchQueue.main.async {
      self.emitAdEvent(payload)
    }
  }

  // MARK: - 工具方法

  private func topViewController() -> UIViewController? {
    if #available(iOS 13.0, *) {
      let scenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
      for scene in scenes {
        if let window = scene.windows.first(where: { $0.isKeyWindow }),
           let root = window.rootViewController {
          return topViewController(from: root)
        }
      }
    }
    if let window = UIApplication.shared.keyWindow, let root = window.rootViewController {
      return topViewController(from: root)
    }
    return nil
  }

  private func topViewController(from root: UIViewController) -> UIViewController {
    if let presented = root.presentedViewController {
      return topViewController(from: presented)
    }
    if let nav = root as? UINavigationController, let top = nav.topViewController {
      return topViewController(from: top)
    }
    if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
      return topViewController(from: selected)
    }
    return root
  }

  private func readInt(request: [String: Any], key: String, fallback: Int) -> Int {
    let extra = request["extra"] as? [String: Any] ?? [:]
    let iosOptions = request["iosOptions"] as? [String: Any] ?? [:]
    let value = iosOptions[key] ?? extra[key]
    if let number = value as? NSNumber { return number.intValue }
    if let str = value as? String { return Int(str) ?? fallback }
    return fallback
  }

  private func readString(request: [String: Any], key: String) -> String? {
    let extra = request["extra"] as? [String: Any] ?? [:]
    let iosOptions = request["iosOptions"] as? [String: Any] ?? [:]
    return (iosOptions[key] as? String) ?? (extra[key] as? String)
  }

  private func readBool(request: [String: Any], key: String) -> Bool? {
    let extra = request["extra"] as? [String: Any] ?? [:]
    let iosOptions = request["iosOptions"] as? [String: Any] ?? [:]
    if let boolVal = iosOptions[key] as? Bool { return boolVal }
    if let boolVal = extra[key] as? Bool { return boolVal }
    return nil
  }

  // MARK: - 广告实例模型

  /// 广告基类
  class GromoreAdHolder {
    /// 广告实例 ID
    let adId: String
    /// 代码位
    let placementId: String
    /// 广告类型
    let adType: String
    /// 视图容器
    weak var container: UIView?

    init(adId: String, placementId: String, adType: String) {
      self.adId = adId
      self.placementId = placementId
      self.adType = adType
    }
  }

  /// 开屏广告实例
  final class SplashAdHolder: GromoreAdHolder {
    var splashAd: BUSplashAd?
    var delegate: SplashDelegate?

    init(adId: String, placementId: String) {
      super.init(adId: adId, placementId: placementId, adType: "splash")
    }
  }

  /// 激励视频广告实例
  final class RewardAdHolder: GromoreAdHolder {
    var rewardedAd: BUNativeExpressRewardedVideoAd?
    var delegate: RewardDelegate?

    init(adId: String, placementId: String) {
      super.init(adId: adId, placementId: placementId, adType: "rewardVideo")
    }
  }

  /// 插全屏广告实例
  final class FullScreenAdHolder: GromoreAdHolder {
    var fullscreenAd: BUNativeExpressFullscreenVideoAd?
    var delegate: FullscreenDelegate?

    override init(adId: String, placementId: String, adType: String) {
      super.init(adId: adId, placementId: placementId, adType: adType)
    }
  }

  /// Banner 广告实例
  final class BannerAdHolder: GromoreAdHolder {
    var bannerView: BUNativeExpressBannerView?
    var delegate: BannerDelegate?
    var adSize: CGSize = .zero

    init(adId: String, placementId: String) {
      super.init(adId: adId, placementId: placementId, adType: "banner")
    }
  }

  /// 信息流广告实例
  final class FeedAdHolder: GromoreAdHolder {
    var adsManager: BUNativeAdsManager?
    var nativeAd: BUNativeAd?
    var delegate: FeedDelegate?

    override init(adId: String, placementId: String, adType: String = "native") {
      super.init(adId: adId, placementId: placementId, adType: adType)
    }
  }

  // MARK: - Delegate 实现

  /// 开屏代理
  final class SplashDelegate: NSObject, BUSplashAdDelegate, BUSplashCardDelegate {
    weak var manager: GromoreAdManager?
    let adId: String
    let placementId: String

    init(manager: GromoreAdManager, adId: String, placementId: String) {
      self.manager = manager
      self.adId = adId
      self.placementId = placementId
    }

    func splashAdLoadSuccess(_ splashAd: BUSplashAd) {
      manager?.emitLog("info", "splash load success: \(adId)", "ad")
      manager?.emitAdLoaded(adId: adId, adType: "splash", placementId: placementId)
    }

    func splashAdLoadFail(_ splashAd: BUSplashAd, error: BUAdError?) {
      let code = error?.errorCode.rawValue ?? error?._code ?? 0
      let message = error?.localizedDescription
      manager?.emitLog("error", "splash load fail: \(adId), code=\(code)", "ad")
      manager?.emitAdError(adId: adId, adType: "splash", placementId: placementId, errorCode: "\(code)", errorMessage: message)
    }

    func splashAdRenderSuccess(_ splashAd: BUSplashAd) {
      manager?.emitLog("info", "splash render success: \(adId)", "ad")
    }

    func splashAdRenderFail(_ splashAd: BUSplashAd, error: BUAdError?) {
      let code = error?.errorCode.rawValue ?? error?._code ?? 0
      manager?.emitLog("error", "splash render fail: \(adId), code=\(code)", "ad")
      manager?.emitAdError(adId: adId, adType: "splash", placementId: placementId, errorCode: "\(code)", errorMessage: error?.localizedDescription)
    }

    func splashAdWillShow(_ splashAd: BUSplashAd) {
      manager?.emitLog("info", "splash will show: \(adId)", "ad")
    }

    func splashAdDidShow(_ splashAd: BUSplashAd) {
      manager?.emitAdShown(adId: adId, adType: "splash", placementId: placementId)
    }

    func splashAdDidClick(_ splashAd: BUSplashAd) {
      manager?.emitAdClicked(adId: adId, adType: "splash", placementId: placementId)
    }

    func splashAdDidClose(_ splashAd: BUSplashAd, closeType: BUSplashAdCloseType) {
      let closeTypeName: String
      switch closeType {
      case .clickSkip: closeTypeName = "click_skip"
      case .countdownToZero: closeTypeName = "count_down_over"
      case .clickAd: closeTypeName = "click_ad"
      case .forceQuit: closeTypeName = "force_quit"
      @unknown default: closeTypeName = "\(closeType.rawValue)"
      }
      manager?.emitAdClosed(adId: adId, adType: "splash", placementId: placementId, data: ["closeType": closeTypeName])
      splashAd.mediation?.destoryAd()
    }

    func splashAdViewControllerDidClose(_ splashAd: BUSplashAd) {
      manager?.emitLog("info", "splash view controller closed: \(adId)", "ad")
    }

    func splashDidCloseOtherController(_ splashAd: BUSplashAd, interactionType: BUInteractionType) {
      manager?.emitLog("info", "splash did close other controller: \(adId), type=\(interactionType.rawValue)", "ad")
    }

    func splashVideoAdDidPlayFinish(_ splashAd: BUSplashAd, didFailWithError error: Error?) {
      if let error = error {
        manager?.emitAdError(adId: adId, adType: "splash", placementId: placementId, errorCode: "\(error._code)", errorMessage: error.localizedDescription)
      } else {
        manager?.emitLog("info", "splash video play finished: \(adId)", "ad")
      }
    }

    func splashAdDidShowFailed(_ splashAd: BUSplashAd, error: Error) {
      manager?.emitAdError(adId: adId, adType: "splash", placementId: placementId, errorCode: "show_failed", errorMessage: error.localizedDescription)
    }

    func splashCardReady(toShow splashAd: BUSplashAd) {
      manager?.emitLog("info", "splash card ready: \(adId)", "ad")
    }

    func splashCardViewDidClick(_ splashAd: BUSplashAd) {
      manager?.emitAdClicked(adId: adId, adType: "splash", placementId: placementId)
    }

    func splashCardViewDidClose(_ splashAd: BUSplashAd) {
      manager?.emitAdClosed(adId: adId, adType: "splash", placementId: placementId, data: ["closeType": "card_close"])
    }
  }

  /// 激励视频代理
  final class RewardDelegate: NSObject, BUMNativeExpressRewardedVideoAdDelegate {
    weak var manager: GromoreAdManager?
    let adId: String
    let placementId: String

    init(manager: GromoreAdManager, adId: String, placementId: String) {
      self.manager = manager
      self.adId = adId
      self.placementId = placementId
    }

    func nativeExpressRewardedVideoAdDidLoad(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
      manager?.emitAdLoaded(adId: adId, adType: "rewardVideo", placementId: placementId)
    }

    func nativeExpressRewardedVideoAd(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
      manager?.emitAdError(adId: adId, adType: "rewardVideo", placementId: placementId, errorCode: "\(error?._code ?? 0)", errorMessage: error?.localizedDescription)
    }

    func nativeExpressRewardedVideoAdDidVisible(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
      manager?.emitAdShown(adId: adId, adType: "rewardVideo", placementId: placementId)
    }

    func nativeExpressRewardedVideoAdDidClick(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
      manager?.emitAdClicked(adId: adId, adType: "rewardVideo", placementId: placementId)
    }

    func nativeExpressRewardedVideoAdDidClose(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
      manager?.emitAdClosed(adId: adId, adType: "rewardVideo", placementId: placementId)
    }

    /// 激励广告展示失败
    ///
    /// - Parameters:
    ///   - rewardedVideoAd: 广告对象
    ///   - error: 失败原因
    func nativeExpressRewardedVideoAdDidShowFailed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error) {
      manager?.emitAdError(adId: adId, adType: "rewardVideo", placementId: placementId, errorCode: "show_failed", errorMessage: error.localizedDescription)
    }

    func nativeExpressRewardedVideoAdServerRewardDidSucceed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, verify: Bool) {
      let model = rewardedVideoAd.rewardedVideoModel
      let data: [String: Any] = [
        "verify": verify,
        "userId": model.userId ?? "",
        "rewardName": model.rewardName ?? "",
        "rewardAmount": model.rewardAmount,
        "rewardId": model.mediation.rewardId ?? "",
        "tradeId": model.mediation.tradeId ?? "",
        "adnName": model.mediation.adnName ?? "",
        "verifyByGroMoreS2S": model.mediation.verifyByGroMoreS2S
      ]
      manager?.emitAdRewarded(adId: adId, adType: "rewardVideo", placementId: placementId, data: data)
    }

    func nativeExpressRewardedVideoAdServerRewardDidFail(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error?) {
      manager?.emitAdError(adId: adId, adType: "rewardVideo", placementId: placementId, errorCode: "\(error?._code ?? 0)", errorMessage: error?.localizedDescription)
    }
  }

  /// 插全屏代理
  final class FullscreenDelegate: NSObject, BUMNativeExpressFullscreenVideoAdDelegate {
    weak var manager: GromoreAdManager?
    let adId: String
    let placementId: String

    init(manager: GromoreAdManager, adId: String, placementId: String) {
      self.manager = manager
      self.adId = adId
      self.placementId = placementId
    }

    func nativeExpressFullscreenVideoAdDidLoad(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
      manager?.emitAdLoaded(adId: adId, adType: "fullscreenVideo", placementId: placementId)
    }

    func nativeExpressFullscreenVideoAd(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd, didFailWithError error: Error?) {
      manager?.emitAdError(adId: adId, adType: "fullscreenVideo", placementId: placementId, errorCode: "\(error?._code ?? 0)", errorMessage: error?.localizedDescription)
    }

    func nativeExpressFullscreenVideoAdDidVisible(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
      manager?.emitAdShown(adId: adId, adType: "fullscreenVideo", placementId: placementId)
    }

    func nativeExpressFullscreenVideoAdDidClick(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
      manager?.emitAdClicked(adId: adId, adType: "fullscreenVideo", placementId: placementId)
    }

    func nativeExpressFullscreenVideoAdDidClose(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
      manager?.emitAdClosed(adId: adId, adType: "fullscreenVideo", placementId: placementId)
    }

    /// 插全屏广告展示失败
    ///
    /// - Parameters:
    ///   - fullscreenVideoAd: 广告对象
    ///   - error: 失败原因
    func nativeExpressFullscreenVideoAdDidShowFailed(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd, error: Error) {
      manager?.emitAdError(adId: adId, adType: "fullscreenVideo", placementId: placementId, errorCode: "show_failed", errorMessage: error.localizedDescription)
    }
  }

  /// Banner 代理
  final class BannerDelegate: NSObject, BUMNativeExpressBannerViewDelegate {
    weak var manager: GromoreAdManager?
    let adId: String
    let placementId: String

    init(manager: GromoreAdManager, adId: String, placementId: String) {
      self.manager = manager
      self.adId = adId
      self.placementId = placementId
    }

    func nativeExpressBannerAdViewDidLoad(_ bannerAdView: BUNativeExpressBannerView) {
      manager?.emitAdLoaded(adId: adId, adType: "banner", placementId: placementId)
    }

    func nativeExpressBannerAdView(_ bannerAdView: BUNativeExpressBannerView, didLoadFailWithError error: Error?) {
      let code = (error as NSError?)?._code ?? 0
      manager?.emitAdError(adId: adId, adType: "banner", placementId: placementId, errorCode: "\(code)", errorMessage: error?.localizedDescription)
    }

    func nativeExpressBannerAdViewDidBecomeVisible(_ bannerAdView: BUNativeExpressBannerView) {
      manager?.emitAdShown(adId: adId, adType: "banner", placementId: placementId)
    }

    func nativeExpressBannerAdViewDidClick(_ bannerAdView: BUNativeExpressBannerView) {
      manager?.emitAdClicked(adId: adId, adType: "banner", placementId: placementId)
    }

    func nativeExpressBannerAdViewDidRemoved(_ nativeExpressAdView: BUNativeExpressBannerView) {
      manager?.emitAdClosed(adId: adId, adType: "banner", placementId: placementId)
    }
  }

  /// 信息流代理
  final class FeedDelegate: NSObject, BUMNativeAdsManagerDelegate, BUMNativeAdDelegate, BUCustomEventProtocol {
    weak var manager: GromoreAdManager?
    let adId: String
    let adType: String
    let placementId: String

    init(manager: GromoreAdManager, adId: String, adType: String, placementId: String) {
      self.manager = manager
      self.adId = adId
      self.adType = adType
      self.placementId = placementId
    }

    func nativeAdsManagerSuccess(toLoad adsManager: BUNativeAdsManager, nativeAds nativeAdDataArray: [BUNativeAd]?) {
      guard let ad = nativeAdDataArray?.first else {
        manager?.emitAdError(adId: adId, adType: adType, placementId: placementId, errorCode: "empty_ad", errorMessage: "No feed ad returned.")
        return
      }
      if let holder = manager?.adHolders[adId] as? FeedAdHolder {
        holder.nativeAd = ad
        ad.rootViewController = manager?.topViewController()
        ad.delegate = self
      }
      manager?.emitAdLoaded(adId: adId, adType: adType, placementId: placementId)
      if ad.mediation?.isExpressAd == true {
        ad.mediation?.render()
      } else {
        manager?.emitLog("warn", "feed ad is native render, current plugin only supports express by default", "ad")
      }
    }

    func nativeAdsManager(_ adsManager: BUNativeAdsManager, didFailWithError error: Error?) {
      manager?.emitAdError(adId: adId, adType: adType, placementId: placementId, errorCode: "\(error?._code ?? 0)", errorMessage: error?.localizedDescription)
    }

    func nativeAdExpressViewRenderSuccess(_ nativeAd: BUNativeAd) {
      if let holder = manager?.adHolders[adId] as? FeedAdHolder {
        holder.nativeAd = nativeAd
        manager?.attachFeedView(holder: holder, width: holder.container?.bounds.size.width ?? 0, height: holder.container?.bounds.size.height ?? 0)
      }
    }

    func nativeAdExpressViewRenderFail(_ nativeAd: BUNativeAd, error: Error?) {
      manager?.emitAdError(adId: adId, adType: adType, placementId: placementId, errorCode: "\(error?._code ?? 0)", errorMessage: error?.localizedDescription)
    }

    func nativeAdDidBecomeVisible(_ nativeAd: BUNativeAd) {
      manager?.emitAdShown(adId: adId, adType: adType, placementId: placementId)
    }

    func nativeAdDidClick(_ nativeAd: BUNativeAd, with view: UIView?) {
      manager?.emitAdClicked(adId: adId, adType: adType, placementId: placementId)
    }

    func nativeAd(_ nativeAd: BUNativeAd?, adContainerViewDidRemoved adContainerView: UIView) {
      manager?.emitAdClosed(adId: adId, adType: adType, placementId: placementId)
    }

    func nativeAdWillPresentFullScreenModal(_ nativeAd: BUNativeAd) {
      manager?.emitLog("info", "feed will present full screen: \(adId)", "ad")
    }

    func nativeAdVideo(_ nativeAd: BUNativeAd?, stateDidChanged playerState: BUPlayerPlayState) {
      manager?.emitLog("info", "feed video state changed: \(adId) state=\(playerState.rawValue)", "ad")
    }

    func nativeAdVideoDidClick(_ nativeAd: BUNativeAd?) {
      manager?.emitLog("info", "feed video clicked: \(adId)", "ad")
    }

    func nativeAdVideoDidPlayFinish(_ nativeAd: BUNativeAd?) {
      manager?.emitLog("info", "feed video finished: \(adId)", "ad")
    }

    func nativeAdShakeViewDidDismiss(_ nativeAd: BUNativeAd?) {
      manager?.emitLog("info", "feed shake view dismissed: \(adId)", "ad")
    }

    func nativeAdVideo(_ nativeAdView: BUNativeAd?, rewardDidCountDown countDown: NSInteger) {
      manager?.emitLog("info", "feed reward countdown: \(adId) count=\(countDown)", "ad")
    }
  }
}
