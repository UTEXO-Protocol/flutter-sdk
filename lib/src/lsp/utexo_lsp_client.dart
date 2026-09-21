import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:meta/meta.dart' show visibleForTesting;

import '../errors/rgb_sdk_exception.dart';
import 'lsp_errors.dart';
import 'lsp_relay_types.dart';
import 'lsp_types.dart';

/// HTTP contract used by [UtexoLsp] orchestration.
///
/// Implementations own their transport lifecycle. [close] must not close a
/// caller-owned transport supplied through dependency injection.
abstract class IUtexoLspClient {
  void close() {}

  Future<LspGetInfoResponse> getInfo();

  Future<LspLnurlpDiscovery> discoverAddress(String username);

  Future<LspLnurlpCallbackResponse> resolveAddress(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  });

  /// Resolves discovery and its consuming callback as one coherent exchange.
  Future<LspAddressResolution> resolveAddressWithDiscovery(
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

  /// Resolves external discovery and its callback as one coherent exchange.
  Future<LspAddressResolution> resolveExternalAddressWithDiscovery(
    String domain,
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  });

  Future<LspLnurlpDiscovery> discoverExternalAddress(
    String domain,
    String username,
  );

  Future<LspLightningAddressByPubkeyResponse> getLightningAddressByPubkey(
    String peerPubkey,
  );

  Future<LspOnchainSendResponse> onchainSend(LspOnchainSendRequest params);

  Future<LspLightningReceiveResponse> lightningReceive(
    LspLightningReceiveRequest params,
  );

  Future<LspLightningSendResponse> lightningSend(
    LspLightningSendRequest params,
  );

  Future<LspLightningSendStatusResponse> lightningSendStatus(
    String paymentHash,
  );
}

class LspError extends NetworkError {
  const LspError({
    required this.endpoint,
    required this.status,
    required this.body,
    Object? cause,
  }) : super(
         status == 0
             ? 'LSP request failed.'
             : 'LSP request failed with HTTP status.',
         statusCode: status == 0 ? null : status,
         cause: cause,
       );

  final String endpoint;
  final int status;

