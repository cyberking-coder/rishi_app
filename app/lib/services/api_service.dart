import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Thrown for any non-2xx API response. `code` mirrors the backend error codes
/// (e.g. 'device_locked', 'bad_credentials') so the UI can react precisely.
class ApiException implements Exception {
  final int status;
  final String message;
  final String? code;

  ApiException(this.status, this.message, [this.code]);

  bool get isDeviceLocked => code == 'device_locked' || status == 423;

  @override
  String toString() => message;
}

class ApiService {
  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> _headers({bool json = true}) => {
        if (json) 'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.apiRoot}$path').replace(queryParameters: query);

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) async {
    final res = await http.get(_uri(path, query), headers: _headers());
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(_uri(path), headers: _headers(), body: jsonEncode(body));
    return _decode(res);
  }

  /// Download raw bytes (e.g. the encrypted-at-rest media file).
  Future<List<int>> getBytes(String path) async {
    final res = await http.get(_uri(path), headers: _headers(json: false));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _throwFrom(res);
    }
    return res.bodyBytes;
  }

  /// Authenticated streaming URL for the platform players. The Authorization
  /// header is passed alongside via the player's `httpHeaders`.
  Uri streamUri(int mediaId) => _uri('/media/$mediaId/stream');

  Map<String, String> get authHeaders => _headers(json: false);

  Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      _throwFrom(res);
    }
    if (res.body.isEmpty) return {};
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Never _throwFrom(http.Response res) {
    String message = 'Request failed (${res.statusCode})';
    String? code;
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final err = body['error'] as Map<String, dynamic>?;
      if (err != null) {
        message = err['message'] as String? ?? message;
        code = err['code'] as String?;
      }
    } catch (_) {/* non-JSON error body */}
    throw ApiException(res.statusCode, message, code);
  }
}
