import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Wywoływane przy każdej odpowiedzi `401` na żądanie wysłane z tokenem.
/// [tokenUsed] to token z nagłówka tego żądania — pozwala odróżnić wygaśnięcie
/// bieżącej sesji od spóźnionej odpowiedzi na token już zastąpiony nowym.
typedef UnauthorizedCallback =
    void Function(ApiException error, String tokenUsed);

class ApiClient {
  ApiClient({required this.baseUrl, this.getToken, this.onUnauthorized})
    : _client = http.Client();

  final String baseUrl;
  final Future<String?> Function()? getToken;

  /// Centralna obsługa unieważnionej sesji (np. `token_revoked`).
  final UnauthorizedCallback? onUnauthorized;

  /// Persistent HTTP client — reuses TCP connections across requests.
  final http.Client _client;

  void close() => _client.close();

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth && getToken != null) {
      final token = await getToken!();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _parse(http.Response response, Map<String, String> requestHeaders) {
    final body = response.body;
    final data = body.isEmpty ? null : jsonDecode(body);
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    final error = data is Map<String, dynamic>
        ? (data['error'] as String?) ?? 'unknown_error'
        : 'unknown_error';
    final exception = ApiException(error, statusCode: response.statusCode);
    if (response.statusCode == 401) _reportUnauthorized(exception, requestHeaders);
    throw exception;
  }

  void _reportUnauthorized(
    ApiException error,
    Map<String, String> requestHeaders,
  ) {
    final callback = onUnauthorized;
    final authorization = requestHeaders['Authorization'];
    if (callback == null || authorization == null) return;
    if (!authorization.startsWith('Bearer ')) return;
    try {
      callback(error, authorization.substring('Bearer '.length));
    } catch (_) {
      /* obsługa sesji nie może zmienić błędu żądania */
    }
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final headers = await _headers(auth: auth);
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _parse(response, headers);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('network_error');
    } catch (_) {
      throw const ApiException('network_error');
    }
  }

  Future<dynamic> get(String path, {bool auth = false}) async {
    try {
      final headers = await _headers(auth: auth);
      final response = await _client
          .get(Uri.parse('$baseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 15));
      return _parse(response, headers);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('network_error');
    } catch (_) {
      throw const ApiException('network_error');
    }
  }

  Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final headers = await _headers(auth: auth);
      final response = await _client
          .patch(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _parse(response, headers);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('network_error');
    } catch (_) {
      throw const ApiException('network_error');
    }
  }

  Future<dynamic> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final headers = await _headers(auth: auth);
      final response = await _client
          .put(
            Uri.parse('$baseUrl$path'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _parse(response, headers);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('network_error');
    } catch (_) {
      throw const ApiException('network_error');
    }
  }

  /// Sends a DELETE request. Returns null for 204 No Content responses.
  Future<dynamic> delete(String path, {bool auth = false}) async {
    try {
      final headers = await _headers(auth: auth);
      final response = await _client
          .delete(Uri.parse('$baseUrl$path'), headers: headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 204) return null;
      return _parse(response, headers);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('network_error');
    } catch (_) {
      throw const ApiException('network_error');
    }
  }

  /// Multipart POST (e.g. exercise image). Does not set `Content-Type`; the
  /// boundary is added automatically by [http.MultipartRequest].
  Future<dynamic> postMultipart(
    String path, {
    required List<http.MultipartFile> files,
    Map<String, String> fields = const {},
    bool auth = false,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = http.MultipartRequest('POST', uri);
      request.fields.addAll(fields);
      request.files.addAll(files);

      final headers = <String, String>{
        'Accept': 'application/json',
      };
      if (auth && getToken != null) {
        final token = await getToken!();
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
      }
      request.headers.addAll(headers);

      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      return _parse(response, headers);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('network_error');
    } catch (_) {
      throw const ApiException('network_error');
    }
  }
}
