import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.payload,
  });

  final String message;
  final int? statusCode;
  final Object? payload;

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  })  : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _client = client ?? http.Client();

  final Uri _baseUri;
  final http.Client _client;
  final Duration timeout;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final response = await _send(
      () => _client.get(
        _resolve(path, queryParameters),
        headers: _headers(headers),
      ),
    );
    return _decodeObject(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    final response = await _send(
      () => _client.post(
        _resolve(path),
        headers: _headers(headers),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decodeObject(response);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _exceptionFrom(response);
      }
      return response;
    } on TimeoutException {
      throw const ApiException(message: 'Превышено время ожидания ответа API');
    } on http.ClientException catch (error) {
      throw ApiException(message: 'Ошибка соединения с API: ${error.message}');
    }
  }

  Uri _resolve(String path, [Map<String, String>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return _baseUri.resolve(normalizedPath).replace(
          queryParameters: queryParameters,
        );
  }

  Map<String, String> _headers(Map<String, String>? headers) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        ...?headers,
      };

  Map<String, dynamic> _decodeObject(http.Response response) {
    if (response.body.trim().isEmpty) return const <String, dynamic>{};

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(message: 'API вернул неожиданный формат ответа');
    }
    return decoded;
  }

  ApiException _exceptionFrom(http.Response response) {
    Object? payload;
    String message = 'API вернул ошибку ${response.statusCode}';

    if (response.body.trim().isNotEmpty) {
      try {
        payload = jsonDecode(response.body);
        if (payload is Map<String, dynamic>) {
          final candidate = payload['message'] ?? payload['error'];
          if (candidate is String && candidate.trim().isNotEmpty) {
            message = candidate;
          }
        }
      } catch (_) {
        payload = response.body;
      }
    }

    return ApiException(
      message: message,
      statusCode: response.statusCode,
      payload: payload,
    );
  }

  void close() => _client.close();
}
