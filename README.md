# gromore_flutter

Flutter plugin for GroMore ads mediation on Android and iOS.

This package provides typed Dart APIs, event callbacks, and Flutter views for
common ad formats, including splash, interstitial, fullscreen video, rewarded
video, banner, feed/native, and draw feed.

For the Chinese documentation, see `README.zh-CN.md`.

## Features

- Android and iOS support
- Typed config classes for each ad type
- MethodChannel + EventChannel architecture
- Unified ad event callbacks
- Banner, feed, and draw Flutter widget views
- Runtime log switch and log level control

## Requirements

- Flutter >= 2.12.0
- Dart >= 2.12.0 < 4.0.0
- Android minSdk 24
- iOS 12.0+

## Installation

```yaml
dependencies:
  gromore_flutter: ^2.1.4
```

## Quick Start

```dart
import 'package:flutter/foundation.dart';
import 'package:gromore_flutter/gromore_flutter.dart';

Future<void> setupGromore() async {
  await GromoreFlutter.instance.requestATT();

  final result = await GromoreFlutter.instance.init(
    GromoreConfig(
      androidAppId: 'your_android_app_id',
      androidAppName: 'your_android_app_name',
      iosAppId: 'your_ios_app_id',
      iosAppName: 'your_ios_app_name',
      debug: kDebugMode,
      useMediation: true,
      enableLog: true,
      enabledAdTypes: {
        GromoreAdType.splash,
        GromoreAdType.interstitial,
        GromoreAdType.fullscreenVideo,
        GromoreAdType.rewardVideo,
        GromoreAdType.native,
        GromoreAdType.drawNative,
        GromoreAdType.banner,
      },
    ),
  );

  if (!result.android.success) {
    debugPrint('Android init failed: ${result.android.errorMessage}');
  }
  if (!result.ios.success) {
    debugPrint('iOS init failed: ${result.ios.errorMessage}');
  }
}
```

## Rewarded Video Example

```dart
final adId = await GromoreReward.load(
  const GromoreRewardConfig(
    placementId: 'your_placement_id',
    rewardName: 'coin',
    rewardAmount: 10,
    userId: 'user_001',
  ),
);

await GromoreReward.show(adId);
```

## Banner View Example

```dart
final bannerId = await GromoreBanner.load(
  const GromoreBannerConfig(
    placementId: 'your_placement_id',
    width: 320,
    height: 150,
  ),
);

GromoreBannerView(
  adId: bannerId,
  width: 320,
  height: 150,
);
```

## Event Listening

```dart
final subscription = GromoreFlutter.instance.listenAdEvents(
  adType: GromoreAdType.rewardVideo,
  callback: GromoreAdCallback(
    onLoaded: (e) => print('loaded: ${e.adId}'),
    onFailed: (e) => print('failed: ${e.errorCode} ${e.errorMessage}'),
    onShown: (e) => print('shown'),
    onRewarded: (e) => print('rewarded'),
    onClosed: (e) => print('closed'),
  ),
);

// Call this when the page is disposed.
await subscription.cancel();
```

## Notes

- Configure Android permissions and iOS Info.plist keys based on your selected ad network adapters.
- If AdMob adapter is enabled on iOS, `GADApplicationIdentifier` is required.
- Use debug and test tools only in development builds.

## Example App

See the `example/` folder for a complete integration demo.

## License

MIT
