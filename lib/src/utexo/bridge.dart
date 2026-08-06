// ignore_for_file: constant_identifier_names

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/rgb_sdk_exception.dart';
import 'network.dart';

const Map<UtxoNetworkPreset, String> DEFAULT_GATEWAY_BASE_URLS =
    <UtxoNetworkPreset, String>{
      'mainnet': 'https://gateway.utexo.utexo.com/',
      'testnet': 'https://dev.gateway.utexo.tricorn.network/',
    };

const List<String> TransferStatuses = <String>[
  'Unspecified',
  'Confirming',
  'Canceled',
  'Finished',
  'Waiting',
  'Cancelling',
  'Failed',
  'Fetching',
];

int encodeTransferStatus(String transferStatus) {
  final index = TransferStatuses.indexOf(transferStatus);
  if (index < 0) {
    throw ValidationError(
      'Unknown UTEXO transfer status: $transferStatus',
      'transferStatus',
    );
  }
  return index;
}

class BridgeApiException extends NetworkError {
  const BridgeApiException(
    super.message, {
    super.statusCode,
    super.cause,
    this.uri,
  });

  final Uri? uri;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    if (uri != null) 'uri': uri.toString(),
  };

  @override
  String toString() {
    final code = statusCode == null ? '' : ' HTTP $statusCode';
    final target = uri == null ? '' : ' $uri';
    return 'BridgeApiException$code$target: $message';
  }
}

class NetworkAddress {
  const NetworkAddress({
    required this.address,
    required this.networkId,
    this.networkName,
  });

  final String address;
  final int networkId;
  final String? networkName;

  Map<String, Object?> toJson() => <String, Object?>{
    'address': address,
    if (networkName != null) 'networkName': networkName,
    'networkId': networkId,
  };
}

class FetchClient {
  FetchClient(
    String baseUrl, {
    http.Client? httpClient,
    this.timeout = const Duration(milliseconds: 120000),
  }) : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
       _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;
  final Duration timeout;

  void close() {
    _http.close();
  }

  Future<Map<String, Object?>> post(String path, [Object? body]) async {
    final response = await _http
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(timeout);
    return _decodeResponse(response);
  }

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, Object?> params = const <String, Object?>{},
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: params.isEmpty
          ? null
          : params.map((key, value) => MapEntry(key, value.toString())),
    );
    return _decodeResponse(await _http.get(uri).timeout(timeout));
  }

  Map<String, Object?> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BridgeApiException(
        response.body.isEmpty ? 'HTTP ${response.statusCode}' : response.body,
        statusCode: response.statusCode,
        uri: response.request?.url,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) return Map<String, Object?>.from(decoded);
    return <String, Object?>{'data': decoded};
  }
}

class UtexoBridgeApiClient {
  UtexoBridgeApiClient(this._http, {this.basePath = '/v1/utexo/bridge'});

  final FetchClient _http;
  final String basePath;

  Future<Map<String, Object?>> getBridgeInSignature(
    Map<String, Object?> request,
  ) {
    return _http.post('$basePath/bridge-in-signature', request);
  }

  Future<String> submitTransaction(Map<String, Object?> request) async {
    final data = await _http.post('$basePath/submit-transaction', request);
    return _requiredString(data, 'txHash');
  }

  Future<void> verifyBridgeIn(Map<String, Object?> request) async {
    await _http.post('$basePath/verify-bridge-in', request);
  }

  Future<String> getReceiverInvoice(int transferId, int networkId) async {
    final data = await _http.get(
      '$basePath/receiver-invoice/$transferId/$networkId',
    );
    return _requiredString(data, 'invoice');
  }

  Future<Map<String, Object?>?> getTransferByMainnetInvoice(
    String mainnetInvoice,
    int networkId,
  ) async {
    try {
      return await _http.get(
        '$basePath/transfer-by-mainnet-invoice',
        params: <String, Object?>{
          'mainnet_invoice': mainnetInvoice,
          'network_id': networkId,
        },
      );
    } on BridgeApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      return null;
    }
  }
}

String _requiredString(Map<String, Object?> data, String field) {
  final value = data[field];
  if (value is String && value.isNotEmpty) return value;
  throw BridgeApiException('Missing or invalid string field "$field".');
}

UtexoBridgeApiClient getBridgeAPI([UtxoNetworkPreset network = 'mainnet']) {
  final baseUrl =
      DEFAULT_GATEWAY_BASE_URLS[network] ??
      DEFAULT_GATEWAY_BASE_URLS['mainnet']!;
  return UtexoBridgeApiClient(FetchClient(baseUrl));
}

String decodeBridgeInvoice(String hexInvoice) {
  final hex = hexInvoice.startsWith('0x')
      ? hexInvoice.substring(2)
      : hexInvoice;
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return utf8.decode(bytes);
}
