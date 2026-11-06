import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

/// Cambia esta URL por la IP de tu PC (10.0.2.2 = localhost desde el emulador Android)
const String kApiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class Api {
  static final _box = GetStorage();

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_box.read('token') != null) 'Authorization': 'Bearer ${_box.read('token')}',
      };

  static Future<dynamic> _send(Future<http.Response> Function() req) async {
    try {
      final res = await req().timeout(const Duration(seconds: 10));
      final body = res.body.isEmpty ? null : jsonDecode(res.body);
      if (res.statusCode >= 400) {
        throw ApiException(body is Map && body['message'] != null ? body['message'] : 'Error ${res.statusCode}');
      }
      return body;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('No hay conexión con el servidor');
    }
  }

  static Uri _u(String path, [Map<String, String>? q]) => Uri.parse('$kApiUrl$path').replace(queryParameters: q);

  static Future<dynamic> get(String path, [Map<String, String>? q]) => _send(() => http.get(_u(path, q), headers: _headers));
  static Future<dynamic> post(String path, [Object? body]) => _send(() => http.post(_u(path), headers: _headers, body: jsonEncode(body ?? {})));
  static Future<dynamic> put(String path, Object body) => _send(() => http.put(_u(path), headers: _headers, body: jsonEncode(body)));
  static Future<dynamic> patch(String path, Object body) => _send(() => http.patch(_u(path), headers: _headers, body: jsonEncode(body)));
  static Future<dynamic> delete(String path) => _send(() => http.delete(_u(path), headers: _headers));
}
