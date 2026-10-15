import 'dart:convert';
import 'dart:io';

/// Exact inputs of the source/symbol audit in doc/IOS_PRIVACY_API_AUDIT.md.
/// This audit found an unresolved category; it is not production approval.
const auditedIosPrivacySourceCommit =
    'ecc69f20308231400561f6f060fea88acfa40cc4';
const auditedIosPrivacyArchiveSha256 =
    'dd5c483753e58c0c1c49f94098a2cc6eef18e16d3eebd167d31131fbd888890a';

/// Code-backed privacy disposition. Release metadata, manifests, signatures and
/// environment variables cannot approve an unreviewed native API call path.
/// Add a positive disposition only after reviewing exact replacement inputs and
/// the final signed archive's required-API report and aggregate manifests.
Map<String, Object?> nativeIosPrivacyDisposition({
  required Object? sourceCommit,
  required Object? archiveSha256,
}) {
  final known =
      sourceCommit == auditedIosPrivacySourceCommit &&
      archiveSha256 == auditedIosPrivacyArchiveSha256;
  return <String, Object?>{
    'scope': 'native-ios-required-reason-api',
    'sourceCommit': sourceCommit,
    'archiveSha256': archiveSha256,
    'status': known ? 'blocked-known-unresolved' : 'unreviewed',
    'productionReady': false,
    'blockers': known
        ? const <String>[
            'iOS privacy: the exact pinned native archive retains statfs/fstatfs/fstatvfs with no reviewed, truthful DiskSpace required-reason disposition. FileTimestamp C617.1 does not close this category. The native publisher must remove unused calls or justify the actual linked use; final signed-archive API and aggregate privacy reports remain required.',
          ]
        : const <String>[
            'iOS privacy: this native source/archive pair has no code-backed required-reason API disposition. Review exact native inputs and final signed-archive API and aggregate privacy reports before production approval.',
          ],
  };
}

/// A dependency-free production preflight, before builds or supplied evidence.
void main(List<String> args) {
  if (args.isNotEmpty && (args.length != 1 || args.single != '--production')) {
    stderr.writeln('Unsupported native privacy validation mode.');
    exitCode = 64;
    return;
  }
  final production = args.contains('--production');
  try {
    final baseline = jsonDecode(
      File('tool/release_baseline.json').readAsStringSync(),
    );
    final rln = baseline is Map<String, Object?> ? baseline['rln'] : null;
    final ios = rln is Map<String, Object?> ? rln['ios'] : null;
    final disposition = nativeIosPrivacyDisposition(
      sourceCommit: rln is Map<String, Object?> ? rln['commit'] : null,
      archiveSha256: ios is Map<String, Object?> ? ios['archiveSha256'] : null,
    );
    stdout.writeln(
      jsonEncode({
        ...disposition,
        'mode': production ? 'production' : 'internal-beta',
      }),
    );
    if (production && disposition['productionReady'] != true) exitCode = 1;
  } on Object {
    stderr.writeln('Native iOS privacy input validation failed.');
    exitCode = 1;
  }
}
