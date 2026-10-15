import 'package:flutter_test/flutter_test.dart';

import '../tool/native_security_policy.dart';

void main() {
  test('current exact native source cannot qualify through Pub-only audit', () {
    final blockers = nativeProductionBlockers(
      'ecc69f20308231400561f6f060fea88acfa40cc4',
    );
    expect(blockers, hasLength(4));
    for (final finding in ['P03:', 'P04:', 'P06:', 'RUSTSEC-2026-0098/0099']) {
      expect(blockers.any((blocker) => blocker.contains(finding)), true);
    }
  });
  test('new source pin does not silently inherit an old source review', () {
    final blockers = nativeProductionBlockers('1' * 40);
    expect(blockers, hasLength(1));
    expect(blockers.single, contains('no approved production'));
  });
}
