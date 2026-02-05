import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'gromore_flutter_method_channel.dart';
import 'src/ad_request.dart';
import 'src/ad_types.dart';
import 'src/config.dart';
import 'src/init_result.dart';
import 'src/logger.dart';

/// 平台接口定义（Android/iOS 具体实现）
abstract class GromoreFlutterPlatform extends PlatformInterface {
  GromoreFlutterPlatform() : super(token: _token);

  /// 用于平台接口校验的 token
  static final Object _token = Object();

  /// 默认平台实现
  static GromoreFlutterPlatform _instance = MethodChannelGromoreFlutter();

  /// 获取当前平台实现实例
  static GromoreFlutterPlatform get instance => _instance;

  /// 设置平台实现实例
  ///
  /// [instance] 平台实现对象
  static set instance(GromoreFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// 启用的广告类型集合
  Set<GromoreAdType> get enabledAdTypes => _enabledAdTypes;

  /// 内部维护的广告类型集合
  Set<GromoreAdType> _enabledAdTypes = const {
    GromoreAdType.splash,
    GromoreAdType.interstitial,
    GromoreAdType.fullscreenVideo,
    GromoreAdType.rewardVideo,
    GromoreAdType.native,
    GromoreAdType.drawNative,
    GromoreAdType.banner,
  };

  /// 更新启用的广告类型集合
  ///
  /// [enabledTypes] 启用的广告类型集合
  void updateEnabledAdTypes(Set<GromoreAdType> enabledTypes) {
    _enabledAdTypes = enabledTypes;
  }

  /// 初始化 SDK
  ///
  /// [config] 初始化配置
  Future<PlatformInitResult> init(GromoreConfig config) {
    throw UnimplementedError('init() has not been implemented.');
  }

  /// 设置日志开关
  ///
  /// [enabled] 是否启用日志
  Future<void> setLogEnabled(bool enabled) {
    throw UnimplementedError('setLogEnabled() has not been implemented.');
  }

  /// 设置日志级别
  ///
  /// [level] 日志级别
  Future<void> setLogLevel(LogLevel level) {
    throw UnimplementedError('setLogLevel() has not been implemented.');
  }

  /// 加载广告
  ///
  /// [type] 广告类型
  /// [request] 广告请求参数
  Future<String> loadAd(GromoreAdType type, GromoreAdRequest request) {
    throw UnimplementedError('loadAd() has not been implemented.');
  }

  /// 展示广告
  ///
  /// [adId] 广告实例 ID
  Future<void> showAd(String adId) {
    throw UnimplementedError('showAd() has not been implemented.');
  }

  /// 销毁广告
  ///
  /// [adId] 广告实例 ID
  Future<void> disposeAd(String adId) {
    throw UnimplementedError('disposeAd() has not been implemented.');
  }

  /// 广告事件流
  Stream<dynamic> get adEvents {
    throw UnimplementedError('adEvents has not been implemented.');
  }

  /// 日志事件流
  Stream<dynamic> get logEvents {
    throw UnimplementedError('logEvents has not been implemented.');
  }

  /// 调用原生自定义方法
  ///
  /// [method] 原生方法名
  /// [args] 方法参数
  Future<dynamic> invokeNative(String method, Map<String, dynamic>? args) {
    throw UnimplementedError('invokeNative() has not been implemented.');
  }
}
