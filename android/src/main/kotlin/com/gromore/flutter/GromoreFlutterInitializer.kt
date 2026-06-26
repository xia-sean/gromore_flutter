package com.gromore.flutter

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import com.bytedance.sdk.openadsdk.LocationProvider
import com.bytedance.sdk.openadsdk.TTAdConfig
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.sdk.openadsdk.TTCustomController
import com.bytedance.sdk.openadsdk.mediation.init.MediationConfig
import com.bytedance.sdk.openadsdk.mediation.init.MediationConfigUserInfoForSegment
import com.bytedance.sdk.openadsdk.mediation.init.MediationPrivacyConfig
import org.json.JSONObject

internal data class GromoreFlutterResolvedInitConfig(
  val appId: String,
  val appName: String,
  val debug: Boolean,
  val useMediation: Boolean,
  val androidOptions: Map<String, Any?>,
  val source: String
)

private data class GromoreFlutterManifestConfig(
  val appId: String,
  val appName: String?,
  val autoInit: Boolean,
  val debug: Boolean,
  val useMediation: Boolean,
  val supportMultiProcess: Boolean?
)

internal object GromoreFlutterInitializer {
  const val META_APP_ID = "com.gromore.flutter.APP_ID"
  const val META_APP_NAME = "com.gromore.flutter.APP_NAME"
  const val META_AUTO_INIT = "com.gromore.flutter.AUTO_INIT"
  const val META_DEBUG = "com.gromore.flutter.DEBUG"
  const val META_USE_MEDIATION = "com.gromore.flutter.USE_MEDIATION"
  const val META_SUPPORT_MULTI_PROCESS = "com.gromore.flutter.SUPPORT_MULTI_PROCESS"

  private val initLock = Any()

  @Volatile
  private var initInProgress = false

  @Volatile
  private var lastInitSource: String? = null

  @Volatile
  private var lastErrorCode: String? = null

  @Volatile
  private var lastErrorMessage: String? = null

  fun resolveConfig(
    context: Context,
    args: Map<*, *> = emptyMap<Any, Any>()
  ): GromoreFlutterResolvedInitConfig? {
    val manifestConfig = readManifestConfig(context)
    val explicitAppId = readString(args, "androidAppId")?.takeUnless { it.isBlank() }
    val explicitAppName = readString(args, "androidAppName")?.takeUnless { it.isBlank() }
    val explicitDebug = readBoolean(args, "debug")
    val explicitUseMediation = readBoolean(args, "useMediation")
    val explicitOptions = args["androidOptions"] as? Map<*, *> ?: emptyMap<Any, Any>()

    val appId = explicitAppId ?: manifestConfig?.appId
    val appName = (explicitAppName ?: manifestConfig?.appName ?: resolveDefaultAppName(context))
      ?.takeUnless { it.isBlank() }
    if (appId.isNullOrBlank()) {
      return null
    }

    val androidOptions = mutableMapOf<String, Any?>()
    manifestConfig?.supportMultiProcess?.let {
      androidOptions["supportMultiProcess"] = it
    }
    explicitOptions.forEach { (key, value) ->
      if (key != null) {
        androidOptions[key.toString()] = value
      }
    }

    val hasExplicitConfig = explicitAppId != null ||
      explicitAppName != null ||
      explicitDebug != null ||
      explicitUseMediation != null ||
      explicitOptions.isNotEmpty()

    val source = when {
      hasExplicitConfig && manifestConfig != null -> "explicit+manifest"
      hasExplicitConfig -> "explicit"
      else -> "manifest"
    }

    return GromoreFlutterResolvedInitConfig(
      appId = appId,
      appName = appName ?: appId,
      debug = explicitDebug ?: manifestConfig?.debug ?: false,
      useMediation = explicitUseMediation ?: manifestConfig?.useMediation ?: true,
      androidOptions = androidOptions,
      source = source
    )
  }

  fun getInitializationStatus(context: Context): Map<String, Any?> {
    val manifestConfig = readManifestConfig(context)
    return mapOf(
      "isInitSuccess" to TTAdSdk.isInitSuccess(),
      "isSdkReady" to TTAdSdk.isSdkReady(),
      "initInProgress" to initInProgress,
      "hasManifestConfig" to (manifestConfig != null),
      "autoInitEnabled" to (manifestConfig?.autoInit == true),
      "lastInitSource" to lastInitSource,
      "lastErrorCode" to lastErrorCode,
      "lastErrorMessage" to lastErrorMessage
    )
  }

