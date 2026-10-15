import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'android_elf.dart';

// Use the ELF checks for every native dependency in an AAR/APK/AAB. AAR and AAB
// ZIP offsets do not describe the installed APK's mmap alignment. The app's
// final APK must additionally pass `zipalign -c -P 16 4` and device tests.
Future<void> main(List<String> args) async {
  final options = <String, String>{};
  try {
    for (var i = 0; i < args.length; i += 2) {
      if (i + 1 >= args.length ||
          !<String>{
            '--archive',
            '--kind',
            '--expected-abis',
            '--elf',
            '--abi',
            '--report',
            '--zipalign',
          }.contains(args[i]) ||
          options.containsKey(args[i])) {
        throw const FormatException('Invalid or duplicate command option.');
      }
      options[args[i]] = args[i + 1];
    }
    final direct = options.containsKey('--elf');
    if (direct == options.containsKey('--archive') ||
        (direct &&
            (options['--abi'] == null ||
                options.containsKey('--kind') ||
                options.containsKey('--expected-abis') ||
                options.containsKey('--zipalign'))) ||
        (!direct && options.containsKey('--abi'))) {
      throw const FormatException(
        'Usage: --elf FILE --abi ABI, or --archive FILE --kind aar|apk|aab '
        '--expected-abis ABI,ABI [--zipalign PATH]; optional --report FILE.',
      );
    }
    final Map<String, Object?> report;
    if (direct) {
      final file = File(options['--elf']!);
      final bytes = await file.readAsBytes();
      final inspection = inspectAndroidElf(bytes, options['--abi']!);
      report = <String, Object?>{
        'schemaVersion': 1,
        'scope': 'elf-static-page-compatibility',
        'path': file.path,
        'sizeBytes': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
        ...inspection.toJson(),
      };
    } else {
      final kind = options['--kind'];
      if (!<String>{'aar', 'apk', 'aab'}.contains(kind) ||
          options['--expected-abis'] == null) {
        throw const FormatException(
          'Archive kind and expected ABIs are required.',
        );
      }
      final abis = options['--expected-abis']!.split(',');
      if (abis.isEmpty ||
          abis.toSet().length != abis.length ||
          abis.any((abi) => !androidElfAbis.containsKey(abi))) {
        throw const FormatException(
          'Expected ABIs must be unique known Android ABIs.',
        );
      }
      report = await inspectAndroidArchive(
        File(options['--archive']!),
        kind!,
        abis.toSet(),
      );
      final zipalign = options['--zipalign'];
      if (zipalign != null) {
        if (kind != 'apk') {
          throw const FormatException('--zipalign applies only to final APKs.');
        }
        final result = await Process.run(zipalign, <String>[
          '-c',
          '-P',
          '16',
          '4',
          options['--archive']!,
        ]);
        final passed = result.exitCode == 0;
        report['apkZipAlignment'] = <String, Object?>{'compatible': passed};
        if (!passed) {
          (report['failures']! as List<String>).add(
            'APK 16 KiB ZIP alignment failed.',
          );
          report['compatible'] = false;
        }
      }
    }
    final json = const JsonEncoder.withIndent('  ').convert(report);
    if (options['--report'] case final String destination) {
      final file = File(destination);
      await file.parent.create(recursive: true);
      await file.writeAsString('$json\n');
    }
    stdout.writeln(json);
    if (report['compatible'] != true) exitCode = 1;
  } on Object catch (error) {
    stderr.writeln('Android ELF validation failed: $error');
    exitCode = 1;
  }
}

Future<Map<String, Object?>> inspectAndroidArchive(
  File archive,
  String kind,
  Set<String> expectedAbis,
) async {
  final root = switch (kind) {
    'aar' => 'jni',
    'apk' => 'lib',
    'aab' => 'base/lib',
    _ => throw const FormatException('Unsupported native archive kind.'),
  };
  if (expectedAbis.isEmpty ||
      expectedAbis.any((abi) => !androidElfAbis.containsKey(abi))) {
    throw const FormatException(
      'Expected ABI inventory is empty or unsupported.',
    );
  }
  final list = await Process.run('unzip', <String>['-Z1', archive.path]);
  if (list.exitCode != 0) {
    throw const FormatException('Cannot list native archive.');
  }
  final entries = list.stdout
      .toString()
      .split('\n')
      .where((entry) => entry.isNotEmpty)
      .toList();
  final nativeEntries = entries
      .where((entry) => entry.endsWith('.so'))
      .toList();
  final archiveDigest = (await sha256.bind(archive.openRead()).first)
      .toString();
  if (nativeEntries.isEmpty ||
      nativeEntries.toSet().length != nativeEntries.length) {
    throw const FormatException('Missing or duplicate native archive entries.');
  }
  final pathPattern = RegExp(
    '^${RegExp.escape(root)}/([a-z0-9_-]+)/'
    r'([A-Za-z0-9_.+-]+\.so)$',
  );
  final reports = <Map<String, Object?>>[];
  final failures = <String>[];
  final actualAbis = <String>{};
  for (final entry in nativeEntries..sort()) {
    final match = pathPattern.firstMatch(entry);
    if (match == null || !androidElfAbis.containsKey(match[1])) {
      throw FormatException('Unexpected native archive path: $entry');
    }
    final abi = match[1]!;
    actualAbis.add(abi);
    // Bound decompression instead of buffering untrusted archive contents without
    // a limit. No extraction occurs, including for duplicate or traversing names.
    final process = await Process.start('unzip', <String>[
      '-p',
      archive.path,
      entry,
    ]);
    final errorDrain = process.stderr.drain<void>();
    final builder = BytesBuilder(copy: false);
    await for (final chunk in process.stdout) {
      if (builder.length + chunk.length > 256 * 1024 * 1024) {
        process.kill();
        await process.exitCode;
        await errorDrain;
        throw FormatException('Native library exceeds 256 MiB limit: $entry');
      }
      builder.add(chunk);
    }
    if (await process.exitCode != 0) {
      throw FormatException('Cannot read native archive entry: $entry');
    }
    await errorDrain;
    try {
      final inspection = inspectAndroidElf(builder.takeBytes(), abi);
      reports.add(<String, Object?>{'entry': entry, ...inspection.toJson()});
      failures.addAll(inspection.failures.map((failure) => '$entry: $failure'));
    } on FormatException catch (error) {
      reports.add(<String, Object?>{
        'entry': entry,
        'abi': abi,
        'compatible': false,
        'failures': <String>[error.message],
      });
      failures.add('$entry: ${error.message}');
    }
  }
  if (actualAbis.length != expectedAbis.length ||
      !actualAbis.containsAll(expectedAbis)) {
    failures.add(
      'Native ABI inventory $actualAbis does not match $expectedAbis.',
    );
  }
  return <String, Object?>{
    'schemaVersion': 1,
    'scope': 'elf-static-page-compatibility',
    'archive': archive.path,
    'archiveSizeBytes': await archive.length(),
    'archiveSha256': archiveDigest,
    'kind': kind,
    'compatible': failures.isEmpty,
    'apkZipAlignment': 'not-checked',
    'expectedAbis': expectedAbis.toList()..sort(),
    'libraries': reports,
    'failures': failures,
  };
}
