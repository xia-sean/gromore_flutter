package com.gromore.flutter

import android.app.Activity
import android.app.Application
import android.os.Handler
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.mockito.Mockito.*

internal class GromoreRewardPresentationTest {
  private fun <T> mock(type: Class<T>): T = org.mockito.Mockito.mock(
    type, withSettings().mockMaker("mock-maker-subclass")
  )

  @Test
  fun dismissalWaitsForRecordedSdkActivityAndNeverFinishesHostOrBusinessPages() {
    val host = mock(Activity::class.java)
    val sdk = mock(Activity::class.java)
    val business = mock(Activity::class.java)
    val application = mock(Application::class.java)
    val presentation = GromoreRewardPresentation(host, mock(Handler::class.java),
      valid = { true }, application = application, ownsActivity = { it === sdk })
    presentation.onActivityCreated(host, null)
    presentation.onActivityCreated(sdk, null)
    presentation.onActivityCreated(business, null)
    presentation.onActivityResumed(sdk)
    var completions = 0
    presentation.closeActivities { completions++ }
    assertEquals(0, completions, "finish() 调用不代表原生页面已退出")
    verify(sdk).finish()
    verify(host, never()).finish()
    verify(business, never()).finish()
    verify(application, never()).unregisterActivityLifecycleCallbacks(presentation)
    presentation.onActivityDestroyed(sdk)
    assertEquals(1, completions)
    verify(application).unregisterActivityLifecycleCallbacks(presentation)
    presentation.closeActivities { completions++ }
    assertEquals(2, completions, "重复清理仍要完成调用方回调")
  }

  @Test
  fun unidentifiedAdSourceReleasesObserverWithoutClosingHost() {
    val host = mock(Activity::class.java)
    val application = mock(Application::class.java)
    val presentation = GromoreRewardPresentation(host, mock(Handler::class.java),
      valid = { true }, application = application)
    var finished = false
    presentation.closeActivities { finished = true }
    assertTrue(finished)
    verify(host, never()).finish()
    verify(application).unregisterActivityLifecycleCallbacks(presentation)
  }

  @Test
  fun onlyKnownSdkActivityNamespacesAreEligible() {
    assertTrue(GromoreRewardPresentation.isAdActivity("com.bytedance.sdk.openadsdk.activity.TTRewardVideoActivity"))
    assertTrue(GromoreRewardPresentation.isAdActivity("com.qq.e.ads.PortraitADActivity"))
    assertFalse(GromoreRewardPresentation.isAdActivity("com.yaoguai.pdf.MainActivity"))
    assertFalse(GromoreRewardPresentation.isAdActivity("com.bytedance.example.BusinessActivity"))
    assertFalse(GromoreRewardPresentation.isAdActivity("com.android.chrome.Main"))
  }
}
