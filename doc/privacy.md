# 隐私与信息采集

## 默认接入

普通接入不需要填写 `privacy`。

## 用户同意前限制采集

```dart
const GromoreConfig(
  androidAppId: 'your_android_app_id',
  iosAppId: 'your_ios_app_id',
  privacy: GromorePrivacyConfig.disableAll(),
)
```

该配置会关闭插件可控制的定位、OAID、Android ID、IMEI、WiFi 状态等采集开关，并限制个性化广告相关能力。

也可以按字段控制：

```dart
const GromorePrivacyConfig(
  canUseLocation: false,
  canUseOaid: false,
  canUseAndroidId: false,
  limitPersonalAds: true,
)
```

`androidOptions['privacy']` 和 `iosOptions['privacy']` 用于平台专属字段，常规接入不需要配置这些 Map。

最终仍需结合宿主 App 的隐私政策、权限申请和第三方 ADN 要求进行合规评估。