  /// Diagnostic detail. Treat caller-supplied values as untrusted and private.
  /// The HTTP client supplies fixed descriptions, never response body previews.
  final String body;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ...super.toJson(),
    'endpoint': _redactEndpoint(endpoint),
    'status': status,
    'hasDiagnosticBody': body.isNotEmpty,
  };

  @override
  String toString() {
    if (status == 0) {
      return 'LSP ${_redactEndpoint(endpoint)} -> request failed';
    }
    return 'LSP ${_redactEndpoint(endpoint)} -> HTTP $status';
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
  }) {
    final baseUri = Uri.tryParse(config.baseUrl);
    if (baseUri == null) {
      throw const WalletValidationException(
        'LSP baseUrl must be a valid absolute http(s) URL.',
        field: 'baseUrl',
      );
    }
    _validateBaseUrl(baseUri);
    _validateTimeout(config.timeoutMs ?? _defaultTimeoutMs, 'timeoutMs');
    _httpClient = httpClient ?? _createPolicyHttpClient();
    _closeHttpClient = closeHttpClient ?? httpClient == null;
  }

  // The core LSP client deliberately uses a shorter deadline than the generic
  // SDK/native operation timeout. A stalled HTTP quote must not hold a wallet
  // flow for two minutes.
  static const _defaultTimeoutMs = 15000;
  static const _maxResponseBytes = 1024 * 1024;

  final LspClientConfig config;
  late final http.Client _httpClient;
  late final bool _closeHttpClient;

  @override
  void close() {
    if (_closeHttpClient) _httpClient.close();
  }

  @override
  Future<LspGetInfoResponse> getInfo() async {
    return LspGetInfoResponse.fromWire(await _requestMap('/get_info'));
  }

  @override
  Future<LspLnurlpDiscovery> discoverAddress(String username) async {
    final normalized = _requiredPathSegment(username, 'username');
    return LspLnurlpDiscovery.fromWire(
      await _requestMap(
        '/.well-known/lnurlp/${Uri.encodeComponent(normalized)}',
      ),
    );
  }

  @override
  Future<LspLnurlpCallbackResponse> resolveAddress(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    return (await resolveAddressWithDiscovery(
      username,
      amtMsat,
      assetId: assetId,
      assetAmount: assetAmount,
    )).callback;
  }

  @override
  Future<LspAddressResolution> resolveAddressWithDiscovery(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    _assertValidAmtMsat(amtMsat);
    _validateOptionalAssetParams(assetId: assetId, assetAmount: assetAmount);
    final meta = await discoverAddress(username);
    _assertAmtMsatInSendableRange(
      amtMsat,
      minSendable: meta.minSendable,
      maxSendable: meta.maxSendable,
    );
    final uri =
        _addQueryParams(_rewriteCallbackUrl(meta.callback), <String, String>{
          'amount': amtMsat.toString(),
          'asset_id': ?assetId,
          'asset_amount': ?assetAmount?.toString(),
        });
    return LspAddressResolution(
      discovery: meta,
      callback: LspLnurlpCallbackResponse.fromWire(await _requestMap(uri)),
    );
  }

  @override
  Future<LspLnurlpCallbackResponse> lnurlCallback(
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    _assertValidAmtMsat(amtMsat);
    _validateOptionalAssetParams(assetId: assetId, assetAmount: assetAmount);
    final normalized = _requiredPathSegment(username, 'username');
    final path = _addQueryParams(
      '/pay/callback/${Uri.encodeComponent(normalized)}',
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
    return (await resolveExternalAddressWithDiscovery(
      domain,
      username,
      amtMsat,
      assetId: assetId,
      assetAmount: assetAmount,
    )).callback;
  }

  @override
  Future<LspAddressResolution> resolveExternalAddressWithDiscovery(
    String domain,
    String username,
    int amtMsat, {
    String? assetId,
    int? assetAmount,
  }) async {
    _assertValidAmtMsat(amtMsat);
    _validateOptionalAssetParams(assetId: assetId, assetAmount: assetAmount);
    final meta = await discoverExternalAddress(domain, username);
    _assertAmtMsatInSendableRange(
      amtMsat,
      minSendable: meta.minSendable,
      maxSendable: meta.maxSendable,
    );
    final callbackUri = _parseExternalCallbackUri(
      _addQueryParams(meta.callback, <String, String>{
        'amount': amtMsat.toString(),
        'asset_id': ?assetId,
        'asset_amount': ?assetAmount?.toString(),
      }),
      discoveryDomain: domain,
    );
    final callbackMap = await _requestMapUri(
      callbackUri,
      attachAuthorization: false,
    );
    return LspAddressResolution(
      discovery: meta,
      callback: LspLnurlpCallbackResponse.fromWire(callbackMap),
    );
  }

  @override
  Future<LspLnurlpDiscovery> discoverExternalAddress(
    String domain,
    String username,
  ) async {
    final discoveryUri = lnurlDiscoveryUri(
      _requiredPathSegment(domain, 'domain'),
      _requiredPathSegment(username, 'username'),
    );
    return LspLnurlpDiscovery.fromWire(
      await _requestMapUri(discoveryUri, attachAuthorization: false),
    );
  }

  @override
  Future<LspLightningAddressByPubkeyResponse> getLightningAddressByPubkey(
    String peerPubkey,
  ) async {
    final pubkey = peerPubkey.trim();
    if (pubkey.isEmpty) {
      throw const ValidationError('peerPubkey is required', 'peerPubkey');
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
    final rgbInvoice = _requiredPathSegment(params.rgbInvoice, 'rgbInvoice');
    final body = <String, Object?>{
      'rgb_invoice': rgbInvoice,
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
    _requiredPathSegment(params.lnInvoice, 'lnInvoice');
    if (params.rgb.assetId != null) {
      _requiredPathSegment(params.rgb.assetId!, 'rgb.assetId');
    }
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

  @override
  Future<LspLightningSendResponse> lightningSend(
    LspLightningSendRequest params,
  ) async {
    final invoice = _requiredPathSegment(params.invoice, 'invoice');
    final payWithAssetId = params.payWithAssetId?.trim();
    if (params.payWithAssetId != null &&
        (payWithAssetId == null || payWithAssetId.isEmpty)) {
      throw const ValidationError(
        'payWithAssetId must be non-empty when present.',
        'payWithAssetId',
      );
    }
    return LspLightningSendResponse.fromWire(
      await _requestMap(
        '/lightning_send',
        method: 'POST',
        body: jsonEncode(<String, Object?>{
          'invoice': invoice,
          'pay_with_asset_id': ?payWithAssetId,
        }),
      ),
    );
  }

  @override
  Future<LspLightningSendStatusResponse> lightningSendStatus(
    String paymentHash,
  ) async {
    final hash = _requiredPathSegment(paymentHash, 'paymentHash');
    final response = LspLightningSendStatusResponse.fromWire(
      await _requestMap('/lightning_send/${Uri.encodeComponent(hash)}'),
    );
    if (response.paymentHash.toLowerCase() != hash.toLowerCase()) {
      throw const NativeProtocolException(
        'LSP payment status does not match the requested payment.',
        field: 'LspLightningSendStatusResponse.paymentHash',
      );
    }
    return response;
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

    _LspHttpResponse response;
    final timeout = Duration(
      milliseconds: config.timeoutMs ?? _defaultTimeoutMs,
    );
    final abortTrigger = Completer<void>();
    try {
      final request =
          http.AbortableRequest(method, uri, abortTrigger: abortTrigger.future)
            ..followRedirects = false
            ..headers.addAll(headers);
      if (body != null) request.body = body;
      response = await _sendAndRead(request, endpoint: endpoint).timeout(
        timeout,
        onTimeout: () {
          if (!abortTrigger.isCompleted) abortTrigger.complete();
          throw TimeoutException('LSP request timed out.', timeout);
        },
      );
    } catch (error) {
      if (!abortTrigger.isCompleted) abortTrigger.complete();
      if (error is LspError) rethrow;
      throw LspError(endpoint: endpoint, status: 0, body: '', cause: error);
    }

    final text = response.body;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw LspError(
        endpoint: endpoint,
        status: response.statusCode,
        body: 'HTTP request rejected by the LSP',
      );
    }
    if (text.isEmpty) return null as T;
    try {
      return jsonDecode(text) as T;
    } catch (error) {
      throw LspError(
        endpoint: endpoint,
        status: response.statusCode,
        body: 'Invalid JSON response',
        cause: const FormatException('Malformed LSP JSON response'),
      );
    }
  }

  Future<_LspHttpResponse> _sendAndRead(
    http.Request request, {
    required String endpoint,
  }) async {
    final streamed = await _httpClient.send(request);
    final advertisedLength = streamed.contentLength;
    if (advertisedLength != null && advertisedLength > _maxResponseBytes) {
      throw LspError(
        endpoint: endpoint,
        status: streamed.statusCode,
        body: 'response exceeds the $_maxResponseBytes-byte limit',
      );
    }

    final bytes = BytesBuilder(copy: false);
    await for (final chunk in streamed.stream) {
      if (bytes.length + chunk.length > _maxResponseBytes) {
        throw LspError(
          endpoint: endpoint,
          status: streamed.statusCode,
          body: 'response exceeds the $_maxResponseBytes-byte limit',
        );
      }
      bytes.add(chunk);
    }
    return _LspHttpResponse(
      statusCode: streamed.statusCode,
      body: utf8.decode(bytes.takeBytes(), allowMalformed: true),
    );
  }

  Uri _uri(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return _parseWireUri(path, field: 'lsp.endpoint');
    }
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    return _parseWireUri('$base$path', field: 'lsp.endpoint');
  }

  String _rewriteCallbackUrl(String callbackUrl) {
    final callback = _parseCallbackUri(callbackUrl);
    if (!callback.hasScheme) {
      return callback.toString();
    }
    final query = callback.hasQuery ? '?${callback.query}' : '';
    final fragment = callback.hasFragment ? '#${callback.fragment}' : '';
    return '${callback.path}$query$fragment';
  }

  String _addQueryParams(String urlOrPath, Map<String, String> params) {
    final uri = _parseCallbackUri(urlOrPath);
    return uri
        .replace(
          queryParameters: <String, String>{...uri.queryParameters, ...params},
        )
        .toString();
  }
}

String redactSupportText(String text) {
  const sensitiveField =
      r'password|passphrase|mnemonic|seed(?:Hex)?|preimage|token|bearerToken|'
      r'bitcoindRpcPassword|invoice|lnInvoice|ln_invoice|rgbInvoice|'
      r'rgb_invoice|paymentHash|payment_hash';
  return text
      .replaceAllMapped(
        RegExp(
          r'(authorization:\s*bearer\s+|bearer\s+)[A-Za-z0-9._~+/=-]+',
          caseSensitive: false,
        ),
        (match) => '${match.group(1)}[REDACTED]',
      )
      .replaceAllMapped(
        RegExp('\\b($sensitiveField)=([^&\\s,}]+)', caseSensitive: false),
        (match) => '${match.group(1)}=[REDACTED]',
      )
      .replaceAllMapped(
        RegExp('"($sensitiveField)"\\s*:\\s*"[^"]*"', caseSensitive: false),
        (match) => '"${match.group(1)}":"[REDACTED]"',
      )
      .replaceAllMapped(
        RegExp(r'\b[0-9a-fA-F]{64,}\b'),
        (_) => '[REDACTED_HEX]',
      )
      .replaceAllMapped(
        RegExp(r'\bln(?:bc|tb|bcrt|sb)[0-9a-z]{20,}\b', caseSensitive: false),
        (_) => '[REDACTED_BOLT11]',
      );
}

String _redactEndpoint(String endpoint) {
  final uri = Uri.tryParse(endpoint);
  if (uri != null &&
      (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment)) {
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
    ).toString();
  }
  return redactSupportText(endpoint);
}

