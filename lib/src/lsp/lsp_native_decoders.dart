import '../errors/rgb_sdk_exception.dart';
import '../models/rln_models.dart';
import 'lsp_types.dart';

ApayNewResponse decodeNativeApayNewResponse(RlnMap map) {
  return ApayNewResponse(
    requestId: _requiredString(map, 'requestId', 'ApayNewResponse'),
    hostNodeId: _requiredString(map, 'hostNodeId', 'ApayNewResponse'),
    protocolVersion: _requiredInt(map, 'protocolVersion', 'ApayNewResponse'),
    orderId: _requiredString(map, 'orderId', 'ApayNewResponse'),
    status: _requiredString(map, 'status', 'ApayNewResponse'),
    acceptedThroughIndex: _requiredInt(
      map,
      'acceptedThroughIndex',
      'ApayNewResponse',
    ),
    nextIndexExpected: _requiredInt(
      map,
      'nextIndexExpected',
      'ApayNewResponse',
    ),
    unusedHashes: _requiredInt(map, 'unusedHashes', 'ApayNewResponse'),
    refillBatchSize: _requiredInt(map, 'refillBatchSize', 'ApayNewResponse'),
    firstHashIndex: _requiredInt(map, 'firstHashIndex', 'ApayNewResponse'),
    lastHashIndex: _requiredInt(map, 'lastHashIndex', 'ApayNewResponse'),
    hashes: _mapList(map['hashes'], 'ApayNewResponse.hashes')
        .map(
          (entry) => ApayHashEntry(
            hashIndex: _requiredInt(entry, 'hashIndex', 'ApayHashEntry'),
            paymentHash: _requiredString(entry, 'paymentHash', 'ApayHashEntry'),
          ),
        )
        .toList(growable: false),
  );
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
  if (value is String && value.isNotEmpty) return value;
  throw NativeProtocolException(
    '$typeName.$key must be a non-empty string.',
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
