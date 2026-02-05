# gromore_flutter
## 持续更新
GroMore Flutter 插件（Android/iOS，聚合/Pangle）。

## 功能概览

- 支持广告类型：✅开屏、✅插屏、✅全屏视频、✅Banner、✅激励视频、✅信息流（模板/自渲染可选）、✅Draw 信息流
- 多端 AppId/AppName 配置：当前平台缺失会初始化失败，非当前平台会返回 `skipped`
- 日志系统：Debug 默认开启，Release 默认关闭，可手动开关；支持日志级别与日志回调
- 预留 nativeOptions/invokeNative 兜底能力，覆盖平台差异
- 示例工程：每种广告类型一个页面，支持输入真实 appId/代码位

## 架构

- `MethodChannel`：初始化、加载/展示/销毁、日志控制
- `EventChannel`：广告事件、原生日志
- Flutter 侧通过 `GromoreFlutter.instance` 使用插件

## 最低系统版本

- Android：minSdk 24（Android 7.0）
- iOS：12.0

## 状态
当前版本已完成 Flutter 层 API 与原生通道骨架，并完成 GroMore 原生 SDK 接入与广告事件映射。  
SDK 具体版本见下方“当前内置的官方 SDK 版本”。  
如需适配官方 SDK 更新，请联系维护者（微信：yiluocheng / 邮箱：xm_sean@163.com）。

## 安装

在你的 Flutter 项目中添加依赖：

```yaml
dependencies:
  gromore_flutter:
    path: ../gromore_flutter
```

> 发布到 pub.dev 后可改为版本号依赖。

## 快速开始（4 步）
1) 添加依赖（见上方安装）。  
2) 配置平台最小项：Android 权限与 Manifest、iOS Info.plist（如引入其它 ADN，再补各平台专有字段）。  
3) 初始化（iOS 若需 IDFA，先 `requestATT()`）。  
4) 加载并展示广告（见下方“广告加载与展示”）。

## Android/iOS 依赖说明（官方 Maven/Pod）

本插件已按官方 Maven/Pod 接入 GroMore SDK（以官方文档为准，可按需调整版本）。

- Android：`android/build.gradle` 中已添加 Pangle/GroMore Maven 仓库与 SDK 依赖。
- iOS：`ios/gromore_flutter.podspec` 已添加 `BUAdSDK` 与 `CSJMediation` 依赖。

Android 端默认不引入任何 Adapter（仅 GroMore 核心）；可通过 `GM_ADNS` 控制接入平台。

## 当前内置的官方 SDK 版本

以下版本来自插件工程内置依赖（如需调整可修改对应文件）：

**iOS（Pod）**
- GroMore 核心：`Ads-CN-Beta 7.4.0.3`（含 `BUAdSDK/CSJMediation`）

**Android（Maven）**
- GroMore 核心：`com.pangle_beta.cn:mediation-sdk:7.4.0.7`
- 测试工具（Debug）：`com.pangle_beta.cn:mediation-test-tools:7.4.0.7`

**Android（已固定的 Adapter 版本）**
- GDT：`com.pangle_beta.cn:mediation-gdt-adapter:4.662.1532.0`
- 百度：`com.pangle_beta.cn:mediation-baidu-adapter:9.423.3`
- 快手：`com.pangle_beta.cn:mediation-ks-adapter:4.11.20.1.0`
- AdMob：`com.pangle_beta.cn:mediation-admob-adapter:17.2.0.72`
- Sigmob：`com.pangle_beta.cn:mediation-sigmob-adapter:4.25.2.0`

## Android 需要的权限与 Manifest 配置（请按官方文档与业务需要取舍）

以下为示例工程中常见配置，请结合你的隐私合规与业务实际情况取舍：

- 必选/常用权限：
  - `android.permission.INTERNET`
  - `android.permission.ACCESS_NETWORK_STATE`
  - `android.permission.ACCESS_WIFI_STATE`
  - `android.permission.CHANGE_NETWORK_STATE`
  - `android.permission.READ_PHONE_STATE`（部分 SDK 仍需）
- 可选权限（按业务场景与合规要求决定）：
  - `android.permission.ACCESS_COARSE_LOCATION` / `android.permission.ACCESS_FINE_LOCATION`
  - `android.permission.REQUEST_INSTALL_PACKAGES`
  - `android.permission.POST_NOTIFICATIONS`（Android 13 通知）
  - `android.permission.QUERY_ALL_PACKAGES`（用于广告安装检测，需隐私声明）
  - `android.permission.VIBRATE` / `android.permission.RECEIVE_USER_PRESENT`
  - `android.permission.SYSTEM_ALERT_WINDOW` / `android.permission.EXPAND_STATUS_BAR`
  - `android.permission.WRITE_EXTERNAL_STORAGE`（旧版本存储）

