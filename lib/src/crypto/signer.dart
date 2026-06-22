import '../errors/rgb_sdk_exception.dart';
import '../models/rln_models.dart';

/// Reserved for future PSBT signing options.
class SignPsbtOptions {
  const SignPsbtOptions();
}

/// RN-parity PSBT signing stub.
///
/// The React Native package removed `bdk-rn` and exports this helper as an
/// explicit throwing stub. Keep the same shape so callers do not mistake missing
/// API surface for supported signing.
Future<String> signPsbt(
  String mnemonic,
  String psbtBase64, {
  String network = 'testnet',
}) {
  throw const UnsupportedWalletFeatureException(
    'signPsbt is unavailable: bdk-rn was removed from this SDK. Use NativeExternalRlnSigner for PSBT signing.',
    feature: 'signPsbt',
  );
}

/// RN-parity PSBT signing-from-seed stub.
Future<String> signPsbtFromSeed(
  Object seed,
  String psbtBase64, {
  String network = 'testnet',
  SignPsbtOptions options = const SignPsbtOptions(),
}) {
  throw const UnsupportedWalletFeatureException(
    'signPsbtFromSeed is unavailable: bdk-rn was removed from this SDK. Use NativeExternalRlnSigner for PSBT signing.',
    feature: 'signPsbtFromSeed',
  );
}

/// RN-parity PSBT fee-estimation stub.
Future<RlnMap> estimatePsbt(String psbtBase64) {
  throw const UnsupportedWalletFeatureException(
    'estimatePsbt is unavailable: bdk-rn was removed from this SDK.',
    feature: 'estimatePsbt',
  );
}
