# 🧩 所有广告加载示例

所有广告都遵循“加载 → 监听 → 展示/挂载 → 释放”的基本流程。每个配置至少需要 `placementId`；以下示例只展示常用字段。

以下代码默认已导入 `package:flutter/foundation.dart` 和 `package:gromore_flutter/gromore_flutter.dart`。

## 🔄 通用调用模式

视频类和开屏广告遵循：`load → listen → show → close/dispose`；Banner、信息流和 Draw 广告则是：`load → listen → 挂载视图 → dispose`。

```dart
final adId = await GromoreSplash.load(
  const GromoreSplashConfig(placementId: 'your_placement_id'),
);

final subscription = GromoreSplash.listen(
  adId: adId,
  callback: GromoreAdCallback(
    onShown: (_) {},
    onClosed: (_) {},
    onFailed: (_) {},
  ),
);

await GromoreSplash.show(adId);
```

## 🧭 Facade 对照

| 类型 | Facade | 配置 | 是否需要视图 |
| --- | --- | --- | --- |
| 开屏 | `GromoreSplash` | `GromoreSplashConfig` | 否 |
| 插屏 | `GromoreInterstitial` | `GromoreInterstitialConfig` | 否 |
| 全屏视频 | `GromoreFullscreenVideo` | `GromoreFullscreenVideoConfig` | 否 |
| 激励视频 | `GromoreReward` | `GromoreRewardConfig` | 否 |
| Banner | `GromoreBanner` | `GromoreBannerConfig` | 是 |
| 信息流 | `GromoreFeed` | `GromoreFeedConfig` | 是 |
| Draw | `GromoreDraw` | `GromoreDrawConfig` | 是 |

## 📡 常用事件

- `onLoaded`：加载成功。
- `onRendered`：模板/信息流渲染完成。
- `onShown`：广告展示。
- `onClicked`：广告点击。
- `onClosed`：广告关闭，包括信息流关闭操作。
- `onCompleted`：视频播放完成。
- `onSkipped`：视频跳过。
- `onRewarded`：激励到账。
- `onFailed`：加载或展示失败。

`loaded` 或 `shown` 事件可能携带 `event.data['ecpmInfo']`；部分平台只有展示后才能返回来源信息。

## 🚀 开屏广告

开屏广告不需要 Flutter 视图组件，加载成功后直接展示。监听要在 `show` 前建立。

```dart
final adId = await GromoreSplash.load(
  const GromoreSplashConfig(
    placementId: 'your_splash_placement_id',
    timeoutMillis: 3000,
  ),
);

final subscription = GromoreSplash.listen(
  adId: adId,
  callback: GromoreAdCallback(
    onShown: (_) => debugPrint('splash shown'),
    onClicked: (_) => debugPrint('splash clicked'),
    onClosed: (_) => debugPrint('splash closed'),
    onFailed: (event) => debugPrint('splash failed: ${event.errorMessage}'),
  ),
);

await GromoreSplash.show(adId);
await subscription.cancel();
await GromoreSplash.dispose(adId);
```

## 📺 插屏广告

```dart
final adId = await GromoreInterstitial.load(
  const GromoreInterstitialConfig(
    placementId: 'your_interstitial_placement_id',
  ),
);

final subscription = GromoreInterstitial.listen(
  adId: adId,
  callback: GromoreAdCallback(
    onShown: (_) => debugPrint('interstitial shown'),
    onClosed: (_) => debugPrint('interstitial closed'),
    onFailed: (event) => debugPrint('interstitial failed: ${event.errorMessage}'),
  ),
);

await GromoreInterstitial.show(adId);
await subscription.cancel();
await GromoreInterstitial.dispose(adId);
```

## 🎬 全屏视频

```dart
final adId = await GromoreFullscreenVideo.load(
  const GromoreFullscreenVideoConfig(
    placementId: 'your_fullscreen_video_placement_id',
  ),
);

final subscription = GromoreFullscreenVideo.listen(
  adId: adId,
  callback: GromoreAdCallback(
    onShown: (_) => debugPrint('fullscreen video shown'),
    onCompleted: (_) => debugPrint('fullscreen video completed'),
    onSkipped: (_) => debugPrint('fullscreen video skipped'),
    onClosed: (_) => debugPrint('fullscreen video closed'),
    onFailed: (event) => debugPrint('fullscreen video failed: ${event.errorMessage}'),
  ),
);

await GromoreFullscreenVideo.show(adId);
await subscription.cancel();
await GromoreFullscreenVideo.dispose(adId);
```

## 🎁 激励视频

完整流程：监听广告事件 → 加载 → 加载成功后展示 → 关闭后释放。

```dart
import 'dart:convert';

final subscription = GromoreReward.listen(
  callback: GromoreAdCallback(
    onLoaded: (event) => GromoreReward.show(event.adId),
    onRewarded: (_) => debugPrint('Reward video completed'),
    onClosed: (event) => GromoreReward.dispose(event.adId),
    onFailed: (event) => debugPrint('Reward video failed：${event.errorMessage}'),
  ),
);

final adId = await GromoreReward.load(
  GromoreRewardConfig(
    placementId: 'your_reward_video_placement_id',
    userId: 'user_123',
    customData: jsonEncode({'orderId': 'order_456'}),
  ),
);
```

- `placementId`：填写 GroMore 后台的广告位 ID。
- `userId`：你自己的用户 ID，让服务器知道给谁发奖励。
- `customData`：你希望服务器收到的业务数据，比如订单号。
- 页面退出时取消监听：`await subscription.cancel()`；未关闭的广告也要调用 `dispose(adId)`。

