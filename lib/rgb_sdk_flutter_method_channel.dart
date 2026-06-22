import 'package:flutter/foundation.dart';

import 'rgb_sdk_flutter_platform_interface.dart';
import 'src/native_artifact_info.dart';
import 'src/pigeon/rln_api.g.dart';

/// An implementation of [RgbSdkFlutterPlatform] that uses method channels.
class MethodChannelRgbSdkFlutter extends RgbSdkFlutterPlatform {
  MethodChannelRgbSdkFlutter({RlnHostApi? hostApi})
    : _hostApi = hostApi ?? RlnHostApi();

  @visibleForTesting
  RlnHostApi get hostApi => _hostApi;

  final RlnHostApi _hostApi;

  @override
  Future<NativeArtifactInfo> getNativeArtifactInfo() async {
    final info = await _hostApi.getNativeArtifactInfo();
    return NativeArtifactInfo.fromPigeon(info);
  }
}
