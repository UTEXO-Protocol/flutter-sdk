import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';
import 'package:rgb_sdk_flutter/src/pigeon/rln_api.g.dart';

import 'utexo_wallet_test.dart' show FakeRlnHostApi;

Map<Object?, Object?> _response() => {
  'assetId': 'rgb:expected',
  'alreadyImported': false,
  'metadata': {
    'assetSchema': 'Bfa',
    'name': 'Usdt',
    'ticker': 'USDT',
    'precision': 6,
    'initialSupply': '0',
    'maxSupply': '18446744073709551615',
    'knownCirculatingSupply': '0',
  },
};

class _Host extends FakeRlnHostApi {
  int imports = 0;
  String? contract;
  String? expected;
  Map<Object?, Object?> response = _response();

  @override
  Future<RlnWireResponse> rlnImportRgbContract(
    int nodeId,
    String contractBase64,
    String expectedAssetId,
  ) async {
    imports++;
    contract = contractBase64;
    expected = expectedAssetId;
    return RlnWireResponse(json: jsonEncode(response));
  }
}

void main() {
  test(
    'import metadata preserves exact u64 supply and requires expected ID',
    () {
      final value = ImportedRgbContract.fromMap(
        _response(),
        expectedAssetId: 'rgb:expected',
      );
      expect(value.assetSchema, 'Bfa');
      expect(value.precision, 6);
      expect(value.name, 'Usdt');
      expect(value.maxSupply, BigInt.parse('18446744073709551615'));
      expect(
        () => ImportedRgbContract.fromMap(
          _response(),
          expectedAssetId: 'rgb:other',
        ),
        throwsA(isA<NativeProtocolException>()),
      );
    },
  );

  test('malformed identity, metadata and supply fail closed', () {
    for (final response in <Map<Object?, Object?>>[
      {..._response(), 'alreadyImported': 'true'},
      {..._response(), 'metadata': null},
      {
        ..._response(),
        'metadata': {...(_response()['metadata']! as Map), 'precision': 256},
      },
      for (final amount in <Object?>[-1, 1.5, '18446744073709551616', '1e6'])
        {
          ..._response(),
          'metadata': {
            ...(_response()['metadata']! as Map),
            'initialSupply': amount,
          },
        },
    ]) {
      expect(
        () => ImportedRgbContract.fromMap(
          response,
          expectedAssetId: 'rgb:expected',
        ),
        throwsA(isA<NativeProtocolException>()),
      );
    }
  });

  test(
    'import requires unlock and canonical bytes before native dispatch',
    () async {
      final host = _Host();
      final wallet = createAdvancedUtexoWallet(
        config: UtexoWalletConfig(storageDirPath: '/tmp/import-test'),
        client: RlnClient(hostApi: host),
      );
      await expectLater(
        () => wallet.importRgbContract(
          contractBase64: 'YWJj',
          expectedAssetId: 'rgb:expected',
        ),
        throwsA(isA<WalletException>()),
      );
      await wallet.init(password: 'test-password');
      await wallet.unlock(
        password: 'test-password',
        config: UtexoUnlockConfig(indexerUrl: 'http://127.0.0.1:18094'),
      );
      for (final payload in [
        '',
        'YQ',
        'YQ==\n',
        'YR==',
        '____',
        'A' * (16 * 1024 * 1024 + 4),
      ]) {
        expect(
          () => wallet.importRgbContract(
            contractBase64: payload,
            expectedAssetId: 'rgb:expected',
          ),
          throwsA(isA<WalletValidationException>()),
        );
      }
      expect(host.imports, 0);
      final imported = await wallet.importRgbContract(
        contractBase64: 'YWJj',
        expectedAssetId: 'rgb:expected',
      );
      expect(imported.assetId, 'rgb:expected');
      expect(host.contract, 'YWJj');
      expect(host.expected, 'rgb:expected');
      expect(host.imports, 1);
      await wallet.destroy();
    },
  );
}
