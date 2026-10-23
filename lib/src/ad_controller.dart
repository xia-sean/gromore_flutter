import 'dart:async';

import 'ad_callbacks.dart';
import 'ad_configs.dart';
import 'ad_event.dart';
import 'ad_types.dart';
import 'gromore_flutter.dart';

/// 可选的广告资源管理器，统一管理广告 ID、事件订阅和销毁。
/// 关闭/页面退出时调用 dispose；组件移除仍由页面负责。
/// dispose 在加载过程中也可调用，迟到的加载结果会自动释放且不会展示。
class GromoreAdController {
  /// 创建指定广告类型的控制器；callback 可省略，加载失败仍通过 Future 抛出。
  GromoreAdController({required this.adType, this.callback});

  /// 控制器管理的广告类型，必须与 load 的配置类型对应。
  final GromoreAdType adType;

  /// 仅接收本控制器实例的事件；成功确认 ID 后补发早期事件。
  /// 加载失败无法确认 ID 时，由 load 的 Future 抛出错误。
  final GromoreAdCallback? callback;

  final List<String> _ids = [];
  StreamSubscription<GromoreAdEvent>? _subscription;
  bool _disposed = false;
  bool _loading = false;
  Future<void>? _disposing;

  /// 已加载实例 ID；Feed/Draw 可能有多条，每条都由控制器释放。
  List<String> get adIds => List.unmodifiable(_ids);

  /// 首条实例 ID，尚未加载或已经销毁时为 null。
  String? get adId => _ids.isEmpty ? null : _ids.first;

  /// 是否已销毁；销毁后的控制器不能重复加载或展示。
  bool get isDisposed => _disposed;

  bool get _embedded =>
      adType == GromoreAdType.banner ||
      adType == GromoreAdType.native ||
      adType == GromoreAdType.drawNative;

  /// 等待加载完成；弹出式广告还会等待 SDK 就绪，不自动展示。
  /// 重复加载会先释放上一批实例；不允许并发 load。
  /// 加载中被 dispose 时，返回 load_cancelled，迟到结果会被释放。
  Future<List<String>> load(GromoreAdConfig config,
      {Duration timeout = const Duration(seconds: 15)}) async {
    _checkActive();
    if (_loading) throw StateError('广告正在加载，请勿重复调用 load');
    final matches =
        (adType == GromoreAdType.splash && config is GromoreSplashConfig) ||
            (adType == GromoreAdType.interstitial &&
                config is GromoreInterstitialConfig) ||
            (adType == GromoreAdType.fullscreenVideo &&
                config is GromoreFullscreenVideoConfig) ||
            (adType == GromoreAdType.rewardVideo &&
                config is GromoreRewardConfig) ||
            (adType == GromoreAdType.banner && config is GromoreBannerConfig) ||
            (adType == GromoreAdType.native && config is GromoreFeedConfig) ||
            (adType == GromoreAdType.drawNative && config is GromoreDrawConfig);
    if (!matches) throw ArgumentError.value(config, 'config', '配置与控制器广告类型不一致');
    final request = config.toRequest();
    request.toMap();
    _loading = true;
    final buffered = <GromoreAdEvent>[];
    try {
      await _release();
      _checkActive();
      final plugin = GromoreFlutter.instance;
      _subscription = plugin.listenAdEvents(
          adType: adType,
          callback: GromoreAdCallback(onEvent: (event) {
            if (_disposed) return;
            if (_ids.isEmpty) {
              buffered.add(event);
            } else if (_ids.contains(event.adId)) {
              callback?.handle(event);
            }
          }));
      final ids = _embedded
          ? await plugin.loadAds(adType, request, timeout: timeout)
          : [await plugin.loadReady(adType, request, timeout: timeout)];
      if (_disposed) {
        await _disposeIds(ids);
        throw StateError('load_cancelled: 控制器已销毁');
      }
      _ids.addAll(ids);
      for (final event in buffered) {
        if (_disposed) break;
        if (_ids.contains(event.adId)) callback?.handle(event);
      }
      _checkActive();
      return adIds;
    } catch (_) {
      await _release();
      rethrow;
    } finally {
      buffered.clear();
      _loading = false;
    }
  }

  /// 展示已就绪的弹出式广告；Banner/Feed/Draw 使用 adId 挂载 View。
  Future<void> show() async {
    _checkActive();
    if (_embedded) throw StateError('Banner/Feed/Draw 请使用广告 View 展示');
    if (_loading || adId == null) throw StateError('请先等待 load 完成');
    try {
      await GromoreFlutter.instance.showAd(adId!);
    } catch (_) {
      await _release();
      rethrow;
    }
  }

  /// 取消监听并释放全部已知实例；重复调用安全。
  /// 加载仍在原生进行时，迟到实例会在返回后继续释放。
  Future<void> dispose() {
    _disposed = true;
    return _disposing ??= _release();
  }

  void _checkActive() {
    if (_disposed) throw StateError('控制器已销毁，请创建新的 GromoreAdController');
  }

  Future<void> _release() async {
    final sub = _subscription;
    _subscription = null;
    final ids = List<String>.from(_ids);
    _ids.clear();
    try {
      await sub?.cancel();
    } finally {
      await _disposeIds(ids);
    }
  }

  Future<void> _disposeIds(List<String> ids) async {
    await Future.wait(ids.map((id) async {
      try {
        await GromoreFlutter.instance
            .disposeAd(id)
            .timeout(const Duration(seconds: 1));
      } catch (_) {/* 清理尽力完成，不覆盖原始加载/展示错误。 */}
    }));
  }
}
