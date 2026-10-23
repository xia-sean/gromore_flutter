import 'dart:convert';

/// 广告请求 width/height 的单位，不影响 Flutter View 的逻辑像素尺寸。
enum GromoreAdSizeUnit {
  /// Flutter 逻辑像素；Android 由插件转换为物理 px，iOS 对应 pt。
  logicalPixels,

  /// 原生 SDK 单位：Android 物理 px，iOS pt，用于兼容已有请求。
  nativePixels,
}

/// 广告请求参数
class GromoreAdRequest {
  /// 构建广告请求。一般使用各广告类型的 Config 即可。
  const GromoreAdRequest({
    required this.placementId,
    this.params,
    this.extra,
    this.androidExtra,
    this.iosExtra,
    this.sizeUnit = GromoreAdSizeUnit.nativePixels,
  });

  /// width/height 的单位。底层请求默认保留原生单位以兼容旧调用；
  /// 各广告 Config 默认使用 logicalPixels，无需手动乘 devicePixelRatio。
  final GromoreAdSizeUnit sizeUnit;

  /// 代码位/PlacementId
  final String placementId;

  /// 两端共用的广告参数，只支持插件已定义的键，不会整体发给服务器。
  /// 激励回调的业务数据用 {'customData': {'orderId': '123'}} 传入。
  /// customData 支持 Map 和 String；Map 在发送到原生前转为 JSON 字符串。
  /// 与 [params] 重名时，此处的值优先。
  final Map<String, dynamic>? extra;

  /// 广告参数，由各广告类型的 Config 自动填写。
  final Map<String, dynamic>? params;

  /// 只给 Android 使用的广告参数，不覆盖 [params] 或 [extra] 的同名值。
  final Map<String, dynamic>? androidExtra;

  /// 只给 iOS 使用的广告参数，不覆盖 [params] 或 [extra] 的同名值。
  final Map<String, dynamic>? iosExtra;

  /// 转为通道传输 Map
  Map<String, dynamic> toMap() {
    if (placementId.trim().isEmpty) {
      throw ArgumentError.value(placementId, 'placementId', '不能为空');
    }
    final Map<String, dynamic> map = {
      'placementId': placementId,
      'sizeUnit': sizeUnit == GromoreAdSizeUnit.logicalPixels
          ? 'logicalPixels'
          : 'nativePixels',
      'extra': _normalizeOptions(extra),
      'androidExtra': _normalizeOptions(androidExtra),
      'iosExtra': _normalizeOptions(iosExtra),
    };
    final Map<String, dynamic> mergedParams = {};
    if (params != null) {
      mergedParams.addAll(params!);
    }
    if (extra != null) {
      mergedParams.addAll(extra!);
    }
    for (final entry in _normalizeOptions(mergedParams)!.entries) {
      if (!map.containsKey(entry.key)) {
        map[entry.key] = entry.value;
      }
    }
    _validate(map, map['androidExtra'] as Map?);
    _validate(map, map['iosExtra'] as Map?);
    return map;
  }

  // 与原生读取优先级一致，校验最终值，不拒绝已被覆盖的旧值。
  static void _validate(Map map, Map? platform) {
    final extra = map['extra'] as Map?;
    dynamic value(String key) => map[key] ?? platform?[key] ?? extra?[key];
    void number(String key,
        {double? min,
        double? max,
        bool integer = false,
        bool positive = false}) {
      final raw = value(key);
      if (raw == null) return;
      final parsed = raw is num ? raw.toDouble() : double.tryParse('$raw');
      if (parsed == null ||
          !parsed.isFinite ||
          (positive && parsed <= 0) ||
          (min != null && parsed < min) ||
          (max != null && parsed > max) ||
          (integer && raw is String && int.tryParse(raw) == null) ||
          (integer && parsed != parsed.truncateToDouble())) {
        throw ArgumentError.value(
            raw,
            key,
            '请填写有效数值'
            '${positive ? '，且大于 0' : ''}${min != null ? '，最小 $min' : ''}'
            '${max != null ? '，最大 $max' : ''}${integer ? '，必须为整数' : ''}');
      }
    }

    number('width', positive: true);
    number('height', positive: true);
    number('splashTimeout', positive: true, integer: true);
    number('logoHeight', positive: true, integer: true);
    number('adCount', min: 1, max: 3, integer: true);
    number('orientation', min: 1, max: 2, integer: true);
    number('rewardAmount', min: 0, integer: true);
    number('volume', min: 0, max: 1);
    final fullscreenReward = value('fullscreenReward');
    if (fullscreenReward != null) {
      if (fullscreenReward is! Map) {
        throw ArgumentError.value(
            fullscreenReward, 'fullscreenReward', '必须为 Map');
      }
      _validate(fullscreenReward, null);
    }
  }

  // 统一在通道边界转换，两端 SDK 均收到 String，并且不修改调用者的 Map。
  static Map<String, dynamic>? _normalizeOptions(Map<String, dynamic>? values) {
    if (values == null) return null;
    final result = Map<String, dynamic>.from(values);
    final customData = result['customData'];
    if (customData is Map) {
      result['customData'] = jsonEncode(customData);
    } else if (customData != null && customData is! String) {
      throw ArgumentError.value(
          customData, 'customData', 'Expected a Map or String');
    }
    // iOS 全屏 GDT 的奖励模型也使用相同的 customData 约定。
    final fullscreenReward = result['fullscreenReward'];
    if (fullscreenReward is Map) {
      result['fullscreenReward'] =
          _normalizeOptions(Map<String, dynamic>.from(fullscreenReward));
    }
    return result;
  }
}
