import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:gromore_flutter/gromore_flutter.dart';

/// 示例应用入口
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GromoreExampleApp());
}

/// GroMore 示例应用
class GromoreExampleApp extends StatefulWidget {
  /// 构建示例应用
  ///
  /// [key] Widget Key
  const GromoreExampleApp({Key? key}) : super(key: key);

  @override
  State<GromoreExampleApp> createState() => _GromoreExampleAppState();
}

/// 示例应用状态
class _GromoreExampleAppState extends State<GromoreExampleApp> {
  /// 示例配置
  final ExampleConfig _config = ExampleConfig();

  /// 日志存储
  final LogStore _logStore = LogStore();

  /// 广告事件订阅
  StreamSubscription<GromoreAdEvent>? _adEventSubscription;

  /// 日志事件订阅
  StreamSubscription<LogEvent>? _logEventSubscription;

  /// 初始化状态与订阅
  @override
  void initState() {
    super.initState();
    GromoreLogger.setHandler(_logStore.add);
    _adEventSubscription = GromoreFlutter.instance.adEvents.listen((event) {
      final level = event.eventType == GromoreAdEventType.failed
          ? LogLevel.error
          : LogLevel.info;
      _logStore.add(LogEvent(
        level: level,
        message:
            'Ad event: ${event.adType.value} ${event.eventType.value} ${event.errorMessage ?? ''}',
        tag: 'ad',
        timestamp: DateTime.now(),
        source: LogSource.dart,
      ));
    });
    _logEventSubscription = GromoreFlutter.instance.logEvents.listen((event) {
      _logStore.add(event);
    });
  }

  /// 释放资源
  @override
  void dispose() {
    _adEventSubscription?.cancel();
    _logEventSubscription?.cancel();
    _config.dispose();
    super.dispose();
  }

  /// 构建界面
  ///
  /// [context] 构建上下文
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 9,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('GroMore Flutter Example'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: '设置'),
                Tab(text: '开屏'),
                Tab(text: '插屏'),
                Tab(text: '全屏'),
                Tab(text: '激励'),
                Tab(text: '信息流'),
                Tab(text: 'Draw信息流'),
                Tab(text: 'Banner'),
                Tab(text: '日志'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              SettingsPage(config: _config, logStore: _logStore),
              AdPage(
                title: '开屏广告',
                adType: GromoreAdType.splash,
                config: _config,
                logStore: _logStore,
              ),
              AdPage(
                title: '插屏广告',
                adType: GromoreAdType.interstitial,
                config: _config,
                logStore: _logStore,
              ),
              AdPage(
                title: '全屏视频',
                adType: GromoreAdType.fullscreenVideo,
                config: _config,
                logStore: _logStore,
              ),
              AdPage(
                title: '激励视频',
                adType: GromoreAdType.rewardVideo,
                config: _config,
                logStore: _logStore,
              ),
              AdPage(
                title: '信息流',
                adType: GromoreAdType.native,
                config: _config,
                logStore: _logStore,
                showSize: true,
              ),
              AdPage(
                title: 'Draw 信息流',
                adType: GromoreAdType.drawNative,
                config: _config,
                logStore: _logStore,
                showSize: true,
              ),
              AdPage(
                title: 'Banner',
                adType: GromoreAdType.banner,
                config: _config,
                logStore: _logStore,
                showSize: true,
              ),
              LogPage(logStore: _logStore),
            ],
          ),
        ),
      ),
    );
  }
}

/// 示例配置数据
class ExampleConfig {
  /// 构建并初始化默认配置
  ExampleConfig() {
    enabledAdTypes = {
      GromoreAdType.splash,
      GromoreAdType.interstitial,
      GromoreAdType.fullscreenVideo,
      GromoreAdType.rewardVideo,
      GromoreAdType.native,
      GromoreAdType.drawNative,
      GromoreAdType.banner,
    };
    _applyDefaults();
  }

  static const String _androidAppIdDefault = '5786586';
  static const String _androidAppNameDefault = '妖怪记账';
  static const String _iosAppIdDefault = '5786645';
  static const String _iosAppNameDefault = '妖怪记账';

  static const Map<GromoreAdType, String> _androidPlacementDefaults = {
    GromoreAdType.splash: '103864669',
    GromoreAdType.interstitial: '103864673',
    GromoreAdType.fullscreenVideo: '103864673',
    GromoreAdType.rewardVideo: '103866429',
    GromoreAdType.native: '103864082',
    GromoreAdType.drawNative: '103875848',
    GromoreAdType.banner: '103866153',
  };

