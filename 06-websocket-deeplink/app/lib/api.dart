import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servidor (REST + WebSocket). 10.0.2.2 = localhost de la PC desde el emulador Android.
const kServer = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:5000');
String get kWsUrl => kServer.replaceFirst('http', 'ws');

class ApiError implements Exception {
  final int status;
  final String message;
  final Map<String, dynamic> body;
  ApiError(this.status, this.message, [this.body = const {}]);
  @override
  String toString() => message;
}

class Api {
  static String? token;

  static Future<void> loadToken() async => token = (await SharedPreferences.getInstance()).getString('token');

  static Map<String, String> get _h => {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};

  static dynamic _parse(http.Response r) {
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode >= 400) {
      throw ApiError(r.statusCode, body is Map ? (body['message'] ?? 'Error') : 'Error ${r.statusCode}', body is Map<String, dynamic> ? body : {});
    }
    return body;
  }

  static Future<dynamic> get(String p) async => _parse(await http.get(Uri.parse('$kServer$p'), headers: _h).timeout(const Duration(seconds: 10)));
  static Future<dynamic> post(String p, [Map? b]) async =>
      _parse(await http.post(Uri.parse('$kServer$p'), headers: _h, body: jsonEncode(b ?? {})).timeout(const Duration(seconds: 10)));

  /// Los archivos se transfieren por HTTP; luego el WebSocket notifica su disponibilidad
  static Future<Map<String, dynamic>> upload(String path, String name) async {
    final req = http.MultipartRequest('POST', Uri.parse('$kServer/upload'))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', path, filename: name));
    final res = await http.Response.fromStream(await req.send());
    return Map<String, dynamic>.from(_parse(res));
  }

  static String absolute(String url) => url.startsWith('http') ? url : '$kServer$url';
}
