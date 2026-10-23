import 'ad_types.dart';
import 'ad_info.dart';

/// 广告事件类型枚举
enum GromoreAdEventType {
  /// 加载成功
  loaded,

  /// 模板渲染完成（返回真实渲染尺寸）
  rendered,

  /// 加载失败
  failed,

  /// 广告错误（兼容 onAdError）
  error,

  /// 广告展示
  shown,

  /// 广告展示（present）
  presented,

  /// 广告曝光
  exposed,

  /// 广告点击
  clicked,

  /// 广告关闭
  closed,

  /// 广告跳过
  skipped,

  /// 广告播放完成
  completed,

  /// 激励触发
  rewarded,

  /// SDK 视频缓存完成，支持范围取决于平台及广告来源。
  cached,

  /// 用户选择不感兴趣，原因等信息保留在 data。
  dislike,

  /// Feed/Draw 视频状态变化；data.state 的类型和枚举取决于平台。
  videoStateChanged,

  /// Android 默认自渲染广告下载状态，data 含状态和可用进度。
  downloadChanged,

  /// iOS SDK 通知打开落地页/全屏内容。
  landingPageOpened,

  /// iOS SDK 通知关闭落地页/其他控制器。
  landingPageClosed,

  /// SDK 摇一摇交互通知。
  shake,

  /// iOS Feed/Draw 奖励倒计时，data.countDown 为 SDK 返回值。
  rewardCountdown,

  /// Android SDK 原始交互事件，data.code/parameters 保留原始信息。
  nativeEvent,

  /// 开屏卡片可展示；需保留广告实例后调用 showSplashCard。
  splashCardReady,
}

/// 广告事件类型值转换
extension GromoreAdEventTypeValue on GromoreAdEventType {
  /// 获取用于通道传输的字符串值
  String get value {
    switch (this) {
      case GromoreAdEventType.cached:
        return 'cached';
      case GromoreAdEventType.dislike:
        return 'dislike';
      case GromoreAdEventType.videoStateChanged:
        return 'videoStateChanged';
      case GromoreAdEventType.downloadChanged:
        return 'downloadChanged';
      case GromoreAdEventType.landingPageOpened:
        return 'landingPageOpened';
      case GromoreAdEventType.landingPageClosed:
        return 'landingPageClosed';
      case GromoreAdEventType.shake:
        return 'shake';
      case GromoreAdEventType.rewardCountdown:
        return 'rewardCountdown';
      case GromoreAdEventType.nativeEvent:
        return 'nativeEvent';
      case GromoreAdEventType.splashCardReady:
        return 'splashCardReady';

      case GromoreAdEventType.loaded:
        return 'loaded';
      case GromoreAdEventType.rendered:
        return 'rendered';
      case GromoreAdEventType.failed:
        return 'failed';
      case GromoreAdEventType.error:
        return 'error';
      case GromoreAdEventType.shown:
        return 'shown';
      case GromoreAdEventType.presented:
        return 'presented';
      case GromoreAdEventType.exposed:
        return 'exposed';
      case GromoreAdEventType.clicked:
        return 'clicked';
      case GromoreAdEventType.closed:
        return 'closed';
      case GromoreAdEventType.skipped:
        return 'skipped';
      case GromoreAdEventType.completed:
        return 'completed';
      case GromoreAdEventType.rewarded:
        return 'rewarded';
    }
  }

  /// 从字符串值解析事件类型
  ///
  /// [value] 通道传输的字符串
  static GromoreAdEventType? fromValue(String? value) {
    switch (value) {
      case 'cached':
        return GromoreAdEventType.cached;
      case 'dislike':
        return GromoreAdEventType.dislike;
      case 'videoStateChanged':
        return GromoreAdEventType.videoStateChanged;
      case 'downloadChanged':
        return GromoreAdEventType.downloadChanged;
      case 'landingPageOpened':
        return GromoreAdEventType.landingPageOpened;
      case 'landingPageClosed':
        return GromoreAdEventType.landingPageClosed;
      case 'shake':
        return GromoreAdEventType.shake;
      case 'rewardCountdown':
        return GromoreAdEventType.rewardCountdown;
      case 'nativeEvent':
        return GromoreAdEventType.nativeEvent;
      case 'splashCardReady':
        return GromoreAdEventType.splashCardReady;

      case 'loaded':
      case 'onAdLoaded':
        return GromoreAdEventType.loaded;
      case 'rendered':
      case 'onAdRendered':
        return GromoreAdEventType.rendered;
      case 'failed':
        return GromoreAdEventType.failed;
      case 'error':
      case 'onAdError':
        return GromoreAdEventType.error;
      case 'shown':
        return GromoreAdEventType.shown;
      case 'onAdPresent':
      case 'presented':
        return GromoreAdEventType.presented;
      case 'onAdExposure':
      case 'exposed':
        return GromoreAdEventType.exposed;
      case 'clicked':
      case 'onAdClicked':
        return GromoreAdEventType.clicked;
      case 'closed':
      case 'onAdClosed':
        return GromoreAdEventType.closed;
      case 'onAdSkip':
      case 'skipped':
        return GromoreAdEventType.skipped;
      case 'onAdComplete':
      case 'completed':
        return GromoreAdEventType.completed;
      case 'rewarded':
      case 'onAdReward':
        return GromoreAdEventType.rewarded;
      default:
        return null;
    }
  }
}

