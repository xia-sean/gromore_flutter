package com.example.gromore_flutter_example

import android.app.Application
import com.gromore.flutter.GromoreFlutterNativeInit

/**
 * 示例宿主 Application。
 *
 * 作用：
 * 1. 展示业务宿主如何在原生侧接入 gromore_flutter 的公开初始化 API。
 * 2. 当 AUTO_INIT=false 时，可在隐私同意后从这里手动触发初始化。
 */
class ExampleApplication : Application() {
  fun initializeGroMoreAfterConsent(callback: GromoreFlutterNativeInit.Callback? = null) {
    // initializeFromManifest 的第二个参数是 androidOptions（Map），第三个才是 callback。
    GromoreFlutterNativeInit.initializeFromManifest(context = this, callback = callback)
  }

  fun getGroMoreInitializationStatus(): Map<String, Any?> {
    return GromoreFlutterNativeInit.getInitializationStatus(this)
  }
}
