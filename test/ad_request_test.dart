import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gromore_flutter/gromore_flutter.dart';

void main() {
  test('invalid sizes and known SDK numeric options fail before native loading',
      () {
    for (final key in ['width', 'height', 'logoHeight', 'splashTimeout']) {
      for (final value in [0, -1, double.nan, double.infinity, 'invalid']) {
        expect(
            () => GromoreAdRequest(placementId: 'test', params: {key: value})
                .toMap(),
            throwsA(isA<ArgumentError>()
                .having((error) => error.name, 'field', key)));
      }
    }
    for (final options in [
      {'orientation': 0},
      {'orientation': 3},
      {'adCount': 0},
      {'adCount': 4},
      {'adCount': 1.5},
      {'volume': -0.1},
      {'volume': 1.1},
      {'rewardAmount': -1},
      {'rewardAmount': 1.5},
      {
        'fullscreenReward': {'rewardAmount': -1}
      },
    ]) {
      expect(
          () => GromoreAdRequest(placementId: 'test', params: options).toMap(),
          throwsArgumentError);
    }
    expect(() => const GromoreAdRequest(placementId: ' ').toMap(),
        throwsArgumentError);
  });
  test('validation follows SDK precedence and allows omitted dimensions', () {
    final map = const GromoreAdRequest(
      placementId: 'test',
      params: {'width': -1},
      extra: {'width': 320.5},
      androidExtra: {'width': -10},
      iosExtra: {'width': -20},
    ).toMap();
    expect(map['width'], 320.5);
    expect(
        () =>
            const GromoreBannerConfig(placementId: 'test').toRequest().toMap(),
        returnsNormally);
    expect(
        () => const GromoreAdRequest(
            placementId: 'test', androidExtra: {'height': -1}).toMap(),
        throwsArgumentError);
  });
  test('sized configs use logical pixels and preserve fractional dimensions',
      () {
    const configs = <GromoreAdConfig>[
      GromoreSplashConfig(placementId: 's', width: 320.5, height: 100.25),
      GromoreBannerConfig(placementId: 'b', width: 320.5, height: 100.25),
      GromoreFeedConfig(placementId: 'f', width: 320.5, height: 100.25),
      GromoreDrawConfig(placementId: 'd', width: 320.5, height: 100.25),
    ];
    for (final config in configs) {
      final request = config.toRequest().toMap();
      expect(request['width'], 320.5);
      expect(request['height'], 100.25);
      expect(request['sizeUnit'], 'logicalPixels');
    }
  });

  test('native size opt-out and legacy requests avoid double conversion', () {
    final map = const GromoreBannerConfig(
      placementId: 'b',
      width: 960,
      height: 300,
      options: GromoreRequestOptions(sizeUnit: GromoreAdSizeUnit.nativePixels),
    ).toRequest().toMap();
    expect(map['width'], 960);
    expect(map['sizeUnit'], 'nativePixels');
    expect(const GromoreAdRequest(placementId: 'legacy').toMap()['sizeUnit'],
        'nativePixels');
    expect(
        const GromoreAdRequest(
          placementId: 'logical',
          sizeUnit: GromoreAdSizeUnit.logicalPixels,
          params: {'width': 320.5},
        ).toMap()['sizeUnit'],
        'logicalPixels');
  });

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

  test('reward config accepts JSON-compatible maps without changing input', () {
    final data = <String, dynamic>{
      'rewardName': '金币',
      'rewardAmount': 1,
      'nested': {
        'items': [true, null, '订单']
      },
    };
    final config = GromoreRewardConfig(placementId: 'reward', customData: data);
    final encoded = config.toRequest().toMap()['customData'];
    expect(encoded, isA<String>());
    expect(jsonDecode(encoded as String), data);
    expect(config.customData, same(data));
    expect(data['nested'], isA<Map>());
  });

  test('extra customData maps reach both envelope and top-level as strings',
      () {
    const data = {'rewardName': '金币', 'rewardAmount': 1};
    const extra = {'userId': '3', 'customData': data};
    final request = const GromoreAdRequest(
      placementId: 'reward',
      extra: extra,
    ).toMap();
    expect(jsonDecode(request['customData'] as String), data);
    expect((request['extra'] as Map)['customData'], request['customData']);
    expect(extra['customData'], data);
  });

  test('platform customData and fullscreen reward maps are normalized', () {
    const android = {
      'customData': {'platform': 'android'}
    };
    const ios = {
      'customData': {'platform': 'ios'}
    };
    final request = const GromoreFullscreenVideoConfig(
      placementId: 'fullscreen',
      androidExtra: android,
      iosExtra: ios,
      options: GromoreRequestOptions(fullscreenReward: {
        'userId': '3',
        'customData': {'orderId': 'ios-order'},
      }),
    ).toRequest().toMap();
    expect(jsonDecode(request['androidExtra']['customData'] as String),
        {'platform': 'android'});
    expect(jsonDecode(request['iosExtra']['customData'] as String),
        {'platform': 'ios'});
    expect(jsonDecode(request['fullscreenReward']['customData'] as String),
        {'orderId': 'ios-order'});
    expect(android['customData'], isA<Map>());
    expect(ios['customData'], isA<Map>());
  });

  test('Map serialization preserves extra override precedence', () {
    final request = const GromoreRewardConfig(
      placementId: 'reward',
      customData: {'source': 'config'},
      extra: {
        'customData': {'source': 'extra'}
      },
      androidExtra: {
        'customData': {'source': 'android'}
      },
    ).toRequest().toMap();
    expect(jsonDecode(request['customData'] as String), {'source': 'extra'});
    expect(jsonDecode(request['androidExtra']['customData'] as String),
        {'source': 'android'});
  });

  test('String customData is preserved verbatim including non-JSON and empty',
      () {
    for (final data in ['', 'raw-data', ' { "order": "金币" } ', '{}']) {
      final request = GromoreRewardConfig(
        placementId: 'reward',
        customData: data,
      ).toRequest().toMap();
      expect(request['customData'], data);
    }
    expect(
        const GromoreRewardConfig(placementId: 'reward')
            .toRequest()
            .toMap()
            .containsKey('customData'),
        isFalse);
    expect(
        const GromoreRewardConfig(placementId: 'reward', customData: {})
            .toRequest()
            .toMap()['customData'],
        '{}');
  });

  test('unsupported customData types and non-JSON map values fail clearly', () {
    for (final data in [
      1,
      false,
      ['order']
    ]) {
      expect(
          () => GromoreRewardConfig(placementId: 'reward', customData: data)
              .toRequest()
              .toMap(),
          throwsArgumentError);
    }
    expect(
        () => GromoreRewardConfig(
              placementId: 'reward',
              customData: {'date': DateTime(2026)},
            ).toRequest().toMap(),
        throwsA(isA<JsonUnsupportedObjectError>()));
  });
}
