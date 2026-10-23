# 🧩 所有广告加载示例

所有广告都遵循“加载 → 监听 → 展示/挂载 → 释放”的基本流程。每个配置至少需要 `placementId`；以下示例只展示常用字段。

开屏、Banner、Feed、Draw 的 Config 宽高默认使用 Flutter 逻辑像素，与 View 保持一致，无需按平台转换。

以下代码默认已完成 SDK 初始化，并导入 `package:flutter/material.dart`、`package:flutter/foundation.dart` 和 `package:gromore_flutter/gromore_flutter.dart`。

各广告示例使用直接操作 `adId` 的方式；也可使用 [GromoreAdController](#gromoreadcontroller) 统一管理加载、监听和销毁，见文末示例。

## 🔄 通用调用模式

视频类和开屏广告遵循：`loadReady → listen → show → 关闭后 dispose`；Banner、信息流和 Draw 广告则是：`等待加载结果 → listen → 挂载视图 → dispose`。

普通 `load()` 只返回实例 ID；视频和开屏的 `loadReady()` 会等待 SDK 可展示，Banner 的 `loadReady()` 只等待加载成功，渲染由挂载 View 触发。下方等待加载的接口内部会处理早于方法响应的加载事件，失败或超时会抛出异常并清理实例，上层调用请用 `try/catch` 处理。

```dart
final adId = await GromoreSplash.loadReady(
  const GromoreSplashConfig(placementId: 'your_placement_id'),
);

final subscription = GromoreSplash.listen(
  adId: adId,
  callback: GromoreAdCallback(
    onShown: (_) {},
    onClosed: (event) => GromoreSplash.dispose(event.adId),
    onFailed: (event) => GromoreSplash.dispose(event.adId),
  ),
);

try {
  await GromoreSplash.show(adId);
} catch (_) {
  await subscription.cancel();
  await GromoreSplash.dispose(adId);
  rethrow;
}
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
- `onRewarded`：客户端激励回调，实际到账由服务端确认。
- `onFailed`：加载或展示失败。

`loaded` 或 `shown` 事件可能携带 `event.data['ecpmInfo']`；部分平台只有展示后才能返回来源信息。

## 🚀 开屏广告

开屏广告不需要 Flutter 视图组件，等待 SDK 可展示后调用 `show`。监听要在 `show` 前建立。

iOS 仅在 `show` 阶段临时锁定竖屏，提前加载不改变页面方向。固定方向的宿主需在初始化时通过 `GromoreConfig.iosSplashRestoreOrientations` 传入原来的方向列表（`DeviceOrientation` 来自 `package:flutter/services.dart`），广告关闭或展示失败后按该列表恢复；默认空列表表示交还系统决定。Flutter 没有读取先前方向限制的公开接口。

```dart
final adId = await GromoreSplash.loadReady(
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
    onClosed: (event) => GromoreSplash.dispose(event.adId),
    onFailed: (event) {
      debugPrint('splash failed: ${event.errorMessage}');
      GromoreSplash.dispose(event.adId);
    },
  ),
);

try {
  await GromoreSplash.show(adId);
} catch (_) {
  await subscription.cancel();
  await GromoreSplash.dispose(adId);
  rethrow;
}
// 关闭后由 onClosed 销毁；页面退出时取消 subscription。
```

## 📺 插屏广告

```dart
final adId = await GromoreInterstitial.loadReady(
  const GromoreInterstitialConfig(
    placementId: 'your_interstitial_placement_id',
  ),
);

final subscription = GromoreInterstitial.listen(
  adId: adId,
  callback: GromoreAdCallback(
    onShown: (_) => debugPrint('interstitial shown'),
    onClosed: (event) => GromoreInterstitial.dispose(event.adId),
    onFailed: (event) {
      debugPrint('interstitial failed: ${event.errorMessage}');
      GromoreInterstitial.dispose(event.adId);
    },
  ),
);

