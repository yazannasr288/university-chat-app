import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_message.dart';

class ChatCacheRepository {
  static const int _maxCachedMessages = 50;
  static const int _maxPendingMessages = 50;
  static const String _boxName = 'chat_messages_box';

  static String _key(String groupId) => 'cached_chat_messages_$groupId';
  static String _pendingKey(String groupId) => 'pending_chat_messages_$groupId';

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
  }

  Future<List<ChatMessage>> loadMessages(String groupId) async {
    try {
      final box = Hive.box(_boxName);
      final List? raw = box.get(_key(groupId));
      if (raw == null || raw.isEmpty) return const [];

      return raw
          .map((e) => ChatMessage.fromCacheMap(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveMessages(String groupId, List<ChatMessage> messages) async {
    try {
      final box = Hive.box(_boxName);
      final cleanMessages = messages
          .where((e) => !e.isLocalPending && !e.isFailed)
          .take(_maxCachedMessages)
          .map((e) => e.toCacheMap())
          .toList();
      await box.put(_key(groupId), cleanMessages);
    } catch (_) {
      // Caching failure shouldn't break the app
    }
  }


  Future<List<ChatMessage>> loadPendingMessages(String groupId) async {
    try {
      final box = Hive.box(_boxName);
      final List? raw = box.get(_pendingKey(groupId));
      if (raw == null || raw.isEmpty) return const [];

      return raw
          .map((e) => ChatMessage.fromPendingCacheMap(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePendingMessages(String groupId, List<ChatMessage> messages) async {
    try {
      final box = Hive.box(_boxName);
      final cleanMessages = messages
          .where((e) => e.isLocalPending || e.isFailed || e.hasPendingWrites)
          .take(_maxPendingMessages)
          .map((e) => e.toPendingCacheMap())
          .toList();

      if (cleanMessages.isEmpty) {
        await box.delete(_pendingKey(groupId));
        return;
      }

      await box.put(_pendingKey(groupId), cleanMessages);
    } catch (_) {
      // Pending persistence failure should not block the chat UI.
    }
  }

  Future<void> clearPendingMessages(String groupId) async {
    try {
      final box = Hive.box(_boxName);
      await box.delete(_pendingKey(groupId));
    } catch (_) {
      // Caching failure shouldn't break the app.
    }
  }

}
