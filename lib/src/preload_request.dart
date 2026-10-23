import 'ad_configs.dart';
import 'ad_types.dart';

/// 一条 SDK 批量预缓存配置，不产生可直接展示的 adId。
/// Android 自动从 config 推导广告类型；iOS 还需宿主注册预缓存工厂。
class GromorePreloadRequest {
  /// 使用广告 Config 构建一条预缓存请求；iOS 需另外指定宿主工厂 ID。
  const GromorePreloadRequest({
    required this.config,
    this.primeRitList = const [],
    this.iosFactoryId,
    this.iosFactoryParams = const {},
  });

  /// 广告配置，宽高、自定义数据与普通加载使用相同规则。
  final GromoreAdConfig config;

  /// Android SDK 约定的优先广告位列表，可省略。
  final List<String> primeRitList;

  /// iOS 宿主注册的 PreloadInfoFactory ID；iOS 必填。
  final String? iosFactoryId;

  /// iOS 工厂需要的业务参数，可从传入 item 的 factoryParams 中读取。
  final Map<String, dynamic> iosFactoryParams;

  /// 转为插件预缓存参数。工厂参数不能覆盖 adType/request 等公共字段。
  Map<String, dynamic> toMap() {
    if (iosFactoryId != null && iosFactoryId!.trim().isEmpty) {
      throw ArgumentError.value(iosFactoryId, 'iosFactoryId', '不能为空字符串');
    }
    if (primeRitList.any((id) => id.trim().isEmpty)) {
      throw ArgumentError.value(primeRitList, 'primeRitList', '广告位不能为空');
    }
    return {
      'adType': _type(config).value,
      'request': config.toRequest().toMap(),
      'primeRitList': List<String>.from(primeRitList),
      if (iosFactoryId != null) 'iosFactoryId': iosFactoryId,
      if (iosFactoryParams.isNotEmpty) 'factoryParams': iosFactoryParams,
    };
  }

  static GromoreAdType _type(GromoreAdConfig config) {
    if (config is GromoreSplashConfig) return GromoreAdType.splash;
    if (config is GromoreInterstitialConfig) return GromoreAdType.interstitial;
    if (config is GromoreFullscreenVideoConfig) {
      return GromoreAdType.fullscreenVideo;
    }
    if (config is GromoreRewardConfig) return GromoreAdType.rewardVideo;
    if (config is GromoreBannerConfig) return GromoreAdType.banner;
    if (config is GromoreFeedConfig) return GromoreAdType.native;
    if (config is GromoreDrawConfig) return GromoreAdType.drawNative;
    throw ArgumentError.value(config, 'config', '不支持的广告配置');
  }
}
