import 'dart:async';

import 'ad_callbacks.dart';
import 'ad_configs.dart';
import 'ad_event.dart';
import 'ad_types.dart';
import 'gromore_flutter.dart';

/// 开屏广告 Facade
class GromoreSplash {
  static Future<String> load(GromoreSplashConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.splash,
      config.toRequest(),
    );
  }

  /// 等待 SDK 可展示后返回实例 ID；不自动展示，关闭或页面退出后仍需 dispose。
  /// timeout 覆盖原生响应、加载及就绪等待，失败时自动清理。
  static Future<String> loadReady(GromoreSplashConfig config,
          {Duration timeout = const Duration(seconds: 15)}) =>
      GromoreFlutter.instance.loadReady(
          GromoreAdType.splash, config.toRequest(),
          timeout: timeout);

  static Future<void> show(String adId) {
    return GromoreFlutter.instance.showAd(adId);
  }

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  /// 等待开屏加载就绪后发起展示，返回实例 ID；不等待广告关闭。
  /// 失败/超时会尝试清理实例；成功后仍需在关闭或页面退出时 dispose。
  static Future<String> loadAndShow(GromoreSplashConfig config) async {
    final adId = await GromoreFlutter.instance.loadReady(
        GromoreAdType.splash, config.toRequest(),
        timeout: Duration(milliseconds: (config.timeoutMillis ?? 3500) + 3000));
    try {
      await show(adId);
      return adId;
    } catch (_) {
      try {
        await dispose(adId);
      } catch (_) {/* Preserve show error. */}
      rethrow;
    }
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.splash,
      adId: adId,
      callback: callback,
    );
  }
}

/// 插屏广告 Facade
class GromoreInterstitial {
  static Future<String> load(GromoreInterstitialConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.interstitial,
      config.toRequest(),
    );
  }

  /// 等待 SDK 可展示后返回实例 ID；不自动展示，关闭或页面退出后仍需 dispose。
  /// timeout 覆盖原生响应、加载及就绪等待，失败时自动清理。
  static Future<String> loadReady(GromoreInterstitialConfig config,
          {Duration timeout = const Duration(seconds: 15)}) =>
      GromoreFlutter.instance.loadReady(
          GromoreAdType.interstitial, config.toRequest(),
          timeout: timeout);

  static Future<void> show(String adId) {
    return GromoreFlutter.instance.showAd(adId);
  }

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.interstitial,
      adId: adId,
      callback: callback,
    );
  }
}

/// 全屏视频广告 Facade
class GromoreFullscreenVideo {
  static Future<String> load(GromoreFullscreenVideoConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.fullscreenVideo,
      config.toRequest(),
    );
  }

  /// 等待 SDK 可展示后返回实例 ID；不自动展示，关闭或页面退出后仍需 dispose。
  /// timeout 覆盖原生响应、加载及就绪等待，失败时自动清理。
  static Future<String> loadReady(GromoreFullscreenVideoConfig config,
          {Duration timeout = const Duration(seconds: 15)}) =>
      GromoreFlutter.instance.loadReady(
          GromoreAdType.fullscreenVideo, config.toRequest(),
          timeout: timeout);

  static Future<void> show(String adId) {
    return GromoreFlutter.instance.showAd(adId);
  }

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.fullscreenVideo,
      adId: adId,
      callback: callback,
    );
  }
}

/// 激励视频广告 Facade
class GromoreReward {
  static Future<String> load(GromoreRewardConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.rewardVideo,
      config.toRequest(),
    );
  }

  /// 等待 SDK 可展示后返回实例 ID；不自动展示，关闭或页面退出后仍需 dispose。
  /// timeout 覆盖原生响应、加载及就绪等待，失败时自动清理。
  static Future<String> loadReady(GromoreRewardConfig config,
          {Duration timeout = const Duration(seconds: 15)}) =>
      GromoreFlutter.instance.loadReady(
          GromoreAdType.rewardVideo, config.toRequest(),
          timeout: timeout);

  static Future<void> show(String adId) {
    return GromoreFlutter.instance.showAd(adId);
  }

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.rewardVideo,
      adId: adId,
      callback: callback,
    );
  }
}

/// Banner 广告 Facade
class GromoreBanner {
  static Future<String> load(GromoreBannerConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.banner,
      config.toRequest(),
    );
  }

  /// 等待 Banner 加载成功；SDK 模板渲染由挂载 View 触发，不自动展示。
  /// 失败或超时自动清理，成功后仍需 dispose。
  static Future<String> loadReady(GromoreBannerConfig config,
          {Duration timeout = const Duration(seconds: 15)}) async =>
      (await GromoreFlutter.instance.loadAds(
              GromoreAdType.banner, config.toRequest(),
              timeout: timeout))
          .first;

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.banner,
      adId: adId,
      callback: callback,
    );
  }
}

/// 信息流广告 Facade
class GromoreFeed {
  static Future<String> load(GromoreFeedConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.native,
      config.toRequest(),
    );
  }

  /// 等待 loaded 后返回 SDK 实际加载的全部 ID，数量可能少于 adCount。
  /// 不自动挂载视图；每条广告需独立监听、挂载和销毁。
  /// 加载失败/超时抛出异常并尝试清理实例，默认 timeout 为 15 秒。
  static Future<List<String>> loadAll(GromoreFeedConfig config,
          {Duration timeout = const Duration(seconds: 15)}) =>
      GromoreFlutter.instance
          .loadAds(GromoreAdType.native, config.toRequest(), timeout: timeout);

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.native,
      adId: adId,
      callback: callback,
    );
  }
}

/// Draw 信息流广告 Facade
class GromoreDraw {
  static Future<String> load(GromoreDrawConfig config) {
    return GromoreFlutter.instance.loadAd(
      GromoreAdType.drawNative,
      config.toRequest(),
    );
  }

  /// 等待 loaded 后返回 SDK 实际加载的全部 ID，数量可能少于 adCount。
  /// 不自动挂载视图；每条广告需独立监听、挂载和销毁。
  /// 加载失败/超时抛出异常并尝试清理实例，默认 timeout 为 15 秒。
  static Future<List<String>> loadAll(GromoreDrawConfig config,
          {Duration timeout = const Duration(seconds: 15)}) =>
      GromoreFlutter.instance.loadAds(
          GromoreAdType.drawNative, config.toRequest(),
          timeout: timeout);

  static Future<void> dispose(String adId) {
    return GromoreFlutter.instance.disposeAd(adId);
  }

  static StreamSubscription<GromoreAdEvent> listen({
    String? adId,
    required GromoreAdCallback callback,
  }) {
    return GromoreFlutter.instance.listenAdEvents(
      adType: GromoreAdType.drawNative,
      adId: adId,
      callback: callback,
    );
  }
}
