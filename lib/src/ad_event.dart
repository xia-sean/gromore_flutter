import 'ad_types.dart';

/// 广告事件类型枚举
enum GromoreAdEventType {
  /// 加载成功
  loaded,

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
}

/// 广告事件类型值转换
extension GromoreAdEventTypeValue on GromoreAdEventType {
  /// 获取用于通道传输的字符串值
  String get value {
    switch (this) {
      case GromoreAdEventType.loaded:
        return 'loaded';
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
      case 'loaded':
      case 'onAdLoaded':
        return GromoreAdEventType.loaded;
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
        adType: GromoreAdTypeValue.fromValue(adTypeValue) ?? GromoreAdType.native,
        eventType: eventType,
      );
    }

    if (eventType == GromoreAdEventType.failed ||
        eventType == GromoreAdEventType.error ||
        errorCode != null ||
        errorMessage != null) {
      return GromoreAdErrorEvent(
        adId: map['adId']?.toString() ?? '',
        adType: GromoreAdTypeValue.fromValue(adTypeValue) ?? GromoreAdType.native,
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

  /// 自定义数据
  final String? customData;

  /// 用户 ID
  final String? userId;

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
    final String? rewardName = map['rewardName']?.toString();
    final int? rewardAmount = _parseInt(map['rewardAmount']);
    final bool? rewardVerify = _parseBool(map['rewardVerify']) ??
        _parseBool(map['isRewardValid']);
    final int? rewardType = _parseInt(map['rewardType']);
    final String? rewardId = map['rewardId']?.toString();
    final String? customData = map['customData']?.toString();
    final String? userId = map['userId']?.toString();
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
    );
  }

  /// 从普通事件构建奖励事件
  factory GromoreAdRewardEvent.fromEvent(GromoreAdEvent event) {
    if (event is GromoreAdRewardEvent) {
      return event;
    }
    return GromoreAdRewardEvent(
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
