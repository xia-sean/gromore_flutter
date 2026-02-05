import 'package:flutter/widgets.dart';

/// 广告视图可见性信息
class GromoreAdVisibilityInfo {
  /// 当前可见比例（0~1）
  final double visibleFraction;

  /// 当前可见区域
  final Rect visibleBounds;

  /// 广告视图尺寸
  final Size size;

  /// 广告视图在屏幕上的全局偏移
  final Offset globalOffset;

  /// 构建可见性信息
  const GromoreAdVisibilityInfo({
    required this.visibleFraction,
    required this.visibleBounds,
    required this.size,
    required this.globalOffset,
  });

  /// 是否被遮挡
  bool get isCovered => visibleFraction < 1.0;
}

/// 可见性变化回调
typedef GromoreAdVisibilityChanged = void Function(GromoreAdVisibilityInfo info);
