package com.gromore.flutter

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.bytedance.sdk.openadsdk.TTAdConfig
import com.bytedance.sdk.openadsdk.TTAdSdk
import com.bytedance.tools.util.ToolsUtil
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * GroMore Flutter 插件 Android 实现
 */
class GromoreFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  /** 方法通道 */
  private lateinit var methodChannel: MethodChannel

  /** 广告事件通道 */
  private var adEventChannel: EventChannel? = null

  /** 日志事件通道 */
  private var logEventChannel: EventChannel? = null

  /** 广告事件 sink */
  private var adEventSink: EventChannel.EventSink? = null

  /** 日志事件 sink */
  private var logEventSink: EventChannel.EventSink? = null

  /** 主线程 Handler */
  private val mainHandler = Handler(Looper.getMainLooper())

  /** 当前 Activity */
  private var activity: Activity? = null

  /** 应用上下文 */
  private var applicationContext: Context? = null

  /** 广告管理器 */
  private var adManager: GromoreAdManager? = null

  /** 初始化状态 */
  private var initInProgress = false

  /** 日志开关 */
  private var logEnabled = false

  /** 日志级别 */
  private var logLevel = "info"

  /**
   * 绑定到 Flutter Engine
   *
   * @param binding FlutterPlugin 绑定对象
   */
  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = binding.applicationContext
    methodChannel = MethodChannel(binding.binaryMessenger, "gromore_flutter/methods")
    methodChannel.setMethodCallHandler(this)

    adEventChannel = EventChannel(binding.binaryMessenger, "gromore_flutter/ad_events")
    logEventChannel = EventChannel(binding.binaryMessenger, "gromore_flutter/log_events")

    adEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
      /**
       * 监听广告事件流
       *
       * @param arguments 监听参数
       * @param events 事件发送器
       */
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        adEventSink = events
      }

      /**
       * 取消广告事件流监听
       *
       * @param arguments 监听参数
       */
      override fun onCancel(arguments: Any?) {
        adEventSink = null
      }
    })

    logEventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
      /**
       * 监听日志事件流
       *
       * @param arguments 监听参数
       * @param events 事件发送器
       */
      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        logEventSink = events
      }

      /**
       * 取消日志事件流监听
       *
       * @param arguments 监听参数
       */
      override fun onCancel(arguments: Any?) {
        logEventSink = null
      }
    })

    adManager = GromoreAdManager(
      appContext = binding.applicationContext,
      activityProvider = { activity },
      emitAdEvent = { payload -> emitAdEvent(payload) },
      emitLog = { level, message, tag -> emitLog(level, message, tag) }
    )
    binding.platformViewRegistry.registerViewFactory(
      "gromore_flutter/ad_view",
      GromoreAdViewFactory(adManager!!)
    )
  }

  /**
   * 解绑 Flutter Engine
   *
   * @param binding FlutterPlugin 绑定对象
   */
  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    adEventChannel?.setStreamHandler(null)
    logEventChannel?.setStreamHandler(null)
    adEventSink = null
    logEventSink = null
    adManager?.clearAll()
    adManager = null
    applicationContext = null
  }

  /**
   * 方法通道回调
   *
   * @param call 方法调用信息
   * @param result 回调结果
   */
  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "init" -> handleInit(call, result)
      "setLogEnabled" -> handleSetLogEnabled(call, result)
      "setLogLevel" -> handleSetLogLevel(call, result)
      "loadAd" -> handleLoadAd(call, result)
      "showAd" -> handleShowAd(call, result)
      "disposeAd" -> handleDisposeAd(call, result)
      "invokeNative" -> handleInvokeNative(call, result)
      else -> {
        result.notImplemented()
      }
    }
  }

  /**
   * 处理初始化
   *
   * @param call 方法调用信息
   * @param result 回调结果
   */
  private fun handleInit(call: MethodCall, result: Result) {
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
    val appId = args["androidAppId"] as? String
    val appName = args["androidAppName"] as? String
    val debug = args["debug"] as? Boolean ?: false
    val useMediation = args["useMediation"] as? Boolean ?: true
    val enableLog = args["enableLog"] as? Boolean

    if (enableLog != null) {
      logEnabled = enableLog
    }

    if (appId.isNullOrBlank()) {
      emitLog("error", "Android appId is missing.", "init")
      result.success(
        mapOf(
          "success" to false,
          "errorCode" to "missing_android_app_id",
          "errorMessage" to "Android appId is missing."
        )
      )
      return
    }

    if (appName.isNullOrBlank()) {
      emitLog("error", "Android appName is missing.", "init")
      result.success(
        mapOf(
          "success" to false,
          "errorCode" to "missing_android_app_name",
          "errorMessage" to "Android appName is missing."
        )
      )
      return
    }

    if (TTAdSdk.isInitSuccess()) {
      emitLog("info", "init result success=true reason=already_initialized", "init")
      result.success(mapOf("success" to true))
      return
    }
    if (initInProgress) {
      emitLog("warn", "init result success=false reason=init_in_progress", "init")
      result.success(
        mapOf(
          "success" to false,
          "errorCode" to "init_in_progress",
          "errorMessage" to "Init is already in progress."
        )
      )
      return
    }

    initInProgress = true
    val config = TTAdConfig.Builder()
      .appId(appId)
      .appName(appName)
      .debug(debug)
      .useMediation(useMediation)
      .build()

    val context = applicationContext ?: activity?.applicationContext
    if (context == null) {
      initInProgress = false
      emitLog("error", "init result success=false reason=no_context", "init")
      result.success(
        mapOf(
          "success" to false,
          "errorCode" to "no_context",
          "errorMessage" to "Application context is null."
        )
      )
      return
    }

    val initSuccess = TTAdSdk.init(context, config)
    if (!initSuccess) {
      initInProgress = false
      emitLog("error", "init result success=false reason=init_failed", "init")
      result.success(
        mapOf(
          "success" to false,
          "errorCode" to "init_failed",
          "errorMessage" to "TTAdSdk.init returned false."
        )
      )
      return
    }

    TTAdSdk.start(object : TTAdSdk.Callback {
      override fun success() {
        initInProgress = false
        emitLog("info", "init result success=true reason=started", "init")
        mainHandler.post {
          result.success(mapOf("success" to true))
        }
      }

      override fun fail(code: Int, msg: String?) {
        initInProgress = false
        emitLog("error", "init result success=false reason=$code:$msg", "init")
        mainHandler.post {
          result.success(
            mapOf(
              "success" to false,
              "errorCode" to code.toString(),
              "errorMessage" to (msg ?: "TTAdSdk.start failed.")
            )
          )
        }
      }
    })
  }

  /**
   * 设置日志开关
   *
   * @param call 方法调用信息
   * @param result 回调结果
   */
  private fun handleSetLogEnabled(call: MethodCall, result: Result) {
    val args = call.arguments as? Map<*, *>
    logEnabled = args?.get("enabled") as? Boolean ?: logEnabled
    result.success(null)
  }

  /**
   * 设置日志级别
   *
   * @param call 方法调用信息
   * @param result 回调结果
   */
  private fun handleSetLogLevel(call: MethodCall, result: Result) {
    val args = call.arguments as? Map<*, *>
    logLevel = args?.get("level") as? String ?: logLevel
    result.success(null)
  }

  /**
   * 加载广告（占位）
   *
   * @param call 方法调用信息
   * @param result 回调结果
   */
  private fun handleLoadAd(call: MethodCall, result: Result) {
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
    val adType = args["adType"] as? String
    val request = args["request"] as? Map<*, *> ?: emptyMap<Any, Any>()
    val placementId = request["placementId"] as? String
    if (adType.isNullOrBlank() || placementId.isNullOrBlank()) {
      result.error("invalid_args", "adType or placementId is missing.", null)
      return
    }
    val manager = adManager
    if (manager == null) {
      result.error("not_ready", "Ad manager is not ready.", null)
      return
    }
    val adId = manager.newAdId()
    manager.loadAd(adId, adType, placementId, request)
    result.success(adId)
  }

  /**
   * 展示广告（占位）
   *
   * @param call 方法调用信息
   * @param result 回调结果
   */
  private fun handleShowAd(call: MethodCall, result: Result) {
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
    val adId = args["adId"] as? String
    if (adId.isNullOrBlank()) {
      result.error("invalid_args", "adId is missing.", null)
      return
    }
    adManager?.showAd(adId)
    result.success(null)
  }

  /**
   * 销毁广告（占位）
   *
   * @param call 方法调用信息
   * @param result 回调结果
   */
  private fun handleDisposeAd(call: MethodCall, result: Result) {
    val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
    val adId = args["adId"] as? String
    if (adId.isNullOrBlank()) {
      result.error("invalid_args", "adId is missing.", null)
      return
    }
    adManager?.disposeAd(adId)
    result.success(null)
  }

  /**
   * 调用原生自定义方法（平台透传兜底）
   *
   * @param call 方法调用信息
   * @param result 回调结果
   */
  private fun handleInvokeNative(call: MethodCall, result: Result) {
    val args = call.arguments as? Map<*, *>
    val method = args?.get("method") as? String ?: "unknown"
    when (method) {
      "isSdkReady" -> result.success(TTAdSdk.isSdkReady())
      "isInitSuccess" -> result.success(TTAdSdk.isInitSuccess())
      "getSdkVersionName" -> result.success(TTAdSdk.SDK_VERSION_NAME)
      "getSdkVersionCode" -> result.success(TTAdSdk.SDK_VERSION_CODE)
      "requestATT" -> result.success(true)
      // 打开 GroMore 测试工具（仅 Debug）
      "openTestTool" -> {
        if (!BuildConfig.DEBUG) {
          result.error("debug_only", "Test tool is only available in debug mode.", null)
          return
        }
        val currentActivity = activity
        if (currentActivity == null) {
          result.error("no_activity", "Activity is null.", null)
          return
        }
        ToolsUtil.start(currentActivity)
        result.success(true)
      }
      "getMediationExtraInfo" -> {
        val info = TTAdSdk.getMediationManager().mediationExtraInfo
        val safeInfo = info.mapValues { entry -> entry.value?.toString() }
        result.success(safeInfo)
      }
      else -> {
        emitLog("warn", "invokeNative not implemented: $method", "native")
        result.error("not_implemented", "invokeNative is not implemented: $method", null)
      }
    }
  }

  /**
   * 发送广告事件到 Flutter
   *
   * @param payload 事件数据
   */
  private fun emitAdEvent(payload: Map<String, Any?>) {
    mainHandler.post {
      adEventSink?.success(payload)
    }
  }

  /**
   * 发送日志事件到 Flutter
   *
   * @param level 日志级别
   * @param message 日志内容
   * @param tag 日志标签
   */
  private fun emitLog(level: String, message: String, tag: String) {
    if (!shouldLog(level)) {
      return
    }
    val payload = mapOf(
      "level" to level,
      "message" to message,
      "tag" to tag,
      "timestamp" to System.currentTimeMillis(),
      "source" to "native"
    )
    mainHandler.post {
      logEventSink?.success(payload)
    }
  }

  /**
   * 判断是否输出日志
   *
   * @param level 日志级别
   */
  private fun shouldLog(level: String): Boolean {
    if (!logEnabled) {
      return false
    }
    return levelPriority(level) >= levelPriority(logLevel)
  }

  /**
   * 获取日志级别优先级
   *
   * @param level 日志级别
   */
  private fun levelPriority(level: String): Int {
    return when (level) {
      "debug" -> 0
      "info" -> 1
      "warn" -> 2
      "error" -> 3
      else -> 1
    }
  }

  /**
   * 绑定 Activity
   *
   * @param binding Activity 绑定对象
   */
  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  /** 配置变化导致 Activity 分离 */
  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  /**
   * 配置变化后重新绑定 Activity
   *
   * @param binding Activity 绑定对象
   */
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  /** Activity 分离 */
  override fun onDetachedFromActivity() {
    activity = null
  }
}
