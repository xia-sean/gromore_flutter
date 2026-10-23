import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'ad_event.dart';
import 'ad_info.dart';
import 'ad_request.dart';
import 'ad_size_cache.dart';
import 'ad_types.dart';
import 'ad_callbacks.dart';
import 'config.dart';
import 'init_result.dart';
import 'logger.dart';
import 'privacy.dart';
import 'preload_request.dart';
import '../gromore_flutter_platform_interface.dart';

/// GroMore Flutter 入口类
///
/// 示例：
/// ```dart
/// final result = await GromoreFlutter.instance.initialize(
///   iosAppId: 'your_ios_app_id',
/// );
/// ```
class GromoreFlutter {
  GromoreFlutter._();

  /// 单例实例
  static final GromoreFlutter instance = GromoreFlutter._();

  /// 广告事件流控制器
  final StreamController<GromoreAdEvent> _adEventController =
      StreamController<GromoreAdEvent>.broadcast();

  /// 日志事件流控制器
  final StreamController<LogEvent> _logEventController =
      StreamController<LogEvent>.broadcast();

  /// 广告事件订阅
  StreamSubscription<dynamic>? _adEventSubscription;

  /// 日志事件订阅
  StreamSubscription<dynamic>? _logEventSubscription;

  /// adId -> 广告类型映射（用于展示后续控制）
  final Map<String, GromoreAdType> _adTypesById = <String, GromoreAdType>{};

  /// 当前处于方向锁定的开屏 adId（仅 iOS）
  String? _lockedSplashAdId;
  final Map<String, GromoreAdEvent> _lastAdErrors = {};

  List<DeviceOrientation> _splashRestoreOrientations = const [];
  List<DeviceOrientation> _activeSplashRestoreOrientations = const [];
  Future<void> _orientationChanges = Future<void>.value();

  /// 广告事件流
  Stream<GromoreAdEvent> get adEvents => _adEventController.stream;

  /// 日志事件流
  Stream<LogEvent> get logEvents => _logEventController.stream;

  /// 确保事件通道已订阅
  void _ensureEventStreams() {
    _adEventSubscription ??=
        GromoreFlutterPlatform.instance.adEvents.listen((dynamic event) {
      if (event is Map) {
        final adEvent = GromoreAdEvent.fromMap(event);
        _onAdEvent(adEvent);
        _adEventController.add(adEvent);
      }
    });
    _logEventSubscription ??=
        GromoreFlutterPlatform.instance.logEvents.listen((dynamic event) {
      if (event is Map) {
        final logEvent = LogEvent.fromMap(event);
        _logEventController.add(logEvent);
        GromoreLogger.handleNative(logEvent);
      }
    });
  }

  /// 初始化 GroMore SDK
  ///
  /// [config] 初始化配置
  Future<InitResult> init(GromoreConfig config) async {
    _ensureEventStreams();
    final bool isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final bool isIos = defaultTargetPlatform == TargetPlatform.iOS;

    final bool logEnabled = config.enableLog ?? kDebugMode;
    GromoreLogger.setLogEnabled(logEnabled);
    await GromoreLogger.setLogFileEnabled(config.enableLogToFile);
    await GromoreFlutterPlatform.instance.setLogEnabled(logEnabled);

    if (isAndroid) {
      final PlatformInitResult result =
          await GromoreFlutterPlatform.instance.init(config);
      return InitResult(
        android: result,
        ios: const PlatformInitResult.skipped(reason: 'not_running_on_ios'),
      );
    }

    if (isIos) {
      final PlatformInitResult iosResult = _validateIos(config);
      if (!iosResult.success) {
        return InitResult(
          android: const PlatformInitResult.skipped(
              reason: 'not_running_on_android'),
          ios: iosResult,
        );
      }
      final PlatformInitResult result =
          await GromoreFlutterPlatform.instance.init(config);
      if (result.success) {
        _splashRestoreOrientations =
            List.unmodifiable(config.iosSplashRestoreOrientations);
      }
      return InitResult(
        android:
            const PlatformInitResult.skipped(reason: 'not_running_on_android'),
        ios: result,
      );
    }

    return const InitResult(
      android: PlatformInitResult.skipped(reason: 'unsupported_platform'),
      ios: PlatformInitResult.skipped(reason: 'unsupported_platform'),
    );
  }

