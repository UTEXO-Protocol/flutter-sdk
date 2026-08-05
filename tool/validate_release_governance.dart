import 'dart:convert';
import 'dart:io';

const _trackerPath = 'doc/RELEASE_READINESS_TRACKER.md';
const _apiPolicyPath = 'doc/API_COMPATIBILITY_AND_DIVERGENCE.md';
const _evidenceSchemaPath = 'doc/RELEASE_EVIDENCE_SCHEMA.md';
const _evidenceCatalogPath = 'tool/test_matrix/evidence_catalog.json';

void main() {
  final errors = <String>[];

  final tracker = _read(_trackerPath, errors);
  final rows = _parseIssueRows(tracker);
  _validateRollup(tracker, rows, errors);
  _validateOpenGroups(tracker, rows, errors);

  final apiPolicy = _read(_apiPolicyPath, errors);
  _requireSections(_apiPolicyPath, apiPolicy, <String>[
    '## Source Precedence',
    '## Approved Divergence Register',
    '## API Stability Tiers',
    '## Dart Adaptation Map',
    '## Deprecation and Breaking-Change Plan',
    '## Architecture Decisions',
    '### Bridge Technology',
    '### Artifact Ownership',
    '### Stable Layering',
  ], errors);
  for (final id in <String>[
    'API-006',
    'API-017',
    'API-019',
    'API-030',
    'SEC-009',
    'TEST-017',
  ]) {
    if (!apiPolicy.contains(id)) {
      errors.add('$_apiPolicyPath must cite divergence tracker row $id.');
    }
  }

  final evidenceSchema = _read(_evidenceSchemaPath, errors);
  _requireSections(_evidenceSchemaPath, evidenceSchema, <String>[
    '## Evidence Identifier',
    '## Required Report Fields',
    '## Sanitization Rules',
    '## Matrix Evidence Catalog',
    '## API and ABI Snapshots',
    '## Documentation Completeness Criteria',
  ], errors);

  _validateEvidenceCatalog(errors);

  final readme = _read('README.md', errors);
  if (readme.contains('no\n`.fvmrc`') || readme.contains('no `.fvmrc`')) {
    errors.add('README.md still claims the repository has no .fvmrc.');
  }
  for (final path in <String>[
    _apiPolicyPath,
    'doc/BRIDGE_BEHAVIOR_CONTRACT.md',
    _evidenceSchemaPath,
    'doc/INTEGRATION_SECURITY_AND_RELEASE.md',
  ]) {
    if (!readme.contains(path)) {
      errors.add('README.md must link to $path.');
    }
  }

  if (errors.isNotEmpty) {
    stderr.writeln('Release governance validation failed:');
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exit(1);
  }

  stdout.writeln('Release governance validation passed.');
}

String _read(String path, List<String> errors) {
  final file = File(path);
  if (!file.existsSync()) {
    errors.add('Missing required file: $path');
    return '';
  }
  return file.readAsStringSync();
}

List<_IssueRow> _parseIssueRows(String tracker) {
  final issuePattern = RegExp(
    r'^\|\s*([A-Z]+-\d{3})\s*\|\s*(P\d)\s*\|\s*([^|]+?)\s*\|',
    multiLine: true,
  );
  return issuePattern
      .allMatches(tracker)
      .map(
        (match) => _IssueRow(
          id: match.group(1)!,
          priority: match.group(2)!,
          status: match.group(3)!.trim(),
        ),
      )
      .toList(growable: false);
}

void _validateRollup(
  String tracker,
  List<_IssueRow> rows,
  List<String> errors,
) {
  final expected = <String, int>{
    'Total tracked findings': rows.length,
    'P0': rows.where((row) => row.priority == 'P0').length,
    'P1': rows.where((row) => row.priority == 'P1').length,
    'P2': rows.where((row) => row.priority == 'P2').length,
    'Open': rows.where((row) => row.status == 'Open').length,
    'In progress': rows.where((row) => row.status == 'In progress').length,
    'Needs decision': rows
        .where((row) => row.status == 'Needs decision')
        .length,
    'Accepted constraint': rows
        .where((row) => row.status == 'Accepted constraint')
        .length,
    'Verified': rows.where((row) => row.status == 'Verified').length,
  };

  for (final entry in expected.entries) {
    final pattern = RegExp(
      r'\|\s*' + RegExp.escape(entry.key) + r'\s*\|\s*(\d+)\s*\|',
    );
    final match = pattern.firstMatch(tracker);
    if (match == null) {
      errors.add('Issue Rollup is missing ${entry.key}.');
      continue;
    }
    final actual = int.parse(match.group(1)!);
    if (actual != entry.value) {
      errors.add(
        'Issue Rollup ${entry.key} is $actual but ledger count is ${entry.value}.',
      );
    }
  }
}

