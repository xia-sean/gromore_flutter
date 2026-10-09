# 日志与 Debug 工具

Debug 默认开启日志，Release 默认关闭。常规接入不需要配置。

```dart
await GromoreFlutter.instance.setLogEnabled(true);
await GromoreFlutter.instance.setLogLevel(LogLevel.info);
GromoreLogger.setPrintNativeLog(true);
```

需要导出日志时才开启文件日志：

```dart
await GromoreFlutter.instance.setLogFileEnabled(true);
final path = await GromoreFlutter.instance.exportLogFile(
  fileName: 'gromore_debug_log.txt',
);
```

其他方法包括 `getLogFilePath()`、`readLogFileContent()`、`clearLogFile()` 和 `deleteLogFile()`。

Debug 预览工具仅用于 Debug，并需要满足 SDK 白名单要求：

```dart
await GromoreFlutter.instance.invokeNative('openTestTool', {});
```