  /// 快速初始化入口。
  ///
  /// 普通接入只需要传入当前平台的 AppId。需要配置日志、广告类型、
  /// 多进程或平台扩展参数时，继续使用 [init] 和 [GromoreConfig]。
  Future<InitResult> initialize({
    String? androidAppId,
    String? iosAppId,
    GromorePrivacyConfig? privacy,
  }) {
    return init(
      GromoreConfig(
        androidAppId: androidAppId,
        iosAppId: iosAppId,
        privacy: privacy,
      ),
    );
  }

  /// 设置日志开关
  ///
  /// [enabled] 是否启用日志
  Future<void> setLogEnabled(bool enabled) async {
    GromoreLogger.setLogEnabled(enabled);
    await GromoreFlutterPlatform.instance.setLogEnabled(enabled);
  }

  /// 设置是否写入日志文件
  ///
  /// [enabled] 是否写入
  Future<void> setLogFileEnabled(bool enabled) async {
    await GromoreLogger.setLogFileEnabled(enabled);
  }

  /// 设置日志级别
  /// 采用阈值模式，而不是精确匹配模式。
  /// 例如设置为 `LogLevel.info` 时，会输出和写入 `info/warn/error`；
  /// 设置为 `LogLevel.debug` 时，会输出和写入全部级别日志。
  ///
  /// [level] 日志级别
  Future<void> setLogLevel(LogLevel level) async {
    GromoreLogger.setLogLevel(level);
    await GromoreFlutterPlatform.instance.setLogLevel(level);
  }

  /// 导出日志为 txt 文件，返回导出路径
  ///
  /// [fileName] 自定义导出文件名，需包含 `.txt`
  Future<String?> exportLogFile({String? fileName}) async {
    return GromoreLogger.exportLogFile(fileName: fileName);
  }

  /// 获取当前日志文件路径
  Future<String?> getLogFilePath() async {
    return GromoreLogger.getLogFilePath();
  }

  /// 读取当前日志文件内容
  Future<String> readLogFileContent() async {
    return GromoreLogger.readLogFileContent();
  }

  /// 清空当前日志文件内容
  Future<void> clearLogFile() async {
    await GromoreLogger.clearLogFile();
  }

  /// 删除当前日志文件
  Future<void> deleteLogFile() async {
    await GromoreLogger.deleteLogFile();
  }

  /// 加载广告
  ///
  /// [type] 广告类型
  /// [request] 广告请求参数
  ///
  /// 示例：
  /// ```dart
  /// final adId = await GromoreFlutter.instance.loadAd(
  ///   GromoreAdType.splash,
  ///   const GromoreAdRequest(placementId: 'your_placement_id'),
  /// );
  /// ```
  Future<String> loadAd(GromoreAdType type, GromoreAdRequest request) async {
    _ensureEventStreams();
    _assertAdTypeEnabled(type);
    request.toMap(); // 在调用原生 SDK 前校验最终生效参数。
    final requestSize = type == GromoreAdType.banner ||
            type == GromoreAdType.native ||
            type == GromoreAdType.drawNative
        ? AdRequestSize.fromRequest(request)
        : null;
    final adId = await GromoreFlutterPlatform.instance.loadAd(type, request);
    _adTypesById[adId] = type;
    if (requestSize != null) AdSizeCache.set(adId, requestSize);
    return adId;
  }

