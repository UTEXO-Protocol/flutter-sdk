import 'pigeon/rln_api.g.dart';

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

  factory NativeArtifactInfo.fromMap(Map<String, Object?> map) {
    return NativeArtifactInfo(
      platform: _readString(map, 'platform'),
      rlnVersion: _readString(map, 'rlnVersion'),
      reactNativeParityVersion: _readString(map, 'reactNativeParityVersion'),
      bridge: _readString(map, 'bridge'),
      nativeArtifact: _readString(map, 'nativeArtifact'),
    );
  }

  factory NativeArtifactInfo.fromPigeon(RlnNativeArtifactInfo info) {
    return NativeArtifactInfo(
      platform: info.platform,
      rlnVersion: info.rlnVersion,
      reactNativeParityVersion: info.reactNativeParityVersion,
      bridge: info.bridge,
      nativeArtifact: info.nativeArtifact,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'platform': platform,
      'rlnVersion': rlnVersion,
      'reactNativeParityVersion': reactNativeParityVersion,
      'bridge': bridge,
      'nativeArtifact': nativeArtifact,
    };
  }

  static String _readString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }

    throw FormatException('Expected non-empty string for "$key".');
  }
}