void _validateOpenGroups(
  String tracker,
  List<_IssueRow> rows,
  List<String> errors,
) {
  final openIds = rows
      .where((row) => row.status == 'Open')
      .map((row) => row.id)
      .toSet();
  final groupIds = <String>[];
  final groupPattern = RegExp(
    r'^\|\s*\d+\s*\|[^|]*\|\s*([^|]+?)\s*\|\s*(\d+)\s*\|\s*(\d+)/(\d+)\s*\|',
    multiLine: true,
  );

  final priorityById = <String, String>{
    for (final row in rows) row.id: row.priority,
  };

  for (final match in groupPattern.allMatches(tracker)) {
    final ids = RegExp(r'[A-Z]+-\d{3}')
        .allMatches(match.group(1)!)
        .map((match) => match.group(0)!)
        .toList(growable: false);
    final declaredCount = int.parse(match.group(2)!);
    final declaredP1 = int.parse(match.group(3)!);
    final declaredP2 = int.parse(match.group(4)!);
    if (ids.length != declaredCount) {
      errors.add(
        'Open work group declares count $declaredCount but lists ${ids.length}: ${ids.join(', ')}.',
      );
    }
    final actualP1 = ids.where((id) => priorityById[id] == 'P1').length;
    final actualP2 = ids.where((id) => priorityById[id] == 'P2').length;
    if (actualP1 != declaredP1 || actualP2 != declaredP2) {
      errors.add(
        'Open work group ${ids.join(', ')} declares P1/P2 $declaredP1/$declaredP2 '
        'but ledger has $actualP1/$actualP2.',
      );
    }
    groupIds.addAll(ids);
  }

  final grouped = groupIds.toSet();
  final missing = openIds.difference(grouped).toList()..sort();
  final extra = grouped.difference(openIds).toList()..sort();
  final duplicates = <String>{};
  final seen = <String>{};
  for (final id in groupIds) {
    if (!seen.add(id)) duplicates.add(id);
  }
  if (missing.isNotEmpty) {
    errors.add('Open work groups miss: ${missing.join(', ')}.');
  }
  if (extra.isNotEmpty) {
    errors.add('Open work groups include non-open rows: ${extra.join(', ')}.');
  }
  if (duplicates.isNotEmpty) {
    final sorted = duplicates.toList()..sort();
    errors.add('Open work groups contain duplicates: ${sorted.join(', ')}.');
  }
}

void _requireSections(
  String path,
  String text,
  List<String> sections,
  List<String> errors,
) {
  for (final section in sections) {
    if (!text.contains(section)) {
      errors.add('$path is missing required section: $section.');
    }
  }
}

void _validateEvidenceCatalog(List<String> errors) {
  final text = _read(_evidenceCatalogPath, errors);
  if (text.isEmpty) return;
  final catalog = jsonDecode(text) as Map<String, Object?>;
  if (catalog['schemaVersion'] != 1) {
    errors.add('$_evidenceCatalogPath must have schemaVersion 1.');
  }
  final buckets = catalog['buckets'];
  if (buckets is! Map<String, Object?>) {
    errors.add('$_evidenceCatalogPath must contain a buckets object.');
    return;
  }
  for (final matrixPath in <String>[
    'tool/test_matrix/rln_methods.json',
    'tool/test_matrix/wallet_methods.json',
    'tool/test_matrix/core_exports.json',
  ]) {
    final matrix =
        jsonDecode(File(matrixPath).readAsStringSync()) as Map<String, Object?>;
    final methods = matrix['methods'] as List<Object?>;
    for (final row in methods.cast<Map<String, Object?>>()) {
      final bucket = row['evidenceBucket'];
      if (bucket is! String || !buckets.containsKey(bucket)) {
        errors.add(
          '$matrixPath/${row['id']} uses uncataloged evidence bucket: $bucket.',
        );
      }
    }
  }

  for (final entry in buckets.entries) {
    final value = entry.value;
    if (value is! Map<String, Object?>) {
      errors.add('Evidence bucket ${entry.key} must be an object.');
      continue;
    }
    for (final field in <String>['claimLevel', 'testIds', 'assertions']) {
      if (!value.containsKey(field)) {
        errors.add('Evidence bucket ${entry.key} is missing $field.');
      }
    }
    if (value['testIds'] is! List || (value['testIds'] as List).isEmpty) {
      errors.add('Evidence bucket ${entry.key} must list executable testIds.');
    }
    if (value['assertions'] is! List || (value['assertions'] as List).isEmpty) {
      errors.add('Evidence bucket ${entry.key} must list assertions.');
    }
  }
}

final class _IssueRow {
  const _IssueRow({
    required this.id,
    required this.priority,
    required this.status,
  });

  final String id;
  final String priority;
  final String status;
}
