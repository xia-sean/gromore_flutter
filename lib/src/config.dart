import 'ad_types.dart';

/// GroMore 初始化配置
class GromoreConfig {
  /// 构建初始化配置
  ///
  /// [androidAppId] Android AppId
  /// [androidAppName] Android AppName
  /// [iosAppId] iOS AppId
  /// [iosAppName] iOS AppName
  /// [debug] 是否 Debug 模式
  /// [useMediation] 是否启用聚合
  /// [enabledAdTypes] 启用的广告类型集合
  /// [androidOptions] Android 平台扩展参数
  /// [iosOptions] iOS 平台扩展参数
  /// [enableLog] 是否启用日志（不传则 Debug 默认开、Release 默认关）
  const GromoreConfig({
    this.androidAppId,
    this.androidAppName,
    this.iosAppId,
    this.iosAppName,
    this.debug = false,
    this.useMediation = true,
    this.enabledAdTypes = const <GromoreAdType>{
      GromoreAdType.splash,
      GromoreAdType.interstitial,
      GromoreAdType.fullscreenVideo,
      GromoreAdType.rewardVideo,
      GromoreAdType.native,
      GromoreAdType.drawNative,
      GromoreAdType.banner,
    },
    this.androidOptions,
    this.iosOptions,
    this.enableLog,
  });

  /// Android AppId
  final String? androidAppId;

  /// Android AppName
  final String? androidAppName;

  /// iOS AppId
  final String? iosAppId;

  /// iOS AppName
  final String? iosAppName;

  /// 是否 Debug 模式
  final bool debug;

  /// 是否启用聚合
  final bool useMediation;

  /// 启用的广告类型集合
  final Set<GromoreAdType> enabledAdTypes;

  /// Android 平台扩展参数
  final Map<String, dynamic>? androidOptions;

  /// iOS 平台扩展参数
  final Map<String, dynamic>? iosOptions;

  /// 是否启用日志（不传则 Debug 默认开、Release 默认关）
  final bool? enableLog;

  /// 转为通道传输 Map
  Map<String, dynamic> toMap() {
    return {
      'androidAppId': androidAppId,
      'androidAppName': androidAppName,
      'iosAppId': iosAppId,
      'iosAppName': iosAppName,
      'debug': debug,
      'useMediation': useMediation,
      'enabledAdTypes': enabledAdTypes.map((type) => type.value).toList(),
      'androidOptions': androidOptions,
      'iosOptions': iosOptions,
      'enableLog': enableLog,
    };
  }
}
