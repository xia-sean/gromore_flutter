import 'ad_event.dart';

/// 广告事件回调集合
class GromoreAdCallback {
  const GromoreAdCallback({
    this.onEvent,
    this.onLoaded,
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

  /// 任意事件回调
  final void Function(GromoreAdEvent event)? onEvent;

  /// 加载成功
  final void Function(GromoreAdEvent event)? onLoaded;

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
      case GromoreAdEventType.loaded:
        onLoaded?.call(event);
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