try {
  await GromoreInterstitial.show(adId);
} catch (_) {
  await subscription.cancel();
  await GromoreInterstitial.dispose(adId);
  rethrow;
}
// 关闭后由 onClosed 销毁；页面退出时取消 subscription。
```

## 🎬 全屏视频

```dart
final adId = await GromoreFullscreenVideo.loadReady(
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
    onClosed: (event) => GromoreFullscreenVideo.dispose(event.adId),
    onFailed: (event) {
      debugPrint('fullscreen video failed: ${event.errorMessage}');
      GromoreFullscreenVideo.dispose(event.adId);
    },
  ),
);

try {
  await GromoreFullscreenVideo.show(adId);
} catch (_) {
  await subscription.cancel();
  await GromoreFullscreenVideo.dispose(adId);
  rethrow;
}
// 关闭后由 onClosed 销毁；页面退出时取消 subscription。
```

## 🎁 激励视频

完整流程：加载并等待可展示 → 监听当前实例 → 展示 → 关闭后释放。

```dart
final adId = await GromoreReward.loadReady(
  const GromoreRewardConfig(
    placementId: 'your_reward_video_placement_id',
    userId: 'user_123',
    rewardName: '金币',
    rewardAmount: 1,
    customData: {'orderId': 'order_456'},
  ),
);

final subscription = GromoreReward.listen(
  adId: adId,
  callback: GromoreAdCallback(
    onShown: (_) => debugPrint('Reward video shown'),
    onRewarded: (event) => debugPrint('Reward verified: ${event.rewardVerify}'),
    onClosed: (event) => GromoreReward.dispose(event.adId),
    onFailed: (event) {
      debugPrint('Reward video failed: ${event.errorMessage}');
      GromoreReward.dispose(event.adId);
    },
  ),
);

try {
  await GromoreReward.show(adId);
} catch (_) {
  await subscription.cancel();
  await GromoreReward.dispose(adId);
  rethrow;
}
// show 返回不代表广告关闭；关闭后由 onClosed 销毁实例。
// 页面退出时另行 await subscription.cancel()，并释放未关闭的广告。
```

- `placementId`：填写 GroMore 后台的广告位 ID。
- `userId`：你自己的用户 ID，让服务器知道给谁发奖励。
- `customData`：服务端业务数据，支持 Map 和 String；Map 自动转 JSON 字符串，String 原样传递。Map 内容须可 JSON 序列化。
- 页面退出时取消监听：`await subscription.cancel()`；未关闭的广告也要调用 `dispose(adId)`。

`loadReady()` 会等待 SDK 可展示，加载失败或超时会抛出异常并清理实例；上层调用请用 `try/catch` 处理。监听已按 `adId` 过滤。

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

- 三个 Map 只支持插件已定义的参数。写 `extra: {'orderId': '123'}` 不会把订单号发给服务器；请用 `customData: {'orderId': '123'}`。
- 同一个参数不要重复填写。重名时沿用旧规则：`extra` > 普通字段 > 当前平台 Extra。

平台专属广告请求参数使用 `androidExtra`、`iosExtra`；`options` 用于 `GromoreRequestOptions` 类型的 SDK 扩展选项。初始化配置 `GromoreConfig` 的字段名不变。

### 以前用 GromoreAdRequest 怎么写？

仍然支持，只需把业务数据放到 `customData`：

```dart
final request = GromoreAdRequest(
  placementId: '你的激励广告位ID',
  extra: {
    'userId': 'user_123',
    'customData': {'orderId': 'order_456'},
  },
);
```

这里的 `extra` 是广告参数 Map；服务器收到的 `extra` 是 `customData` 字符串，二者不是一回事。

## 📌 Banner

```dart
final adId = await GromoreBanner.loadReady(
  GromoreBannerConfig(
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
    onClosed: (event) => GromoreBanner.dispose(event.adId),
    onFailed: (event) {
      debugPrint('banner failed: ${event.errorMessage}');
      GromoreBanner.dispose(event.adId);
    },
  ),
);

// 保存 adId 到页面状态，在 build() 中挂载视图，自动复用加载尺寸。
GromoreBannerView(adId: adId);

