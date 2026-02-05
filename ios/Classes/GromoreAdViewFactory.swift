import Foundation
import Flutter
import UIKit

/// GroMore 广告 PlatformView 工厂
final class GromoreAdViewFactory: NSObject, FlutterPlatformViewFactory {
  /// 广告管理器
  private let adManager: GromoreAdManager

  /// 构建工厂
  ///
  /// - Parameter adManager: 广告管理器
  init(adManager: GromoreAdManager) {
    self.adManager = adManager
  }

  /// 创建参数解码器
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  /// 创建 PlatformView
  ///
  /// - Parameters:
  ///   - frame: 视图 frame
  ///   - viewIdentifier: 视图 ID
  ///   - arguments: 创建参数
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    let params = args as? [String: Any] ?? [:]
    let adId = params["adId"] as? String ?? ""
    let adType = params["adType"] as? String
    let width = (params["width"] as? NSNumber)?.doubleValue ?? frame.size.width
    let height = (params["height"] as? NSNumber)?.doubleValue ?? frame.size.height
    return GromoreAdPlatformView(
      frame: CGRect(x: 0, y: 0, width: width, height: height),
      adId: adId,
      adType: adType,
      adManager: adManager
    )
  }
}

/// GroMore 广告 PlatformView 实现
final class GromoreAdPlatformView: NSObject, FlutterPlatformView {
  /// 容器视图
  private let containerView: UIView
  /// 广告实例 ID
  private let adId: String
  /// 广告类型
  private let adType: String?
  /// 广告管理器
  private let adManager: GromoreAdManager

  /// 构建 PlatformView
  ///
  /// - Parameters:
  ///   - frame: 视图 frame
  ///   - adId: 广告实例 ID
  ///   - adType: 广告类型
  ///   - adManager: 广告管理器
  init(
    frame: CGRect,
    adId: String,
    adType: String?,
    adManager: GromoreAdManager
  ) {
    self.containerView = UIView(frame: frame)
    self.adId = adId
    self.adType = adType
    self.adManager = adManager
    super.init()
    adManager.attachAdView(
      adId: adId,
      adType: adType,
      container: containerView,
      width: frame.size.width,
      height: frame.size.height
    )
  }

  /// 返回视图实例
  func view() -> UIView {
    return containerView
  }

  /// 销毁视图
  deinit {
    adManager.detachAdView(adId: adId)
  }
}
