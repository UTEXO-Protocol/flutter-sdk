import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:pointycastle/ecc/api.dart' show ECPoint;
import 'package:pointycastle/ecc/curves/secp256k1.dart';

import '../errors/rgb_sdk_exception.dart';
import 'constants.dart';
import 'keys.dart';
import 'validation.dart';

class SignMessageParams {
  const SignMessageParams({
    required this.message,
    required this.seed,
    this.network = DEFAULT_NETWORK,
  });

  final Object message;
  final Object seed;
  final Network network;
}

class VerifyMessageParams {
  const VerifyMessageParams({
    required this.message,
    required this.signature,
    required this.accountXpub,
    this.network = DEFAULT_NETWORK,
  });

  final Object message;
  final String signature;
  final String accountXpub;
  final Network network;
}

final ECCurve_secp256k1 _secp = ECCurve_secp256k1();
final BigInt _p = BigInt.parse(
  'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F',
  radix: 16,
);
final BigInt _n = BigInt.parse(
  'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
  radix: 16,
);
final BigInt _seven = BigInt.from(7);

Uint8List _messageBytes(Object message) {
  if (message is String) {
    if (message.isEmpty) {
      throw const ValidationError('message must not be empty', 'message');
    }
    return Uint8List.fromList(utf8.encode(message));
  }
  if (message is Uint8List) {
    if (message.isEmpty) {
      throw const ValidationError('message must not be empty', 'message');
    }
    return Uint8List.fromList(message);
  }
  throw const ValidationError(
    'message must be a string or Uint8List',
    'message',
  );
}

Uint8List _sha256(List<int> data) =>
    Uint8List.fromList(crypto.sha256.convert(data).bytes);

Uint8List _taggedHash(String tag, List<int> data) {
  final tagHash = _sha256(utf8.encode(tag));
  return _sha256(<int>[...tagHash, ...tagHash, ...data]);
}

BigInt _bytesToInt(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

Uint8List _intToBytes(BigInt value) {
  final result = Uint8List(32);
  var current = value;
  for (var i = 31; i >= 0; i -= 1) {
    result[i] = (current & BigInt.from(0xff)).toInt();
    current >>= 8;
  }
  return result;
}

Uint8List xOnlyPointFromPoint(Uint8List point) {
  if (point.length == 33 || point.length == 65) {
    return Uint8List.fromList(point.sublist(1, 33));
  }
  if (point.length == 32) return Uint8List.fromList(point);
  throw ValidationError('Invalid public key length: ${point.length}', 'point');
}

bool _hasOddY(ECPoint point) => point.y!.toBigInteger()!.isOdd;

ECPoint _liftX(Uint8List xBytes) {
  if (xBytes.length != 32) {
    throw const ValidationError('public key must be 32 bytes', 'publicKey');
  }
  final x = _bytesToInt(xBytes);
  if (x >= _p) {
    throw const ValidationError('Invalid x-only public key', 'publicKey');
  }
  final ySquared = (x.modPow(BigInt.from(3), _p) + _seven) % _p;
  var y = ySquared.modPow((_p + BigInt.one) >> 2, _p);
  if (y.modPow(BigInt.two, _p) != ySquared) {
    throw const ValidationError('Invalid x-only public key', 'publicKey');
  }
  if (y.isOdd) y = _p - y;
  return _secp.curve.createPoint(x, y);
}

Uint8List signSchnorr(
  Uint8List messageHash,
  Uint8List privateKey, {
  Uint8List? auxRand,
}) {
  if (messageHash.length != 32) {
    throw const ValidationError('message hash must be 32 bytes', 'message');
  }
  final d0 = _bytesToInt(privateKey);
  if (d0 <= BigInt.zero || d0 >= _n) {
    throw const ValidationError('Invalid private key', 'privateKey');
  }

  final point = (_secp.G * d0)!;
  final d = _hasOddY(point) ? _n - d0 : d0;
  final publicKey = _intToBytes(point.x!.toBigInteger()!);
  final aux = auxRand == null ? Uint8List(32) : Uint8List.fromList(auxRand);
  if (aux.length != 32) {
    throw const ValidationError('auxRand must be 32 bytes', 'auxRand');
  }

  final auxHash = _taggedHash('BIP0340/aux', aux);
  final dBytes = _intToBytes(d);
  final t = Uint8List(32);
  for (var i = 0; i < 32; i += 1) {
    t[i] = dBytes[i] ^ auxHash[i];
  }

  final rand = _taggedHash('BIP0340/nonce', <int>[
    ...t,
    ...publicKey,
    ...messageHash,
  ]);
  final k0 = _bytesToInt(rand) % _n;
  if (k0 == BigInt.zero) {
    throw const CryptoError('Failed to generate Schnorr nonce');
  }

  final rPoint = (_secp.G * k0)!;
  final k = _hasOddY(rPoint) ? _n - k0 : k0;
  final r = _intToBytes(rPoint.x!.toBigInteger()!);
  final e =
      _bytesToInt(
        _taggedHash('BIP0340/challenge', <int>[
          ...r,
          ...publicKey,
          ...messageHash,
        ]),
      ) %
      _n;
  final s = (k + e * d) % _n;
  return Uint8List.fromList(<int>[...r, ..._intToBytes(s)]);
}

bool verifySchnorr(
  Uint8List messageHash,
  Uint8List publicKey,
  Uint8List signature,
) {
  if (messageHash.length != 32 ||
      publicKey.length != 32 ||
      signature.length != 64) {
    return false;
  }
  final r = _bytesToInt(signature.sublist(0, 32));
  final s = _bytesToInt(signature.sublist(32, 64));
  if (r >= _p || s >= _n) return false;

  try {
    final point = _liftX(publicKey);
    final e =
        _bytesToInt(
          _taggedHash('BIP0340/challenge', <int>[
            ...signature.sublist(0, 32),
            ...publicKey,
            ...messageHash,
          ]),
        ) %
        _n;
    final rPoint = (_secp.G * s)! + (point * ((_n - e) % _n))!;
    if (rPoint == null || rPoint.isInfinity || _hasOddY(rPoint)) return false;
    return rPoint.x!.toBigInteger() == r;
  } catch (_) {
    return false;
  }
}

Future<String> signMessage(SignMessageParams params) async {
  final normalizedNetwork = normalizeNetwork(params.network);
  final seed = normalizeSeedInput(params.seed, 'seed');
  final root = rootNodeFromSeed(seed, normalizedNetwork);
  final accountNode = root.derivePath(
    accountDerivationPath(normalizedNetwork, false),
  );
  final child = accountNode.derivePath('0/0');
  final privateKey = child.privateKey;
  if (privateKey == null) {
    throw const CryptoError('Derived node does not contain a private key');
  }
  final messageHash = _sha256(_messageBytes(params.message));
  return base64Encode(signSchnorr(messageHash, privateKey));
}

Future<bool> verifyMessage(VerifyMessageParams params) async {
  final normalizedNetwork = normalizeNetwork(params.network);
  final messageHash = _sha256(_messageBytes(params.message));
  try {
    final signature = base64Decode(params.signature);
    final accountNode = rootNodeFromBase58(
      params.accountXpub,
      normalizedNetwork,
    );
    final child = accountNode.derivePath('0/0');
    return verifySchnorr(
      messageHash,
      xOnlyPointFromPoint(child.publicKey),
      Uint8List.fromList(signature),
    );
  } on ValidationError {
    rethrow;
  } on FormatException {
    return false;
  } catch (_) {
    throw const ValidationError('Invalid account xpub provided', 'accountXpub');
  }
}
