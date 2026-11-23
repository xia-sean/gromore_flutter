package com.gromore.flutter

import android.app.Activity
import android.app.AlertDialog
import android.app.Application
import android.os.Bundle
import android.os.Handler
import android.os.SystemClock

/** 仅跟踪本次 show 之后创建的 SDK 页面，禁止关闭宿主或其他业务 Activity。 */
internal class GromoreRewardPresentation(
  private val host: Activity,
  private val handler: Handler,
  private val valid: () -> Boolean,
  private val application: Application = host.application,
  private val ownsActivity: (Activity) -> Boolean = { isAdActivity(it.javaClass.name) }
) : Application.ActivityLifecycleCallbacks {
  private val activities = linkedSetOf<Activity>()
  private var resumed: Activity? = null
  private var dialog: AlertDialog? = null
  private var reply: ((Boolean) -> Unit)? = null
  private var retry: Runnable? = null
  private var closing = false
  private var stopped = false
  private val closeCallbacks = mutableListOf<() -> Unit>()

  init { application.registerActivityLifecycleCallbacks(this) }

  companion object {
    // 未识别来源安全降级为 SDK 自然关闭，不猜测宿主 Activity 的归属。
    internal fun isAdActivity(name: String): Boolean = listOf(
      "com.bytedance.sdk.openadsdk.", "com.bykv.vk.openvk.",
      "com.qq.e.ads.", "com.kwad.sdk.", "com.baidu.mobads.sdk.",
      "com.sigmob.sdk.", "com.google.android.gms.ads."
    ).any { name.startsWith(it) }
  }

  fun showConfirmation(options: Map<*, *>, completion: (Boolean) -> Unit) {
    check(reply == null) { "Reward confirmation already pending" }
    if (!valid() || stopped || closing) { completion(false); return }
    val title = options["title"] as? String
    val message = options["message"] as? String
    val cancel = options["cancelLabel"] as? String
    val confirm = options["confirmLabel"] as? String
    if (listOf(title, message, cancel, confirm).any { it.isNullOrBlank() })
      throw GromoreAdException("invalid_args", "Reward confirmation text required")
    reply = completion
    val deadline = SystemClock.uptimeMillis() + 180_000
    val work = object : Runnable {
      override fun run() {
        if (reply == null || closing || stopped) return
        if (!valid() || SystemClock.uptimeMillis() >= deadline) { cancelConfirmation(); return }
        val activity = resumed
        if (activity == null || activity.isFinishing || activity.isDestroyed || !activity.hasWindowFocus()) {
          handler.postDelayed(this, 250)
          return
        }
        val alert = AlertDialog.Builder(activity).setTitle(title).setMessage(message)
          .setNegativeButton(cancel) { _, _ -> resolve(false) }
          .setPositiveButton(confirm, null).create()
        dialog = alert
        alert.setOnCancelListener { resolve(false) }
        alert.setOnDismissListener { if (!closing) resolve(false); dialog = null }
        try {
          alert.show()
          alert.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener {
            // 先关闭 Alert，再退出本次记录的 SDK 页面；自然关闭回调可以先到达。
            closing = true
            alert.dismiss()
            resolve(true)
          }
        } catch (_: android.view.WindowManager.BadTokenException) {
          dialog = null
          handler.postDelayed(this, 250)
        }
      }
    }
    retry = work
    work.run()
  }

  private fun resolve(accepted: Boolean) {
    val callback = reply ?: return
    reply = null
    retry?.let { handler.removeCallbacks(it) }
    retry = null
    callback(accepted && valid())
  }

  fun cancelConfirmation() {
    if (closing) return
    resolve(false)
    dialog?.dismiss()
    dialog = null
  }

  /** dispose 回调要等记录的 SDK Activity 销毁，Flutter 才能继续系统分享。 */
  fun closeActivities(completion: () -> Unit) {
    if (stopped) { completion(); return }
    closeCallbacks.add(completion)
    if (!closing) { cancelConfirmation(); closing = true }
    dialog?.dismiss()
    dialog = null
    activities.filter { !it.isFinishing && !it.isDestroyed }.forEach { it.finish() }
    checkClosed()
  }

  private fun checkClosed() {
    if (!closing || stopped || activities.any { !it.isDestroyed }) return
    stopped = true
    application.unregisterActivityLifecycleCallbacks(this)
    resumed = null
    val callbacks = closeCallbacks.toList()
    closeCallbacks.clear()
    callbacks.forEach { it() }
  }

  override fun onActivityCreated(activity: Activity, state: Bundle?) {
    if (activity !== host && ownsActivity(activity)) {
      activities.add(activity)
      if (closing) activity.finish()
    }
  }
  override fun onActivityResumed(activity: Activity) {
    if (activities.contains(activity)) resumed = activity
  }
  override fun onActivityPaused(activity: Activity) { if (resumed === activity) resumed = null }
  override fun onActivityDestroyed(activity: Activity) {
    if (resumed === activity) resumed = null
    activities.remove(activity)
    checkClosed()
  }
  override fun onActivityStarted(activity: Activity) {}
  override fun onActivityStopped(activity: Activity) {}
  override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) {}
}
