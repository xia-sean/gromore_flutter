# 真机广告验证

真实广告已由接入方在其他设备验证。本次不重复实测；下面保留可重复运行的集成测试入口。

## 运行

在 example 目录执行，使用测试应用及测试广告位：

```sh
flutter test integration_test/ad_lifecycle_test.dart -d 设备ID \
  --dart-define=GM_RUN_REAL_ADS=true \
  --dart-define=GM_APP_ID=测试AppId \
  --dart-define=GM_REWARD_ID=激励广告位 \
  --dart-define=GM_BANNER_ID=Banner广告位
```

可选传入 `GM_FEED_ID`、`GM_DRAW_ID`、`GM_SPLASH_ID`、`GM_INTERSTITIAL_ID`、`GM_FULLSCREEN_ID`。未提供广告位的类型会跳过；未打开 GM_RUN_REAL_ADS 时全部跳过，不请求广告。

测试覆盖加载、展示回调、移除视图及重复销毁。弹出式广告需在设备上完成播放并关闭，等待上限为两分钟。Feed/Draw 可在展示期间切换前后台、滚动移出视口，观察视频是否按预期暂停和恢复。SDK、Adapter、广告位和宿主配置需事先完成。

## 服务端回调

激励测试传入 `userId: integration_test`，以及 `customData: {'source': 'integration_test', 'orderId': 'test-order'}`。在测试应用的回调记录中核对 `user_id` 和解码后的 `extra`，并确认服务端已验签、按交易 ID 去重。该固定测试订单不要用于生产发奖。

客户端 `onRewarded` 只能验证客户端回调，不能证明服务端收到 extra。服务端验证结果以业务服务器记录为准。
