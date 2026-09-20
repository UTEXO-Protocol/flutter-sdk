import '../errors/rgb_sdk_exception.dart';
import '../models/rln_models.dart';
import 'lsp_protocol_policy.dart';
import 'lsp_types.dart';

ApayNewResponse decodeNativeApayNewResponse(
  RlnMap map, {
  required String expectedHostNodeId,
}) {
  final hostNodeId = _requiredString(map, 'hostNodeId', 'ApayNewResponse');
  if (hostNodeId.toLowerCase() != expectedHostNodeId.trim().toLowerCase()) {
    throw NativeProtocolException(
      'ApayNewResponse.hostNodeId does not match the requested host.',
      field: 'ApayNewResponse.hostNodeId',
    );
  }
  final protocolVersion = _requiredInt(
    map,
    'protocolVersion',
    'ApayNewResponse',
  );
  if (protocolVersion != ApayProtocolPolicy.protocolVersion) {
    throw NativeProtocolException(
      'ApayNewResponse.protocolVersion is unsupported.',
      field: 'ApayNewResponse.protocolVersion',
    );
  }
  final status = _requiredString(map, 'status', 'ApayNewResponse');
  if (status != ApayProtocolPolicy.activeStatus) {
    throw NativeProtocolException(
      'ApayNewResponse.status must be "${ApayProtocolPolicy.activeStatus}".',
      field: 'ApayNewResponse.status',
    );
  }
  final acceptedThroughIndex = _requiredNonNegativeInt(
    map,
    'acceptedThroughIndex',
    'ApayNewResponse',
  );
  final nextIndexExpected = _requiredPositiveInt(
    map,
    'nextIndexExpected',
    'ApayNewResponse',
  );
  final unusedHashes = _requiredNonNegativeInt(
    map,
    'unusedHashes',
    'ApayNewResponse',
  );
  final refillBatchSize = _requiredPositiveInt(
    map,
    'refillBatchSize',
    'ApayNewResponse',
  );
  if (refillBatchSize > ApayProtocolPolicy.maxBatchSize) {
    throw NativeProtocolException(
      'ApayNewResponse.refillBatchSize exceeds the APay protocol maximum.',
      field: 'ApayNewResponse.refillBatchSize',
    );
  }
  final firstHashIndex = _requiredPositiveInt(
    map,
    'firstHashIndex',
    'ApayNewResponse',
  );
  final lastHashIndex = _requiredPositiveInt(
    map,
    'lastHashIndex',
    'ApayNewResponse',
  );
  if (firstHashIndex > lastHashIndex ||
      lastHashIndex > ApayProtocolPolicy.maxHashIndex) {
    throw NativeProtocolException(
      'ApayNewResponse hash range is outside the APay BIP32 derivation range.',
      field: 'ApayNewResponse.lastHashIndex',
    );
  }
  final hashes = _mapList(map['hashes'], 'ApayNewResponse.hashes')
      .map(
        (entry) => ApayHashEntry(
          hashIndex: _requiredPositiveInt(entry, 'hashIndex', 'ApayHashEntry'),
          paymentHash: _requiredString(entry, 'paymentHash', 'ApayHashEntry'),
        ),
      )
      .toList(growable: false);
  _validateHashBatch(
    hashes: hashes,
    firstHashIndex: firstHashIndex,
    lastHashIndex: lastHashIndex,
    acceptedThroughIndex: acceptedThroughIndex,
    nextIndexExpected: nextIndexExpected,
  );
  return ApayNewResponse(
    requestId: _requiredString(map, 'requestId', 'ApayNewResponse'),
    hostNodeId: hostNodeId,
    protocolVersion: protocolVersion,
    orderId: _requiredString(map, 'orderId', 'ApayNewResponse'),
    status: status,
    acceptedThroughIndex: acceptedThroughIndex,
    nextIndexExpected: nextIndexExpected,
    unusedHashes: unusedHashes,
    refillBatchSize: refillBatchSize,
    firstHashIndex: firstHashIndex,
    lastHashIndex: lastHashIndex,
    hashes: hashes,
  );
}

void _validateHashBatch({
  required List<ApayHashEntry> hashes,
  required int firstHashIndex,
  required int lastHashIndex,
  required int acceptedThroughIndex,
  required int nextIndexExpected,
}) {
  final expectedLength = lastHashIndex - firstHashIndex + 1;
  if (hashes.isEmpty ||
      hashes.length != expectedLength ||
      hashes.length > ApayProtocolPolicy.maxBatchSize) {
    throw NativeProtocolException(
      'ApayNewResponse.hashes must exactly cover the reported hash range.',
      field: 'ApayNewResponse.hashes',
    );
  }
  for (var offset = 0; offset < hashes.length; offset += 1) {
    final hash = hashes[offset];
    if (hash.hashIndex != firstHashIndex + offset) {
      throw NativeProtocolException(
        'ApayNewResponse.hashes must use contiguous hash indices.',
        field: 'ApayNewResponse.hashes[$offset].hashIndex',
      );
    }
    if (!ApayProtocolPolicy.isPaymentHash(hash.paymentHash)) {
      throw NativeProtocolException(
        'ApayNewResponse.hashes payment hashes must be 32-byte hexadecimal.',
        field: 'ApayNewResponse.hashes[$offset].paymentHash',
      );
    }
  }
  if (acceptedThroughIndex != lastHashIndex ||
      nextIndexExpected != lastHashIndex + 1) {
    throw NativeProtocolException(
      'ApayNewResponse accepted/next indices do not match the hash batch.',
      field: 'ApayNewResponse.nextIndexExpected',
    );
  }
}

int _requiredInt(RlnMap map, String key, String typeName) {
  final value = map[key];
  final parsed = switch (value) {
    int() => value,
    double() when value.isFinite && value % 1 == 0 => value.toInt(),
    String() => int.tryParse(value),
    _ => null,
  };
  if (parsed == null) {
    throw NativeProtocolException(
      '$typeName.$key must be an integer.',
      field: '$typeName.$key',
    );
  }
  return parsed;
}

String _requiredString(RlnMap map, String key, String typeName) {
  final value = map[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw NativeProtocolException(
    '$typeName.$key must be a non-empty string.',
    field: '$typeName.$key',
  );
}

int _requiredNonNegativeInt(RlnMap map, String key, String typeName) {
  final value = _requiredInt(map, key, typeName);
  if (value >= 0) return value;
  throw NativeProtocolException(
    '$typeName.$key must be a non-negative integer.',
    field: '$typeName.$key',
  );
}

int _requiredPositiveInt(RlnMap map, String key, String typeName) {
  final value = _requiredInt(map, key, typeName);
  if (value > 0) return value;
  throw NativeProtocolException(
    '$typeName.$key must be a positive integer.',
    field: '$typeName.$key',
  );
}

List<RlnMap> _mapList(Object? value, String field) {
  if (value is! List) {
    throw NativeProtocolException('$field must be a list.', field: field);
  }
  return List<RlnMap>.unmodifiable(
    value.map((item) {
      if (item is! Map) {
        throw NativeProtocolException(
          '$field entries must be maps.',
          field: field,
        );
      }
      return Map<Object?, Object?>.from(item);
    }),
  );
}