  fun autoInitializeIfNeeded(
    context: Context,
    emitLog: (String, String, String) -> Unit
  ) {
    val manifestConfig = readManifestConfig(context) ?: return
    if (!manifestConfig.autoInit) {
      return
    }
    initialize(
      context = context,
      config = manifestConfig.toResolvedConfig(context),
      emitLog = emitLog,
      onComplete = null
    )
  }

  fun initialize(
    context: Context,
    config: GromoreFlutterResolvedInitConfig,
    emitLog: (String, String, String) -> Unit,
    onComplete: ((Map<String, Any?>) -> Unit)?
  ) {
    if (TTAdSdk.isInitSuccess()) {
      lastInitSource = config.source
      emitLog("info", "init result success=true reason=already_initialized", "init")
      onComplete?.invoke(successResult())
      return
    }

    synchronized(initLock) {
      if (TTAdSdk.isInitSuccess()) {
        lastInitSource = config.source
        emitLog("info", "init result success=true reason=already_initialized", "init")
        onComplete?.invoke(successResult())
        return
      }
      if (initInProgress) {
        emitLog("warn", "init result success=false reason=init_in_progress", "init")
        onComplete?.invoke(
          failureResult(
            errorCode = "init_in_progress",
            errorMessage = "Init is already in progress."
          )
        )
        return
      }
      initInProgress = true
      lastInitSource = config.source
      lastErrorCode = null
      lastErrorMessage = null
    }

    val initSuccess = TTAdSdk.init(context.applicationContext, buildAdConfig(config))
    if (!initSuccess) {
      completeFailure(
        emitLog = emitLog,
        onComplete = onComplete,
        errorCode = "init_failed",
        errorMessage = "TTAdSdk.init returned false."
      )
      return
    }

    TTAdSdk.start(object : TTAdSdk.Callback {
      override fun success() {
        completeSuccess(emitLog, onComplete)
      }

      override fun fail(code: Int, msg: String?) {
        completeFailure(
          emitLog = emitLog,
          onComplete = onComplete,
          errorCode = code.toString(),
          errorMessage = msg ?: "TTAdSdk.start failed."
        )
      }
    })
  }

  private fun completeSuccess(
    emitLog: (String, String, String) -> Unit,
    onComplete: ((Map<String, Any?>) -> Unit)?
  ) {
    initInProgress = false
    lastErrorCode = null
    lastErrorMessage = null
    emitLog("info", "init result success=true reason=started", "init")
    onComplete?.invoke(successResult())
  }

  private fun completeFailure(
    emitLog: (String, String, String) -> Unit,
    onComplete: ((Map<String, Any?>) -> Unit)?,
    errorCode: String,
    errorMessage: String
  ) {
    initInProgress = false
    lastErrorCode = errorCode
    lastErrorMessage = errorMessage
    emitLog("error", "init result success=false reason=$errorCode:$errorMessage", "init")
    onComplete?.invoke(
      failureResult(
        errorCode = errorCode,
        errorMessage = errorMessage
      )
    )
  }

  private fun buildAdConfig(config: GromoreFlutterResolvedInitConfig): TTAdConfig {
    val builder = TTAdConfig.Builder()
      .appId(config.appId)
      .appName(config.appName)
      .debug(config.debug)
      .useMediation(config.useMediation)
      .customController(buildPrivacyCustomController(config.androidOptions))

    readBoolean(config.androidOptions, "supportMultiProcess")?.let { builder.supportMultiProcess(it) }
    readBoolean(config.androidOptions, "paid")?.let { builder.paid(it) }
    readString(config.androidOptions, "keywords")?.let { builder.keywords(it) }
    readString(config.androidOptions, "data")?.let { builder.data(it) }
    readInt(config.androidOptions, "titleBarTheme")?.let { builder.titleBarTheme(it) }
    readBoolean(config.androidOptions, "allowShowNotify")?.let { builder.allowShowNotify(it) }
    readInt(config.androidOptions, "themeStatus")?.let { builder.themeStatus(it) }
    readInt(config.androidOptions, "ageGroup")?.let { builder.setAgeGroup(it) }
    readIntList(config.androidOptions, "directDownloadNetworkType")
      ?.takeIf { it.isNotEmpty() }
      ?.let { values ->
        builder.directDownloadNetworkType(*values.toIntArray())
      }
    buildMediationConfig(config.androidOptions)?.let { builder.setMediationConfig(it) }
    (config.androidOptions["initExtra"] as? Map<*, *>)?.forEach { (key, value) ->
      if (key != null && value != null) {
        builder.addExtra(key.toString(), value)
      }
    }
    return builder.build()
  }

