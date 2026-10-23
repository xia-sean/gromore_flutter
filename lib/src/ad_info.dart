/// SDK 返回的广告来源和 eCPM 信息。
///
/// 缺失字段返回 null，原始字段保留在 [raw]，不将受限收益值当成实际收益。
class GromoreEcpmInfo {
  /// 从原生通道字段创建只读快照，不修改传入 Map。
  GromoreEcpmInfo(Map<dynamic, dynamic> values)
      : raw = Map<String, dynamic>.unmodifiable(values.cast<String, dynamic>());

  /// 当前 SDK 桥接的全部字段；字段名和可用性随平台及广告来源而异。
  final Map<String, dynamic> raw;

  /// 广告来源 SDK 名称，SDK 未提供时为 null。
  String? get sdkName => raw['sdkName']?.toString();

  /// 广告来源侧代码位 ID，SDK 未提供时为 null。
  String? get slotId => raw['slotId']?.toString();

  /// SDK 请求 ID，SDK 未提供时为 null。
  String? get requestId => raw['requestId']?.toString();

  /// GroMore 场景 ID，SDK 未提供时为 null。
  String? get scenarioId => raw['scenarioId']?.toString();

  /// SDK 原始 eCPM 字符串；单位和访问权限遵循 SDK/平台约定。
  String? get ecpm => raw['ecpm']?.toString();

  /// 可解析的非负 eCPM 数值；缺失、负数权限标记或非有限值返回 null。
  double? get ecpmValue {
    final value = double.tryParse(ecpm ?? '');
    return value != null && value.isFinite && value >= 0 ? value : null;
  }
}

/// 广告实例当前状态的快照；状态查询不会触发加载或展示。
class GromoreAdState {
  /// 从原生 isReady/isLoading 字段创建快照。
  GromoreAdState(Map<dynamic, dynamic> values)
      : isReady = values['isReady'] == true,
        isLoading = values['isLoading'] == true;

  /// SDK 当前是否认为可展示，不保证后续 show 一定成功。
  final bool isReady;

  /// 是否加载中；Android 由插件回调追踪，iOS 读取 SDK 状态。
  final bool isLoading;
}

/// 各广告来源的加载诊断，以及当前最优、展示、竞价和缓存信息。
///
/// 字段可用性由平台、广告来源及权限决定，空值不表示收益为零。
class GromoreAdDiagnostics {
  /// 从原生诊断结果创建只读 Map 快照。
  GromoreAdDiagnostics(Map<dynamic, dynamic> values)
      : raw = Map<String, dynamic>.unmodifiable(values.cast<String, dynamic>());

  /// 当前 SDK 桥接的全部诊断字段，包括 iOS waterfallFillFailMessages。
  final Map<String, dynamic> raw;

  GromoreEcpmInfo? _info(String key) =>
      raw[key] is Map ? GromoreEcpmInfo(raw[key] as Map) : null;
  List<GromoreEcpmInfo>? _list(String key) => raw[key] is List
      ? (raw[key] as List)
          .whereType<Map>()
          .map((e) => GromoreEcpmInfo(e))
          .toList()
      : null;

  /// SDK 当前最优广告的 eCPM 信息；尚未返回或不可用时为 null。
  GromoreEcpmInfo? get bestEcpm => _info('bestEcpm');

  /// 实际展示广告的 eCPM 信息，通常需等展示后才可用。
  GromoreEcpmInfo? get showEcpm => _info('showEcpm');

  /// SDK 返回的竞价广告信息列表；未返回时为 null，不保证包含全部来源。
  List<GromoreEcpmInfo>? get multiBiddingEcpm => _list('multiBiddingEcpm');

  /// SDK 返回的缓存广告信息列表；未返回时为 null。
  List<GromoreEcpmInfo>? get cacheList => _list('cacheList');

  /// 各来源的加载诊断，常见字段为 mediationRit/adnName/errCode/errMsg。
  /// 原生未提供时返回空列表；字段含义以 SDK 为准。
  List<Map<String, dynamic>> get loadInfo => (raw['loadInfo'] as List? ?? [])
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .toList();
}
