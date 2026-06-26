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
import com.bytedance.sdk.openadsdk.mediation.manager.MediationAdEcpmInfo
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
  private val emitLog: (String, String, String) -> Unit
) {
  /** 主线程 Handler */
  private val mainHandler = Handler(Looper.getMainLooper())

  /** 广告实例缓存 */
  private val adHolders: MutableMap<String, GromoreAdHolder> = mutableMapOf()

  /**
   * 生成新的广告实例 ID
   */
  fun newAdId(): String = UUID.randomUUID().toString()

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
      emitLog("error", "showAd failed: adId not found: $adId", "ad")
      return
    }
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
    when (holder) {
      is SplashAdHolder -> holder.ad?.mediationManager?.destroy()
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
  }

  /** 加载开屏广告 */
  private fun loadSplashAd(
    activity: Activity,
    adId: String,
    placementId: String,
    requestMap: Map<*, *>
  ) {
    val width = readInt(requestMap, "width", activity.resources.displayMetrics.widthPixels)
    val height = readInt(requestMap, "height", activity.resources.displayMetrics.heightPixels)
    val timeout = readInt(requestMap, "splashTimeout", 3500)

    val adSlot = AdSlot.Builder()
      .setCodeId(placementId)
      .setImageAcceptedSize(width, height)
      .build()

    val adNative = TTAdSdk.getAdManager().createAdNative(activity)
    val holder = SplashAdHolder(adId, placementId)
    adHolders[adId] = holder

    val loadListener = object : TTAdNative.CSJSplashAdListener {
      override fun onSplashLoadSuccess(ad: CSJSplashAd?) {
        emitLog("info", "splash load success: $adId", "ad")
        holder.ad = ad
        emitAdLoaded(holder)
      }

      override fun onSplashLoadFail(error: CSJAdError?) {
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
        holder.ad = ad
        emitLog("info", "splash render success: $adId", "ad")
      }

      override fun onSplashRenderFail(ad: CSJSplashAd?, error: CSJAdError?) {
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
      emitLog("error", "showSplashAd failed: missing activity or ad", "ad")
      return
    }
    val splashListener = object : CSJSplashAd.SplashAdListener {
      override fun onSplashAdShow(ad: CSJSplashAd?) {
        emitLog("info", "splash shown: ${holder.adId}", "ad")
        emitAdShown(holder)
      }

      override fun onSplashAdClick(ad: CSJSplashAd?) {
        emitLog("info", "splash clicked: ${holder.adId}", "ad")
        emitAdClicked(holder)
      }

      override fun onSplashAdClose(ad: CSJSplashAd?, closeType: Int) {
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
        emitAdClosed(holder, mapOf("closeType" to closeTypeName))
      }
    }
    holder.showListener = splashListener
    ad.setSplashAdListener(splashListener)

    val splashView = ad.splashView ?: return
    val container = FrameLayout(activity)
    container.layoutParams = FrameLayout.LayoutParams(
      ViewGroup.LayoutParams.MATCH_PARENT,
      ViewGroup.LayoutParams.MATCH_PARENT
    )
    container.addView(
      splashView,
      FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT
      )
    )
    holder.container = container
    val decorView = activity.window.decorView as? ViewGroup
    decorView?.addView(container)
  }

  /** 加载激励视频广告 */
  private fun loadRewardAd(
    activity: Activity,
    adId: String,
    placementId: String,
    requestMap: Map<*, *>
  ) {
    val orientation = readInt(requestMap, "orientation", TTAdConstant.VERTICAL)
    val adSlot = AdSlot.Builder()
      .setCodeId(placementId)
      .setOrientation(orientation)
      .build()

    val adNative = TTAdSdk.getAdManager().createAdNative(activity)
    val holder = RewardAdHolder(adId, placementId)
    adHolders[adId] = holder

    val listener = object : TTAdNative.RewardVideoAdListener {
      override fun onError(code: Int, message: String?) {
        emitLog("error", "reward load fail: $adId, code=$code, msg=$message", "ad")
        emitAdError(adId, holder.adType, placementId, code.toString(), message)
      }

      override fun onRewardVideoAdLoad(ad: TTRewardVideoAd?) {
        emitLog("info", "reward load success: $adId", "ad")
        holder.ad = ad
        emitAdLoaded(holder)
      }

      override fun onRewardVideoCached() {
        emitLog("info", "reward cached: $adId", "ad")
      }

      override fun onRewardVideoCached(ad: TTRewardVideoAd?) {
        holder.ad = ad
        emitLog("info", "reward cached with ad: $adId", "ad")
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
      emitLog("error", "showRewardAd failed: missing activity or ad", "ad")
      return
    }
    if (!ad.mediationManager.isReady) {
      emitAdError(holder.adId, holder.adType, holder.placementId, "not_ready", "Reward ad is not ready.")
      return
    }
    val interactionListener = object : TTRewardVideoAd.RewardAdInteractionListener {
      override fun onAdShow() {
        emitLog("info", "reward shown: ${holder.adId}", "ad")
        emitAdShown(holder)
      }

      override fun onAdVideoBarClick() {
        emitLog("info", "reward clicked: ${holder.adId}", "ad")
        emitAdClicked(holder)
      }

      override fun onAdClose() {
        emitLog("info", "reward closed: ${holder.adId}", "ad")
        emitAdClosed(holder)
      }

      override fun onVideoComplete() {
        emitLog("info", "reward video complete: ${holder.adId}", "ad")
        emitAdCompleted(holder)
      }

      override fun onVideoError() {
        emitLog("error", "reward video error: ${holder.adId}", "ad")
      }

      override fun onRewardVerify(
        rewardVerify: Boolean,
        rewardAmount: Int,
        rewardName: String?,
        errorCode: Int,
        errorMsg: String?
      ) {
        // deprecated in GroMore，使用 onRewardArrived
      }

      override fun onRewardArrived(isRewardValid: Boolean, rewardType: Int, extraInfo: Bundle?) {
        val data = bundleToMap(extraInfo).toMutableMap()
        data["isRewardValid"] = isRewardValid
        data["rewardType"] = rewardType
        emitAdRewarded(holder, data)
      }

      override fun onSkippedVideo() {
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
      .build()

    val adNative = TTAdSdk.getAdManager().createAdNative(activity)
    val holder = FullScreenAdHolder(adId, placementId, adType)
    adHolders[adId] = holder

    val listener = object : TTAdNative.FullScreenVideoAdListener {
      override fun onError(code: Int, message: String?) {
        emitLog("error", "fullscreen load fail: $adId, code=$code, msg=$message", "ad")
        emitAdError(adId, holder.adType, placementId, code.toString(), message)
      }

      override fun onFullScreenVideoAdLoad(ad: TTFullScreenVideoAd?) {
        emitLog("info", "fullscreen load success: $adId", "ad")
        holder.ad = ad
        emitAdLoaded(holder)
      }

      override fun onFullScreenVideoCached() {
        emitLog("info", "fullscreen cached: $adId", "ad")
      }

      override fun onFullScreenVideoCached(ad: TTFullScreenVideoAd?) {
        holder.ad = ad
        emitLog("info", "fullscreen cached with ad: $adId", "ad")
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
      emitLog("error", "showFullScreenAd failed: missing activity or ad", "ad")
      return
    }
    if (!ad.mediationManager.isReady) {
      emitAdError(holder.adId, holder.adType, holder.placementId, "not_ready", "FullScreen ad is not ready.")
      return
    }
    val interactionListener = object : TTFullScreenVideoAd.FullScreenVideoAdInteractionListener {
      override fun onAdShow() {
        emitLog("info", "fullscreen shown: ${holder.adId}", "ad")
        emitAdShown(holder)
      }

      override fun onAdVideoBarClick() {
        emitLog("info", "fullscreen clicked: ${holder.adId}", "ad")
        emitAdClicked(holder)
      }

      override fun onAdClose() {
        emitLog("info", "fullscreen closed: ${holder.adId}", "ad")
        emitAdClosed(holder)
      }

      override fun onVideoComplete() {
        emitLog("info", "fullscreen video complete: ${holder.adId}", "ad")
        emitAdCompleted(holder)
      }

      override fun onSkippedVideo() {
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
    val width = readInt(requestMap, "width", dpToPx(activity, 320f))
    val height = readInt(requestMap, "height", dpToPx(activity, 150f))
    val adSlot = AdSlot.Builder()
      .setCodeId(placementId)
      .setImageAcceptedSize(width, height)
      .build()

    val adNative = TTAdSdk.getAdManager().createAdNative(activity)
    val holder = BannerAdHolder(adId, placementId)
    adHolders[adId] = holder

    val listener = object : TTAdNative.NativeExpressAdListener {
      override fun onNativeExpressAdLoad(ads: MutableList<TTNativeExpressAd>?) {
        val ad = ads?.firstOrNull()
        if (ad == null) {
          emitAdError(adId, holder.adType, placementId, "empty_ad", "No banner ad returned.")
          return
        }
        holder.ad = ad
        emitLog("info", "banner load success: $adId", "ad")
        emitAdLoaded(holder)
      }

      override fun onError(code: Int, message: String?) {
        emitLog("error", "banner load fail: $adId, code=$code, msg=$message", "ad")
        emitAdError(adId, holder.adType, placementId, code.toString(), message)
      }
    }
    holder.loadListener = listener
    adNative.loadBannerExpressAd(adSlot, listener)
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
        emitAdClicked(holder)
      }

      override fun onAdShow(view: View?, type: Int) {
        emitAdShown(holder)
      }

      override fun onRenderFail(view: View?, msg: String?, code: Int) {
        emitAdError(holder.adId, holder.adType, holder.placementId, code.toString(), msg)
      }

      override fun onRenderSuccess(view: View?, width: Float, height: Float) {
        emitLog("info", "banner render success: ${holder.adId}, width=$width, height=$height", "ad")
        emitAdRendered(holder, width, height)
      }
    })
    ad.setDislikeCallback(activity, object : TTAdDislike.DislikeInteractionCallback {
      override fun onShow() {
        emitLog("info", "banner dislike show: ${holder.adId}", "ad")
      }

      override fun onSelected(position: Int, value: String?, enforce: Boolean) {
        emitLog("info", "banner dislike selected: ${holder.adId}", "ad")
        emitAdClosed(holder, mapOf("dislike" to true, "value" to value))
        holder.container?.removeAllViews()
      }

      override fun onCancel() {
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
    val width = readInt(requestMap, "width", activity.resources.displayMetrics.widthPixels)
    val height = readInt(requestMap, "height", 720)
    val requestedAdCount = readInt(requestMap, "adCount", 1)
    val adCount = requestedAdCount.coerceIn(1, 3)
    if (requestedAdCount != adCount) {
      emitLog("warn", "feed adCount out of range, clamped from $requestedAdCount to $adCount", "ad")
    }
    if (adCount > 1) {
      emitLog("info", "feed requested $adCount ads, current Flutter plugin uses the first returned ad only", "ad")
    }
    val adSlot = AdSlot.Builder()
      .setCodeId(placementId)
      .setImageAcceptedSize(width, height)
      .setAdCount(adCount)
      .build()

    val adNative = TTAdSdk.getAdManager().createAdNative(activity)
    val holder = FeedAdHolder(adId, placementId, adType)
    adHolders[adId] = holder

    val listener = object : TTAdNative.FeedAdListener {
      override fun onError(code: Int, message: String?) {
        emitLog("error", "feed load fail: $adId, code=$code, msg=$message", "ad")
        emitAdError(adId, holder.adType, placementId, code.toString(), message)
      }

      override fun onFeedAdLoad(ads: MutableList<TTFeedAd>?) {
        val ad = ads?.firstOrNull()
        if (ad == null) {
          emitAdError(adId, holder.adType, placementId, "empty_ad", "No feed ad returned.")
          return
        }
        holder.ad = ad
        bindFeedDislikeCallback(activity, holder, ad)
        emitLog("info", "feed load success: $adId", "ad")
        emitAdLoaded(holder)
        if (ad.mediationManager.isExpress) {
          val renderListener = object : MediationExpressRenderListener {
            override fun onRenderSuccess(view: View?, width: Float, height: Float, isExpress: Boolean) {
              holder.renderedView = ad.adView
              emitLog("info", "feed render success: $adId", "ad")
              emitFeedRendered(holder, width, height)
              attachFeedView(holder)
            }

            override fun onRenderFail(view: View?, msg: String?, code: Int) {
              emitLog("error", "feed render fail: $adId, code=$code, msg=$msg", "ad")
              emitAdError(adId, holder.adType, placementId, code.toString(), msg)
            }

            override fun onAdClick() {
              emitAdClicked(holder)
            }

            override fun onAdShow() {
              emitAdShown(holder)
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
    val width = readInt(requestMap, "width", activity.resources.displayMetrics.widthPixels)
    val height = readInt(requestMap, "height", activity.resources.displayMetrics.heightPixels)
    val requestedAdCount = readInt(requestMap, "adCount", 1)
    val adCount = requestedAdCount.coerceIn(1, 3)
    if (requestedAdCount != adCount) {
      emitLog("warn", "draw adCount out of range, clamped from $requestedAdCount to $adCount", "ad")
    }
    if (adCount > 1) {
      emitLog("info", "draw requested $adCount ads, current Flutter plugin uses the first returned ad only", "ad")
    }
    val adSlot = AdSlot.Builder()
      .setCodeId(placementId)
      .setImageAcceptedSize(width, height)
      .setAdCount(adCount)
      .build()

    val adNative = TTAdSdk.getAdManager().createAdNative(activity)
    val holder = DrawAdHolder(adId, placementId, adType)
    adHolders[adId] = holder

    val listener = object : TTAdNative.DrawFeedAdListener {
      override fun onError(code: Int, message: String?) {
        emitLog("error", "draw load fail: $adId, code=$code, msg=$message", "ad")
        emitAdError(adId, holder.adType, placementId, code.toString(), message)
      }

      override fun onDrawFeedAdLoad(ads: MutableList<TTDrawFeedAd>?) {
        val ad = ads?.firstOrNull()
        if (ad == null) {
          emitAdError(adId, holder.adType, placementId, "empty_ad", "No draw ad returned.")
          return
        }
        holder.ad = ad
        bindFeedDislikeCallback(activity, holder, ad)
        emitLog("info", "draw load success: $adId", "ad")
        emitAdLoaded(holder)
        if (ad.mediationManager.isExpress) {
          val renderListener = object : MediationExpressRenderListener {
            override fun onRenderSuccess(view: View?, width: Float, height: Float, isExpress: Boolean) {
              holder.renderedView = ad.adView
              emitLog("info", "draw render success: $adId", "ad")
              emitDrawRendered(holder, width, height)
              attachDrawView(holder)
            }

            override fun onRenderFail(view: View?, msg: String?, code: Int) {
              emitLog("error", "draw render fail: $adId, code=$code, msg=$msg", "ad")
              emitAdError(adId, holder.adType, placementId, code.toString(), msg)
            }

            override fun onAdClick() {
              emitAdClicked(holder)
            }

            override fun onAdShow() {
              emitAdShown(holder)
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
    }
    holder.loadListener = listener
    adNative.loadDrawFeedAd(adSlot, listener)
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
      holder.renderedView ?: buildNativeFeedView(activity, holder, ad).also {
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
      holder.renderedView ?: buildNativeDrawView(activity, holder, ad).also {
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
        emitLog("info", "feed dislike show: ${holder.adId}", "ad")
      }

      override fun onSelected(position: Int, value: String?, enforce: Boolean) {
        emitLog("info", "feed dislike selected: ${holder.adId}", "ad")
        emitAdClosed(holder, mapOf("dislike" to true, "value" to value))
        holder.container?.removeAllViews()
      }

      override fun onCancel() {
        emitLog("info", "feed dislike cancel: ${holder.adId}", "ad")
      }
    })
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
      ad.getDislikeDialog(activity)?.showDislikeDialog()
    }

    ad.setActivityForDownloadApp(activity)
    bindNativeFeedDownloadListener(ctaView, ad)

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

    ad.registerViewForInteraction(
      activity,
      root as ViewGroup,
      clickViews,
      creativeViews,
      emptyList(),
      object : TTNativeAd.AdInteractionListener {
        override fun onAdClicked(view: View, nativeAd: TTNativeAd) {
          emitAdClicked(holder)
        }

        override fun onAdCreativeClick(view: View, nativeAd: TTNativeAd) {
          emitAdClicked(holder)
        }

        override fun onAdShow(nativeAd: TTNativeAd) {
          emitAdShown(holder)
        }
      },
      binder
    )
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
    bindNativeFeedDownloadListener(ctaView, ad)

    val clickViews = mutableListOf<View>(root, mediaView, ctaView, titleView, descView)
    val creativeViews = mutableListOf<View>(mediaView, ctaView)
    ad.registerViewForInteraction(
      mediaView as ViewGroup,
      clickViews,
      creativeViews,
      object : TTNativeAd.AdInteractionListener {
        override fun onAdClicked(view: View, nativeAd: TTNativeAd) {
          emitAdClicked(holder)
        }

        override fun onAdCreativeClick(view: View, nativeAd: TTNativeAd) {
          emitAdClicked(holder)
        }

        override fun onAdShow(nativeAd: TTNativeAd) {
          emitAdShown(holder)
        }
      }
    )
    return root
  }

  /** 原生自渲染下载按钮状态联动 */
  private fun bindNativeFeedDownloadListener(ctaView: TextView, ad: TTNativeAd) {
    ad.setDownloadListener(object : TTAppDownloadListener {
      override fun onIdle() {
        ctaView.post { ctaView.text = ad.buttonText.orEmpty().ifBlank { defaultCallToAction(ad) } }
      }

      override fun onDownloadActive(totalBytes: Long, currBytes: Long, fileName: String?, appName: String?) {
        val progress = if (totalBytes > 0) ((currBytes * 100) / totalBytes).toInt() else 0
        ctaView.post { ctaView.text = "下载中 $progress%" }
      }

      override fun onDownloadPaused(totalBytes: Long, currBytes: Long, fileName: String?, appName: String?) {
        ctaView.post { ctaView.text = "继续下载" }
      }

      override fun onDownloadFailed(totalBytes: Long, currBytes: Long, fileName: String?, appName: String?) {
        ctaView.post { ctaView.text = "重新下载" }
      }

      override fun onDownloadFinished(totalBytes: Long, fileName: String?, appName: String?) {
        ctaView.post { ctaView.text = "立即安装" }
      }

      override fun onInstalled(fileName: String?, appName: String?) {
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
    val ecpm = holder.mediationEcpmInfo()
    val data = if (ecpm == null) null else mapOf("ecpmInfo" to ecpm)
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

  /** 广告模板渲染完成事件（返回真实渲染尺寸） */
  private fun emitAdRendered(holder: GromoreAdHolder, width: Float, height: Float) {
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

  /** 激励到账事件 */
  private fun emitAdRewarded(holder: GromoreAdHolder, data: Map<String, Any?>? = null) {
    postAdEvent(
      mapOf(
        "adId" to holder.adId,
        "adType" to holder.adType,
        "eventType" to "rewarded",
        "placementId" to holder.placementId,
        "data" to data
      )
    )
  }

  /** 广告播放完成事件 */
  private fun emitAdCompleted(holder: GromoreAdHolder, data: Map<String, Any?>? = null) {
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
    errorMessage: String?
  ) {
    postAdEvent(
      mapOf(
        "adId" to adId,
        "adType" to adType,
        "eventType" to "failed",
        "placementId" to placementId,
        "errorCode" to errorCode,
        "errorMessage" to errorMessage
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
    if (info == null) {
      return null
    }
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
      map[key] = bundle.get(key)
    }
    return map
  }

  /** 读取请求参数中的整数值 */
  private fun readInt(source: Map<*, *>, key: String, fallback: Int): Int {
    val extra = source["extra"] as? Map<*, *> ?: emptyMap<Any, Any>()
    val androidOptions = source["androidOptions"] as? Map<*, *> ?: emptyMap<Any, Any>()
    val raw = source[key] ?: androidOptions[key] ?: extra[key]
    return when (raw) {
      is Int -> raw
      is Number -> raw.toInt()
      is String -> raw.toIntOrNull() ?: fallback
      else -> fallback
    }
  }

  /** 发送广告事件（切到主线程） */
  private fun postAdEvent(payload: Map<String, Any?>) {
    mainHandler.post {
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
  }

  /** 开屏广告实例 */
  internal class SplashAdHolder(adId: String, placementId: String) : GromoreAdHolder(adId, placementId) {
    override val adType: String = "splash"
    var ad: CSJSplashAd? = null
    var loadListener: TTAdNative.CSJSplashAdListener? = null
    var showListener: CSJSplashAd.SplashAdListener? = null
  }

  /** 激励视频广告实例 */
  internal class RewardAdHolder(adId: String, placementId: String) : GromoreAdHolder(adId, placementId) {
    override val adType: String = "rewardVideo"
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
