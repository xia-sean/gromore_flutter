import 'ad_request.dart';

/// 广告请求的 SDK 扩展选项，不是 SDK 初始化配置。
///
/// 未传字段沿用 SDK 默认行为；平台专属字段仅在对应平台生效。
/// 通过各广告 Config 的 options 传入，普通 Config 同名字段优先。
class GromoreRequestOptions {
  /// 构建可选的 SDK 请求参数；具体效果取决于广告类型和广告来源。
  const GromoreRequestOptions(
      {this.sizeUnit = GromoreAdSizeUnit.logicalPixels,
      this.scenarioId,
      this.volume,
      this.useSurfaceView,
      this.bidNotify,
      this.wxAppId,
      this.extraObjects,
      this.addParams,
      this.rewardVerification,
      this.fullscreenReward,
      this.nativeRenderFactoryId,
      this.logoHeight,
      this.splashShakeButton,
      this.splashPreLoad,
      this.allowShowCloseBtn,
      this.supportCardView});

  /// Config 的 width/height 默认使用 Flutter 逻辑像素，插件内部转换。
  /// 已自行转换尺寸的旧代码可指定 nativePixels，避免 Android 重复缩放。
  /// 不影响 logoHeight 等 SDK 扩展字段的单位。
  final GromoreAdSizeUnit sizeUnit;

  /// GroMore 场景 ID，Android/iOS 均支持。
  final String? scenarioId;

  /// Android 播放音量，范围 0~1；无效值在调用原生前报错。
  final double? volume;

  /// Android 是否使用 SurfaceView，由广告来源决定是否支持。
  final bool? useSurfaceView;

  /// 是否让 SDK 向广告来源发送竞价结果通知（Android/iOS）。
  /// 不会因此产生业务侧竞价结果回调。
  final bool? bidNotify;

  /// Android 微信跳转所需 AppId；需同时完成宿主及广告来源配置。
  final String? wxAppId;

  /// Android MediationAdSlot.setExtraObject，使用 SDK 定义的键。
  final Map<String, dynamic>? extraObjects;

  /// iOS mediation.addParam，使用 SDK/ADN 定义的键。
  final Map<String, dynamic>? addParams;

  /// Android ADN 奖励通道，键为 pangle / gdt / baidu，值遵循各 ADN 约定。
  final Map<String, dynamic>? rewardVerification;

  /// iOS 全屏 GDT 奖励模型：userId/rewardName/rewardAmount/customData。
  /// customData 支持 Map/String；不表示所有全屏广告都有 GroMore 奖励回调。
  final Map<String, dynamic>? fullscreenReward;

  /// 宿主原生渲染工厂 ID，用于自渲染 Feed、Draw 或 Banner。
  /// 需在对应平台主线程预先注册；未注册时加载报 factory_not_found。
  /// 模板广告仍由 SDK 渲染，不会调用此工厂。
  final String? nativeRenderFactoryId;

  /// 品牌区高度，单位 Android px / iOS pt，默认 80。
  final int? logoHeight;

  /// Android 开屏摇一摇按钮开关，效果由 SDK/广告来源决定。
  final bool? splashShakeButton;

  /// Android 开屏请求的预加载标记，不等同于批量 preloadAds。
  final bool? splashPreLoad;

  /// Android 开屏是否允许显示关闭按钮，效果由 SDK/广告来源决定。
  final bool? allowShowCloseBtn;

  /// iOS 开屏是否启用卡片支持；收到 splashCardReady 后再请求展示。
  final bool? supportCardView;

  /// 转为广告请求参数；customData 的 Map 在请求发送前统一序列化。
  Map<String, dynamic> toMap() => {
        if (supportCardView != null) 'supportCardView': supportCardView,
        if (scenarioId != null) 'scenarioId': scenarioId,
        if (volume != null) 'volume': volume,
        if (useSurfaceView != null) 'useSurfaceView': useSurfaceView,
        if (bidNotify != null) 'bidNotify': bidNotify,
        if (wxAppId != null) 'wxAppId': wxAppId,
        if (extraObjects != null) 'extraObjects': extraObjects,
        if (addParams != null) 'addParams': addParams,
        if (rewardVerification != null)
          'rewardVerification': rewardVerification,
        if (fullscreenReward != null) 'fullscreenReward': fullscreenReward,
        if (nativeRenderFactoryId != null)
          'nativeRenderFactoryId': nativeRenderFactoryId,
        if (logoHeight != null) 'logoHeight': logoHeight,
        if (splashShakeButton != null) 'splashShakeButton': splashShakeButton,
        if (splashPreLoad != null) 'splashPreLoad': splashPreLoad,
        if (allowShowCloseBtn != null) 'allowShowCloseBtn': allowShowCloseBtn,
      };
}

