import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'lsp_types.dart';

abstract class IUtexoLspClient {
  void close() {}

  Future<LspGetInfoResponse> getInfo();

  Future<LspLnurlpCallbackResponse> resolveAddress(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  });

  Future<LspLnurlpCallbackResponse> lnurlCallback(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  });

  Future<LspLightningAddressByPubkeyResponse> getLightningAddressByPubkey(
    String peerPubkey,
  );

  Future<LspOnchainSendResponse> onchainSend(LspOnchainSendRequest params);

  Future<LspLightningReceiveResponse> lightningReceive(
    LspLightningReceiveRequest params,
  );
}

class LspError implements Exception {
  const LspError({
    required this.endpoint,
    required this.status,
    required this.body,
    this.cause,
  });

  final String endpoint;
  final int status;
  final String body;
  final Object? cause;

  @override
  String toString() {
    if (status == 0) {
      return 'LSP $endpoint -> ${cause ?? 'request failed'}';
    }
    return 'LSP $endpoint -> HTTP $status: $body';
  }
}

class UtexoLspClient implements IUtexoLspClient {
  UtexoLspClient({
    required String baseUrl,
    String? bearerToken,
    int? timeoutMs,
    http.Client? httpClient,
  }) : this.config(
         LspClientConfig(
           baseUrl: baseUrl,
           bearerToken: bearerToken,
           timeoutMs: timeoutMs,
         ),
         httpClient: httpClient,
       );

  UtexoLspClient.config(this.config, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const _defaultTimeoutMs = 15000;

  final LspClientConfig config;
  final http.Client _httpClient;

  @override
  void close() {
    _httpClient.close();
  }

  @override
  Future<LspGetInfoResponse> getInfo() async {
    return LspGetInfoResponse.fromWire(await _requestMap('/get_info'));
  }

  @override
  Future<LspLnurlpCallbackResponse> resolveAddress(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    final meta = await _requestMap(
      '/.well-known/lnurlp/${Uri.encodeComponent(username)}',
    );
    final callback = meta['callback']?.toString();
    if (callback == null || callback.isEmpty) {
      throw const LspError(
        endpoint: '/.well-known/lnurlp',
        status: 200,
        body: 'missing callback in LNURL response',
      );
    }
    final uri = _addQueryParams(_rewriteCallbackUrl(callback), <String, String>{
      'amount': amtMsat.toString(),
      'asset_id': ?assetId,
      'asset_amount': ?assetAmount?.toString(),
    });
    return LspLnurlpCallbackResponse.fromWire(await _requestMap(uri));
  }

  @override
  Future<LspLnurlpCallbackResponse> lnurlCallback(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    final path = _addQueryParams(
      '/pay/callback/${Uri.encodeComponent(username)}',
      <String, String>{
        'amount': amtMsat.toString(),
        'asset_id': ?assetId,
        'asset_amount': ?assetAmount?.toString(),
      },
    );
    return LspLnurlpCallbackResponse.fromWire(await _requestMap(path));
  }

  @override
  Future<LspLightningAddressByPubkeyResponse> getLightningAddressByPubkey(
    String peerPubkey,
  ) async {
    final pubkey = peerPubkey.trim();
    if (pubkey.isEmpty) {
      throw ArgumentError.value(
        peerPubkey,
        'peerPubkey',
        'peerPubkey is required',
      );
    }
    return LspLightningAddressByPubkeyResponse.fromWire(
      await _requestMap(
        '/lightning_address/by_pubkey/${Uri.encodeComponent(pubkey)}',
      ),
    );
  }

  @override
  Future<LspOnchainSendResponse> onchainSend(
    LspOnchainSendRequest params,
  ) async {
    final body = <String, Object?>{
      'rgb_invoice': params.rgbInvoice,
      if (params.ln != null) 'lninvoice': params.ln!.toWire(),
    };
    return LspOnchainSendResponse.fromWire(
      await _requestMap(
        '/onchain_send',
        method: 'POST',
        body: jsonEncode(body),
      ),
    );
  }

  @override
  Future<LspLightningReceiveResponse> lightningReceive(
    LspLightningReceiveRequest params,
  ) async {
    final body = <String, Object?>{
      'ln_invoice': params.lnInvoice,
      'rgb_invoice': params.rgb.toWire(),
    };
    return LspLightningReceiveResponse.fromWire(
      await _requestMap(
        '/lightning_receive',
        method: 'POST',
        body: jsonEncode(body),
      ),
    );
  }

  Future<Map<String, Object?>> _requestMap(
    String path, {
    String method = 'GET',
    String? body,
  }) async {
    final decoded = await _request<Object?>(path, method: method, body: body);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) return Map<String, Object?>.from(decoded);
    throw LspError(
      endpoint: path,
      status: 200,
      body: 'expected JSON object response',
    );
  }

  Future<T> _request<T>(
    String path, {
    String method = 'GET',
    String? body,
  }) async {
    final uri = _uri(path);
    final headers = <String, String>{'Accept': 'application/json'};
    final bearerToken = config.bearerToken;
    if (bearerToken != null && bearerToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $bearerToken';
    }
    if (body != null) headers['Content-Type'] = 'application/json';

    http.Response response;
    try {
      final request = method == 'POST'
          ? _httpClient.post(uri, headers: headers, body: body)
          : _httpClient.get(uri, headers: headers);
      response = await request.timeout(
        Duration(milliseconds: config.timeoutMs ?? _defaultTimeoutMs),
      );
    } catch (error) {
      throw LspError(endpoint: path, status: 0, body: '', cause: error);
    }

    final text = response.body;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LspError(
        endpoint: path,
        status: response.statusCode,
        body: text.trim(),
      );
    }
    if (text.isEmpty) return null as T;
    try {
      return jsonDecode(text) as T;
    } catch (error) {
      final previewLength = text.length > 200 ? 200 : text.length;
      throw LspError(
        endpoint: path,
        status: response.statusCode,
        body: 'invalid JSON: ${text.substring(0, previewLength)}',
        cause: error,
      );
    }
  }

  Uri _uri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Uri.parse(path);
    }
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    return Uri.parse('$base$path');
  }

  String _rewriteCallbackUrl(String callbackUrl) {
    try {
      final base = Uri.parse(config.baseUrl);
      final callback = Uri.parse(callbackUrl);
      return callback
          .replace(
            scheme: base.scheme,
            host: base.host,
            port: base.hasPort ? base.port : null,
          )
          .toString();
    } catch (_) {
      return callbackUrl;
    }
  }

  String _addQueryParams(String urlOrPath, Map<String, String> params) {
    final uri = Uri.parse(urlOrPath);
    return uri
        .replace(
          queryParameters: <String, String>{...uri.queryParameters, ...params},
        )
        .toString();
  }
}
