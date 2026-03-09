import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'ad_event.dart';
import 'ad_request.dart';
import 'ad_types.dart';
import 'ad_callbacks.dart';
import 'config.dart';
import 'init_result.dart';
import 'logger.dart';
import '../gromore_flutter_platform_interface.dart';

/// GroMore Flutter 入口类
///
/// 示例：
/// ```dart
/// final result = await GromoreFlutter.instance.init(
///   const GromoreConfig(
///     androidAppId: 'your_android_app_id',
///     androidAppName: 'your_android_app_name',
///     iosAppId: 'your_ios_app_id',
///     iosAppName: 'your_ios_app_name',
///   ),
/// );
/// ```
class GromoreFlutter {
  GromoreFlutter._();

  /// 单例实例
  static final GromoreFlutter instance = GromoreFlutter._();

  /// 广告事件流控制器
  final StreamController<GromoreAdEvent> _adEventController =
      StreamController<GromoreAdEvent>.broadcast();

  /// 日志事件流控制器
  final StreamController<LogEvent> _logEventController =
      StreamController<LogEvent>.broadcast();

  /// 广告事件订阅
  StreamSubscription<dynamic>? _adEventSubscription;

  /// 日志事件订阅
  StreamSubscription<dynamic>? _logEventSubscription;

  /// adId -> 广告类型映射（用于展示后续控制）
  final Map<String, GromoreAdType> _adTypesById = <String, GromoreAdType>{};

  /// 当前处于方向锁定的开屏 adId（仅 iOS）
  String? _lockedSplashAdId;

  /// 当前是否已执行开屏方向锁定（仅 iOS）
  bool _isSplashOrientationLocked = false;

  /// 广告事件流
  Stream<GromoreAdEvent> get adEvents => _adEventController.stream;

  /// 日志事件流
  Stream<LogEvent> get logEvents => _logEventController.stream;

  /// 确保事件通道已订阅
  void _ensureEventStreams() {
    _adEventSubscription ??=
        GromoreFlutterPlatform.instance.adEvents.listen((dynamic event) {
      if (event is Map) {
        final adEvent = GromoreAdEvent.fromMap(event);
        _onAdEvent(adEvent);
        _adEventController.add(adEvent);
      }
    });
    _logEventSubscription ??=
        GromoreFlutterPlatform.instance.logEvents.listen((dynamic event) {
      if (event is Map) {
        final logEvent = LogEvent.fromMap(event);
        _logEventController.add(logEvent);
        GromoreLogger.handleNative(logEvent);
      }
    });
  }

  /// 初始化 GroMore SDK
  ///
  /// [config] 初始化配置
  Future<InitResult> init(GromoreConfig config) async {
    _ensureEventStreams();
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final bool isIos = defaultTargetPlatform == TargetPlatform.iOS;

    final bool logEnabled = config.enableLog ?? kDebugMode;
    GromoreLogger.setLogEnabled(logEnabled);
    await GromoreFlutterPlatform.instance.setLogEnabled(logEnabled);

    if (isAndroid) {
      final PlatformInitResult androidResult = _validateAndroid(config);
      if (!androidResult.success) {
        return InitResult(
          android: androidResult,
          ios: const PlatformInitResult.skipped(reason: 'not_running_on_ios'),
        );
      }
      final PlatformInitResult result =
          await GromoreFlutterPlatform.instance.init(config);
      return InitResult(
        android: result,
        ios: const PlatformInitResult.skipped(reason: 'not_running_on_ios'),
      );
    }

    if (isIos) {
      final PlatformInitResult iosResult = _validateIos(config);
      if (!iosResult.success) {
        return InitResult(
          android: const PlatformInitResult.skipped(
              reason: 'not_running_on_android'),
          ios: iosResult,
        );
      }
      final PlatformInitResult result =
          await GromoreFlutterPlatform.instance.init(config);
      return InitResult(
        android:
            const PlatformInitResult.skipped(reason: 'not_running_on_android'),
        ios: result,
      );
    }

    return const InitResult(
      android: PlatformInitResult.skipped(reason: 'unsupported_platform'),
      ios: PlatformInitResult.skipped(reason: 'unsupported_platform'),
    );
  }