// 关闭、失败或页面退出时移除视图并释放，不能在挂载后立即销毁。
```

Banner 通过挂载视图展示，不需要调用 `show()`。

## 📰 信息流

```dart
final ids = await GromoreFeed.loadAll(
  GromoreFeedConfig(
    placementId: 'your_feed_placement_id',
    width: 360,
    height: 640,
    adCount: 1,
  ),
);
final adId = ids.first;

final subscription = GromoreFeed.listen(
  adId: adId,
  callback: GromoreAdCallback(
    onRendered: (_) => debugPrint('feed rendered'),
    onShown: (_) => debugPrint('feed shown'),
    onClosed: (event) => GromoreFeed.dispose(event.adId),
    onFailed: (event) {
      debugPrint('feed failed: ${event.errorMessage}');
      GromoreFeed.dispose(event.adId);
    },
  ),
);

// 保存 adId 到页面状态，在 build() 中挂载视图，自动复用加载尺寸。
GromoreFeedView(adId: adId);

// 关闭、失败或页面退出时移除视图并释放，不能在挂载后立即销毁。
```

信息流关闭操作会回调 `onClosed`。视图默认开启可见性/遮挡检测，也可以传入 `enableVisibility: false` 关闭。

## 🧱 Draw 信息流

```dart
final ids = await GromoreDraw.loadAll(
  GromoreDrawConfig(
    placementId: 'your_draw_placement_id',
    width: 360,
    height: 640,
    adCount: 1,
  ),
);
final adId = ids.first;

final subscription = GromoreDraw.listen(
  adId: adId,
  callback: GromoreAdCallback(
    onRendered: (_) => debugPrint('draw rendered'),
    onShown: (_) => debugPrint('draw shown'),
    onClosed: (event) => GromoreDraw.dispose(event.adId),
    onFailed: (event) {
      debugPrint('draw failed: ${event.errorMessage}');
      GromoreDraw.dispose(event.adId);
    },
  ),
);

// 保存 adId 到页面状态，在 build() 中挂载视图，自动复用加载尺寸。
GromoreDrawView(adId: adId);

