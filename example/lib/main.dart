import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      String suffix = event.errorMessage ?? '';
      if (event.eventType == GromoreAdEventType.rendered) {
        final data = event.data;
        final width = data?['renderWidth'];
        final height = data?['renderHeight'];
        suffix = 'renderSize=$width x $height';
      }
      _logStore.add(LogEvent(
        level: level,
        message:
            'Ad event: ${event.adType.value} ${event.eventType.value} $suffix',
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

  static const String _iosAppIdDefault = '5820777';
  static const String _iosAppNameDefault = 'Example-iOS';

  static const Map<GromoreAdType, String> _androidPlacementDefaults = {
    GromoreAdType.splash: '104037358',
    GromoreAdType.interstitial: '104036683',
    GromoreAdType.fullscreenVideo: '104036683',
    GromoreAdType.rewardVideo: '104036684',
    GromoreAdType.native: '104037455',
    GromoreAdType.drawNative: '104037163',
    GromoreAdType.banner: '104037605',
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

  /// 是否写入日志文件
  bool logToFileEnabled = false;

  /// 日志级别
  LogLevel logLevel = LogLevel.info;

  /// 是否已初始化 SDK
  bool isInitialized = false;

  /// iOS ATT 是否已请求
  bool attRequested = false;

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
    androidAppId.text = '';
    androidAppName.text = '';
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
      androidOptions: isAndroid
          ? {
              'privacy': {
                'canUseLocation': false,
                'canUsePhoneState': false,
                'canUseOaid': false,
              },
            }
          : null,
      iosOptions: isIos
          ? {
              'privacy': {
                'canUseLocation': false,
              },
              'mediation': {
                'limitPersonalAds': 1,
              },
            }
          : null,
      enableLog: logEnabled,
      enableLogToFile: logToFileEnabled,
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

  /// 是否正在读取原生初始化状态
  bool _isCheckingNativeStatus = false;

  Future<void> _requestAtt() async {
    final granted = await GromoreFlutter.instance.requestATT();
    widget.config.attRequested = true;
    widget.logStore.add(LogEvent(
      level: LogLevel.info,
      message: 'ATT result: $granted',
      tag: 'privacy',
      timestamp: DateTime.now(),
      source: LogSource.dart,
    ));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(granted ? 'ATT 已授权或无需授权' : 'ATT 未授权')),
    );
    setState(() {});
  }

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

  Future<void> _showNativeInitStatus() async {
    if (!widget.config.isAndroid) {
      return;
    }
    setState(() {
      _isCheckingNativeStatus = true;
    });
    try {
      final dynamic result = await GromoreFlutter.instance.invokeNative(
        'getInitializationStatus',
        null,
      );
      final Map<dynamic, dynamic> status =
          result is Map ? result : <dynamic, dynamic>{};
      final String message = status.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n');
      widget.logStore.add(LogEvent(
        level: LogLevel.info,
        message: 'Native init status: $status',
        tag: 'init',
        timestamp: DateTime.now(),
        source: LogSource.dart,
      ));
      await _showInitDialog(
        success: status['isInitSuccess'] == true,
        message: message.isEmpty ? '未获取到原生初始化状态' : message,
      );
    } catch (error) {
      widget.logStore.add(LogEvent(
        level: LogLevel.error,
        message: 'Get native init status exception: $error',
        tag: 'init',
        timestamp: DateTime.now(),
        source: LogSource.dart,
      ));
      await _showInitDialog(success: false, message: '读取原生初始化状态异常：$error');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingNativeStatus = false;
        });
      }
    }
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
        if (isIos) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _requestAtt,
              child: Text(
                widget.config.attRequested ? '重新请求 ATT' : '先请求 ATT',
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'iOS 建议先请求 ATT，再初始化 SDK；示例工程已预置 ATT 文案与基础 SKAdNetworkItems。',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
        ],
        if (isAndroid) ...[
          const Text(
            'Android 宿主接入方式',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const _IntegrationModeCard(
            title: '方案 A：单进程',
            subtitle: '适合普通 Flutter App',
            description:
                '直接在 Flutter 调用 init(config)，并传 androidAppId/androidAppName。宿主原生不用额外控制初始化时机。',
          ),
          const SizedBox(height: 8),
          const _IntegrationModeCard(
            title: '方案 B：多进程自动初始化',
            subtitle: '适合多进程且允许启动即初始化',
            description:
                '在 AndroidManifest.xml + res/values/gromore_config.xml 配置 APP_ID/APP_NAME/AUTO_INIT=true。Flutter 侧可不再传 Android appId/appName。',
          ),
          const SizedBox(height: 8),
          const _IntegrationModeCard(
            title: '方案 C：隐私同意后初始化',
            subtitle: '适合合规要求更严格的宿主',
            description:
                '把 AUTO_INIT=false，并在宿主原生 Application 或隐私同意回调里调用 GromoreFlutterNativeInit.initializeFromManifest(...)。',
          ),
          const SizedBox(height: 12),
          const Text(
            'Android 示例已改为 manifest meta-data + 原生资源文件自动初始化。AppId/AppName 可以留空，点击“初始化 SDK”时会优先复用宿主原生配置；这也是多进程场景推荐的接入方式。',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 4),
          const Text(
            '示例配置文件在 example/android/app/src/main/AndroidManifest.xml 与 res/values/gromore_config.xml。若业务要做隐私同意后再初始化，请关闭 AUTO_INIT，并改为在宿主原生 Application/各进程里调用初始化。',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 8),
        ],
        const Text('App 配置', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (isIos)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.config.iosAppId,
                  decoration: const InputDecoration(labelText: 'iOS AppId'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.config.iosAppName,
                  decoration: const InputDecoration(labelText: 'iOS AppName'),
                ),
              ),
            ],
          )
        else if (isAndroid)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.config.androidAppId,
                  decoration: const InputDecoration(
                    labelText: 'Android AppId',
                    hintText: '留空则使用 manifest meta-data',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: widget.config.androidAppName,
                  decoration: const InputDecoration(
                    labelText: 'Android AppName',
                    hintText: '留空则使用 manifest meta-data',
                  ),
                ),
              ),
            ],
          )
        else
          const Text('当前平台不支持 App 配置'),
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
        _CompactSwitchRow(
          title: '写入日志文件',
          value: widget.config.logToFileEnabled,
          onChanged: (value) =>
              setState(() => widget.config.logToFileEnabled = value),
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
        if (isAndroid) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isCheckingNativeStatus ? null : _showNativeInitStatus,
              child: Text(
                _isCheckingNativeStatus ? '读取中...' : '查看原生初始化状态',
              ),
            ),
          ),
        ],
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

