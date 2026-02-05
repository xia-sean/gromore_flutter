import Flutter
import UIKit
import BUAdSDK
import AppTrackingTransparency

/// GroMore Flutter 插件 iOS 实现
public class GromoreFlutterPlugin: NSObject, FlutterPlugin {
  /// 方法通道
  private var methodChannel: FlutterMethodChannel?
  /// 广告事件通道
  private var adEventChannel: FlutterEventChannel?
  /// 日志事件通道
  private var logEventChannel: FlutterEventChannel?
  /// 广告事件 sink
  private var adEventSink: FlutterEventSink?
  /// 日志事件 sink
  private var logEventSink: FlutterEventSink?

  /// 广告管理器
  private var adManager: GromoreAdManager?

  /// 初始化状态
  private var initInProgress = false

  /// 日志开关
  private var logEnabled: Bool = false
  /// 日志级别
  private var logLevel: String = "info"

  /// 注册插件
  ///
  /// - Parameter registrar: Flutter 插件注册器
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = GromoreFlutterPlugin()
    let methodChannel = FlutterMethodChannel(name: "gromore_flutter/methods", binaryMessenger: registrar.messenger())
    let adEventChannel = FlutterEventChannel(name: "gromore_flutter/ad_events", binaryMessenger: registrar.messenger())
    let logEventChannel = FlutterEventChannel(name: "gromore_flutter/log_events", binaryMessenger: registrar.messenger())

    instance.methodChannel = methodChannel
    instance.adEventChannel = adEventChannel
    instance.logEventChannel = logEventChannel

    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    adEventChannel.setStreamHandler(AdEventStreamHandler(owner: instance))
    logEventChannel.setStreamHandler(LogEventStreamHandler(owner: instance))

