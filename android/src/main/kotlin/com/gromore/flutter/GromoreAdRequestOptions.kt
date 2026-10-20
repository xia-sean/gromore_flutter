package com.gromore.flutter

import com.bytedance.sdk.openadsdk.AdSlot
import com.bytedance.sdk.openadsdk.TTAdConstant
import com.bytedance.sdk.openadsdk.mediation.MediationConstant
import com.bytedance.sdk.openadsdk.mediation.ad.MediationAdSlot

internal class GromoreAdRequestOptions(private val source: Map<*, *>) {
  private fun value(key: String): Any? {
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

  fun mediationSlot(reward: Boolean = false): MediationAdSlot {
    val builder = MediationAdSlot.Builder()
    bool("muted")?.let { builder.setMuted(it) }
    string("scenarioId")?.let { builder.setScenarioId(it) }
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
