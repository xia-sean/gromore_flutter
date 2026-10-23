import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'ad_types.dart';
import 'ad_size_cache.dart';
import 'gromore_flutter.dart';
import 'visibility.dart';

/// GroMore 广告视图（用于 Banner/Feed/Draw 等需要嵌入视图的广告）。
/// 未填写的 width/height 分别复用加载 Config 的尺寸；两处均未填写会报错。
/// 显式尺寸仅覆盖展示容器，不重新加载或改变 SDK 已请求的素材。
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
  /// [width] 视图宽度（Flutter 逻辑像素），未填写时复用加载尺寸。
  /// [height] 视图高度（Flutter 逻辑像素），未填写时复用加载尺寸。
  /// [onViewCreated] 平台视图创建回调
  /// [enableVisibility] 是否开启可见性/遮挡检测
  /// [onVisibilityChanged] 可见性变化回调
  const GromoreAdView({
    Key? key,
    required this.adId,
    required this.adType,
    this.width,
    this.height,
    this.onViewCreated,
    this.enableVisibility = true,
    this.autoManageVideo = true,
    this.onVisibilityChanged,
  }) : super(key: key);

  /// 广告实例 ID
  final String adId;

  /// 广告类型（Banner/信息流）
  final GromoreAdType adType;

  /// 视图宽度（Flutter 逻辑像素），未填时复用加载 Config 的宽度。
  final double? width;

  /// 视图高度（Flutter 逻辑像素），未填时复用加载 Config 的高度。
  final double? height;

  /// 平台视图创建回调
  final PlatformViewCreatedCallback? onViewCreated;

  /// 是否开启可见性/遮挡检测
  final bool enableVisibility;

  /// Feed/Draw 是否随可见性和应用生命周期自动暂停/恢复，默认 true。
  /// 仅在原生视图创建后生效；设为 false 可由 controlVideo 手动管理。
  /// 此设置只控制视频，不会自动销毁广告。
  final bool autoManageVideo;

  /// 可见性变化回调
  final GromoreAdVisibilityChanged? onVisibilityChanged;

  @override
  State<GromoreAdView> createState() => _GromoreAdViewState();
}

/// GroMore 广告视图状态
class _GromoreAdViewState extends State<GromoreAdView>
    with WidgetsBindingObserver {
  bool _visible = true;
  bool _foreground = true;
  bool _created = false;
  String? _videoCommand;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncVideo();
  }

  Future<void> _syncVideo() async {
    if (!widget.autoManageVideo ||
        !_created ||
        (widget.adType != GromoreAdType.native &&
            widget.adType != GromoreAdType.drawNative)) {
      return;
    }
    final adId = widget.adId;
    final action = _foreground && _visible && mounted
        ? GromoreVideoAction.resume
        : GromoreVideoAction.pause;
    final command = '$adId:$action';
    if (_videoCommand == command) return;
    _videoCommand = command;
    try {
      await GromoreFlutter.instance.controlVideo(adId, action);
    } on PlatformException catch (error) {
      if (_videoCommand == command) _videoCommand = null;
      if (!['ad_not_found', 'unsupported', 'not_ready'].contains(error.code)) {
        FlutterError.reportError(FlutterErrorDetails(exception: error));
      }
    }
  }

  void _onCreated(int id) {
    _created = true;
    _syncVideo();
    widget.onViewCreated?.call(id);
  }

  @override
  void didUpdateWidget(covariant GromoreAdView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.adId != widget.adId || oldWidget.adType != widget.adType) {
      _created = false;
      _videoCommand = null;
    }
    if (oldWidget.autoManageVideo != widget.autoManageVideo) _syncVideo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _visible = false;
    _syncVideo();
    super.dispose();
  }

  /// 广告平台视图类型
  static const String _viewType = 'gromore_flutter/ad_view';

  final UniqueKey _visibilityKey = UniqueKey();

  /// 构建平台视图参数
  Map<String, dynamic> _buildParams(Size size) {
    return {
      'adId': widget.adId,
      'adType': widget.adType.value,
      'width': size.width,
      'height': size.height,
    };
  }

  /// 构建广告视图
  @override
  Widget build(BuildContext context) {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final ratio = MediaQuery.maybeOf(context)?.devicePixelRatio ??
        (views.isEmpty ? 1.0 : views.first.devicePixelRatio);
    final size = AdSizeCache.resolve(
      widget.adId,
      widget.width,
      widget.height,
      devicePixelRatio: ratio,
    );
    final params = _buildParams(size);

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _wrapVisibility(
        context,
        size,
        SizedBox(
          width: size.width,
          height: size.height,
          child: AndroidView(
            key: ValueKey('${widget.adType.value}:${widget.adId}'),
            viewType: _viewType,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
          ),
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _wrapVisibility(
        context,
        size,
        SizedBox(
          width: size.width,
          height: size.height,
          child: UiKitView(
            key: ValueKey('${widget.adType.value}:${widget.adId}'),
            viewType: _viewType,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onCreated,
          ),
        ),
      );
    }

    return _wrapVisibility(
      context,
      size,
      SizedBox(
        width: size.width,
        height: size.height,
        child: const Center(
          child: Text('当前平台不支持广告视图'),
        ),
      ),
    );
  }

  Widget _wrapVisibility(BuildContext context, Size size, Widget child) {
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
        _visible = info.visibleFraction > 0;
        _syncVideo();
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
            size: size,
            globalOffset: offset,
          ),
        );
      },
      child: child,
    );
  }
}
