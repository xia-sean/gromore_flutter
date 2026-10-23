import Foundation
import UIKit
import BUAdSDK
import Flutter

/// GroMore 广告管理器（iOS）
final class GromoreAdManager: NSObject {
  /// 广告事件回调
  private let emitAdEvent: ([String: Any]) -> Void
  /// 日志回调
  private let emitLog: (String, String, String) -> Void
  /// 广告实例缓存
  private var adHolders: [String: GromoreAdHolder]

  /// 构建广告管理器
  ///
  /// - Parameters:
  ///   - emitAdEvent: 广告事件回调
  ///   - emitLog: 日志回调
  init(
    emitAdEvent: @escaping ([String: Any]) -> Void,
    emitLog: @escaping (String, String, String) -> Void,
    adHolders: [String: GromoreAdHolder] = [:]
  ) {
    self.emitAdEvent = emitAdEvent
    self.emitLog = emitLog
    self.adHolders = adHolders
  }

  /// 生成新的广告实例 ID
  func newAdId() -> String {
    return UUID().uuidString
  }

  private func failShow(_ holder: GromoreAdHolder, code: String, message: String) throws -> Never {
    emitAdError(adId: holder.adId, adType: holder.adType, placementId: holder.placementId, errorCode: code, errorMessage: message, phase: "show")
    throw GromoreAdFailure(code: code, message: message)
  }

  private func requireHolder(_ id: String) throws -> GromoreAdHolder {
    guard let holder = adHolders[id] else {
      throw GromoreAdFailure(code: "ad_not_found", message: "Unknown adId: \(id)")
    }
    return holder
  }

  func adState(adId: String) throws -> [String: Any] {
    let holder = try requireHolder(adId)
    var ready = false
    var loading = holder.loading
    switch holder {
    case let holder as SplashAdHolder:
      ready = holder.splashAd?.mediation?.isReady == true
      loading = holder.splashAd?.mediation?.isLoading ?? loading
    case let holder as RewardAdHolder:
      ready = holder.rewardedAd?.mediation?.isReady == true
      loading = holder.rewardedAd?.mediation?.isLoading ?? loading
    case let holder as FullScreenAdHolder:
      ready = holder.fullscreenAd?.mediation?.isReady == true
      loading = holder.fullscreenAd?.mediation?.isLoading ?? loading
    case let holder as BannerAdHolder:
      ready = holder.bannerView?.mediation?.isReady == true
      loading = holder.bannerView?.mediation?.isLoading ?? loading
    case let holder as FeedAdHolder:
      ready = holder.nativeAd?.mediation?.isReady == true
      loading = holder.adsManager?.mediation?.isLoading ?? loading
    default: break
    }
    return ["isReady": ready, "isLoading": loading]
  }

  func operation(_ method: String, args: [String: Any]) throws -> Any? {
    guard let id = args["adId"] as? String else {
      throw GromoreAdFailure(code: "invalid_args", message: "adId required")
    }
    let holder = try requireHolder(id)
    switch method {
    case "getAdIds": return holder.batchIds.filter { adHolders[$0] != nil }
    case "getAdState": return try adState(adId: id)
    case "getAdDiagnostics": return diagnostics(holder)
    case "controlVideo":
      guard let feed = holder as? FeedAdHolder else {
        throw GromoreAdFailure(code: "unsupported", message: "Requires Feed/Draw")
      }
      switch args["action"] as? String {
      case "play", "resume": feed.videoAction = "play"
      case "pause": feed.videoAction = "pause"
      case "stop": feed.videoAction = "stop"
      default: throw GromoreAdFailure(code: "unsupported", message: "Unknown video action")
      }
      syncFeedVideo(feed)
    case "showSplashCard":
      guard let ad = (holder as? SplashAdHolder)?.splashAd, ad.cardView != nil,
            let root = topViewController() else {
        throw GromoreAdFailure(code: "not_ready", message: "Splash card is unavailable")
      }
      ad.showCardView(inRootViewController: root)
    case "hideSplashSkipButton":
      guard let ad = (holder as? SplashAdHolder)?.splashAd else {
        throw GromoreAdFailure(code: "unsupported", message: "Requires splash ad")
      }
      ad.hideSkipButton = true
    default: throw GromoreAdFailure(code: "not_implemented", message: method)
    }
    return nil
  }

  private func diagnostics(_ holder: GromoreAdHolder) -> [String: Any] {
    var best: BUMRitInfo?
    var bidding: [BUMRitInfo]?
    var cache: [BUMRitInfo]?
    switch holder {
    case let holder as SplashAdHolder:
      let mediation = holder.splashAd?.mediation
      best = mediation?.getCurrentBestEcpmInfo()
      bidding = mediation?.multiBiddingEcpmInfos()
      cache = mediation?.cacheRitList()
    case let holder as RewardAdHolder:
      let mediation = holder.rewardedAd?.mediation
      best = mediation?.getCurrentBestEcpmInfo()
      bidding = mediation?.multiBiddingEcpmInfos()
      cache = mediation?.cacheRitList()
    case let holder as FullScreenAdHolder:
      let mediation = holder.fullscreenAd?.mediation
      best = mediation?.getCurrentBestEcpmInfo()
      bidding = mediation?.multiBiddingEcpmInfos()
      cache = mediation?.cacheRitList()
    case let holder as BannerAdHolder:
      let mediation = holder.bannerView?.mediation
      best = mediation?.getCurrentBestEcpmInfo()
      bidding = mediation?.multiBiddingEcpmInfos()
      cache = mediation?.cacheRitList()
    case let holder as FeedAdHolder:
      best = holder.nativeAd?.mediation?.getCurrentBestEcpmInfo()
      bidding = holder.nativeAd?.mediation?.multiBiddingEcpmInfos()
      cache = holder.nativeAd?.mediation?.cacheRitList()
    default: break
    }
    var result: [String: Any] = [:]
    result["bestEcpm"] = buildEcpmInfo(best)
    result["showEcpm"] = buildEcpmInfo(adId: holder.adId)
    result["multiBiddingEcpm"] = bidding?.compactMap { buildEcpmInfo($0) }
    result["cacheList"] = cache?.compactMap { buildEcpmInfo($0) }
    result.merge(loadDiagnostics(holder)) { _, new in new }
    return result
  }

  /// 失败事件发送前读取，避免 Dart 自动销毁实例后丢失各 ADN 的错误信息。
  private func loadDiagnostics(_ holder: GromoreAdHolder) -> [String: Any] {
    var loads: [BUMAdLoadInfo]?
    var failures: [[AnyHashable: Any]]?
    switch holder {
    case let holder as SplashAdHolder:
      loads = holder.splashAd?.mediation?.getAdLoadInfoList()
      failures = holder.splashAd?.mediation?.waterfallFillFailMessages()
    case let holder as RewardAdHolder:
      loads = holder.rewardedAd?.mediation?.getAdLoadInfoList()
      failures = holder.rewardedAd?.mediation?.waterfallFillFailMessages()
    case let holder as FullScreenAdHolder:
      loads = holder.fullscreenAd?.mediation?.getAdLoadInfoList()
      failures = holder.fullscreenAd?.mediation?.waterfallFillFailMessages()
    case let holder as BannerAdHolder:
      loads = holder.bannerView?.mediation?.getAdLoadInfoList()
      failures = holder.bannerView?.mediation?.waterfallFillFailMessages()
    case let holder as FeedAdHolder:
      loads = holder.adsManager?.mediation?.getAdLoadInfoList()
      failures = holder.adsManager?.mediation?.waterfallFillFailMessages()
    default: break
    }
    return [
      "loadInfo": loads?.map {
        ["mediationRit": $0.mediationRit, "adnName": $0.adnName,
         "errCode": $0.errCode, "errMsg": $0.errMsg] as [String: Any]
      } ?? [],
      "waterfallFillFailMessages": Self.channelValue(failures ?? [])
    ]
  }

  /// SDK 的瀑布流错误可能含 NSError 等对象，先转换为通道支持的值。
  private static func channelValue(_ value: Any) -> Any {
    if let error = value as? NSError {
      return ["domain": error.domain, "code": error.code,
        "message": error.localizedDescription] as [String: Any]
    }
    if let map = value as? [AnyHashable: Any] {
      return Dictionary(map.map { (String(describing: $0.key), channelValue($0.value)) },
        uniquingKeysWith: { _, new in new })
    }
    if let array = value as? [Any] { return array.map { channelValue($0) } }
    if value is String || value is NSNumber || value is NSNull { return value }
    return String(describing: value)
  }

  private func emitExtra(_ id: String, _ event: String, _ data: [String: Any] = [:]) {
    guard let holder = adHolders[id] else { return }
    postAdEvent(["adId": id, "adType": holder.adType, "placementId": holder.placementId,
      "eventType": event, "data": data])
  }

