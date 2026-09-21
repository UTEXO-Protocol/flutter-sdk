import 'package:flutter_test/flutter_test.dart';

import '../tool/bridge_vector_applicability.dart';

void main() {
  const vectors = {
    'dart-malformed-wire',
    'native-invalid-argument',
    'native-unknown-node-error',
    'platform-smoke-or-regtest-success',
  };
  Set<String> requiredFor(String method, String declaration) =>
      applicableFamilyVectors(
        pigeonSource: 'abstract class RlnHostApi { $declaration }',
        hostMethods: {method},
        requiredVectors: vectors,
      );

  test('primitive responses do not pretend to exercise JSON parsing', () {
    expect(requiredFor('rlnVssBackup', 'int rlnVssBackup(int nodeId);'), {
      'native-unknown-node-error',
      'platform-smoke-or-regtest-success',
    });
    expect(
      requiredFor(
        'rlnListPeers',
        'List<RlnWireResponse> rlnListPeers(int nodeId);',
      ),
      {
        'dart-malformed-wire',
        'native-unknown-node-error',
        'platform-smoke-or-regtest-success',
      },
    );
  });
  test('new numeric and JSON fields automatically require their vectors', () {
    expect(
      requiredFor(
        'newMethod',
        'RlnWireResponse newMethod(int nodeId, List<int> amounts);',
      ),
      vectors,
    );
    expect(
      requiredFor(
        'newMethod',
        'RlnWireResponse newMethod(int nodeId, double? feeRate);',
      ),
      vectors,
    );
    expect(
      requiredFor(
        'newMethod',
        'RlnWireResponse newMethod(int nodeId, {int? amount});',
      ),
      vectors,
    );
  });
  test('only accepted native-blocked backup substitutes unsupported proof', () {
    expect(
      requiredFor('rlnBackup', 'void rlnBackup(int nodeId, String path);'),
      {
        'dart-delegation',
        'dart-platform-error-mapping',
        'native-explicit-unsupported',
      },
    );
    expect(
      requiredFor('otherBackup', 'void otherBackup(int nodeId, String path);'),
      contains('platform-smoke-or-regtest-success'),
    );
  });
  test('missing methods fail closed instead of receiving exclusions', () {
    expect(() => requiredFor('missing', 'void another();'), throwsStateError);
  });
}
