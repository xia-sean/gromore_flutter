import 'ad_request.dart';

/// 广告配置基类
abstract class GromoreAdConfig {
  const GromoreAdConfig({
    required this.placementId,
    this.extra,
    this.androidOptions,
    this.iosOptions,
  });

  /// 代码位/PlacementId
  final String placementId;

  /// 通用扩展参数
  final Map<String, dynamic>? extra;

  /// Android 平台扩展参数
  final Map<String, dynamic>? androidOptions;

  /// iOS 平台扩展参数
  final Map<String, dynamic>? iosOptions;

  /// 构建顶层请求参数
  Map<String, dynamic> buildParams();

  /// 转为统一请求
  GromoreAdRequest toRequest() {
    return GromoreAdRequest(
      placementId: placementId,
      params: buildParams(),
      extra: extra,
      androidOptions: androidOptions,
      iosOptions: iosOptions,
    );
  }
}

/// 开屏广告配置
class GromoreSplashConfig extends GromoreAdConfig {
  const GromoreSplashConfig({
    required String placementId,
    this.width,
    this.height,
    this.timeoutMillis,
    this.logo,
    Map<String, dynamic>? extra,
    Map<String, dynamic>? androidOptions,
    Map<String, dynamic>? iosOptions,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidOptions: androidOptions,
          iosOptions: iosOptions,
        );

  /// 广告宽度
  final int? width;

  /// 广告高度
  final int? height;

  /// 加载超时时间（毫秒）
  final int? timeoutMillis;

  /// 底部 logo（仅部分平台可用）
  final String? logo;

  @override
  Map<String, dynamic> buildParams() {
    final Map<String, dynamic> params = {};
    if (width != null) params['width'] = width;
    if (height != null) params['height'] = height;
    if (timeoutMillis != null) params['splashTimeout'] = timeoutMillis;
    if (logo != null) params['logo'] = logo;
    return params;
  }
}

/// 激励视频广告配置
class GromoreRewardConfig extends GromoreAdConfig {
  const GromoreRewardConfig({
    required String placementId,
    this.orientation,
    this.muted,
    this.scenarioId,
    this.userId,
    this.rewardName,
    this.rewardAmount,
    this.customData,
    Map<String, dynamic>? extra,
    Map<String, dynamic>? androidOptions,
    Map<String, dynamic>? iosOptions,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidOptions: androidOptions,
          iosOptions: iosOptions,
        );

  /// 播放方向（竖屏=1，横屏=2，仅 Android）
  final int? orientation;

  /// 是否静音（iOS 可用）
  final bool? muted;

  /// 场景 ID（iOS 可用）
  final String? scenarioId;

  /// 用户 ID（iOS 可用）
  final String? userId;

  /// 奖励名称（iOS 可用）
  final String? rewardName;

  /// 奖励数量（iOS 可用）
  final int? rewardAmount;

  /// 服务端验证自定义数据
  final String? customData;

  @override
  Map<String, dynamic> buildParams() {
    final Map<String, dynamic> params = {};
    if (orientation != null) params['orientation'] = orientation;
    if (muted != null) params['muted'] = muted;
    if (scenarioId != null) params['scenarioId'] = scenarioId;
    if (userId != null) params['userId'] = userId;
    if (rewardName != null) params['rewardName'] = rewardName;
    if (rewardAmount != null) params['rewardAmount'] = rewardAmount;
    if (customData != null) params['customData'] = customData;
    return params;
  }
}

/// 插屏广告配置
class GromoreInterstitialConfig extends GromoreAdConfig {
  const GromoreInterstitialConfig({
    required String placementId,
    this.orientation,
    this.muted,
    Map<String, dynamic>? extra,
    Map<String, dynamic>? androidOptions,
    Map<String, dynamic>? iosOptions,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidOptions: androidOptions,
          iosOptions: iosOptions,
        );

  /// 播放方向（竖屏=1，横屏=2，仅 Android）
  final int? orientation;

  /// 是否静音（iOS 可用）
  final bool? muted;

  @override
  Map<String, dynamic> buildParams() {
    final Map<String, dynamic> params = {};
    if (orientation != null) params['orientation'] = orientation;
    if (muted != null) params['muted'] = muted;
    return params;
  }
}

/// 全屏视频广告配置
class GromoreFullscreenVideoConfig extends GromoreAdConfig {
  const GromoreFullscreenVideoConfig({
    required String placementId,
    this.orientation,
    this.muted,
    Map<String, dynamic>? extra,
    Map<String, dynamic>? androidOptions,
    Map<String, dynamic>? iosOptions,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidOptions: androidOptions,
          iosOptions: iosOptions,
        );

  /// 播放方向（竖屏=1，横屏=2，仅 Android）
  final int? orientation;

  /// 是否静音（iOS 可用）
  final bool? muted;

  @override
  Map<String, dynamic> buildParams() {
    final Map<String, dynamic> params = {};
    if (orientation != null) params['orientation'] = orientation;
    if (muted != null) params['muted'] = muted;
    return params;
  }
}

/// Banner 广告配置
class GromoreBannerConfig extends GromoreAdConfig {
  const GromoreBannerConfig({
    required String placementId,
    this.width,
    this.height,
    this.muted,
    Map<String, dynamic>? extra,
    Map<String, dynamic>? androidOptions,
    Map<String, dynamic>? iosOptions,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidOptions: androidOptions,
          iosOptions: iosOptions,
        );

  /// 广告宽度
  final int? width;

  /// 广告高度
  final int? height;

  /// 是否静音（iOS 可用）
  final bool? muted;

  @override
  Map<String, dynamic> buildParams() {
    final Map<String, dynamic> params = {};
    if (width != null) params['width'] = width;
    if (height != null) params['height'] = height;
    if (muted != null) params['muted'] = muted;
    return params;
  }
}

/// 信息流广告配置
class GromoreFeedConfig extends GromoreAdConfig {
  const GromoreFeedConfig({
    required String placementId,
    this.width,
    this.height,
    this.adCount,
    this.muted,
    Map<String, dynamic>? extra,
    Map<String, dynamic>? androidOptions,
    Map<String, dynamic>? iosOptions,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidOptions: androidOptions,
          iosOptions: iosOptions,
        );

  /// 广告宽度
  final int? width;

  /// 广告高度
  final int? height;

  /// 请求数量
  final int? adCount;

  /// 是否静音（iOS 可用）
  final bool? muted;

  @override
  Map<String, dynamic> buildParams() {
    final Map<String, dynamic> params = {};
    if (width != null) params['width'] = width;
    if (height != null) params['height'] = height;
    if (adCount != null) params['adCount'] = adCount;
    if (muted != null) params['muted'] = muted;
    return params;
  }
}

/// Draw 信息流广告配置
class GromoreDrawConfig extends GromoreAdConfig {
  const GromoreDrawConfig({
    required String placementId,
    this.width,
    this.height,
    this.adCount,
    this.muted,
    Map<String, dynamic>? extra,
    Map<String, dynamic>? androidOptions,
    Map<String, dynamic>? iosOptions,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidOptions: androidOptions,
          iosOptions: iosOptions,
        );

  /// 广告宽度
  final int? width;

  /// 广告高度
  final int? height;

  /// 请求数量
  final int? adCount;

  /// 是否静音（iOS 可用）
  final bool? muted;

  @override
  Map<String, dynamic> buildParams() {
    final Map<String, dynamic> params = {};
    if (width != null) params['width'] = width;
    if (height != null) params['height'] = height;
    if (adCount != null) params['adCount'] = adCount;
    if (muted != null) params['muted'] = muted;
    return params;
  }
}
