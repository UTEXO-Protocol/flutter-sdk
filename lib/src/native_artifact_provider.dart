import 'native_artifact_info.dart';
import 'pigeon/rln_api.g.dart';

/// Internal diagnostics adapter for native artifact metadata.
///
/// Runtime wallet and node operations intentionally do not flow through
/// Flutter's federated platform-interface pattern. They are owned by
/// `RlnClient`/`RLNBinding` over the generated Pigeon `RlnHostApi`; this adapter
/// exists only so the package entrypoint can expose support metadata.
class NativeArtifactInfoReader {
  NativeArtifactInfoReader({RlnHostApi? hostApi}) : _hostApi = hostApi;

  final RlnHostApi? _hostApi;

  Future<NativeArtifactInfo> getNativeArtifactInfo() async {
    final info = await (_hostApi ?? RlnHostApi()).getNativeArtifactInfo();
    return NativeArtifactInfo.fromPigeon(info);
  }
}