  /// 发起加载并等待 loaded，返回 SDK 实际加载的全部实例 ID。
  ///
  /// Feed/Draw 可返回多条，其他类型通常只有一条；每条均需单独销毁。
  /// 返回表示加载成功，不保证 SDK 已可展示；弹出式广告可用 [loadReady]。
  /// 加载失败抛出 PlatformException，等待结果超过 [timeout] 抛出 TimeoutException，
  /// timeout 覆盖原生方法响应和 loaded 等待；超时后迟到的实例会继续释放。
  /// 清理最多等待 200ms，随后在后台继续，不覆盖原始错误。
  /// 不会自动挂载视图或调用 showAd。
  Future<List<String>> loadAds(GromoreAdType type, GromoreAdRequest request,
      {Duration timeout = const Duration(seconds: 15)}) async {
    _validateTimeout(timeout);
    final watch = Stopwatch()..start();
    final pending = <GromoreAdEvent>[];
    final result = Completer<List<String>>();
    String? id;
    var abandoned = false;
    void accept(GromoreAdEvent event) {
      if (event.adId != id || result.isCompleted || abandoned) return;
      if (event.eventType == GromoreAdEventType.loaded) {
        final ids = (event.data?['adIds'] as List?)?.cast<String>() ?? [id!];
        if (ids.isEmpty) {
          result.completeError(PlatformException(
              code: 'empty_ad', message: 'SDK returned no ad IDs'));
          return;
        }
        for (final item in ids) {
          _adTypesById[item] = type;
          AdSizeCache.copy(id!, item);
        }
        result.complete(ids);
      } else if (event.eventType == GromoreAdEventType.failed ||
          event.eventType == GromoreAdEventType.error) {
        result.completeError(PlatformException(
            code: event.errorCode ?? 'load_failed',
            message: event.errorMessage,
            details: event.data));
      }
    }

    _ensureEventStreams();
    final subscription = adEvents.listen((event) {
      if (id == null) {
        pending.add(event);
      } else {
        accept(event);
      }
    });
    // 先挂错误处理，避免原生响应之前的失败事件成为未处理异常。
    final outcome = result.future;
    outcome.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    final loading = loadAd(type, request).then((value) {
      id = value;
      if (abandoned) {
        _cleanupLoadedIds(value);
      } else {
        for (final event in pending) {
          accept(event);
        }
      }
      pending.clear();
      return value;
    });
    loading.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    try {
      await loading.timeout(_remaining(timeout, watch));
      return await outcome.timeout(_remaining(timeout, watch));
    } catch (_) {
      abandoned = true;
      if (id != null) {
        // 清理失败或平台不响应，不能覆盖原错误、阻塞超时返回。
        await _cleanupLoadedIds(id!)
            .timeout(const Duration(milliseconds: 200), onTimeout: () {});
      }
      rethrow;
    } finally {
      pending.clear();
      await subscription.cancel();
    }
  }

