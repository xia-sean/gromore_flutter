# gromore_flutter_example

示例工程（展示新 API 与事件/视图用法）。

## 0. iOS 多 ADN 配置（官方推荐 / 固定版本）

示例工程的 `example/ios/Podfile` 支持两种模式，通过环境变量控制。  
**默认不引入其它 ADN（仅 GroMore 核心）**，如需接入其它平台请使用 `GM_ADNS` 指定。  
Android 端也默认不引入 Adapter（仅 GroMore 核心），可通过 `GM_ADNS` 选择平台。

**注意事项**
- 官方推荐模式依赖远端匹配，网络受限时可能卡住；可切换到固定版本模式。  
- 官方推荐模式需安装插件：`sudo gem install cocoapods-byte-csjm`。  
- 也可用 `CSJM_DISABLE_REMOTE=1` 一键降级（等同 `GM_MODE=fixed`）。  
- 若包含 AdMob（`admob`），iOS 必须在 `Info.plist` 配置 `GADApplicationIdentifier`，否则会直接崩溃。
- 未引入的平台无需配置其 `Info.plist`/权限/系统能力；插件不会自动写入这些字段。

**Android 选择部分 ADN（GM_ADNS）**
- 在 `example/android/gradle.properties` 中添加：
```
GM_ADNS=gdt,baidu
```
- 或命令行临时指定：
```
./gradlew assembleDebug -PGM_ADNS=gdt,baidu
```
```
GM_ADNS=gdt,baidu flutter run
```
- 提示：环境变量必须前置（如 `GM_ADNS=... flutter run`），不能写成 `flutter run GM_ADNS=...`。

**如何选择（优劣对比）**
- 官方推荐模式（`GM_MODE=official`）
  - 优点：Adapter 版本与官方后台推荐匹配，兼容性更稳，适配关系更新更快。
  - 缺点：依赖远端接口与网络环境，可能卡住或拉取失败。
- 固定版本模式（`GM_MODE=fixed`）
  - 优点：离线可用、可重复构建、安装更稳定。
  - 缺点：版本不自动更新，可能与官方推荐有偏差，需要手动维护。

**官方推荐模式**

```bash
GM_MODE=official GM_ADNS=all pod install
```

**固定版本模式（默认，离线兜底）**

```bash
GM_MODE=fixed pod install
```

**可选 ADN 白名单**  
`GM_ADNS` 为空/不设置时 **不引入其它 ADN**（仅 GroMore 核心）。  
`GM_ADNS=all` 表示全量；也可以只选部分平台，例如：
- 提示：环境变量必须前置（如 `GM_ADNS=... pod install`），不能写成 `pod install GM_ADNS=...`。

```bash
GM_MODE=official GM_ADNS=gdt,baidu pod install
```

只接入 AdMob（需同时配置 iOS `GADApplicationIdentifier`）：

```bash
GM_MODE=fixed GM_ADNS=admob pod install
```

## 运行示例工程（Android / iOS）

### Android

```bash
cd example
flutter pub get
flutter run
```

### iOS

```bash
cd example
flutter pub get
cd ios

# 官方推荐模式
GM_MODE=official GM_ADNS=all pod install

# 固定版本模式（默认，离线兜底）
GM_MODE=fixed pod install

cd ..
flutter run
```

运行后在应用内填写 AppId/AppName 与代码位，再进行加载/展示测试。


## 1. 初始化

```dart
import 'package:gromore_flutter/gromore_flutter.dart';

final config = GromoreConfig(
  androidAppId: 'your_android_app_id',
  androidAppName: 'your_android_app_name',
  iosAppId: 'your_ios_app_id',
  iosAppName: 'your_ios_app_name',
  debug: true,
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
);

final result = await GromoreFlutter.instance.init(config);
```

如需请求 iOS ATT：

```dart
final granted = await GromoreFlutter.instance.requestATT();
```

## 2. 事件监听（新事件模型 + 子类事件）

推荐使用类型化回调：

```dart
final subscription = GromoreFlutter.instance.listenAdEvents(
  adType: GromoreAdType.rewardVideo,
  callback: GromoreAdCallback(
    onLoaded: (e) => print('loaded: ${e.adId}'),
    onFailed: (e) => print('failed: ${e.errorCode} ${e.errorMessage}'),
    onShown: (e) => print('shown'),
    onClicked: (e) => print('clicked'),
    onClosed: (e) => print('closed'),
    onCompleted: (e) => print('completed'),
    onSkipped: (e) => print('skipped'),
    onRewarded: (e) => print('reward: ${e.rewardName} ${e.rewardAmount}'),
  ),
);
```

也可直接监听事件流：

