package com.gromore.flutter

import android.content.Context
import android.view.View
import android.widget.FrameLayout
import io.flutter.plugin.platform.PlatformView

/**
 * GroMore 广告 PlatformView 实现
 */
internal class GromoreAdPlatformView(
  context: Context,
  private val adId: String,
  private val adType: String?,
  private val width: Int,
  private val height: Int,
  private val adManager: GromoreAdManager
) : PlatformView {

  /** 容器视图 */
  private val container: FrameLayout = FrameLayout(context)

  init {
    if (width > 0 && height > 0) {
      container.layoutParams = FrameLayout.LayoutParams(width, height)
    }
    adManager.attachAdView(adId, adType, container, width, height)
  }

  /**
   * 获取 PlatformView 对应的 View
   */
  override fun getView(): View = container

  /**
   * 释放资源
   */
  override fun dispose() {
    adManager.detachAdView(adId)
  }
}