  /// 设置日志开关
  ///
  /// [enabled] 是否启用日志
  Future<void> setLogEnabled(bool enabled) async {
    GromoreLogger.setLogEnabled(enabled);
    await GromoreFlutterPlatform.instance.setLogEnabled(enabled);
  }

  /// 设置日志级别
  ///
  /// [level] 日志级别
  Future<void> setLogLevel(LogLevel level) async {
    GromoreLogger.setLogLevel(level);
    await GromoreFlutterPlatform.instance.setLogLevel(level);
  }

  /// 加载广告
  ///
  /// [type] 广告类型
  /// [request] 广告请求参数
  ///
  /// 示例：
  /// ```dart
  /// final adId = await GromoreFlutter.instance.loadAd(
  ///   GromoreAdType.splash,
  ///   const GromoreAdRequest(placementId: 'your_placement_id'),
  /// );
  /// ```
  Future<String> loadAd(GromoreAdType type, GromoreAdRequest request) async {
    _assertAdTypeEnabled(type);
    final shouldLockSplashOrientation =
        defaultTargetPlatform == TargetPlatform.iOS &&
            type == GromoreAdType.splash;
    if (shouldLockSplashOrientation) {
      await _lockSplashOrientation();
    }
    final String adId;
    try {
      adId = await GromoreFlutterPlatform.instance.loadAd(type, request);
    } catch (_) {
      if (shouldLockSplashOrientation) {
        await _unlockSplashOrientation();
      }
      rethrow;
    }
    if (shouldLockSplashOrientation) {
      await _lockSplashOrientation(adId: adId);
    }
    _adTypesById[adId] = type;
    return adId;
  }

  /// 展示广告
  ///
  /// [adId] 广告实例 ID
  Future<void> showAd(String adId) async {
    final adType = _adTypesById[adId];
    final shouldLockSplashOrientation =
        defaultTargetPlatform == TargetPlatform.iOS &&
            adType == GromoreAdType.splash;
    if (shouldLockSplashOrientation) {
      await _lockSplashOrientation(adId: adId);
    }
    try {
      return await GromoreFlutterPlatform.instance.showAd(adId);
    } catch (_) {
      if (shouldLockSplashOrientation) {
        await _unlockSplashOrientation();
      }
      rethrow;
    }
  }

