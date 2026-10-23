## 2.2.6

- 修复已知bug。

## 2.2.5

- 修复 iOS 信息流渲染事件重复发送及渲染失败阶段标记；Feed/Draw 重新挂载保留手动暂停状态。
- iOS 开屏仅在展示时锁定竖屏，新增可选的 `iosSplashRestoreOrientations` 恢复宿主方向限制。
- 同步 podspec 插件版本；最低工具链声明更新为 Flutter 3.22 / Dart 3.4。
- 加载超时覆盖完整流程；超时后返回的广告会自动释放，避免一直等待。
- 提前检查广告位、宽高、数量、音量等参数，错误提示更明确。
- 开屏、激励、插屏、全屏和 Banner 新增 `loadReady()`，减少调用代码。
- 新增可选的 `GromoreAdController`，统一管理广告、事件监听和资源释放。
- Feed、Draw 专用视图支持关闭自动视频管理，方便手动控制播放。
- 视频控制支持 `GromoreVideoAction` 枚举，预缓存支持 `GromorePreloadRequest` 配置；旧字符串和 Map 调用继续可用。
- 请求宽高默认使用 Flutter 逻辑像素，Android 自动转换；View 默认复用加载尺寸，也支持单独覆盖宽高。
- 激励 `customData` 支持 Map 和 String；Map 自动转 JSON，String 保持原样。
- 完善广告回调、状态和收益诊断、原生自渲染、预缓存及运行期配置接口，补齐使用注释。
- 同步示例和文档，增加超时、参数校验、尺寸复用和资源清理测试，提供可选的真机广告测试入口。
- 升级注意：Config 中已手动乘 DPR 的宽高请移除转换，或指定 `GromoreAdSizeUnit.nativePixels`；底层 `GromoreAdRequest` 默认仍使用原生单位。SDK 接入及初始化方式不变。

## 2.2.4

- 修复已知bug。

## 2.2.3

- 修复已知bug。

## 2.2.2

- **不兼容变更**：广告请求改用 `androidExtra`、`iosExtra`，移除旧名称；初始化参数不变。
- 修复激励视频回调数据及双端广告参数传递问题。
- 修复 iOS 预览工具参数读取，完善示例、文档和测试。

## 2.2.1

- 修复安卓无法运行的问题。

## 2.2.0

- 精简插件接入流程，精简文档接入指引，做到真正的5分钟可接入
- 升级双端 GroMore SDK：iOS `7.8.0.5`，Android 核心与 Debug 测试工具 `7.8.1.4`。
- 新增 `GromoreFlutter.instance.initialize(...)` 快速初始化入口，复杂场景仍可使用 `init(GromoreConfig)`。
- 新增统一隐私采集配置接口，支持在用户同意隐私协议前关闭可控的个人信息采集。
- 补齐信息流广告关闭事件回调，并修复优量汇开屏广告展示回调缺失问题。

## 2.1.9

- 更新 GroMore SDK 版本：iOS `7.7.0.3`，Android 核心 `7.6.4.3`，Android 测试工具 `7.6.1.1`。
- Android 插件自动合并基础权限与 `TTFileProvider`，减少宿主工程重复配置。
- Android 新增 `manifest meta-data` 原生初始化能力，支持通过资源文件配置 AppId/AppName，并支持多进程启动时自动初始化。
- Android 新增宿主原生公开初始化 API，支持隐私同意后手动初始化。
- 新增 Android 宿主接入模板文档，覆盖单进程、多进程与隐私同意后初始化三种场景。

## 2.1.8

- 更新 GroMore SDK 版本：iOS `7.4.0.1`，Android `7.4.1.4`。
- 新增文件日志能力，支持日志写入文件、读取内容、清空、删除与导出 txt。
- 示例工程增加日志文件调试操作。

## 2.1.7

- 修复iOS端开屏广告横屏问题

## 2.1.4

- 修复已知bug

## 2.1.3

- 提升插件稳定性。
- 修复已知问题。

## 2.1.1

- 在文档中添加二维码和截图。
- 示例应用仅展示当前平台配置项。

## 2.1.0

- 首次公开发布 GroMore Flutter 插件，支持开屏、插屏、全屏视频、激励视频、Banner、信息流和 Draw 信息流。
- 提供初始化、广告加载/展示/销毁及事件回调 API。
- 提供 Android/iOS ADN 接入文档与示例工程。

## 0.0.1

- 初始化插件工程结构。
- 增加 Dart API 与日志系统骨架。
- 增加支持 appId 和代码位输入的示例应用。
- 增加 Android 与 iOS MethodChannel 骨架。
