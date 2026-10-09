/// GroMore 隐私信息采集配置。
///
/// 该配置会在 SDK 初始化时传给平台侧隐私控制器。未设置的字段保持
/// SDK 默认行为；需要在用户同意隐私协议前完全关闭采集时，使用
/// [GromorePrivacyConfig.disableAll]。
class GromorePrivacyConfig {
  const GromorePrivacyConfig({
    this.disableCollection = false,
    this.canUseLocation,
    this.canUsePhoneState,
    this.canUseWifiState,
    this.canUseWriteExternal,
    this.canUseAndroidId,
    this.canUseOaid,
    this.canUseRecordAudio,
    this.canUseMessage,
    this.limitPersonalAds,
    this.programmaticRecommend,
    this.canUseWiFiBSSID,
    this.latitude,
    this.longitude,
    this.androidId,
    this.oaid,
    this.customAppList,
    this.customDevImeis,
    this.privacyConfig,
  });

  /// 关闭 SDK 可控制的全部个人信息采集开关。
  const GromorePrivacyConfig.disableAll()
      : disableCollection = true,
        canUseLocation = false,
        canUsePhoneState = false,
        canUseWifiState = false,
        canUseWriteExternal = false,
        canUseAndroidId = false,
        canUseOaid = false,
        canUseRecordAudio = false,
        canUseMessage = false,
        limitPersonalAds = true,
        programmaticRecommend = false,
        canUseWiFiBSSID = false,
        latitude = null,
        longitude = null,
        androidId = null,
        oaid = null,
        customAppList = null,
        customDevImeis = null,
        privacyConfig = null;

  /// 是否关闭所有未单独配置的采集项。
  final bool disableCollection;

  final bool? canUseLocation;
  final bool? canUsePhoneState;
  final bool? canUseWifiState;
  final bool? canUseWriteExternal;
  final bool? canUseAndroidId;
  final bool? canUseOaid;
  final bool? canUseRecordAudio;
  final bool? canUseMessage;
  final bool? limitPersonalAds;
  final bool? programmaticRecommend;
  final bool? canUseWiFiBSSID;
  final double? latitude;
  final double? longitude;
  final String? androidId;
  final String? oaid;
  final List<String>? customAppList;
  final List<String>? customDevImeis;
  final Map<String, dynamic>? privacyConfig;

  /// 转为 Android/iOS 共用的隐私参数 map。
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    void put(String key, dynamic value) {
      if (value != null) map[key] = value;
    }

    if (disableCollection) map['disableCollection'] = true;
    put('canUseLocation', canUseLocation);
    put('canUsePhoneState', canUsePhoneState);
    put('canUseWifiState', canUseWifiState);
    put('canUseWriteExternal', canUseWriteExternal);
    put('canUseAndroidId', canUseAndroidId);
    put('canUseOaid', canUseOaid);
    put('canUseRecordAudio', canUseRecordAudio);
    put('canUseMessage', canUseMessage);
    put('limitPersonalAds', limitPersonalAds);
    put('programmaticRecommend', programmaticRecommend);
    put('canUseWiFiBSSID', canUseWiFiBSSID);
    put('latitude', latitude);
    put('longitude', longitude);
    put('androidId', androidId);
    put('oaid', oaid);
    put('customAppList', customAppList);
    put('customDevImeis', customDevImeis);
    put('privacyConfig', privacyConfig);
    return map;
  }
}
