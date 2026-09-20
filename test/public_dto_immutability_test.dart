import 'package:flutter_test/flutter_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';

void main() {
  group('public DTO collection boundaries', () {
    test('wallet config and request lists are defensively copied', () {
      final peers = <String>['peer-a'];
      final config = UtexoWalletConfig(
        storageDirPath: '/tmp/rgb-wallet-test',
        virtualPeerPubkeys: peers,
      );
      peers.add('peer-b');

      expect(config.virtualPeerPubkeys, <String>['peer-a']);
      expect(
        () => config.virtualPeerPubkeys!.add('peer-c'),
        throwsUnsupportedError,
      );

      final announceAddresses = <String>['127.0.0.1:9735'];
      final unlockConfig = UtexoUnlockConfig(
        announceAddresses: announceAddresses,
      );
      announceAddresses.add('127.0.0.1:9736');

      expect(unlockConfig.announceAddresses, <String>['127.0.0.1:9735']);
      expect(
        () => unlockConfig.announceAddresses.add('127.0.0.1:9737'),
        throwsUnsupportedError,
      );

      final inflationAmounts = <int>[1, 2];
      final request = InflateAssetIfaRequest(
        assetId: 'asset',
        inflationAmounts: inflationAmounts,
      );
      inflationAmounts.add(3);

      expect(request.inflationAmounts, <int>[1, 2]);
      expect(() => request.inflationAmounts.add(4), throwsUnsupportedError);
    });

    test('native and core model lists are unmodifiable', () {
      final endpoints = <String>['endpoint-a'];
      final decoded = RlnDecodedRgbInvoice(
        recipientId: 'recipient',
        proxyRecipientId: 'proxy-recipient',
        recipientType: 'Blind',
        assignment: 'Fungible(1)',
        network: 'regtest',
        transportEndpoints: endpoints,
      );
      endpoints.add('endpoint-b');

      expect(decoded.transportEndpoints, <String>['endpoint-a']);
      expect(
        () => decoded.transportEndpoints.add('endpoint-c'),
        throwsUnsupportedError,
      );

      final assignments = <String>['Fungible(1)'];
      final transportEndpoints = <RlnTransferTransportEndpoint>[
        const RlnTransferTransportEndpoint(
          endpoint: 'endpoint-a',
          transportType: 'JsonRpc',
          used: true,
        ),
      ];
      final transfer = RlnTransfer(
        idx: 1,
        createdAt: 1,
        updatedAt: 2,
        status: 'Settled',
        assignments: assignments,
        kind: 'Send',
        transportEndpoints: transportEndpoints,
      );
      assignments.add('Fungible(2)');
      transportEndpoints.add(
        const RlnTransferTransportEndpoint(
          endpoint: 'endpoint-b',
          transportType: 'JsonRpc',
          used: false,
        ),
      );

      expect(transfer.assignments, <String>['Fungible(1)']);
      expect(transfer.transportEndpoints, hasLength(1));
      expect(
        () => transfer.assignments.add('Fungible(3)'),
        throwsUnsupportedError,
      );
      expect(
        () => transfer.transportEndpoints.add(
          const RlnTransferTransportEndpoint(
            endpoint: 'endpoint-c',
            transportType: 'JsonRpc',
            used: false,
          ),
        ),
        throwsUnsupportedError,
      );

      final coreTransfer = transfer.toCore();
      expect(
        coreTransfer.transportEndpoints.single,
        isA<CoreTransferTransportEndpoint>(),
      );
      expect(
        () => coreTransfer.assignments.add(const Assignment(type: 'Any')),
        throwsUnsupportedError,
      );
      expect(
        () => coreTransfer.transportEndpoints.add(
          const CoreTransferTransportEndpoint(
            endpoint: 'endpoint-c',
            transportType: 'JsonRpc',
            used: false,
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('APay response lists are defensively copied', () {
      final hashes = <ApayHashEntry>[
        const ApayHashEntry(hashIndex: 100, paymentHash: 'hash'),
      ];
      final response = ApayNewResponse(
        requestId: 'request',
        hostNodeId: 'host',
        protocolVersion: 1,
        orderId: 'order',
        status: 'active',
        acceptedThroughIndex: 100,
        nextIndexExpected: 101,
        unusedHashes: 1,
        refillBatchSize: 100,
        firstHashIndex: 100,
        lastHashIndex: 100,
        hashes: hashes,
      );
      hashes.add(const ApayHashEntry(hashIndex: 101, paymentHash: 'later'));

      expect(response.hashes, hasLength(1));
      expect(
        () => response.hashes.add(
          const ApayHashEntry(hashIndex: 102, paymentHash: 'mutation'),
        ),
        throwsUnsupportedError,
      );
    });
  });
}
