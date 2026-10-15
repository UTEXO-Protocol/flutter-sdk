/// Supported release scopes. Historical reports without a profile are beta
/// evidence only; they cannot satisfy the mainnet-onchain production profile.
const mainnetOnchainProfile = 'mainnet-onchain';
const internalBetaProfile = 'internal-beta';
const releaseProfiles = {mainnetOnchainProfile, internalBetaProfile};

/// Required isolated-stack cases for the initial password-signer, onchain-only
/// release. These are qualification evidence requirements, never permission to
/// transact with mainnet funds or modify a shared development chain.
const onchainQualificationCases = <String>{
  'wallet-create-unlock',
  'btc-send-receive',
  'bfa-mint-backing',
  'bfa-burn-payout',
  'rgb-blind-send-receive',
  'rgb-witness-bound-send-receive',
  'rgb-witness-unbound-send-receive',
  'onchain-history-accounting',
  'password-interrupted-send-reconciliation',
  'rgb-reorg-reconfirm',
  'bfa-wrong-lock-valid-lock',
  'fresh-device-vss-restore',
  'mainnet-lightning-rejected',
  'mainnet-external-signer-rejected',
};

Set<String> expectedChildEvidence({
  required String profile,
  required String ios,
  required String android,
}) {
  if (!releaseProfiles.contains(profile)) {
    throw ArgumentError.value(profile, 'profile', 'Unknown release profile.');
  }
  if (ios.isEmpty || android.isEmpty || ios == android) {
    throw ArgumentError(
      'Distinct explicit iOS and Android devices are required.',
    );
  }
  return {
    'clean-consumer-matrix/',
    'native-android-jvm/',
    'native-ios-xctest/$ios',
    for (final device in [ios, android])
      if (profile == mainnetOnchainProfile)
        'platform-onchain-regtest/$device'
      else ...[
        'platform-unfunded-regtest/$device',
        'platform-funded-regtest/$device',
        'external-signer-process-restart/$device',
      ],
  };
}

/// A strict report boundary for independently operated qualification clients.
/// Reports are checksummed local evidence, not signed provenance attestations.
List<String> onchainQualificationErrors(Map<String, Object?> report) {
  final errors = <String>[];
  if (report['releaseProfile'] != mainnetOnchainProfile ||
      report['walletSigner'] != 'password' ||
      report['releaseNetwork'] != 'mainnet' ||
      report['testNetwork'] != 'regtest') {
    errors.add(
      'Onchain evidence must qualify mainnet password mode on regtest.',
    );
  }
  final stack = report['stackIdentity'];
  final ports = stack is Map<String, Object?> ? stack['ports'] : null;
  final services = stack is Map<String, Object?> ? stack['services'] : null;
  if (stack is! Map<String, Object?> ||
      stack['project'] != 'wdk-rln-017-qualification' ||
      stack['host'] != 'localhost' ||
      stack['containerLifecycle'] != 'preserved' ||
      ports is! Map<String, Object?> ||
      ports['rlnApi'] != 29301 ||
      ports['esplora'] != 29302 ||
      ports['rgbProxy'] != 29300 ||
      services is! List<Object?> ||
      services.isEmpty ||
      !{'rln', 'esplora', 'rgb-proxy'}.every(
        (role) => services.whereType<Map<String, Object?>>().any(
          (entry) => entry['role'] == role,
        ),
      ) ||
      !services.every(
        (entry) =>
            entry is Map<String, Object?> &&
            entry['containerId'] is String &&
            RegExp(
              r'^[a-f0-9]{64}$',
            ).hasMatch(entry['containerId']! as String) &&
            entry['imageId'] is String &&
            RegExp(
              r'^sha256:[a-f0-9]{64}$',
            ).hasMatch(entry['imageId']! as String),
      )) {
    errors.add('Missing preserved isolated qualification stack identities.');
  }
  final evm = report['bfaChainIdentity'];
  if (evm is! Map<String, Object?> ||
      evm['project'] != 'wdk-rln-017-bfa-anvil-20261014' ||
      evm['rpcUrl'] != 'http://localhost:29545' ||
      evm['chainId'] != 31337 ||
      evm['containerId'] is! String ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(evm['containerId']! as String) ||
      evm['imageId'] is! String ||
      !RegExp(r'^sha256:[a-f0-9]{64}$').hasMatch(evm['imageId']! as String) ||
      evm['containerLifecycle'] != 'preserved' ||
      evm['contractsPreserved'] != true) {
    errors.add('Missing preserved isolated BFA-chain identity.');
  }
  final cases = report['cases'];
  final seen = <String>{};
  if (cases is! List<Object?>) {
    errors.add('Missing onchain qualification cases.');
  } else {
    for (final entry in cases) {
      if (entry is! Map<String, Object?> ||
          entry['id'] is! String ||
          !onchainQualificationCases.contains(entry['id']) ||
          !seen.add(entry['id']! as String) ||
          entry['status'] != 'passed' ||
          entry['assertions'] is! List<Object?> ||
          (entry['assertions']! as List<Object?>).isEmpty ||
          !(entry['assertions']! as List<Object?>).every(
            (assertion) => assertion is String && assertion.trim().isNotEmpty,
          )) {
        errors.add('Unknown, duplicate, failed or unasserted onchain case.');
      }
    }
  }
  if (!seen.containsAll(onchainQualificationCases)) {
    errors.add(
      'Missing cases: ${onchainQualificationCases.difference(seen).join(', ')}.',
    );
  }
  return errors;
}