这个示例的监听会处理所有激励广告事件；同时管理多个广告时，需按 `adId` 区分。

### 服务器会收到什么？

先在 GroMore 广告位设置中配置“服务端激励回调”地址。使用上面的参数后，回调中对应的是：

```text
user_id = user_123
extra = {"orderId":"order_456"}
```

`onRewarded` 只是客户端事件。真正发放奖励时，请由服务器验签并按 `trans_id` 去重。
不要在 GroMore 和广告来源后台重复配置两套奖励发放回调。

### extra、androidExtra、iosExtra 怎么选？

**通常不用填它们，直接使用 `userId`、`customData`、`muted` 等字段即可。**

| 参数 | 一句话解释 |
| --- | --- |
| `extra` | 两端都使用的广告参数 |
| `androidExtra` | 只给 Android 使用的广告参数 |
| `iosExtra` | 只给 iOS 使用的广告参数 |
| `customData` | 要让服务器收到的业务数据 |

例如，只想在 Android 上静音：

```dart
const config = GromoreRewardConfig(
  placementId: '你的激励广告位ID',
  androidExtra: {'muted': true},
);
```

注意两点：

- 三个 Map 只支持插件已定义的参数。写 `extra: {'orderId': '123'}` 不会把订单号发给服务器；请用 `customData: jsonEncode({'orderId': '123'})`。
- 同一个参数不要重复填写。重名时沿用旧规则：`extra` > 普通字段 > 当前平台 Extra。

广告请求只使用 `androidExtra`、`iosExtra`，不再接受旧的 options 名称。
这里改名的是**广告请求参数**，初始化配置 `GromoreConfig` 的字段名不变。

### 以前用 GromoreAdRequest 怎么写？

仍然支持，只需把业务数据放到 `customData`：

```dart
final request = GromoreAdRequest(
  placementId: '你的激励广告位ID',
  extra: {
    'userId': 'user_123',
    'customData': jsonEncode({'orderId': 'order_456'}),
  },
);
```

这里的 `extra` 是广告参数 Map；服务器收到的 `extra` 是 `customData` 字符串，二者不是一回事。

## 📌 Banner

```dart
final adId = await GromoreBanner.load(
  const GromoreBannerConfig(
    placementId: 'your_banner_placement_id',
    width: 320,
    height: 100,
  ),
);

final subscription = GromoreBanner.listen(
  adId: adId,
  callback: GromoreAdCallback(
    onRendered: (_) => debugPrint('banner rendered'),
    onShown: (_) => debugPrint('banner shown'),
    onClicked: (_) => debugPrint('banner clicked'),
    onClosed: (_) => debugPrint('banner closed'),
    onFailed: (event) => debugPrint('banner failed: ${event.errorMessage}'),
  ),
);

// 将 adId 放到页面的 GromoreBannerView 中。
GromoreBannerView(
  adId: adId,
  width: 320,
  height: 100,
);

await subscription.cancel();
await GromoreBanner.dispose(adId);
```

## 📰 信息流

```dart
final adId = await GromoreFeed.load(
  const GromoreFeedConfig(
    placementId: 'your_feed_placement_id',
    width: 360,
    height: 640,
    adCount: 1,
  ),
);

final subscription = GromoreFeed.listen(
  adId: adId,
  callback: GromoreAdCallback(
    onRendered: (_) => debugPrint('feed rendered'),
    onShown: (_) => debugPrint('feed shown'),
    onClosed: (_) => debugPrint('feed closed'),
    onFailed: (event) => debugPrint('feed failed: ${event.errorMessage}'),
  ),
);

GromoreFeedView(
  adId: adId,
  width: 360,
  height: 640,
);

await subscription.cancel();
await GromoreFeed.dispose(adId);
```

信息流关闭操作会回调 `onClosed`。视图默认开启可见性/遮挡检测，也可以传入 `enableVisibility: false` 关闭。

## 🧱 Draw 信息流

```dart
final adId = await GromoreDraw.load(
  const GromoreDrawConfig(
    placementId: 'your_draw_placement_id',
    width: 360,
    height: 640,
    adCount: 1,
  ),
);

final subscription = GromoreDraw.listen(
  adId: adId,
  callback: GromoreAdCallback(
    onRendered: (_) => debugPrint('draw rendered'),
    onShown: (_) => debugPrint('draw shown'),
    onClosed: (_) => debugPrint('draw closed'),
    onFailed: (event) => debugPrint('draw failed: ${event.errorMessage}'),
  ),
);

GromoreDrawView(
  adId: adId,
  width: 360,
  height: 640,
);

await subscription.cancel();
await GromoreDraw.dispose(adId);
```

## 👁️ 视图与可见性

Banner、信息流和 Draw 都需要把加载得到的 `adId` 放入对应视图：

- Banner：`GromoreBannerView`
- 信息流：`GromoreFeedView`
- Draw：`GromoreDrawView`

视图宽高使用 Flutter 逻辑像素；`adCount` 支持 `1~3`，当前插件使用首条返回广告。

视图默认开启可见性/遮挡检测，需要监听可见比例时可以传入：

```dart
GromoreFeedView(
  adId: adId,
  width: 360,
  height: 640,
  onVisibilityChanged: (info) {
    debugPrint('${info.visibleFraction}');
  },
)
```

不需要检测时设置 `enableVisibility: false`。模板/Express 由 SDK 渲染；Native 和 Draw 的自渲染结果会回退到插件默认样式，当前插件不提供 Flutter 自定义 Native 素材布局 API。

## 🧹 资源释放

`subscription.cancel()` 和 `dispose(adId)` 应放在页面销毁、广告关闭或不再使用广告实例的位置。
