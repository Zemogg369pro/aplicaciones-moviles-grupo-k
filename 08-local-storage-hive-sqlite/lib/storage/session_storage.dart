import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// INICIO DE SESIÓN con SharedPreferences (local storage clave-valor).
/// Guarda la sesión activa, la opción "recordarme" y las cuentas registradas (contraseña como hash).
class SessionStorage {
  static const _kSession = 'session_user';
  static const _kRemember = 'remember_user';
  static const _kAccounts = 'accounts';

  final SharedPreferences _p;
  SessionStorage(this._p);

  static String _hash(String s) => sha256.convert(utf8.encode(s)).toString();

  Map<String, String> get _accounts => Map<String, String>.from(jsonDecode(_p.getString(_kAccounts) ?? '{}'));

  Future<void> register(String user, String pass) async {
    final u = user.trim().toLowerCase();
    if (u.isEmpty || pass.length < 6) throw ArgumentError('Usuario requerido y contraseña de al menos 6 caracteres.');
    final acc = _accounts;
    if (acc.containsKey(u)) throw ArgumentError('El usuario ya existe.');
    acc[u] = _hash(pass);
    await _p.setString(_kAccounts, jsonEncode(acc));
  }

  Future<void> login(String user, String pass, {bool remember = true}) async {
    final u = user.trim().toLowerCase();
    if (_accounts[u] != _hash(pass)) throw ArgumentError('Usuario o contraseña incorrectos.');
    await _p.setString(_kSession, u);
    remember ? await _p.setString(_kRemember, u) : await _p.remove(_kRemember);
  }

  String? get currentUser => _p.getString(_kSession);
  String? get rememberedUser => _p.getString(_kRemember);

  Future<void> logout() => _p.remove(_kSession);
}
