import 'dart:typed_data';

import '../crypto/constants.dart';
import '../crypto/message.dart' as message_crypto;
import '../crypto/signer.dart' as psbt_signer;
import '../models/rln_models.dart';

class RNSigner {
  const RNSigner();

  Future<String> signPsbtWithMnemonic(
    String mnemonic,
    String psbt, {
    Network network = DEFAULT_NETWORK,
  }) {
    return psbt_signer.signPsbt(mnemonic, psbt, network: network);
  }

  Future<String> signPsbtWithSeed(
    Uint8List seed,
    String psbt, {
    Network network = DEFAULT_NETWORK,
  }) {
    return psbt_signer.signPsbtFromSeed(seed, psbt, network: network);
  }

  Future<String> signMessage({
    required Object message,
    required Object seed,
    Network network = DEFAULT_NETWORK,
    message_crypto.SchnorrSigningMode signingMode =
        message_crypto.SchnorrSigningMode.disabled,
  }) {
    return message_crypto.signMessage(
      message_crypto.SignMessageParams(
        message: message,
        seed: seed,
        network: network,
        signingMode: signingMode,
      ),
    );
  }

  Future<bool> verifyMessage({
    required Object message,
    required String signature,
    required String accountXpub,
    Network network = DEFAULT_NETWORK,
  }) {
    return message_crypto.verifyMessage(
      message_crypto.VerifyMessageParams(
        message: message,
        signature: signature,
        accountXpub: accountXpub,
        network: network,
      ),
    );
  }

  Future<RlnMap> estimateFee(String psbt) {
    return psbt_signer.estimatePsbt(psbt);
  }
}