  static const Map<GromoreAdType, String> _iosPlacementDefaults = {
    GromoreAdType.splash: '103866437',
    GromoreAdType.interstitial: '103866249',
    GromoreAdType.fullscreenVideo: '103866249',
    GromoreAdType.rewardVideo: '103866251',
    GromoreAdType.native: '103866159',
    GromoreAdType.drawNative: '103866346',
    GromoreAdType.banner: '103864578',
  };

  /// Android AppId 输入控制器（示例默认值：5786586）
  final TextEditingController androidAppId = TextEditingController();

  /// Android AppName 输入控制器（示例默认值：妖怪记账）
  final TextEditingController androidAppName = TextEditingController();

  /// iOS AppId 输入控制器（示例默认值：5786645）
  final TextEditingController iosAppId = TextEditingController();

  /// iOS AppName 输入控制器（示例默认值：妖怪记账）
  final TextEditingController iosAppName = TextEditingController();

  /// 各广告类型代码位输入控制器（示例默认值仅用于演示）
  final Map<GromoreAdType, TextEditingController> placementControllers = {
    GromoreAdType.splash: TextEditingController(),
    GromoreAdType.interstitial: TextEditingController(),
    GromoreAdType.fullscreenVideo: TextEditingController(),
    GromoreAdType.rewardVideo: TextEditingController(),
    GromoreAdType.native: TextEditingController(),
    GromoreAdType.drawNative: TextEditingController(),
    GromoreAdType.banner: TextEditingController(),
  };

  /// 宽度输入控制器（用于 Banner/信息流）
  final TextEditingController widthController =
      TextEditingController(text: '400');

  /// 高度输入控制器（用于 Banner/信息流）
  final TextEditingController heightController =
      TextEditingController(text: '250');

  /// 是否 Debug 模式
  bool debug = true;

  /// 是否启用聚合
  bool useMediation = true;

  /// 是否启用日志
  bool logEnabled = true;

  /// 日志级别
  LogLevel logLevel = LogLevel.info;

  /// 是否已初始化 SDK
  bool isInitialized = false;

  /// 启用的广告类型集合
  Set<GromoreAdType> enabledAdTypes = {};

  /// 当前是否 iOS
  bool get isIos => defaultTargetPlatform == TargetPlatform.iOS;

  /// 当前是否 Android
  bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// 当前平台文案
  String get platformLabel {
    if (isIos) {
      return 'iOS';
    }
    if (isAndroid) {
      return 'Android';
    }
    return '未知';
  }

  void _applyDefaults() {
    androidAppId.text = _androidAppIdDefault;
    androidAppName.text = _androidAppNameDefault;
    iosAppId.text = _iosAppIdDefault;
    iosAppName.text = _iosAppNameDefault;

    final Map<GromoreAdType, String> defaults =
        defaultTargetPlatform == TargetPlatform.iOS
            ? _iosPlacementDefaults
            : _androidPlacementDefaults;
    for (final entry in defaults.entries) {
      placementControllers[entry.key]?.text = entry.value;
    }
  }

  /// 转为 SDK 初始化配置
  GromoreConfig toConfig() {
    return GromoreConfig(
      androidAppId: isAndroid
          ? (androidAppId.text.trim().isEmpty ? null : androidAppId.text.trim())
          : null,
      androidAppName: isAndroid
          ? (androidAppName.text.trim().isEmpty
              ? null
              : androidAppName.text.trim())
          : null,
      iosAppId: isIos
          ? (iosAppId.text.trim().isEmpty ? null : iosAppId.text.trim())
          : null,
      iosAppName: isIos
          ? (iosAppName.text.trim().isEmpty ? null : iosAppName.text.trim())
          : null,
      debug: debug,
      useMediation: useMediation,
      enabledAdTypes: enabledAdTypes,
      enableLog: logEnabled,
    );
  }

  /// 获取指定广告类型的代码位
  ///
  /// [type] 广告类型
  String placementId(GromoreAdType type) {
    return placementControllers[type]?.text.trim() ?? '';
  }

  /// 释放控制器资源
  void dispose() {
    androidAppId.dispose();
    androidAppName.dispose();
    iosAppId.dispose();
    iosAppName.dispose();
    for (final controller in placementControllers.values) {
      controller.dispose();
    }
    widthController.dispose();
    heightController.dispose();
  }
}

/// 日志存储与通知器
class LogStore {
  /// 日志列表通知器
  final ValueNotifier<List<LogEvent>> logs = ValueNotifier<List<LogEvent>>([]);

  /// 添加日志
  ///
  /// [event] 日志事件
  void add(LogEvent event) {
    logs.value = List<LogEvent>.from(logs.value)..add(event);
  }

