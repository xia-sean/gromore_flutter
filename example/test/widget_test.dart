import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_flutter/gromore_flutter.dart';
import 'package:gromore_flutter/gromore_flutter_platform_interface.dart';
import 'package:gromore_flutter_example/main.dart';

class ExamplePlatform extends GromoreFlutterPlatform {
  final events = StreamController<dynamic>.broadcast(sync: true);
  final nativeLogs = StreamController<dynamic>.broadcast(sync: true);
  final shown = <String>[];
  final disposed = <String>[];
  final requests = <Map<String, dynamic>>[];
  Completer<void>? responseGate;
  bool ready = true;
  bool failLoad = false;
  bool failShow = false;
  int nextId = 0;
  final initSteps = <String>[];
  Completer<bool>? attGate;

  @override
  Future<PlatformInitResult> init(GromoreConfig config) async {
    initSteps.add('init');
    return const PlatformInitResult.success();
  }

  @override
  Future<void> setLogEnabled(bool enabled) async {}

  @override
  Future<void> setLogLevel(LogLevel level) async {}

  @override
  Stream<dynamic> get adEvents => events.stream;
  @override
  Stream<dynamic> get logEvents => nativeLogs.stream;

  @override
  Future<String> loadAd(GromoreAdType type, GromoreAdRequest request) async {
    final id = 'example-${nextId++}';
    requests.add(request.toMap());
    events.add({
      'adId': id,
      'adType': type.value,
      'eventType': failLoad ? 'failed' : 'loaded',
      if (failLoad) 'errorCode': 'no_fill',
      if (failLoad)
        'data': {
          'phase': 'load',
          'loadInfo': [
            {
              'adnName': 'test-network',
              'mediationRit': 'source-placement',
              'errCode': 204,
              'errMsg': 'no ad available',
            }
          ],
        },
    });
    // 加载结果先于方法响应，覆盖旧示例会漏掉的事件时序。
    await responseGate?.future;
    return id;
  }

  @override
  Future<dynamic> invokeNative(
      String method, Map<String, dynamic>? args) async {
    if (method == 'requestATT') {
      initSteps.add('ATT');
      return attGate?.future ?? false;
    }
    if (method == 'getAdState') return {'isReady': ready};
    if (method == 'getAdIds') return [args!['adId']];
    return null;
  }

  @override
  Future<void> showAd(String adId) async {
    if (failShow) throw PlatformException(code: 'show_failed');
    shown.add(adId);
  }

  @override
  Future<void> disposeAd(String adId) async => disposed.add(adId);
}