  private fun readManifestConfig(context: Context): GromoreFlutterManifestConfig? {
    val metaData = readMetaData(context) ?: return null
    val appId = resolveMetaString(context, metaData, META_APP_ID)?.takeUnless { it.isBlank() } ?: return null
    val appName = resolveMetaString(context, metaData, META_APP_NAME)?.takeUnless { it.isBlank() }
    return GromoreFlutterManifestConfig(
      appId = appId,
      appName = appName,
      autoInit = resolveMetaBoolean(context, metaData, META_AUTO_INIT) ?: false,
      debug = resolveMetaBoolean(context, metaData, META_DEBUG) ?: false,
      useMediation = resolveMetaBoolean(context, metaData, META_USE_MEDIATION) ?: true,
      supportMultiProcess = resolveMetaBoolean(context, metaData, META_SUPPORT_MULTI_PROCESS)
    )
  }

  private fun readMetaData(context: Context): Bundle? {
    return try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        context.packageManager.getApplicationInfo(
          context.packageName,
          PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong())
        ).metaData
      } else {
        @Suppress("DEPRECATION")
        context.packageManager.getApplicationInfo(
          context.packageName,
          PackageManager.GET_META_DATA
        ).metaData
      }
    } catch (_: Exception) {
      null
    }
  }

  private fun resolveMetaString(context: Context, metaData: Bundle, key: String): String? {
    return when (val value = metaData.get(key)) {
      is String -> value
      is Int -> resolveStringResource(context, value) ?: value.toString()
      else -> null
    }
  }

  private fun resolveMetaBoolean(context: Context, metaData: Bundle, key: String): Boolean? {
    return when (val value = metaData.get(key)) {
      is Boolean -> value
      is Int -> resolveBooleanResource(context, value) ?: (value != 0)
      is String -> parseBoolean(value)
      else -> null
    }
  }

  private fun resolveStringResource(context: Context, resId: Int): String? {
    return runCatching {
      when (context.resources.getResourceTypeName(resId)) {
        "string" -> context.getString(resId)
        else -> null
      }
    }.getOrNull()
  }

  private fun resolveBooleanResource(context: Context, resId: Int): Boolean? {
    return runCatching {
      when (context.resources.getResourceTypeName(resId)) {
        "bool" -> context.resources.getBoolean(resId)
        "integer" -> context.resources.getInteger(resId) != 0
        else -> null
      }
    }.getOrNull()
  }

  private fun GromoreFlutterManifestConfig.toResolvedConfig(context: Context): GromoreFlutterResolvedInitConfig {
    val androidOptions = mutableMapOf<String, Any?>()
    supportMultiProcess?.let {
      androidOptions["supportMultiProcess"] = it
    }
    return GromoreFlutterResolvedInitConfig(
      appId = appId,
      appName = appName ?: resolveDefaultAppName(context) ?: appId,
      debug = debug,
      useMediation = useMediation,
      androidOptions = androidOptions,
      source = "manifest"
    )
  }

  private fun resolveDefaultAppName(context: Context): String? {
    return runCatching {
      val pm = context.packageManager
      val appInfo = context.applicationInfo
      val label = pm.getApplicationLabel(appInfo)?.toString()?.trim()
      label?.takeUnless { it.isEmpty() } ?: context.packageName
    }.getOrElse {
      context.packageName
    }
  }

  private fun successResult(): Map<String, Any?> {
    return mapOf("success" to true)
  }

  private fun failureResult(
    errorCode: String,
    errorMessage: String
  ): Map<String, Any?> {
    return mapOf(
      "success" to false,
      "errorCode" to errorCode,
      "errorMessage" to errorMessage
    )
  }

  private fun buildPrivacyCustomController(androidOptions: Map<*, *>): TTCustomController {
    val privacy = androidOptions["privacy"] as? Map<*, *> ?: emptyMap<Any, Any>()
    return object : TTCustomController() {
      override fun isCanUseLocation(): Boolean {
        return readBoolean(privacy, "canUseLocation") ?: super.isCanUseLocation()
      }

      override fun getTTLocation(): LocationProvider? {
        val latitude = readDouble(privacy, "latitude")
        val longitude = readDouble(privacy, "longitude")
        if (latitude == null || longitude == null) {
          return super.getTTLocation()
        }
        return object : LocationProvider {
          override fun getLatitude(): Double = latitude
          override fun getLongitude(): Double = longitude
        }
      }

      override fun alist(): Boolean {
        return readBoolean(privacy, "alist") ?: super.alist()
      }

      override fun isCanUsePhoneState(): Boolean {
        return readBoolean(privacy, "canUsePhoneState") ?: super.isCanUsePhoneState()
      }

      override fun getDevImei(): String? {
        return readString(privacy, "imei") ?: super.getDevImei()
      }

      override fun isCanUseWifiState(): Boolean {
        return readBoolean(privacy, "canUseWifiState") ?: super.isCanUseWifiState()
      }

      override fun getMacAddress(): String? {
        return readString(privacy, "macAddress") ?: super.getMacAddress()
      }

      override fun isCanUseWriteExternal(): Boolean {
        return readBoolean(privacy, "canUseWriteExternal") ?: super.isCanUseWriteExternal()
      }

      override fun getDevOaid(): String? {
        return readString(privacy, "oaid") ?: super.getDevOaid()
      }

      override fun isCanUseAndroidId(): Boolean {
        return readBoolean(privacy, "canUseAndroidId") ?: super.isCanUseAndroidId()
      }

      override fun getAndroidId(): String? {
        return readString(privacy, "androidId") ?: super.getAndroidId()
      }

      override fun isCanUsePermissionRecordAudio(): Boolean {
        return readBoolean(privacy, "canUseRecordAudio") ?: super.isCanUsePermissionRecordAudio()
      }

      override fun isCanUseMessage(): Boolean {
        return readBoolean(privacy, "canUseMessage") ?: super.isCanUseMessage()
      }

      override fun getMediationPrivacyConfig(): MediationPrivacyConfig {
        return object : MediationPrivacyConfig() {
          override fun getCustomAppList(): MutableList<String> {
            return (readStringList(privacy, "customAppList")
              ?: super.getCustomAppList()
              ?: emptyList()).toMutableList()
          }

          override fun getCustomDevImeis(): MutableList<String> {
            return (readStringList(privacy, "customDevImeis")
              ?: super.getCustomDevImeis()
              ?: emptyList()).toMutableList()
          }

          override fun isCanUseOaid(): Boolean {
            return readBoolean(privacy, "canUseOaid") ?: super.isCanUseOaid()
          }

          override fun isLimitPersonalAds(): Boolean {
            return readBoolean(privacy, "limitPersonalAds") ?: super.isLimitPersonalAds()
          }

          override fun isProgrammaticRecommend(): Boolean {
            return readBoolean(privacy, "programmaticRecommend") ?: super.isProgrammaticRecommend()
          }
        }
      }

      override fun userPrivacyConfig(): MutableMap<String, Any> {
        val map = HashMap<String, Any>()
        map["mcod"] = readString(privacy, "mcod") ?: "0"
        return map
      }
    }
  }

  private fun buildMediationConfig(androidOptions: Map<*, *>): MediationConfig? {
    val mediationOptions = androidOptions["mediationConfig"] as? Map<*, *> ?: return null
    val builder = MediationConfig.Builder()
    readString(mediationOptions, "publisherDid")?.let { builder.setPublisherDid(it) }
    readBoolean(mediationOptions, "openAdnTest")?.let { builder.setOpenAdnTest(it) }
    readBoolean(mediationOptions, "https")?.let { builder.setHttps(it) }
    readBoolean(mediationOptions, "wxInstalled")?.let { builder.setWxInstalled(it) }
    readString(mediationOptions, "opensdkVer")?.let { builder.setOpensdkVer(it) }
    readBoolean(mediationOptions, "supportH265")?.let { builder.setSupportH265(it) }
    readBoolean(mediationOptions, "supportSplashZoomout")?.let { builder.setSupportSplashZoomout(it) }
    readString(mediationOptions, "wxAppId")?.let { builder.setWxAppId(it) }
    (mediationOptions["localExtra"] as? Map<*, *>)?.let { raw ->
      val map = mutableMapOf<String, Any>()
      raw.forEach { (key, value) ->
        if (key != null && value != null) {
          map[key.toString()] = value
        }
      }
      if (map.isNotEmpty()) {
        builder.setLocalExtra(map)
      }
    }
    (mediationOptions["customLocalConfig"] as? Map<*, *>)?.let { raw ->
      val json = JSONObject()
      raw.forEach { (key, value) ->
        if (key != null && value != null) {
          json.put(key.toString(), value)
        }
      }
      builder.setCustomLocalConfig(json)
    }
    buildMediationSegmentInfo(mediationOptions["userInfoForSegment"] as? Map<*, *>)?.let {
      builder.setMediationConfigUserInfoForSegment(it)
    }
    return builder.build()
  }

  private fun buildMediationSegmentInfo(raw: Map<*, *>?): MediationConfigUserInfoForSegment? {
    if (raw == null) {
      return null
    }
    val info = MediationConfigUserInfoForSegment()
    var hasValue = false
    readString(raw, "userId")?.let {
      info.setUserId(it)
      hasValue = true
    }
    readString(raw, "channel")?.let {
      info.setChannel(it)
      hasValue = true
    }
    readString(raw, "subChannel")?.let {
      info.setSubChannel(it)
      hasValue = true
    }
    readInt(raw, "age")?.let {
      info.setAge(it)
      hasValue = true
    }
    readString(raw, "gender")?.let {
      info.setGender(it)
      hasValue = true
    }
    readString(raw, "userValueGroup")?.let {
      info.setUserValueGroup(it)
      hasValue = true
    }
    (raw["customInfos"] as? Map<*, *>)?.let { custom ->
      val map = mutableMapOf<String, String>()
      custom.forEach { (key, value) ->
        if (key != null && value != null) {
          map[key.toString()] = value.toString()
        }
      }
      if (map.isNotEmpty()) {
        info.setCustomInfos(map)
        hasValue = true
      }
    }
    return if (hasValue) info else null
  }

  private fun readString(source: Map<*, *>, key: String): String? {
    return source[key]?.toString()
  }

  private fun readBoolean(source: Map<*, *>, key: String): Boolean? {
    return parseBoolean(source[key])
  }

  private fun parseBoolean(value: Any?): Boolean? {
    return when (value) {
      is Boolean -> value
      is Number -> value.toInt() != 0
      is String -> when (value.trim().lowercase()) {
        "true", "1", "yes" -> true
        "false", "0", "no" -> false
        else -> null
      }
      else -> null
    }
  }

  private fun readInt(source: Map<*, *>, key: String): Int? {
    return when (val value = source[key]) {
      is Int -> value
      is Number -> value.toInt()
      is String -> value.toIntOrNull()
      else -> null
    }
  }

  private fun readDouble(source: Map<*, *>, key: String): Double? {
    return when (val value = source[key]) {
      is Double -> value
      is Number -> value.toDouble()
      is String -> value.toDoubleOrNull()
      else -> null
    }
  }

  private fun readIntList(source: Map<*, *>, key: String): List<Int>? {
    val raw = source[key] as? List<*> ?: return null
    return raw.mapNotNull {
      when (it) {
        is Int -> it
        is Number -> it.toInt()
        is String -> it.toIntOrNull()
        else -> null
      }
    }
  }

  private fun readStringList(source: Map<*, *>, key: String): List<String>? {
    val raw = source[key] as? List<*> ?: return null
    return raw.mapNotNull { it?.toString() }
  }
}
