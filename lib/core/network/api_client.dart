import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    TokenStorage? tokenStorage,
  })  : _baseUrl = baseUrl ?? Env.apiBaseUrl,
        _httpClient = httpClient ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final String _baseUrl;
  final http.Client _httpClient;
  final TokenStorage _tokenStorage;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool authRequired = false,
  }) {
    return _send(
      () async => _httpClient.get(
        _buildUri(path, query),
        headers: await _headers(authRequired: authRequired),
      ),
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool authRequired = false,
  }) {
    return _send(
      () async => _httpClient.post(
        _buildUri(path),
        headers: await _headers(authRequired: authRequired),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool authRequired = false,
  }) {
    return _send(
      () async => _httpClient.put(
        _buildUri(path),
        headers: await _headers(authRequired: authRequired),
        body: jsonEncode(body ?? <String, dynamic>{}),
      ),
    );
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    bool authRequired = false,
  }) {
    return _send(
      () async => _httpClient.delete(
        _buildUri(path),
        headers: await _headers(authRequired: authRequired),
        body: body == null ? null : jsonEncode(body),
      ),
    );
  }

  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final normalizedBase = _baseUrl.endsWith('/')
        ? _baseUrl.substring(0, _baseUrl.length - 1)
        : _baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');

    if (query == null || query.isEmpty) {
      return uri;
    }

    final queryParams = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
    return uri.replace(queryParameters: queryParams);
  }

  Future<Map<String, String>> _headers({required bool authRequired}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authRequired) {
      final token = await _tokenStorage.readToken();
      if (token == null || token.isEmpty) {
        throw const ApiException(
          message: 'Missing authentication token. Please login again.',
          statusCode: 401,
        );
      }
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(const Duration(seconds: 30));
      return _decodeResponse(response);
    } on SocketException {
      throw const ApiException(
        message: 'Network connection failed.',
      );
    } on TimeoutException {
      throw const ApiException(
        message: 'Request timed out. Please try again.',
      );
    } on FormatException {
      throw const ApiException(
        message: 'Invalid server response format.',
      );
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final responseText = response.body.trim();
    final dynamic parsed = responseText.isEmpty ? <String, dynamic>{} : jsonDecode(responseText);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
      return {'data': parsed};
    }

    final errorMap = parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
    throw ApiException(
      message: (errorMap['message'] as String?) ?? 'Unexpected API error.',
      statusCode: response.statusCode,
      details: (errorMap['details'] as Map<String, dynamic>?),
    );
  }
}