Manifest 关键配置示例（按需调整）：

```xml
<application
    android:networkSecurityConfig="@xml/network_config"
    android:requestLegacyExternalStorage="true">

    <provider
        android:name="com.bytedance.sdk.openadsdk.TTFileProvider"
        android:authorities="${applicationId}.TTFileProvider"
        android:exported="false"
        android:grantUriPermissions="true">
        <meta-data
            android:name="android.support.FILE_PROVIDER_PATHS"
            android:resource="@xml/file_paths" />
    </provider>
</application>
```

`res/xml/file_paths.xml` 示例：

```xml
<?xml version="1.0" encoding="utf-8"?>
<paths xmlns:android="http://schemas.android.com/apk/res/android">
    <external-path name="external_storage_root" path="." />
</paths>
```

> 混淆（ProGuard/R8）与支持架构请按官方文档配置；示例工程常见支持 `armeabi-v7a`/`arm64-v8a`。

**Android 平台额外必需配置（按所选 ADN）**
- 若启用 AdMob（含 adapter），需在 `AndroidManifest.xml` 添加：
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy" />
```
- 其他平台如有 AppId/AppKey/权限要求，请按对应 SDK 文档补齐；未引入的平台无需配置。

**Android ADN 选择（GM_ADNS）**
- **默认值**：`GM_ADNS=none`（仅 GroMore 核心，不引入任何 Adapter）。  
- **可选值**：`gdt,baidu,ks,sigmob,admob`，`GM_ADNS=all` 表示全量。
- **配置方式 1：gradle.properties（推荐）**
```
GM_ADNS=gdt,baidu
```
- **配置方式 2：Gradle 命令行**
```
./gradlew assembleDebug -PGM_ADNS=gdt,baidu
```
- **配置方式 3：flutter run 环境变量**
- **提示**：环境变量必须前置（如 `GM_ADNS=... flutter run`），不能写成 `flutter run GM_ADNS=...`。
```
GM_ADNS=gdt,baidu flutter run
```

## iOS 需要的 Info.plist 配置（请按官方文档与业务需要取舍）

以下为示例工程中常见配置，请结合你的隐私合规与业务实际情况取舍：

- `NSUserTrackingUsageDescription`（获取 IDFA 的提示文案）
- `NSAppTransportSecurity`（网络访问策略，建议精细化配置域名）
- `NSLocationWhenInUseUsageDescription` / `NSLocationAlwaysUsageDescription`（如使用定位）
- `NSCameraUsageDescription`（如广告落地页需相机）
- `LSApplicationQueriesSchemes`（第三方应用跳转能力）
- `SKAdNetworkItems`（SKAdNetwork 配置列表，按官方文档补齐）

> 若接入多家 ADN（如广点通/快手/百度等），请按对应 SDK 文档补充相关 `Info.plist` 与系统能力配置。

**最小配置说明**
- 仅使用 GroMore 核心时，不需要额外第三方平台（ADN）的 AppId/AppKey/专有字段。
- 只要引入某个平台 SDK/Adapter，就必须补齐该平台要求的 `Info.plist`/权限/系统能力配置（例如 AdMob 的 `GADApplicationIdentifier`）。
- 插件不会自动修改应用侧的 `Info.plist`，这些字段需要接入方手动补充。

## iOS 多 ADN 配置（官方推荐 / 固定版本）

本插件默认只依赖 GroMore 核心（`Ads-CN-Beta/CSJMediation`）。要启用多平台竞价/加载，需要额外引入各 ADN SDK + Adapter。

我们提供两种模式，`官方推荐模式` 和 `固定版本模式`（在你业务工程iOS的 `Podfile` 中配置）：

**注意事项**  
- 官方推荐模式依赖远端接口，网络受限时可能卡住；可用固定版本模式降级。  
- 使用官方推荐模式前需安装插件：`sudo gem install cocoapods-byte-csjm`。  
- 也可用 `CSJM_DISABLE_REMOTE=1` 一键降级（等同 `GM_MODE=fixed`）。  
- 若包含 AdMob（`admob`），iOS 必须在 `Info.plist` 配置 `GADApplicationIdentifier`，否则会直接崩溃。  
- 各平台通常都有自己的 AppId/AppKey/Info.plist/Manifest 要求，请按对应 SDK 文档补齐。

**如何选择（优劣对比）**
- 官方推荐模式（`GM_MODE=official`）
  - **版本含义**：Adapter 版本由官方远端接口推荐并自动匹配。
  - 优点：Adapter 版本与官方后台推荐匹配，兼容性更稳，适配关系更新更快。
  - 缺点：依赖远端接口与网络环境，可能卡住或拉取失败。
- 固定版本模式（`GM_MODE=fixed`）
  - **版本含义**：Adapter 版本按 Podfile 中固定值使用（示例见 `example/ios/Podfile` 的 `ADAPTERS_BETA` 版本表）。
  - 优点：离线可用、可重复构建、安装更稳定。
  - 缺点：版本不自动更新，可能与官方推荐有偏差，需要手动维护。

**1) 官方推荐模式**  
由 `cocoapods-byte-csjm` 插件远端匹配 Adapter 版本。使用 `GM_MODE=official pod install` 开启官方推荐模式；不设置 `GM_MODE` 时默认为 `fixed`。

**2) 固定版本模式（默认，离线兜底）**  
不走远端匹配，直接使用固定的 Adapter 版本。

**ADN 选择（GM_ADNS）**  
- `GM_ADNS` 为白名单，逗号分隔（如 `gdt,baidu`）。  
- `GM_ADNS=all` 表示全量（`gdt,baidu,ks,sigmob,mtg,admob,unity`）；`GM_ADNS=none` 表示仅 GroMore 核心。  
- `GM_ADNS` 为空时取 Podfile 默认值（示例工程默认 `none`）。  
- 建议业务工程显式设置 `GM_ADNS`，避免默认值不清晰。
- **提示**：环境变量必须前置（如 `GM_ADNS=... pod install`），不能写成 `pod install GM_ADNS=...`。

**命令示例**
```bash
# 官方推荐：全量（gdt,baidu,ks,sigmob,mtg,admob,unity）
GM_MODE=official GM_ADNS=all pod install

