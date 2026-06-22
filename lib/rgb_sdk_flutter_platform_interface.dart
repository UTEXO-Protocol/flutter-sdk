import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'rgb_sdk_flutter_method_channel.dart';
import 'src/native_artifact_info.dart';

abstract class RgbSdkFlutterPlatform extends PlatformInterface {
  /// Constructs a RgbSdkFlutterPlatform.
  RgbSdkFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static RgbSdkFlutterPlatform _instance = MethodChannelRgbSdkFlutter();

  /// The default instance of [RgbSdkFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelRgbSdkFlutter].
  static RgbSdkFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [RgbSdkFlutterPlatform] when
  /// they register themselves.
  static set instance(RgbSdkFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<NativeArtifactInfo> getNativeArtifactInfo() {
    throw UnimplementedError(
      'getNativeArtifactInfo() has not been implemented.',
    );
  }
}