// 关闭、失败或页面退出时移除视图并释放，不能在挂载后立即销毁。
```

## 👁️ 视图与可见性

Banner、信息流和 Draw 都需要把加载得到的 `adId` 放入对应视图：

- Banner：`GromoreBannerView`
- 信息流：`GromoreFeedView`
- Draw：`GromoreDrawView`

Config 和 View 的宽高统一使用 Flutter 逻辑像素。View 未填写的宽/高分别复用加载 Config 的对应尺寸，显式填写则覆盖容器尺寸，不会重新请求广告；Config 也未设置的尺寸需在 View 中补齐。插件内部完成 Android px 转换，iOS 使用 pt。旧代码若已乘 devicePixelRatio，请去掉手动转换；也可通过 `options: GromoreRequestOptions(sizeUnit: GromoreAdSizeUnit.nativePixels)` 保留原生单位。底层 `GromoreAdRequest` 默认仍使用原生单位，需自动转换时显式指定 `sizeUnit: GromoreAdSizeUnit.logicalPixels`。

例如 `GromoreBannerView(adId: adId)` 复用加载尺寸；`GromoreBannerView(adId: adId, width: 360)` 只覆盖宽度，高度继续复用。尺寸记录随广告实例销毁而清理。

信息流和 Draw 示例请求单条（`adCount: 1`）。需要多条时使用 `GromoreFeed.loadAll()` / `GromoreDraw.loadAll()`，`adCount` 支持 `1~3`，实际数量以 SDK 为准。保存返回的全部 ID，为每条挂载独立视图，并分别取消订阅和销毁，不能只保留 `ids.first`。

视图默认开启可见性/遮挡检测，需要监听可见比例时可以传入：

```dart
GromoreFeedView(
  adId: adId,
  onVisibilityChanged: (info) {
    debugPrint('${info.visibleFraction}');
  },
);
```

不需要检测时设置 `enableVisibility: false`。模板/Express 由 SDK 渲染；Native 和 Draw 默认使用插件原生自渲染样式，也支持通过 `options.nativeRenderFactoryId` 选择宿主注册的原生渲染工厂；当前没有 Flutter 素材级布局 API。

## 🧹 资源释放

将 `adId` 和 `subscription` 保存到页面，在页面销毁或不再使用广告时执行：

```dart
await subscription.cancel();
await GromoreFlutter.instance.disposeAd(adId);
```

`show()` 返回不代表广告关闭，不能紧接着执行上述清理。关闭/失败回调中已销毁的实例不必再次销毁，但仍需取消订阅；嵌入式广告关闭/失败时还需从 Widget 树移除对应视图。加载期间页面已退出时，也要释放随后返回的全部 ID，不能继续展示。完整页面生命周期处理见 [example](../example/lib/main.dart)。

## GromoreAdController

控制器是可选的，适用于全部广告类型，统一管理广告 ID、事件监听和销毁。使用后无需再单独调用 `listen()` 或保存 `subscription`；SDK 初始化方式不变。

开屏、插屏、全屏视频、激励视频使用 `load → show → dispose`。以激励视频为例：

```dart
late final GromoreAdController controller;
controller = GromoreAdController(
  adType: GromoreAdType.rewardVideo,
  callback: GromoreAdCallback(
    onRewarded: (event) => debugPrint('激励结果: ${event.rewardVerify}'),
    onClosed: (_) => controller.dispose(),
    onFailed: (_) => controller.dispose(),
  ),
);
try {
  await controller.load(const GromoreRewardConfig(placementId: 'reward_id'));
  await controller.show();
} catch (_) {
  await controller.dispose();
  rethrow;
}
// 页面退出时同样调用 controller.dispose()，它会取消监听并释放广告。
```

Banner、信息流和 Draw 使用 `load → 挂载 View → dispose`，不调用 `show()`。以 Banner 为例，加载完成后将视图加入 Widget 树：

```dart
final controller = GromoreAdController(adType: GromoreAdType.banner);
final ids = await controller.load(
  const GromoreBannerConfig(
    placementId: 'banner_id',
    width: 320,
    height: 100,
  ),
);
GromoreBannerView(adId: ids.first);

// 关闭、失败或页面退出时移除视图，再释放控制器。
// await controller.dispose();
```

- `adType` 必须与 Config 对应；信息流使用 `GromoreAdType.native`，Draw 使用 `GromoreAdType.drawNative`。
- `load()` 返回本次全部广告 ID；`adId` 为首条，`adIds` 为全部。Feed/Draw 多条广告需分别挂载 View，控制器会统一释放。
- 加载失败通过 `load()` 抛出异常，调用方仍需 `try/catch`。嵌入式广告的关闭/失败事件可通过 `callback` 处理，视图移除由页面负责。
- 页面退出时调用 `dispose()`。加载中销毁会清理迟到结果，`load()` 会抛出取消错误；销毁后的控制器需重新创建。

## 可选：手动控制 Feed/Draw 视频

```dart
GromoreFeedView(adId: adId, autoManageVideo: false);
await GromoreFlutter.instance.controlVideo(adId, GromoreVideoAction.pause);
```

在原生视图创建后控制。Draw 同理；stop 仅 iOS 支持。原来的 `'pause'` 等字符串仍可使用。

## 可选：使用配置类预缓存

```dart
await GromoreFlutter.instance.preloadAds([
  GromorePreloadRequest(
    config: GromoreRewardConfig(placementId: 'reward_id'),
    iosFactoryId: 'reward_preload',
  ),
]);
```

iOS 需先在宿主注册同名预缓存工厂；Android 忽略 iosFactoryId。工厂额外参数可用 `iosFactoryParams` 传入，在原生 item 的 `factoryParams` 中读取。预缓存不返回 adId，展示仍需正常加载。旧 Map 调用继续支持。

宽高必须是有限正数；adCount 为 1~3，volume 为 0~1。无效值在请求前抛出 ArgumentError。加载超时包含原生响应和就绪等待，已知实例最多额外等待 200ms 清理；迟到实例会继续释放。
