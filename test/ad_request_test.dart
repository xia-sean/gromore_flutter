import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_flutter/gromore_flutter.dart';

void main() {
  test('reward config serializes GroMore server verification parameters', () {
    const config = GromoreRewardConfig(
      placementId: 'reward-placement',
      userId: 'test_user',
      rewardName: '金币',
      rewardAmount: 1,
      customData: '{"orderId":"order-123"}',
      muted: true,
      scenarioId: 'reward-scene',
      orientation: 1,
    );

    expect(config.toRequest().toMap(), containsPair('userId', 'test_user'));
    expect(config.toRequest().toMap(), containsPair('rewardName', '金币'));
    expect(config.toRequest().toMap(), containsPair('rewardAmount', 1));
    expect(config.toRequest().toMap(),
        containsPair('customData', '{"orderId":"order-123"}'));
    expect(config.toRequest().toMap(), containsPair('muted', true));
    expect(
        config.toRequest().toMap(), containsPair('scenarioId', 'reward-scene'));
    expect(config.toRequest().toMap(), containsPair('orientation', 1));
  });

  test('legacy extra keeps its envelope and exposes known fields to native',
      () {
    const extra = <String, dynamic>{
      'userId': 'test_user',
      'rewardName': '金币',
      'rewardAmount': 1,
      'customData': '{"orderId":"order-123"}',
    };
    final map = const GromoreAdRequest(
      placementId: 'reward-placement',
      extra: extra,
    ).toMap();

    expect(map['extra'], extra);
    for (final entry in extra.entries) {
      expect(map[entry.key], entry.value);
    }
  });

  test('platform extras use only the new channel keys', () {
    const options = <String, dynamic>{
      'userId': 'platform-user',
      'customData': 'platform-data',
      'muted': false,
    };
    final map = const GromoreAdRequest(
      placementId: 'placement',
      androidExtra: options,
      iosExtra: options,
    ).toMap();

    expect(map['androidExtra'], options);
    expect(map['iosExtra'], options);
    expect(map.containsKey('customData'), isFalse);
    expect(map.containsKey('androidOptions'), isFalse);
    expect(map.containsKey('iosOptions'), isFalse);
  });

  test('every ad config forwards platform extras', () {
    const android = {'muted': true};
    const ios = {'muted': false};
    const configs = <GromoreAdConfig>[
      GromoreSplashConfig(
          placementId: 'placement', androidExtra: android, iosExtra: ios),
      GromoreRewardConfig(
          placementId: 'placement', androidExtra: android, iosExtra: ios),
      GromoreInterstitialConfig(
          placementId: 'placement', androidExtra: android, iosExtra: ios),
      GromoreFullscreenVideoConfig(
          placementId: 'placement', androidExtra: android, iosExtra: ios),
      GromoreBannerConfig(
          placementId: 'placement', androidExtra: android, iosExtra: ios),
      GromoreFeedConfig(
          placementId: 'placement', androidExtra: android, iosExtra: ios),
      GromoreDrawConfig(
          placementId: 'placement', androidExtra: android, iosExtra: ios),
    ];

    for (final config in configs) {
      expect(config.androidExtra, android);
      expect(config.iosExtra, ios);
      expect(config.toRequest().toMap()['androidExtra'], android);
      expect(config.toRequest().toMap()['iosExtra'], ios);
    }
  });

  test('platform extras do not override ordinary fields', () {
    const config = GromoreRewardConfig(
      placementId: 'placement',
      customData: 'shared',
      androidExtra: {'customData': 'android'},
      iosExtra: {'customData': 'ios'},
    );

    final map = config.toRequest().toMap();
    expect(map['customData'], 'shared');
    expect(map['androidExtra'], {'customData': 'android'});
    expect(map['iosExtra'], {'customData': 'ios'});
  });

  test('extra preserves legacy overrides without replacing request envelope',
      () {
    final map = const GromoreAdRequest(
      placementId: 'placement',
      params: {'userId': 'typed-user', 'muted': false},
      extra: {'userId': 'legacy-user', 'placementId': 'wrong-placement'},
    ).toMap();

    expect(map['userId'], 'legacy-user');
    expect(map['muted'], false);
    expect(map['placementId'], 'placement');
  });

  test('all ad configs forward their supported request fields', () {
    final configs = <GromoreAdConfig>[
      const GromoreSplashConfig(
        placementId: 'placement',
        width: 320,
        height: 480,
        timeoutMillis: 2500,
      ),
      const GromoreInterstitialConfig(placementId: 'placement', muted: false),
      const GromoreFullscreenVideoConfig(
          placementId: 'placement', muted: false),
      const GromoreBannerConfig(placementId: 'placement', muted: false),
      const GromoreFeedConfig(
        placementId: 'placement',
        adCount: 2,
        muted: false,
      ),
      const GromoreDrawConfig(
        placementId: 'placement',
        adCount: 2,
        muted: false,
      ),
    ];

    for (final config in configs) {
      final map = config.toRequest().toMap();
      for (final entry in config.buildParams().entries) {
        expect(map[entry.key], entry.value);
      }
    }
    expect(configs.first.toRequest().toMap()['splashTimeout'], 2500);
  });
}