Uri lnurlDiscoveryUri(String domain, String username) {
  final authority = _parseExternalDomain(domain);
  _validateExternalTarget(authority, field: 'domain');
  final scheme = isLoopbackHost(authority.host) ? 'http' : 'https';
  return authority.replace(
    scheme: scheme,
    pathSegments: <String>['.well-known', 'lnurlp', username],
    query: null,
    fragment: null,
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
    } on FormatException {
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
};

const Set<String> _actualLoopbackHosts = <String>{
  'localhost',
  '127.0.0.1',
  '::1',
};

const Set<String> _nonPublicHostSuffixes = <String>{
  '.example',
  '.home',
  '.internal',
  '.invalid',
  '.lan',
  '.local',
  '.localhost',
  '.test',
};

bool isLoopbackHost(String hostOrUrl) {
  return _loopbackHosts.contains(hostnameOf(hostOrUrl));
}

bool _isActualLoopbackHost(String hostOrUrl) {
  return _actualLoopbackHosts.contains(hostnameOf(hostOrUrl));
}

bool isSameLspHost(String domain, String baseUrl) {
  final a = hostnameOf(domain);
  final b = hostnameOf(baseUrl);
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  return _loopbackHosts.contains(a) && _loopbackHosts.contains(b);
}

void _validateBaseUrl(Uri uri) {
  if (!uri.hasScheme ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw WalletValidationException(
      'LSP baseUrl must be an absolute http(s) URL without credentials, '
      'query, or fragment.',
      field: 'baseUrl',
    );
  }
  _validateRequestUri(uri);
  final literal = InternetAddress.tryParse(uri.host);
  if (literal != null &&
      !isLoopbackHost(uri.host) &&
      !_isPublicInternetAddress(literal)) {
    throw LspTransportPolicyException(
      'LSP baseUrl cannot target a non-public IP address.',
      uri: uri,
    );
  }
}

Uri _parseWireUri(String value, {required String field}) {
  final uri = Uri.tryParse(value);
  if (uri == null) {
    throw NativeProtocolException('$field must be a valid URI.', field: field);
  }
  return uri;
}

Uri _parseCallbackUri(String value) {
  final uri = _parseWireUri(value, field: 'lsp.callback');
  final isAbsoluteHttp =
      uri.hasScheme &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty;
  final isRelativePath =
      !uri.hasScheme && !uri.hasAuthority && uri.path.startsWith('/');
  if (!isAbsoluteHttp && !isRelativePath) {
    throw const NativeProtocolException(
      'LSP callback must be an absolute http(s) URL or an absolute path.',
      field: 'lsp.callback',
    );
  }
  return uri;
}

Uri _parseExternalCallbackUri(String value, {required String discoveryDomain}) {
  final uri = _parseCallbackUri(value);
  if (!uri.hasScheme) {
    throw const NativeProtocolException(
      'External LNURL callback must be an absolute http(s) URL.',
      field: 'lsp.callback',
    );
  }
  _validateRequestUri(uri);
  _validateExternalTarget(uri, field: 'lsp.callback');
  if (!isLoopbackHost(discoveryDomain) && isLoopbackHost(uri.host)) {
    throw LspTransportPolicyException(
      'A public Lightning Address cannot redirect its callback to loopback.',
      uri: uri,
    );
  }
  return uri;
}

void _validateExternalTarget(Uri uri, {required String field}) {
  final host = uri.host.toLowerCase();
  if (host.isEmpty) {
    throw NativeProtocolException(
      '$field must contain a hostname.',
      field: field,
    );
  }
  // `10.0.2.2` is trusted only when explicitly configured as the Android
  // emulator's LSP base URL. A remote LNURL document must not use that alias
  // to reach services on the developer host.
  if (_isActualLoopbackHost(host)) return;

  final address = InternetAddress.tryParse(host);
  if (address != null) {
    if (!_isPublicInternetAddress(address)) {
      throw LspTransportPolicyException(
        'External Lightning Address requests cannot target a non-public IP.',
        uri: uri,
      );
    }
    return;
  }

  if (!host.contains('.') || _nonPublicHostSuffixes.any(host.endsWith)) {
    throw LspTransportPolicyException(
      'External Lightning Address requests require a public hostname.',
      uri: uri,
    );
  }
}

bool _isPublicInternetAddress(InternetAddress address) {
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return !_isNonPublicIpv4(bytes);
  }

  if (bytes.length != 16) return false;
  final isUnspecified = bytes.every((byte) => byte == 0);
  final isLoopback =
      bytes.take(15).every((byte) => byte == 0) && bytes.last == 1;
  final isUniqueLocal = (bytes[0] & 0xfe) == 0xfc;
  final isLinkLocal = bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80;
  final isDeprecatedSiteLocal = bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0xc0;
  final isMulticast = bytes[0] == 0xff;
  final isDocumentation =
      bytes[0] == 0x20 &&
      bytes[1] == 0x01 &&
      bytes[2] == 0x0d &&
      bytes[3] == 0xb8;
  final isIpv4Mapped =
      bytes.take(10).every((byte) => byte == 0) &&
      bytes[10] == 0xff &&
      bytes[11] == 0xff;
  final isIpv4Compatible =
      bytes.take(12).every((byte) => byte == 0) &&
      !isUnspecified &&
      !isLoopback;
  if ((isIpv4Mapped || isIpv4Compatible) &&
      _isNonPublicIpv4(bytes.sublist(12))) {
    return false;
  }
  return !isUnspecified &&
      !isLoopback &&
      !isUniqueLocal &&
      !isLinkLocal &&
      !isDeprecatedSiteLocal &&
      !isMulticast &&
      !isDocumentation;
}

