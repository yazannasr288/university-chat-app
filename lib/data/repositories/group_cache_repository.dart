import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/group_model.dart';

class GroupCacheRepository {
  static const int _maxCachedGroups = 40;

  static String _key(String uid) => 'cached_groups_$uid';

  Future<List<GroupModel>> loadGroups(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => GroupModel.fromCacheMap(Map<String, dynamic>.from(e)))
          .where((e) => e.groupId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveGroups(String uid, List<GroupModel> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final limited = groups.take(_maxCachedGroups).map((e) => e.toCacheMap()).toList();
    await prefs.setString(_key(uid), jsonEncode(limited));
  }
}
