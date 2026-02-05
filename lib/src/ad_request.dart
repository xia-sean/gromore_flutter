/// 广告请求参数
class GromoreAdRequest {
  /// 构建广告请求
  ///
  /// [placementId] 代码位/PlacementId
  /// [extra] 通用扩展参数
  /// [params] 顶层请求参数（会合并进请求 Map 顶层）
  /// [androidOptions] Android 平台扩展参数
  /// [iosOptions] iOS 平台扩展参数
  const GromoreAdRequest({
    required this.placementId,
    this.params,
    this.extra,
    this.androidOptions,
    this.iosOptions,
  });

  /// 代码位/PlacementId
  final String placementId;

  /// 通用扩展参数
  final Map<String, dynamic>? extra;

  /// 顶层请求参数（会合并进请求 Map 顶层）
  final Map<String, dynamic>? params;

  /// Android 平台扩展参数
  final Map<String, dynamic>? androidOptions;

  /// iOS 平台扩展参数
  final Map<String, dynamic>? iosOptions;

  /// 转为通道传输 Map
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'placementId': placementId,
      'extra': extra,
      'androidOptions': androidOptions,
      'iosOptions': iosOptions,
    };
    final Map<String, dynamic> mergedParams = {};
    if (params != null) {
      mergedParams.addAll(params!);
    }
    if (extra != null) {
      mergedParams.addAll(extra!);
    }
    for (final entry in mergedParams.entries) {
      if (!map.containsKey(entry.key)) {
        map[entry.key] = entry.value;
      }
    }
    return map;
  }
}
