<div align="center">

【♻️ 持续更新】一款优质的 GroMore 聚合 Flutter 广告插件，支持多广告类型、事件回调与多 ADN 配置。

![pub](https://img.shields.io/pub/v/gromore_flutter?label=pub&color=blue)
![platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-4CAF50)
![license](https://img.shields.io/badge/license-Source--Available-9C27B0)
![repo](https://img.shields.io/badge/github-xia--sean%2Fgromore__flutter-black)

# 📱 Flutter GroMore Ads

<br/>
<img src="https://raw.githubusercontent.com/xia-sean/gromore_flutter/main/doc/images/wechat_qr.png" width="120" alt="微信二维码" />
<br/>
<br/>

邮箱📬 xm_sean@163.com

</div>

> 中文：本仓库为源码可见项目。允许 fork 仅用于评估、测试、修复问题并通过 Pull Request 回馈主仓库；不允许将本项目或修改版本重新发布为独立插件、SDK、package 或竞品。详见 [LICENSE](LICENSE)、[LICENSE.zh-CN.md](LICENSE.zh-CN.md) 与 [CONTRIBUTING.md](CONTRIBUTING.md)。
>
> English: This repository is source-available. Forks are permitted only for evaluation, testing, bug fixing, and contributing back via pull requests. Republishing this project or any modified version as a separate plugin, SDK, package, or competing product is not permitted. See [LICENSE](LICENSE), [LICENSE.zh-CN.md](LICENSE.zh-CN.md), and [CONTRIBUTING.md](CONTRIBUTING.md).

## 🚀 核心功能

- ✅开屏广告
- ✅插屏广告
- ✅全屏视频
- ✅Banner
- ✅激励视频
- ✅信息流（模板/Express + 内置默认自渲染样式）
- ✅Draw 信息流
- 🏆多端 AppId/AppName 配置：iOS 继续走 Flutter 显式传参；Android 支持 Flutter 传参或 `manifest meta-data` 原生配置
- 🏆日志系统：Debug 默认开启，Release 默认关闭，可手动开关；支持日志级别、日志回调、文件落盘与 txt 导出
- 🏆预留 nativeOptions/invokeNative 兜底能力，覆盖平台差异
- 🏆示例工程：每种广告类型一个页面，支持输入真实 appId/代码位
- 🏆文档清晰完整，方法简单

## 📡 示例截图

<div align="center">
  <img src="https://raw.githubusercontent.com/xia-sean/gromore_flutter/main/doc/images/1.jpg" width="19%" />
  <img src="https://raw.githubusercontent.com/xia-sean/gromore_flutter/main/doc/images/2.jpg" width="19%" />
  <img src="https://raw.githubusercontent.com/xia-sean/gromore_flutter/main/doc/images/3.jpg" width="19%" />
  <img src="https://raw.githubusercontent.com/xia-sean/gromore_flutter/main/doc/images/4.jpg" width="19%" />
  <img src="https://raw.githubusercontent.com/xia-sean/gromore_flutter/main/doc/images/5.jpg" width="19%" />
</div>

## 🏡 架构

- `MethodChannel`：初始化、加载/展示/销毁、日志控制
- `EventChannel`：广告事件、原生日志
- Flutter 侧通过 `GromoreFlutter.instance` 使用插件

## 📱 最低系统版本

- Android：minSdk 24（Android 7.0）
- iOS：13.0

## 🕐 状态

当前版本已完成 Flutter 层 API 与原生通道骨架，并完成 GroMore 原生 SDK 接入与广告事件映射。  
SDK 具体版本见下方“当前内置的官方 SDK 版本”。  
如需适配官方 SDK 更新，请联系维护者（微信：yiluocheng / 邮箱：xm_sean@163.com）。

## 💻 安装

在你的 Flutter 项目中添加依赖：

```yaml
dependencies:
  gromore_flutter: ^2.1.9
```

## 🔜 快速开始（4 步）

1. 添加依赖（见上方安装）。
2. 配置平台最小项：Android 权限与 Manifest、iOS Info.plist（如引入其它 ADN，再补各平台专有字段）。
3. 初始化（iOS 若需 IDFA，先 `requestATT()`）。
4. 加载并展示广告（见下方“广告加载与展示”）。

## ⚠️ Android 接入先看这里

如果你是 Android 宿主接入方，先按这 3 种场景选：

- 单进程普通 App：直接用 Flutter `init(config)`，在 Dart 里传 `androidAppId/androidAppName`
- 多进程，且允许启动即初始化：在宿主 `AndroidManifest.xml` 里配置 meta-data `com.gromore.flutter.AUTO_INIT=true`，Flutter 可不再传 Android `appId/appName`
- 必须用户同意隐私后再初始化：在宿主 `AndroidManifest.xml` 里配置 meta-data `com.gromore.flutter.AUTO_INIT=false`，然后由宿主原生调用 `GromoreFlutterNativeInit`

宿主可直接照抄完整模板：
[Android 宿主接入模板](https://github.com/xia-sean/gromore_flutter/blob/main/doc/android_host_integration_template.md)

宿主原生手动初始化的公开 API：

- `GromoreFlutterNativeInit.initializeFromManifest(...)`
- `GromoreFlutterNativeInit.initialize(...)`
- `GromoreFlutterNativeInit.getInitializationStatus(...)`

## 🔗 Android/iOS 依赖说明（官方 Maven/Pod）

本插件已按官方 Maven/Pod 接入 GroMore SDK（以官方文档为准，可按需调整版本）。

- Android：`android/build.gradle` 中已添加 Pangle/GroMore Maven 仓库与 SDK 依赖。
- iOS：`ios/gromore_flutter.podspec` 已添加 `BUAdSDK` 与 `CSJMediation` 依赖。

Android 端默认不引入任何 Adapter（仅 GroMore 核心）；可通过 `GM_ADNS` 控制接入平台。

## 📦 当前内置的官方 SDK 版本

以下版本来自插件工程内置依赖（如需调整可修改对应文件）：

**iOS（Pod）**

- GroMore 核心：`Ads-CN-Beta 7.7.0.3`（含 `BUAdSDK/CSJMediation`）

**Android（Maven）**

- GroMore 核心：`com.pangle_beta.cn:mediation-sdk:7.6.4.3`
- 测试工具（Debug）：`com.pangle_beta.cn:mediation-test-tools:7.6.1.1`

**Android（已固定的 Adapter 版本）**

- GDT：`com.pangle_beta.cn:mediation-gdt-adapter:4.670.1540.0`
- 百度：`com.pangle_beta.cn:mediation-baidu-adapter:9.430.0`
- 快手：`com.pangle_beta.cn:mediation-ks-adapter:4.12.20.1.0`
- AdMob：`com.pangle_beta.cn:mediation-admob-adapter:17.2.0.73`
- Sigmob：`com.pangle_beta.cn:mediation-sigmob-adapter:4.25.9.0`

## 🔐 Android 需要的权限与 Manifest 配置（请按官方文档与业务需要取舍）

插件 Android 库会自动合并以下基础项：

- `android.permission.INTERNET`
- `android.permission.ACCESS_NETWORK_STATE`
- `android.permission.ACCESS_WIFI_STATE`
- `com.bytedance.sdk.openadsdk.TTFileProvider`
- `@xml/pangle_file_paths`
- `GromoreFlutterInitProvider`（可按宿主 `manifest meta-data` 在进程启动时自动初始化 SDK）

**Android 原生初始化配置（推荐用于多进程）**

Android 端现在支持通过宿主应用的 `manifest meta-data` 提供初始化参数，值可以直接写在 manifest 中，也可以引用 `@string/@bool` 资源文件。  
其中 `com.gromore.flutter.AUTO_INIT` 是一个真实可配置的 manifest meta-data key，用来控制“是否启用进程启动阶段自动初始化”，不是文档里的抽象模式名词。典型配置如下：

```xml
<application>
    <meta-data
        android:name="com.gromore.flutter.APP_ID"
        android:value="@string/gromore_android_app_id" />
    <meta-data
        android:name="com.gromore.flutter.APP_NAME"
        android:value="@string/gromore_android_app_name" />
    <meta-data
        android:name="com.gromore.flutter.AUTO_INIT"
        android:value="@bool/gromore_android_auto_init" />
    <meta-data
        android:name="com.gromore.flutter.DEBUG"
        android:value="@bool/gromore_android_debug" />
    <meta-data
        android:name="com.gromore.flutter.USE_MEDIATION"
        android:value="@bool/gromore_android_use_mediation" />
    <meta-data
        android:name="com.gromore.flutter.SUPPORT_MULTI_PROCESS"
        android:value="@bool/gromore_android_support_multi_process" />
</application>
```

```xml
<resources>
    <string name="gromore_android_app_id">your_android_app_id</string>
    <string name="gromore_android_app_name">your_android_app_name</string>
    <bool name="gromore_android_auto_init">true</bool>
    <bool name="gromore_android_debug">false</bool>
    <bool name="gromore_android_use_mediation">true</bool>
    <bool name="gromore_android_support_multi_process">true</bool>
</resources>
```

- 当宿主 manifest meta-data `com.gromore.flutter.AUTO_INIT=true` 时，插件会在进程启动阶段自动初始化 GroMore，适合标准多进程接入。
- 当宿主 manifest meta-data `com.gromore.flutter.AUTO_INIT=false` 时，插件不会在进程启动阶段自动初始化；但 Flutter `init()` 或宿主原生公开 API 仍可继续手动初始化。
- 如果你的业务需要“用户同意隐私后再初始化”，请把宿主 manifest meta-data `com.gromore.flutter.AUTO_INIT` 设为 `false`，然后在宿主原生 `Application`/对应子进程里自行触发初始化，再由 Flutter 侧只负责广告操作。

以下为业务 App 仍需按官方文档与业务需要自行补充/取舍的配置：

- 常用权限：
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

插件未自动注入、业务侧可按需追加的 Manifest 配置示例：

```xml
<application
    android:networkSecurityConfig="@xml/network_config"
    android:requestLegacyExternalStorage="true" />
```

如你需要自定义文件共享路径，也可在应用侧覆盖 `res/xml/pangle_file_paths.xml`：

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

## 🍎 iOS 需要的 Info.plist 配置（请按官方文档与业务需要取舍）

以下为示例工程中常见配置，请结合你的隐私合规与业务实际情况取舍：

- `NSUserTrackingUsageDescription`（获取 IDFA 的提示文案）
- `NSAppTransportSecurity`（网络访问策略，建议精细化配置域名）
- `NSLocationWhenInUseUsageDescription` / `NSLocationAlwaysUsageDescription`（如使用定位）
- `NSCameraUsageDescription`（如广告落地页需相机）
- `LSApplicationQueriesSchemes`（第三方应用跳转能力）
- `SKAdNetworkItems`（SKAdNetwork 配置列表，按官方文档补齐）
- `NSBonjourServices`（调试阶段建议包含 `_dartVmService._tcp`）
- `NSLocalNetworkUsageDescription`（本地网络调试连接说明）

> 若接入多家 ADN（如广点通/快手/百度等），请按对应 SDK 文档补充相关 `Info.plist` 与系统能力配置。

**iOS 17 隐私清单**

- 插件 Pod 已随产物打包 `PrivacyInfo.xcprivacy`。
- 若你的 App 自身也维护了 `PrivacyInfo.xcprivacy`，请将各 SDK 的条目合并到应用自己的清单中，不要只依赖单个 SDK bundle。

**最小配置说明**

- 仅使用 GroMore 核心时，不需要额外第三方平台（ADN）的 AppId/AppKey/专有字段。
- 只要引入某个平台 SDK/Adapter，就必须补齐该平台要求的 `Info.plist`/权限/系统能力配置（例如 AdMob 的 `GADApplicationIdentifier`）。
- 插件不会自动修改应用侧的 `Info.plist`，这些字段需要接入方手动补充。
- 若使用较老 Flutter 版本配合较新 Xcode（如 Xcode 26+）进行 iOS 调试，缺少 `NSBonjourServices` / `NSLocalNetworkUsageDescription` 可能触发 `Info.plist: Could not extract value` 并导致构建脚本失败，建议在业务工程 `Info.plist` 显式补齐。

## 🧩 iOS 多 ADN 配置（官方推荐 / 固定版本）

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

## 🧰 初始化（完整示例）

**参数说明**

- `androidAppId/androidAppName/iosAppId/iosAppName`：平台 AppId/AppName。
- Android 可直接在 Flutter 里传 `androidAppId/androidAppName`，也可改为宿主 `manifest meta-data` 原生配置后在 Flutter 留空。
- iOS 仍需在 Flutter 侧显式传 `iosAppId/iosAppName`；非当前平台可不填。
- `debug`：是否调试模式（建议 Debug=true，Release=false）。
- `useMediation`：是否启用聚合。
- `enableLog`：日志开关（不传则 Debug 默认开、Release 默认关）。
- `enableLogToFile`：是否把日志同时写入应用沙盒文件；写入时同样遵循日志级别阈值规则。
- `enabledAdTypes`：启用的广告类型集合；未启用的类型会在 `loadAd` 时抛出异常。
  - 支持类型：`splash / interstitial / fullscreenVideo / rewardVideo / native / drawNative / banner`
- `androidOptions/iosOptions`：扩展参数透传给原生（按官方文档/业务需求填写）。

**初始化扩展参数（当前已支持的常用键）**

- `androidOptions`
- `supportMultiProcess`、`paid`、`keywords`、`data`、`titleBarTheme`、`allowShowNotify`、`themeStatus`、`ageGroup`、`directDownloadNetworkType`
- `privacy.canUseLocation`、`privacy.latitude`、`privacy.longitude`、`privacy.canUsePhoneState`、`privacy.canUseWifiState`、`privacy.canUseWriteExternal`、`privacy.canUseAndroidId`、`privacy.androidId`、`privacy.canUseOaid`、`privacy.oaid`、`privacy.limitPersonalAds`、`privacy.programmaticRecommend`、`privacy.customAppList`、`privacy.customDevImeis`
- `mediationConfig.publisherDid`、`mediationConfig.openAdnTest`、`mediationConfig.https`、`mediationConfig.localExtra`、`mediationConfig.customLocalConfig`、`mediationConfig.userInfoForSegment`
- `iosOptions`
- `ageGroup`、`userExtData`、`themeStatus`、`customIdfa`、`allowModifyAudioSessionSetting`、`unityDeveloper`
- `privacy.canUseLocation`、`privacy.latitude`、`privacy.longitude`、`privacy.canUseWiFiBSSID`、`privacy.privacyConfig`
- `mediation.limitPersonalAds`、`mediation.limitProgrammaticAds`、`mediation.forbiddenIDFA`、`mediation.allowUploadDeviceInfo`、`mediation.advanceSDKConfigPath`、`mediation.extraDeviceMap`、`mediation.userInfoForSegment`、`mediation.extraData`

**返回结果**

- `InitResult.android/ios`：分别表示 Android/iOS 的初始化结果；未配置的平台会返回 `skipped`。

**初始化相关方法**

- `requestATT()`：iOS ATT 授权请求（仅 iOS 生效）。
- `init(config)`：初始化 GroMore。
- `setLogEnabled(bool)`：动态开关日志。
- `setLogFileEnabled(bool)`：动态开关日志文件写入。
- `setLogLevel(LogLevel)`：设置日志级别阈值，例如 `info` 会记录 `info/warn/error`，`debug` 会记录全部。
- `getLogFilePath()`：获取当前活跃日志文件路径。
- `readLogFileContent()`：读取当前日志文件内容。
- `clearLogFile()`：清空当前日志文件内容。
- `deleteLogFile()`：删除当前日志文件。
- `exportLogFile({String? fileName})`：导出当前日志文件并返回 txt 路径。
- `GromoreLogger.setPrintNativeLog(bool)`：是否把原生日志输出到控制台。

**Android 推荐接法分层**

- 单进程普通 App：直接使用 Flutter `init(config)`。
- 多进程 App：推荐在宿主 `AndroidManifest.xml` 中配置 `com.gromore.flutter.AUTO_INIT=true`。
- 隐私同意后初始化：推荐在宿主 `AndroidManifest.xml` 中配置 `com.gromore.flutter.AUTO_INIT=false`，并由宿主原生在同意后调用 `GromoreFlutterNativeInit.initializeFromManifest(...)` 或 `initialize(...)`。

```dart
import 'package:flutter/foundation.dart';
import 'package:gromore_flutter/gromore_flutter.dart';

// 1) 可选：iOS ATT（仅 iOS 生效）
await GromoreFlutter.instance.requestATT();

// 2) 初始化配置（覆盖所有字段）
final config = GromoreConfig(
  iosAppId: 'your_ios_app_id',
  iosAppName: 'your_ios_app_name',
  debug: kDebugMode,
  useMediation: true,
  enableLog: true, // 不传则 Debug 默认开、Release 默认关
  enableLogToFile: true, // 打开后会持续写入沙盒日志文件
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
  androidOptions: {
    'themeStatus': 0,
    'privacy': {
      'canUseLocation': false,
      'canUsePhoneState': false,
      'canUseOaid': false,
      'limitPersonalAds': true,
    },
  },
  iosOptions: {
    'ageGroup': 0,
    'privacy': {
      'canUseLocation': false,
      'privacyConfig': {
        'ABUPrivacyLimitPersonalAds': 1,
      },
    },
    'mediation': {
      'limitPersonalAds': 1,
    },
  },
);

// 3) 初始化
final result = await GromoreFlutter.instance.init(config);

// Android 若已在宿主 AndroidManifest.xml 中配置 com.gromore.flutter.AUTO_INIT=true，
// Flutter 侧调用 init()
// 只会复用/确认原生初始化状态；未自动初始化时则按当前配置兜底初始化。

// 4) 日志开关/级别（可在 init 前后调用）
await GromoreFlutter.instance.setLogEnabled(true);
await GromoreFlutter.instance.setLogFileEnabled(true);
await GromoreFlutter.instance.setLogLevel(LogLevel.info);
GromoreLogger.setPrintNativeLog(true);

// 4.1) 导出日志文件（适合接到 App 内调试页面）
final path = await GromoreFlutter.instance.exportLogFile(
  fileName: 'gromore_debug_log.txt',
);
debugPrint('exported log path: $path');

// 4.2) 读取/删除日志文件
final currentLogPath = await GromoreFlutter.instance.getLogFilePath();
final logContent = await GromoreFlutter.instance.readLogFileContent();
await GromoreFlutter.instance.clearLogFile();
await GromoreFlutter.instance.deleteLogFile();

// 5) 结果处理
if (!result.android.success) {
  debugPrint('Android init failed: ${result.android.errorCode} ${result.android.errorMessage}');
}
if (!result.ios.success) {
  debugPrint('iOS init failed: ${result.ios.errorCode} ${result.ios.errorMessage}');
}
```

## 🤖 Android 宿主原生手动初始化（隐私同意后）

如果你的业务要求“用户同意隐私协议后再初始化 SDK”，推荐在宿主 Android 原生侧调用公开 API，而不是把首次初始化完全依赖在 Flutter 页面时机上。

完整宿主模板可直接看：
[Android 宿主接入模板](https://github.com/xia-sean/gromore_flutter/blob/main/doc/android_host_integration_template.md)

**方式 1：从 manifest meta-data 读取**

```kotlin
import com.gromore.flutter.GromoreFlutterNativeInit

class App : Application() {
  fun initGroMoreAfterConsent() {
    GromoreFlutterNativeInit.initializeFromManifest(
      context = this,
      callback = object : GromoreFlutterNativeInit.Callback {
        override fun onSuccess() {
          // SDK 已初始化
        }

        override fun onFailure(errorCode: String, errorMessage: String) {
          // 初始化失败
        }
      }
    )
  }
}
```

如果你需要在“以 manifest 为主”的前提下，补充更多 Android 初始化参数，也可以传入 `androidOptions`：

```kotlin
GromoreFlutterNativeInit.initializeFromManifest(
  context = this,
  androidOptions = mapOf(
    GromoreFlutterNativeInit.OPTION_PRIVACY to mapOf(
      "canUseLocation" to false,
      "canUsePhoneState" to false,
      "canUseOaid" to false,
    ),
    GromoreFlutterNativeInit.OPTION_MEDIATION_CONFIG to mapOf(
      "publisherDid" to "your_publisher_did",
    ),
  ),
)
```

**方式 2：宿主原生显式传参**

```kotlin
import com.gromore.flutter.GromoreFlutterNativeInit

GromoreFlutterNativeInit.initialize(
  context = this,
  appId = "your_android_app_id",
  appName = "your_android_app_name",
  debug = BuildConfig.DEBUG,
  useMediation = true,
  androidOptions = mapOf(
    GromoreFlutterNativeInit.OPTION_SUPPORT_MULTI_PROCESS to true,
    GromoreFlutterNativeInit.OPTION_THEME_STATUS to 0,
    GromoreFlutterNativeInit.OPTION_PRIVACY to mapOf(
      "canUseLocation" to false,
      "canUsePhoneState" to false,
      "canUseOaid" to false,
      "limitPersonalAds" to true,
    ),
    GromoreFlutterNativeInit.OPTION_MEDIATION_CONFIG to mapOf(
      "publisherDid" to "your_publisher_did",
    ),
  ),
  callback = object : GromoreFlutterNativeInit.Callback {
    override fun onSuccess() {}

    override fun onFailure(errorCode: String, errorMessage: String) {}
  }
)
```

宿主原生这套 `androidOptions` 与 Flutter `GromoreConfig.androidOptions` 使用同一套 key 语义，常用项包括：

- `OPTION_SUPPORT_MULTI_PROCESS`
- `OPTION_PAID`
- `OPTION_KEYWORDS`
- `OPTION_DATA`
- `OPTION_TITLE_BAR_THEME`
- `OPTION_ALLOW_SHOW_NOTIFY`
- `OPTION_THEME_STATUS`
- `OPTION_AGE_GROUP`
- `OPTION_DIRECT_DOWNLOAD_NETWORK_TYPE`
- `OPTION_INIT_EXTRA`
- `OPTION_PRIVACY`
- `OPTION_MEDIATION_CONFIG`

**公开的 Android meta-data key**

- `GromoreFlutterNativeInit.META_APP_ID`
- `GromoreFlutterNativeInit.META_APP_NAME`
- `GromoreFlutterNativeInit.META_AUTO_INIT` 对应宿主 manifest meta-data key：`com.gromore.flutter.AUTO_INIT`
- `GromoreFlutterNativeInit.META_DEBUG`
- `GromoreFlutterNativeInit.META_USE_MEDIATION`
- `GromoreFlutterNativeInit.META_SUPPORT_MULTI_PROCESS`

**建议**

- 单进程且无隐私前置要求：继续用 Flutter `init(config)` 即可。
- 多进程且允许启动即初始化：在宿主 `AndroidManifest.xml` 中配置 `com.gromore.flutter.AUTO_INIT=true`。
- 多进程且必须隐私同意后初始化：在宿主 `AndroidManifest.xml` 中配置 `com.gromore.flutter.AUTO_INIT=false`，并使用宿主原生手动初始化，Flutter 侧只负责广告操作与兜底确认。

## 📝 日志

- Debug 模式默认开启；Release 默认关闭，可手动控制。
- 原生日志不会默认重复输出到 Dart 控制台（避免重复），可通过 `setPrintNativeLog(true)` 开启。
- 日志级别采用“阈值模式”而不是“精确匹配模式”：选择 `info` 会记录 `info/warn/error`，选择 `debug` 会记录全部。
- `enableLogToFile: true` 后，日志会写入应用沙盒目录下的 `gromore_flutter_logs/gromore_active_log.txt`。
- `getLogFilePath()` 可拿到当前活跃日志文件路径，业务侧可直接展示或二次处理。
- `readLogFileContent()` 可直接读取完整文本内容，适合在 App 内调试页展示。
- `clearLogFile()` 仅清空文件内容；`deleteLogFile()` 会删除文件并关闭文件日志写入，若需继续记录可重新调用 `setLogFileEnabled(true)`。
- 调用 `exportLogFile()` 会复制出一个独立的 `.txt` 文件，并返回文件路径，便于业务侧做分享、上传或反馈。

```dart
GromoreLogger.setLogEnabled(true);
GromoreLogger.setLogLevel(LogLevel.info);
GromoreLogger.setHandler((event) {
  // 自定义日志处理
});
```

## 🔍 查看广告平台来源（ecpmInfo）

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

## 📣 广告加载与展示（示例）

## 🔔 1. 事件监听（新事件模型 + 子类事件）

推荐使用类型化回调：

```dart
final subscription = GromoreFlutter.instance.listenAdEvents(
  adType: GromoreAdType.rewardVideo,
  callback: GromoreAdCallback(
    onLoaded: (e) => print('loaded: ${e.adId}'),
    onRendered: (e) => print("rendered: ${e.data?['renderWidth']} x ${e.data?['renderHeight']}"),
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

`rendered` 事件用于回传模板广告真实渲染尺寸，字段位于 `event.data`：
- `renderWidth`
- `renderHeight`

## 🧩 2. 类型化 Config + Facade（推荐用法）

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

> 当前 Flutter 插件优先展示模板/Express 信息流；若代码位实际返回自渲染信息流，会回退到插件内置的默认原生卡片样式。
> `adCount` 会按官方范围限制在 `1~3`，但当前 Flutter 插件只会使用首条返回广告。
> Android 原生信息流请求宽高遵循官方接口单位 `px`；Flutter 页面展示宽高仍使用逻辑像素，示例工程里已按 `dp * devicePixelRatio` 转换后再发起请求。
> Draw 已改为走原生 SDK 的专用加载链路；若返回自渲染 draw，插件会回退到内置沉浸式默认样式。

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

## 🖼️ 3. 视图组件（默认支持可见性/遮挡检测）

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

## 🧹 4. 资源释放与订阅管理

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

## 🧭 信息流模式说明

- 模板/Express：SDK 返回广告视图，SDK 负责广告 UI 渲染；你将其插入列表/瀑布流。
- 自渲染/Native：官方流程需要媒体侧绑定素材、注册点击区域，并在 iOS 侧刷新 `canvasView` 数据。
- 当前 Flutter 插件已内置一套默认自渲染卡片样式：当代码位返回自渲染信息流时，原生层会自动完成素材绑定、点击注册和基础下载按钮状态联动。
- 当前 Flutter 插件仍未暴露 Flutter 自定义信息流素材布局 API；若你需要完全自定义 UI，仍需继续扩展插件接口。

## 🧪 预览工具（Debug）

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

## 📦 示例工程

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
