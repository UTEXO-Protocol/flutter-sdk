import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_webrgb.dart';
import 'package:rgb_sdk_flutter/src/wallet/burn_recipient.dart' as recipient;

void main() {
  test('EIP-155 policy, codec and journal require the whole chain ID', () {
    const address = '0x1212121212121212121212121212121212121212';
    final commitment = encodeEvmBurnRecipient(address);
    final valid = BurnOperationRecord(
      id: 'pending',
      params: BurnParams(
        assetId: 'rgb:asset',
        amount: '1',
        burnRecipient: commitment,
        feeRate: 2,
        minConfirmations: 3,
      ),
      metadata: const BurnOperationMetadata(
        origin: 'https://mint.example',
        network: 'regtest',
        payout: BurnPayout(chainId: 'eip155:1', address: address),
      ),
      state: BurnOperationState.pending,
    ).toJson();
    expect(recipient.isSupportedBurnPayoutChain('eip155:1'), isTrue);
    expect(recipient.encodeBurnRecipient('eip155:1', address), commitment);
    expect(normalizeBurnRecord(valid).metadata.payout.chainId, 'eip155:1');
    for (final chain in [
      'eip155:1\n',
      'eip155:1\r',
      'eip155:1\r\n',
      'eip155:1\u2028',
      'eip155:1\u2029',
      'eip155:1\u0000',
      'eip155:1\t',
      'eip155:1 ',
      ' eip155:1',
    ]) {
      expect(recipient.isSupportedBurnPayoutChain(chain), isFalse);
      expect(
        () => recipient.encodeBurnRecipient(chain, address),
        throwsA(isA<WalletValidationException>()),
      );
      expect(
        () => normalizeBurnRecord({
          ...valid,
          'metadata': {
            ...valid['metadata']! as Map<String, Object?>,
            'payout': {'chainId': chain, 'address': address},
          },
        }),
        throwsA(isA<WalletValidationException>()),
      );
    }
  });

  test(
    'Tron vectors encode only the 20 account bytes into a 32-byte recipient',
    () {
      // USDT's public Tron contract address, also used by the RN parity vectors.
      expect(
        encodeTronBurnRecipient('TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t'),
        '${'0' * 24}a614f803b6fd780986a42c78ec9c7f77e6ded13c',
      );
      // Independently generated Base58Check vector for account bytes 0x01..0x14.
      expect(
        encodeTronBurnRecipient('TA4Y62o6YC2Zsck9rZVGTvqW1AQ7X9zTnj'),
        '${'0' * 24}0102030405060708090a0b0c0d0e0f1011121314',
      );
    },
  );

  test(
    'Tron checksum, prefix, zero account, case and bounded syntax fail closed',
    () {
      for (final address in [
        'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6a',
        'TZQ7s7Wkv2SyN5pgpJ7AMdTsXyvYLbktsg', // Valid checksum, version 0x42.
        'T9yD14Nj9j7xAB4dbGeiX9h8unkKHxuWwb', // Zero account.
        'tr7nhqjekqxgtci8q8zy4pl8otszgjlj6t',
        'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6T', // Case changes checksum bytes.
        ' TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
        'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t\n',
        'T${'1' * 32}',
        'T${'1' * 34}',
        'T${'0' * 33}',
        '',
      ]) {
        expect(
          () => encodeTronBurnRecipient(address),
          throwsA(
            isA<WebRgbError>().having((e) => e.code, 'code', 'INVALID_PARAMS'),
          ),
        );
      }
    },
  );

  test(
    'journal requires supported payout chain and the committed account bytes',
    () {
      const payout = BurnPayout(
        chainId: 'tron:728126428',
        address: 'TR7NHqjeKQxGTCi8q8ZY4pL8otSzgjLj6t',
      );
      final commitment = encodeTronBurnRecipient(payout.address);
      final valid = BurnOperationRecord(
        id: 'pending',
        params: BurnParams(
          assetId: 'rgb:asset',
          amount: '1',
          burnRecipient: commitment,
          feeRate: 2,
          minConfirmations: 3,
        ),
        metadata: const BurnOperationMetadata(
          origin: 'https://mint.example',
          network: 'regtest',
          payout: payout,
        ),
        state: BurnOperationState.pending,
      ).toJson();
      expect(
        normalizeBurnRecord(valid).metadata.payout.address,
        payout.address,
      );
      for (final badPayout in [
        {'chainId': payout.chainId, 'address': payout.address.toLowerCase()},
        {'chainId': 'tron:1', 'address': payout.address},
        {'chainId': 'eip155:1', 'address': payout.address},
        {
          'chainId': payout.chainId,
          'address': 'TA4Y62o6YC2Zsck9rZVGTvqW1AQ7X9zTnj',
        },
      ]) {
        expect(
          () => normalizeBurnRecord({
            ...valid,
            'metadata': {
              ...valid['metadata']! as Map<String, Object?>,
              'payout': badPayout,
            },
          }),
          throwsA(isA<WalletValidationException>()),
        );
      }
    },
  );
}
