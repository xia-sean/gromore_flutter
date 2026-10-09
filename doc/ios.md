# iOS 配置

## 最小配置

普通接入只需要在 Flutter 初始化时传入 iOS AppId：

```dart
await GromoreFlutter.instance.initialize(
  iosAppId: 'your_ios_app_id',
);
```

插件当前使用 `Ads-CN-Beta 7.8.0.5`，包含 `BUAdSDK` 与 `CSJMediation`。

## ATT / IDFA

只有业务需要 IDFA 或个性化广告授权时才调用 `requestATT()`，并在宿主 `Info.plist` 添加 `NSUserTrackingUsageDescription`。

## 其他 Info.plist 配置

按实际使用场景添加，不要全部复制：

- `SKAdNetworkItems`：按接入的广告平台要求添加。
- `NSLocationWhenInUseUsageDescription`：使用定位时添加。
- `LSApplicationQueriesSchemes`：需要跳转第三方 App 时添加。
- `NSCameraUsageDescription`：广告落地页或业务使用相机时添加。
- `NSBonjourServices`、`NSLocalNetworkUsageDescription`：主要用于 Flutter Debug 调试。

插件已提供 `PrivacyInfo.xcprivacy`；如果宿主 App 自己维护隐私清单，请按所有 SDK 要求合并。

## 第三方 ADN

示例工程默认只接入 GroMore 核心。需要额外 ADN 时，在业务工程 `Podfile` 配置对应 SDK 和 Adapter：

```bash
GM_MODE=fixed GM_ADNS=gdt,baidu pod install
```

也可以使用官方远端匹配模式：

```bash
GM_MODE=official GM_ADNS=gdt,baidu pod install
```

各 ADN 的 AppId、权限和 `Info.plist` 要求以对应平台文档为准。
