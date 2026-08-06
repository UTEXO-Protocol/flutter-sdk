import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'package:rgb_sdk_flutter/src/crypto/keys.dart' as keys;
import 'package:rgb_sdk_flutter/src/crypto/validation.dart' as validation;

const _mnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon about';

void main() {
  group('network and Lightning Address validation', () {
    test('normalizes supported networks and rejects invalid inputs', () {
      expect(isNetwork('mainnet'), true);
      expect(isNetwork('bitcoin'), false);
      expect(isNetwork(1), false);
      expect(normalizeNetwork('mainnet'), 'mainnet');
      expect(() => normalizeNetwork('liquid'), throwsA(isA<ValidationError>()));
    });

    test('parses Lightning Address and UMA-compatible address forms', () {
      final plain = parseLightningAddress(' Alice@Example.com ');
      expect(plain.username, 'Alice');
      expect(plain.domain, 'Example.com');
      expect(plain.isUma, false);
      expect(plain.address, 'Alice@Example.com');

      final uma = parseLightningAddress(r'$alice@example.com');
      expect(uma.username, 'alice');
      expect(uma.domain, 'example.com');
      expect(uma.isUma, true);
      expect(
        normalizeLightningAddress(r'$ALICE@EXAMPLE.COM'),
        'alice@example.com',
      );
      expect(isUmaAddress(r'$alice@example.com'), true);

      expect(
        () => parseLightningAddress('missing-domain'),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => parseLightningAddress('@example.com'),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => parseLightningAddress(r'$bad/name@example.com'),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => parseLightningAddress(
          r'$aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa@example.com',
        ),
        throwsA(isA<ValidationError>()),
      );
    });
  });

  group('primitive value validation', () {
    test('validates mnemonic, base64, PSBT, hex, and required strings', () {
      validateMnemonic(_mnemonic);
      validateBip39Mnemonic(_mnemonic);
      validateBase64('AQID');
      validatePsbt(
        'cHNidP8BAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
      );
      validateHex('00ffAA');
      validateRequired('value', 'field');
      validateString('value', 'field');

      expect(
        () => validateMnemonic('one two'),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => validateBip39Mnemonic(
          '${_mnemonic.split(' ').take(11).join(' ')} wrong',
        ),
        throwsA(isA<ValidationError>()),
      );
      expect(() => validateBase64('@@@'), throwsA(isA<ValidationError>()));
      expect(() => validateBase64('abcd='), throwsA(isA<ValidationError>()));
      expect(() => validatePsbt('AQID'), throwsA(isA<ValidationError>()));
      expect(() => validateHex('00zz'), throwsA(isA<ValidationError>()));
      expect(
        () => validateRequired<Object?>(null, 'field'),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => validateString(' ', 'field'),
        throwsA(isA<ValidationError>()),
      );
    });

    test('converts asset units without losing sign or precision', () {
      expect(toUnitsNumber('1.23', 2), 123);
      expect(validation.toUnitsBigInt('-1.2300', 4), BigInt.from(-12300));
      expect(fromUnitsNumber(123, 2), 1.23);
      expect(validation.fromUnitsBigInt(BigInt.from(-12300), 4), '-1.23');
      expect(validation.toNumber(BigInt.from(7)), 7);
      expect(validation.toBigInt(7), BigInt.from(7));
      expect(validation.toNumber(null), null);
      expect(validation.toBigInt(null), null);

      expect(
        () => toUnitsNumber('9007199254740992', 0),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => validation.toUnitsBigInt('1.2.3', 2),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => validation.toUnitsBigInt('not-a-number', 2),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => validation.fromUnitsBigInt(BigInt.one, -1),
        throwsA(isA<ValidationError>()),
      );
      expect(() => validation.toNumber('7'), throwsA(isA<ValidationError>()));
      expect(() => validation.toBigInt('7'), throwsA(isA<ValidationError>()));
    });
  });

  group('key helper boundaries', () {
    test(
      'normalizes mutable seed inputs defensively and rejects malformed seeds',
      () {
        final seedBytes = Uint8List.fromList(List<int>.filled(64, 1));
        final copied = normalizeSeedInput(seedBytes);
        seedBytes[0] = 9;
        expect(copied[0], 1);

        final listSeed = List<int>.filled(64, 2);
        final copiedList = normalizeSeedInput(listSeed);
        listSeed[0] = 9;
        expect(copiedList[0], 2);

        final hexSeed = '0x${'03' * 64}';
        expect(normalizeSeedInput(hexSeed), hasLength(64));
        expect(() => normalizeSeedInput(''), throwsA(isA<ValidationError>()));
        expect(() => normalizeSeedInput('0'), throwsA(isA<ValidationError>()));
        expect(() => normalizeSeedInput('00'), throwsA(isA<ValidationError>()));
        expect(
          () => normalizeSeedInput('${'00' * 63}zz'),
          throwsA(isA<ValidationError>()),
        );
        expect(
          () => normalizeSeedInput(<int>[]),
          throwsA(isA<ValidationError>()),
        );
        expect(
          () => normalizeSeedInput(Object()),
          throwsA(isA<ValidationError>()),
        );
      },
    );

    test(
      'constructs wallet init params and derives keys from supported sources',
      () async {
        const params = WalletInitParams(
          xpubVan: 'vanilla',
          xpubCol: 'colored',
          masterFingerprint: '00000000',
        );
        expect(params.xpubVan, 'vanilla');

        final restored = await restoreKeys('regtest', _mnemonic);
        expect(restored.mnemonic, _mnemonic);
        expect(restored.xpriv, isNotEmpty);

        final xpriv = await getXprivFromMnemonic('regtest', _mnemonic);
        final xpub = await getXpubFromXpriv(xpriv);
        expect(xpub, isNotEmpty);
        final fromXpriv = await deriveKeysFromXpriv(xpriv);
        expect(fromXpriv.accountXpubVanilla, isNotEmpty);

        final seed = seedFromMnemonic(_mnemonic);
        final fromSeed = await deriveKeysFromMnemonicOrSeed('regtest', seed);
        expect(fromSeed.mnemonic, isEmpty);
        wipeSecretBytes(seed);
        expect(seed.every((byte) => byte == 0), true);

        final generated = await createWallet('regtest');
        expect(generated.mnemonic.split(' '), hasLength(12));
      },
    );

    test('maps malformed extended keys to SDK errors', () async {
      expect(
        () => keys.rootNodeFromBase58('not-an-xpriv', 'regtest'),
        throwsA(isA<CryptoError>()),
      );
      await expectLater(getXpubFromXpriv(''), throwsA(isA<ValidationError>()));
      await expectLater(
        deriveKeysFromXpriv('not-an-xpriv'),
        throwsA(isA<CryptoError>()),
      );
    });
  });
}