  /// 清空日志
  void clear() {
    logs.value = <LogEvent>[];
  }
}

/// 设置页
class SettingsPage extends StatefulWidget {
  /// 构建设置页
  ///
  /// [key] Widget Key
  /// [config] 示例配置
  /// [logStore] 日志存储
  const SettingsPage({Key? key, required this.config, required this.logStore})
      : super(key: key);

  /// 示例配置
  final ExampleConfig config;

  /// 日志存储
  final LogStore logStore;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// 设置页状态
class _SettingsPageState extends State<SettingsPage> {
  /// 是否正在初始化
  bool _isInitializing = false;

  Future<void> _showInitDialog({
    required bool success,
    required String message,
  }) async {
    if (!mounted) {
      return;
    }
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(success ? '初始化成功' : '初始化失败'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 执行初始化逻辑
  Future<void> _initialize() async {
    setState(() {
      _isInitializing = true;
    });
    try {
      await GromoreFlutter.instance.setLogLevel(widget.config.logLevel);
      await GromoreFlutter.instance.setLogEnabled(widget.config.logEnabled);
      final result =
          await GromoreFlutter.instance.init(widget.config.toConfig());
      final bool isIos = widget.config.isIos;
      final bool isAndroid = widget.config.isAndroid;
      final PlatformInitResult platformResult = isIos
          ? result.ios
          : (isAndroid
              ? result.android
              : const PlatformInitResult.skipped(
                  reason: 'unsupported_platform'));
      final String platformName =
          isIos ? 'iOS' : (isAndroid ? 'Android' : '未知平台');
      final bool ok = platformResult.success;
      widget.config.isInitialized = ok;
      final String message =
          '$platformName: ${platformResult.success ? '成功' : '失败'}'
          '${platformResult.errorMessage == null ? '' : '\n原因: ${platformResult.errorMessage}'}';
      widget.logStore.add(LogEvent(
        level: ok ? LogLevel.info : LogLevel.error,
        message:
            'Init result: $platformName=${platformResult.success}(${platformResult.errorMessage ?? ''})',
        tag: 'init',
        timestamp: DateTime.now(),
        source: LogSource.dart,
      ));
      await _showInitDialog(success: ok, message: message);
    } catch (error) {
      widget.config.isInitialized = false;
      widget.logStore.add(LogEvent(
        level: LogLevel.error,
        message: 'Init exception: $error',
        tag: 'init',
        timestamp: DateTime.now(),
        source: LogSource.dart,
      ));
      await _showInitDialog(success: false, message: '初始化异常：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  /// 构建设置页界面
  ///
  /// [context] 构建上下文
  @override
  Widget build(BuildContext context) {
    final bool isIos = widget.config.isIos;
    final bool isAndroid = widget.config.isAndroid;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '当前平台：${widget.config.platformLabel}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text('App 配置', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.config.iosAppId,
                enabled: isIos,
                decoration: const InputDecoration(labelText: 'iOS AppId'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: widget.config.iosAppName,
                enabled: isIos,
                decoration: const InputDecoration(labelText: 'iOS AppName'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.config.androidAppId,
                enabled: isAndroid,
                decoration: const InputDecoration(labelText: 'Android AppId'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: widget.config.androidAppName,
                enabled: isAndroid,
                decoration: const InputDecoration(labelText: 'Android AppName'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _CompactSwitchRow(
          title: 'Debug 模式',
          value: widget.config.debug,
          onChanged: (value) => setState(() => widget.config.debug = value),
        ),
        _CompactSwitchRow(
          title: '启用 GroMore 聚合',
          value: widget.config.useMediation,
          onChanged: (value) =>
              setState(() => widget.config.useMediation = value),
        ),
        _CompactSwitchRow(
          title: '启用日志',
          value: widget.config.logEnabled,
          onChanged: (value) =>
              setState(() => widget.config.logEnabled = value),
        ),
        DropdownButtonFormField<LogLevel>(
          value: widget.config.logLevel,
          decoration: const InputDecoration(labelText: '日志级别'),
          items: LogLevel.values
              .map(
                (level) => DropdownMenuItem(
                  value: level,
                  child: Text(level.value),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => widget.config.logLevel = value);
            }
          },
        ),
        const SizedBox(height: 16),
        const Text('启用广告类型', style: TextStyle(fontWeight: FontWeight.bold)),
        LayoutBuilder(
          builder: (context, constraints) {
            final double itemWidth = (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 4,
              children: GromoreAdType.values.map((type) {
                return SizedBox(
                  width: itemWidth,
                  child: CheckboxListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: EdgeInsets.zero,
                    title: Text(type.value),
                    value: widget.config.enabledAdTypes.contains(type),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          widget.config.enabledAdTypes.add(type);
                        } else {
                          widget.config.enabledAdTypes.remove(type);
                        }
                      });
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: _isInitializing ? null : _initialize,
            child: Text(_isInitializing ? '初始化中...' : '初始化 SDK'),
          ),
        ),
      ],
    );
  }
}

/// 广告操作页
class AdPage extends StatefulWidget {
  /// 构建广告操作页
  ///
  /// [key] Widget Key
  /// [title] 页面标题
  /// [adType] 广告类型
  /// [config] 示例配置
  /// [logStore] 日志存储
  /// [showSize] 是否展示宽高输入
  const AdPage({
    Key? key,
    required this.title,
    required this.adType,
    required this.config,
    required this.logStore,
    this.showSize = false,
  }) : super(key: key);

  /// 页面标题
  final String title;

  /// 广告类型
  final GromoreAdType adType;

  /// 示例配置
  final ExampleConfig config;

  /// 日志存储
  final LogStore logStore;

  /// 是否展示宽高输入
  final bool showSize;

  @override
  State<AdPage> createState() => _AdPageState();
}

/// 紧凑开关行
class _CompactSwitchRow extends StatelessWidget {
  const _CompactSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// 广告操作页状态
class _AdPageState extends State<AdPage> {
  /// 当前广告实例 ID
  String? _adId;

  /// 是否正在加载
  bool _isLoading = false;

  /// 是否正在展示
  bool _isShowing = false;

  /// 是否展示嵌入式广告视图（Banner/信息流）
  bool _showEmbeddedView = false;

  /// 加载广告
  Future<String?> _loadAd() async {
    final placementId = widget.config.placementId(widget.adType);
    if (placementId.isEmpty) {
      widget.logStore.add(LogEvent(
        level: LogLevel.error,
        message: 'PlacementId 不能为空',
        tag: 'ad',
        timestamp: DateTime.now(),
        source: LogSource.dart,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PlacementId 不能为空')),
        );
      }
      return null;
    }
    setState(() {
      _isLoading = true;
      _showEmbeddedView = false;
    });
    try {
      final Map<String, dynamic> extra = {};
      if (widget.showSize) {
        final double ratio = MediaQuery.of(context).devicePixelRatio;
        final double width =
            double.tryParse(widget.config.widthController.text) ?? 0;
        final double height =
            double.tryParse(widget.config.heightController.text) ?? 0;
        extra['width'] = (width * ratio).round();
        extra['height'] = (height * ratio).round();
      }
      if (widget.adType == GromoreAdType.rewardVideo) {
        extra['userId'] = 'test_user';
        extra['rewardName'] = '金币';
        extra['rewardAmount'] = 1;
      }
      final request = GromoreAdRequest(
        placementId: placementId,
        extra: extra.isEmpty ? null : extra,
      );
      final adId = await GromoreFlutter.instance.loadAd(widget.adType, request);
      setState(() {
        _adId = adId;
        _showEmbeddedView = false;
      });
      widget.logStore.add(LogEvent(
        level: LogLevel.info,
        message: 'loadAd success: $adId',
        tag: 'ad',
        timestamp: DateTime.now(),
        source: LogSource.dart,
      ));
      return adId;
    } catch (error) {
      widget.logStore.add(LogEvent(
        level: LogLevel.error,
        message: 'loadAd failed: $error',
        tag: 'ad',
        timestamp: DateTime.now(),
        source: LogSource.dart,
      ));
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 展示广告
  Future<void> _showAd() async {
    if (_isLoading || _isShowing) {
      return;
    }
    if (!widget.config.isInitialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先初始化 SDK')),
        );
      }
      return;
    }

    if (_adId != null) {
      await _disposeAd();
    }

    setState(() {
      _isShowing = true;
    });

    StreamSubscription<GromoreAdEvent>? sub;
    final completer = Completer<GromoreAdEvent>();
    String? pendingAdId;
    sub = GromoreFlutter.instance.adEvents.listen((event) {
      if (pendingAdId == null) {
        return;
      }
      if (event.adId == pendingAdId &&
          (event.eventType == GromoreAdEventType.loaded ||
              event.eventType == GromoreAdEventType.failed ||
              event.eventType == GromoreAdEventType.error)) {
        if (!completer.isCompleted) {
          completer.complete(event);
        }
      }
    });

    try {
      final adId = await _loadAd();
      if (adId == null) {
        return;
      }
      pendingAdId = adId;
      final event = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('广告加载超时'),
      );
      if (event.eventType == GromoreAdEventType.failed ||
          event.eventType == GromoreAdEventType.error) {
        widget.logStore.add(LogEvent(
          level: LogLevel.error,
          message: 'loadAd failed: ${event.errorMessage ?? 'unknown'}',
          tag: 'ad',
          timestamp: DateTime.now(),
          source: LogSource.dart,
        ));
        return;
      }

      if (_isEmbeddedType(widget.adType)) {
        setState(() {
          _showEmbeddedView = true;
        });
      }

      await GromoreFlutter.instance.showAd(adId);
      widget.logStore.add(LogEvent(
        level: LogLevel.info,
        message: 'showAd invoked: $adId',
        tag: 'ad',
        timestamp: DateTime.now(),
        source: LogSource.dart,
      ));
    } catch (error) {
      widget.logStore.add(LogEvent(
        level: LogLevel.error,
        message: 'showAd failed: $error',
        tag: 'ad',
        timestamp: DateTime.now(),
        source: LogSource.dart,
      ));
    } finally {
      await sub?.cancel();
      if (mounted) {
        setState(() {
          _isShowing = false;
        });
      }
    }
  }

  /// 销毁广告
  Future<void> _disposeAd() async {
    if (_adId == null) {
      return;
    }
    try {
      await GromoreFlutter.instance.disposeAd(_adId!);
      widget.logStore.add(LogEvent(
        level: LogLevel.info,
        message: 'disposeAd invoked: $_adId',
        tag: 'ad',
        timestamp: DateTime.now(),
        source: LogSource.dart,
      ));
    } catch (error) {
      widget.logStore.add(LogEvent(
        level: LogLevel.error,
        message: 'disposeAd failed: $error',
        tag: 'ad',
        timestamp: DateTime.now(),
        source: LogSource.dart,
      ));
    } finally {
      setState(() {
        _adId = null;
        _showEmbeddedView = false;
      });
    }
  }

  /// 判断是否为嵌入式广告类型（Banner/信息流）
  ///
  /// [type] 广告类型
  bool _isEmbeddedType(GromoreAdType type) {
    return type == GromoreAdType.banner ||
        type == GromoreAdType.native ||
        type == GromoreAdType.drawNative;
  }

  /// 构建嵌入式广告视图
  Widget _buildEmbeddedAdView() {
    if (_adId == null ||
        !_showEmbeddedView ||
        !_isEmbeddedType(widget.adType)) {
      return const SizedBox.shrink();
    }
    final double width =
        double.tryParse(widget.config.widthController.text.trim()) ?? 0;
    final double height =
        double.tryParse(widget.config.heightController.text.trim()) ?? 0;
    if (width <= 0 || height <= 0) {
      return const Text('请输入正确的宽高以展示广告视图');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('广告视图预览', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: GromoreAdView(
            adId: _adId!,
            adType: widget.adType,
            width: width,
            height: height,
          ),
        ),
      ],
    );
  }

  /// 构建广告操作页界面
  ///
  /// [context] 构建上下文
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          '当前广告类型：${widget.adType.value}',
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.config.placementControllers[widget.adType],
          decoration: const InputDecoration(labelText: '代码位/PlacementId'),
        ),
        if (widget.showSize) ...[
          TextField(
            controller: widget.config.widthController,
            decoration: const InputDecoration(labelText: '宽度 (dp)'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: widget.config.heightController,
            decoration: const InputDecoration(labelText: '高度 (dp)'),
            keyboardType: TextInputType.number,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(88, 40),
              ),
              onPressed: _isShowing || _isLoading ? null : _showAd,
              child: Text(_isShowing || _isLoading ? '加载中...' : '展示'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _disposeAd,
              child: const Text('销毁'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('当前 adId: ${_adId ?? '-'}'),
        _buildEmbeddedAdView(),
      ],
    );
  }
}

/// 日志展示页
class LogPage extends StatelessWidget {
  /// 构建日志页
  ///
  /// [key] Widget Key
  /// [logStore] 日志存储
  const LogPage({Key? key, required this.logStore}) : super(key: key);

  /// 日志存储
  final LogStore logStore;

  /// 构建日志页界面
  ///
  /// [context] 构建上下文
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('日志', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(
                onPressed: logStore.clear,
                child: const Text('清空'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<List<LogEvent>>(
            valueListenable: logStore.logs,
            builder: (context, logs, _) {
              if (logs.isEmpty) {
                return const Center(child: Text('暂无日志'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return ListTile(
                    dense: true,
                    title: Text('[${log.source.value}] ${log.message}'),
                    subtitle: Text(
                        '${log.timestamp.toIso8601String()} ${log.level.value}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
