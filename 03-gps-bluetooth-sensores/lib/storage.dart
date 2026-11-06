import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class TripStorage {
  static const _key = 'trips';

  static Future<List<Trip>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => Trip.fromJson(e)).toList()..sort((a, b) => b.start.compareTo(a.start));
  }

  static Future<void> save(Trip t) async {
    final list = await load();
    list.removeWhere((x) => x.id == t.id);
    list.insert(0, t);
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> delete(String id) async {
    final list = await load()..removeWhere((x) => x.id == id);
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }
}
