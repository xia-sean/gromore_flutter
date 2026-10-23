package com.gromore.flutter

import android.content.Context
import android.os.Handler
import android.widget.FrameLayout
import com.bytedance.sdk.openadsdk.TTDrawFeedAd
import com.bytedance.sdk.openadsdk.TTFeedAd
import com.bytedance.sdk.openadsdk.mediation.manager.MediationNativeManager
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.mockito.Mockito.*

internal class GromoreVideoLifecycleTest {
  // 这些依赖均无需 final 方法代理，避免旧版 inline 引擎重写宿主 JDK 类。
  private fun <T> mock(type: Class<T>): T = org.mockito.Mockito.mock(
    type, withSettings().mockMaker("mock-maker-subclass")
  )

  @Test
  fun manualPauseSurvivesMountAndRemountForFeedAndDraw() {
    for (draw in listOf(false, true)) {
      val sdk = mock(MediationNativeManager::class.java)
      `when`(sdk.isExpress).thenReturn(true)
      val holder = holder(draw, sdk)
      val manager = manager(holder)
      manager.operation("controlVideo", mapOf("adId" to "ad", "action" to "pause"))
      clearInvocations(sdk)
      val container = mock(FrameLayout::class.java)
      manager.attachAdView("ad", holder.adType, container, 320, 100)
      manager.detachAdView("ad")
      manager.attachAdView("ad", holder.adType, container, 320, 100)
      assertTrue(holder.videoPaused)
      verify(sdk, never()).onResume()
      verify(sdk, atLeastOnce()).onPause()
    }
  }

  @Test
  fun detachedResumeWaitsForRemountAndTemporaryPausePreservesPlayIntent() {
    for (draw in listOf(false, true)) {
      val sdk = mock(MediationNativeManager::class.java)
      `when`(sdk.isExpress).thenReturn(true)
      val holder = holder(draw, sdk)
      val manager = manager(holder)
      manager.operation("controlVideo", mapOf("adId" to "ad", "action" to "resume"))
      verify(sdk, never()).onResume()
      val container = mock(FrameLayout::class.java)
      manager.attachAdView("ad", holder.adType, container, 320, 100)
      verify(sdk).onResume()
      manager.detachAdView("ad")
      assertFalse(holder.videoPaused)
      clearInvocations(sdk)
      manager.attachAdView("ad", holder.adType, container, 320, 100)
      verify(sdk).onResume()
    }
  }

  private fun manager(holder: GromoreAdManager.GromoreAdHolder) = GromoreAdManager(
    appContext = mock(Context::class.java), activityProvider = { null },
    emitAdEvent = {}, emitLog = { _, _, _ -> }, mainHandler = mock(Handler::class.java),
    adHolders = mutableMapOf("ad" to holder)
  )

  private fun holder(draw: Boolean, sdk: MediationNativeManager): GromoreAdManager.GromoreAdHolder {
    if (draw) {
      val ad = mock(TTDrawFeedAd::class.java)
      `when`(ad.mediationManager).thenReturn(sdk)
      return GromoreAdManager.DrawAdHolder("ad", "placement").apply { this.ad = ad }
    }
    val ad = mock(TTFeedAd::class.java)
    `when`(ad.mediationManager).thenReturn(sdk)
    return GromoreAdManager.FeedAdHolder("ad", "placement").apply { this.ad = ad }
  }
}
