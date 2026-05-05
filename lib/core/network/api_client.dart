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

class ApiClient {
  ApiClient({required this.baseUrl, this.getToken}) : _client = http.Client();

  final String baseUrl;
  final Future<String?> Function()? getToken;

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

  dynamic _parse(http.Response response) {
    final body = response.body;
    final data = body.isEmpty ? null : jsonDecode(body);
    if (response.statusCode >= 200 && response.statusCode < 300) return data;
    final error = data is Map<String, dynamic>
        ? (data['error'] as String?) ?? 'unknown_error'
        : 'unknown_error';
    throw ApiException(error, statusCode: response.statusCode);
  }

  Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _parse(response);
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
      final response = await _client
          .get(
            Uri.parse('$baseUrl$path'),
            headers: await _headers(auth: auth),
          )
          .timeout(const Duration(seconds: 15));
      return _parse(response);
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
      final response = await _client
          .put(
            Uri.parse('$baseUrl$path'),
            headers: await _headers(auth: auth),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _parse(response);
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
      final response = await _client
          .delete(
            Uri.parse('$baseUrl$path'),
            headers: await _headers(auth: auth),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 204) return null;
      return _parse(response);
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
      return _parse(response);
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('network_error');
    } catch (_) {
      throw const ApiException('network_error');
    }
  }
}
