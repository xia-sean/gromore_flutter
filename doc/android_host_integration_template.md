# Android 宿主接入模板

这份文档给 `gromore_flutter` 的 Android 宿主工程提供三套可直接复制的接入模板。

适用对象：

- Flutter 业务 App 的 Android 宿主层
- 需要对单进程 / 多进程 / 隐私同意后初始化做明确区分的接入方

## 1. 先怎么选

按这个判断即可：

- 普通单进程 App：用“模板 A”
- 多进程，且允许启动即初始化：用“模板 B”
- 必须用户同意隐私后再初始化：用“模板 C”

## 2. 模板 A：单进程，Flutter 直接初始化

适合：

- 宿主没有多进程需求
- 不要求 Android 原生先介入初始化

宿主 Android 侧只需要配置 GroMore 基础 manifest 项和你自己的业务配置，Flutter 里正常调用：

```dart
final result = await GromoreFlutter.instance.init(
  const GromoreConfig(
    androidAppId: 'your_android_app_id',
    androidAppName: 'your_android_app_name',
  ),
);
```

说明：

- 这是默认最简单的方式。
- 如果你后面改成多进程，再切到模板 B 或模板 C。

## 3. 模板 B：多进程，启动即原生初始化

适合：

- 宿主本身有多进程
- 允许 SDK 在进程启动时初始化
- 希望 Flutter 不承担“首次初始化时机”

### 3.1 宿主 Manifest 配置

```xml
<application
    android:name=".App">
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

### 3.2 宿主资源文件

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

### 3.3 Flutter 侧

Flutter 可以不再传 Android 的 `appId/appName`：

```dart
final result = await GromoreFlutter.instance.init(
  const GromoreConfig(
    iosAppId: 'your_ios_app_id',
    iosAppName: 'your_ios_app_name',
  ),
);
```

说明：

- 插件会在 Android 进程启动时自动初始化。
- Flutter 侧 `init()` 更像确认/复用原生初始化状态。

## 4. 模板 C：隐私同意后，由宿主原生手动初始化

适合：

- 业务要求“用户未同意隐私前，不要初始化广告 SDK”
- 同时又希望支持多进程

核心原则：

- `AUTO_INIT=false`
- 宿主在隐私同意后调用公开原生 API

### 4.1 Manifest 仍然保留配置，但关闭 AUTO_INIT

```xml
<application
    android:name=".App">
    <meta-data
        android:name="com.gromore.flutter.APP_ID"
        android:value="@string/gromore_android_app_id" />
    <meta-data
        android:name="com.gromore.flutter.APP_NAME"
        android:value="@string/gromore_android_app_name" />
    <meta-data
        android:name="com.gromore.flutter.AUTO_INIT"
        android:value="false" />
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

### 4.2 宿主 Application 模板

```kotlin
package com.example.app

import android.app.Application
import com.gromore.flutter.GromoreFlutterNativeInit

class App : Application() {
  fun initializeGroMoreAfterConsent() {
    GromoreFlutterNativeInit.initializeFromManifest(
      context = this,
      callback = object : GromoreFlutterNativeInit.Callback {
        override fun onSuccess() {
          // 初始化成功
        }

        override fun onFailure(errorCode: String, errorMessage: String) {
          // 初始化失败
        }
      }
    )
  }
}
```

### 4.3 如果仍想复用 manifest 配置，但补充更多初始化参数

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

### 4.4 如果不想把 appId/appName 放 Manifest，也可以原生显式传参

```kotlin
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

原生 `androidOptions` 与 Flutter `GromoreConfig.androidOptions` 使用同一套 key 语义，常用项包括：

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

### 4.5 隐私同意后调用位置建议

可以放在：

- 隐私弹窗同意回调里
- 宿主自己的隐私管理器回调里
- 宿主首页启动流程中，确认已同意后再调用

不要放在：

- Flutter 页面 `initState` 之前又依赖 Flutter 才能决定时机的链路里
- “还没确认用户是否同意”就会执行的原生启动逻辑里

## 5. Flutter 侧该怎么配合

无论模板 B 还是模板 C，Flutter 侧都建议这样理解：

- Flutter 负责广告加载、展示、销毁
- Flutter `init()` 负责兜底和确认状态
- Android 首次初始化时机应由宿主策略决定

因此，如果你已经在宿主原生初始化过 Android，Flutter 侧可以不再传 Android `appId/appName`。

## 6. 宿主如何判断当前初始化状态

Android 宿主原生可调用：

```kotlin
val status = GromoreFlutterNativeInit.getInitializationStatus(this)
```

返回信息通常包含：

- `isInitSuccess`
- `isSdkReady`
- `initInProgress`
- `hasManifestConfig`
- `autoInitEnabled`
- `lastInitSource`
- `lastErrorCode`
- `lastErrorMessage`

Flutter 侧也可以通过：

```dart
final status = await GromoreFlutter.instance.invokeNative(
  'getInitializationStatus',
  null,
);
```

## 7. 推荐结论

如果你是插件接入方，直接按这个结论选：

- 没有多进程：模板 A
- 有多进程，且允许启动即初始化：模板 B
- 有多进程，且必须隐私同意后初始化：模板 C
