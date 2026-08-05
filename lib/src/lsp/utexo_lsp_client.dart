import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../errors/rgb_sdk_exception.dart';
import '../crypto/constants.dart';
import 'lsp_errors.dart';
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

  Future<LspLnurlpCallbackResponse> resolveExternalAddress(
    String domain,
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
      return 'LSP ${redactSupportText(endpoint)} -> '
          '${redactSupportText(cause?.toString() ?? 'request failed')}';
    }
    return 'LSP ${redactSupportText(endpoint)} -> HTTP $status: '
        '${redactSupportText(body)}';
  }
}

class UtexoLspClient implements IUtexoLspClient {
  UtexoLspClient({
    required String baseUrl,
    String? bearerToken,
    int? timeoutMs,
    http.Client? httpClient,
    bool? closeHttpClient,
  }) : this.config(
         LspClientConfig(
           baseUrl: baseUrl,
           bearerToken: bearerToken,
           timeoutMs: timeoutMs,
         ),
         httpClient: httpClient,
         closeHttpClient: closeHttpClient,
       );

  UtexoLspClient.config(
    this.config, {
    http.Client? httpClient,
    bool? closeHttpClient,
  }) : _httpClient = httpClient ?? http.Client(),
       _closeHttpClient = closeHttpClient ?? httpClient == null {
    _validateBaseUrl(Uri.parse(config.baseUrl));
    _validateTimeout(config.timeoutMs ?? _defaultTimeoutMs, 'timeoutMs');
  }

  static const _defaultTimeoutMs = DEFAULT_API_TIMEOUT;
  static const _maxBodyPreviewChars = 512;

  final LspClientConfig config;
  final http.Client _httpClient;
  final bool _closeHttpClient;

  @override
  void close() {
    if (_closeHttpClient) _httpClient.close();
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
    _assertValidAmtMsat(amtMsat);
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
    _assertAmtMsatInSendableRange(
      amtMsat,
      minSendable: _requiredInt(meta['minSendable'], 'minSendable'),
      maxSendable: _requiredInt(meta['maxSendable'], 'maxSendable'),
    );
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
    _assertValidAmtMsat(amtMsat);
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
  Future<LspLnurlpCallbackResponse> resolveExternalAddress(
    String domain,
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    _assertValidAmtMsat(amtMsat);
    final discoveryUri = lnurlDiscoveryUri(domain, username);
    final meta = await _requestMapUri(discoveryUri, attachAuthorization: false);
    final callback = meta['callback']?.toString();
    if (callback == null || callback.isEmpty) {
      throw LspError(
        endpoint: discoveryUri.toString(),
        status: 200,
        body: 'missing callback in LNURL response',
      );
    }
    _assertAmtMsatInSendableRange(
      amtMsat,
      minSendable: _requiredInt(meta['minSendable'], 'minSendable'),
      maxSendable: _requiredInt(meta['maxSendable'], 'maxSendable'),
    );
    final callbackUri = Uri.parse(
      _addQueryParams(callback, <String, String>{
        'amount': amtMsat.toString(),
        'asset_id': ?assetId,
        'asset_amount': ?assetAmount?.toString(),
      }),
    );
    final callbackMap = await _requestMapUri(
      callbackUri,
      attachAuthorization: false,
    );
    return LspLnurlpCallbackResponse.fromWire(callbackMap);
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
    return _requestUri<T>(uri, endpoint: path, method: method, body: body);
  }

  Future<Map<String, Object?>> _requestMapUri(
    Uri uri, {
    String method = 'GET',
    String? body,
    bool attachAuthorization = true,
  }) async {
    final decoded = await _requestUri<Object?>(
      uri,
      endpoint: uri.toString(),
      method: method,
      body: body,
      attachAuthorization: attachAuthorization,
    );
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) return Map<String, Object?>.from(decoded);
    throw LspError(
      endpoint: uri.toString(),
      status: 200,
      body: 'expected JSON object response',
    );
  }

