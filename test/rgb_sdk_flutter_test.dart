import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

void main() {
  test('exposes package and pinned artifact versions', () {
    expect(RgbSdkFlutter.packageName, 'rgb_sdk_flutter');
    expect(RgbSdkFlutter.reactNativeParityVersion, isNotEmpty);
    expect(RgbSdkFlutter.rlnVersion, isNotEmpty);
  });
}