```dart
GromoreFlutter.instance.adEvents.listen((event) {
  print('event: ${event.eventType} ${event.adId}');
});
```

## 2.1 查看广告平台来源（ecpmInfo）

`loaded/shown` 事件会尽力附带 `data.ecpmInfo`，但仅在 SDK 有展示 eCPM 信息时才返回。  
注意：`loaded` 阶段部分平台可能还拿不到来源，建议以 `shown` 为准；字段也可能为 `null`。

**字段说明（常见字段，实际以平台返回为准）**
- `sdkName`：广告平台/ADN 名称（如 pangle/gdt/baidu/admob 等）。
- `customSdkName`：自定义平台名称（如有）。
- `slotId`：平台侧代码位/广告位 ID。
- `ecpm`：平台回传的 eCPM 数值（单位/精度由平台决定）。
- `reqBiddingType`：请求/竞价类型（int）。
- `levelTag`：瀑布流层级/标签。
- `errorMsg`：获取 eCPM 失败时的错误信息（如有）。
- `requestId`：请求 ID。
- `ritType`：rit 类型/广告类型标识（int）。
- `abTestId`：AB 实验标识。
- `scenarioId`：场景 ID。
- `segmentId`：分群 ID。
- `channel` / `subChannel`：渠道/子渠道标识。
- `customData`：Android 扩展字段（Map）。
- `creativeId`：iOS 创意 ID。
- `subRitType`：iOS 子 rit 类型（int）。

```dart
final subscription = GromoreFlutter.instance.listenAdEvents(
  adType: GromoreAdType.rewardVideo,
  callback: GromoreAdCallback(
    onLoaded: (e) {
      final ecpm = (e.data?['ecpmInfo'] as Map?)?.cast<String, dynamic>();
      if (ecpm == null) {
        debugPrint('loaded: ecpmInfo not available');
        return;
      }
      debugPrint('loaded from: ${ecpm['sdkName']} slot=${ecpm['slotId']} ecpm=${ecpm['ecpm']}');
    },
    onShown: (e) {
      final ecpm = (e.data?['ecpmInfo'] as Map?)?.cast<String, dynamic>();
      if (ecpm == null) {
        debugPrint('shown: ecpmInfo not available');
        return;
      }
      debugPrint(
        'shown from: ${ecpm['sdkName']} slot=${ecpm['slotId']} ecpm=${ecpm['ecpm']} '
        'reqBiddingType=${ecpm['reqBiddingType']} requestId=${ecpm['requestId']}',
      );
    },
  ),
);
```

## 3. 类型化 Config + Facade（推荐用法）

### 3.1 开屏

```dart
final adId = await GromoreSplash.load(
  const GromoreSplashConfig(
    placementId: 'your_placement_id',
    timeoutMillis: 3500,
  ),
);
await GromoreSplash.show(adId);
```

### 3.2 插屏

```dart
final adId = await GromoreInterstitial.load(
  const GromoreInterstitialConfig(
    placementId: 'your_placement_id',
    orientation: 1, // 竖屏
  ),
);
await GromoreInterstitial.show(adId);
```

### 3.3 全屏视频

```dart
final adId = await GromoreFullscreenVideo.load(
  const GromoreFullscreenVideoConfig(
    placementId: 'your_placement_id',
    orientation: 2, // 横屏
  ),
);
await GromoreFullscreenVideo.show(adId);
```

### 3.4 激励视频

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

### 3.5 信息流 / Draw

```dart
final feedId = await GromoreFeed.load(
  const GromoreFeedConfig(
    placementId: 'your_placement_id',
    width: 360,
    height: 640,
    adCount: 1,
  ),
);

final drawId = await GromoreDraw.load(
  const GromoreDrawConfig(
    placementId: 'your_placement_id',
    width: 360,
    height: 640,
    adCount: 1,
  ),
);
```

### 3.6 Banner

```dart
final bannerId = await GromoreBanner.load(
  const GromoreBannerConfig(
    placementId: 'your_placement_id',
    width: 320,
    height: 150,
  ),
);
```

## 4. 视图组件（默认支持可见性/遮挡检测）

```dart
GromoreBannerView(
  adId: bannerId,
  width: 320,
  height: 150,
  onVisibilityChanged: (info) {
    print('visible: ${info.visibleFraction} covered=${info.isCovered}');
  },
);

GromoreFeedView(
  adId: feedId,
  width: 360,
  height: 640,
  onVisibilityChanged: (info) {
    print('visible: ${info.visibleFraction}');
  },
);

GromoreDrawView(
  adId: drawId,
  width: 360,
  height: 640,
);
```

如需关闭可见性检测：

```dart
GromoreBannerView(
  adId: bannerId,
  width: 320,
  height: 150,
  enableVisibility: false,
);
```