bool _isNonPublicIpv4(List<int> bytes) {
  if (bytes.length != 4) return true;
  final first = bytes[0];
  final second = bytes[1];
  return first == 0 ||
      first == 10 ||
      first == 127 ||
      (first == 100 && second >= 64 && second <= 127) ||
      (first == 169 && second == 254) ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 0) ||
      (first == 192 && second == 168) ||
      (first == 198 && (second == 18 || second == 19)) ||
      (first == 198 && second == 51 && bytes[2] == 100) ||
      (first == 203 && second == 0 && bytes[2] == 113) ||
      first >= 224;
}

Uri _parseExternalDomain(String value) {
  final domain = value.trim();
  if (domain.isEmpty || RegExp(r'[\s/@?#]').hasMatch(domain)) {
    throw const ValidationError(
      'domain must be a hostname with an optional port.',
      'domain',
    );
  }
  final uri = Uri.tryParse('https://$domain');
  if (uri == null ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw const ValidationError(
      'domain must be a hostname with an optional port.',
      'domain',
    );
  }
  try {
    if (uri.hasPort && (uri.port < 1 || uri.port > 65535)) {
      throw const ValidationError(
        'domain port must be in range 1..65535.',
        'domain',
      );
    }
  } on FormatException {
    throw const ValidationError(
      'domain port must be in range 1..65535.',
      'domain',
    );
  }
  return uri;
}