void main() {
  final platform = ExamplePlatform();
  setUpAll(() async {
    GromoreFlutterPlatform.instance = platform;
    // 单例的原生事件订阅应在各 Widget 测试的 FakeAsync Zone 外建立。
    final subscription = GromoreFlutter.instance.listenAdEvents(
      callback: const GromoreAdCallback(),
    );
    await subscription.cancel();
  });
  setUp(() {
    platform.shown.clear();
    platform.disposed.clear();
    platform.requests.clear();
    platform.responseGate = null;
    platform.ready = true;
    platform.failLoad = false;
    platform.failShow = false;
    platform.initSteps.clear();
    platform.attGate = null;
  });

  Future<void> flushEvents(WidgetTester tester) async {
    // 单例事件流可能在测试外的 Zone 创建，需要同时排空真实异步队列。
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  Future<LogStore> openRewardPage(WidgetTester tester) async {
    final config = ExampleConfig()..isInitialized = true;
    final logs = LogStore();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: AdPage(
        title: '激励视频',
        adType: GromoreAdType.rewardVideo,
        config: config,
        logStore: logs,
      )),
    ));
    addTearDown(config.dispose);
    return logs;
  }

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    GromoreLogger.setHandler(null);
  });

  testWidgets('example starts on the settings page', (tester) async {
    await tester.pumpWidget(const GromoreExampleApp());

    expect(find.text('GroMore Flutter Example'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(9));
    expect(find.byType(SettingsPage).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('log export shares a txt attachment with the recorded content',
      (tester) async {
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('gromore-share-'),
    ))!;
    final shared = Completer<MethodCall>();
    messenger.setMockMethodCallHandler(
        pathChannel, (_) async => directory.path);
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      shared.complete(call);
      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    addTearDown(() async {
      await GromoreLogger.deleteLogFile();
      messenger.setMockMethodCallHandler(pathChannel, null);
      messenger.setMockMethodCallHandler(shareChannel, null);
      await directory.delete(recursive: true);
    });
    await tester.runAsync(() async {
      await GromoreLogger.setLogFileEnabled(true);
      GromoreLogger.info('share-file-content');
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LogPage(logStore: LogStore())),
    ));
    await tester.tap(find.text('导出'));
    for (var i = 0; i < 50 && !shared.isCompleted; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump();
    }
    expect(shared.isCompleted, isTrue);
    await tester.runAsync(() async {
      final call = await shared.future;
      expect(call.method, 'shareFiles');
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final paths = List<String>.from(args['paths'] as List);
      expect(paths, hasLength(1));
      expect(paths.single, endsWith('.txt'));
      expect(await File(paths.single).readAsString(),
          contains('share-file-content'));
      expect(args['mimeTypes'], ['text/plain']);
      expect(args['originWidth'], greaterThan(0));
      expect(args['originHeight'], greaterThan(0));
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('log export without a file explains why sharing is unavailable',
      (tester) async {
    await tester.runAsync(GromoreLogger.deleteLogFile);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LogPage(logStore: LogStore())),
    ));
    await tester.tap(find.text('导出'));
    await tester.pump();
    expect(find.text('暂无可导出的日志文件'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'native logs enter the example store once and retain ADN failures',
      (tester) async {
    await tester.pumpWidget(const GromoreExampleApp());
    final store =
        tester.widget<SettingsPage>(find.byType(SettingsPage)).logStore;
    platform.nativeLogs.add({
      'level': 'info',
      'message': 'unique-native-log',
      'tag': 'ad',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    platform.events.add({
      'adId': 'failed-diagnostics',
      'adType': 'banner',
      'eventType': 'failed',
      'errorCode': '10086',
      'errorMessage': 'all networks failed',
      'data': {
        'phase': 'load',
        'loadInfo': [
          {
            'adnName': 'test-network',
            'errCode': 204,
            'errMsg': 'no ad available'
          }
        ],
      },
    });
    await flushEvents(tester);
    expect(store.logs.value.where((log) => log.message == 'unique-native-log'),
        hasLength(1));
    final failure = store.logs.value
        .singleWhere((log) => log.message.contains('all networks failed'));
    expect(failure.message, contains('test-network'));
    expect(failure.message, contains('204'));
    expect(failure.message, contains('no ad available'));
  });

  testWidgets('iOS initialization can cancel or wait for ATT before SDK init',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      // 文件系统不参与本测试，只检查 ATT 和初始化调用顺序。
      final config = ExampleConfig()..logToFileEnabled = false;
      addTearDown(config.dispose);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
        body: SettingsPage(config: config, logStore: LogStore()),
      )));
      expect(find.text('先请求 ATT'), findsNothing);
      final initialize = find.widgetWithText(ElevatedButton, '初始化 SDK');
      await tester.scrollUntilVisible(initialize, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(initialize);
      await tester.pumpAndSettle();
      expect(platform.initSteps, isEmpty);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(platform.initSteps, isEmpty);
      expect(config.isInitialized, isFalse);

      platform.attGate = Completer<bool>();
      await tester.tap(initialize);
      await tester.pumpAndSettle();
      await tester.tap(find.text('请求 ATT').last);
      await tester.pumpAndSettle();
      expect(platform.initSteps, ['ATT']);
      expect(config.isInitialized, isFalse);
      // 系统拒绝授权也应继续初始化；自定义 Alert 的取消才中止流程。
      platform.attGate!.complete(false);
      await flushEvents(tester);
      await tester.pumpAndSettle();
      expect(platform.initSteps, ['ATT', 'init']);
      expect(config.isInitialized, isTrue);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('reward video requires SDK initialization before showing',
      (tester) async {
    await tester.pumpWidget(const GromoreExampleApp());

    await tester.tap(find.text('激励'));
    await tester.pumpAndSettle();

    expect(find.text('激励视频').hitTestable(), findsOneWidget);
    await tester.tap(find.text('展示').hitTestable());
    await tester.pump();

    expect(find.text('请先初始化 SDK'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reward waits for readiness and keeps callbacks until closed',
      (tester) async {
    final logs = await openRewardPage(tester);
    platform.responseGate = Completer<void>();
    platform.ready = false;
    await tester.tap(find.text('展示'));
    await flushEvents(tester);
    expect(platform.requests, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final request = platform.requests.single;
    expect(request['userId'], 'test_user');
    expect(request['rewardName'], '金币');
    expect(request['rewardAmount'], 1);
    expect(jsonDecode(request['customData'] as String),
        {'source': 'flutter_example'});
    platform.responseGate!.complete();
    await flushEvents(tester);
    expect(platform.shown, isEmpty);
    platform.ready = true;
    await tester.pump(const Duration(milliseconds: 60));
    await flushEvents(tester);
    final id = platform.shown.single;
    expect(platform.disposed, isEmpty);
    // showAd 的方法响应先返回，广告还没真正显示时继续 loading。
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('展示中'), findsNothing);
    platform.events.add({
      'adId': id,
      'adType': 'rewardVideo',
      'eventType': 'exposed',
    });
    await flushEvents(tester);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    platform.events.add({
      'adId': id,
      'adType': 'rewardVideo',
      'eventType': 'shown',
    });
    await flushEvents(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('展示中'), findsOneWidget);
    platform.events.add({
      'adId': id,
      'adType': 'rewardVideo',
      'eventType': 'rewarded',
      'data': {'verify': true, 'tradeId': 'trade-1'},
    });
    await flushEvents(tester);
    expect(
        logs.logs.value.any((log) => log.message.contains('trade-1')), isTrue);
    expect(platform.disposed, isEmpty);
    platform.events.add({
      'adId': id,
      'adType': 'rewardVideo',
      'eventType': 'closed',
    });
    await flushEvents(tester);
    expect(platform.disposed, [id]);
    expect(find.text('展示'), findsOneWidget);
  });

  testWidgets('page exit disposes a late load without showing it',
      (tester) async {
    await openRewardPage(tester);
    platform.responseGate = Completer<void>();
    await tester.tap(find.text('展示'));
    await flushEvents(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    platform.responseGate!.complete();
    await flushEvents(tester);
    expect(platform.shown, isEmpty);
    expect(platform.disposed, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('skip releases the ad even when SDK never sends closed',
      (tester) async {
    await openRewardPage(tester);
    await tester.tap(find.text('展示'));
    await flushEvents(tester);
    final id = platform.shown.single;
    platform.events.add({
      'adId': id,
      'adType': 'rewardVideo',
      'eventType': 'skipped',
    });
    await flushEvents(tester);
    expect(platform.disposed, [id]);
    expect(find.text('展示'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    platform.events.add({
      'adId': id,
      'adType': 'rewardVideo',
      'eventType': 'closed',
    });
    await flushEvents(tester);
    expect(platform.disposed, [id]);
  });

  testWidgets('leaving an embedded ad tab releases its video and view',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final config = ExampleConfig()..isInitialized = true;
      addTearDown(config.dispose);
      await tester.pumpWidget(MaterialApp(
          home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
              bottom: const TabBar(tabs: [
            Tab(text: '广告页'),
            Tab(text: '切换页面'),
          ])),
          body: TabBarView(children: [
            AdPage(
                title: 'Draw',
                adType: GromoreAdType.drawNative,
                config: config,
                logStore: LogStore(),
                tabIndex: 0),
            const Text('其他页面'),
          ]),
        ),
      )));
      await tester.tap(find.text('展示'));
      await flushEvents(tester);
      final id = tester.widget<GromoreAdView>(find.byType(GromoreAdView)).adId;
      await tester.tap(find.text('切换页面'));
      await flushEvents(tester);
      await tester.pumpAndSettle();
      expect(platform.disposed, [id]);
      expect(find.byType(GromoreAdView), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('destroy during loading discards the pending result',
      (tester) async {
    await openRewardPage(tester);
    platform.responseGate = Completer<void>();
    await tester.tap(find.text('展示'));
    await flushEvents(tester);
    await tester.tap(find.text('销毁'));
    await flushEvents(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    platform.responseGate!.complete();
    await flushEvents(tester);
    expect(platform.shown, isEmpty);
    expect(platform.disposed, hasLength(1));
    expect(find.text('展示'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('load failure is cleaned up and permits retry', (tester) async {
    final logs = await openRewardPage(tester);
    platform.failLoad = true;
    await tester.tap(find.text('展示'));
    await flushEvents(tester);
    expect(platform.shown, isEmpty);
    expect(platform.disposed, hasLength(1));
    expect(find.text('展示'), findsOneWidget);
    expect(
        logs.logs.value.any((log) =>
            log.message.contains('test-network') &&
            log.message.contains('no ad available')),
        isTrue);
    platform.failLoad = false;
    await tester.tap(find.text('展示'));
    await flushEvents(tester);
    expect(platform.shown, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await flushEvents(tester);
    expect(platform.disposed, hasLength(2));
  });

  testWidgets('show failure disposes the instance', (tester) async {
    await openRewardPage(tester);
    platform.failShow = true;
    await tester.tap(find.text('展示'));
    await flushEvents(tester);
    expect(platform.disposed, hasLength(1));
    expect(find.text('展示'), findsOneWidget);
  });

  for (final type in [
    GromoreAdType.banner,
    GromoreAdType.native,
    GromoreAdType.drawNative
  ]) {
    testWidgets(
        '${type.value} mounts a view without popup show or readiness wait',
        (tester) async {
      // 仅验证 Dart 调用和视图挂载，桌面占位避免依赖测试环境的原生视图。
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        final config = ExampleConfig()..isInitialized = true;
        platform.ready = false;
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: AdPage(
          title: '嵌入式广告',
          adType: type,
          config: config,
          logStore: LogStore(),
          showSize: true,
        ))));
        await tester.tap(find.text('展示'));
        await flushEvents(tester);
        expect(platform.requests, hasLength(1));
        expect(platform.shown, isEmpty);
        expect(find.byType(GromoreAdView), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(platform.requests.single['width'], 400);
        expect(platform.requests.single['height'], 250);
        expect(platform.requests.single['sizeUnit'], 'logicalPixels');
        final view = tester.widget<GromoreAdView>(find.byType(GromoreAdView));
        expect(view.width, isNull);
        expect(view.height, isNull);
        expect(
            tester.getSize(find.byType(GromoreAdView)), const Size(400, 250));
        if (type != GromoreAdType.banner) {
          expect(platform.requests.single['adCount'], 1);
        }
        final id = view.adId;
        final viewElement = tester.element(find.byType(GromoreAdView));
        platform.events.add({
          'adId': id,
          'adType': type.value,
          'eventType': 'rendered',
        });
        await flushEvents(tester);
        // 素材渲染完成不等于已显示到页面。
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        platform.events.add({
          'adId': id,
          'adType': type.value,
          'eventType': 'shown',
        });
        await flushEvents(tester);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.element(find.byType(GromoreAdView)), same(viewElement),
            reason: '收起 loading 必须保留已经挂载的原生广告视图');
        await tester.pumpWidget(const SizedBox.shrink());
        await flushEvents(tester);
        await tester.pump(const Duration(milliseconds: 200));
        expect(platform.disposed, hasLength(1));
        config.dispose();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
