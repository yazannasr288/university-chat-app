import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'app_error_monitor.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  final handled = await NotificationService.showRemoteChatNotification(
    message,
    fromBackground: true,
  );

  if (kDebugMode) {
    debugPrint(
      handled
          ? 'Background chat notification rendered locally: ${message.messageId}'
          : 'Background message ignored by local notification renderer: ${message.messageId}',
    );
  }
}

@pragma('vm:entry-point')
Future<void> notificationTapBackgroundHandler(
  NotificationResponse response,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (_) {
    // Opening a local notification should not crash the background isolate if
    // Firebase was already initialized by another engine or is temporarily
    // unavailable. Navigation can still be resolved from the local payload.
  }

  await NotificationService.handleNotificationResponse(response);
}

class _NotificationOpenTarget {
  final String groupId;
  final String groupName;

  const _NotificationOpenTarget({
    required this.groupId,
    required this.groupName,
  });
}

class _StoredNotificationLine {
  final String id;
  final String text;
  final int time;

  const _StoredNotificationLine({
    required this.id,
    required this.text,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'time': time,
      };

  static _StoredNotificationLine? fromJson(Object? value) {
    if (value is! Map) return null;

    final text = value['text']?.toString().trim() ?? '';
    if (text.isEmpty) return null;

    final rawTime = NumberParser.toInt(value['time']);
    return _StoredNotificationLine(
      id: value['id']?.toString().trim() ?? '',
      text: text,
      time: rawTime > 0 ? rawTime : DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class _StoredGroupNotification {
  final String groupId;
  final String groupName;
  final int latestTime;
  final List<_StoredNotificationLine> lines;

  const _StoredGroupNotification({
    required this.groupId,
    required this.groupName,
    required this.latestTime,
    required this.lines,
  });

  int get unreadCount => lines.length;

  String get latestLine => lines.isEmpty ? '' : lines.last.text;

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'groupName': groupName,
        'latestTime': latestTime,
        'lines': lines.map((line) => line.toJson()).toList(),
      };

  static _StoredGroupNotification? fromJson(Object? value) {
    if (value is! Map) return null;

    final groupId = value['groupId']?.toString().trim() ?? '';
    if (groupId.isEmpty) return null;

    final rawLines = value['lines'];
    final lines = rawLines is List
        ? rawLines
            .map(_StoredNotificationLine.fromJson)
            .whereType<_StoredNotificationLine>()
            .toList()
        : <_StoredNotificationLine>[];

    if (lines.isEmpty) return null;

    final latestTime = NumberParser.toInt(value['latestTime']);

    return _StoredGroupNotification(
      groupId: groupId,
      groupName: value['groupName']?.toString().trim() ?? '',
      latestTime: latestTime > 0 ? latestTime : lines.last.time,
      lines: lines,
    );
  }
}

class NumberParser {
  static int toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class NotificationService {
  static String? activeGroupId;

  static void setActiveGroup(String? groupId) {
    final cleanGroupId = groupId?.trim() ?? '';
    activeGroupId = cleanGroupId.isEmpty ? null : cleanGroupId;

    // Any local notification lines for the currently opened group are stale.
    // Remove them immediately so read messages are not merged back into the
    // next incoming notification for the same group.
    if (activeGroupId != null) {
      unawaited(_cancelGroupNotifications(activeGroupId!));
    }
  }

  static final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'chat_messages';
  static const String _fallbackChannelName = 'Chat Messages';
  static const String _fallbackChannelDescription =
      'Notifications for chat messages';
  static const String _notificationGroupKey = 'alwatanyachat_chat_messages';
  static const String _fallbackSummaryTitle = 'Alwatanya Chat';
  static const String _storedGroupsPrefsKey = 'chat_notification_groups_v2';
  static const String _notificationIdMapPrefsKey =
      'chat_notification_id_map_v1';
  static const int _summaryNotificationId = 0x0A170001;
  static const int _maxLinesPerGroup = 6;
  static const int _maxStoredGroups = 12;

  static bool _initialized = false;
  static bool _localNotificationsConfigured = false;
  static Future<void>? _localNotificationsConfiguration;
  static Future<void> _storedGroupsOperationQueue = Future<void>.value();
  static StreamSubscription<RemoteMessage>? _foregroundSub;
  static StreamSubscription<RemoteMessage>? _openedSub;
  static void Function(String groupId, String groupName)? _onOpenGroup;
  static _NotificationOpenTarget? _pendingOpenGroup;

  static void configureOpenGroupHandler(
    void Function(String groupId, String groupName) handler,
  ) {
    _onOpenGroup = handler;

    final pending = _pendingOpenGroup;
    if (pending != null) {
      _pendingOpenGroup = null;
      _openGroup(pending.groupId, pending.groupName);
    }
  }

  static void clearOpenGroupHandler() {
    _onOpenGroup = null;
  }

  static String _localized(String key, String fallback) {
    try {
      final value = tr(key).trim();
      return value.isEmpty || value == key ? fallback : value;
    } catch (_) {
      return fallback;
    }
  }

  static String get _channelName => _localized(
        'notifications.chat_channel_name',
        _fallbackChannelName,
      );

  static String get _channelDescription => _localized(
        'notifications.chat_channel_desc',
        _fallbackChannelDescription,
      );

  static bool get _devicePrefersArabic {
    try {
      return PlatformDispatcher.instance.locale.languageCode.toLowerCase() ==
          'ar';
    } catch (_) {
      return false;
    }
  }

  static String get _summaryTitle => _localized(
        'notifications.chat_summary_title',
        _fallbackSummaryTitle,
      );

  static String _summaryBody({
    required int groupCount,
    required int messageCount,
  }) {
    if (_devicePrefersArabic) {
      return groupCount == 1
          ? '$messageCount رسائل جديدة في مجموعة واحدة'
          : '$messageCount رسائل جديدة في $groupCount مجموعات';
    }

    return groupCount == 1
        ? '$messageCount new messages in 1 group'
        : '$messageCount new messages in $groupCount groups';
  }

  static int _notificationIdForGroup(String groupId) {
    final cleanGroupId = groupId.trim();
    if (cleanGroupId.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch & 0x7fffffff;
    }

    var hash = 0;
    for (final unit in cleanGroupId.codeUnits) {
      hash = (hash * 31 + unit) & 0x0fffffff;
    }

    return 0x10000000 + (hash == 0 ? 1 : hash);
  }

  static AndroidNotificationChannel _androidChannel() {
    return AndroidNotificationChannel(
      channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
  }

  static InitializationSettings _initializationSettings() {
    return const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
  }

  static Future<void> _ensureLocalNotificationsConfigured() async {
    if (_localNotificationsConfigured) return;

    final pending = _localNotificationsConfiguration;
    if (pending != null) return pending;

    final configuration = _configureLocalNotifications();
    _localNotificationsConfiguration = configuration;
    try {
      await configuration;
    } finally {
      if (identical(_localNotificationsConfiguration, configuration)) {
        _localNotificationsConfiguration = null;
      }
    }
  }

  static Future<void> _configureLocalNotifications() async {
    await localNotifications.initialize(
      _initializationSettings(),
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          notificationTapBackgroundHandler,
    );

    await localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel());

    _localNotificationsConfigured = true;
  }

  static String _notificationPayload({
    required String groupId,
    required String groupName,
  }) {
    return jsonEncode({
      'groupId': groupId.trim(),
      'groupName': groupName.trim(),
    });
  }

  static _NotificationOpenTarget? _decodePayload(String? payload) {
    final cleanPayload = payload?.trim() ?? '';
    if (cleanPayload.isEmpty) return null;

    try {
      final decoded = jsonDecode(cleanPayload);
      if (decoded is Map) {
        final groupId = decoded['groupId']?.toString().trim() ?? '';
        final groupName = decoded['groupName']?.toString().trim() ?? '';
        if (groupId.isNotEmpty) {
          return _NotificationOpenTarget(
            groupId: groupId,
            groupName: groupName,
          );
        }
      }
    } catch (_) {
      // Older local notifications used the group id itself as payload.
    }

    return _NotificationOpenTarget(groupId: cleanPayload, groupName: '');
  }

  static Map<String, _StoredGroupNotification> _decodeStoredGroups(
    String? encoded,
  ) {
    if (encoded == null || encoded.trim().isEmpty) {
      return <String, _StoredGroupNotification>{};
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return <String, _StoredGroupNotification>{};

      final result = <String, _StoredGroupNotification>{};
      for (final entry in decoded.entries) {
        final group = _StoredGroupNotification.fromJson(entry.value);
        if (group != null) result[group.groupId] = group;
      }
      return result;
    } catch (error, stackTrace) {
      AppErrorMonitor.recordHandled(
        error,
        stackTrace,
        context: 'notification_decode_stored_groups',
      );
      return <String, _StoredGroupNotification>{};
    }
  }

  static String _encodeStoredGroups(
    Map<String, _StoredGroupNotification> groups,
  ) {
    return jsonEncode(
      groups.map((key, value) => MapEntry(key, value.toJson())),
    );
  }

  static Future<Map<String, _StoredGroupNotification>> _readStoredGroups() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeStoredGroups(prefs.getString(_storedGroupsPrefsKey));
  }

  static Future<void> _writeStoredGroups(
    Map<String, _StoredGroupNotification> groups,
  ) async {
    final sorted = groups.values.toList()
      ..sort((a, b) => b.latestTime.compareTo(a.latestTime));

    final limited = <String, _StoredGroupNotification>{};
    for (final group in sorted.take(_maxStoredGroups)) {
      limited[group.groupId] = group;
    }

    final prefs = await SharedPreferences.getInstance();
    if (limited.isEmpty) {
      await prefs.remove(_storedGroupsPrefsKey);
    } else {
      await prefs.setString(_storedGroupsPrefsKey, _encodeStoredGroups(limited));
    }
  }

  static Map<int, String> _decodeNotificationIdMap(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return <int, String>{};

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return <int, String>{};

      final result = <int, String>{};
      for (final entry in decoded.entries) {
        final id = int.tryParse(entry.key.toString()) ?? 0;
        final groupId = entry.value?.toString().trim() ?? '';
        if (id > 0 && groupId.isNotEmpty) result[id] = groupId;
      }
      return result;
    } catch (error, stackTrace) {
      AppErrorMonitor.recordHandled(
        error,
        stackTrace,
        context: 'notification_decode_id_map',
      );
      return <int, String>{};
    }
  }

  static Future<Map<int, String>> _readNotificationIdMap() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeNotificationIdMap(prefs.getString(_notificationIdMapPrefsKey));
  }

  static Future<void> _writeNotificationIdMap(Map<int, String> map) async {
    final prefs = await SharedPreferences.getInstance();
    if (map.isEmpty) {
      await prefs.remove(_notificationIdMapPrefsKey);
      return;
    }

    await prefs.setString(
      _notificationIdMapPrefsKey,
      jsonEncode(map.map((key, value) => MapEntry(key.toString(), value))),
    );
  }

  static Future<void> _rememberNotificationId({
    required int notificationId,
    required String groupId,
  }) async {
    final map = await _readNotificationIdMap();
    map[notificationId] = groupId.trim();
    await _writeNotificationIdMap(map);
  }

  static Future<void> _forgetNotificationIdForGroup(String groupId) async {
    final cleanGroupId = groupId.trim();
    if (cleanGroupId.isEmpty) return;

    final map = await _readNotificationIdMap();
    map.removeWhere((_, value) => value.trim() == cleanGroupId);
    await _writeNotificationIdMap(map);
  }

  static Future<_StoredGroupNotification> _storeIncomingChatNotification({
    required String groupId,
    required String groupName,
    required String lineText,
    required String messageId,
    required int messageTime,
  }) {
    return _withStoredGroupsLock(() async {
      final groups = await _readStoredGroups();
      final existing = groups[groupId];
      final existingLines =
          existing?.lines ?? const <_StoredNotificationLine>[];

      final cleanMessageId = messageId.trim();
      final deduped = cleanMessageId.isEmpty
          ? existingLines
          : existingLines.where((line) => line.id != cleanMessageId).toList();

      final line = _StoredNotificationLine(
        id: cleanMessageId,
        text: lineText,
        time: messageTime,
      );

      final nextLines = [...deduped, line]
        ..sort((a, b) => a.time.compareTo(b.time));

      final limitedLines = nextLines.length <= _maxLinesPerGroup
          ? nextLines
          : nextLines.sublist(nextLines.length - _maxLinesPerGroup);

      final stored = _StoredGroupNotification(
        groupId: groupId,
        groupName: groupName.isNotEmpty ? groupName : existing?.groupName ?? '',
        latestTime: messageTime > (existing?.latestTime ?? 0)
            ? messageTime
            : existing?.latestTime ?? messageTime,
        lines: limitedLines,
      );

      groups[groupId] = stored;
      await _writeStoredGroups(groups);
      return stored;
    });
  }

  static Future<void> _removeStoredGroup(String groupId) {
    return _withStoredGroupsLock(() async {
      final groups = await _readStoredGroups();
      groups.remove(groupId.trim());
      await _writeStoredGroups(groups);
    });
  }

  static Future<T> _withStoredGroupsLock<T>(
    Future<T> Function() operation,
  ) {
    final completer = Completer<T>();
    _storedGroupsOperationQueue = _storedGroupsOperationQueue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static List<_StoredGroupNotification> _sortedGroups(
    Map<String, _StoredGroupNotification> groups,
  ) {
    return groups.values.toList()
      ..sort((a, b) => b.latestTime.compareTo(a.latestTime));
  }

  static Future<void> _showGroupSummaryNotification() async {
    await _ensureLocalNotificationsConfigured();

    final groups = _sortedGroups(await _readStoredGroups());
    if (groups.isEmpty) {
      await localNotifications.cancel(_summaryNotificationId);
      return;
    }

    final messageCount = groups.fold<int>(
      0,
      (total, group) => total + group.unreadCount,
    );
    final body = _summaryBody(
      groupCount: groups.length,
      messageCount: messageCount,
    );
    final inboxLines = groups
        .take(6)
        .map((group) {
          final name = group.groupName.isEmpty
              ? _fallbackSummaryTitle
              : group.groupName;
          final latestLine = group.latestLine;
          return latestLine.isEmpty ? name : '$name: $latestLine';
        })
        .toList();

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        groupKey: _notificationGroupKey,
        setAsGroupSummary: true,
        groupAlertBehavior: GroupAlertBehavior.children,
        category: AndroidNotificationCategory.message,
        styleInformation: InboxStyleInformation(
          inboxLines,
          contentTitle: _summaryTitle,
          summaryText: body,
        ),
        number: messageCount,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );

    await localNotifications.show(
      _summaryNotificationId,
      _summaryTitle,
      body,
      details,
    );
  }

  static Future<void> _showStoredGroupNotification(
    _StoredGroupNotification group,
  ) async {
    await _ensureLocalNotificationsConfigured();

    final title = group.groupName.isEmpty ? _fallbackSummaryTitle : group.groupName;
    final body = group.latestLine;
    final notificationId = _notificationIdForGroup(group.groupId);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        groupKey: _notificationGroupKey,
        groupAlertBehavior: GroupAlertBehavior.children,
        category: AndroidNotificationCategory.message,
        styleInformation: InboxStyleInformation(
          group.lines.map((line) => line.text).toList(),
          contentTitle: title,
          summaryText: _devicePrefersArabic
              ? (group.unreadCount == 1
                  ? 'رسالة واحدة'
                  : '${group.unreadCount} رسائل')
              : (group.unreadCount == 1
                  ? '1 message'
                  : '${group.unreadCount} messages'),
        ),
        number: group.unreadCount,
      ),
      iOS: const DarwinNotificationDetails(),
      macOS: const DarwinNotificationDetails(),
    );

