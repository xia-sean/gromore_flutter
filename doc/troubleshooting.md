# 排错指南

## 初始化失败

- Android：确认 `androidAppId` 或 Manifest AppId 已配置。
- iOS：确认 `iosAppId` 已传入。
- 多进程：确认 `AUTO_INIT` 与初始化时机符合预期。

## 广告加载失败

确认 AppId 与 placementId 属于同一应用和平台，并检查第三方 ADN 的 SDK、Adapter 和平台配置是否完整。

通过 `onFailed` 或 `GromoreFlutter.instance.logEvents` 查看错误码和错误信息。

## 没有收到展示或关闭事件

确保在 `load` 后、`show` 前建立监听。广告实例销毁后不会继续产生事件。信息流还要确保对应 `Gromore*View` 已经插入 Widget 树。

## iOS 构建问题

修改 Podfile 后重新执行 `pod install`；引入 ADN 后按对应平台补充 `Info.plist` 和 Pod 依赖。

### 模拟器测试启动时报 `TTFFmpeg.framework` 加载失败

运行原生测试时保留 Xcode 默认签名，不要传入 `CODE_SIGNING_ALLOWED=NO`。CocoaPods 会裁剪内嵌 Framework 的架构，需要重新签名才能正常加载。

在 `example/ios` 目录执行，将 `模拟器ID` 替换为本机设备 ID：

```sh
xcodebuild test -workspace Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,id=模拟器ID' \
  -parallel-testing-enabled NO -only-testing:RunnerTests
```

## Android 构建问题

确认 Maven 仓库可以访问 `artifact.bytedance.com`。接入 ADN 时，检查 `GM_ADNS` 是否在命令前设置：

```bash
GM_ADNS=gdt,baidu flutter run
```
