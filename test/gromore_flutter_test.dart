import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_flutter/gromore_flutter.dart';
import 'package:gromore_flutter/gromore_flutter_platform_interface.dart';
import 'package:gromore_flutter/gromore_flutter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// 平台接口 Mock 实现（用于单元测试）
class MockGromoreFlutterPlatform
    with MockPlatformInterfaceMixin
    implements GromoreFlutterPlatform {
  @override
  /// 启用的广告类型集合
  Set<GromoreAdType> get enabledAdTypes => const {GromoreAdType.splash};

  @override
  /// 更新启用的广告类型集合（测试占位）
  void updateEnabledAdTypes(Set<GromoreAdType> enabledTypes) {}

  @override
  /// 初始化（测试占位）
  Future<PlatformInitResult> init(GromoreConfig config) async {
    return const PlatformInitResult.success();
  }

  @override
  /// 设置日志开关（测试占位）
  Future<void> setLogEnabled(bool enabled) async {}

  @override
  /// 设置日志级别（测试占位）
  Future<void> setLogLevel(LogLevel level) async {}

  @override
  /// 加载广告（测试占位）
  Future<String> loadAd(GromoreAdType type, GromoreAdRequest request) async {
    return 'mock-ad-id';
  }

  @override
  /// 展示广告（测试占位）
  Future<void> showAd(String adId) async {}

  @override
  /// 销毁广告（测试占位）
  Future<void> disposeAd(String adId) async {}

  @override
  /// 广告事件流（测试占位）
  Stream<dynamic> get adEvents => const Stream<dynamic>.empty();

  @override
  /// 日志事件流（测试占位）
  Stream<dynamic> get logEvents => const Stream<dynamic>.empty();

  @override
  /// 调用原生方法（测试占位）
  Future<dynamic> invokeNative(String method, Map<String, dynamic>? args) async {}
}

/// 单元测试入口
void main() {
  /// 记录初始平台实现
  final GromoreFlutterPlatform initialPlatform =
      GromoreFlutterPlatform.instance;

  test('$MethodChannelGromoreFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelGromoreFlutter>());
  });

  test('init uses platform instance', () async {
    final MockGromoreFlutterPlatform fakePlatform =
        MockGromoreFlutterPlatform();
    GromoreFlutterPlatform.instance = fakePlatform;

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final result = await GromoreFlutter.instance.init(
      const GromoreConfig(
        androidAppId: 'test',
        androidAppName: 'test',
      ),
    );
    debugDefaultTargetPlatformOverride = null;

    expect(result.android.success, isTrue);
  });
}
