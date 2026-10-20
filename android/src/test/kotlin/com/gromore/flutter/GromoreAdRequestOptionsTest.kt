package com.gromore.flutter

import com.bytedance.sdk.openadsdk.TTAdConstant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class GromoreAdRequestOptionsTest {
  @Test
  fun rewardParametersAreReadFromEverySupportedContainer() {
    val parameters = mapOf(
      "userId" to "test_user",
      "rewardName" to "金币",
      "rewardAmount" to 1,
      "customData" to "{\"orderId\":\"order-123\"}",
      "muted" to true,
      "scenarioId" to "reward_scene",
      "orientation" to TTAdConstant.HORIZONTAL
    )
    val requests = listOf(parameters, mapOf("extra" to parameters), mapOf("androidExtra" to parameters))
    for (request in requests) {
      val options = GromoreAdRequestOptions(request)
      assertEquals("test_user", options.string("userId"))
      assertEquals("金币", options.string("rewardName"))
      assertEquals(1, options.int("rewardAmount", 0))
      assertEquals(TTAdConstant.HORIZONTAL, options.int("orientation", TTAdConstant.VERTICAL))
      assertEquals("reward_scene", options.string("scenarioId"))
      assertTrue(options.bool("muted")!!)
      assertEquals(parameters["customData"], options.string("customData"))
    }
  }

  @Test
  fun topLevelThenPlatformExtraThenExtraTakePrecedence() {
    val options = GromoreAdRequestOptions(mapOf(
      "userId" to "top-level-user",
      "androidExtra" to mapOf("userId" to "platform-user", "muted" to false),
      "extra" to mapOf("userId" to "extra-user", "muted" to true, "scenarioId" to "extra-scene")
    ))
    assertEquals("top-level-user", options.string("userId"))
    assertFalse(options.bool("muted")!!)
    assertEquals("extra-scene", options.string("scenarioId"))
  }

  @Test
  fun ordinaryAdsReadMediationOptions() {
    val options = GromoreAdRequestOptions(mapOf("extra" to mapOf(
      "muted" to "false", "scenarioId" to "feed-scene", "customData" to "reward-only"
    )))
    assertFalse(options.bool("muted")!!)
    assertEquals("feed-scene", options.string("scenarioId"))
  }

  @Test
  fun nullValuesFallBackAndNumbersAndBooleansAreParsed() {
    val options = GromoreAdRequestOptions(mapOf(
      "userId" to null,
      "androidExtra" to mapOf("userId" to null),
      "extra" to mapOf("userId" to "extra-user", "rewardAmount" to "3", "muted" to 0)
    ))
    assertEquals("extra-user", options.string("userId"))
    assertEquals(3, options.int("rewardAmount", 0))
    assertEquals(TTAdConstant.VERTICAL, options.int("orientation", TTAdConstant.VERTICAL))
    assertFalse(options.bool("muted")!!)
    assertEquals(3000, options.int("missing", 3000))
  }

  @Test
  fun arbitraryExtraMapIsNotTreatedAsCustomData() {
    val options = GromoreAdRequestOptions(mapOf("extra" to mapOf(
      "userId" to "test_user", "orderId" to "private-order", "width" to 320
    )))
    assertNull(options.string("customData"))
  }

  @Test
  fun legacyAndOtherPlatformContainersAreNotRead() {
    val options = GromoreAdRequestOptions(mapOf(
      "androidOptions" to mapOf("userId" to "legacy-user"),
      "iosOptions" to mapOf("userId" to "legacy-ios-user"),
      "iosExtra" to mapOf("userId" to "ios-user")
    ))
    assertNull(options.string("userId"))
  }
}
