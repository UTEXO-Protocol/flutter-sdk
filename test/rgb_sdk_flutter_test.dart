import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_method_channel.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_platform_interface.dart';

class MockRgbSdkFlutterPlatform
    with MockPlatformInterfaceMixin
    implements RgbSdkFlutterPlatform {
  @override
  Future<NativeArtifactInfo> getNativeArtifactInfo() async {
    return const NativeArtifactInfo(
      platform: 'test',
      rlnVersion: RgbSdkFlutter.rlnVersion,
      reactNativeParityVersion: RgbSdkFlutter.reactNativeParityVersion,
      bridge: 'mock',
      nativeArtifact: 'mock-artifact',
    );
  }
}

void main() {
  final RgbSdkFlutterPlatform initialPlatform = RgbSdkFlutterPlatform.instance;

  test('$MethodChannelRgbSdkFlutter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelRgbSdkFlutter>());
  });

  test('nativeArtifactInfo', () async {
    const rgbSdkFlutterPlugin = RgbSdkFlutter();
    final fakePlatform = MockRgbSdkFlutterPlatform();
    RgbSdkFlutterPlatform.instance = fakePlatform;

    final info = await rgbSdkFlutterPlugin.nativeArtifactInfo();

    expect(info.rlnVersion, RgbSdkFlutter.rlnVersion);
    expect(
      info.reactNativeParityVersion,
      RgbSdkFlutter.reactNativeParityVersion,
    );
    expect(info.bridge, 'mock');
  });
}
