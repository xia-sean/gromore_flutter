#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint gromore_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'gromore_flutter'
  s.version          = '2.1.9'
  s.summary          = 'GroMore Flutter plugin for Android/iOS.'
  s.description      = <<-DESC
GroMore Flutter plugin for Android/iOS (Pangle mediation).
                       DESC
  s.homepage         = 'https://www.csjplatform.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Gromore Flutter' => 'xm_sean@163.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  # GroMore 依赖（穿山甲 iOS 融合 SDK）
  s.dependency 'Ads-CN-Beta', '7.7.0.3'
  s.subspec 'BUAdSDK' do |cs|
    cs.dependency 'Ads-CN-Beta/BUAdSDK', '7.7.0.3'
  end
  s.subspec 'CSJMediation' do |cs|
    cs.dependency 'Ads-CN-Beta/CSJMediation', '7.7.0.3'
  end
  s.static_framework = true
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Ship the plugin privacy manifest so the pod output contains the SDK's
  # required reason API declaration on iOS 17+.
  s.resource_bundles = { 'gromore_flutter_privacy' => ['Resources/PrivacyInfo.xcprivacy'] }
end