  /// 加载广告
  ///
  /// - Parameters:
  ///   - adId: 广告实例 ID
  ///   - adType: 广告类型
  ///   - placementId: 代码位
  ///   - request: 请求参数
  func loadAd(adId: String, adType: String, placementId: String, request: [String: Any]) {
    if let id = GromoreAdRequestOptions(request: request).string("nativeRenderFactoryId") {
      let registered = adType == "banner" ? GromoreNativeRenderRegistry.bannerFactory(id) != nil
        : (["native", "draw_native"].contains(adType) && GromoreNativeRenderRegistry.factory(id) != nil)
      if !registered {
        emitAdError(adId: adId, adType: adType, placementId: placementId,
          errorCode: "factory_not_found", errorMessage: "No native factory for \(adType): \(id)")
        return
      }
    }
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
      loadDrawAd(adId: adId, adType: adType, placementId: placementId, request: request)
    default:
      emitAdError(adId: adId, adType: adType, placementId: placementId, errorCode: "unknown_ad_type", errorMessage: "Unknown adType: \(adType)")
    }
  }

  /// 展示广告
  ///
  /// - Parameter adId: 广告实例 ID
  func showAd(adId: String) throws {
    guard let holder = adHolders[adId] else {
      throw GromoreAdFailure(code: "ad_not_found", message: "Unknown adId: \(adId)")
    }
    if topViewController() == nil {
      try failShow(holder, code: "no_root_view_controller", message: "No view controller")
    }
    if !(try adState(adId: adId)["isReady"] as? Bool ?? false) {
      try failShow(holder, code: "not_ready", message: "Ad is not ready")
    }
    switch holder {
    case let splash as SplashAdHolder:
      try showSplashAd(holder: splash)
    case let reward as RewardAdHolder:
      try showRewardAd(holder: reward)
    case let full as FullScreenAdHolder:
      try showFullScreenAd(holder: full)
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
      splash.splashAd?.delegate = nil
      splash.splashAd?.mediation?.destoryAd()
      splash.splashAd = nil
    case let reward as RewardAdHolder:
      reward.rewardedAd?.delegate = nil
      reward.rewardedAd?.rewardPlayAgainInteractionDelegate = nil
      dismissAdPresentation(holder)
      reward.rewardedAd = nil
    case let full as FullScreenAdHolder:
      full.fullscreenAd?.delegate = nil
      dismissAdPresentation(holder)
      full.fullscreenAd = nil
    case let banner as BannerAdHolder:
      banner.bannerView?.delegate = nil
      banner.bannerView?.mediation?.destory()
      banner.bannerView?.removeFromSuperview()
      banner.bannerView = nil
    case let feed as FeedAdHolder:
      feed.nativeAd?.delegate = nil
      performFeedVideoAction(feed, action: "stop")
      feed.nativeAd?.unregisterView()
      feed.nativeAd?.mediation?.canvasView.removeFromSuperview()
      if !adHolders.values.contains(where: { ($0 as? FeedAdHolder)?.adsManager === feed.adsManager }) {
        feed.adsManager?.mediation?.destory()
      }
      feed.nativeAd = nil
      feed.adsManager = nil
    default:
      break
    }
    holder.container?.subviews.forEach { $0.removeFromSuperview() }
    holder.container = nil
    emitLog("info", "disposeAd: \(adId)", "ad")
  }

  private func dismissAdPresentation(_ holder: GromoreAdHolder) {
    // 只关闭 show 时记录的广告控制器，避免误关宿主页面。
    if let controller = holder.presentedAdController,
       let presenter = controller.presentingViewController,
       presenter.presentedViewController === controller,
       !controller.isBeingDismissed {
      controller.dismiss(animated: false)
    }
    holder.presentedAdController = nil
    holder.presentationRoot = nil
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
      syncFeedVideo(feed)
    default:
      emitLog("warn", "attachAdView unsupported for adType=\(adType ?? "-")", "ad")
    }
  }

  /// 解除平台视图容器绑定
  ///
  /// - Parameter adId: 广告实例 ID
  func detachAdView(adId: String, container: UIView? = nil) {
    guard let holder = adHolders[adId] else { return }
    // Flutter 重建时新视图可能先绑定，旧 PlatformView 随后才释放。
    if let container = container, holder.container !== container { return }
    holder.container?.subviews.forEach { $0.removeFromSuperview() }
    holder.container = nil
    if let feed = holder as? FeedAdHolder { syncFeedVideo(feed) }
  }

  // 解绑只临时暂停，不改变业务指定的 play/pause/stop 意图。
  private func syncFeedVideo(_ holder: FeedAdHolder) {
    let action: String
    switch holder.videoAction {
    case "stop": action = "stop"
    case "pause": action = "pause"
    default: action = holder.container == nil ? "pause" : "play"
    }
    performFeedVideoAction(holder, action: action)
  }

  private func performFeedVideoAction(_ holder: FeedAdHolder, action: String) {
    if Self.performVideoAction(on: holder.nativeAd?.mediation, action: action) { return }
    // 7.8.0.5 部分聚合对象未提供播放 API，回退到 SDK 公开的媒体视图。
    if let canvas = holder.nativeAd?.mediation?.canvasView,
       canvas.responds(to: NSSelectorFromString("mediaView")) {
      Self.performVideoAction(on: nil, action: action, fallbackTarget: canvas.mediaView)
    }
  }

  // 7.8.0.5 部分 Draw 对象未实现协议声明的播放方法，直接调用会触发 ObjC 异常。
  @discardableResult
  static func performVideoAction(on target: AnyObject?, action: String, fallbackTarget: AnyObject? = nil) -> Bool {
    guard ["play", "pause", "stop"].contains(action) else { return false }
    let selector = NSSelectorFromString(action)
    if let target = target as? NSObject, target.responds(to: selector) {
      target.perform(selector)
      return true
    }
    // 媒体视图公开的是 play/pause，没有 stop；销毁前至少暂停。
    guard let fallbackTarget = fallbackTarget else { return false }
    return performVideoAction(on: fallbackTarget, action: action == "stop" ? "pause" : action)
  }

  // MARK: - 广告加载实现

  private func loadSplashAd(adId: String, placementId: String, request: [String: Any]) {
    let slot = BUAdSlot()
    slot.id = placementId
    GromoreAdRequestOptions(request: request).configureSlot(slot)
    let options = GromoreAdRequestOptions(request: request)
    let size = normalizedSplashAdSize(options.splashSize(fallback: resolveSplashAdSize()))


    emitLog(
      "info",
      "splash ad size resolved: width=\(Int(size.width)), height=\(Int(size.height))",
      "ad"
    )

    let splashAd = BUSplashAd(slot: slot, adSize: size)
    for (key, value) in GromoreAdRequestOptions(request: request).value("addParams") as? [String: Any] ?? [:] {
      splashAd.mediation?.addParam(value, withKey: key)
    }
    options.configureSplashAd(splashAd)
    let delegate = SplashDelegate(manager: self, adId: adId, placementId: placementId)
    splashAd.delegate = delegate
    splashAd.cardDelegate = delegate
    splashAd.supportCardView = options.bool("supportCardView") ?? false
    if let logo = options.string("logo") {
      guard let image = UIImage(contentsOfFile: logo) else {
        emitAdError(adId: adId, adType: "splash", placementId: placementId,
          errorCode: "invalid_args", errorMessage: "Cannot decode splash logo: \(logo)")
        return
      }
      let bottom = UIImageView(image: image)
      bottom.backgroundColor = .white
      bottom.contentMode = .scaleAspectFit
      bottom.frame = CGRect(x: 0, y: 0, width: size.width, height: CGFloat(max(1, options.int("logoHeight", fallback: 80))))
      splashAd.mediation?.customBottomView = bottom
    }

    let holder = SplashAdHolder(adId: adId, placementId: placementId)
    holder.splashAd = splashAd
    holder.delegate = delegate
    holder.factoryId = GromoreAdRequestOptions(request: request).string("nativeRenderFactoryId")
    adHolders[adId] = holder

    splashAd.loadData()
  }

  private func loadRewardAd(adId: String, placementId: String, request: [String: Any]) {
    let slot = BUAdSlot()
    slot.id = placementId
    GromoreAdRequestOptions(request: request).configureSlot(slot)
    if let muted = readBool(request: request, key: "muted") {
      slot.mediation.mutedIfCan = muted
    }
    if let scenarioId = readString(request: request, key: "scenarioId") {
      slot.mediation.scenarioID = scenarioId
    }
    let model = GromoreAdRequestOptions(request: request).rewardModel()

    let rewardedAd = BUNativeExpressRewardedVideoAd(slot: slot, rewardedVideoModel: model)
    for (key, value) in GromoreAdRequestOptions(request: request).value("addParams") as? [String: Any] ?? [:] {
      rewardedAd.mediation?.addParam(value, withKey: key)
    }
    let delegate = RewardDelegate(manager: self, adId: adId, placementId: placementId)
    rewardedAd.delegate = delegate

    let holder = RewardAdHolder(adId: adId, placementId: placementId)
    holder.rewardedAd = rewardedAd
    holder.delegate = delegate
    holder.factoryId = GromoreAdRequestOptions(request: request).string("nativeRenderFactoryId")
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
    GromoreAdRequestOptions(request: request).configureSlot(slot)
    if let muted = readBool(request: request, key: "muted") {
      slot.mediation.mutedIfCan = muted
    }
    let fullscreenAd = BUNativeExpressFullscreenVideoAd(slot: slot)
    for (key, value) in GromoreAdRequestOptions(request: request).value("addParams") as? [String: Any] ?? [:] {
      fullscreenAd.mediation?.addParam(value, withKey: key)
    }
    let delegate = FullscreenDelegate(manager: self, adId: adId, placementId: placementId, adType: adType)
    fullscreenAd.delegate = delegate
    if let reward = GromoreAdRequestOptions(request: request).value("fullscreenReward") as? [String: Any] {
      fullscreenAd.mediation?.rewardModel = GromoreAdRequestOptions(request: reward).rewardModel()
    }

    let holder = FullScreenAdHolder(adId: adId, placementId: placementId, adType: adType)
    holder.fullscreenAd = fullscreenAd
    holder.delegate = delegate
    holder.factoryId = GromoreAdRequestOptions(request: request).string("nativeRenderFactoryId")
    adHolders[adId] = holder

    fullscreenAd.loadData()
  }

  private func loadBannerAd(adId: String, placementId: String, request: [String: Any]) {
    let width = GromoreAdRequestOptions(request: request).dimension("width", fallback: 320)
    let height = GromoreAdRequestOptions(request: request).dimension("height", fallback: 150)
    let slot = BUAdSlot()
    slot.id = placementId
    GromoreAdRequestOptions(request: request).configureSlot(slot)
    if let muted = readBool(request: request, key: "muted") {
      slot.mediation.mutedIfCan = muted
    }

    guard let rootVC = topViewController() else {
      emitAdError(adId: adId, adType: "banner", placementId: placementId, errorCode: "no_root_view_controller", errorMessage: "Banner rootViewController is nil.")
      return
    }
    let bannerView = BUNativeExpressBannerView(slot: slot, rootViewController: rootVC, adSize: CGSize(width: width, height: height))
    for (key, value) in GromoreAdRequestOptions(request: request).value("addParams") as? [String: Any] ?? [:] {
      bannerView.mediation?.addParam(value, withKey: key)
    }
    let delegate = BannerDelegate(manager: self, adId: adId, placementId: placementId)
    bannerView.delegate = delegate

    let holder = BannerAdHolder(adId: adId, placementId: placementId)
    holder.bannerView = bannerView
    holder.delegate = delegate
    holder.adSize = CGSize(width: width, height: height)
    holder.factoryId = GromoreAdRequestOptions(request: request).string("nativeRenderFactoryId")
    adHolders[adId] = holder

    bannerView.loadAdData()
  }

  private func loadFeedAd(adId: String, adType: String, placementId: String, request: [String: Any]) {
    let width = GromoreAdRequestOptions(request: request).dimension("width", fallback: UIScreen.main.bounds.size.width)
    let height = GromoreAdRequestOptions(request: request).dimension("height", fallback: 400)
    let requestedCount = readInt(request: request, key: "adCount", fallback: 1)
    let count = max(1, min(requestedCount, 3))
    if requestedCount != count {
      emitLog("warn", "feed adCount out of range, clamped from \(requestedCount) to \(count)", "ad")
    }
    guard let rootVC = topViewController() else {
      emitAdError(adId: adId, adType: adType, placementId: placementId, errorCode: "no_root_view_controller", errorMessage: "Feed rootViewController is nil.")
      return
    }
    let slot = BUAdSlot()
    slot.id = placementId
    GromoreAdRequestOptions(request: request).configureSlot(slot)
    let imageSize = BUSize()
    imageSize.width = max(1, Int(width))
    imageSize.height = max(1, Int(height))
    slot.imgSize = imageSize
    slot.adSize = CGSize(width: width, height: height)
    if let muted = readBool(request: request, key: "muted") {
      slot.mediation.mutedIfCan = muted
    }

    let adsManager = BUNativeAdsManager(slot: slot)
    for (key, value) in GromoreAdRequestOptions(request: request).value("addParams") as? [String: Any] ?? [:] {
      adsManager.mediation?.addParam(value, withKey: key)
    }
    let delegate = FeedDelegate(manager: self, adId: adId, adType: adType, placementId: placementId)
    adsManager.delegate = delegate
    adsManager.mediation?.rootViewController = rootVC

    let holder = FeedAdHolder(adId: adId, placementId: placementId, adType: adType)
    holder.adsManager = adsManager
    holder.delegate = delegate
    holder.factoryId = GromoreAdRequestOptions(request: request).string("nativeRenderFactoryId")
    adHolders[adId] = holder

    adsManager.loadAdData(withCount: count)
  }

  private func loadDrawAd(adId: String, adType: String, placementId: String, request: [String: Any]) {
    let width = GromoreAdRequestOptions(request: request).dimension("width", fallback: UIScreen.main.bounds.size.width)
    let height = GromoreAdRequestOptions(request: request).dimension("height", fallback: UIScreen.main.bounds.size.height)
    let requestedCount = readInt(request: request, key: "adCount", fallback: 1)
    let count = max(1, min(requestedCount, 3))
    if requestedCount != count {
      emitLog("warn", "draw adCount out of range, clamped from \(requestedCount) to \(count)", "ad")
    }
    guard let rootVC = topViewController() else {
      emitAdError(adId: adId, adType: adType, placementId: placementId, errorCode: "no_root_view_controller", errorMessage: "Draw rootViewController is nil.")
      return
    }
    let slot = BUAdSlot()
    slot.id = placementId
    GromoreAdRequestOptions(request: request).configureSlot(slot)
    slot.adType = .drawVideo
    let imageSize = BUSize()
    imageSize.width = max(1, Int(width))
    imageSize.height = max(1, Int(height))
    slot.imgSize = imageSize
    slot.adSize = CGSize(width: width, height: height)
    if let muted = readBool(request: request, key: "muted") {
      slot.mediation.mutedIfCan = muted
    }

    let adsManager = BUNativeAdsManager(slot: slot)
    for (key, value) in GromoreAdRequestOptions(request: request).value("addParams") as? [String: Any] ?? [:] {
      adsManager.mediation?.addParam(value, withKey: key)
    }
    let delegate = FeedDelegate(manager: self, adId: adId, adType: adType, placementId: placementId)
    adsManager.delegate = delegate
    adsManager.mediation?.rootViewController = rootVC

    let holder = FeedAdHolder(adId: adId, placementId: placementId, adType: adType)
    holder.adsManager = adsManager
    holder.delegate = delegate
    holder.factoryId = GromoreAdRequestOptions(request: request).string("nativeRenderFactoryId")
    adHolders[adId] = holder

    adsManager.loadAdData(withCount: count)
  }

  // MARK: - 展示实现

  private func showSplashAd(holder: SplashAdHolder) throws {
    guard let ad = holder.splashAd else { try failShow(holder, code: "not_ready", message: "No ad object") }
    guard let rootVC = topViewController() else {
      try failShow(holder, code: "no_root_view_controller", message: "No view controller")
    }
    ad.showSplashView(inRootViewController: rootVC)
    scheduleSdkConstraintRepair()
  }

  private func showRewardAd(holder: RewardAdHolder) throws {
    guard let ad = holder.rewardedAd else { try failShow(holder, code: "not_ready", message: "No ad object") }
    if ad.mediation?.isReady != true {
      try failShow(holder, code: "not_ready", message: "Ad is not ready")
    }
    guard let rootVC = topViewController() else {
      try failShow(holder, code: "no_root_view_controller", message: "No view controller")
    }
    holder.presentationRoot = rootVC
    if !ad.show(fromRootViewController: rootVC) {
      try failShow(holder, code: "show_failed", message: "SDK rejected show")
    }
    holder.presentedAdController = rootVC.presentedViewController
  }

  private func showFullScreenAd(holder: FullScreenAdHolder) throws {
    guard let ad = holder.fullscreenAd else { try failShow(holder, code: "not_ready", message: "No ad object") }
    if ad.mediation?.isReady != true {
      try failShow(holder, code: "not_ready", message: "Ad is not ready")
    }
    guard let rootVC = topViewController() else {
      try failShow(holder, code: "no_root_view_controller", message: "No view controller")
    }
    holder.presentationRoot = rootVC
    if !ad.show(fromRootViewController: rootVC) {
      try failShow(holder, code: "show_failed", message: "SDK rejected show")
    }
    holder.presentedAdController = rootVC.presentedViewController
  }

  private func attachBannerView(holder: BannerAdHolder, width: CGFloat, height: CGFloat) {
    guard let bannerView = holder.bannerView, let container = holder.container else { return }
    bannerView.frame = container.bounds
    bannerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    container.subviews.forEach { $0.removeFromSuperview() }
    container.addSubview(bannerView)
  }

  private func attachFeedView(holder: FeedAdHolder, width: CGFloat, height: CGFloat) {
    guard let container = holder.container else { return }
    guard let nativeAd = holder.nativeAd,
          let canvasView = nativeAd.mediation?.canvasView else { return }
    let targetSize = CGSize(
      width: container.bounds.width > 0 ? container.bounds.width : width,
      height: container.bounds.height > 0 ? container.bounds.height : height
    )
    if nativeAd.mediation?.isExpressAd == true {
      canvasView.frame = CGRect(origin: .zero, size: targetSize)
      canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    } else {
      if let id = holder.factoryId {
        if let factory = GromoreNativeRenderRegistry.factory(id) {
          factory(nativeAd, canvasView, targetSize, holder.adType)
        } else {
          emitAdError(adId: holder.adId, adType: holder.adType, placementId: holder.placementId,
            errorCode: "factory_not_found", errorMessage: "No native factory: \(id)")
          return
        }
      } else if holder.adType == "draw_native" {
        configureNativeDrawCanvasView(nativeAd: nativeAd, canvasView: canvasView, size: targetSize)
      } else {
        configureNativeCanvasView(nativeAd: nativeAd, canvasView: canvasView, size: targetSize)
      }
    }
    container.subviews.forEach { $0.removeFromSuperview() }
    container.addSubview(canvasView)
    syncFeedVideo(holder)
    // 模板广告只在 SDK 渲染成功回调中发送 rendered；挂载不代表渲染成功。
    if nativeAd.mediation?.isExpressAd != true {
      let renderSize = canvasView.bounds.size
      emitFeedRendered(holder, size: renderSize)
    }
  }

  private func emitFeedRendered(_ holder: FeedAdHolder, size: CGSize) {
    guard !holder.renderEventSent else { return }
    holder.renderEventSent = true
    emitAdRendered(adId: holder.adId, adType: holder.adType,
      placementId: holder.placementId, width: size.width, height: size.height)
  }

  private func configureBannerCanvas(_ canvas: BUMCanvasView, size: CGSize) {
    let width = max(size.width, 1), height = max(size.height, 1)
    canvas.frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
    canvas.backgroundColor = .white
    let title = canvas.titleLabel
    title.text = canvas.data?.adTitle
    title.frame = CGRect(x: 84, y: 8, width: max(1, width - 184), height: 25)
    title.font = .boldSystemFont(ofSize: 14)
    canvas.addSubview(title)
    let desc = canvas.descLabel
    desc.text = canvas.data?.adDescription
    desc.frame = CGRect(x: 84, y: 34, width: max(1, width - 184), height: max(1, height - 42))
    desc.font = .systemFont(ofSize: 12)
    canvas.addSubview(desc)
    let cta = canvas.callToActionBtn
    cta.setTitle(canvas.data?.buttonText ?? "查看", for: .normal)
    cta.frame = CGRect(x: max(0, width - 100), y: max(0, (height - 34) / 2), width: 88, height: 34)
    canvas.addSubview(cta)
    if let logo = canvas.adLogoView {
      logo.frame.origin = CGPoint(x: max(0, width - logo.bounds.width), y: 0)
      canvas.addSubview(logo)
    }
    if let media = canvas.mediaView {
      media.frame = CGRect(x: 8, y: 8, width: 68, height: max(1, height - 32))
      canvas.addSubview(media)
    } else {
      canvas.imageView.frame = CGRect(x: 8, y: 8, width: 68, height: max(1, height - 32))
      canvas.imageView.contentMode = .scaleAspectFit
      loadImage(from: canvas.data?.imageAry?.first?.imageURL, into: canvas.imageView)
      canvas.addSubview(canvas.imageView)
    }
    canvas.registerClickableViews([title, desc, cta, canvas.imageView])
  }

  private func configureNativeCanvasView(nativeAd: BUNativeAd, canvasView: BUMCanvasView, size: CGSize) {
    let width = max(size.width, 1)
    let height = max(size.height, 1)
    canvasView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
    canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    canvasView.backgroundColor = .white
    canvasView.layer.cornerRadius = 12
    canvasView.clipsToBounds = true
    canvasView.subviews.forEach { $0.removeFromSuperview() }

    let padding: CGFloat = 12
    let iconSize: CGFloat = 40
    let buttonHeight: CGFloat = 34
    let contentWidth = width - padding * 2

    let titleLabel = canvasView.titleLabel
    titleLabel.text = nativeAd.data?.adTitle ?? "广告推荐"
    titleLabel.font = .boldSystemFont(ofSize: 16)
    titleLabel.textColor = UIColor(red: 0.12, green: 0.16, blue: 0.22, alpha: 1)
    titleLabel.numberOfLines = 2

    let descLabel = canvasView.descLabel
    descLabel.text = nativeAd.data?.adDescription ?? "精彩内容，点击查看详情"
    descLabel.font = .systemFont(ofSize: 14)
    descLabel.textColor = UIColor(red: 0.29, green: 0.33, blue: 0.39, alpha: 1)
    descLabel.numberOfLines = 2

    let sourceLabel = UILabel(frame: CGRect(x: padding + iconSize + 10, y: padding + 22, width: contentWidth - iconSize - 84, height: 16))
    sourceLabel.text = nativeAd.data?.adSource ?? nativeAd.data?.adxName ?? "广告"
    sourceLabel.font = .systemFont(ofSize: 12)
    sourceLabel.textColor = UIColor(red: 0.42, green: 0.46, blue: 0.5, alpha: 1)

    let badgeLabel = UILabel(frame: CGRect(x: width - padding - 36, y: padding + 10, width: 36, height: 18))
    badgeLabel.text = "广告"
    badgeLabel.textAlignment = .center
    badgeLabel.font = .systemFont(ofSize: 10)
    badgeLabel.textColor = UIColor(red: 0.42, green: 0.46, blue: 0.5, alpha: 1)
    badgeLabel.backgroundColor = UIColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1)
    badgeLabel.layer.cornerRadius = 9
    badgeLabel.clipsToBounds = true

    if let iconView = canvasView.iconImageView {
      iconView.frame = CGRect(x: padding, y: padding, width: iconSize, height: iconSize)
      iconView.layer.cornerRadius = 8
      iconView.clipsToBounds = true
      if let iconURL = nativeAd.data?.icon?.imageURL {
        loadImage(from: iconURL, into: iconView)
      }
      canvasView.addSubview(iconView)
    }

    titleLabel.frame = CGRect(x: padding + iconSize + 10, y: padding, width: contentWidth - iconSize - 52, height: 22)
    canvasView.addSubview(titleLabel)
    canvasView.addSubview(sourceLabel)
    canvasView.addSubview(badgeLabel)

    let hasVideo = (nativeAd.data?.videoDuration ?? 0) > 0
    let mediaY = padding + iconSize + 12
    let mediaHeight = max(height * 0.42, 140)
    var bottomY = mediaY
    if hasVideo, let mediaView = canvasView.mediaView {
      mediaView.frame = CGRect(x: padding, y: mediaY, width: contentWidth, height: mediaHeight)
      mediaView.clipsToBounds = true
      mediaView.layer.cornerRadius = 10
      canvasView.addSubview(mediaView)
      bottomY = mediaView.frame.maxY
    } else {
      let imageView = canvasView.imageView
      imageView.frame = CGRect(x: padding, y: mediaY, width: contentWidth, height: mediaHeight)
      imageView.clipsToBounds = true
      imageView.layer.cornerRadius = 10
      imageView.contentMode = .scaleAspectFill
      if let imageURL = nativeAd.data?.imageAry?.first?.imageURL {
        loadImage(from: imageURL, into: imageView)
      }
      canvasView.addSubview(imageView)
      bottomY = imageView.frame.maxY
    }

    descLabel.frame = CGRect(x: padding, y: bottomY + 10, width: contentWidth, height: 40)
    canvasView.addSubview(descLabel)

    let ctaButton = canvasView.callToActionBtn
    ctaButton.frame = CGRect(x: width - padding - 96, y: min(descLabel.frame.maxY + 12, height - padding - buttonHeight), width: 96, height: buttonHeight)
    ctaButton.setTitle(nativeAd.data?.buttonText ?? "立即查看", for: .normal)
    ctaButton.setTitleColor(.white, for: .normal)
    ctaButton.titleLabel?.font = .boldSystemFont(ofSize: 13)
    ctaButton.backgroundColor = UIColor(red: 0.15, green: 0.39, blue: 0.92, alpha: 1)
    ctaButton.layer.cornerRadius = 17
    canvasView.addSubview(ctaButton)

    var clickableViews: [UIView] = [canvasView, titleLabel, descLabel, ctaButton, badgeLabel]
    if let iconView = canvasView.iconImageView {
      clickableViews.append(iconView)
    }
    if hasVideo, let mediaView = canvasView.mediaView {
      clickableViews.append(mediaView)
    } else {
      clickableViews.append(canvasView.imageView)
    }
    nativeAd.unregisterView()
    nativeAd.registerContainer(canvasView, withClickableViews: clickableViews)
    canvasView.registerClickableViews(clickableViews)
  }

  private func configureNativeDrawCanvasView(nativeAd: BUNativeAd, canvasView: BUMCanvasView, size: CGSize) {
    let width = max(size.width, 1)
    let height = max(size.height, 1)
    canvasView.frame = CGRect(origin: .zero, size: CGSize(width: width, height: height))
    canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    canvasView.backgroundColor = .black
    canvasView.clipsToBounds = true
    canvasView.subviews.forEach { $0.removeFromSuperview() }

    let overlayHeight: CGFloat = min(max(height * 0.28, 150), 220)
    let mediaHeight = height - overlayHeight
    if let mediaView = canvasView.mediaView {
      mediaView.frame = CGRect(x: 0, y: 0, width: width, height: mediaHeight)
      if let drawMediaView = mediaView as? BUMediaAdView {
        drawMediaView.drawVideoClickEnable = true
      }
      canvasView.addSubview(mediaView)
    } else {
      let imageView = canvasView.imageView
      imageView.frame = CGRect(x: 0, y: 0, width: width, height: mediaHeight)
      imageView.contentMode = .scaleAspectFill
      imageView.clipsToBounds = true
      if let imageURL = nativeAd.data?.imageAry?.first?.imageURL {
        loadImage(from: imageURL, into: imageView)
      }
      canvasView.addSubview(imageView)
    }

    let overlay = UIView(frame: CGRect(x: 0, y: height - overlayHeight, width: width, height: overlayHeight))
    overlay.backgroundColor = UIColor(white: 0, alpha: 0.55)
    canvasView.addSubview(overlay)

    let padding: CGFloat = 16
    let titleLabel = canvasView.titleLabel
    titleLabel.text = nativeAd.data?.adTitle ?? "精彩广告内容"
    titleLabel.font = .boldSystemFont(ofSize: 20)
    titleLabel.textColor = .white
    titleLabel.numberOfLines = 2
    titleLabel.frame = CGRect(x: padding, y: 18, width: width - padding * 2, height: 52)
    overlay.addSubview(titleLabel)

    let descLabel = canvasView.descLabel
    descLabel.text = nativeAd.data?.adDescription ?? "上下滑动查看更多精彩内容"
    descLabel.font = .systemFont(ofSize: 14)
    descLabel.textColor = UIColor(red: 0.9, green: 0.92, blue: 0.95, alpha: 1)
    descLabel.numberOfLines = 2
    descLabel.frame = CGRect(x: padding, y: titleLabel.frame.maxY + 8, width: width - padding * 2, height: 40)
    overlay.addSubview(descLabel)

    let sourceLabel = UILabel(frame: CGRect(x: padding, y: overlayHeight - 48, width: width - 140, height: 18))
    sourceLabel.text = nativeAd.data?.adSource ?? nativeAd.data?.adxName ?? "广告"
    sourceLabel.font = .systemFont(ofSize: 12)
    sourceLabel.textColor = UIColor(red: 0.82, green: 0.85, blue: 0.88, alpha: 1)
    overlay.addSubview(sourceLabel)

    let ctaButton = canvasView.callToActionBtn
    ctaButton.frame = CGRect(x: width - padding - 104, y: overlayHeight - 56, width: 104, height: 36)
    ctaButton.setTitle(nativeAd.data?.buttonText ?? "立即查看", for: .normal)
    ctaButton.setTitleColor(.white, for: .normal)
    ctaButton.titleLabel?.font = .boldSystemFont(ofSize: 14)
    ctaButton.backgroundColor = UIColor(red: 0.15, green: 0.39, blue: 0.92, alpha: 1)
    ctaButton.layer.cornerRadius = 18
    overlay.addSubview(ctaButton)

    var clickableViews: [UIView] = [canvasView, overlay, titleLabel, descLabel, ctaButton]
    if let mediaView = canvasView.mediaView {
      clickableViews.append(mediaView)
    } else {
      clickableViews.append(canvasView.imageView)
    }
    nativeAd.unregisterView()
    nativeAd.registerContainer(canvasView, withClickableViews: clickableViews)
    canvasView.registerClickableViews(clickableViews)
  }

  private func loadImage(from urlString: String?, into imageView: UIImageView?) {
    guard let imageView, let urlString, let url = URL(string: urlString) else { return }
    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data, let image = UIImage(data: data) else { return }
      DispatchQueue.main.async {
        imageView.image = image
      }
    }.resume()
  }

  // MARK: - 事件上报

  private func emitAdLoaded(adId: String, adType: String, placementId: String, data: [String: Any]? = nil) {
    var payload: [String: Any] = [
      "adId": adId,
      "adType": adType,
      "eventType": "loaded",
      "placementId": placementId
    ]
    adHolders[adId]?.loading = false
    adHolders[adId]?.loadFailureSent = false
    var mergedData = data ?? [:]
    mergedData["adIds"] = adHolders[adId]?.batchIds ?? [adId]
    if let ecpmInfo = buildEcpmInfo(adId: adId) {
      mergedData["ecpmInfo"] = ecpmInfo
    }
    if !mergedData.isEmpty {
      payload["data"] = mergedData
    }
    postAdEvent(payload)
  }

  private func emitAdShown(adId: String, adType: String, placementId: String, data: [String: Any]? = nil) {
    if let holder = adHolders[adId], holder.presentedAdController == nil {
      holder.presentedAdController = holder.presentationRoot?.presentedViewController
    }
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

  private func emitAdRendered(adId: String, adType: String, placementId: String, width: CGFloat, height: CGFloat) {
    postAdEvent([
      "adId": adId,
      "adType": adType,
      "eventType": "rendered",
      "placementId": placementId,
      "data": [
        "renderWidth": Double(width),
        "renderHeight": Double(height)
      ]
    ])
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

  private func emitAdError(adId: String, adType: String, placementId: String, errorCode: String?, errorMessage: String?, phase: String? = nil) {
    let resolvedPhase = phase ?? (["show_failed": "show", "video_error": "playback",
      "render_failed": "render", "reward_verify_failed": "rewardVerification"][errorCode ?? ""] ?? "load")
    var data: [String: Any] = ["phase": resolvedPhase]
    if resolvedPhase == "load", let holder = adHolders[adId] {
      // 同一轮加载可能收到多次失败回调，只通知一次；成功加载后允许下一轮失败。
      guard !holder.loadFailureSent else { return }
      holder.loadFailureSent = true
      data.merge(loadDiagnostics(holder)) { _, new in new }
      emitLog("error", "loadAd failed: \(adId), placementId=\(placementId), code=\(errorCode ?? "unknown"), message=\(errorMessage ?? ""), diagnostics=\(data)", "ad")
    }
    postAdEvent([
      "adId": adId,
      "adType": adType,
      "eventType": "failed",
      "placementId": placementId,
      "errorCode": errorCode as Any,
      "errorMessage": errorMessage as Any,
      "data": data
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
    let subChannel = info.sub_channel
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
    let id = payload["adId"] as? String ?? ""
    if payload["eventType"] as? String == "failed" { adHolders[id]?.loading = false }
    let holder = adHolders[id]
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      if let holder = holder, self.adHolders[id] !== holder { return }
      if holder == nil && payload["eventType"] as? String != "failed" { return }
      self.emitAdEvent(payload)
    }
  }

  // MARK: - 工具方法

  private func scheduleSdkConstraintRepair() {
    let delays: [TimeInterval] = [0, 0.12, 0.35, 0.8]
    for delay in delays {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        guard let self else { return }
        guard let rootView = self.currentKeyWindow() ?? self.topViewController()?.view else {
          return
        }
        let fixedCount = self.repairSdkConstraintConflicts(in: rootView)
        if fixedCount > 0 {
          self.emitLog("info", "sdk constraint repair applied: \(fixedCount)", "ad")
        }
      }
    }
  }

  @discardableResult
  private func repairSdkConstraintConflicts(in rootView: UIView) -> Int {
    var fixedCount = 0
    fixedCount += repairUpieLottieConstraintsIfNeeded(in: rootView)
    fixedCount += repairUgenImageConstraintsIfNeeded(in: rootView)
    for subview in rootView.subviews {
      fixedCount += repairSdkConstraintConflicts(in: subview)
    }
    return fixedCount
  }

  private func repairUpieLottieConstraintsIfNeeded(in view: UIView) -> Int {
    let className = NSStringFromClass(type(of: view))
    guard className.contains("UpieLottiePlayerControlView") else { return 0 }

    var fixedCount = 0
    for case let button as UIButton in view.subviews {
      guard buttonFillsSuperview(button, in: view) else { continue }
      let conflicting = button.constraints.filter {
        guard $0.relation == .equal, $0.secondItem == nil else { return false }
        let isSize = $0.firstAttribute == .width || $0.firstAttribute == .height
        return isSize && abs($0.constant - 50) < 0.5
      }
      if !conflicting.isEmpty {
        NSLayoutConstraint.deactivate(conflicting)
        fixedCount += conflicting.count
      }
    }
    return fixedCount
  }

  private func buttonFillsSuperview(_ button: UIButton, in container: UIView) -> Bool {
    var top = false
    var bottom = false
    var leading = false
    var trailing = false

    for constraint in container.constraints {
      let firstView = constraint.firstItem as? UIView
      let secondView = constraint.secondItem as? UIView
      let pairMatches =
        (firstView === button && secondView === container) ||
        (firstView === container && secondView === button)
      guard pairMatches, constraint.relation == .equal, abs(constraint.constant) < 0.5 else {
        continue
      }
      switch (constraint.firstAttribute, constraint.secondAttribute) {
      case (.top, .top), (.topMargin, .topMargin):
        top = true
      case (.bottom, .bottom), (.bottomMargin, .bottomMargin):
        bottom = true
      case (.leading, .leading), (.left, .left), (.leadingMargin, .leadingMargin):
        leading = true
      case (.trailing, .trailing), (.right, .right), (.trailingMargin, .trailingMargin):
        trailing = true
      default:
        break
      }
    }
    return top && bottom && leading && trailing
  }

  private func repairUgenImageConstraintsIfNeeded(in view: UIView) -> Int {
    let className = NSStringFromClass(type(of: view))
    guard className.contains("UgenImageView") else { return 0 }
    guard let superview = view.superview,
          NSStringFromClass(type(of: superview)).contains("UgenFrameLayoutView") else {
      return 0
    }
    guard ugenImageIsPinnedVertically(view, in: superview),
          ugenImageHasFixedWidth(view) else {
      return 0
    }

    let conflicting = view.constraints.filter {
      guard $0.relation == .equal else { return false }
      let firstView = $0.firstItem as? UIView
      let secondView = $0.secondItem as? UIView
      return firstView === view &&
        secondView === view &&
        (
          ($0.firstAttribute == .width && $0.secondAttribute == .height) ||
          ($0.firstAttribute == .height && $0.secondAttribute == .width)
        )
    }
    if conflicting.isEmpty { return 0 }
    NSLayoutConstraint.deactivate(conflicting)
    return conflicting.count
  }

  private func ugenImageIsPinnedVertically(_ view: UIView, in container: UIView) -> Bool {
    var topPinned = false
    var bottomPinned = false
    for constraint in container.constraints {
      let firstView = constraint.firstItem as? UIView
      let secondView = constraint.secondItem as? UIView
      let pairMatches =
        (firstView === view && secondView === container) ||
        (firstView === container && secondView === view)
      guard pairMatches, constraint.relation == .equal || constraint.relation == .greaterThanOrEqual else {
        continue
      }
      switch (constraint.firstAttribute, constraint.secondAttribute) {
      case (.top, .top), (.topMargin, .topMargin):
        topPinned = true
      case (.bottom, .bottom), (.bottomMargin, .bottomMargin):
        bottomPinned = true
      default:
        break
      }
    }
    return topPinned && bottomPinned
  }

  private func ugenImageHasFixedWidth(_ view: UIView) -> Bool {
    return view.constraints.contains {
      $0.relation == .equal &&
      $0.secondItem == nil &&
      $0.firstItem as? UIView === view &&
      $0.firstAttribute == .width
    }
  }

  private func resolveSplashAdSize() -> CGSize {
    let fallbackSize = normalizedSplashAdSize(UIScreen.main.bounds.size)

    let candidates: [CGSize?] = [
      currentKeyWindow()?.bounds.size,
      topViewController()?.view.window?.bounds.size,
      topViewController()?.view.bounds.size,
      activeWindowScene()?.screen.bounds.size,
      UIScreen.main.bounds.size
    ]

    for candidate in candidates {
      guard let size = candidate, size.width > 0, size.height > 0 else { continue }
      return normalizedSplashAdSize(size)
    }

    return fallbackSize.width > 0 && fallbackSize.height > 0
      ? fallbackSize
      : CGSize(width: 375, height: 667)
  }

  private func normalizedSplashAdSize(_ size: CGSize) -> CGSize {
    let width = max(size.width, 0)
    let height = max(size.height, 0)
    guard width > 0, height > 0 else { return .zero }
    return CGSize(width: min(width, height), height: max(width, height))
  }

  private func activeWindowScene() -> UIWindowScene? {
    if #available(iOS 13.0, *) {
      return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
    }
    return nil
  }

  private func currentKeyWindow() -> UIWindow? {
    if #available(iOS 13.0, *) {
      for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
        if let window = scene.windows.first(where: { $0.isKeyWindow }) {
          return window
        }
      }
    }
    return UIApplication.shared.keyWindow
  }

  private func topViewController() -> UIViewController? {
    if let window = currentKeyWindow(), let root = window.rootViewController {
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
    return GromoreAdRequestOptions(request: request).int(key, fallback: fallback)
  }

  private func readString(request: [String: Any], key: String) -> String? {
    return GromoreAdRequestOptions(request: request).string(key)
  }

  private func readBool(request: [String: Any], key: String) -> Bool? {
    return GromoreAdRequestOptions(request: request).bool(key)
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
    var loading = true
    var loadFailureSent = false
    var batchIds: [String] = []
    var factoryId: String?
    weak var presentationRoot: UIViewController?
    weak var presentedAdController: UIViewController?

    init(adId: String, placementId: String, adType: String) {
      self.adId = adId
      self.placementId = placementId
      self.adType = adType
      self.batchIds = [adId]
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
    var renderEventSent: Bool = false
    var videoAction = "play"

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
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitLog("info", "splash load success: \(adId)", "ad")
      manager?.emitAdLoaded(adId: adId, adType: "splash", placementId: placementId)
    }

    func splashAdLoadFail(_ splashAd: BUSplashAd, error: BUAdError?) {
      guard manager?.adHolders[adId] != nil else { return }
      let code = error?.errorCode.rawValue ?? error?._code ?? 0
      let message = error?.localizedDescription
      manager?.emitLog("error", "splash load fail: \(adId), code=\(code)", "ad")
      manager?.emitAdError(adId: adId, adType: "splash", placementId: placementId, errorCode: "\(code)", errorMessage: message)
    }

    func splashAdRenderSuccess(_ splashAd: BUSplashAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "rendered")
    }

    func splashAdRenderFail(_ splashAd: BUSplashAd, error: BUAdError?) {
      guard manager?.adHolders[adId] != nil else { return }
      let code = error?.errorCode.rawValue ?? error?._code ?? 0
      manager?.emitLog("error", "splash render fail: \(adId), code=\(code)", "ad")
      manager?.emitAdError(adId: adId, adType: "splash", placementId: placementId, errorCode: "\(code)", errorMessage: error?.localizedDescription)
    }

    func splashAdWillShow(_ splashAd: BUSplashAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitLog("info", "splash will show: \(adId)", "ad")
      manager?.scheduleSdkConstraintRepair()
    }

    func splashAdDidShow(_ splashAd: BUSplashAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.scheduleSdkConstraintRepair()
      manager?.emitAdShown(adId: adId, adType: "splash", placementId: placementId)
    }

    func splashAdDidClick(_ splashAd: BUSplashAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdClicked(adId: adId, adType: "splash", placementId: placementId)
    }

    func splashAdDidClose(_ splashAd: BUSplashAd, closeType: BUSplashAdCloseType) {
      guard manager?.adHolders[adId] != nil else { return }
      let closeTypeName: String
      switch closeType {
      case .clickSkip: closeTypeName = "click_skip"
      case .countdownToZero: closeTypeName = "count_down_over"
      case .clickAd: closeTypeName = "click_ad"
      case .forceQuit: closeTypeName = "force_quit"
      case .unknow: closeTypeName = "unknown"
      @unknown default: closeTypeName = "\(closeType.rawValue)"
      }
      manager?.emitAdClosed(adId: adId, adType: "splash", placementId: placementId, data: ["closeType": closeTypeName])
      if !splashAd.supportCardView { splashAd.mediation?.destoryAd() }
    }

    func splashAdViewControllerDidClose(_ splashAd: BUSplashAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitLog("info", "splash view controller closed: \(adId)", "ad")
    }

    func splashDidCloseOtherController(_ splashAd: BUSplashAd, interactionType: BUInteractionType) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "landingPageClosed", ["interactionType": interactionType.rawValue])
    }

    func splashVideoAdDidPlayFinish(_ splashAd: BUSplashAd, didFailWithError error: Error?) {
      guard manager?.adHolders[adId] != nil else { return }
      if let error = error {
        manager?.emitAdError(adId: adId, adType: "splash", placementId: placementId, errorCode: "\(error._code)", errorMessage: error.localizedDescription)
      } else {
        manager?.emitLog("info", "splash video play finished: \(adId)", "ad")
      }
    }

    func splashAdDidShowFailed(_ splashAd: BUSplashAd, error: Error) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdError(adId: adId, adType: "splash", placementId: placementId, errorCode: "show_failed", errorMessage: error.localizedDescription)
    }

    func splashCardReady(toShow splashAd: BUSplashAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "splashCardReady")
    }

    func splashCardViewDidClick(_ splashAd: BUSplashAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdClicked(adId: adId, adType: "splash", placementId: placementId)
    }

    func splashCardViewDidClose(_ splashAd: BUSplashAd) {
      guard manager?.adHolders[adId] != nil else { return }
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

    func nativeExpressRewardedVideoAdDidDownLoadVideo(_ ad: BUNativeExpressRewardedVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "cached")
    }
    func nativeExpressRewardedVideoAdDidClickSkip(_ ad: BUNativeExpressRewardedVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "skipped")
    }
    func nativeExpressRewardedVideoAdDidPlayFinish(_ ad: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
      guard manager?.adHolders[adId] != nil else { return }
      if let error = error {
        manager?.emitAdError(adId: adId, adType: "rewardVideo", placementId: placementId,
          errorCode: "video_error", errorMessage: error.localizedDescription)
      } else { manager?.emitExtra(adId, "completed") }
    }
    func nativeExpressRewardedVideoAdWillPresentFullScreenModal(_ ad: BUNativeExpressRewardedVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "landingPageOpened")
    }
    func nativeExpressRewardedVideoAdDidCloseOtherController(_ ad: BUNativeExpressRewardedVideoAd, interactionType: BUInteractionType) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "landingPageClosed", ["interactionType": interactionType.rawValue])
    }

    func nativeExpressRewardedVideoAdViewRenderSuccess(_ ad: BUNativeExpressRewardedVideoAd) {
      manager?.emitExtra(adId, "rendered")
    }
    func nativeExpressRewardedVideoAdViewRenderFail(_ ad: BUNativeExpressRewardedVideoAd, error: Error?) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdError(adId: adId, adType: "rewardVideo", placementId: placementId,
        errorCode: "render_failed", errorMessage: error?.localizedDescription)
    }

    func nativeExpressRewardedVideoAdDidLoad(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdLoaded(adId: adId, adType: "rewardVideo", placementId: placementId)
    }

    func nativeExpressRewardedVideoAd(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdError(adId: adId, adType: "rewardVideo", placementId: placementId, errorCode: "\(error?._code ?? 0)", errorMessage: error?.localizedDescription)
    }

    func nativeExpressRewardedVideoAdDidVisible(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdShown(adId: adId, adType: "rewardVideo", placementId: placementId)
    }

    func nativeExpressRewardedVideoAdDidClick(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdClicked(adId: adId, adType: "rewardVideo", placementId: placementId)
    }

    func nativeExpressRewardedVideoAdDidClose(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdClosed(adId: adId, adType: "rewardVideo", placementId: placementId)
    }

    /// 激励广告展示失败
    ///
    /// - Parameters:
    ///   - rewardedVideoAd: 广告对象
    ///   - error: 失败原因
    func nativeExpressRewardedVideoAdDidShowFailed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdError(adId: adId, adType: "rewardVideo", placementId: placementId, errorCode: "show_failed", errorMessage: error.localizedDescription)
    }

    func nativeExpressRewardedVideoAdServerRewardDidSucceed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, verify: Bool) {
      guard manager?.adHolders[adId] != nil else { return }
      let model = rewardedVideoAd.rewardedVideoModel
      let data: [String: Any] = [
        "verify": verify,
        "customData": model.extra ?? "",
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
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdError(adId: adId, adType: "rewardVideo", placementId: placementId, errorCode: "reward_verify_failed", errorMessage: error?.localizedDescription)
    }
  }

  /// 插全屏代理
  final class FullscreenDelegate: NSObject, BUMNativeExpressFullscreenVideoAdDelegate {
    weak var manager: GromoreAdManager?
    let adType: String
    let adId: String
    let placementId: String

    init(manager: GromoreAdManager, adId: String, placementId: String, adType: String) {
      self.manager = manager
      self.adType = adType
      self.adId = adId
      self.placementId = placementId
    }

    func nativeExpressFullscreenVideoAdDidDownLoadVideo(_ ad: BUNativeExpressFullscreenVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "cached")
    }
    func nativeExpressFullscreenVideoAdDidClickSkip(_ ad: BUNativeExpressFullscreenVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "skipped")
    }
    func nativeExpressFullscreenVideoAdDidPlayFinish(_ ad: BUNativeExpressFullscreenVideoAd, didFailWithError error: Error?) {
      guard manager?.adHolders[adId] != nil else { return }
      if let error = error {
        manager?.emitAdError(adId: adId, adType: adType, placementId: placementId,
          errorCode: "video_error", errorMessage: error.localizedDescription)
      } else { manager?.emitExtra(adId, "completed") }
    }
    func nativeExpressFullscreenVideoAdWillPresentFullScreenModal(_ ad: BUNativeExpressFullscreenVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "landingPageOpened")
    }
    func nativeExpressFullscreenVideoAdDidCloseOtherController(_ ad: BUNativeExpressFullscreenVideoAd, interactionType: BUInteractionType) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "landingPageClosed", ["interactionType": interactionType.rawValue])
    }

    func nativeExpressFullscreenVideoAdServerRewardDidSucceed(_ ad: BUNativeExpressFullscreenVideoAd, verify: Bool) {
      guard manager?.adHolders[adId] != nil else { return }
      let model = ad.mediation?.rewardModel
      manager?.emitAdRewarded(adId: adId, adType: adType, placementId: placementId, data: [
        "verify": verify, "userId": model?.userId ?? "", "rewardName": model?.rewardName ?? "",
        "rewardAmount": model?.rewardAmount ?? 0, "customData": model?.extra ?? "",
        "adnName": "gdt", "tradeId": model?.mediation.tradeId ?? ""
      ])
    }
    func nativeExpressFullscreenVideoAdServerRewardDidFail(_ ad: BUNativeExpressFullscreenVideoAd, error: Error) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdError(adId: adId, adType: adType, placementId: placementId,
        errorCode: "reward_verify_failed", errorMessage: error.localizedDescription)
    }

    func nativeExpressFullscreenVideoAdViewRenderSuccess(_ ad: BUNativeExpressFullscreenVideoAd) {
      manager?.emitExtra(adId, "rendered")
    }
    func nativeExpressFullscreenVideoAdViewRenderFail(_ ad: BUNativeExpressFullscreenVideoAd, error: Error?) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdError(adId: adId, adType: adType, placementId: placementId,
        errorCode: "render_failed", errorMessage: error?.localizedDescription)
    }

    func nativeExpressFullscreenVideoAdDidLoad(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdLoaded(adId: adId, adType: adType, placementId: placementId)
    }

    func nativeExpressFullscreenVideoAd(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd, didFailWithError error: Error?) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdError(adId: adId, adType: adType, placementId: placementId, errorCode: "\(error?._code ?? 0)", errorMessage: error?.localizedDescription)
    }

    func nativeExpressFullscreenVideoAdDidVisible(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdShown(adId: adId, adType: adType, placementId: placementId)
    }

    func nativeExpressFullscreenVideoAdDidClick(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdClicked(adId: adId, adType: adType, placementId: placementId)
    }

    func nativeExpressFullscreenVideoAdDidClose(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdClosed(adId: adId, adType: adType, placementId: placementId)
    }

    /// 插全屏广告展示失败
    ///
    /// - Parameters:
    ///   - fullscreenVideoAd: 广告对象
    ///   - error: 失败原因
    func nativeExpressFullscreenVideoAdDidShowFailed(_ fullscreenVideoAd: BUNativeExpressFullscreenVideoAd, error: Error) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdError(adId: adId, adType: adType, placementId: placementId, errorCode: "show_failed", errorMessage: error.localizedDescription)
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

    func nativeExpressBannerAdNeedLayoutUI(_ bannerAd: BUNativeExpressBannerView, canvasView: BUMCanvasView) {
      guard manager?.adHolders[adId] != nil else { return }
      guard let manager = manager, let holder = manager.adHolders[adId] else { return }
      if let id = holder.factoryId {
        guard let factory = GromoreNativeRenderRegistry.bannerFactory(id) else {
          manager.emitAdError(adId: adId, adType: "banner", placementId: placementId,
            errorCode: "factory_not_found", errorMessage: "No banner factory: \(id)")
          return
        }
        factory(canvasView, bannerAd.bounds.size)
      } else {
        manager.configureBannerCanvas(canvasView, size: bannerAd.bounds.size)
      }
    }
    func nativeExpressBannerAdView(_ bannerAdView: BUNativeExpressBannerView, dislikeWithReason filterwords: [BUDislikeWords]?) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "dislike", ["reasons": filterwords?.map { $0.name ?? "" } ?? []])
    }
    func nativeExpressBannerAdViewDidCloseOtherController(_ bannerAdView: BUNativeExpressBannerView, interactionType: BUInteractionType) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "landingPageClosed", ["interactionType": interactionType.rawValue])
    }

    func nativeExpressBannerAdViewDidLoad(_ bannerAdView: BUNativeExpressBannerView) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdLoaded(adId: adId, adType: "banner", placementId: placementId)
    }

    func nativeExpressBannerAdView(_ bannerAdView: BUNativeExpressBannerView, didLoadFailWithError error: Error?) {
      guard manager?.adHolders[adId] != nil else { return }
      let code = (error as NSError?)?._code ?? 0
      manager?.emitAdError(adId: adId, adType: "banner", placementId: placementId, errorCode: "\(code)", errorMessage: error?.localizedDescription)
    }

    func nativeExpressBannerAdViewDidBecomeVisible(_ bannerAdView: BUNativeExpressBannerView) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdShown(adId: adId, adType: "banner", placementId: placementId)
    }

    func nativeExpressBannerAdViewRenderFail(_ bannerAdView: BUNativeExpressBannerView, error: Error?) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdError(adId: adId, adType: "banner", placementId: placementId,
        errorCode: "render_failed", errorMessage: error?.localizedDescription)
    }

    func nativeExpressBannerAdViewRenderSuccess(_ bannerAdView: BUNativeExpressBannerView) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitLog("info", "banner render success: \(adId), width=\(bannerAdView.bounds.size.width), height=\(bannerAdView.bounds.size.height)", "ad")
      manager?.emitAdRendered(
        adId: adId,
        adType: "banner",
        placementId: placementId,
        width: bannerAdView.bounds.size.width,
        height: bannerAdView.bounds.size.height
      )
    }

    func nativeExpressBannerAdViewDidClick(_ bannerAdView: BUNativeExpressBannerView) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdClicked(adId: adId, adType: "banner", placementId: placementId)
    }

    func nativeExpressBannerAdViewDidRemoved(_ nativeExpressAdView: BUNativeExpressBannerView) {
      guard manager?.adHolders[adId] != nil else { return }
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
      guard let manager = manager,
            let first = manager.adHolders[adId] as? FeedAdHolder else {
        nativeAdDataArray?.forEach { $0.unregisterView() }
        adsManager.mediation?.destory()
        return
      }
      guard let ads = nativeAdDataArray, !ads.isEmpty else {
        manager.emitAdError(adId: adId, adType: adType, placementId: placementId, errorCode: "empty_ad", errorMessage: "No feed ads returned")
        return
      }
      let holders = ads.enumerated().map { index, _ -> FeedAdHolder in
        let holder = index == 0 ? first : FeedAdHolder(adId: manager.newAdId(), placementId: placementId, adType: adType)
        holder.factoryId = first.factoryId
        holder.adsManager = adsManager
        manager.adHolders[holder.adId] = holder
        return holder
      }
      let ids = holders.map { $0.adId }
      for (ad, holder) in zip(ads, holders) {
        holder.batchIds = ids
        holder.nativeAd = ad
        let delegate = holder === first ? self : FeedDelegate(manager: manager, adId: holder.adId, adType: adType, placementId: placementId)
        holder.delegate = delegate
        ad.rootViewController = manager.topViewController()
        ad.delegate = delegate
        manager.syncFeedVideo(holder)
        manager.emitAdLoaded(adId: holder.adId, adType: adType, placementId: placementId)
        if ad.mediation?.isExpressAd == true {
          ad.mediation?.render()
        } else {
          manager.attachFeedView(holder: holder, width: holder.container?.bounds.width ?? 0, height: holder.container?.bounds.height ?? 0)
        }
      }
    }

    func nativeAdsManager(_ adsManager: BUNativeAdsManager, didFailWithError error: Error?) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdError(adId: adId, adType: adType, placementId: placementId, errorCode: "\(error?._code ?? 0)", errorMessage: error?.localizedDescription)
    }

    func nativeAdExpressViewRenderSuccess(_ nativeAd: BUNativeAd) {
      guard manager?.adHolders[adId] != nil else { return }
      if let holder = manager?.adHolders[adId] as? FeedAdHolder {
        holder.nativeAd = nativeAd
        let canvasSize = nativeAd.mediation?.canvasView.bounds.size ?? .zero
        let fallbackSize = holder.container?.bounds.size ?? .zero
        let size = CGSize(
          width: canvasSize.width > 0 ? canvasSize.width : fallbackSize.width,
          height: canvasSize.height > 0 ? canvasSize.height : fallbackSize.height
        )
        manager?.emitLog("info", "feed render success: \(adId), width=\(size.width), height=\(size.height)", "ad")
        manager?.emitFeedRendered(holder, size: size)
        manager?.attachFeedView(holder: holder, width: holder.container?.bounds.size.width ?? 0, height: holder.container?.bounds.size.height ?? 0)
      }
    }

    func nativeAdExpressViewRenderFail(_ nativeAd: BUNativeAd, error: Error?) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdError(adId: adId, adType: adType, placementId: placementId, errorCode: "\(error?._code ?? 0)", errorMessage: error?.localizedDescription, phase: "render")
    }

    func nativeAdDidBecomeVisible(_ nativeAd: BUNativeAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdShown(adId: adId, adType: adType, placementId: placementId)
    }

    func nativeAdDidClick(_ nativeAd: BUNativeAd, with view: UIView?) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdClicked(adId: adId, adType: adType, placementId: placementId)
    }

    func nativeAd(_ nativeAd: BUNativeAd?, adContainerViewDidRemoved adContainerView: UIView) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitAdClosed(adId: adId, adType: adType, placementId: placementId)
    }

    func nativeAd(_ nativeAd: BUNativeAd?, dislikeWithReason filterWords: [BUDislikeWords]?) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "dislike", ["reasons": filterWords?.map { $0.name ?? "" } ?? []])
      manager?.emitAdClosed(adId: adId, adType: adType, placementId: placementId, data: ["dislike": true])
    }
    func nativeAdDidCloseOtherController(_ nativeAd: BUNativeAd, interactionType: BUInteractionType) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "landingPageClosed", ["interactionType": interactionType.rawValue])
    }

    func nativeAdWillPresentFullScreenModal(_ nativeAd: BUNativeAd) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "landingPageOpened")
    }

    func nativeAdVideo(_ nativeAd: BUNativeAd?, stateDidChanged playerState: BUPlayerPlayState) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "videoStateChanged", ["state": playerState.rawValue])
    }

    func nativeAdVideoDidClick(_ nativeAd: BUNativeAd?) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitLog("info", "feed video clicked: \(adId)", "ad")
    }

    func nativeAdVideoDidPlayFinish(_ nativeAd: BUNativeAd?) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "completed")
    }

    func nativeAdShakeViewDidDismiss(_ nativeAd: BUNativeAd?) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "shake", ["state": "dismissed"])
    }

    func nativeAdVideo(_ nativeAdView: BUNativeAd?, rewardDidCountDown countDown: NSInteger) {
      guard manager?.adHolders[adId] != nil else { return }
      manager?.emitExtra(adId, "rewardCountdown", ["countDown": countDown])
    }
  }
}
