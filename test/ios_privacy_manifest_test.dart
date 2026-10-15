import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'privacy contents validate and malformed/reasonless manifests fail',
    () async {
      final valid = await Process.run('python3', [
        'tool/validate_ios_privacy.py',
        'ios/Resources/PrivacyInfo.xcprivacy',
      ]);
      expect(valid.exitCode, 0, reason: '${valid.stderr}');
      final temp = Directory.systemTemp.createTempSync('rgb-privacy-test-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final source = File(
        'ios/Resources/PrivacyInfo.xcprivacy',
      ).readAsStringSync();
      for (final invalid in [
        'not a plist',
        source.replaceFirst('C617.1', 'made-up-reason'),
        source.replaceFirst('C617.1', ''),
        source.replaceFirst('<false/>', '<true/>'),
        source.replaceFirst('NSPrivacyAccessedAPITypes', 'MisspelledAPITypes'),
        source.replaceFirst(
          'NSPrivacyAccessedAPICategoryFileTimestamp',
          'NSPrivacyAccessedAPICategoryDiskSpace',
        ),
      ]) {
        final fixture = File('${temp.path}/invalid.xcprivacy')
          ..writeAsStringSync(invalid);
        final result = await Process.run('python3', [
          'tool/validate_ios_privacy.py',
          fixture.path,
        ]);
        expect(result.exitCode, 1, reason: invalid);
      }
    },
  );
}