    let adManager = GromoreAdManager(
      emitAdEvent: { payload in
        instance.emitAdEvent(payload)
      },
      emitLog: { level, message, tag in
        instance.emitLog(level: level, message: message, tag: tag)
      }
    )
    instance.adManager = adManager
    registrar.register(GromoreAdViewFactory(adManager: adManager), withId: "gromore_flutter/ad_view")
  }

  /// 方法通道回调
  ///
  /// - Parameters:
  ///   - call: 方法调用信息
  ///   - result: 回调结果
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "init":
      handleInit(call, result: result)
    case "setLogEnabled":
      handleSetLogEnabled(call, result: result)
    case "setLogLevel":
      handleSetLogLevel(call, result: result)
    case "loadAd":
      handleLoadAd(call, result: result)
    case "showAd":
      handleShowAd(call, result: result)
    case "disposeAd":
      handleDisposeAd(call, result: result)
    case "invokeNative":
      handleInvokeNative(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 处理初始化
  ///
  /// - Parameters:
  ///   - call: 方法调用信息
  ///   - result: 回调结果
  private func handleInit(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let appId = args?["iosAppId"] as? String
    let appName = args?["iosAppName"] as? String
    let debug = args?["debug"] as? Bool ?? false
    let useMediation = args?["useMediation"] as? Bool ?? true
    if let enableLog = args?["enableLog"] as? Bool {
      logEnabled = enableLog
    }

    if appId == nil || appId?.isEmpty == true {
      emitLog(level: "error", message: "iOS appId is missing.", tag: "init")
      result([
        "success": false,
        "errorCode": "missing_ios_app_id",
        "errorMessage": "iOS appId is missing."
      ])
      return
    }

    if appName == nil || appName?.isEmpty == true {
      emitLog(level: "error", message: "iOS appName is missing.", tag: "init")
      result([
        "success": false,
        "errorCode": "missing_ios_app_name",
        "errorMessage": "iOS appName is missing."
      ])
      return
    }

    if BUAdSDKManager.state == .start {
      emitLog(level: "info", message: "init result success=true reason=already_initialized", tag: "init")
      result(["success": true])
      return
    }

    if initInProgress {
      emitLog(level: "warn", message: "init result success=false reason=init_in_progress", tag: "init")
      result([
        "success": false,
        "errorCode": "init_in_progress",
        "errorMessage": "Init is already in progress."
      ])
      return
    }

    initInProgress = true
    let configuration = BUAdSDKConfiguration.configuration()
    configuration.appID = appId
    configuration.debugLog = NSNumber(value: debug ? 1 : 0)
    configuration.useMediation = useMediation

    BUAdSDKManager.start(asyncCompletionHandler: { success, error in
      self.initInProgress = false
      if success {
        self.emitLog(level: "info", message: "init result success=true reason=started", tag: "init")
        result(["success": true])
      } else {
        let code = error?._code ?? -1
        let message = error?.localizedDescription ?? "BUAdSDKManager start failed."
        self.emitLog(level: "error", message: "init result success=false reason=\(code):\(message)", tag: "init")
        result([
          "success": false,
          "errorCode": "\(code)",
          "errorMessage": message
        ])
      }
    })
  }

  /// 设置日志开关
  ///
  /// - Parameters:
  ///   - call: 方法调用信息
  ///   - result: 回调结果
  private func handleSetLogEnabled(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if let args = call.arguments as? [String: Any],
       let enabled = args["enabled"] as? Bool {
      logEnabled = enabled
    }
    result(nil)
  }

  /// 设置日志级别
  ///
  /// - Parameters:
  ///   - call: 方法调用信息
  ///   - result: 回调结果
  private func handleSetLogLevel(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if let args = call.arguments as? [String: Any],
       let level = args["level"] as? String {
      logLevel = level
    }
    result(nil)
  }

  /// 加载广告
  ///
  /// - Parameters:
  ///   - call: 方法调用信息
  ///   - result: 回调结果
  private func handleLoadAd(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let adType = args?["adType"] as? String
    let request = args?["request"] as? [String: Any] ?? [:]
    let placementId = request["placementId"] as? String
    if adType == nil || placementId == nil || placementId?.isEmpty == true {
      result(FlutterError(code: "invalid_args", message: "adType or placementId is missing.", details: nil))
      return
    }
    guard let adManager = adManager else {
      result(FlutterError(code: "not_ready", message: "Ad manager is not ready.", details: nil))
      return
    }
    let adId = adManager.newAdId()
    adManager.loadAd(adId: adId, adType: adType ?? "", placementId: placementId ?? "", request: request)
    result(adId)
  }

  /// 展示广告
  ///
  /// - Parameters:
  ///   - call: 方法调用信息
  ///   - result: 回调结果
  private func handleShowAd(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let adId = args?["adId"] as? String
    if adId == nil || adId?.isEmpty == true {
      result(FlutterError(code: "invalid_args", message: "adId is missing.", details: nil))
      return
    }
    adManager?.showAd(adId: adId ?? "")
    result(nil)
  }

  /// 销毁广告
  ///
  /// - Parameters:
  ///   - call: 方法调用信息
  ///   - result: 回调结果
  private func handleDisposeAd(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let adId = args?["adId"] as? String
    if adId == nil || adId?.isEmpty == true {
      result(FlutterError(code: "invalid_args", message: "adId is missing.", details: nil))
      return
    }
    adManager?.disposeAd(adId: adId ?? "")
    result(nil)
  }

  /// 调用原生自定义方法（平台透传兜底）
  ///
  /// - Parameters:
  ///   - call: 方法调用信息
  ///   - result: 回调结果
  private func handleInvokeNative(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let method = args?["method"] as? String ?? "unknown"
    switch method {
    case "getSdkVersion":
      result(BUAdSDKManager.sdkVersion)
    case "getSdkState":
      result(BUAdSDKManager.state.rawValue)
    case "getAppId":
      result(BUAdSDKManager.appID())
    case "requestATT":
      if #available(iOS 14, *) {
        ATTrackingManager.requestTrackingAuthorization { status in
          DispatchQueue.main.async {
            result(status == .authorized)
          }
        }
      } else {
        result(true)
      }
    // 打开 GroMore 预览工具（仅 Debug）
    case "openTestTool":
#if DEBUG
      var info = args?["info"] as? [String: Any] ?? [:]
      if let rit = args?["rit"] as? String, !rit.isEmpty {
        info["rit"] = rit
      }
      BUAdSDKTestToolManager.configStylePreviewInfo(info) { success, error, _ in
        if success {
          result(true)
        } else {
          result(FlutterError(code: "preview_failed", message: error.localizedDescription, details: nil))
        }
      }
#else
      result(FlutterError(code: "debug_only", message: "Test tool is only available in debug mode.", details: nil))
#endif
    default:
      emitLog(level: "warn", message: "invokeNative not implemented: \(method)", tag: "native")
      result(FlutterError(code: "not_implemented", message: "invokeNative is not implemented: \(method)", details: nil))
    }
  }

  /// 发送广告事件到 Flutter
  ///
  /// - Parameter payload: 事件数据
  private func emitAdEvent(_ payload: [String: Any]) {
    DispatchQueue.main.async {
      self.adEventSink?(payload)
    }
  }

  /// 发送日志事件到 Flutter
  ///
  /// - Parameters:
  ///   - level: 日志级别
  ///   - message: 日志内容
  ///   - tag: 日志标签
  private func emitLog(level: String, message: String, tag: String) {
    guard shouldLog(level: level) else { return }
    let payload: [String: Any] = [
      "level": level,
      "message": message,
      "tag": tag,
      "timestamp": Int(Date().timeIntervalSince1970 * 1000),
      "source": "native"
    ]
    logEventSink?(payload)
  }

  /// 判断是否输出日志
  ///
  /// - Parameter level: 日志级别
  private func shouldLog(level: String) -> Bool {
    if !logEnabled { return false }
    return levelPriority(level) >= levelPriority(logLevel)
  }

  /// 获取日志级别优先级
  ///
  /// - Parameter level: 日志级别
  private func levelPriority(_ level: String) -> Int {
    switch level {
    case "debug":
      return 0
    case "info":
      return 1
    case "warn":
      return 2
    case "error":
      return 3
    default:
      return 1
    }
  }

  /// 广告事件流处理器
  private class AdEventStreamHandler: NSObject, FlutterStreamHandler {
    /// 插件实例引用
    private weak var owner: GromoreFlutterPlugin?

    /// 构建处理器
    ///
    /// - Parameter owner: 插件实例
    init(owner: GromoreFlutterPlugin) {
      self.owner = owner
    }

    /// 开始监听事件流
    ///
    /// - Parameters:
    ///   - arguments: 监听参数
    ///   - events: 事件发送器
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
      owner?.adEventSink = events
      return nil
    }

    /// 取消监听事件流
    ///
    /// - Parameter arguments: 监听参数
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
      owner?.adEventSink = nil
      return nil
    }
  }

  /// 日志事件流处理器
  private class LogEventStreamHandler: NSObject, FlutterStreamHandler {
    /// 插件实例引用
    private weak var owner: GromoreFlutterPlugin?

    /// 构建处理器
    ///
    /// - Parameter owner: 插件实例
    init(owner: GromoreFlutterPlugin) {
      self.owner = owner
    }

    /// 开始监听事件流
    ///
    /// - Parameters:
    ///   - arguments: 监听参数
    ///   - events: 事件发送器
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
      owner?.logEventSink = events
      return nil
    }

    /// 取消监听事件流
    ///
    /// - Parameter arguments: 监听参数
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
      owner?.logEventSink = nil
      return nil
    }
  }
}
