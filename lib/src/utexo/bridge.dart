// ignore_for_file: constant_identifier_names

import 'dart:convert';

import 'package:http/http.dart' as http;

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
  return utf8.encode(transferStatus).first;
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
  FetchClient(String baseUrl, {http.Client? httpClient})
    : _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
      _http = httpClient ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  Future<Map<String, Object?>> post(String path, [Object? body]) async {
    final response = await _http.post(
      Uri.parse('$_baseUrl$path'),
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: body == null ? null : jsonEncode(body),
    );
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
    return _decodeResponse(await _http.get(uri));
  }

  Map<String, Object?> _decodeResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        response.body.isEmpty ? 'HTTP ${response.statusCode}' : response.body,
        response.request?.url,
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
    return data['txHash'].toString();
  }

  Future<void> verifyBridgeIn(Map<String, Object?> request) async {
    await _http.post('$basePath/verify-bridge-in', request);
  }

  Future<String> getReceiverInvoice(int transferId, int networkId) async {
    final data = await _http.get(
      '$basePath/receiver-invoice/$transferId/$networkId',
    );
    return data['invoice'].toString();
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
    } catch (_) {
      return null;
    }
  }
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