class _IntegrationModeCard extends StatelessWidget {
  const _IntegrationModeCard({
    required this.title,
    required this.subtitle,
    required this.description,
  });

  final String title;
  final String subtitle;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(description),
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
      await sub.cancel();
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

  String _formatLogLine(LogEvent log) {
    return '[${log.source.value}] '
        '${log.timestamp.toIso8601String()} '
        '${log.level.value} '
        '${log.message}';
  }

  Future<void> _copyLogs(BuildContext context) async {
    final logs = logStore.logs.value;
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无可复制日志')),
      );
      return;
    }
    final content = logs.reversed.map(_formatLogLine).join('\n');
    await Clipboard.setData(ClipboardData(text: content));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 ${logs.length} 条日志')),
    );
  }

  Future<void> _showLogFileContent(BuildContext context) async {
    final String content = await GromoreFlutter.instance.readLogFileContent();
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('文件日志内容'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(content.isEmpty ? '暂无文件日志内容' : content),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showLogFilePath(BuildContext context) async {
    final String? path = await GromoreFlutter.instance.getLogFilePath();
    if (!context.mounted) {
      return;
    }
    final String message = path == null ? '当前没有日志文件' : '日志文件路径：$path';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _exportLogs(BuildContext context) async {
    final String? path = await GromoreFlutter.instance.exportLogFile();
    if (!context.mounted) {
      return;
    }
    final String message = path == null ? '暂无可导出的日志文件' : '日志已导出：$path';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _deleteLogFile(BuildContext context) async {
    await GromoreFlutter.instance.deleteLogFile();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('日志文件已删除')),
    );
  }

  /// 构建日志页界面
  ///
  /// [context] 构建上下文
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('日志', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      onPressed: () => _showLogFilePath(context),
                      child: const Text('路径'),
                    ),
                    TextButton(
                      onPressed: () => _showLogFileContent(context),
                      child: const Text('文件内容'),
                    ),
                    TextButton(
                      onPressed: () => _exportLogs(context),
                      child: const Text('导出'),
                    ),
                    TextButton(
                      onPressed: () => _deleteLogFile(context),
                      child: const Text('删除文件'),
                    ),
                    TextButton(
                      onPressed: () => _copyLogs(context),
                      child: const Text('复制全部'),
                    ),
                    TextButton(
                      onPressed: logStore.clear,
                      child: const Text('清空'),
                    ),
                  ],
                ),
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
                  final log = logs[logs.length - 1 - index];
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
