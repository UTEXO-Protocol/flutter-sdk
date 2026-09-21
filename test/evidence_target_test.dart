import 'package:flutter_test/flutter_test.dart';

import '../tool/evidence_target.dart';

void main() {
  test('Dart evidence names must be actual registrations, not comments', () {
    expect(
      registeredTestNames('example.dart', '''
// test('fake', () {});
const notes = "test('also fake', () {})";
void main() { group('family', () { test('real', () {}); }); }
'''),
      <String>{'family', 'real'},
    );
  });
  test('shell labels are not executable test registration evidence', () {
    expect(registeredTestNames('runner.sh', 'echo funded-hodl-smoke'), isEmpty);
  });
  test('native registration names are resolved explicitly', () {
    expect(
      registeredTestNames('Test.kt', '@Test\nfun drainsQueue() {}'),
      <String>{'drainsQueue'},
    );
    expect(
      registeredTestNames('Test.swift', 'func testDrainsQueue() {}'),
      <String>{'testDrainsQueue'},
    );
  });
}
