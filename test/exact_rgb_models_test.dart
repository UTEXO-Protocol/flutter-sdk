import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';
import 'package:rgb_sdk_flutter/src/crypto/validation.dart' show toNumber;
import 'package:rgb_sdk_flutter/src/lsp/lsp_native_decoders.dart';
import 'package:rgb_sdk_flutter/src/models/exact_integer.dart';

void main() {
  test('malformed relay status never enters serialized diagnostics', () {
    const privateValue = 'unstructured-private-response';
    try {
      LspLightningSendStatusResponse.fromWire({'status': privateValue});
      fail('Invalid status must be rejected.');
    } on NativeProtocolException catch (error) {
      expect(error.cause, privateValue);
      expect(error.toString(), isNot(contains(privateValue)));
      expect(error.toJson().toString(), isNot(contains(privateValue)));
    }
  });
  test('LSP and APay decoders reject saturating numeric responses', () {
    expect(
      () => LspLnurlpDiscovery.fromWire({
        'callback': 'https://example.com/callback',
        'minSendable': 1,
        'maxSendable': 1e30,
        'metadata': '[["text/plain","test"]]',
        'tag': 'payRequest',
      }),
      throwsA(isA<NativeProtocolException>()),
    );
    expect(
      () => LspLightningSendResponse.fromWire({
        'ln_invoice': 'test-invoice',
        'payment_hash': 'test-hash',
        'inbound': {'amt_msat': 1e30},
        'outbound': {'amt_msat': 1},
        'converted': false,
        'fee_msat': 0,
        'expires_at': 1,
      }),
      throwsA(isA<NativeProtocolException>()),
    );
    expect(
      () => decodeNativeApayNewResponse({
        'hostNodeId': 'host',
        'protocolVersion': 1,
        'status': 'active',
        'acceptedThroughIndex': 1,
        'nextIndexExpected': 2,
        'unusedHashes': 1e30,
      }, expectedHostNodeId: 'host'),
      throwsA(
        isA<NativeProtocolException>().having(
          (error) => error.field,
          'field',
          'ApayNewResponse.unusedHashes',
        ),
      ),
    );
  });
  test('signed wire parsing never saturates', () {
    for (final invalid in <Object>[
      1e30,
      -1e30,
      double.infinity,
      double.nan,
      1.5,
      9007199254740992.0,
      '9223372036854775808',
      '-9223372036854775809',
      '0x10',
      '1e30',
    ]) {
      expect(exactWireInt(invalid), isNull);
    }
    expect(exactWireInt('9223372036854775807'), 9223372036854775807);
    expect(exactWireInt('-9223372036854775808'), -9223372036854775808);
    expect(exactWireInt(12.0), 12);
    expect(() => toNumber(BigInt.one << 64), throwsA(isA<ValidationError>()));
  });
  final max = BigInt.parse(rlnMaxUnsigned64Decimal);
  final balance = <String, Object>{
    'settled': max.toString(),
    'future': max.toString(),
    'spendable': max.toString(),
    'offchainOutbound': max.toString(),
    'offchainInbound': max.toString(),
  };
  final common = <String, Object>{
    'assetId': 'rgb:asset',
    'name': 'Asset',
    'ticker': 'ASSET',
    'precision': 8,
    'timestamp': 1,
    'addedAt': 2,
    'balance': balance,
  };

  test(
    'all RGB asset families preserve maximum UInt64 balances and supplies',
    () {
      final assets = RlnAssets.fromMap({
        'nia': [
          {...common, 'issuedSupply': max.toString()},
        ],
        'cfa': [
          {...common, 'issuedSupply': max.toString()},
        ],
        'ifa': [
          {
            ...common,
            'initialSupply': max.toString(),
            'maxSupply': max.toString(),
            'knownCirculatingSupply': max.toString(),
          },
        ],
        'uda': [common],
      }).toCore();
      expect(assets.nia.single.issuedSupply, max);
      expect(assets.cfa.single.issuedSupply, max);
      expect(assets.ifa.single.initialSupply, max);
      expect(assets.ifa.single.maxSupply, max);
      expect(assets.ifa.single.knownCirculatingSupply, max);
      for (final asset in [
        ...assets.nia,
        ...assets.cfa,
        ...assets.ifa,
        ...assets.uda,
      ]) {
        expect(asset.balance.settled, max);
        expect(asset.balance.future, max);
        expect(asset.balance.spendable, max);
        expect(asset.balance.offchainOutbound, max);
        expect(asset.balance.offchainInbound, max);
      }
    },
  );

  test(
    'RGB balance rejects invalid and absent fields instead of fabricating zero',
    () {
      for (final bad in <Object?>[
        -1,
        '-1',
        '${max + BigInt.one}',
        1.5,
        9007199254740992.0,
        '0x10',
        null,
        'oops',
      ]) {
        expect(
          () => RlnAssetBalance.fromMap({...balance, 'spendable': bad}),
          throwsA(isA<NativeProtocolException>()),
        );
      }
      expect(
        () => RlnAssetBalance.fromMap({...balance}..remove('offchainInbound')),
        throwsA(isA<NativeProtocolException>()),
      );
    },
  );

  test('assignment parsing is exact bounded and anchored', () {
    expect(parseCoreAssignment('Fungible($max)').amount, max);
    expect(parseCoreAssignment('$max').amount, max);
    expect(parseCoreAssignment('Any').amount, isNull);
    for (final bad in [
      'prefixFungible(2)',
      'Fungible(2)suffix',
      '-1',
      'Fungible(${max + BigInt.one})',
    ]) {
      expect(
        () => parseCoreAssignment(bad),
        throwsA(isA<NativeProtocolException>()),
      );
    }
  });

  test(
    'stable transfer preserves requested assignment independently of outcomes',
    () {
      final transfer = RlnTransfer.fromMap({
        'idx': 1,
        'status': 'Settled',
        'kind': 'ReceiveBlind',
        'requestedAssignment': 'Any',
        'assignments': ['Fungible($max)'],
        'transportEndpoints': <Object>[],
      }).toCore();
      expect(transfer.requestedAssignment?.type, 'Any');
      expect(transfer.assignments.single.amount, max);
    },
  );

  test(
    'stable network adapter normalizes all native aliases and rejects unknowns',
    () {
      for (final entry in {
        'Bitcoin': 'mainnet',
        'MAINNET': 'mainnet',
        'testnet3': 'testnet',
        'Testnet4': 'testnet4',
        'Signet': 'signet',
        'Signet_Custom': 'utexo',
        ' utexo ': 'utexo',
        'Regtest': 'regtest',
      }.entries) {
        final result = RlnNetworkInfo.fromMap({
          'network': entry.key,
          'height': 100,
        }).toWalletNetworkInfo();
        expect(result.network, entry.value);
        expect(result.blockHeight, 100);
      }
      expect(
        () => RlnNetworkInfo.fromMap({
          'network': 'future-chain',
          'height': 1,
        }).toWalletNetworkInfo(),
        throwsA(isA<NativeProtocolException>()),
      );
    },
  );
}
