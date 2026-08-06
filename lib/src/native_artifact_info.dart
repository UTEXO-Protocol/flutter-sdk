/// Metadata reported by the native bridge.
///
/// Useful for diagnostics because the Flutter package, React Native parity
/// target, and RLN artifact versions must stay aligned.
class NativeArtifactInfo {
  const NativeArtifactInfo({
    required this.platform,
    required this.rlnVersion,
    required this.reactNativeParityVersion,
    required this.bridge,
    required this.nativeArtifact,
  });

  final String platform;
  final String rlnVersion;
  final String reactNativeParityVersion;
  final String bridge;
  final String nativeArtifact;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'platform': platform,
      'rlnVersion': rlnVersion,
      'reactNativeParityVersion': reactNativeParityVersion,
      'bridge': bridge,
      'nativeArtifact': nativeArtifact,
    };
  }
}
