package com.gromore.flutter

import android.content.Context
import android.os.Handler
import android.os.Looper

/**
 * 提供给宿主原生工程直接调用的 Android 初始化入口。
 *
 * 典型用途：
 * 1. 用户同意隐私协议后，由宿主原生手动初始化 GroMore。
 * 2. 多进程项目中，由宿主在 Application / 指定子进程控制初始化时机。
 */
object GromoreFlutterNativeInit {
  /** 宿主 manifest 中可用的 meta-data key：Android AppId。 */
  const val META_APP_ID = "com.gromore.flutter.APP_ID"

  /** 宿主 manifest 中可用的 meta-data key：Android AppName。 */
  const val META_APP_NAME = "com.gromore.flutter.APP_NAME"

  /** 宿主 manifest 中可用的 meta-data key：是否进程启动即自动初始化。 */
  const val META_AUTO_INIT = "com.gromore.flutter.AUTO_INIT"

  /** 宿主 manifest 中可用的 meta-data key：是否开启 GroMore Debug。 */
  const val META_DEBUG = "com.gromore.flutter.DEBUG"

  /** 宿主 manifest 中可用的 meta-data key：是否启用聚合。 */
  const val META_USE_MEDIATION = "com.gromore.flutter.USE_MEDIATION"

  /** 宿主 manifest 中可用的 meta-data key：是否启用多进程。 */
  const val META_SUPPORT_MULTI_PROCESS = "com.gromore.flutter.SUPPORT_MULTI_PROCESS"

  /** Android 初始化扩展参数 key：是否启用多进程。 */
  const val OPTION_SUPPORT_MULTI_PROCESS = "supportMultiProcess"

  /** Android 初始化扩展参数 key：是否付费流量。 */
  const val OPTION_PAID = "paid"

  /** Android 初始化扩展参数 key：关键词。 */
  const val OPTION_KEYWORDS = "keywords"

  /** Android 初始化扩展参数 key：扩展 data。 */
  const val OPTION_DATA = "data"

  /** Android 初始化扩展参数 key：标题栏主题。 */
  const val OPTION_TITLE_BAR_THEME = "titleBarTheme"

  /** Android 初始化扩展参数 key：是否允许通知。 */
  const val OPTION_ALLOW_SHOW_NOTIFY = "allowShowNotify"

  /** Android 初始化扩展参数 key：主题状态。 */
  const val OPTION_THEME_STATUS = "themeStatus"

  /** Android 初始化扩展参数 key：年龄分组。 */
  const val OPTION_AGE_GROUP = "ageGroup"

  /** Android 初始化扩展参数 key：直下网络类型。 */
  const val OPTION_DIRECT_DOWNLOAD_NETWORK_TYPE = "directDownloadNetworkType"

  /** Android 初始化扩展参数 key：初始化附加参数。 */
  const val OPTION_INIT_EXTRA = "initExtra"

  /** Android 初始化扩展参数 key：隐私配置 map。 */
  const val OPTION_PRIVACY = "privacy"

  /** Android 初始化扩展参数 key：聚合配置 map。 */
  const val OPTION_MEDIATION_CONFIG = "mediationConfig"

  private val mainHandler = Handler(Looper.getMainLooper())

  /** 原生初始化回调。 */
  interface Callback {
    fun onSuccess()

    fun onFailure(errorCode: String, errorMessage: String)
  }

  /**
   * 从宿主 manifest meta-data 读取配置并初始化。
   *
   * 适合：
   * - appId/appName 放在 `AndroidManifest.xml` 或 `res/values` 资源文件
   * - `AUTO_INIT=false`，并希望在隐私同意后手动触发初始化
   */
  @JvmStatic
  @JvmOverloads
  fun initializeFromManifest(
    context: Context,
    androidOptions: Map<String, Any?> = emptyMap(),
    callback: Callback? = null
  ) {
    val args = if (androidOptions.isEmpty()) {
      emptyMap<String, Any?>()
    } else {
      mapOf("androidOptions" to androidOptions)
    }
    val resolvedConfig = GromoreFlutterInitializer.resolveConfig(context.applicationContext, args)
    if (resolvedConfig == null) {
      dispatchFailure(
        callback = callback,
        errorCode = "missing_android_init_config",
        errorMessage = "Android init config is missing. Configure manifest meta-data first."
      )
      return
    }
    initializeResolved(context.applicationContext, resolvedConfig, callback)
  }

  /**
   * 使用宿主原生显式传入的配置手动初始化。
   *
   * 适合：
   * - 不想把 appId/appName 放在 manifest 中
   * - 需要由宿主原生完全掌控初始化参数
   */
  @JvmStatic
  @JvmOverloads
  fun initialize(
    context: Context,
    appId: String,
    appName: String,
    debug: Boolean = false,
    useMediation: Boolean = true,
    androidOptions: Map<String, Any?> = emptyMap(),
    callback: Callback? = null
  ) {
    val args = mutableMapOf<String, Any?>(
      "androidAppId" to appId,
      "androidAppName" to appName,
      "debug" to debug,
      "useMediation" to useMediation
    )
    if (androidOptions.isNotEmpty()) {
      args["androidOptions"] = androidOptions
    }
    val resolvedConfig = GromoreFlutterInitializer.resolveConfig(context.applicationContext, args)
    if (resolvedConfig == null) {
      dispatchFailure(
        callback = callback,
        errorCode = "missing_android_init_config",
        errorMessage = "Android init config is missing."
      )
      return
    }
    initializeResolved(context.applicationContext, resolvedConfig, callback)
  }

  /**
   * 简化版显式初始化，保留 supportMultiProcess 便捷入口。
   */
  @JvmStatic
  fun initialize(
    context: Context,
    appId: String,
    appName: String,
    debug: Boolean = false,
    useMediation: Boolean = true,
    supportMultiProcess: Boolean? = null,
    callback: Callback? = null
  ) {
    val androidOptions = mutableMapOf<String, Any?>()
    if (supportMultiProcess != null) {
      androidOptions[OPTION_SUPPORT_MULTI_PROCESS] = supportMultiProcess
    }
    initialize(
      context = context,
      appId = appId,
      appName = appName,
      debug = debug,
      useMediation = useMediation,
      androidOptions = androidOptions,
      callback = callback
    )
  }

  /** 返回当前 Android 初始化状态。 */
  @JvmStatic
  fun getInitializationStatus(context: Context): Map<String, Any?> {
    return GromoreFlutterInitializer.getInitializationStatus(context.applicationContext)
  }

  private fun initializeResolved(
    context: Context,
    config: GromoreFlutterResolvedInitConfig,
    callback: Callback?
  ) {
    GromoreFlutterInitializer.initialize(
      context = context,
      config = config,
      emitLog = { _, _, _ -> },
      onComplete = { payload ->
        val success = payload["success"] == true
        if (success) {
          dispatchSuccess(callback)
        } else {
          dispatchFailure(
            callback = callback,
            errorCode = payload["errorCode"]?.toString() ?: "init_failed",
            errorMessage = payload["errorMessage"]?.toString() ?: "Init failed."
          )
        }
      }
    )
  }

  private fun dispatchSuccess(callback: Callback?) {
    if (callback == null) {
      return
    }
    mainHandler.post {
      callback.onSuccess()
    }
  }

  private fun dispatchFailure(
    callback: Callback?,
    errorCode: String,
    errorMessage: String
  ) {
    if (callback == null) {
      return
    }
    mainHandler.post {
      callback.onFailure(errorCode, errorMessage)
    }
  }
}
