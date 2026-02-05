/// 广告类型枚举
enum GromoreAdType {
  /// 开屏广告
  splash,

  /// 插屏广告
  interstitial,

  /// 全屏视频广告
  fullscreenVideo,

  /// 激励视频广告
  rewardVideo,

  /// 信息流广告
  native,

  /// Draw 信息流广告
  drawNative,

  /// Banner 广告
  banner,
}

/// 广告类型值转换
extension GromoreAdTypeValue on GromoreAdType {
  /// 获取用于通道传输的字符串值
  String get value {
    switch (this) {
      case GromoreAdType.splash:
        return 'splash';
      case GromoreAdType.interstitial:
        return 'interstitial';
      case GromoreAdType.fullscreenVideo:
        return 'fullscreenVideo';
      case GromoreAdType.rewardVideo:
        return 'rewardVideo';
      case GromoreAdType.native:
        return 'native';
      case GromoreAdType.drawNative:
        return 'draw_native';
      case GromoreAdType.banner:
        return 'banner';
    }
  }

  /// 从字符串值解析广告类型
  ///
  /// [value] 通道传输的字符串
  static GromoreAdType? fromValue(String? value) {
    switch (value) {
      case 'splash':
        return GromoreAdType.splash;
      case 'interstitial':
        return GromoreAdType.interstitial;
      case 'fullscreenVideo':
        return GromoreAdType.fullscreenVideo;
      case 'rewardVideo':
        return GromoreAdType.rewardVideo;
      case 'native':
        return GromoreAdType.native;
      case 'draw_native':
        return GromoreAdType.drawNative;
      case 'banner':
        return GromoreAdType.banner;
      default:
        return null;
    }
  }
}
