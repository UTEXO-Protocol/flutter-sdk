import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';

void main() {
  test('matches official BIP340 Schnorr vectors', () {
    final rows = File(
      'test/fixtures/bip340_test_vectors.csv',
    ).readAsLinesSync().skip(1);

    for (final row in rows) {
      final columns = row.split(',');
      final index = columns[0];
      final secretKey = columns[1];
      final publicKey = _hexToBytes(columns[2]);
      final auxRand = columns[3].isEmpty ? null : _hexToBytes(columns[3]);
      final message = _hexToBytes(columns[4]);
      final expectedSignature = _hexToBytes(columns[5]);
      final expectedVerification = columns[6] == 'TRUE';

      expect(
        verifySchnorr(message, publicKey, expectedSignature),
        expectedVerification,
        reason: 'BIP340 vector $index verification',
      );

      if (secretKey.isNotEmpty) {
        final signature = signSchnorr(
          message,
          _hexToBytes(secretKey),
          auxRand: auxRand,
        );
        expect(
          _bytesToHex(signature),
          _bytesToHex(expectedSignature),
          reason: 'BIP340 vector $index signing',
        );
      }
    }
  });

  test('rejects tampered BIP340 messages, public keys, and signatures', () {
    final rows = File(
      'test/fixtures/bip340_test_vectors.csv',
    ).readAsLinesSync().skip(1);

    for (final row in rows) {
      final columns = row.split(',');
      final index = columns[0];
      final publicKey = _hexToBytes(columns[2]);
      final message = _hexToBytes(columns[4]);
      final signature = _hexToBytes(columns[5]);
      final expectedVerification = columns[6] == 'TRUE';
      if (!expectedVerification) continue;

      expect(
        verifySchnorr(_flipped(message), publicKey, signature),
        false,
        reason: 'BIP340 vector $index rejects tampered message',
      );
      expect(
        verifySchnorr(message, _flipped(publicKey), signature),
        false,
        reason: 'BIP340 vector $index rejects tampered public key',
      );
      expect(
        verifySchnorr(message, publicKey, _flipped(signature)),
        false,
        reason: 'BIP340 vector $index rejects tampered signature',
      );
    }
  });

  test('enforces Schnorr scalar and byte-length boundaries', () {
    final message = Uint8List(32);
    final privateKey = Uint8List(32)..[31] = 3;
    final publicKey = _hexToBytes(
      'F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9',
    );
    final signature = signSchnorr(message, privateKey);

    expect(verifySchnorr(message, publicKey, signature), true);
    expect(verifySchnorr(message, Uint8List(31), signature), false);
    expect(verifySchnorr(message, publicKey, Uint8List(63)), false);
    expect(
      () => signSchnorr(message, Uint8List(32), auxRand: Uint8List(32)),
      throwsA(isA<ValidationError>()),
    );
    expect(
      () => signSchnorr(message, privateKey, auxRand: Uint8List(31)),
      throwsA(isA<ValidationError>()),
    );
  });
}

Uint8List _hexToBytes(String hex) {
  if (hex.isEmpty) return Uint8List(0);
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < result.length; i += 1) {
    result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return result;
}

String _bytesToHex(Iterable<int> bytes) {
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

Uint8List _flipped(Uint8List bytes) {
  if (bytes.isEmpty) return Uint8List.fromList(<int>[0]);
  final copy = Uint8List.fromList(bytes);
  copy[copy.length - 1] ^= 0x01;
  return copy;
}