/// 广告配置，优先使用各广告类型提供的字段。
abstract class GromoreAdConfig {
  const GromoreAdConfig({
    required this.placementId,
    this.extra,
    this.androidExtra,
    this.iosExtra,
    this.options,
  });

  /// 可选的 SDK 请求扩展参数，不影响 initialize/init 的初始化配置。
  final GromoreRequestOptions? options;

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
      sizeUnit: options?.sizeUnit ?? GromoreAdSizeUnit.logicalPixels,
      params: {...?options?.toMap(), ...buildParams()},
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
    GromoreRequestOptions? options,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
          options: options,
        );

  /// 请求宽度，默认 Flutter 逻辑像素，可与 View.width 使用相同值。
  /// Android 由插件转换为物理 px；可通过 options.sizeUnit 兼容原生单位。
  final num? width;

  /// 请求高度，默认 Flutter 逻辑像素，可与 View.height 使用相同值。
  /// Android 由插件转换为物理 px；可通过 options.sizeUnit 兼容原生单位。
  final num? height;

  /// 加载超时时间（毫秒）
  final int? timeoutMillis;

  /// 本地品牌图片的绝对路径（两端），高度由 options.logoHeight 指定。
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
    GromoreRequestOptions? options,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
          options: options,
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
  /// 支持 Map 和 String；Map 自动转为 JSON 字符串，String 保持原样。
  /// Map 中的键和值必须能够被 JSON 序列化。
  /// 与上面的 [extra] 广告参数 Map 不同。
  final Object? customData;

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
    GromoreRequestOptions? options,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
          options: options,
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
    GromoreRequestOptions? options,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
          options: options,
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
    GromoreRequestOptions? options,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
          options: options,
        );

  /// 请求宽度，默认 Flutter 逻辑像素，可与 View.width 使用相同值。
  /// Android 由插件转换为物理 px；可通过 options.sizeUnit 兼容原生单位。
  final num? width;

  /// 请求高度，默认 Flutter 逻辑像素，可与 View.height 使用相同值。
  /// Android 由插件转换为物理 px；可通过 options.sizeUnit 兼容原生单位。
  final num? height;

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
    GromoreRequestOptions? options,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
          options: options,
        );

  /// 请求宽度，默认 Flutter 逻辑像素，可与 View.width 使用相同值。
  /// Android 由插件转换为物理 px；可通过 options.sizeUnit 兼容原生单位。
  final num? width;

  /// 请求高度，默认 Flutter 逻辑像素，可与 View.height 使用相同值。
  /// Android 由插件转换为物理 px；可通过 options.sizeUnit 兼容原生单位。
  final num? height;

  /// 请求数量，范围 1~3；SDK 实际返回数量可能更少。
  /// 多条场景请通过 loadAll 获取全部实例并逐条销毁。
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
    GromoreRequestOptions? options,
  }) : super(
          placementId: placementId,
          extra: extra,
          androidExtra: androidExtra,
          iosExtra: iosExtra,
          options: options,
        );

  /// 请求宽度，默认 Flutter 逻辑像素，可与 View.width 使用相同值。
  /// Android 由插件转换为物理 px；可通过 options.sizeUnit 兼容原生单位。
  final num? width;

  /// 请求高度，默认 Flutter 逻辑像素，可与 View.height 使用相同值。
  /// Android 由插件转换为物理 px；可通过 options.sizeUnit 兼容原生单位。
  final num? height;

  /// 请求数量，范围 1~3；SDK 实际返回数量可能更少。
  /// 多条场景请通过 loadAll 获取全部实例并逐条销毁。
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
