import 'dart:convert';
import 'dart:io';

import 'evidence_report.dart';

void main(List<String> args) {
  if (args.length != 2) {
    throw ArgumentError('Expected report directory and run ID.');
  }
  final root = Directory.current;
  final directory = Directory(args[0]);
  final runId = args[1];
  final candidate = candidateIdentity();
  final errors = <String>[];
  final ios = Platform.environment['IOS_DEVICE'];
  final android = Platform.environment['ANDROID_DEVICE'];
  if (ios == null || ios.isEmpty || android == null || android.isEmpty) {
    stderr.writeln(
      'Both explicit platform devices are required for child evidence.',
    );
    exit(1);
  }
  final expected = <String>{
    'clean-consumer-matrix/',
    'native-android-jvm/',
    'native-ios-xctest/$ios',
    for (final device in [ios, android]) ...[
      'platform-unfunded-regtest/$device',
      'platform-funded-regtest/$device',
      'external-signer-process-restart/$device',
    ],
  };
  final seen = <String>{};
  final children = <Map<String, String>>[];
  for (final file in directory.listSync().whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;
    final value = jsonDecode(file.readAsStringSync());
    if (value is! Map<String, Object?> || value['runId'] != runId) continue;
    final key = '${value['suite']}/${value['device'] ?? ''}';
    if (!expected.contains(key)) continue;
    if (!seen.add(key)) errors.add('Duplicate report for $key.');
    errors.addAll(
      evidenceReportErrors(
        value,
        candidate: candidate,
        runId: runId,
        root: root,
      ).map((error) => '$key: $error'),
    );
    children.add({
      'path': file.absolute.path.replaceAll(root.path, '<repo>'),
      'sha256': fileDigest(file),
    });
  }
  errors.addAll(
    expected.difference(seen).map((key) => 'Missing child report: $key'),
  );
  if (errors.isNotEmpty) {
    stderr.writeln(errors.join('\n'));
    exit(1);
  }
  File('${directory.path}/children-$runId.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'runId': runId, 'children': children})}\n',
  );
  stdout.writeln(
    'Validated ${children.length} clean child reports and completed logs.',
  );
}
