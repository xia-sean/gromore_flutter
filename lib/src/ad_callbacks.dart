import 'ad_event.dart';

/// 广告事件回调集合
class GromoreAdCallback {
  /// 构建事件处理器；平台或广告来源未提供的事件不会触发。
  const GromoreAdCallback({
    this.onEvent,
    this.onCached,
    this.onDislike,
    this.onVideoStateChanged,
    this.onDownloadChanged,
    this.onLandingPageOpened,
    this.onLandingPageClosed,
    this.onShake,
    this.onRewardCountdown,
    this.onNativeEvent,
    this.onSplashCardReady,
    this.onLoaded,
    this.onRendered,
    this.onFailed,
    this.onShown,
    this.onPresented,
    this.onExposed,
    this.onClicked,
    this.onClosed,
    this.onSkipped,
    this.onCompleted,
    this.onRewarded,
  });

  /// 视频缓存完成；仅 SDK 提供缓存回调的广告类型会触发，不替代就绪检查。
  final void Function(GromoreAdEvent event)? onCached;

  /// 用户选择不感兴趣；data 保留 SDK 返回的 index/reason/reasons 等字段。
  final void Function(GromoreAdEvent event)? onDislike;

  /// Feed/Draw 播放状态变化；data.state 为 Android 状态字符串或 iOS SDK 枚举值。
  final void Function(GromoreAdEvent event)? onVideoStateChanged;

  /// Android 默认自渲染广告的下载状态；data 含 state 及可用的下载进度字段。
  final void Function(GromoreAdEvent event)? onDownloadChanged;

  /// iOS SDK 通知广告落地页/全屏内容即将打开，支持范围取决于广告类型。
  final void Function(GromoreAdEvent event)? onLandingPageOpened;

  /// iOS SDK 通知落地页/其他控制器关闭，data 可带 interactionType。
  final void Function(GromoreAdEvent event)? onLandingPageClosed;

  /// SDK 摇一摇交互通知，data.state 当前可为 dismissed。
  final void Function(GromoreAdEvent event)? onShake;

  /// iOS Feed/Draw 奖励倒计时，data.countDown 为 SDK 返回值。
  final void Function(GromoreAdEvent event)? onRewardCountdown;

  /// Android SDK 原始交互事件，data 包含 code/parameters；不是竞价结果回调。
  final void Function(GromoreAdEvent event)? onNativeEvent;

  /// 开屏卡片可展示通知，之后可调用 showSplashCard；需保留原广告实例。
  final void Function(GromoreAdEvent event)? onSplashCardReady;

  /// 任意事件回调
  final void Function(GromoreAdEvent event)? onEvent;

  /// 加载成功
  final void Function(GromoreAdEvent event)? onLoaded;

  /// 模板渲染完成（返回真实渲染尺寸）
  final void Function(GromoreAdEvent event)? onRendered;

  /// 加载失败/错误
  final void Function(GromoreAdErrorEvent event)? onFailed;

  /// 广告展示
  final void Function(GromoreAdEvent event)? onShown;

  /// 广告展示（present）
  final void Function(GromoreAdEvent event)? onPresented;

  /// 广告曝光
  final void Function(GromoreAdEvent event)? onExposed;

  /// 广告点击
  final void Function(GromoreAdEvent event)? onClicked;

  /// 广告关闭
  final void Function(GromoreAdEvent event)? onClosed;

  /// 广告跳过
  final void Function(GromoreAdEvent event)? onSkipped;

  /// 广告播放完成
  final void Function(GromoreAdEvent event)? onCompleted;

  /// 激励触发
  final void Function(GromoreAdRewardEvent event)? onRewarded;

  /// 处理事件分发
  void handle(GromoreAdEvent event) {
    onEvent?.call(event);
    switch (event.eventType) {
      case GromoreAdEventType.cached:
        onCached?.call(event);
        break;
      case GromoreAdEventType.dislike:
        onDislike?.call(event);
        break;
      case GromoreAdEventType.videoStateChanged:
        onVideoStateChanged?.call(event);
        break;
      case GromoreAdEventType.downloadChanged:
        onDownloadChanged?.call(event);
        break;
      case GromoreAdEventType.landingPageOpened:
        onLandingPageOpened?.call(event);
        break;
      case GromoreAdEventType.landingPageClosed:
        onLandingPageClosed?.call(event);
        break;
      case GromoreAdEventType.shake:
        onShake?.call(event);
        break;
      case GromoreAdEventType.rewardCountdown:
        onRewardCountdown?.call(event);
        break;
      case GromoreAdEventType.nativeEvent:
        onNativeEvent?.call(event);
        break;
      case GromoreAdEventType.splashCardReady:
        onSplashCardReady?.call(event);
        break;

      case GromoreAdEventType.loaded:
        onLoaded?.call(event);
        break;
      case GromoreAdEventType.rendered:
        onRendered?.call(event);
        break;
      case GromoreAdEventType.failed:
      case GromoreAdEventType.error:
        onFailed?.call(GromoreAdErrorEvent.fromEvent(event));
        break;
      case GromoreAdEventType.shown:
        onShown?.call(event);
        break;
      case GromoreAdEventType.presented:
        onPresented?.call(event);
        break;
      case GromoreAdEventType.exposed:
        onExposed?.call(event);
        break;
      case GromoreAdEventType.clicked:
        onClicked?.call(event);
        break;
      case GromoreAdEventType.closed:
        onClosed?.call(event);
        break;
      case GromoreAdEventType.skipped:
        onSkipped?.call(event);
        break;
      case GromoreAdEventType.completed:
        onCompleted?.call(event);
        break;
      case GromoreAdEventType.rewarded:
        onRewarded?.call(GromoreAdRewardEvent.fromEvent(event));
        break;
    }
  }
}
