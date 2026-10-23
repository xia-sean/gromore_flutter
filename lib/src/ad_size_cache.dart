import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'ad_request.dart';

/// 插件内部按实例保存请求尺寸；View 的覆盖值不会修改此记录。
class AdSizeCache {
  static final Map<String, AdRequestSize> _sizes = {};

  static void set(String adId, AdRequestSize size) => _sizes[adId] = size;

  static void copy(String sourceId, String targetId) {
    final size = _sizes[sourceId];
    if (size != null) _sizes[targetId] = size;
  }

  static void remove(String adId) => _sizes.remove(adId);

  static Size resolve(String adId, double? width, double? height,
      {required double devicePixelRatio}) {
    final cached = _sizes[adId];
    final scale = cached?.nativePixels == true &&
            defaultTargetPlatform == TargetPlatform.android
        ? devicePixelRatio
        : 1.0;
    final resolvedWidth =
        width ?? (cached?.width == null ? null : cached!.width! / scale);
    final resolvedHeight =
        height ?? (cached?.height == null ? null : cached!.height! / scale);
    if (resolvedWidth == null ||
        resolvedHeight == null ||
        !resolvedWidth.isFinite ||
        !resolvedHeight.isFinite ||
        resolvedWidth <= 0 ||
        resolvedHeight <= 0) {
      throw FlutterError(
        '广告 $adId 缺少有效的视图尺寸。请在加载 Config 中设置正数 width/height，'
        '或在广告 View 中补齐；未知或已销毁的实例需在 View 中显式填写尺寸。',
      );
    }
    return Size(resolvedWidth, resolvedHeight);
  }
}

/// 在发起加载时快照请求，沿用原生参数优先级，不持有业务 Map。
class AdRequestSize {
  AdRequestSize.fromRequest(GromoreAdRequest request)
      : this._fromMap(request.toMap());

  AdRequestSize._fromMap(Map<String, dynamic> request)
      : width = _dimension(request, 'width'),
        height = _dimension(request, 'height'),
        nativePixels = request['sizeUnit'] != 'logicalPixels';

  final double? width;
  final double? height;
  final bool nativePixels;

  static double? _dimension(Map<String, dynamic> request, String key) {
    final platformExtra = request[
        defaultTargetPlatform == TargetPlatform.android
            ? 'androidExtra'
            : 'iosExtra'] as Map?;
    final extra = request['extra'] as Map?;
    final value = request[key] ?? platformExtra?[key] ?? extra?[key];
    return value is num ? value.toDouble() : double.tryParse('$value');
  }
}
