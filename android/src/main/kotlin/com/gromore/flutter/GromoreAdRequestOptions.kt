package com.gromore.flutter

import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.TTAdConstant
import com.bytedance.sdk.openadsdk.mediation.MediationConstant
import com.bytedance.sdk.openadsdk.mediation.ad.MediationAdSlot
import kotlin.math.roundToInt

internal class GromoreAdRequestOptions(private val source: Map<*, *>) {
  fun value(key: String): Any? {
    val androidExtra = source["androidExtra"] as? Map<*, *>
    val extra = source["extra"] as? Map<*, *>
    return source[key] ?: androidExtra?.get(key) ?: extra?.get(key)
  }

  fun string(key: String): String? = value(key) as? String

  fun int(key: String, fallback: Int): Int {
    return when (val raw = value(key)) {
      is Number -> raw.toInt()
      is String -> raw.toIntOrNull() ?: fallback
      else -> fallback
    }
  }

  /** Config 尺寸按逻辑像素转换；未传尺寸的 fallback 已是 px，不再缩放。
   * 未带单位标记的旧请求仍按原生 px 读取。
   */
  fun dimensionPx(key: String, density: Float, fallback: Int): Int {
    val raw = when (val input = value(key)) {
      is Number -> input.toDouble()
      is String -> input.toDoubleOrNull()
      else -> null
    } ?: return fallback
    if (!raw.isFinite()) return fallback
    return if (string("sizeUnit") == "logicalPixels") {
      (raw * density).roundToInt()
    } else {
      raw.toInt()
    }
  }

  fun bool(key: String): Boolean? {
    return when (val raw = value(key)) {
      is Boolean -> raw
      is Number -> raw.toInt() != 0
      is String -> when (raw.trim().lowercase()) {
        "true", "1" -> true
        "false", "0" -> false
        else -> null
      }
      else -> null
    }
  }

  fun mediationSlot(reward: Boolean = false, bannerListener: com.bytedance.sdk.openadsdk.mediation.ad.MediationNativeToBannerListener? = null): MediationAdSlot {
    val builder = MediationAdSlot.Builder()
    bannerListener?.let { builder.setMediationNativeToBannerListener(it) }
    bool("muted")?.let { builder.setMuted(it) }
    string("scenarioId")?.let { builder.setScenarioId(it) }
    (value("volume") as? Number)?.let { builder.setVolume(it.toFloat().coerceIn(0f, 1f)) }
    bool("useSurfaceView")?.let { builder.setUseSurfaceView(it) }
    bool("bidNotify")?.let { builder.setBidNotify(it) }
    bool("splashShakeButton")?.let { builder.setSplashShakeButton(it) }
    bool("splashPreLoad")?.let { builder.setSplashPreLoad(it) }
    bool("allowShowCloseBtn")?.let { builder.setAllowShowCloseBtn(it) }
    string("wxAppId")?.let { builder.setWxAppId(it) }
    (value("extraObjects") as? Map<*, *>)?.forEach { (key, value) ->
      if (key is String && value != null) builder.setExtraObject(key, value)
    }
    (value("rewardVerification") as? Map<*, *>)?.forEach { (key, value) ->
      val adnKey = when(key) {
        "pangle" -> MediationConstant.ADN_PANGLE
        "gdt" -> MediationConstant.ADN_GDT
        "baidu" -> MediationConstant.ADN_BAIDU
        else -> throw IllegalArgumentException("Unsupported reward ADN: $key")
      }
      if (value != null) builder.setExtraObject(adnKey, value)
    }
    if (reward) {
      string("rewardName")?.let { builder.setRewardName(it) }
      if (value("rewardAmount") != null) {
        builder.setRewardAmount(int("rewardAmount", 0))
      }
      string("customData")?.let {
        builder.setExtraObject(MediationConstant.KEY_GROMORE_EXTRA, it)
      }
    }
    return builder.build()
  }

  fun rewardSlot(placementId: String): AdSlot {
    val builder = AdSlot.Builder()
      .setCodeId(placementId)
      .setOrientation(int("orientation", TTAdConstant.VERTICAL))
      .setMediationAdSlot(mediationSlot(reward = true))
    string("userId")?.let { builder.setUserID(it) }
    string("rewardName")?.let { builder.setRewardName(it) }
    if (value("rewardAmount") != null) {
      builder.setRewardAmount(int("rewardAmount", 0))
    }
    return builder.build()
  }
}
