import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_flutter/gromore_flutter_method_channel.dart';
import 'package:gromore_flutter/gromore_flutter.dart';

/// MethodChannel 实现测试入口
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 待测试的平台实现
  final MethodChannelGromoreFlutter platform = MethodChannelGromoreFlutter();

  /// Mock 的方法通道
  const MethodChannel channel = MethodChannel('gromore_flutter/methods');

  /// 测试前准备
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'loadAd':
            return 'mock-ad-id';
          case 'init':
            return <String, dynamic>{'success': true};
          default:
            return null;
        }
      },
    );
  });

  /// 测试后清理
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  /// loadAd 返回广告实例 ID
  test('sized Config reaches native with logical units and no Dart scaling',
      () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return 'mock-ad-id';
    });
    await platform.loadAd(
      GromoreAdType.banner,
      const GromoreBannerConfig(
        placementId: 'banner',
        width: 320.5,
        height: 100.25,
      ).toRequest(),
    );
    final request = (captured!.arguments as Map)['request'] as Map;
    expect(request['width'], 320.5);
    expect(request['height'], 100.25);
    expect(request['sizeUnit'], 'logicalPixels');
  });

  test('loadAd returns adId', () async {
    final adId = await platform.loadAd(
      GromoreAdType.splash,
      const GromoreAdRequest(placementId: 'test'),
    );
    expect(adId, 'mock-ad-id');
  });

  test('loadAd sends reward verification fields through MethodChannel',
      () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return 'mock-ad-id';
    });

    await platform.loadAd(
      GromoreAdType.rewardVideo,
      const GromoreRewardConfig(
        placementId: 'reward-placement',
        userId: 'test_user',
        customData: '{"orderId":"order-123"}',
      ).toRequest(),
    );

    expect(captured!.method, 'loadAd');
    final arguments = captured!.arguments as Map;
    expect(arguments['adType'], GromoreAdType.rewardVideo.value);
    final request = arguments['request'] as Map;
    expect(request['userId'], 'test_user');
    expect(request['customData'], '{"orderId":"order-123"}');
  });

  test('invokeNative sends preview options inside args', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return true;
    });

    await platform.invokeNative('openTestTool', {
      'rit': 'reward-placement',
      'info': {'test': 'value'},
    });

    expect(captured!.method, 'invokeNative');
    expect(captured!.arguments, {
      'method': 'openTestTool',
      'args': {
        'rit': 'reward-placement',
        'info': {'test': 'value'},
      },
    });
  });

  test('platform extras reach native using only the new channel keys',
      () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return 'mock-ad-id';
    });

    await platform.loadAd(
      GromoreAdType.rewardVideo,
      const GromoreRewardConfig(
        placementId: 'reward-placement',
        androidExtra: {'customData': 'android-data'},
        iosExtra: {'customData': 'ios-data'},
      ).toRequest(),
    );

    final request = (captured!.arguments as Map)['request'] as Map;
    expect(request['androidExtra'], {'customData': 'android-data'});
    expect(request['iosExtra'], {'customData': 'ios-data'});
  });

  test('Map customData is encoded before crossing the native channel',
      () async {
    final requests = <Map>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      requests.add((call.arguments as Map)['request'] as Map);
      return 'mock-ad-id';
    });
    await platform.loadAd(
        GromoreAdType.rewardVideo,
        const GromoreRewardConfig(
          placementId: 'reward',
          customData: {'orderId': 'typed'},
        ).toRequest());
    await platform.loadAd(
        GromoreAdType.rewardVideo,
        const GromoreAdRequest(placementId: 'reward', extra: {
          'userId': '3',
          'customData': {'rewardName': '金币', 'rewardAmount': 1},
        }));
    await platform.loadAd(
        GromoreAdType.rewardVideo,
        const GromoreAdRequest(
          placementId: 'reward',
          androidExtra: {
            'customData': {'platform': 'android'}
          },
          iosExtra: {
            'customData': {'platform': 'ios'}
          },
        ));
    expect(
        jsonDecode(requests[0]['customData'] as String), {'orderId': 'typed'});
    expect(jsonDecode(requests[1]['customData'] as String),
        {'rewardName': '金币', 'rewardAmount': 1});
    expect(requests[1]['extra']['customData'], requests[1]['customData']);
    expect(jsonDecode(requests[2]['androidExtra']['customData'] as String),
        {'platform': 'android'});
    expect(jsonDecode(requests[2]['iosExtra']['customData'] as String),
        {'platform': 'ios'});
  });
}
