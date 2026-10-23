package com.gromore.flutter

import android.app.Activity
import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.CSJAdError
import com.bytedance.sdk.openadsdk.CSJSplashAd
import com.bytedance.sdk.openadsdk.CSJSplashCloseType
import com.bytedance.sdk.openadsdk.TTAdConstant
import com.bytedance.sdk.openadsdk.TTAdDislike
import com.bytedance.sdk.openadsdk.TTAdNative
import com.bytedance.sdk.openadsdk.TTAppDownloadListener
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.TTDrawFeedAd
import com.bytedance.sdk.openadsdk.TTFeedAd
import com.bytedance.sdk.openadsdk.TTFullScreenVideoAd
import com.bytedance.sdk.openadsdk.TTNativeAd
import com.bytedance.sdk.openadsdk.TTNativeExpressAd
import com.bytedance.sdk.openadsdk.TTRewardVideoAd
import com.bytedance.sdk.openadsdk.mediation.ad.MediationViewBinder
import com.bytedance.sdk.openadsdk.mediation.ad.MediationExpressRenderListener
import com.bytedance.sdk.openadsdk.mediation.ad.IMediationNativeAdInfo
import com.bytedance.sdk.openadsdk.mediation.manager.MediationAdEcpmInfo
import com.bytedance.sdk.openadsdk.mediation.manager.MediationBaseManager
import com.bytedance.sdk.openadsdk.TTClientBidding
import com.bytedance.sdk.openadsdk.TTAdInteractionListener
import com.bytedance.sdk.openadsdk.mediation.MediationConstant
import java.net.URL
import java.util.UUID

/**
 * GroMore 广告管理器（Android）
 *
 * 负责加载/展示/销毁广告，并将事件回传到 Flutter。
 */
