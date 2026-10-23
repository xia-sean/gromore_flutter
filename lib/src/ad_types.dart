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

/// Feed/Draw 视频操作；stop 仅 iOS 支持。
enum GromoreVideoAction {
  /// 请求播放，由当前广告来源决定是否支持。
  play,

  /// 请求恢复播放。
  resume,

  /// 请求暂停播放。
  pause,

  /// 请求停止播放，仅 iOS 支持；Android 返回 unsupported。
  stop,
}

/// 视频操作对应的原生参数。
extension GromoreVideoActionValue on GromoreVideoAction {
  /// 获取原生通道使用的操作名称。
  String get value {
    switch (this) {
      case GromoreVideoAction.play:
        return 'play';
      case GromoreVideoAction.resume:
        return 'resume';
      case GromoreVideoAction.pause:
        return 'pause';
      case GromoreVideoAction.stop:
        return 'stop';
    }
  }
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
