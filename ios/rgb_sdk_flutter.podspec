require 'json'

#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint rgb_sdk_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  baseline_path = File.expand_path('../tool/release_baseline.json', __dir__)
  baseline = JSON.parse(File.read(baseline_path))
  rln_version = baseline.fetch('rln').fetch('version')
  ios_requirements = baseline.fetch('buildRequirements').fetch('ios')

  s.name             = 'rgb_sdk_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Flutter SDK bridge for Bitcoin RGB Protocol and RGB Lightning Node.'
  s.description      = <<-DESC
Flutter SDK bridge for Bitcoin RGB Protocol and RGB Lightning Node. This
package consumes the same RLN native artifacts as @utexo/rgb-sdk-rn.
Pinned RLN artifact: #{rln_version}.
                       DESC
  s.homepage         = 'https://github.com/zeusbuilds/rgb-sdk-flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'UTEXO Protocol' => 'https://github.com/UTEXO-Protocol' }
  s.source           = { :path => '.' }
  s.prepare_command = 'bash ../tool/download_rln_ios.sh'
  s.source_files = [
    'Classes/**/*',
    'RGBLightningNode.swift',
    'RGBLightningNodeFFI.h'
  ]
  s.public_header_files = 'RGBLightningNodeFFI.h'
  s.preserve_paths = [
    'RGBLightningNode.xcframework',
    'RGBLightningNode.swift',
    'RGBLightningNodeFFI.h',
    'RGBLightningNodeFFI.modulemap'
  ]
  s.dependency 'Flutter'
  s.platform = :ios, ios_requirements.fetch('minimumOsVersion')

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'SWIFT_INCLUDE_PATHS' => '$(PODS_TARGET_SRCROOT)',
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)',
    'HEADER_SEARCH_PATHS[sdk=iphoneos*]' => '$(PODS_TARGET_SRCROOT)/RGBLightningNode.xcframework/ios-arm64/Headers',
    'HEADER_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(PODS_TARGET_SRCROOT)/RGBLightningNode.xcframework/ios-arm64_x86_64-simulator/Headers',
    'LIBRARY_SEARCH_PATHS[sdk=iphoneos*]' => '$(PODS_TARGET_SRCROOT)/RGBLightningNode.xcframework/ios-arm64',
    'LIBRARY_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(PODS_TARGET_SRCROOT)/RGBLightningNode.xcframework/ios-arm64_x86_64-simulator',
    'OTHER_LDFLAGS' => '$(inherited) -l"rgb_lightning_node"'
  }
  s.user_target_xcconfig = {
    'HEADER_SEARCH_PATHS[sdk=iphoneos*]' => '$(inherited) "$(PODS_ROOT)/../.symlinks/plugins/rgb_sdk_flutter/ios/RGBLightningNode.xcframework/ios-arm64/Headers"',
    'HEADER_SEARCH_PATHS[sdk=iphonesimulator*]' => '$(inherited) "$(PODS_ROOT)/../.symlinks/plugins/rgb_sdk_flutter/ios/RGBLightningNode.xcframework/ios-arm64_x86_64-simulator/Headers"'
  }
  s.swift_version = ios_requirements.fetch('swiftLanguageVersion')

  s.resource_bundles = {
    'rgb_sdk_flutter_privacy' => ['Resources/PrivacyInfo.xcprivacy']
  }
end
