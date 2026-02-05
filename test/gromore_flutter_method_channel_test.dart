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
  test('loadAd returns adId', () async {
    final adId = await platform.loadAd(
      GromoreAdType.splash,
      const GromoreAdRequest(placementId: 'test'),
    );
    expect(adId, 'mock-ad-id');
  });
}
