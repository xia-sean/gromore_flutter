import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

import 'ad_types.dart';
import 'ad_view.dart';
import 'visibility.dart';

/// Banner 广告视图
class GromoreBannerView extends StatelessWidget {
  const GromoreBannerView({
    Key? key,
    required this.adId,
    required this.width,
    required this.height,
    this.enableVisibility = true,
    this.onVisibilityChanged,
    this.onViewCreated,
  }) : super(key: key);

  /// 广告实例 ID
  final String adId;

  /// 视图宽度
  final double width;

  /// 视图高度
  final double height;

  /// 是否开启可见性/遮挡检测
  final bool enableVisibility;

  /// 可见性变化回调
  final GromoreAdVisibilityChanged? onVisibilityChanged;

  /// 平台视图创建回调
  final PlatformViewCreatedCallback? onViewCreated;

  @override
  Widget build(BuildContext context) {
    return GromoreAdView(
      adId: adId,
      adType: GromoreAdType.banner,
      width: width,
      height: height,
      enableVisibility: enableVisibility,
      onVisibilityChanged: onVisibilityChanged,
      onViewCreated: onViewCreated,
    );
  }
}

/// 信息流广告视图（模板/Express）
class GromoreFeedView extends StatelessWidget {
  const GromoreFeedView({
    Key? key,
    required this.adId,
    required this.width,
    required this.height,
    this.enableVisibility = true,
    this.onVisibilityChanged,
    this.onViewCreated,
  }) : super(key: key);

  /// 广告实例 ID
  final String adId;

  /// 视图宽度
  final double width;

  /// 视图高度
  final double height;

  /// 是否开启可见性/遮挡检测
  final bool enableVisibility;

  /// 可见性变化回调
  final GromoreAdVisibilityChanged? onVisibilityChanged;

  /// 平台视图创建回调
  final PlatformViewCreatedCallback? onViewCreated;

  @override
  Widget build(BuildContext context) {
    return GromoreAdView(
      adId: adId,
      adType: GromoreAdType.native,
      width: width,
      height: height,
      enableVisibility: enableVisibility,
      onVisibilityChanged: onVisibilityChanged,
      onViewCreated: onViewCreated,
    );
  }
}

/// Draw 信息流广告视图（模板/Express）
class GromoreDrawView extends StatelessWidget {
  const GromoreDrawView({
    Key? key,
    required this.adId,
    required this.width,
    required this.height,
    this.enableVisibility = true,
    this.onVisibilityChanged,
    this.onViewCreated,
  }) : super(key: key);

  /// 广告实例 ID
  final String adId;

  /// 视图宽度
  final double width;

  /// 视图高度
  final double height;

  /// 是否开启可见性/遮挡检测
  final bool enableVisibility;

  /// 可见性变化回调
  final GromoreAdVisibilityChanged? onVisibilityChanged;

  /// 平台视图创建回调
  final PlatformViewCreatedCallback? onViewCreated;

  @override
  Widget build(BuildContext context) {
    return GromoreAdView(
      adId: adId,
      adType: GromoreAdType.drawNative,
      width: width,
      height: height,
      enableVisibility: enableVisibility,
      onVisibilityChanged: onVisibilityChanged,
      onViewCreated: onViewCreated,
    );
  }
}