/// 广告事件实体
class GromoreAdEvent {
  /// 构建广告事件
  ///
  /// [adId] 广告实例 ID
  /// [adType] 广告类型
  /// [eventType] 事件类型
  /// [placementId] 代码位（可选）
  /// [errorCode] 错误码（可选）
  /// [errorMessage] 错误信息（可选）
  /// [data] 额外数据（可选）
  GromoreAdEvent({
    required this.adId,
    required this.adType,
    required this.eventType,
    this.placementId,
    this.errorCode,
    this.errorMessage,
    this.data,
  });

  /// 广告实例 ID
  final String adId;

  /// 广告类型
  final GromoreAdType adType;

  /// 事件类型
  final GromoreAdEventType eventType;

  /// 代码位（可选）
  final String? placementId;

  /// 错误码（可选）
  final String? errorCode;

  /// 错误信息（可选）
  final String? errorMessage;

  /// 额外数据（可选）
  final Map<String, dynamic>? data;

  /// 此次事件携带的 eCPM 信息；SDK 未提供时为 null。
  GromoreEcpmInfo? get ecpmInfo => data?['ecpmInfo'] is Map
      ? GromoreEcpmInfo(data!['ecpmInfo'] as Map)
      : null;

  /// 从通道 Map 解析为事件对象
  ///
  /// [map] 通道回传的事件数据
  static GromoreAdEvent fromMap(Map<dynamic, dynamic> map) {
    final String adTypeValue = map['adType']?.toString() ?? '';
    final String eventValue =
        map['eventType']?.toString() ?? map['action']?.toString() ?? '';
    final GromoreAdEventType eventType =
        GromoreAdEventTypeValue.fromValue(eventValue) ??
            GromoreAdEventType.failed;
    final String? errorCode =
        map['errorCode']?.toString() ?? map['errCode']?.toString();
    final String? errorMessage =
        map['errorMessage']?.toString() ?? map['errMsg']?.toString();
    final bool hasRewardFields = map.containsKey('rewardVerify') ||
        map.containsKey('rewardAmount') ||
        map.containsKey('rewardName') ||
        map.containsKey('rewardId') ||
        map.containsKey('isRewardValid') ||
        map.containsKey('rewardType');

    if (eventType == GromoreAdEventType.rewarded || hasRewardFields) {
      return GromoreAdRewardEvent.fromMap(
        map,
        adType:
            GromoreAdTypeValue.fromValue(adTypeValue) ?? GromoreAdType.native,
        eventType: eventType,
      );
    }

    if (eventType == GromoreAdEventType.failed ||
        eventType == GromoreAdEventType.error ||
        errorCode != null ||
        errorMessage != null) {
      return GromoreAdErrorEvent(
        adId: map['adId']?.toString() ?? '',
        adType:
            GromoreAdTypeValue.fromValue(adTypeValue) ?? GromoreAdType.native,
        eventType: eventType,
        placementId: map['placementId']?.toString(),
        errorCode: errorCode,
        errorMessage: errorMessage,
        data: (map['data'] as Map?)?.cast<String, dynamic>(),
      );
    }

    return GromoreAdEvent(
      adId: map['adId']?.toString() ?? '',
      adType: GromoreAdTypeValue.fromValue(adTypeValue) ?? GromoreAdType.native,
      eventType: eventType,
      placementId: map['placementId']?.toString(),
      errorCode: errorCode,
      errorMessage: errorMessage,
      data: (map['data'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

/// 广告错误事件
class GromoreAdErrorEvent extends GromoreAdEvent {
  /// 构建广告错误事件
  GromoreAdErrorEvent({
    required String adId,
    required GromoreAdType adType,
    required GromoreAdEventType eventType,
    String? placementId,
    String? errorCode,
    String? errorMessage,
    Map<String, dynamic>? data,
  }) : super(
          adId: adId,
          adType: adType,
          eventType: eventType,
          placementId: placementId,
          errorCode: errorCode,
          errorMessage: errorMessage,
          data: data,
        );

  /// 错误阶段（如 load/show）；旧回调或 SDK 未提供时为 null。
  String? get phase => data?['phase']?.toString();

  /// 解析错误码为 int
  int? get errorCodeInt => int.tryParse(errorCode ?? '');

  /// 从普通事件构建错误事件
  factory GromoreAdErrorEvent.fromEvent(GromoreAdEvent event) {
    return GromoreAdErrorEvent(
      adId: event.adId,
      adType: event.adType,
      eventType: event.eventType,
      placementId: event.placementId,
      errorCode: event.errorCode,
      errorMessage: event.errorMessage,
      data: event.data,
    );
  }
}

/// 广告激励事件
class GromoreAdRewardEvent extends GromoreAdEvent {
  /// 奖励是否有效
  final bool? rewardVerify;

  /// 奖励数量
  final int? rewardAmount;

  /// 奖励名称
  final String? rewardName;

  /// 奖励 ID
  final String? rewardId;

  /// 奖励类型
  final int? rewardType;

  /// SDK 在客户端回调中返回的自定义字符串，未返回时为 null。
  /// 请求传 Map 时自动编码为 JSON；客户端是否回传由广告来源决定。
  final String? customData;

  /// 用户 ID
  final String? userId;

  /// SDK 奖励交易 ID，缺失时为 null；实际发奖仍需服务端验签和去重。
  final String? tradeId;

  /// 提供奖励回调的广告来源名称，SDK 未提供时为 null。
  final String? adnName;

  /// SDK 是否标记为 GroMore 服务端验证通道；未提供时为 null。
  /// 该客户端字段不能替代服务器对回调的验证。
  final bool? verifyByGroMoreS2S;

  /// 构建奖励事件
  GromoreAdRewardEvent({
    required String adId,
    required GromoreAdType adType,
    required GromoreAdEventType eventType,
    String? placementId,
    String? errorCode,
    String? errorMessage,
    Map<String, dynamic>? data,
    this.rewardVerify,
    this.rewardAmount,
    this.rewardName,
    this.rewardId,
    this.rewardType,
    this.customData,
    this.userId,
    this.tradeId,
    this.adnName,
    this.verifyByGroMoreS2S,
  }) : super(
          adId: adId,
          adType: adType,
          eventType: eventType,
          placementId: placementId,
          errorCode: errorCode,
          errorMessage: errorMessage,
          data: data,
        );

  /// 从 Map 解析奖励事件
  factory GromoreAdRewardEvent.fromMap(
    Map<dynamic, dynamic> map, {
    required GromoreAdType adType,
    required GromoreAdEventType eventType,
  }) {
    final data = map['data'] as Map?;
    final fields = <dynamic, dynamic>{
      ...?data?['extraInfo'] as Map?,
      ...?data,
      ...map,
    };
    dynamic field(List<String> keys) {
      for (final key in keys) {
        if (fields[key] != null) return fields[key];
      }
      return null;
    }

    final rewardName = field(['rewardName', 'reward_name'])?.toString();
    final rewardAmount = _parseInt(field(['rewardAmount', 'reward_amount']));
    final rewardVerify = _parseBool(field([
      'rewardVerify',
      'isRewardValid',
      'verify',
      'reward_valid',
      'reward_verify'
    ]));
    final rewardType = _parseInt(field(['rewardType', 'reward_type']));
    final rewardId = field(['rewardId', 'reward_id'])?.toString();
    final customData =
        field(['customData', 'extra', 'reward_custom_data'])?.toString();
    final userId = field(['userId', 'user_id'])?.toString();
    return GromoreAdRewardEvent(
      adId: map['adId']?.toString() ?? '',
      adType: adType,
      eventType: eventType,
      placementId: map['placementId']?.toString(),
      errorCode: map['errorCode']?.toString() ?? map['errCode']?.toString(),
      errorMessage:
          map['errorMessage']?.toString() ?? map['errMsg']?.toString(),
      data: (map['data'] as Map?)?.cast<String, dynamic>(),
      rewardVerify: rewardVerify,
      rewardAmount: rewardAmount,
      rewardName: rewardName,
      rewardId: rewardId,
      rewardType: rewardType,
      customData: customData,
      userId: userId,
      tradeId:
          field(['tradeId', 'transId', 'trans_id', 'trade_id'])?.toString(),
      adnName: field(['adnName', 'adn_name'])?.toString(),
      verifyByGroMoreS2S: _parseBool(
          field(['verifyByGroMoreS2S', 'isGroMoreServerSideVerify'])),
    );
  }

  /// 从普通事件构建奖励事件
  factory GromoreAdRewardEvent.fromEvent(GromoreAdEvent event) {
    if (event is GromoreAdRewardEvent) {
      return event;
    }
    return GromoreAdRewardEvent.fromMap({
      'adId': event.adId,
      'placementId': event.placementId,
      'errorCode': event.errorCode,
      'errorMessage': event.errorMessage,
      'data': event.data,
    }, adType: event.adType, eventType: event.eventType);
  }
}

int? _parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

bool? _parseBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final String text = value.toString().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return null;
}
