import UIKit

/// 只在本次广告的呈现链上显示业务确认；不创建额外 UIWindow、不生成奖励事件。
final class GromoreRewardConfirmation {
  private let controller: () -> UIViewController?
  private let isValid: () -> Bool
  private let result: (Bool) -> Void
  private let isForeground: () -> Bool
  private let deadline = ProcessInfo.processInfo.systemUptime + 180
  private var retry: DispatchWorkItem?
  private var finishing = false
  private var finished = false
  private var accepted = false
  private var cleanup: [() -> Void] = []
  private(set) var alert: UIAlertController?

  init(title: String, message: String, cancelLabel: String, confirmLabel: String,
       controller: @escaping () -> UIViewController?, isValid: @escaping () -> Bool,
       isForeground: @escaping () -> Bool = { UIApplication.shared.applicationState == .active },
       result: @escaping (Bool) -> Void) {
    self.controller = controller
    self.isValid = isValid
    self.isForeground = isForeground
    self.result = result
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    self.alert = alert
    alert.addAction(UIAlertAction(title: cancelLabel, style: .cancel) { [weak self] _ in
      self?.choose(confirmed: false)
    })
    alert.addAction(UIAlertAction(title: confirmLabel, style: .default) { [weak self] _ in
      self?.choose(confirmed: true)
    })
  }

  func present() {
    guard !finishing, !finished else { return }
    guard isValid(), ProcessInfo.processInfo.systemUptime < deadline else { cancel(); return }
    // 服务器可能在 Safari/后台期间到账，等原生应用恢复后再呈现。
    guard isForeground(), let ad = controller(), ad.presentingViewController != nil,
          let window = ad.viewIfLoaded?.window,
          window.windowScene == nil || window.windowScene?.activationState == .foregroundActive
          else { schedulePresentation(); return }
    var top = ad
    while let next = top.presentedViewController { top = next }
    guard !(top is UIAlertController), !top.isBeingPresented, !top.isBeingDismissed,
          top.transitionCoordinator == nil else { schedulePresentation(); return }
    guard let alert else { cancel(); return }
    top.present(alert, animated: true)
  }

  private func schedulePresentation() {
    let work = DispatchWorkItem { [weak self] in self?.present() }
    retry = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
  }

  /// 按钮回调在 UIAlertController 自动消失之前到达；通道结果必须等弹窗退出。
  func choose(confirmed: Bool) {
    guard !finishing, !finished else { return }
    accepted = confirmed && isValid()
    finishing = true
    retry?.cancel()
    DispatchQueue.main.async { self.dismissAlert() }
  }

  /// 广告自然关闭/业务取消时，同时撤销排队或已显示的业务弹窗。
  func cancel(completion: @escaping () -> Void = {}) {
    if finished { completion(); return }
    cleanup.append(completion)
    accepted = false
    if finishing { return }
    choose(confirmed: false)
  }

  private func dismissAlert() {
    guard let alert, alert.presentingViewController != nil else { complete(); return }
    if (alert.isBeingPresented || alert.isBeingDismissed), let transition = alert.transitionCoordinator,
       transition.animate(alongsideTransition: nil, completion: { _ in self.dismissAlert() }) { return }
    alert.dismiss(animated: false) { self.complete() }
  }

  private func complete() {
    guard !finished else { return }
    finished = true
    alert = nil
    result(accepted && isValid())
    let callbacks = cleanup
    cleanup.removeAll()
    callbacks.forEach { $0() }
  }
}
