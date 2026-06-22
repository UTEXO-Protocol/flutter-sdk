import 'rgb_sdk_flutter_platform_interface.dart';
import 'src/client/rln_client.dart';
import 'src/native_artifact_info.dart';
import 'src/wallet/rln_manager.dart';
import 'src/wallet/utexo_wallet.dart';

export 'src/binding/rln_binding.dart';
export 'src/client/rln_client.dart';
export 'src/crypto/constants.dart';
export 'src/crypto/keys.dart';
export 'src/crypto/message.dart';
export 'src/crypto/signer.dart';
export 'src/crypto/validation.dart';
export 'src/errors/rgb_sdk_exception.dart';
export 'src/lsp/lsp_errors.dart';
export 'src/lsp/lsp_types.dart';
export 'src/lsp/utexo_lsp.dart';
export 'src/lsp/utexo_lsp_client.dart';
export 'src/models/rln_models.dart';
export 'src/models/utexo_core_models.dart';
export 'src/native_artifact_info.dart';
export 'src/signer/rn_signer.dart';
export 'src/utexo/bridge.dart';
export 'src/utexo/network.dart';
export 'src/utils/logger.dart';
export 'src/wallet/network_defaults.dart';
export 'src/wallet/rln_manager.dart';
export 'src/wallet/rln_signers.dart';
export 'src/wallet/utexo_wallet.dart';

/// Flutter entry point for RGB Lightning Node bindings.
///
/// App code should usually create [UtexoWallet] instances through [wallet].
/// Use [rlnClient] only for low-level RN parity checks or bridge debugging.
class RgbSdkFlutter {
  const RgbSdkFlutter();

  /// Dart package name.
  static const packageName = 'rgb_sdk_flutter';

  /// React Native package used as the parity reference.
  static const reactNativePackageName = '@utexo/rgb-sdk-rn';

  /// React Native package version this bridge targets.
  static const reactNativeParityVersion = '1.0.0-beta.19';

  /// RGB Lightning Node artifact version pinned by this package.
  static const rlnVersion = '0.6.0-beta.2';

  /// Returns native artifact metadata for diagnostics and support reports.
  Future<NativeArtifactInfo> nativeArtifactInfo() {
    return RgbSdkFlutterPlatform.instance.getNativeArtifactInfo();
  }

  /// Creates the low-level raw RLN bridge client.
  RlnClient rlnClient() => RlnClient();

  /// Creates the RN-style stateful RLN manager.
  RLNManager rlnManager() => createRLNManager();

  /// Creates a typed wallet facade for app-level wallet workflows.
  UtexoWallet wallet({required UtexoWalletConfig config}) {
    return UtexoWallet(config: config);
  }
}
