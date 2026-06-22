import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_method_channel.dart';
import 'package:rgb_sdk_flutter/src/pigeon/rln_api.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelRgbSdkFlutter platform = MethodChannelRgbSdkFlutter();
  final channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.rgb_sdk_flutter.RlnHostApi.getNativeArtifactInfo',
    RlnHostApi.pigeonChannelCodec,
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(channel, (
          Object? message,
        ) async {
          expect(message, isNull);
          return <Object?>[
            RlnNativeArtifactInfo(
              platform: 'test',
              rlnVersion: RgbSdkFlutter.rlnVersion,
              reactNativeParityVersion: RgbSdkFlutter.reactNativeParityVersion,
              bridge: 'pigeon-bootstrap',
              nativeArtifact: 'test-artifact',
            ),
          ];
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(channel, null);
  });

  test('getNativeArtifactInfo', () async {
    final info = await platform.getNativeArtifactInfo();

    expect(info.platform, 'test');
    expect(info.rlnVersion, RgbSdkFlutter.rlnVersion);
    expect(info.nativeArtifact, 'test-artifact');
  });
}