# 官方推荐：部分平台
GM_MODE=official GM_ADNS=gdt,baidu pod install

# 固定版本：仅 GroMore 核心
GM_MODE=fixed GM_ADNS=none pod install

# 固定版本：只接入 AdMob（需同时配置 iOS GADApplicationIdentifier）
GM_MODE=fixed GM_ADNS=admob pod install
```

## 初始化（完整示例）

**参数说明**
- `androidAppId/androidAppName/iosAppId/iosAppName`：平台 AppId/AppName；当前平台缺失会初始化失败，非当前平台可不填。
- `debug`：是否调试模式（建议 Debug=true，Release=false）。
- `useMediation`：是否启用聚合。
- `enableLog`：日志开关（不传则 Debug 默认开、Release 默认关）。
- `enabledAdTypes`：启用的广告类型集合；未启用的类型会在 `loadAd` 时抛出异常。
  - 支持类型：`splash / interstitial / fullscreenVideo / rewardVideo / native / drawNative / banner`
- `androidOptions/iosOptions`：扩展参数透传给原生（按官方文档/业务需求填写）。

**返回结果**
- `InitResult.android/ios`：分别表示 Android/iOS 的初始化结果；未配置的平台会返回 `skipped`。

**初始化相关方法**
- `requestATT()`：iOS ATT 授权请求（仅 iOS 生效）。
- `init(config)`：初始化 GroMore。
- `setLogEnabled(bool)`：动态开关日志。
- `setLogLevel(LogLevel)`：设置日志级别。
- `GromoreLogger.setPrintNativeLog(bool)`：是否把原生日志输出到控制台。

```dart
import 'package:flutter/foundation.dart';
import 'package:gromore_flutter/gromore_flutter.dart';

// 1) 可选：iOS ATT（仅 iOS 生效）
await GromoreFlutter.instance.requestATT();

// 2) 初始化配置（覆盖所有字段）
final config = GromoreConfig(
  androidAppId: 'your_android_app_id',
  androidAppName: 'your_android_app_name',
  iosAppId: 'your_ios_app_id',
  iosAppName: 'your_ios_app_name',
  debug: kDebugMode,
  useMediation: true,
  enableLog: true, // 不传则 Debug 默认开、Release 默认关
  enabledAdTypes: {
    GromoreAdType.splash,
    GromoreAdType.interstitial,
    GromoreAdType.fullscreenVideo,
    GromoreAdType.rewardVideo,
    GromoreAdType.native,
    GromoreAdType.drawNative,
    GromoreAdType.banner,
  },
  // 透传给原生的扩展参数（按需填写）
  androidOptions: {'custom': 'value'},
  iosOptions: {'custom': 'value'},
);

