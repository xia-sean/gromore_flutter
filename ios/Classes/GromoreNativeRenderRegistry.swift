import BUAdSDK
import UIKit

/// 在主线程注册；宿主使用 SDK 画布提供的素材控件并注册点击区域。
public enum GromoreNativeRenderRegistry {
  /// 自渲染 Feed/Draw 布局回调：广告对象、SDK 画布、尺寸（pt）、广告类型。
  /// adType 为 native/draw_native；在主线程填充画布，不替代 SDK 点击注册。
  public typealias Factory = (BUNativeAd, BUMCanvasView, CGSize, String) -> Void
  /// 返回 SDK preloadAdsWithInfos 接受的原生 info 对象；由宿主按 SDK 协议构建。
  public typealias PreloadInfoFactory = ([String: Any]) -> Any
  /// 自渲染 Banner 布局回调，接收 SDK 画布和尺寸（pt）。
  public typealias BannerFactory = (BUMCanvasView, CGSize) -> Void
  private static var factories: [String: Factory] = [:]
  private static var preloadFactories: [String: PreloadInfoFactory] = [:]
  private static var banners: [String: BannerFactory] = [:]
  /// 主线程注册 Feed/Draw 工厂，加载前调用；同 ID 会替换原工厂。
  public static func register(_ id: String, factory: @escaping Factory) { factories[id] = factory }
  /// 主线程注册 Banner 工厂，请求通过 options.nativeRenderFactoryId 选择。
  public static func registerBanner(_ id: String, factory: @escaping BannerFactory) { banners[id] = factory }
  /// 主线程注册批量预缓存 info 工厂；Dart 每项通过 iosFactoryId 选择。
  /// 工厂接收原始请求项，返回当前 SDK preloadAds 接受的 info 对象。
  /// 只有使用批量预缓存时才需要注册，不影响 SDK 初始化或普通广告加载。
  public static func registerPreload(_ id: String, factory: @escaping PreloadInfoFactory) { preloadFactories[id] = factory }
  /// 主线程移除该 ID 的渲染和预缓存工厂，不销毁存活广告实例。
  public static func unregister(_ id: String) { factories[id] = nil; banners[id] = nil; preloadFactories[id] = nil }
  static func preloadFactory(_ id: String) -> PreloadInfoFactory? { preloadFactories[id] }
  static func factory(_ id: String) -> Factory? { factories[id] }
  static func bannerFactory(_ id: String) -> BannerFactory? { banners[id] }
}

struct GromoreAdFailure: Error {
  let code: String
  let message: String
}