  Future<T> _requestUri<T>(
    Uri uri, {
    required String endpoint,
    String method = 'GET',
    String? body,
    bool attachAuthorization = true,
  }) async {
    _validateRequestUri(uri);
    final headers = <String, String>{'Accept': 'application/json'};
    final bearerToken = config.bearerToken;
    if (attachAuthorization && bearerToken != null && bearerToken.isNotEmpty) {
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
      throw LspError(endpoint: endpoint, status: 0, body: '', cause: error);
    }

    final text = response.body;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LspError(
        endpoint: endpoint,
        status: response.statusCode,
        body: _redactedPreview(text),
      );
    }
    if (text.isEmpty) return null as T;
    try {
      return jsonDecode(text) as T;
    } catch (error) {
      throw LspError(
        endpoint: endpoint,
        status: response.statusCode,
        body: 'invalid JSON: ${_redactedPreview(text)}',
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
      final callback = Uri.parse(callbackUrl);
      if (!callback.hasScheme) return callbackUrl;
      final query = callback.hasQuery ? '?${callback.query}' : '';
      final fragment = callback.hasFragment ? '#${callback.fragment}' : '';
      return '${callback.path}$query$fragment';
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

  static String _redactedPreview(String text) {
    final trimmed = text.trim();
    final preview = trimmed.length > _maxBodyPreviewChars
        ? '${trimmed.substring(0, _maxBodyPreviewChars)}...'
        : trimmed;
    return redactSupportText(preview);
  }
}

String redactSupportText(String text) {
  return text
      .replaceAllMapped(
        RegExp(
          r'(authorization:\s*bearer\s+|bearer\s+)[A-Za-z0-9._~+/=-]+',
          caseSensitive: false,
        ),
        (match) => '${match.group(1)}[REDACTED]',
      )
      .replaceAllMapped(
        RegExp(
          r'\b(password|passphrase|mnemonic|seed(?:Hex)?|preimage|token|bearerToken|bitcoindRpcPassword)=([^&\s,}]+)',
          caseSensitive: false,
        ),
        (match) => '${match.group(1)}=[REDACTED]',
      )
      .replaceAllMapped(
        RegExp(
          r'"(password|passphrase|mnemonic|seed(?:Hex)?|preimage|token|bearerToken|bitcoindRpcPassword)"\s*:\s*"[^"]*"',
          caseSensitive: false,
        ),
        (match) => '"${match.group(1)}":"[REDACTED]"',
      )
      .replaceAllMapped(
        RegExp(r'\b[0-9a-fA-F]{64,}\b'),
        (_) => '[REDACTED_HEX]',
      );
}

Uri lnurlDiscoveryUri(String domain, String username) {
  final scheme = isLoopbackHost(domain) ? 'http' : 'https';
  return Uri.parse(
    '$scheme://$domain/.well-known/lnurlp/${Uri.encodeComponent(username)}',
  );
}

String hostnameOf(String hostOrUrl) {
  final raw = hostOrUrl.trim();
  if (raw.isEmpty) return '';
  if (RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false).hasMatch(raw)) {
    try {
      return Uri.parse(
        raw,
      ).host.replaceAll(RegExp(r'^\[|\]$'), '').toLowerCase();
    } catch (_) {
      return '';
    }
  }
  if (raw.startsWith('[')) {
    final end = raw.indexOf(']');
    if (end > 0) return raw.substring(1, end).toLowerCase();
    return '';
  }
  final parts = raw.split(':');
  if (parts.length == 2) return parts.first.toLowerCase();
  return raw.toLowerCase();
}

const Set<String> _loopbackHosts = <String>{
  'localhost',
  '127.0.0.1',
  '::1',
  '10.0.2.2',
  '0.0.0.0',
};

bool isLoopbackHost(String hostOrUrl) {
  return _loopbackHosts.contains(hostnameOf(hostOrUrl));
}

bool isSameLspHost(String domain, String baseUrl) {
  final a = hostnameOf(domain);
  final b = hostnameOf(baseUrl);
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  return _loopbackHosts.contains(a) && _loopbackHosts.contains(b);
}

void _validateBaseUrl(Uri uri) {
  if (!uri.hasScheme || uri.host.isEmpty) {
    throw WalletValidationException(
      'LSP baseUrl must be an absolute http(s) URL.',
      field: 'baseUrl',
    );
  }
  _validateRequestUri(uri);
}

void _validateRequestUri(Uri uri) {
  if (uri.scheme == 'https') return;
  if (uri.scheme == 'http' && isLoopbackHost(uri.host)) return;
  throw LspTransportPolicyException(
    'LSP HTTP transport must use HTTPS unless the host is local loopback.',
    uri: uri,
  );
}

void _validateTimeout(int timeoutMs, String field) {
  if (timeoutMs <= 0) {
    throw ValidationError('$field must be a positive integer', field);
  }
}

void _assertValidAmtMsat(int amtMsat, [String field = 'amtMsat']) {
  if (amtMsat <= 0) {
    throw ValidationError(
      '$field must be a finite positive integer (msat)',
      field,
    );
  }
}

void _assertAmtMsatInSendableRange(
  int amtMsat, {
  required int minSendable,
  required int maxSendable,
}) {
  _assertValidAmtMsat(amtMsat);
  if (amtMsat < minSendable || amtMsat > maxSendable) {
    throw LspAmountOutOfRangeException(
      amtMsat: amtMsat,
      minSendable: minSendable,
      maxSendable: maxSendable,
    );
  }
}

int _requiredInt(Object? value, String field) {
  if (value is int) return value;
  if (value is double && value.isFinite && value % 1 == 0) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw NativeProtocolException(
    'Expected integer field "$field".',
    field: field,
  );
}