  static void _validateTimeout(Duration timeout) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', '必须大于 0');
    }
  }

  static Duration _remaining(Duration timeout, Stopwatch watch) {
    final remaining = timeout - watch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException('Ad loading timed out', timeout);
    }
    return remaining;
  }

  Future<void> _cleanupLoadedIds(String id) async {
    var ids = <String>[id];
    try {
      final value = await invokeNative('getAdIds', {'adId': id})
          .timeout(const Duration(milliseconds: 100));
      if (value is List) ids = {id, ...value.cast<String>()}.toList();
    } catch (_) {/* Holder may not exist yet. */}
    await Future.wait(ids.map((item) async {
      try {
        await disposeAd(item);
      } catch (_) {/* Preserve original error. */}
    }));
  }

  /// 等待广告可展示；timeout 覆盖原生响应、加载结果和就绪查询。
  /// 失败或超时会清理实例，Feed/Draw 多条广告请使用 loadAds。
  Future<String> loadReady(GromoreAdType type, GromoreAdRequest request,
      {Duration timeout = const Duration(seconds: 15)}) async {
    _validateTimeout(timeout);
    final watch = Stopwatch()..start();
    final ids = await loadAds(type, request, timeout: timeout);
    final id = ids.first;
    try {
      while (true) {
        final failure = _lastAdErrors[id];
        if (failure != null) {
          throw PlatformException(
              code: failure.errorCode ?? 'load_failed',
              message: failure.errorMessage);
        }
        if (await isAdReady(id).timeout(_remaining(timeout, watch))) return id;
        final remaining = _remaining(timeout, watch);
        await Future<void>.delayed(remaining < const Duration(milliseconds: 50)
            ? remaining
            : const Duration(milliseconds: 50));
      }
    } catch (_) {
      await Future.wait(ids.map((item) async {
        try {
          await disposeAd(item).timeout(const Duration(milliseconds: 200));
        } catch (_) {}
      }));
      rethrow;
    }
  }

  /// 查询存活广告实例的就绪和加载中状态（Android/iOS）。
  /// 不触发加载；未知或已销毁的 [adId] 抛出 ad_not_found 平台异常。
  Future<GromoreAdState> getAdState(String adId) async =>
      GromoreAdState(await invokeNative('getAdState', {'adId': adId}) as Map);

  /// 查询 SDK 当前是否认为广告可展示；查询后状态仍可能变化。
  Future<bool> isAdReady(String adId) async => (await getAdState(adId)).isReady;

  /// 查询实例的加载诊断、eCPM、竞价和缓存信息（Android/iOS）。
  /// 可用字段由 SDK/广告来源和权限决定，不支持或未返回的字段保留空值。
  /// 未知或已销毁的 [adId] 抛出 ad_not_found 平台异常。
  Future<GromoreAdDiagnostics> getAdDiagnostics(String adId) async =>
      GromoreAdDiagnostics(
          await invokeNative('getAdDiagnostics', {'adId': adId}) as Map);

  /// 控制 Feed/Draw 视频；不适用于激励、全屏或其他广告类型。
  ///
  /// [action] 推荐 GromoreVideoAction 枚举，也兼容 play/resume/pause/stop 字符串。
  /// stop 仅 iOS 支持。
  /// Android stop 或不支持的广告类型抛出 unsupported；实际效果由广告来源决定。
  /// GromoreAdView 默认按可见性/应用生命周期自动控制，可能覆盖手动暂停状态，
  /// 需要完全手动控制时设置该视图 autoManageVideo 为 false。
  Future<void> controlVideo(String adId, Object action) async {
    final value = action is GromoreVideoAction ? action.value : action;
    if (value is! String ||
        !['play', 'resume', 'pause', 'stop'].contains(value)) {
      throw ArgumentError.value(
          action, 'action', '请使用 GromoreVideoAction 或 play/resume/pause/stop');
    }
    await invokeNative('controlVideo', {'adId': adId, 'action': value});
  }

  /// 展示已加载开屏的卡片，须先收到 splashCardReady 事件。
  /// iOS 请求还需启用 options.supportCardView；未就绪时抛出 not_ready。
  /// 卡片可用性由广告来源决定，使用卡片期间需保留对应开屏实例。
  Future<void> showSplashCard(String adId) async {
    await invokeNative('showSplashCard', {'adId': adId});
  }

  /// 隐藏已加载开屏的 SDK 跳过按钮（Android/iOS）。
  /// 仅适用于开屏；具体展示效果以 SDK/广告来源为准。
  Future<void> hideSplashSkipButton(String adId) async {
    await invokeNative('hideSplashSkipButton', {'adId': adId});
  }

  /// SDK 批量预缓存，不创建可直接展示的 Flutter 实例 ID，展示仍需正常加载。
  ///
  /// 须在初始化成功后调用。推荐 [requests] 使用 GromorePreloadRequest，
  /// 自动推导广告类型并校验参数；同时兼容旧 Map。Android Map 每项使用
  /// {adType: 'rewardVideo', request: config.toRequest().toMap(), primeRitList: [...] }。
  /// iOS 每项需 iosFactoryId，宿主先注册原生 PreloadInfoFactory，
  /// 由工厂按当前 SDK 协议构建原生 info；未注册时抛出 factory_not_found。
  /// [requests] 不能为空，[interval] 范围 1~10，[concurrent] 范围 1~20；
  /// 参数越界抛出 ArgumentError。返回仅表示调用完成，不保证预缓存命中。
  Future<void> preloadAds(List<Object> requests,
      {int interval = 1, int concurrent = 2}) async {
    if (requests.isEmpty ||
        interval < 1 ||
        interval > 10 ||
        concurrent < 1 ||
        concurrent > 20) {
      throw ArgumentError('Invalid preload requests/interval/concurrent');
    }
    final items = requests.map((item) {
      final Map<String, dynamic> map;
      if (item is GromorePreloadRequest) {
        map = item.toMap();
      } else if (item is Map<String, dynamic>) {
        map = Map<String, dynamic>.from(item);
      } else {
        throw ArgumentError.value(item, 'requests',
            '请使用 GromorePreloadRequest 或 Map<String, dynamic>');
      }
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final id = map['iosFactoryId'];
        if (id is! String || id.trim().isEmpty) {
          throw ArgumentError.value(
              id, 'iosFactoryId', 'iOS 预缓存需要注册宿主工厂并填写 ID');
        }
      } else {
        final type = map['adType'];
        final raw = map['request'] ?? map;
        if (type is! String ||
            GromoreAdTypeValue.fromValue(type) == null ||
            raw is! Map ||
            raw['placementId'] is! String) {
          throw ArgumentError.value(
              item, 'requests', '请填写有效 adType 和 request.placementId');
        }
        final data = Map<String, dynamic>.from(raw);
        final normalized = GromoreAdRequest(
          placementId: data['placementId'] as String,
          params: data,
          extra: (data['extra'] as Map?)?.cast<String, dynamic>(),
          androidExtra: (data['androidExtra'] as Map?)?.cast<String, dynamic>(),
          iosExtra: (data['iosExtra'] as Map?)?.cast<String, dynamic>(),
          sizeUnit: data['sizeUnit'] == 'logicalPixels'
              ? GromoreAdSizeUnit.logicalPixels
              : GromoreAdSizeUnit.nativePixels,
        ).toMap();
        map['request'] = normalized;
      }
      return map;
    }).toList();
    await invokeNative('preloadAds',
        {'requests': items, 'interval': interval, 'concurrent': concurrent});
  }

  /// 初始化成功后更新 SDK 的运行期配置，不会重新初始化 SDK。
  ///
  /// Android 支持 privacy、userInfoForSegment、localExtra、themeStatus、publisherDid；
  /// iOS 仅支持 themeStatus、userInfoForSegment。不支持的键抛出 unsupported。
  /// 参数结构沿用初始化时的平台选项；segment 更新为整组替换。
  /// iOS 隐私和本地额外参数仍须在初始化前配置。
  Future<void> updateConfig(Map<String, dynamic> options) async {
    await invokeNative('updateConfig', options);
  }

  /// 查询 SDK 版本和初始化状态，返回 version/isReady/isInitialized。
  /// 不会触发初始化，也不代表某个广告实例可展示。
  Future<Map<String, dynamic>> getSdkInfo() async =>
      (await invokeNative('getSdkInfo', null) as Map).cast<String, dynamic>();

  /// 打开 SDK 广告测试/预览工具，仅支持原生 Debug 构建。
  /// [rit] 为测试广告位 ID，[info] 为 SDK 约定的预览参数；rit 优先于 info 同名值。
  /// 成功返回 true；Release 构建抛出 debug_only，SDK 打开失败时抛出平台异常。
  Future<bool> openTestTool({String? rit, Map<String, dynamic>? info}) async =>
      await invokeNative('openTestTool', {'rit': rit, 'info': info}) == true;

  /// 展示广告
  ///
  /// [adId] 必须是已加载且 SDK 就绪的实例；弹出式广告可用 [loadReady] 等待。
  /// 未就绪、实例不存在或原生无法展示时抛出 PlatformException。
  /// 返回只表示已发起展示，需保留监听至关闭/失败后再销毁。
  /// Banner/Feed/Draw 通过平台视图展示，无需调用此方法。
  Future<void> showAd(String adId) async {
    final adType = _adTypesById[adId];
    final shouldLockSplashOrientation =
        defaultTargetPlatform == TargetPlatform.iOS &&
            adType == GromoreAdType.splash;
    if (shouldLockSplashOrientation && _lockedSplashAdId != null) {
      throw PlatformException(
          code: 'splash_show_in_progress', message: '已有开屏正在展示');
    }
    try {
      if (shouldLockSplashOrientation) {
        await _lockSplashOrientation(adId);
      }
      return await GromoreFlutterPlatform.instance.showAd(adId);
    } catch (_) {
      if (shouldLockSplashOrientation) {
        await _restoreSplashOrientation(adId);
      }
      rethrow;
    }
  }

  /// 销毁广告
  ///
  /// [adId] 广告实例 ID
  Future<void> disposeAd(String adId) async {
    AdSizeCache.remove(adId);
    _lastAdErrors.remove(adId);
    final adType = _adTypesById.remove(adId);
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          adType == GromoreAdType.splash) {
        await _restoreSplashOrientation(adId);
      }
    } finally {
      await GromoreFlutterPlatform.instance.disposeAd(adId);
    }
  }

  /// 调用原生自定义方法
  ///
  /// [method] 原生方法名
  /// [args] 方法参数
  Future<dynamic> invokeNative(
      String method, Map<String, dynamic>? args) async {
    return GromoreFlutterPlatform.instance.invokeNative(method, args);
  }

  /// 请求 iOS ATT 授权（仅 iOS）
  ///
  /// 返回 true 表示已授权或无需授权
  Future<bool> requestATT() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return true;
    }
    final dynamic result = await invokeNative('requestATT', null);
    return result == true;
  }

  /// 监听广告事件（支持按 adId / adType 过滤）
  StreamSubscription<GromoreAdEvent> listenAdEvents({
    String? adId,
    GromoreAdType? adType,
    required GromoreAdCallback callback,
  }) {
    _ensureEventStreams();
    return adEvents.where((event) {
      final bool idMatch = adId == null || event.adId == adId;
      final bool typeMatch = adType == null || event.adType == adType;
      return idMatch && typeMatch;
    }).listen(callback.handle);
  }

  void _onAdEvent(GromoreAdEvent event) {
    if (event.eventType == GromoreAdEventType.failed ||
        event.eventType == GromoreAdEventType.error) {
      _lastAdErrors[event.adId] = event;
    }
    final shouldUnlockSplashOrientation =
        defaultTargetPlatform == TargetPlatform.iOS &&
            event.adType == GromoreAdType.splash &&
            event.adId == _lockedSplashAdId &&
            _isSplashUnlockEvent(event.eventType);
    if (shouldUnlockSplashOrientation) {
      unawaited(_restoreSplashOrientation(event.adId));
    }
  }

  bool _isSplashUnlockEvent(GromoreAdEventType eventType) {
    switch (eventType) {
      case GromoreAdEventType.failed:
      case GromoreAdEventType.error:
      case GromoreAdEventType.closed:
      case GromoreAdEventType.skipped:
        return true;
      default:
        return false;
    }
  }

  Future<void> _lockSplashOrientation(String adId) async {
    _lockedSplashAdId = adId;
    _activeSplashRestoreOrientations = _splashRestoreOrientations;
    await _setSplashOrientations(const [DeviceOrientation.portraitUp]);
    await _waitForPortraitOrientation();
    if (_lockedSplashAdId != adId || !_adTypesById.containsKey(adId)) {
      throw PlatformException(code: 'show_cancelled', message: '开屏在展示前已关闭或销毁');
    }
  }

  Future<void> _restoreSplashOrientation(String adId) async {
    if (_lockedSplashAdId != adId) return;
    _lockedSplashAdId = null;
    try {
      await _setSplashOrientations(_activeSplashRestoreOrientations);
    } catch (error) {
      GromoreLogger.warn('恢复开屏方向失败: $error', tag: 'ad');
    }
  }

  // 串行发送方向请求，避免上一条广告的异步恢复覆盖下一条广告的竖屏锁定。
  Future<void> _setSplashOrientations(List<DeviceOrientation> orientations) {
    final change = _orientationChanges
        .then((_) => SystemChrome.setPreferredOrientations(orientations));
    _orientationChanges = change.then<void>((_) {}, onError: (Object _) {});
    return change;
  }

  Future<void> _waitForPortraitOrientation() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    final DateTime deadline =
        DateTime.now().add(const Duration(milliseconds: 1200));
    while (DateTime.now().isBefore(deadline)) {
      final views = WidgetsBinding.instance.platformDispatcher.views;
      final Size size = views.isNotEmpty ? views.first.physicalSize : Size.zero;
      if (size.width > 0 && size.height > 0 && size.height >= size.width) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  /// 校验 iOS 初始化参数
  ///
  /// [config] 初始化配置
  PlatformInitResult _validateIos(GromoreConfig config) {
    if ((config.iosAppId ?? '').isEmpty) {
      GromoreLogger.error('iOS appId is missing.', tag: 'init');
      return const PlatformInitResult.failure(
        errorCode: 'missing_ios_app_id',
        errorMessage: 'iOS appId is missing.',
      );
    }
    return const PlatformInitResult.success();
  }

  /// 断言广告类型已启用
  ///
  /// [type] 广告类型
  void _assertAdTypeEnabled(GromoreAdType type) {
    final Set<GromoreAdType> enabledTypes =
        GromoreFlutterPlatform.instance.enabledAdTypes;
    if (!enabledTypes.contains(type)) {
      final message = 'Ad type ${type.value} is not enabled.';
      GromoreLogger.warn(message, tag: 'ad');
      throw StateError(message);
    }
  }
}
