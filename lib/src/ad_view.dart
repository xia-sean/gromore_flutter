import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'ad_types.dart';
import 'visibility.dart';

/// GroMore 广告视图（用于 Banner/信息流等需要嵌入视图的广告）
///
/// 使用示例：
/// ```dart
/// GromoreAdView(
///   adId: adId,
///   adType: GromoreAdType.banner,
///   width: 300,
///   height: 150,
/// )
/// ```
class GromoreAdView extends StatefulWidget {
  /// 构建广告视图
  ///
  /// [adId] 广告实例 ID
  /// [adType] 广告类型（Banner/信息流）
  /// [width] 视图宽度（px）
  /// [height] 视图高度（px）
  /// [onViewCreated] 平台视图创建回调
  /// [enableVisibility] 是否开启可见性/遮挡检测
  /// [onVisibilityChanged] 可见性变化回调
  const GromoreAdView({
    Key? key,
    required this.adId,
    required this.adType,
    required this.width,
    required this.height,
    this.onViewCreated,
    this.enableVisibility = true,
    this.onVisibilityChanged,
  }) : super(key: key);

  /// 广告实例 ID
  final String adId;

  /// 广告类型（Banner/信息流）
  final GromoreAdType adType;

  /// 视图宽度（px）
  final double width;

  /// 视图高度（px）
  final double height;

  /// 平台视图创建回调
  final PlatformViewCreatedCallback? onViewCreated;

  /// 是否开启可见性/遮挡检测
  final bool enableVisibility;

  /// 可见性变化回调
  final GromoreAdVisibilityChanged? onVisibilityChanged;

  @override
  State<GromoreAdView> createState() => _GromoreAdViewState();
}

/// GroMore 广告视图状态
class _GromoreAdViewState extends State<GromoreAdView> {
  /// 广告平台视图类型
  static const String _viewType = 'gromore_flutter/ad_view';

  final UniqueKey _visibilityKey = UniqueKey();

  /// 构建平台视图参数
  Map<String, dynamic> _buildParams() {
    return {
      'adId': widget.adId,
      'adType': widget.adType.value,
      'width': widget.width.toInt(),
      'height': widget.height.toInt(),
    };
  }

  /// 构建广告视图
  @override
  Widget build(BuildContext context) {
    final params = _buildParams();
    final size = Size(widget.width, widget.height);

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _wrapVisibility(
        context,
        SizedBox(
        width: size.width,
        height: size.height,
        child: AndroidView(
          viewType: _viewType,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: widget.onViewCreated,
        ),
      ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _wrapVisibility(
        context,
        SizedBox(
        width: size.width,
        height: size.height,
        child: UiKitView(
          viewType: _viewType,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: widget.onViewCreated,
        ),
      ),
      );
    }

    return _wrapVisibility(
      context,
      SizedBox(
      width: size.width,
      height: size.height,
      child: const Center(
        child: Text('当前平台不支持广告视图'),
      ),
    ),
    );
  }

  Widget _wrapVisibility(BuildContext context, Widget child) {
    if (!widget.enableVisibility) {
      return child;
    }
    VisibilityDetectorController.instance.updateInterval =
        const Duration(milliseconds: 100);
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        if (!mounted) {
          return;
        }
        final renderObject = context.findRenderObject();
        if (renderObject is! RenderBox || !renderObject.attached) {
          return;
        }
        final renderBox = renderObject;
        final Offset offset = renderBox.localToGlobal(Offset.zero);
        widget.onVisibilityChanged?.call(
          GromoreAdVisibilityInfo(
            visibleFraction: info.visibleFraction,
            visibleBounds: info.visibleBounds,
            size: Size(widget.width, widget.height),
            globalOffset: offset,
          ),
        );
      },
      child: child,
    );
  }
}
