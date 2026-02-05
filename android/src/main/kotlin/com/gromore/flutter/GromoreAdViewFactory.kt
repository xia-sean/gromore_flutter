package com.gromore.flutter

import android.content.Context
import io.flutter.plugin.common.MessageCodec
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * GroMore 广告 PlatformView 工厂
 */
internal class GromoreAdViewFactory(
  private val adManager: GromoreAdManager,
  codec: MessageCodec<Any?> = StandardMessageCodec.INSTANCE
) : PlatformViewFactory(codec) {

  /**
   * 创建 PlatformView
   *
   * @param context 上下文
   * @param viewId 视图 ID
   * @param args 创建参数
   */
  override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    val params = args as? Map<*, *> ?: emptyMap<Any, Any>()
    val adId = params["adId"]?.toString() ?: ""
    val adType = params["adType"]?.toString()
    val width = (params["width"] as? Number)?.toInt() ?: 0
    val height = (params["height"] as? Number)?.toInt() ?: 0
    return GromoreAdPlatformView(
      context = context,
      adId = adId,
      adType = adType,
      width = width,
      height = height,
      adManager = adManager
    )
  }
}