internal class GromoreAdManager(
  private val appContext: Context,
  private val activityProvider: () -> Activity?,
  private val emitAdEvent: (Map<String, Any?>) -> Unit,
  private val emitLog: (String, String, String) -> Unit,
  private val mainHandler: Handler = Handler(Looper.getMainLooper()),
  private val adHolders: MutableMap<String, GromoreAdHolder> = mutableMapOf()
) {
  /**
   * 生成新的广告实例 ID
   */
  fun newAdId(): String = UUID.randomUUID().toString()

  private fun failShow(holder: GromoreAdHolder, code: String, message: String): Nothing {
    emitAdError(holder.adId, holder.adType, holder.placementId, code, message, "show")
    throw GromoreAdException(code, message)
  }

  private fun GromoreAdHolder.manager(): MediationBaseManager? = when (this) {
    is SplashAdHolder -> ad?.mediationManager
    is RewardAdHolder -> ad?.mediationManager
    is FullScreenAdHolder -> ad?.mediationManager
    is BannerAdHolder -> ad?.mediationManager
    is FeedAdHolder -> ad?.mediationManager
    is DrawAdHolder -> ad?.mediationManager
  }

  private fun GromoreAdHolder.isReady() = !disposed && manager()?.isReady == true

  fun operation(method: String, args: Map<*, *>): Any? {
    val id = args["adId"] as? String ?: throw GromoreAdException("invalid_args", "adId is required")
    val holder = adHolders[id] ?: throw GromoreAdException("ad_not_found", "Unknown adId: $id")
    val manager = holder.manager()
    return when (method) {
      "getAdIds" -> holder.batchIds.filter { adHolders.containsKey(it) }
      "getAdState" -> mapOf("isReady" to holder.isReady(), "isLoading" to holder.loading)
      "getAdDiagnostics" -> mapOf(
        "loadInfo" to manager?.adLoadInfo?.map {
          mapOf("mediationRit" to it.mediationRit, "adnName" to it.adnName,
            "adType" to it.adType, "errCode" to it.errCode, "errMsg" to it.errMsg)
        },
        "bestEcpm" to ecpmMap(manager?.bestEcpm),
        "showEcpm" to ecpmMap(manager?.showEcpm),
        "multiBiddingEcpm" to manager?.multiBiddingEcpm?.map { ecpmMap(it) },
        "cacheList" to manager?.cacheList?.map { ecpmMap(it) }
      )
      "controlVideo" -> {
        if (holder !is FeedAdHolder && holder !is DrawAdHolder)
          throw GromoreAdException("unsupported", "Video control requires Feed/Draw")
        when (args["action"]) {
          "play", "resume" -> { holder.videoPaused = false }
          "pause" -> { holder.videoPaused = true }
          else -> throw GromoreAdException("unsupported", "Android mediation supports pause/resume only")
        }
        syncVideo(holder)
        null
      }
      "hideSplashSkipButton" -> {
        val ad = (holder as? SplashAdHolder)?.ad
          ?: throw GromoreAdException("unsupported", "Requires a loaded splash ad")
        ad.hideSkipButton()
        null
      }
      "showSplashCard" -> {
        val ad = (holder as? SplashAdHolder)?.ad
          ?: throw GromoreAdException("unsupported", "Requires a loaded splash ad")
        val activity = activityProvider() ?: throw GromoreAdException("no_activity", "Activity is null")
        if (ad.splashCardView == null) throw GromoreAdException("not_ready", "Splash card is unavailable")
        val container = FrameLayout(activity)
        (activity.window.decorView as ViewGroup).addView(container,
          ViewGroup.LayoutParams(-1, -1))
        holder.container = container
        ad.showSplashCardView(container, activity)
        null
      }
      else -> throw GromoreAdException("not_implemented", method)
    }
  }

  private fun emitExtra(holder: GromoreAdHolder, event: String, data: Map<String, Any?> = emptyMap()) {
    if (holder.disposed) return
    postAdEvent(mapOf("adId" to holder.adId, "adType" to holder.adType,
      "placementId" to holder.placementId, "eventType" to event, "data" to data))
  }

  private fun emitCached(holder: GromoreAdHolder) {
    if (holder.cachedEventSent || holder.disposed) return
    holder.cachedEventSent = true
    emitExtra(holder, "cached")
  }

  private fun bindNativeEvents(holder: GromoreAdHolder, ad: TTClientBidding) {
    ad.setAdInteractionListener(object : TTAdInteractionListener {
      override fun onAdEvent(code: Int, data: MutableMap<Any?, Any?>?) {
        if (holder.disposed) return
        emitExtra(holder, "nativeEvent", mapOf("code" to code, "parameters" to codecValue(data)))
      }
    })
  }

  private fun bindVideoEvents(holder: GromoreAdHolder, ad: TTFeedAd) {
    ad.mediationManager.setShakeViewListener { emitExtra(holder, "shake", mapOf("state" to "dismissed")) }
    ad.setVideoAdListener(object : TTFeedAd.VideoAdListener {
      override fun onVideoLoad(ad: TTFeedAd?) = emitCached(holder)
      override fun onVideoError(code: Int, extra: Int) {
        if (!holder.disposed) emitAdError(holder.adId, holder.adType, holder.placementId, "video_error", "$code/$extra")
      }
      override fun onVideoAdStartPlay(ad: TTFeedAd?) = emitExtra(holder, "videoStateChanged", mapOf("state" to "playing"))
      override fun onVideoAdPaused(ad: TTFeedAd?) = emitExtra(holder, "videoStateChanged", mapOf("state" to "paused"))
      override fun onVideoAdContinuePlay(ad: TTFeedAd?) = emitExtra(holder, "videoStateChanged", mapOf("state" to "playing"))
      override fun onProgressUpdate(position: Long, duration: Long) = Unit
      override fun onVideoAdComplete(ad: TTFeedAd?) = emitAdCompleted(holder)
    })
  }

  private fun codecValue(value: Any?): Any? = when (value) {
    null, is String, is Boolean, is Int, is Long, is Double, is Float,
    is ByteArray, is IntArray, is LongArray, is DoubleArray -> value
    is Number -> value.toDouble()
    is Bundle -> bundleToMap(value)
    is Map<*, *> -> value.entries.associate { it.key.toString() to codecValue(it.value) }
    is Iterable<*> -> value.map { codecValue(it) }
    is Array<*> -> value.map { codecValue(it) }
    else -> value.toString()
  }

  /**
   * 加载广告
   *
   * @param adId 广告实例 ID
   * @param adType 广告类型
   * @param placementId 代码位
   * @param requestMap 请求参数
   */
  fun loadAd(
    adId: String,
    adType: String,
    placementId: String,
    requestMap: Map<*, *>
  ) {
    val activity = activityProvider()
    if (activity == null) {
      emitAdError(adId, adType, placementId, "no_activity", "Activity is null.")
      return
    }
    val factoryId = GromoreAdRequestOptions(requestMap).string("nativeRenderFactoryId")
    if (factoryId != null && when (adType) {
        "banner" -> GromoreNativeRenderRegistry.bannerFactory(factoryId) == null
        "native", "draw_native" -> GromoreNativeRenderRegistry.factory(factoryId) == null
        else -> true
      }) throw GromoreAdException("factory_not_found", "No native factory for $adType: $factoryId")
    emitLog("info", "loadAd start: $adType, placementId=$placementId, adId=$adId", "ad")
    when (adType) {
      "splash" -> loadSplashAd(activity, adId, placementId, requestMap)
      "rewardVideo" -> loadRewardAd(activity, adId, placementId, requestMap)
      "fullscreenVideo" -> loadFullScreenAd(activity, adId, placementId, requestMap, adType)
      "interstitial" -> loadFullScreenAd(activity, adId, placementId, requestMap, adType)
      "banner" -> loadBannerAd(activity, adId, placementId, requestMap)
      "native" -> loadFeedAd(activity, adId, adType, placementId, requestMap)
      "draw_native" -> loadDrawAd(activity, adId, adType, placementId, requestMap)
      else -> emitAdError(adId, adType, placementId, "unknown_ad_type", "Unknown adType: $adType")
    }
  }

  /**
   * 展示广告
   *
   * @param adId 广告实例 ID
   */
  fun showAd(adId: String) {
    val holder = adHolders[adId]
    if (holder == null) {
      throw GromoreAdException("ad_not_found", "Unknown adId: $adId")
    }
    if (activityProvider() == null) failShow(holder, "no_activity", "Activity is null")
    if (!holder.isReady()) failShow(holder, "not_ready", "Ad is not ready")
    when (holder) {
      is SplashAdHolder -> showSplashAd(holder)
      is RewardAdHolder -> showRewardAd(holder)
      is FullScreenAdHolder -> showFullScreenAd(holder)
      is BannerAdHolder -> emitLog("info", "showAd for banner handled by view", "ad")
      is FeedAdHolder -> emitLog("info", "showAd for feed handled by view", "ad")
      is DrawAdHolder -> emitLog("info", "showAd for draw handled by view", "ad")
    }
  }

  /**
   * 销毁广告
   *
   * @param adId 广告实例 ID
   */
  fun disposeAd(adId: String) {
    val holder = adHolders.remove(adId) ?: return
    holder.disposed = true
    when (holder) {
      is SplashAdHolder -> {
        holder.ad?.mediationManager?.destroy()
        holder.container?.let { (it.parent as? ViewGroup)?.removeView(it) }
        holder.logo = null
      }
      is RewardAdHolder -> holder.ad?.mediationManager?.destroy()
      is FullScreenAdHolder -> holder.ad?.mediationManager?.destroy()
      is BannerAdHolder -> holder.ad?.destroy()
      is FeedAdHolder -> holder.ad?.destroy()
      is DrawAdHolder -> holder.ad?.destroy()
    }
    holder.container?.removeAllViews()
    emitLog("info", "disposeAd: $adId", "ad")
  }

  /**
   * 清理全部广告实例
   */
  fun clearAll() {
    val ids = adHolders.keys.toList()
    ids.forEach { disposeAd(it) }
  }

  /**
   * 绑定平台视图容器
   *
   * @param adId 广告实例 ID
   * @param adType 广告类型
   * @param container 容器视图
   * @param width 视图宽度
   * @param height 视图高度
   */
  fun attachAdView(adId: String, adType: String?, container: FrameLayout, width: Int, height: Int) {
    val holder = adHolders[adId]
    if (holder == null) {
      emitLog("warn", "attachAdView failed: adId not found: $adId", "ad")
      return
    }
    holder.container = container
    when (holder) {
      is BannerAdHolder -> attachBannerView(holder)
      is FeedAdHolder -> attachFeedView(holder)
      is DrawAdHolder -> attachDrawView(holder)
      else -> emitLog("warn", "attachAdView unsupported for adType=$adType", "ad")
    }
    syncVideo(holder)
  }

  /**
   * 解除平台视图容器绑定
   *
   * @param adId 广告实例 ID
   */
  fun detachAdView(adId: String) {
    val holder = adHolders[adId] ?: return
    holder.container?.removeAllViews()
    holder.container = null
    syncVideo(holder)
  }

  /** 解绑只临时暂停，不覆盖手动暂停；未绑定时的 resume 延后至重新挂载。 */
  private fun syncVideo(holder: GromoreAdHolder) {
    val manager = when (holder) {
      is FeedAdHolder -> holder.ad?.mediationManager
      is DrawAdHolder -> holder.ad?.mediationManager
      else -> null
    } ?: return
    if (holder.videoPaused || holder.container == null) manager.onPause()
    else manager.onResume()
  }

  /** 加载开屏广告 */
  private fun loadSplashAd(
    activity: Activity,
    adId: String,
    placementId: String,
    requestMap: Map<*, *>
  ) {
    val width = GromoreAdRequestOptions(requestMap).dimensionPx("width", activity.resources.displayMetrics.density, activity.resources.displayMetrics.widthPixels)
    val height = GromoreAdRequestOptions(requestMap).dimensionPx("height", activity.resources.displayMetrics.density, activity.resources.displayMetrics.heightPixels)
    val timeout = readInt(requestMap, "splashTimeout", 3500)


    val adSlot = AdSlot.Builder()
      .setCodeId(placementId)
      .setImageAcceptedSize(width, height)
      .setMediationAdSlot(GromoreAdRequestOptions(requestMap).mediationSlot())
      .build()

    val adNative = TTAdSdk.getAdManager().createAdNative(activity)
    val holder = SplashAdHolder(adId, placementId)
    val options = GromoreAdRequestOptions(requestMap)
    options.string("logo")?.let { path ->
      holder.logo = BitmapFactory.decodeFile(path)
        ?: throw GromoreAdException("invalid_args", "Cannot decode splash logo: $path")
      holder.logoHeight = options.int("logoHeight", 80).coerceAtLeast(1)
    }
    holder.factoryId = GromoreAdRequestOptions(requestMap).string("nativeRenderFactoryId")
    adHolders[adId] = holder

    val loadListener = object : TTAdNative.CSJSplashAdListener {
      override fun onSplashLoadSuccess(ad: CSJSplashAd?) {
        if (holder.disposed) { ad?.mediationManager?.destroy(); return }
        if (ad == null) {
          emitAdError(adId, holder.adType, placementId, "empty_ad", "SDK returned no ad")
          return
        }
        emitLog("info", "splash load success: $adId", "ad")
        holder.ad = ad
        bindNativeEvents(holder, ad)
        ad.setSplashCardListener(object : CSJSplashAd.SplashCardListener {
          override fun onSplashCardReadyToShow(ad: CSJSplashAd) = emitExtra(holder, "splashCardReady")
          override fun onSplashCardClick() = emitAdClicked(holder)
          override fun onSplashCardClose() {
            if (holder.disposed) return
            holder.container?.let { (it.parent as? ViewGroup)?.removeView(it) }
            emitAdClosed(holder, mapOf("closeType" to "card_close"))
          }
        })
        emitAdLoaded(holder)
      }

      override fun onSplashLoadFail(error: CSJAdError?) {
        if (holder.disposed) return
        emitLog("error", "splash load fail: $adId, code=${error?.code}, msg=${error?.msg}", "ad")
        emitAdError(
          adId,
          holder.adType,
          placementId,
          error?.code?.toString(),
          error?.msg
        )
      }

      override fun onSplashRenderSuccess(ad: CSJSplashAd?) {
        if (holder.disposed) { ad?.mediationManager?.destroy(); return }
        holder.ad = ad
        emitAdRendered(holder, 0f, 0f)
        emitLog("info", "splash render success: $adId", "ad")
      }

      override fun onSplashRenderFail(ad: CSJSplashAd?, error: CSJAdError?) {
        if (holder.disposed) return
        emitLog("error", "splash render fail: $adId, code=${error?.code}, msg=${error?.msg}", "ad")
        emitAdError(
          adId,
          holder.adType,
          placementId,
          error?.code?.toString(),
          error?.msg
        )
      }
    }
    holder.loadListener = loadListener

    adNative.loadSplashAd(adSlot, loadListener, timeout)
  }

  /** 展示开屏广告 */
  private fun showSplashAd(holder: SplashAdHolder) {
    val activity = activityProvider()
    val ad = holder.ad
    if (activity == null || ad == null) {
      failShow(holder, "not_ready", "Missing activity or ad")
    }
    val splashListener = object : CSJSplashAd.SplashAdListener {
      override fun onSplashAdShow(ad: CSJSplashAd?) {
        if (holder.disposed) return
        emitLog("info", "splash shown: ${holder.adId}", "ad")
        emitAdShownOnce(holder)
      }

      override fun onSplashAdClick(ad: CSJSplashAd?) {
        if (holder.disposed) return
        emitLog("info", "splash clicked: ${holder.adId}", "ad")
        emitAdClicked(holder)
      }

      override fun onSplashAdClose(ad: CSJSplashAd?, closeType: Int) {
        if (holder.disposed) return
        emitLog("info", "splash closed: ${holder.adId}, closeType=$closeType", "ad")
        holder.container?.let { container ->
          container.removeAllViews()
          (container.parent as? ViewGroup)?.removeView(container)
        }
        val closeTypeName = when (closeType) {
          CSJSplashCloseType.CLICK_SKIP -> "click_skip"
          CSJSplashCloseType.COUNT_DOWN_OVER -> "count_down_over"
          CSJSplashCloseType.CLICK_JUMP -> "click_jump"
          else -> closeType.toString()
        }
        emitAdClosedOnce(holder, mapOf("closeType" to closeTypeName))
      }
    }
    holder.showListener = splashListener
    ad.setSplashAdListener(splashListener)

    val container = FrameLayout(activity)
    container.layoutParams = FrameLayout.LayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT,
      ViewGroup.LayoutParams.MATCH_PARENT
    )
    holder.container = container
    val decorView = activity.window.decorView as? ViewGroup
    if (decorView == null) {
      failShow(holder, "no_window", "Decor view is null")
    }
    // 使用 SDK 的 showSplashView，而不是手动把 splashView 加到窗口。
    // 部分聚合广告源（如优量汇）只有在该入口中才会触发展示回调。
    decorView.addView(container)
    val adContainer = FrameLayout(activity)
    container.addView(adContainer, FrameLayout.LayoutParams(-1, -1).apply {
      bottomMargin = if (holder.logo != null) holder.logoHeight else 0
    })
    holder.logo?.let { logo ->
      val logoView = ImageView(activity)
      logoView.setBackgroundColor(Color.WHITE)
      logoView.setImageBitmap(logo)
      logoView.scaleType = ImageView.ScaleType.FIT_CENTER
      container.addView(logoView, FrameLayout.LayoutParams(-1, holder.logoHeight, android.view.Gravity.BOTTOM))
    }
    ad.showSplashView(adContainer)

  }

  /** 加载激励视频广告 */
  private fun loadRewardAd(
    activity: Activity,
    adId: String,
    placementId: String,
    requestMap: Map<*, *>
  ) {
    val adSlot = GromoreAdRequestOptions(requestMap).rewardSlot(placementId)

    val adNative = TTAdSdk.getAdManager().createAdNative(activity)
    val holder = RewardAdHolder(adId, placementId)
    val options = GromoreAdRequestOptions(requestMap)
    holder.rewardData = listOf("userId", "customData", "rewardName", "rewardAmount").associateWith { options.value(it) }
    holder.factoryId = GromoreAdRequestOptions(requestMap).string("nativeRenderFactoryId")
    adHolders[adId] = holder

    val listener = object : TTAdNative.RewardVideoAdListener {
      override fun onError(code: Int, message: String?) {
        if (holder.disposed) return
        emitLog("error", "reward load fail: $adId, code=$code, msg=$message", "ad")
        emitAdError(adId, holder.adType, placementId, code.toString(), message)
      }

      override fun onRewardVideoAdLoad(ad: TTRewardVideoAd?) {
        if (holder.disposed) { ad?.mediationManager?.destroy(); return }
        if (ad == null) {
          emitAdError(adId, holder.adType, placementId, "empty_ad", "SDK returned no ad")
          return
        }
        emitLog("info", "reward load success: $adId", "ad")
        holder.ad = ad
        if (ad != null) bindNativeEvents(holder, ad)
        emitAdLoaded(holder)
      }

      override fun onRewardVideoCached() {
        if (holder.disposed) return
        emitLog("info", "reward cached: $adId", "ad")
        emitCached(holder)
      }

      override fun onRewardVideoCached(ad: TTRewardVideoAd?) {
        if (holder.disposed) { ad?.mediationManager?.destroy(); return }
        holder.ad = ad
        emitLog("info", "reward cached with ad: $adId", "ad")
        emitCached(holder)
      }
    }
    holder.loadListener = listener
    adNative.loadRewardVideoAd(adSlot, listener)
  }

  /** 展示激励视频广告 */
  private fun showRewardAd(holder: RewardAdHolder) {
    val activity = activityProvider()
    val ad = holder.ad
    if (activity == null || ad == null) {
      failShow(holder, "not_ready", "Missing activity or ad")
    }
    if (!ad.mediationManager.isReady) {
      failShow(holder, "not_ready", "Reward ad is not ready")
    }
    val interactionListener = object : TTRewardVideoAd.RewardAdInteractionListener {
      override fun onAdShow() {
        if (holder.disposed) return
        emitLog("info", "reward shown: ${holder.adId}", "ad")
        emitAdShownOnce(holder)
      }

      override fun onAdVideoBarClick() {
        if (holder.disposed) return
        emitLog("info", "reward clicked: ${holder.adId}", "ad")
        emitAdClicked(holder)
      }

      override fun onAdClose() {
        if (holder.disposed) return
        emitLog("info", "reward closed: ${holder.adId}", "ad")
        emitAdClosed(holder)
      }

      override fun onVideoComplete() {
        if (holder.disposed) return
        emitLog("info", "reward video complete: ${holder.adId}", "ad")
        emitAdCompleted(holder)
      }

      override fun onVideoError() {
        if (holder.disposed) return
        emitAdError(holder.adId, holder.adType, holder.placementId, "video_error", "Reward video playback failed")
      }

      override fun onRewardVerify(
        rewardVerify: Boolean,
        rewardAmount: Int,
        rewardName: String?,
        errorCode: Int,
        errorMsg: String?
      ) {
        if (holder.disposed) return
        // deprecated in GroMore，使用 onRewardArrived
      }

      override fun onRewardArrived(isRewardValid: Boolean, rewardType: Int, extraInfo: Bundle?) {
        if (holder.disposed) return
        val data = bundleToMap(extraInfo).toMutableMap()
        data["isRewardValid"] = isRewardValid
        data["rewardType"] = rewardType
        data["rewardName"] = extraInfo?.get(MediationConstant.REWARD_NAME)
        data["rewardAmount"] = extraInfo?.get(MediationConstant.REWARD_AMOUNT)
        data["customData"] = extraInfo?.get(MediationConstant.REWARD_CUSTOM_DATA)
        data["tradeId"] = extraInfo?.get(MediationConstant.KEY_TRANS_ID)
        data["adnName"] = extraInfo?.get(MediationConstant.KEY_ADN_NAME)
        data["verifyByGroMoreS2S"] = extraInfo?.get(MediationConstant.KEY_IS_GROMORE_SERVER_SIDE_VERIFY)
        emitAdRewarded(holder, data)
      }

      override fun onSkippedVideo() {
        if (holder.disposed) return
        emitLog("info", "reward skipped: ${holder.adId}", "ad")
        emitAdSkipped(holder)
      }
    }
    holder.showListener = interactionListener
    ad.setRewardAdInteractionListener(interactionListener)
    ad.showRewardVideoAd(activity)
  }

  /**
   * 加载插全屏广告
   *
   * @param adType 广告类型（fullscreenVideo/interstitial）
   */
  private fun loadFullScreenAd(
    activity: Activity,
    adId: String,
    placementId: String,
    requestMap: Map<*, *>,
    adType: String
  ) {
    val orientation = readInt(requestMap, "orientation", TTAdConstant.VERTICAL)
    val adSlot = AdSlot.Builder()
      .setCodeId(placementId)
      .setOrientation(orientation)
      .setMediationAdSlot(GromoreAdRequestOptions(requestMap).mediationSlot())
      .build()

    val adNative = TTAdSdk.getAdManager().createAdNative(activity)
    val holder = FullScreenAdHolder(adId, placementId, adType)
    holder.factoryId = GromoreAdRequestOptions(requestMap).string("nativeRenderFactoryId")
    adHolders[adId] = holder

    val listener = object : TTAdNative.FullScreenVideoAdListener {
      override fun onError(code: Int, message: String?) {
        if (holder.disposed) return
        emitLog("error", "fullscreen load fail: $adId, code=$code, msg=$message", "ad")
        emitAdError(adId, holder.adType, placementId, code.toString(), message)
      }

      override fun onFullScreenVideoAdLoad(ad: TTFullScreenVideoAd?) {
        if (holder.disposed) { ad?.mediationManager?.destroy(); return }
        if (ad == null) {
          emitAdError(adId, holder.adType, placementId, "empty_ad", "SDK returned no ad")
          return
        }
        emitLog("info", "fullscreen load success: $adId", "ad")
        holder.ad = ad
        if (ad != null) bindNativeEvents(holder, ad)
        emitAdLoaded(holder)
      }

      override fun onFullScreenVideoCached() {
        if (holder.disposed) return
        emitLog("info", "fullscreen cached: $adId", "ad")
        emitCached(holder)
      }

      override fun onFullScreenVideoCached(ad: TTFullScreenVideoAd?) {
        if (holder.disposed) { ad?.mediationManager?.destroy(); return }
        holder.ad = ad
        emitLog("info", "fullscreen cached with ad: $adId", "ad")
        emitCached(holder)
      }
    }
    holder.loadListener = listener
    adNative.loadFullScreenVideoAd(adSlot, listener)
  }

  /** 展示插全屏广告 */
  private fun showFullScreenAd(holder: FullScreenAdHolder) {
    val activity = activityProvider()
    val ad = holder.ad
    if (activity == null || ad == null) {
      failShow(holder, "not_ready", "Missing activity or ad")
    }
    if (!ad.mediationManager.isReady) {
      failShow(holder, "not_ready", "Fullscreen ad is not ready")
    }
    val interactionListener = object : TTFullScreenVideoAd.FullScreenVideoAdInteractionListener {
      override fun onAdShow() {
        if (holder.disposed) return
        emitLog("info", "fullscreen shown: ${holder.adId}", "ad")
        emitAdShownOnce(holder)
      }

      override fun onAdVideoBarClick() {
        if (holder.disposed) return
        emitLog("info", "fullscreen clicked: ${holder.adId}", "ad")
        emitAdClicked(holder)
      }

      override fun onAdClose() {
        if (holder.disposed) return
        emitLog("info", "fullscreen closed: ${holder.adId}", "ad")
        emitAdClosed(holder)
      }

      override fun onVideoComplete() {
        if (holder.disposed) return
        emitLog("info", "fullscreen video complete: ${holder.adId}", "ad")
        emitAdCompleted(holder)
      }

      override fun onSkippedVideo() {
        if (holder.disposed) return
        emitLog("info", "fullscreen skipped: ${holder.adId}", "ad")
        emitAdSkipped(holder)
      }
    }
    holder.showListener = interactionListener
    ad.setFullScreenVideoAdInteractionListener(interactionListener)
    ad.showFullScreenVideoAd(activity)
  }

  /** 加载 Banner 广告 */
  private fun loadBannerAd(
    activity: Activity,
    adId: String,
    placementId: String,
    requestMap: Map<*, *>
  ) {
    val width = GromoreAdRequestOptions(requestMap).dimensionPx("width", activity.resources.displayMetrics.density, dpToPx(activity, 320f))
    val height = GromoreAdRequestOptions(requestMap).dimensionPx("height", activity.resources.displayMetrics.density, dpToPx(activity, 150f))
    val adSlot = AdSlot.Builder()
      .setCodeId(placementId)
      .setImageAcceptedSize(width, height)
      .setMediationAdSlot(GromoreAdRequestOptions(requestMap).mediationSlot(bannerListener = bannerRenderer(activity, requestMap)))
      .build()

    val adNative = TTAdSdk.getAdManager().createAdNative(activity)
    val holder = BannerAdHolder(adId, placementId)
    holder.factoryId = GromoreAdRequestOptions(requestMap).string("nativeRenderFactoryId")
    adHolders[adId] = holder

    val listener = object : TTAdNative.NativeExpressAdListener {
      override fun onNativeExpressAdLoad(ads: MutableList<TTNativeExpressAd>?) {
        if (holder.disposed) { ads?.forEach { it.destroy() }; return }
        val ad = ads?.firstOrNull()
        if (ad == null) {
          emitAdError(adId, holder.adType, placementId, "empty_ad", "No banner ad returned.")
          return
        }
        ads?.drop(1)?.forEach { it.destroy() }
        holder.ad = ad
        emitLog("info", "banner load success: $adId", "ad")
        emitAdLoaded(holder)
        if (holder.container != null) attachBannerView(holder)
      }

      override fun onError(code: Int, message: String?) {
        if (holder.disposed) return
        emitLog("error", "banner load fail: $adId, code=$code, msg=$message", "ad")
        emitAdError(adId, holder.adType, placementId, code.toString(), message)
      }
    }
    holder.loadListener = listener
    adNative.loadBannerExpressAd(adSlot, listener)
  }

  private fun bannerRenderer(activity: Activity, request: Map<*, *>): com.bytedance.sdk.openadsdk.mediation.ad.MediationNativeToBannerListener {
    return object : com.bytedance.sdk.openadsdk.mediation.ad.MediationNativeToBannerListener() {
      override fun getMediationBannerViewFromNativeAd(ad: IMediationNativeAdInfo): View {
        val id = GromoreAdRequestOptions(request).string("nativeRenderFactoryId")
        if (id != null) {
          val factory = GromoreNativeRenderRegistry.bannerFactory(id)
            ?: throw GromoreAdException("factory_not_found", "No banner factory: $id")
          return factory.create(activity, ad)
        }
        val root = LayoutInflater.from(activity).inflate(R.layout.gromore_banner_native, null, false) as ViewGroup
        root.findViewById<TextView>(R.id.gromore_feed_title).text = ad.title
        root.findViewById<TextView>(R.id.gromore_feed_desc).text = ad.description
        root.findViewById<TextView>(R.id.gromore_feed_source).text = ad.source
        val cta = root.findViewById<TextView>(R.id.gromore_feed_cta)
        cta.text = ad.actionText
        loadImageInto(ad.iconUrl, root.findViewById(R.id.gromore_feed_icon))
        loadImageInto(ad.imageUrl, root.findViewById(R.id.gromore_feed_main_image))
        val binder = MediationViewBinder.Builder(R.layout.gromore_banner_native)
          .titleId(R.id.gromore_feed_title).descriptionTextId(R.id.gromore_feed_desc)
          .callToActionId(R.id.gromore_feed_cta).iconImageId(R.id.gromore_feed_icon)
          .mainImageId(R.id.gromore_feed_main_image).mediaViewIdId(R.id.gromore_feed_media)
          .sourceId(R.id.gromore_feed_source).logoLayoutId(R.id.gromore_banner_logo).build()
        ad.registerView(activity, root, listOf(root, cta), listOf(cta), emptyList(), binder)
        return root
      }
    }
  }

  /** 绑定 Banner 视图 */
  private fun attachBannerView(holder: BannerAdHolder) {
    val activity = activityProvider()
    val ad = holder.ad
    if (activity == null || ad == null) {
      emitLog("warn", "attachBannerView failed: missing activity or ad", "ad")
      return
    }
    ad.setExpressInteractionListener(object : TTNativeExpressAd.ExpressAdInteractionListener {
      override fun onAdClicked(view: View?, type: Int) {
        if (holder.disposed) return
        emitAdClicked(holder)
      }

      override fun onAdShow(view: View?, type: Int) {
        if (holder.disposed) return
        emitAdShown(holder)
      }

      override fun onRenderFail(view: View?, msg: String?, code: Int) {
        if (holder.disposed) return
        emitAdError(holder.adId, holder.adType, holder.placementId, code.toString(), msg, phase = "render")
      }

      override fun onRenderSuccess(view: View?, width: Float, height: Float) {
        if (holder.disposed) return
        emitLog("info", "banner render success: ${holder.adId}, width=$width, height=$height", "ad")
        emitAdRendered(holder, width, height)
      }
    })
    ad.setDislikeCallback(activity, object : TTAdDislike.DislikeInteractionCallback {
      override fun onShow() {
        if (holder.disposed) return
        emitLog("info", "banner dislike show: ${holder.adId}", "ad")
      }

      override fun onSelected(position: Int, value: String?, enforce: Boolean) {
        if (holder.disposed) return
        emitLog("info", "banner dislike selected: ${holder.adId}", "ad")
        emitExtra(holder, "dislike", mapOf("reason" to value, "position" to position))
        emitAdClosedOnce(holder, mapOf("dislike" to true, "value" to value))
        holder.container?.removeAllViews()
      }

      override fun onCancel() {
        if (holder.disposed) return
        emitLog("info", "banner dislike cancel: ${holder.adId}", "ad")
      }
    })

    val view = ad.expressAdView
    if (view != null) {
      view.removeFromParent()
      holder.container?.removeAllViews()
      holder.container?.addView(
        view,
        FrameLayout.LayoutParams(
          ViewGroup.LayoutParams.MATCH_PARENT,
          ViewGroup.LayoutParams.MATCH_PARENT
        )
      )
    }
  }

  /** 加载信息流广告 */
  private fun loadFeedAd(
    activity: Activity,
    adId: String,
    adType: String,
    placementId: String,
    requestMap: Map<*, *>
  ) {
    val width = GromoreAdRequestOptions(requestMap).dimensionPx("width", activity.resources.displayMetrics.density, activity.resources.displayMetrics.widthPixels)
    val height = GromoreAdRequestOptions(requestMap).dimensionPx("height", activity.resources.displayMetrics.density, 720)
    val requestedAdCount = readInt(requestMap, "adCount", 1)
    val adCount = requestedAdCount.coerceIn(1, 3)
    if (requestedAdCount != adCount) {
      emitLog("warn", "feed adCount out of range, clamped from $requestedAdCount to $adCount", "ad")
    }
    val adSlot = AdSlot.Builder()
      .setCodeId(placementId)
      .setImageAcceptedSize(width, height)
      .setAdCount(adCount)
      .setMediationAdSlot(GromoreAdRequestOptions(requestMap).mediationSlot())
      .build()

    val adNative = TTAdSdk.getAdManager().createAdNative(activity)
    val holder = FeedAdHolder(adId, placementId, adType)
    holder.factoryId = GromoreAdRequestOptions(requestMap).string("nativeRenderFactoryId")
    adHolders[adId] = holder

    val listener = object : TTAdNative.FeedAdListener {
      override fun onError(code: Int, message: String?) {
        if (holder.disposed) return
        emitLog("error", "feed load fail: $adId, code=$code, msg=$message", "ad")
        emitAdError(adId, holder.adType, placementId, code.toString(), message)
      }

      override fun onFeedAdLoad(ads: MutableList<TTFeedAd>?) {
        if (holder.disposed) { ads?.forEach { it.destroy() }; return }
        val ad = ads?.firstOrNull()
        if (ad == null) {
          emitAdError(adId, holder.adType, placementId, "empty_ad", "No feed ad returned.")
          return
        }
        val items = ads ?: return
        val holders = items.mapIndexed { index, _ ->
          val target = if (index == 0) holder else FeedAdHolder(newAdId(), placementId, adType)
          target.factoryId = holder.factoryId
          adHolders[target.adId] = target
          target
        }
        val ids = holders.map { it.adId }
        holders.forEach { it.batchIds = ids }
        items.zip(holders).forEach { (item, target) -> prepareFeed(activity, target, item) }
      }
    }
    holder.loadListener = listener
    adNative.loadFeedAd(adSlot, listener)
  }

  /** 加载 Draw 信息流广告 */
  private fun loadDrawAd(
    activity: Activity,
    adId: String,
    adType: String,
    placementId: String,
    requestMap: Map<*, *>
  ) {
    val width = GromoreAdRequestOptions(requestMap).dimensionPx("width", activity.resources.displayMetrics.density, activity.resources.displayMetrics.widthPixels)
    val height = GromoreAdRequestOptions(requestMap).dimensionPx("height", activity.resources.displayMetrics.density, activity.resources.displayMetrics.heightPixels)
    val requestedAdCount = readInt(requestMap, "adCount", 1)
    val adCount = requestedAdCount.coerceIn(1, 3)
    if (requestedAdCount != adCount) {
      emitLog("warn", "draw adCount out of range, clamped from $requestedAdCount to $adCount", "ad")
    }
    val adSlot = AdSlot.Builder()
      .setCodeId(placementId)
      .setImageAcceptedSize(width, height)
      .setAdCount(adCount)
      .setMediationAdSlot(GromoreAdRequestOptions(requestMap).mediationSlot())
      .build()

    val adNative = TTAdSdk.getAdManager().createAdNative(activity)
    val holder = DrawAdHolder(adId, placementId, adType)
    holder.factoryId = GromoreAdRequestOptions(requestMap).string("nativeRenderFactoryId")
    adHolders[adId] = holder

    val listener = object : TTAdNative.DrawFeedAdListener {
      override fun onError(code: Int, message: String?) {
        if (holder.disposed) return
        emitLog("error", "draw load fail: $adId, code=$code, msg=$message", "ad")
        emitAdError(adId, holder.adType, placementId, code.toString(), message)
      }

      override fun onDrawFeedAdLoad(ads: MutableList<TTDrawFeedAd>?) {
        if (holder.disposed) { ads?.forEach { it.destroy() }; return }
        val ad = ads?.firstOrNull()
        if (ad == null) {
          emitAdError(adId, holder.adType, placementId, "empty_ad", "No draw ad returned.")
          return
        }
        val items = ads ?: return
        val holders = items.mapIndexed { index, _ ->
          val target = if (index == 0) holder else DrawAdHolder(newAdId(), placementId, adType)
          target.factoryId = holder.factoryId
          adHolders[target.adId] = target
          target
        }
        val ids = holders.map { it.adId }
        holders.forEach { it.batchIds = ids }
        items.zip(holders).forEach { (item, target) -> prepareDraw(activity, target, item) }
      }
    }
    holder.loadListener = listener
    adNative.loadDrawFeedAd(adSlot, listener)
  }

  private fun prepareFeed(activity: Activity, holder: FeedAdHolder, ad: TTFeedAd) {
    holder.ad = ad
    syncVideo(holder)
    bindFeedDislikeCallback(activity, holder, ad)
    emitLog("info", "feed load success: ${holder.adId}", "ad")
    bindVideoEvents(holder, ad)
    bindNativeEvents(holder, ad)
    emitAdLoaded(holder)
    if (ad.mediationManager.isExpress) {
      val renderListener = object : MediationExpressRenderListener {
        override fun onRenderSuccess(view: View?, width: Float, height: Float, isExpress: Boolean) {
          if (holder.disposed) return
          holder.renderedView = ad.adView
          emitLog("info", "feed render success: ${holder.adId}", "ad")
          emitFeedRendered(holder, width, height)
          attachFeedView(holder)
        }

        override fun onRenderFail(view: View?, msg: String?, code: Int) {
          if (holder.disposed) return
          emitLog("error", "feed render fail: ${holder.adId}, code=$code, msg=$msg", "ad")
          emitAdError(holder.adId, holder.adType, holder.placementId, code.toString(), msg, phase = "render")
        }

        override fun onAdClick() {
          if (holder.disposed) return
          emitAdClicked(holder)
        }

        override fun onAdShow() {
          if (holder.disposed) return
          emitAdShownOnce(holder)
        }
      }
      holder.renderListener = renderListener
      ad.setExpressRenderListener(renderListener)
      ad.render()
    } else {
      emitLog("info", "feed native render detected, using built-in native feed view", "ad")
      attachFeedView(holder)
    }
  }

  private fun prepareDraw(activity: Activity, holder: DrawAdHolder, ad: TTDrawFeedAd) {
    holder.ad = ad
    syncVideo(holder)
    bindFeedDislikeCallback(activity, holder, ad)
    emitLog("info", "draw load success: ${holder.adId}", "ad")
    bindVideoEvents(holder, ad)
    bindNativeEvents(holder, ad)
    emitAdLoaded(holder)
    if (ad.mediationManager.isExpress) {
      val renderListener = object : MediationExpressRenderListener {
        override fun onRenderSuccess(view: View?, width: Float, height: Float, isExpress: Boolean) {
          if (holder.disposed) return
          holder.renderedView = ad.adView
          emitLog("info", "draw render success: ${holder.adId}", "ad")
          emitDrawRendered(holder, width, height)
          attachDrawView(holder)
        }

        override fun onRenderFail(view: View?, msg: String?, code: Int) {
          if (holder.disposed) return
          emitLog("error", "draw render fail: ${holder.adId}, code=$code, msg=$msg", "ad")
          emitAdError(holder.adId, holder.adType, holder.placementId, code.toString(), msg, phase = "render")
        }

        override fun onAdClick() {
          if (holder.disposed) return
          emitAdClicked(holder)
        }

        override fun onAdShow() {
          if (holder.disposed) return
          emitAdShownOnce(holder)
        }
      }
      holder.renderListener = renderListener
      ad.setExpressRenderListener(renderListener)
      ad.render()
    } else {
      emitLog("info", "draw native render detected, using built-in native draw view", "ad")
      attachDrawView(holder)
    }
  }

  /** 绑定信息流视图 */
  private fun attachFeedView(holder: FeedAdHolder) {
    val ad = holder.ad ?: return
    val view = if (ad.mediationManager.isExpress) {
      holder.renderedView ?: ad.adView
    } else {
      val activity = activityProvider()
      if (activity == null) {
        emitLog("warn", "attachFeedView failed: missing activity for native render", "ad")
        return
      }
      holder.renderedView ?: renderCustom(holder, activity, ad) { buildNativeFeedView(activity, holder, ad) }.also {
        holder.renderedView = it
      }
    }
    if (view != null) {
      view.removeFromParent()
      holder.container?.removeAllViews()
      holder.container?.addView(
        view,
        FrameLayout.LayoutParams(
          ViewGroup.LayoutParams.MATCH_PARENT,
          ViewGroup.LayoutParams.MATCH_PARENT
        )
      )
      syncVideo(holder)
      if (!holder.renderEventSent) {
        view.post {
          emitFeedRendered(holder, view.width.toFloat(), view.height.toFloat())
        }
      }
    }
  }

  /** 绑定 Draw 视图 */
  private fun attachDrawView(holder: DrawAdHolder) {
    val ad = holder.ad ?: return
    val view = if (ad.mediationManager.isExpress) {
      holder.renderedView ?: ad.adView
    } else {
      val activity = activityProvider()
      if (activity == null) {
        emitLog("warn", "attachDrawView failed: missing activity for native render", "ad")
        return
      }
      holder.renderedView ?: renderCustom(holder, activity, ad) { buildNativeDrawView(activity, holder, ad) }.also {
        holder.renderedView = it
      }
    }
    if (view != null) {
      view.removeFromParent()
      holder.container?.removeAllViews()
      holder.container?.addView(
        view,
        FrameLayout.LayoutParams(
          ViewGroup.LayoutParams.MATCH_PARENT,
          ViewGroup.LayoutParams.MATCH_PARENT
        )
      )
      syncVideo(holder)
      if (!holder.renderEventSent) {
        view.post {
          emitDrawRendered(holder, view.width.toFloat(), view.height.toFloat())
        }
      }
    }
  }

  /** 绑定信息流 dislike 回调 */
  private fun bindFeedDislikeCallback(activity: Activity, holder: GromoreAdHolder, ad: TTNativeAd) {
    ad.setDislikeCallback(activity, object : TTAdDislike.DislikeInteractionCallback {
      override fun onShow() {
        if (holder.disposed) return
        emitLog("info", "feed dislike show: ${holder.adId}", "ad")
      }

      override fun onSelected(position: Int, value: String?, enforce: Boolean) {
        if (holder.disposed) return
        emitLog("info", "feed dislike selected: ${holder.adId}", "ad")
        emitExtra(holder, "dislike", mapOf("reason" to value, "position" to position))
        emitAdClosedOnce(holder, mapOf("dislike" to true, "value" to value))
        holder.container?.removeAllViews()
      }

      override fun onCancel() {
        if (holder.disposed) return
        emitLog("info", "feed dislike cancel: ${holder.adId}", "ad")
      }
    })
  }

  private fun renderCustom(holder: GromoreAdHolder, activity: Activity, ad: TTFeedAd, fallback: () -> View): View {
    val id = holder.factoryId ?: return fallback()
    val factory = GromoreNativeRenderRegistry.factory(id)
    if (factory == null) {
      emitAdError(holder.adId, holder.adType, holder.placementId, "factory_not_found", "No native factory: $id")
      return FrameLayout(activity)
    }
    return factory.create(activity, ad, holder.adType)
  }

  /** 内置默认自渲染信息流视图 */
  private fun buildNativeFeedView(activity: Activity, holder: FeedAdHolder, ad: TTFeedAd): View {
    val root = LayoutInflater.from(activity).inflate(R.layout.gromore_feed_native, null, false)
    val titleView = root.findViewById<TextView>(R.id.gromore_feed_title)
    val descView = root.findViewById<TextView>(R.id.gromore_feed_desc)
    val sourceView = root.findViewById<TextView>(R.id.gromore_feed_source)
    val ctaView = root.findViewById<TextView>(R.id.gromore_feed_cta)
    val iconView = root.findViewById<ImageView>(R.id.gromore_feed_icon)
    val mainImageView = root.findViewById<ImageView>(R.id.gromore_feed_main_image)
    val mediaView = root.findViewById<FrameLayout>(R.id.gromore_feed_media)
    val badgeView = root.findViewById<TextView>(R.id.gromore_feed_ad_badge)
    val closeView = root.findViewById<TextView>(R.id.gromore_feed_close)

    titleView.text = ad.title.orEmpty().ifBlank { "广告推荐" }
    descView.text = ad.description.orEmpty().ifBlank { "精彩内容，点击查看详情" }
    sourceView.text = ad.source.orEmpty().ifBlank { "广告" }
    ctaView.text = ad.buttonText.orEmpty().ifBlank { defaultCallToAction(ad) }

    badgeView.background = roundedDrawable(
      backgroundColor = Color.parseColor("#F3F4F6"),
      strokeColor = Color.parseColor("#E5E7EB"),
      radiusDp = 10f
    )
    ctaView.background = roundedDrawable(
      backgroundColor = Color.parseColor("#2563EB"),
      strokeColor = Color.TRANSPARENT,
      radiusDp = 14f
    )

    val icon = ad.icon
    if (icon?.isValid == true) {
      iconView.visibility = View.VISIBLE
      loadImageInto(icon.imageUrl, iconView)
    } else {
      iconView.visibility = View.GONE
    }

    val mainImage = ad.imageList?.firstOrNull()
    val isVideoLike = ad.videoDuration > 0 || ad.getVideoCoverImage()?.isValid == true
    if (isVideoLike) {
      mediaView.visibility = View.VISIBLE
      mainImageView.visibility = View.GONE
    } else if (mainImage?.isValid == true) {
      mediaView.visibility = View.VISIBLE
      mainImageView.visibility = View.VISIBLE
      loadImageInto(mainImage.imageUrl, mainImageView)
    } else {
      mediaView.visibility = View.GONE
    }

    closeView.setOnClickListener {
      // 自渲染信息流的关闭按钮不一定经过 SDK dislike 回调，先把用户关闭动作
      // 透传到 Flutter；onSelected 到达时由 emitAdClosedOnce 去重。
      emitAdClosedOnce(holder, mapOf("dislike" to true, "source" to "close_button"))
      ad.getDislikeDialog(activity)?.showDislikeDialog()
    }

    ad.setActivityForDownloadApp(activity)
    bindNativeFeedDownloadListener(holder, ctaView, ad)

    val clickViews = mutableListOf<View>(root, titleView, descView, sourceView, ctaView)
    val creativeViews = mutableListOf<View>(ctaView)
    if (iconView.visibility == View.VISIBLE) {
      clickViews.add(iconView)
    }
    if (mediaView.visibility == View.VISIBLE) {
      clickViews.add(mediaView)
      creativeViews.add(mediaView)
    }
    if (mainImageView.visibility == View.VISIBLE) {
      clickViews.add(mainImageView)
      creativeViews.add(mainImageView)
    }

    val binder = MediationViewBinder.Builder(R.layout.gromore_feed_native)
      .titleId(R.id.gromore_feed_title)
      .descriptionTextId(R.id.gromore_feed_desc)
      .sourceId(R.id.gromore_feed_source)
      .callToActionId(R.id.gromore_feed_cta)
      .iconImageId(R.id.gromore_feed_icon)
      .mainImageId(R.id.gromore_feed_main_image)
      .mediaViewIdId(R.id.gromore_feed_media)
      .logoLayoutId(R.id.gromore_feed_ad_badge)
      .build()

    val interactionListener = object : TTNativeAd.AdInteractionListener {
      override fun onAdClicked(view: View, nativeAd: TTNativeAd) {
        if (holder.disposed) return
        emitAdClicked(holder)
      }

      override fun onAdCreativeClick(view: View, nativeAd: TTNativeAd) {
        if (holder.disposed) return
        emitAdClicked(holder)
      }

      override fun onAdShow(nativeAd: TTNativeAd) {
        if (holder.disposed) return
        emitAdShownOnce(holder)
      }
    }

    // GroMore 7.8 removed the legacy TTNativeAd overload that accepted an
    // Activity and MediationViewBinder. Mediation native ads now expose the
    // binder registration through IMediationNativeAdInfo; non-mediation ads
    // continue to use TTNativeAd's standard registration API.
    val mediationAd = ad as? IMediationNativeAdInfo
    val rootGroup = root as ViewGroup
    if (mediationAd != null) {
      mediationAd.registerView(
        activity,
        rootGroup,
        clickViews,
        creativeViews,
        emptyList(),
        binder
      )
    } else {
      ad.registerViewForInteraction(
        rootGroup,
        clickViews,
        creativeViews,
        interactionListener
      )
    }
    return root
  }

  /** 内置默认 Draw 自渲染视图 */
  private fun buildNativeDrawView(activity: Activity, holder: DrawAdHolder, ad: TTDrawFeedAd): View {
    val root = LayoutInflater.from(activity).inflate(R.layout.gromore_draw_native, null, false)
    val titleView = root.findViewById<TextView>(R.id.gromore_draw_title)
    val descView = root.findViewById<TextView>(R.id.gromore_draw_desc)
    val sourceView = root.findViewById<TextView>(R.id.gromore_draw_source)
    val ctaView = root.findViewById<TextView>(R.id.gromore_draw_cta)
    val mediaView = root.findViewById<FrameLayout>(R.id.gromore_draw_media)
    val mainImageView = root.findViewById<ImageView>(R.id.gromore_draw_main_image)

    titleView.text = ad.title.orEmpty().ifBlank { "精彩广告内容" }
    descView.text = ad.description.orEmpty().ifBlank { "上下滑动查看更多精彩内容" }
    sourceView.text = ad.source.orEmpty().ifBlank { "广告" }
    ctaView.text = ad.buttonText.orEmpty().ifBlank { defaultCallToAction(ad) }
    ctaView.background = roundedDrawable(
      backgroundColor = Color.parseColor("#2563EB"),
      strokeColor = Color.TRANSPARENT,
      radiusDp = 18f
    )

    val mainImage = ad.imageList?.firstOrNull()
    val isVideoLike = ad.videoDuration > 0 || ad.getVideoCoverImage()?.isValid == true
    if (isVideoLike) {
      mainImageView.visibility = View.GONE
    } else if (mainImage?.isValid == true) {
      mainImageView.visibility = View.VISIBLE
      loadImageInto(mainImage.imageUrl, mainImageView)
    } else {
      mainImageView.visibility = View.GONE
    }

    ad.setActivityForDownloadApp(activity)
    bindNativeFeedDownloadListener(holder, ctaView, ad)

    val clickViews = mutableListOf<View>(root, mediaView, ctaView, titleView, descView)
    val creativeViews = mutableListOf<View>(mediaView, ctaView)
    ad.registerViewForInteraction(
      mediaView as ViewGroup,
      clickViews,
      creativeViews,
      object : TTNativeAd.AdInteractionListener {
        override fun onAdClicked(view: View, nativeAd: TTNativeAd) {
          if (holder.disposed) return
          emitAdClicked(holder)
        }

        override fun onAdCreativeClick(view: View, nativeAd: TTNativeAd) {
          if (holder.disposed) return
          emitAdClicked(holder)
        }

        override fun onAdShow(nativeAd: TTNativeAd) {
          if (holder.disposed) return
          emitAdShownOnce(holder)
        }
      }
    )
    return root
  }

  /** 原生自渲染下载按钮状态联动 */
  private fun bindNativeFeedDownloadListener(holder: GromoreAdHolder, ctaView: TextView, ad: TTNativeAd) {
    ad.setDownloadListener(object : TTAppDownloadListener {
      override fun onIdle() {
        if (holder.disposed) return
        emitExtra(holder, "downloadChanged", mapOf("state" to "idle"))
        ctaView.post { ctaView.text = ad.buttonText.orEmpty().ifBlank { defaultCallToAction(ad) } }
      }

      override fun onDownloadActive(totalBytes: Long, currBytes: Long, fileName: String?, appName: String?) {
        if (holder.disposed) return
        emitExtra(holder, "downloadChanged", mapOf("state" to "active", "totalBytes" to totalBytes, "currentBytes" to currBytes))
        val progress = if (totalBytes > 0) ((currBytes * 100) / totalBytes).toInt() else 0
        ctaView.post { ctaView.text = "下载中 $progress%" }
      }

      override fun onDownloadPaused(totalBytes: Long, currBytes: Long, fileName: String?, appName: String?) {
        if (holder.disposed) return
        emitExtra(holder, "downloadChanged", mapOf("state" to "paused"))
        ctaView.post { ctaView.text = "继续下载" }
      }

      override fun onDownloadFailed(totalBytes: Long, currBytes: Long, fileName: String?, appName: String?) {
        if (holder.disposed) return
        emitExtra(holder, "downloadChanged", mapOf("state" to "failed"))
        ctaView.post { ctaView.text = "重新下载" }
      }

      override fun onDownloadFinished(totalBytes: Long, fileName: String?, appName: String?) {
        if (holder.disposed) return
        emitExtra(holder, "downloadChanged", mapOf("state" to "finished"))
        ctaView.post { ctaView.text = "立即安装" }
      }

      override fun onInstalled(fileName: String?, appName: String?) {
        if (holder.disposed) return
        emitExtra(holder, "downloadChanged", mapOf("state" to "installed"))
        ctaView.post { ctaView.text = "立即打开" }
      }
    })
  }

  /** 加载远程图片 */
  private fun loadImageInto(url: String?, imageView: ImageView) {
    if (url.isNullOrBlank()) {
      return
    }
    Thread {
      runCatching {
        URL(url).openStream().use { input ->
          BitmapFactory.decodeStream(input)
        }
      }.onSuccess { bitmap ->
        if (bitmap != null) {
          imageView.post { imageView.setImageBitmap(bitmap) }
        }
      }
    }.start()
  }

  /** 默认 CTA 文案 */
  private fun defaultCallToAction(ad: TTNativeAd): String {
    return when (ad.interactionType) {
      TTAdConstant.INTERACTION_TYPE_DOWNLOAD -> "立即下载"
      TTAdConstant.INTERACTION_TYPE_LANDING_PAGE -> "查看详情"
      TTAdConstant.INTERACTION_TYPE_BROWSER -> "立即查看"
      else -> "立即查看"
    }
  }

  /** 圆角背景 */
  private fun roundedDrawable(backgroundColor: Int, strokeColor: Int, radiusDp: Float): GradientDrawable {
    return GradientDrawable().apply {
      shape = GradientDrawable.RECTANGLE
      cornerRadius = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        radiusDp,
        appContext.resources.displayMetrics
      )
      setColor(backgroundColor)
      if (strokeColor != Color.TRANSPARENT) {
        setStroke(dpToPx(appContext, 1f), strokeColor)
      }
    }
  }

  /** 信息流渲染完成事件（避免重复上报） */
  private fun emitFeedRendered(holder: FeedAdHolder, width: Float, height: Float) {
    if (holder.renderEventSent) {
      return
    }
    holder.renderEventSent = true
    emitAdRendered(holder, width, height)
  }

  /** Draw 渲染完成事件（避免重复上报） */
  private fun emitDrawRendered(holder: DrawAdHolder, width: Float, height: Float) {
    if (holder.renderEventSent) {
      return
    }
    holder.renderEventSent = true
    emitAdRendered(holder, width, height)
  }

  /** 广告加载成功事件 */
  private fun emitAdLoaded(holder: GromoreAdHolder) {
    if (holder.disposed) return
    val ecpm = holder.mediationEcpmInfo()
    holder.loading = false
    val data = mapOf("ecpmInfo" to ecpm, "adIds" to holder.batchIds)
    postAdEvent(
      mapOf(
        "adId" to holder.adId,
        "adType" to holder.adType,
        "eventType" to "loaded",
        "placementId" to holder.placementId,
        "data" to data
      )
    )
  }

  /** 广告展示事件 */
  private fun emitAdShown(holder: GromoreAdHolder) {
    if (holder.disposed) return
    val ecpm = holder.mediationEcpmInfo()
    val data = if (ecpm == null) null else mapOf("ecpmInfo" to ecpm)
    postAdEvent(
      mapOf(
        "adId" to holder.adId,
        "adType" to holder.adType,
        "eventType" to "shown",
        "placementId" to holder.placementId,
        "data" to data
      )
    )
  }

  /** 广告展示事件（同一广告实例只上报一次，兼容聚合源重复/缺失回调）。 */
  private fun emitAdShownOnce(holder: GromoreAdHolder) {
    if (holder.disposed) return
    if (holder.shownEventSent) return
    holder.shownEventSent = true
    emitAdShown(holder)
  }

  /** 广告模板渲染完成事件（返回真实渲染尺寸） */
  private fun emitAdRendered(holder: GromoreAdHolder, width: Float, height: Float) {
    if (holder.disposed) return
    postAdEvent(
      mapOf(
        "adId" to holder.adId,
        "adType" to holder.adType,
        "eventType" to "rendered",
        "placementId" to holder.placementId,
        "data" to mapOf(
          "renderWidth" to width.toDouble(),
          "renderHeight" to height.toDouble()
        )
      )
    )
  }

  /** 广告点击事件 */
  private fun emitAdClicked(holder: GromoreAdHolder) {
    if (holder.disposed) return
    postAdEvent(
      mapOf(
        "adId" to holder.adId,
        "adType" to holder.adType,
        "eventType" to "clicked",
        "placementId" to holder.placementId
      )
    )
  }

  /** 广告关闭事件 */
  private fun emitAdClosed(holder: GromoreAdHolder, data: Map<String, Any?>? = null) {
    if (holder.disposed) return
    postAdEvent(
      mapOf(
        "adId" to holder.adId,
        "adType" to holder.adType,
        "eventType" to "closed",
        "placementId" to holder.placementId,
        "data" to data
      )
    )
  }

  /** 信息流关闭事件去重。 */
  private fun emitAdClosedOnce(holder: GromoreAdHolder, data: Map<String, Any?>? = null) {
    if (holder.disposed) return
    if (holder.closeEventSent) return
    holder.closeEventSent = true
    emitAdClosed(holder, data)
  }

  /** 激励到账事件 */
  private fun emitAdRewarded(holder: GromoreAdHolder, data: Map<String, Any?>? = null) {
    if (holder.disposed) return
    val rewardData = (holder as? RewardAdHolder)?.rewardData.orEmpty() + data.orEmpty().filterValues { it != null }
    postAdEvent(
      mapOf(
        "adId" to holder.adId,
        "adType" to holder.adType,
        "eventType" to "rewarded",
        "placementId" to holder.placementId,
        "data" to rewardData
      )
    )
  }

  /** 广告播放完成事件 */
  private fun emitAdCompleted(holder: GromoreAdHolder, data: Map<String, Any?>? = null) {
    if (holder.disposed) return
    postAdEvent(
      mapOf(
        "adId" to holder.adId,
        "adType" to holder.adType,
        "eventType" to "completed",
        "placementId" to holder.placementId,
        "data" to data
      )
    )
  }

  /** 广告跳过事件 */
  private fun emitAdSkipped(holder: GromoreAdHolder, data: Map<String, Any?>? = null) {
    if (holder.disposed) return
    postAdEvent(
      mapOf(
        "adId" to holder.adId,
        "adType" to holder.adType,
        "eventType" to "skipped",
        "placementId" to holder.placementId,
        "data" to data
      )
    )
  }

  /** 广告失败事件 */
  private fun emitAdError(
    adId: String,
    adType: String,
    placementId: String,
    errorCode: String?,
    errorMessage: String?,
    phase: String? = null
  ) {
    postAdEvent(
      mapOf(
        "adId" to adId,
        "adType" to adType,
        "eventType" to "failed",
        "placementId" to placementId,
        "errorCode" to errorCode,
        "errorMessage" to errorMessage,
        "data" to mapOf("phase" to (phase ?: when(errorCode) {
          "show_failed" -> "show"
          "video_error" -> "playback"
          "render_failed" -> "render"
          else -> "load"
        }))
      )
    )
  }

  /** 获取展示 Ecpm 信息 */
  private fun GromoreAdHolder.mediationEcpmInfo(): Map<String, Any?>? {
    val info: MediationAdEcpmInfo? = when (this) {
      is SplashAdHolder -> ad?.mediationManager?.showEcpm
      is RewardAdHolder -> ad?.mediationManager?.showEcpm
      is FullScreenAdHolder -> ad?.mediationManager?.showEcpm
      is BannerAdHolder -> ad?.mediationManager?.showEcpm
      is FeedAdHolder -> ad?.mediationManager?.showEcpm
      is DrawAdHolder -> ad?.mediationManager?.showEcpm
    }
    return ecpmMap(info)
  }

  private fun ecpmMap(info: MediationAdEcpmInfo?): Map<String, Any?>? {
    if (info == null) return null
    return mapOf(
      "sdkName" to info.sdkName,
      "customSdkName" to info.customSdkName,
      "slotId" to info.slotId,
      "ecpm" to info.ecpm,
      "reqBiddingType" to info.reqBiddingType,
      "levelTag" to info.levelTag,
      "errorMsg" to info.errorMsg,
      "requestId" to info.requestId,
      "ritType" to info.ritType,
      "abTestId" to info.abTestId,
      "scenarioId" to info.scenarioId,
      "segmentId" to info.segmentId,
      "channel" to info.channel,
      "subChannel" to info.subChannel,
      "customData" to info.customData
    )
  }

  /** 将 Bundle 转为 Map */
  private fun bundleToMap(bundle: Bundle?): Map<String, Any?> {
    if (bundle == null) return emptyMap()
    val map = mutableMapOf<String, Any?>()
    for (key in bundle.keySet()) {
      map[key] = codecValue(bundle.get(key))
    }
    return map
  }

  /** 读取请求参数中的整数值 */
  private fun readInt(source: Map<*, *>, key: String, fallback: Int): Int {
    return GromoreAdRequestOptions(source).int(key, fallback)
  }

  /** 发送广告事件（切到主线程） */
  private fun postAdEvent(payload: Map<String, Any?>) {
    if (payload["eventType"] == "failed") adHolders[payload["adId"]]?.loading = false
    val holder = adHolders[payload["adId"]]
    mainHandler.post {
      if (holder != null && (holder.disposed || adHolders[holder.adId] !== holder)) return@post
      emitAdEvent(payload)
    }
  }

  /** dp 转 px */
  private fun dpToPx(context: Context, dp: Float): Int {
    return TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, dp, context.resources.displayMetrics).toInt()
  }

  /** View 从父容器移除 */
  private fun View.removeFromParent() {
    val parent = parent
    if (parent is ViewGroup) {
      parent.removeView(this)
    }
  }

  /**
   * 广告基类
   *
   * @property adId 广告实例 ID
   * @property placementId 代码位
   */
  internal sealed class GromoreAdHolder(
    val adId: String,
    val placementId: String
  ) {
    /** 广告类型 */
    abstract val adType: String

    /** 当前绑定的容器视图 */
    var container: FrameLayout? = null

    /** 展示事件是否已上报 */
    var shownEventSent: Boolean = false

    /** 广告实例是否已销毁 */
    var disposed: Boolean = false
    var loading = true
    var videoPaused = false
    var cachedEventSent = false
    var batchIds = listOf(adId)
    var factoryId: String? = null

    /** 关闭事件是否已上报 */
    var closeEventSent: Boolean = false
  }

  /** 开屏广告实例 */
  internal class SplashAdHolder(adId: String, placementId: String) : GromoreAdHolder(adId, placementId) {
    override val adType: String = "splash"
    var logo: android.graphics.Bitmap? = null
    var logoHeight = 80
    var ad: CSJSplashAd? = null
    var loadListener: TTAdNative.CSJSplashAdListener? = null
    var showListener: CSJSplashAd.SplashAdListener? = null
  }

  /** 激励视频广告实例 */
  internal class RewardAdHolder(adId: String, placementId: String) : GromoreAdHolder(adId, placementId) {
    override val adType: String = "rewardVideo"
    var rewardData: Map<String, Any?> = emptyMap()
    var ad: TTRewardVideoAd? = null
    var loadListener: TTAdNative.RewardVideoAdListener? = null
    var showListener: TTRewardVideoAd.RewardAdInteractionListener? = null
  }

  /** 插全屏广告实例 */
  /**
   * 插全屏广告实例
   *
   * @param adType 广告类型（fullscreenVideo/interstitial）
   */
  internal class FullScreenAdHolder(
    adId: String,
    placementId: String,
    override val adType: String
  ) : GromoreAdHolder(adId, placementId) {
    var ad: TTFullScreenVideoAd? = null
    var loadListener: TTAdNative.FullScreenVideoAdListener? = null
    var showListener: TTFullScreenVideoAd.FullScreenVideoAdInteractionListener? = null
  }

  /** Banner 广告实例 */
  internal class BannerAdHolder(adId: String, placementId: String) : GromoreAdHolder(adId, placementId) {
    override val adType: String = "banner"
    var ad: TTNativeExpressAd? = null
    var loadListener: TTAdNative.NativeExpressAdListener? = null
  }

  /** 信息流广告实例 */
  internal class FeedAdHolder(
    adId: String,
    placementId: String,
    override val adType: String = "native"
  ) : GromoreAdHolder(adId, placementId) {
    var ad: TTFeedAd? = null
    var loadListener: TTAdNative.FeedAdListener? = null
    var renderListener: MediationExpressRenderListener? = null
    var renderedView: View? = null
    var renderEventSent: Boolean = false
  }

  /** Draw 信息流广告实例 */
  internal class DrawAdHolder(
    adId: String,
    placementId: String,
    override val adType: String = "draw_native"
  ) : GromoreAdHolder(adId, placementId) {
    var ad: TTDrawFeedAd? = null
    var loadListener: TTAdNative.DrawFeedAdListener? = null
    var renderListener: MediationExpressRenderListener? = null
    var renderedView: View? = null
    var renderEventSent: Boolean = false
  }
}
