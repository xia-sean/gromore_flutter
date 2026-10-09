# Android 配置

普通单进程应用不需要手动修改 Manifest。插件会自动合并基础网络权限、`TTFileProvider` 和初始化 Provider。

## Flutter 侧初始化

```dart
await GromoreFlutter.instance.initialize(
  androidAppId: 'your_android_app_id',
);
```

`androidAppName` 可以省略，插件会读取宿主应用名称。也可以把 AppId 放到宿主 Manifest，此时 Flutter 侧可以省略 `androidAppId`。

## 多进程或隐私同意后初始化

只有需要控制初始化时机时，才在宿主 `AndroidManifest.xml` 配置：

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
        android:value="false" />
</application>
```

- `AUTO_INIT=true`：进程启动时自动初始化。
- `AUTO_INIT=false`：不自动初始化，由 Flutter `init()` 或宿主原生 API 手动初始化。

用户同意隐私协议后，可在宿主原生调用 `GromoreFlutterNativeInit.initializeFromManifest(...)`。

完整宿主模板见：[Android 宿主接入模板](android_host_integration_template.md)。

## 第三方 ADN

默认只引入 GroMore 核心，不引入额外 ADN Adapter。需要接入时，通过 `GM_ADNS` 选择：

```bash
GM_ADNS=gdt,baidu flutter run
```

可选值：`gdt`、`baidu`、`ks`、`sigmob`、`admob`。AdMob 还需要按官方要求添加 Application ID。

## 当前 SDK 版本

- GroMore 核心：`com.pangle_beta.cn:mediation-sdk:7.8.1.4`
- Debug 测试工具：`com.pangle_beta.cn:mediation-test-tools:7.8.1.4`
