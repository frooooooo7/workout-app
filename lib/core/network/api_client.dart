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
    final data = jsonDecode(response.body);
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
}
