import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'gromore_flutter_platform_interface.dart';
import 'src/ad_request.dart';
import 'src/ad_types.dart';
import 'src/config.dart';
import 'src/init_result.dart';
import 'src/logger.dart';

/// MethodChannel 平台实现
class MethodChannelGromoreFlutter extends GromoreFlutterPlatform {
  @visibleForTesting
  /// 方法通道
  final MethodChannel methodChannel =
      const MethodChannel('gromore_flutter/methods');

  @visibleForTesting
  /// 广告事件通道
  final EventChannel adEventChannel =
      const EventChannel('gromore_flutter/ad_events');

  @visibleForTesting
  /// 日志事件通道
  final EventChannel logEventChannel =
      const EventChannel('gromore_flutter/log_events');

  /// 广告事件流缓存
  Stream<dynamic>? _adEventStream;

  /// 日志事件流缓存
  Stream<dynamic>? _logEventStream;

  @override
  /// 初始化 SDK
  ///
  /// [config] 初始化配置
  Future<PlatformInitResult> init(GromoreConfig config) async {
    updateEnabledAdTypes(config.enabledAdTypes);
    final Map<dynamic, dynamic>? result = await methodChannel
        .invokeMethod<Map<dynamic, dynamic>>('init', config.toMap());
    if (result == null) {
      return const PlatformInitResult.failure(
        errorCode: 'init_failed',
        errorMessage: 'Init returned null.',
      );
    }
    return PlatformInitResult.fromMap(result);
  }

  @override
  /// 设置日志开关
  ///
  /// [enabled] 是否启用日志
  Future<void> setLogEnabled(bool enabled) async {
    await methodChannel.invokeMethod('setLogEnabled', {'enabled': enabled});
  }

  @override
  /// 设置日志级别
  ///
  /// [level] 日志级别
  Future<void> setLogLevel(LogLevel level) async {
    await methodChannel.invokeMethod('setLogLevel', {'level': level.value});
  }

  @override
  /// 加载广告
  ///
  /// [type] 广告类型
  /// [request] 广告请求参数
  Future<String> loadAd(GromoreAdType type, GromoreAdRequest request) async {
    final String? adId = await methodChannel.invokeMethod<String>('loadAd', {
      'adType': type.value,
      'request': request.toMap(),
    });
    if (adId == null || adId.isEmpty) {
      throw PlatformException(
        code: 'load_failed',
        message: 'loadAd returned empty adId.',
      );
    }
    return adId;
  }

  @override
  /// 展示广告
  ///
  /// [adId] 广告实例 ID
  Future<void> showAd(String adId) async {
    await methodChannel.invokeMethod('showAd', {'adId': adId});
  }

  @override
  /// 销毁广告
  ///
  /// [adId] 广告实例 ID
  Future<void> disposeAd(String adId) async {
    await methodChannel.invokeMethod('disposeAd', {'adId': adId});
  }

  @override
  /// 广告事件流
  Stream<dynamic> get adEvents {
    _adEventStream ??= adEventChannel.receiveBroadcastStream();
    return _adEventStream!;
  }

  @override
  /// 日志事件流
  Stream<dynamic> get logEvents {
    _logEventStream ??= logEventChannel.receiveBroadcastStream();
    return _logEventStream!;
  }

  @override
  /// 调用原生自定义方法
  ///
  /// [method] 原生方法名
  /// [args] 方法参数
  Future<dynamic> invokeNative(String method, Map<String, dynamic>? args) {
    return methodChannel.invokeMethod('invokeNative', {
      'method': method,
      'args': args,
    });
  }
}
