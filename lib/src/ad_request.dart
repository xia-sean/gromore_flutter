/// 广告请求参数
class GromoreAdRequest {
  /// 构建广告请求。一般使用各广告类型的 Config 即可。
  const GromoreAdRequest({
    required this.placementId,
    this.params,
    this.extra,
    this.androidExtra,
    this.iosExtra,
  });

  /// 代码位/PlacementId
  final String placementId;

  /// 两端共用的广告参数，只支持插件已定义的键，不会整体发给服务器。
  /// 激励回调的业务数据用 {'customData': '{"orderId":"123"}'} 传入。
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
    final Map<String, dynamic> map = {
      'placementId': placementId,
      'extra': extra,
      'androidExtra': androidExtra,
      'iosExtra': iosExtra,
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