    await _rememberNotificationId(
      notificationId: notificationId,
      groupId: group.groupId,
    );

    await localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: _notificationPayload(
        groupId: group.groupId,
        groupName: group.groupName,
      ),
    );

    await _showGroupSummaryNotification();
  }

  static Future<void> _cancelGroupNotifications(String groupId) async {
    final cleanGroupId = groupId.trim();
    if (cleanGroupId.isEmpty) return;

    try {
      await _ensureLocalNotificationsConfigured();
      await _removeStoredGroup(cleanGroupId);
      await localNotifications.cancel(_notificationIdForGroup(cleanGroupId));
      await _forgetNotificationIdForGroup(cleanGroupId);
      await _showGroupSummaryNotification();
    } catch (error, stackTrace) {
      AppErrorMonitor.recordHandled(
        error,
        stackTrace,
        context: 'notification_cancel_group',
      );
    }
  }

  static bool _isChatNotification(RemoteMessage message) {
    final kind = _dataString(message, 'notificationKind');
    if (kind == 'chat_message') return true;

    return _dataString(message, 'groupId').isNotEmpty &&
        _dataString(message, 'messageId').isNotEmpty;
  }

  static String _dataString(RemoteMessage message, String key) {
    return message.data[key]?.toString().trim() ?? '';
  }

  static String _remoteTitle(RemoteMessage message) {
    final dataTitle = _dataString(message, 'notificationTitle');
    return dataTitle.isNotEmpty
        ? dataTitle
        : message.notification?.title?.trim() ?? '';
  }

  static String _remoteBody(RemoteMessage message) {
    final dataBody = _dataString(message, 'notificationBody');
    return dataBody.isNotEmpty
        ? dataBody
        : message.notification?.body?.trim() ?? '';
  }

  static Future<bool> showRemoteChatNotification(
    RemoteMessage message, {
    bool fromBackground = false,
  }) async {
    if (!_isChatNotification(message)) return false;

    final groupId = _dataString(message, 'groupId');
    if (groupId.isEmpty) return false;

    if (!fromBackground && groupId == activeGroupId) {
      await _cancelGroupNotifications(groupId);
      return true;
    }

    try {
      await _ensureLocalNotificationsConfigured();

      final title = _remoteTitle(message);
      final body = _remoteBody(message);
      final dataGroupName = _dataString(message, 'groupName');
      final groupName = dataGroupName.isNotEmpty ? dataGroupName : title;
      final sender = _dataString(message, 'sender');
      final dataMessageId = _dataString(message, 'messageId');
      final messageId = dataMessageId.isNotEmpty
          ? dataMessageId
          : message.messageId?.trim() ?? '';
      final messageTime = NumberParser.toInt(message.data['messageTime']);
      final now = DateTime.now().millisecondsSinceEpoch;
      final effectiveTime = messageTime > 0 ? messageTime : now;
      final cleanBody = body.isNotEmpty
          ? body
          : sender.isEmpty
              ? 'New message'
              : '$sender: New message';

      final stored = await _storeIncomingChatNotification(
        groupId: groupId,
        groupName: groupName,
        lineText: cleanBody,
        messageId: messageId,
        messageTime: effectiveTime,
      );

      await _showStoredGroupNotification(stored);
      return true;
    } catch (error, stackTrace) {
      AppErrorMonitor.recordHandled(
        error,
        stackTrace,
        context: fromBackground
            ? 'notification_background_render'
            : 'notification_foreground_render',
      );
      if (kDebugMode) {
        debugPrint('Render chat notification failed: $error');
      }
      return false;
    }
  }

  static void _openGroup(String groupId, String groupName) {
    final cleanGroupId = groupId.trim();
    if (cleanGroupId.isEmpty) return;

    unawaited(_cancelGroupNotifications(cleanGroupId));

    final handler = _onOpenGroup;
    if (handler == null) {
      _pendingOpenGroup = _NotificationOpenTarget(
        groupId: cleanGroupId,
        groupName: groupName.trim(),
      );
      return;
    }

    handler(cleanGroupId, groupName.trim());
  }

  static Future<_NotificationOpenTarget?> _targetFromResponse(
    NotificationResponse response,
  ) async {
    final payloadTarget = _decodePayload(response.payload);
    if (payloadTarget != null) return payloadTarget;

    final notificationId = response.id;
    if (notificationId == null) return null;

    final map = await _readNotificationIdMap();
    final groupId = map[notificationId]?.trim() ?? '';
    if (groupId.isEmpty) return null;

    final storedGroup = (await _readStoredGroups())[groupId];
    return _NotificationOpenTarget(
      groupId: groupId,
      groupName: storedGroup?.groupName ?? '',
    );
  }

  static Future<void> handleNotificationResponse(
    NotificationResponse response,
  ) async {
    // The app no longer exposes notification actions. Ignore any stale action
    // response left from notifications posted by an older build.
    final actionId = response.actionId?.trim() ?? '';
    if (actionId.isNotEmpty) return;

    final payload = await _targetFromResponse(response);
    if (payload == null) return;

    _openGroup(payload.groupId, payload.groupName);
  }

  static Future<void> _handleRemoteMessageOpen(RemoteMessage message) async {
    final groupId = _dataString(message, 'groupId');
    if (groupId.isEmpty) return;

    final groupName = _dataString(message, 'groupName').isNotEmpty
        ? _dataString(message, 'groupName')
        : message.notification?.title?.trim() ?? '';

    _openGroup(groupId, groupName);
  }

  static Future<void> init() async {
    if (_initialized) return;

    try {
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (kDebugMode) {
        debugPrint(
          'Notification permission: ${permission.authorizationStatus.name}',
        );
      }

      await _ensureLocalNotificationsConfigured();

      final launchDetails = await localNotifications
          .getNotificationAppLaunchDetails();
      final launchResponse = launchDetails?.notificationResponse;
      if (launchDetails?.didNotificationLaunchApp == true &&
          launchResponse != null) {
        unawaited(handleNotificationResponse(launchResponse));
      }

      await _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) async {
        final handled = await showRemoteChatNotification(message);
        if (handled) return;

        final notification = message.notification;
        if (notification == null) return;

        final messageGroupId = message.data['groupId']?.toString().trim();
        final messageGroupName = message.data['groupName']?.toString().trim() ??
            notification.title?.trim() ??
            '';

        if (messageGroupId != null &&
            messageGroupId.isNotEmpty &&
            messageGroupId == activeGroupId) {
          return;
        }

        final details = NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            groupKey: _notificationGroupKey,
            groupAlertBehavior: GroupAlertBehavior.children,
            category: AndroidNotificationCategory.message,
          ),
          iOS: const DarwinNotificationDetails(),
          macOS: const DarwinNotificationDetails(),
        );

        final notificationId = messageGroupId == null || messageGroupId.isEmpty
            ? notification.hashCode
            : _notificationIdForGroup(messageGroupId);

        if (messageGroupId != null && messageGroupId.isNotEmpty) {
          await _rememberNotificationId(
            notificationId: notificationId,
            groupId: messageGroupId,
          );
        }

        await localNotifications.show(
          notificationId,
          notification.title,
          notification.body,
          details,
          payload: messageGroupId == null || messageGroupId.isEmpty
              ? null
              : _notificationPayload(
                  groupId: messageGroupId,
                  groupName: messageGroupName,
                ),
        );
      });

      await _openedSub?.cancel();
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleRemoteMessageOpen,
      );

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        unawaited(_handleRemoteMessageOpen(initialMessage));
      }

      _initialized = true;
    } catch (error, stackTrace) {
      _initialized = false;
      AppErrorMonitor.recordHandled(
        error,
        stackTrace,
        context: 'notification_service_init',
      );
      if (kDebugMode) {
        debugPrint('Notification init failed: $error');
        debugPrint('$stackTrace');
      }
      rethrow;
    }
  }

  static Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedSub?.cancel();
    _foregroundSub = null;
    _openedSub = null;
    _initialized = false;
  }
}