void _validateRequestUri(Uri uri) {
  if (uri.userInfo.isNotEmpty) {
    throw LspTransportPolicyException(
      'LSP URLs must not embed credentials.',
      uri: uri,
    );
  }
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

String _requiredPathSegment(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ValidationError('$field is required.', field);
  }
  return normalized;
}

void _validateOptionalAssetParams({String? assetId, int? assetAmount}) {
  if (assetId != null && assetId.trim().isEmpty) {
    throw const ValidationError(
      'assetId must be non-empty when present.',
      'assetId',
    );
  }
  if (assetAmount != null && assetAmount < 0) {
    throw const ValidationError(
      'assetAmount must be non-negative when present.',
      'assetAmount',
    );
  }
}

class _LspHttpResponse {
  const _LspHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

http.Client _createPolicyHttpClient() {
  final client = HttpClient();
  client.findProxy = (_) => 'DIRECT';
  client.connectionFactory =
      (Uri uri, String? proxyHost, int? proxyPort) async {
        if (proxyHost != null || proxyPort != null) {
          throw LspTransportPolicyException(
            'LSP transport does not permit an implicit network proxy.',
            uri: uri,
          );
        }
        final literal = InternetAddress.tryParse(uri.host);
        final addresses = literal == null
            ? await InternetAddress.lookup(uri.host)
            : <InternetAddress>[literal];
        final address = selectLspConnectionAddressForTesting(uri, addresses);
        final port = uri.hasPort
            ? uri.port
            : uri.scheme == 'https'
            ? 443
            : 80;
        final tcpTask = await Socket.startConnect(address, port);
        if (uri.scheme != 'https') return tcpTask;

        final secureSocket = tcpTask.socket.then(
          (socket) => SecureSocket.secure(socket, host: uri.host),
        );
        return ConnectionTask.fromSocket<Socket>(secureSocket, tcpTask.cancel);
      };
  return IOClient(client);
}

/// Selects the DNS-pinned socket target used by the default LSP transport.
///
/// Exposed only so tests can prove DNS-rebinding policy without making network
/// requests. It is not exported by either package entrypoint.
@visibleForTesting
InternetAddress selectLspConnectionAddressForTesting(
  Uri uri,
  List<InternetAddress> addresses,
) {
  if (addresses.isEmpty) {
    throw LspTransportPolicyException(
      'LSP hostname resolution returned no addresses.',
      uri: uri,
    );
  }
  if (!isLoopbackHost(uri.host)) {
    final unsafe = addresses.where(
      (address) => !_isPublicInternetAddress(address),
    );
    if (unsafe.isNotEmpty) {
      throw LspTransportPolicyException(
        'LSP hostname resolved to a non-public network address.',
        uri: uri,
      );
    }
  }
  return addresses.first;
}
