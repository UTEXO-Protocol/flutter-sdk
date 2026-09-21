/// Parses a signed Dart/bridge integer without double or BigInt saturation.
/// Wire strings are decimal only; malformed/out-of-range values return null so
/// each boundary can report its own typed field error.
int? exactWireInt(Object? value) {
  if (value is int) return value;
  if (value is String && RegExp(r'^-?[0-9]+$').hasMatch(value)) {
    return int.tryParse(value);
  }
  // Larger doubles may already have rounded a different wire integer.
  if (value is double &&
      value.isFinite &&
      value % 1 == 0 &&
      value.abs() <= 9007199254740991) {
    final integer = BigInt.from(value);
    return integer.isValidInt ? integer.toInt() : null;
  }
  return null;
}
