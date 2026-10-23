package com.gromore.flutter

import android.app.Activity
import android.view.View
import com.bytedance.sdk.openadsdk.TTFeedAd
import com.bytedance.sdk.openadsdk.mediation.ad.IMediationNativeAdInfo

/** 宿主须在主线程注册/注销，并按 SDK 约定注册素材点击和媒体容器。 */
object GromoreNativeRenderRegistry {
  /** 自渲染 Feed/Draw 工厂；模板广告仍由 SDK 渲染。 */
  interface Factory {
    /**
     * 在主线程返回广告 View，adType 为 native 或 draw_native。
     * 宿主须使用 SDK 媒体容器，并按 SDK 协议注册素材点击及广告标识。
     */
    fun create(activity: Activity, ad: TTFeedAd, adType: String): View
  }
  /** 聚合原生广告转 Banner 的布局工厂。 */
  interface BannerFactory {
    /** 返回 Banner View；素材点击及媒体容器由宿主按 SDK 协议注册。 */
    fun create(activity: Activity, ad: IMediationNativeAdInfo): View
  }
  private val factories = mutableMapOf<String, Factory>()
  private val bannerFactories = mutableMapOf<String, BannerFactory>()
  /** 主线程注册 Feed/Draw 工厂，同 ID 会替换原工厂；在广告加载前调用。 */
  @JvmStatic fun register(id: String, factory: Factory) { factories[id] = factory }
  /** 主线程注册 Banner 工厂；请求使用 options.nativeRenderFactoryId 选择。 */
  @JvmStatic fun registerBanner(id: String, factory: BannerFactory) { bannerFactories[id] = factory }
  /** 主线程移除该 ID 的两类工厂；不会销毁已经创建的广告 View 或实例。 */
  @JvmStatic fun unregister(id: String) { factories.remove(id); bannerFactories.remove(id) }
  internal fun factory(id: String) = factories[id]
  internal fun bannerFactory(id: String) = bannerFactories[id]
}
