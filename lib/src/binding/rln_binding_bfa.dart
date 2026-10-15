part of 'rln_binding.dart';

mixin _RlnBindingBfa on _RlnBindingInternals {
  Future<ImportedRgbContract> rlnImportRgbContract({
    required String contractBase64,
    required String expectedAssetId,
  }) {
    validateRgbContractImport(contractBase64, expectedAssetId);
    return _withNodeOperation(
      'rlnImportRgbContract',
      (nodeId) async => ImportedRgbContract.fromMap(
        await _client.importRgbContract(
          nodeId: nodeId,
          contractBase64: contractBase64,
          expectedAssetId: expectedAssetId,
        ),
        expectedAssetId: expectedAssetId,
      ),
    );
  }

  Future<BfaCapabilities> rlnBfaCapabilities() => _withNodeQueue(
    'rlnBfaCapabilities',
    () async => BfaCapabilities.fromMap(await _client.bfaCapabilities()),
  );

  Future<BurnResult> rlnBurn(BurnParams params) {
    params.validate();
    return _withNodeOperation(
      'rlnBurn',
      (nodeId) async => BurnResult.fromMap(
        await _client.burn(
          nodeId: nodeId,
          assetId: params.assetId,
          amount: params.amount,
          burnRecipient: params.burnRecipient,
          feeRate: params.feeRate,
          minConfirmations: params.minConfirmations,
        ),
      ),
    );
  }

  Future<String> rlnGetConsignment(String assetId, String txid) {
    validateConsignmentLookup(assetId, txid);
    return _withNodeOperation(
      'rlnGetConsignment',
      (nodeId) => _client.getConsignment(nodeId, assetId, txid),
    );
  }

  Future<String> rlnGetConsignmentPath(String assetId, String txid) {
    validateConsignmentLookup(assetId, txid);
    return _withNodeOperation(
      'rlnGetConsignmentPath',
      (nodeId) => _client.getConsignmentPath(nodeId, assetId, txid),
    );
  }
}
