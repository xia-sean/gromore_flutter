import 'ad_request.dart';

/// 广告配置，优先使用各广告类型提供的字段。
abstract class GromoreAdConfig {
  const GromoreAdConfig({
    required this.placementId,
    this.extra,
    this.androidExtra,
    this.iosExtra,
  });

  /// 广告位 ID。
  final String placementId;

  /// 两端共用的广告参数，只支持插件已定义的键，不会整体发给服务器。
  /// 激励回调要传订单号等业务数据，请使用 [GromoreRewardConfig.customData]。
  final Map<String, dynamic>? extra;

  /// 只给 Android 使用的广告参数，例如 {'muted': true}。
  /// 与普通字段或 [extra] 重名时，不覆盖它们。
  final Map<String, dynamic>? androidExtra;

  /// 只给 iOS 使用的广告参数，例如 {'muted': true}。
  /// 与普通字段或 [extra] 重名时，不覆盖它们。
  final Map<String, dynamic>? iosExtra;

  /// 构建广告参数。
  Map<String, dynamic> buildParams();

  /// 转为广告请求。
  GromoreAdRequest toRequest() {
    return GromoreAdRequest(
      placementId: placementId,
      params: buildParams(),
      extra: extra,
      androidExtra: androidExtra,
      iosExtra: iosExtra,
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
    Map<String, dynamic>? androidExtra,
    Map<String, dynamic>? iosExtra,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
        );

  /// 广告宽度
  final int? width;

  /// 广告高度
  final int? height;

  /// 加载超时时间（毫秒）
  final int? timeoutMillis;

  /// 预留字段，当前 Android/iOS 均未实现；传入时原生端会输出警告。
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
    Map<String, dynamic>? androidExtra,
    Map<String, dynamic>? iosExtra,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
        );

  /// 播放方向（竖屏=1，横屏=2，仅 Android）
  final int? orientation;

  /// 是否静音，实际效果取决于广告来源 SDK 是否支持。
  final bool? muted;

  /// GroMore 场景 ID。
  final String? scenarioId;

  /// 服务端激励回调中的用户 ID（Android/iOS）。
  final String? userId;

  /// 奖励名称（Android/iOS），实际奖励以平台配置和回调为准。
  final String? rewardName;

  /// 奖励数量（Android/iOS），实际奖励以平台配置和回调为准。
  final int? rewardAmount;

  /// 要让服务器收到的业务数据，回调字段名为 extra。
  /// 例如 customData: '{"orderId":"123"}'；Map 请先用 jsonEncode 转成字符串。
  /// 与上面的 [extra] 广告参数 Map 不同。
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
    Map<String, dynamic>? androidExtra,
    Map<String, dynamic>? iosExtra,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
        );

  /// 播放方向（竖屏=1，横屏=2，仅 Android）
  final int? orientation;

  /// 是否静音，实际效果取决于广告来源 SDK 是否支持。
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
    Map<String, dynamic>? androidExtra,
    Map<String, dynamic>? iosExtra,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
        );

  /// 播放方向（竖屏=1，横屏=2，仅 Android）
  final int? orientation;

  /// 是否静音，实际效果取决于广告来源 SDK 是否支持。
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
    Map<String, dynamic>? androidExtra,
    Map<String, dynamic>? iosExtra,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
        );

  /// 广告宽度
  final int? width;

  /// 广告高度
  final int? height;

  /// 是否静音，实际效果取决于广告来源 SDK 是否支持。
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
    Map<String, dynamic>? androidExtra,
    Map<String, dynamic>? iosExtra,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
        );

  /// 广告宽度
  final int? width;

  /// 广告高度
  final int? height;

  /// 请求数量
  final int? adCount;

  /// 是否静音，实际效果取决于广告来源 SDK 是否支持。
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
    Map<String, dynamic>? androidExtra,
    Map<String, dynamic>? iosExtra,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
        );

  /// 广告宽度
  final int? width;

  /// 广告高度
  final int? height;

  /// 请求数量
  final int? adCount;

  /// 是否静音，实际效果取决于广告来源 SDK 是否支持。
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