// 3) 初始化
final result = await GromoreFlutter.instance.init(config);

// 4) 日志开关/级别（可在 init 前后调用）
await GromoreFlutter.instance.setLogEnabled(true);
await GromoreFlutter.instance.setLogLevel(LogLevel.info);
GromoreLogger.setPrintNativeLog(true);

// 5) 结果处理
if (!result.android.success) {
  debugPrint('Android init failed: ${result.android.errorCode} ${result.android.errorMessage}');
}
if (!result.ios.success) {
  debugPrint('iOS init failed: ${result.ios.errorCode} ${result.ios.errorMessage}');
}
```

## 日志

- Debug 模式默认开启；Release 默认关闭，可手动控制。
- 原生日志不会默认重复输出到 Dart 控制台（避免重复），可通过 `setPrintNativeLog(true)` 开启。

```dart
GromoreLogger.setLogEnabled(true);
GromoreLogger.setLogLevel(LogLevel.info);
GromoreLogger.setHandler((event) {
  // 自定义日志处理
});
```

## 查看广告平台来源（ecpmInfo）
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

## 广告加载与展示（示例）

## 1. 事件监听（新事件模型 + 子类事件）

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

## 2. 类型化 Config + Facade（推荐用法）

### 2.1 开屏

```dart
final adId = await GromoreSplash.load(
  const GromoreSplashConfig(
    placementId: 'your_placement_id',
    timeoutMillis: 3500,
  ),
);
await GromoreSplash.show(adId);
```

### 2.2 插屏

```dart
final adId = await GromoreInterstitial.load(
  const GromoreInterstitialConfig(
    placementId: 'your_placement_id',
    orientation: 1, // 竖屏
  ),
);
await GromoreInterstitial.show(adId);
```

### 2.3 全屏视频

```dart
final adId = await GromoreFullscreenVideo.load(
  const GromoreFullscreenVideoConfig(
    placementId: 'your_placement_id',
    orientation: 2, // 横屏
  ),
);
await GromoreFullscreenVideo.show(adId);
```

### 2.4 激励视频

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

### 2.5 信息流 / Draw

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

### 2.6 Banner

```dart
final bannerId = await GromoreBanner.load(
  const GromoreBannerConfig(
    placementId: 'your_placement_id',
    width: 320,
    height: 150,
  ),
);
```

## 3. 视图组件（默认支持可见性/遮挡检测）

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

## 4. 资源释放与订阅管理

- 页面/组件销毁时，建议取消事件订阅，避免重复回调与内存泄漏。  
- 广告不再使用时，调用 `dispose`/`disposeAd` 释放资源（尤其是 Banner/信息流类视图广告）。

```dart
// 取消事件订阅
await subscription.cancel();

// 释放广告资源（任意广告类型均可）
await GromoreFlutter.instance.disposeAd(adId);
// 或者使用类型化 facade（如）
// await GromoreReward.dispose(adId);
```

## 信息流模式说明

- 模板/Express：SDK 返回广告视图，SDK 负责广告 UI 渲染；你将其插入列表/瀑布流。
- 自渲染/Native：SDK 返回素材数据，自定义布局并注册点击区域。
- Android 自渲染仅支持历史代码位；如无历史代码位请使用模板信息流。

## 预览工具（Debug）

仅 Debug 环境使用，需满足 SDK 版本与白名单要求，且上线前移除相关调试代码。

```dart
// Android：打开 GroMore 测试工具
await GromoreFlutter.instance.invokeNative('openTestTool', {});

// iOS：快速预览（需传 rit）
await GromoreFlutter.instance.invokeNative('openTestTool', {
  'rit': 'your_rit',
  'info': {
    // 可选参数，按官方文档配置
  }
});
```

## 示例工程

`example/` 提供完整 UI：每种广告类型一个页面，可加载/展示/销毁，并展示日志与状态。

步骤：
1. 运行 example
2. 在「设置」页输入 AppId/AppName
3. 在对应广告页输入代码位，点击加载/展示

示例默认值（仅用于演示）：
- Android AppId：`5786586`
- Android 开屏代码位：`103864669`
- iOS AppId：`5786645`
- iOS 开屏代码位：`103866437`