  /// 销毁广告
  ///
  /// [adId] 广告实例 ID
  Future<void> disposeAd(String adId) async {
    final adType = _adTypesById.remove(adId);
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        adType == GromoreAdType.splash &&
        _lockedSplashAdId == adId) {
      await _unlockSplashOrientation();
    }
    return GromoreFlutterPlatform.instance.disposeAd(adId);
  }

  /// 调用原生自定义方法
  ///
  /// [method] 原生方法名
  /// [args] 方法参数
  Future<dynamic> invokeNative(
      String method, Map<String, dynamic>? args) async {
    return GromoreFlutterPlatform.instance.invokeNative(method, args);
  }

  /// 请求 iOS ATT 授权（仅 iOS）
  ///
  /// 返回 true 表示已授权或无需授权
  Future<bool> requestATT() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }
    final dynamic result = await invokeNative('requestATT', null);
    return result == true;
  }

  /// 监听广告事件（支持按 adId / adType 过滤）
  StreamSubscription<GromoreAdEvent> listenAdEvents({
    String? adId,
    GromoreAdType? adType,
    required GromoreAdCallback callback,
  }) {
    _ensureEventStreams();
    return adEvents.where((event) {
      final bool idMatch = adId == null || event.adId == adId;
      final bool typeMatch = adType == null || event.adType == adType;
      return idMatch && typeMatch;
    }).listen(callback.handle);
  }

  void _onAdEvent(GromoreAdEvent event) {
    if (_isTerminalAdEvent(event.eventType)) {
      _adTypesById.remove(event.adId);
    }
    final shouldUnlockSplashOrientation =
        defaultTargetPlatform == TargetPlatform.iOS &&
            event.adType == GromoreAdType.splash &&
            event.adId == _lockedSplashAdId &&
            _isSplashUnlockEvent(event.eventType);
    if (shouldUnlockSplashOrientation) {
      _unlockSplashOrientation();
    }
  }

  bool _isTerminalAdEvent(GromoreAdEventType eventType) {
    switch (eventType) {
      case GromoreAdEventType.failed:
      case GromoreAdEventType.error:
      case GromoreAdEventType.closed:
      case GromoreAdEventType.skipped:
      case GromoreAdEventType.completed:
        return true;
      default:
        return false;
    }
  }

  bool _isSplashUnlockEvent(GromoreAdEventType eventType) {
    switch (eventType) {
      case GromoreAdEventType.failed:
      case GromoreAdEventType.error:
      case GromoreAdEventType.closed:
      case GromoreAdEventType.skipped:
      case GromoreAdEventType.completed:
        return true;
      default:
        return false;
    }
  }

  Future<void> _lockSplashOrientation({String? adId}) async {
    if (_isSplashOrientationLocked &&
        adId != null &&
        _lockedSplashAdId == adId) {
      await _waitForPortraitOrientation();
      return;
    }
    if (!_isSplashOrientationLocked) {
      await SystemChrome.setPreferredOrientations(
        const <DeviceOrientation>[DeviceOrientation.portraitUp],
      );
      _isSplashOrientationLocked = true;
    }
    if (adId != null) {
      _lockedSplashAdId = adId;
    }
    await _waitForPortraitOrientation();
  }

  Future<void> _unlockSplashOrientation() async {
    if (!_isSplashOrientationLocked && _lockedSplashAdId == null) {
      return;
    }
    _lockedSplashAdId = null;
    _isSplashOrientationLocked = false;
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
  }

  Future<void> _waitForPortraitOrientation() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final DateTime deadline =
        DateTime.now().add(const Duration(milliseconds: 1200));
    while (DateTime.now().isBefore(deadline)) {
      final views = WidgetsBinding.instance.platformDispatcher.views;
      final Size size = views.isNotEmpty ? views.first.physicalSize : Size.zero;
      if (size.width > 0 && size.height > 0 && size.height >= size.width) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  /// 校验 Android 初始化参数
  ///
  /// [config] 初始化配置
  PlatformInitResult _validateAndroid(GromoreConfig config) {
    if ((config.androidAppId ?? '').isEmpty) {
      GromoreLogger.error('Android appId is missing.', tag: 'init');
      return const PlatformInitResult.failure(
        errorCode: 'missing_android_app_id',
        errorMessage: 'Android appId is missing.',
      );
    }
    if ((config.androidAppName ?? '').isEmpty) {
      GromoreLogger.error('Android appName is missing.', tag: 'init');
      return const PlatformInitResult.failure(
        errorCode: 'missing_android_app_name',
        errorMessage: 'Android appName is missing.',
      );
    }
    return const PlatformInitResult.success();
  }

  /// 校验 iOS 初始化参数
  ///
  /// [config] 初始化配置
  PlatformInitResult _validateIos(GromoreConfig config) {
    if ((config.iosAppId ?? '').isEmpty) {
      GromoreLogger.error('iOS appId is missing.', tag: 'init');
      return const PlatformInitResult.failure(
        errorCode: 'missing_ios_app_id',
        errorMessage: 'iOS appId is missing.',
      );
    }
    if ((config.iosAppName ?? '').isEmpty) {
      GromoreLogger.error('iOS appName is missing.', tag: 'init');
      return const PlatformInitResult.failure(
        errorCode: 'missing_ios_app_name',
        errorMessage: 'iOS appName is missing.',
      );
    }
    return const PlatformInitResult.success();
  }

  /// 断言广告类型已启用
  ///
  /// [type] 广告类型
  void _assertAdTypeEnabled(GromoreAdType type) {
    final Set<GromoreAdType> enabledTypes =
        GromoreFlutterPlatform.instance.enabledAdTypes;
    if (!enabledTypes.contains(type)) {
      final message = 'Ad type ${type.value} is not enabled.';
      GromoreLogger.warn(message, tag: 'ad');
      throw StateError(message);
    }
  }
}
