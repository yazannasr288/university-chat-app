import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/utils/error_message.dart';
import '../models/app_event.dart';

class EventRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  EventRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(
          region: 'us-central1',
        );

  CollectionReference<Map<String, dynamic>> get _events =>
      _firestore.collection('events');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');


  Stream<DocumentSnapshot<Map<String, dynamic>>> watchEventById(String eventId) {
    return _events.doc(eventId.trim()).snapshots();
  }


  Stream<List<AppEvent>> watchAllEvents() {
    return watchVisibleEvents(const ['all']);
  }

  Stream<List<AppEvent>> watchVisibleEvents(List<String> visibilityKeys) {
    final keys = visibilityKeys
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (keys.isEmpty) {
      return Stream<List<AppEvent>>.value(const []);
    }

    final controller = StreamController<List<AppEvent>>();
    Timer? expiryTimer;
    Timer? refreshTimer;
    final buckets = <String, List<AppEvent>>{};
    final subscriptions =
        <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    var isRefreshing = false;
    var isCancelled = false;

    final includeUniversity = keys.contains('all');
    final department = keys
        .where((key) => key.startsWith('dept:'))
        .map((key) => key.substring('dept:'.length).trim())
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    final groupIds = keys
        .where((key) => key.startsWith('group:'))
        .map((key) => key.substring('group:'.length).trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    final groupChunks = <List<String>>[];

    for (var start = 0; start < groupIds.length; start += 30) {
      groupChunks.add(
        groupIds.sublist(
          start,
          start + 30 < groupIds.length ? start + 30 : groupIds.length,
        ),
      );
    }

    void emit() {
      final byId = <String, AppEvent>{};

      for (final events in buckets.values) {
        for (final event in events) {
          byId[event.id] = event;
        }
      }

      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final result = byId.values
          .where((event) => event.eventAt >= currentTime)
          .toList()
        ..sort((a, b) => a.eventAt.compareTo(b.eventAt));

      if (!controller.isClosed) {
        controller.add(result);
      }
    }

    List<MapEntry<String, Query<Map<String, dynamic>>>> buildQueries() {
      final lowerBound = DateTime.now().millisecondsSinceEpoch;
      final result = <MapEntry<String, Query<Map<String, dynamic>>>>[];

      Query<Map<String, dynamic>> upcoming(
        Query<Map<String, dynamic>> query,
      ) {
        return query
            .where('isCancelled', isEqualTo: false)
            .where('eventAt', isGreaterThanOrEqualTo: lowerBound)
            .orderBy('eventAt')
            .limit(200);
      }

      if (includeUniversity) {
        result.add(
          MapEntry(
            'university',
            upcoming(
              _events.where(
                'scopeType',
                whereIn: const <String>['university', 'all'],
              ),
            ),
          ),
        );
      }

      if (department != null) {
        result.add(
          MapEntry(
            'department',
            upcoming(
              _events
                  .where('scopeType', isEqualTo: 'department')
                  .where('department', isEqualTo: department),
            ),
          ),
        );
      }

      for (var index = 0; index < groupChunks.length; index++) {
        final groupChunk = groupChunks[index];
        result.add(
          MapEntry(
            'groups:$index',
            upcoming(
              _events
                  .where('scopeType', isEqualTo: 'group')
                  .where('targetGroupId', whereIn: groupChunk),
            ),
          ),
        );
      }

      return result;
    }

    Future<void> refreshQueries() async {
      if (isRefreshing || isCancelled || controller.isClosed) return;
      isRefreshing = true;

      try {
        final previousSubscriptions = List.of(subscriptions);
        subscriptions.clear();
        await Future.wait(previousSubscriptions.map((sub) => sub.cancel()));

        if (isCancelled || controller.isClosed) return;

        for (final descriptor in buildQueries()) {
          final sub = descriptor.value.snapshots().listen(
            (snapshot) {
              if (isCancelled || controller.isClosed) return;
              buckets[descriptor.key] = snapshot.docs
                  .map((doc) => AppEvent.fromMap(doc.id, doc.data()))
                  .toList();
              emit();
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!isCancelled && !controller.isClosed) {
                controller.addError(error, stackTrace);
              }
            },
          );
          subscriptions.add(sub);
        }

        emit();
      } finally {
        isRefreshing = false;
      }
    }

    unawaited(refreshQueries());
    expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) => emit());
    refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      unawaited(refreshQueries());
    });

    controller.onCancel = () async {
      isCancelled = true;
      expiryTimer?.cancel();
      refreshTimer?.cancel();
      final activeSubscriptions = List.of(subscriptions);
      subscriptions.clear();
      await Future.wait(activeSubscriptions.map((sub) => sub.cancel()));
    };

    return controller.stream;
  }

  Stream<Set<String>> watchInterestedEventIds(String uid) {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return Stream<Set<String>>.value(<String>{});
    }

    return _users
        .doc(normalizedUid)
        .collection('eventInterests')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toSet());
  }

  Future<List<AppEvent>> listVisibleEvents() async {
    try {
      final callable = _functions.httpsCallable('listVisibleEvents');
      final eventsById = <String, AppEvent>{};
      int cursorEventAt = 0;
      String cursorEventId = '';

      for (var page = 0; page < 20; page++) {
        final response = await callable.call({
          'limit': 300,
          if (cursorEventAt > 0 && cursorEventId.isNotEmpty) ...{
            'cursorEventAt': cursorEventAt,
            'cursorEventId': cursorEventId,
          },
        });

        final raw = response.data;
        final payload = raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};

        final rawEvents = payload['events'] ?? payload['items'] ?? const [];

        if (rawEvents is List) {
          for (final item in rawEvents) {
            if (item is! Map) continue;

            final map = Map<String, dynamic>.from(item);
            final id = (map['id'] ?? map['eventId'] ?? '').toString().trim();

            if (id.isEmpty) continue;

            eventsById[id] = AppEvent.fromMap(id, map);
          }
        }

        final hasMore = payload['hasMore'] == true;
        final nextCursorRaw = payload['nextCursor'];
        if (!hasMore || nextCursorRaw is! Map) break;

        final nextCursor = Map<String, dynamic>.from(nextCursorRaw);
        final nextEventAt = int.tryParse(nextCursor['eventAt']?.toString() ?? '') ?? 0;
        final nextEventId = (nextCursor['eventId'] ?? '').toString().trim();

        if (nextEventAt <= 0 || nextEventId.isEmpty) break;
        if (nextEventAt == cursorEventAt && nextEventId == cursorEventId) break;

        cursorEventAt = nextEventAt;
        cursorEventId = nextEventId;
      }

      final events = eventsById.values.toList()
        ..sort((a, b) {
          final byTime = a.eventAt.compareTo(b.eventAt);
          if (byTime != 0) return byTime;
          return a.id.compareTo(b.id);
        });
      return events;
    } on FirebaseFunctionsException catch (e) {
      throw _functionMessage(e, tr('events.errors.load_failed_now'));
    } catch (_) {
      throw tr('events.errors.load_failed_now');
    }
  }

  Future<String?> createEvent({
    required String scopeType,
    String groupId = '',
    required String title,
    required String details,
    required String location,
    String notes = '',
    required int eventAt,
  }) async {
    try {
      final callable = _functions.httpsCallable('createEvent');
      await callable.call({
        'scopeType': scopeType.trim(),
        'groupId': groupId.trim(),
        'title': title.trim(),
        'details': details.trim(),
        'location': location.trim(),
        'notes': notes.trim(),
        'eventAt': eventAt,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return _functionMessage(e, tr('events.errors.create_failed_now'));
    } catch (_) {
      return tr('events.errors.create_failed_now');
    }
  }

  Future<String?> updateEvent({
    required String eventId,
    required String title,
    required String details,
    required String location,
    required String notes,
    required int eventAt,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateEvent');
      await callable.call({
        'eventId': eventId.trim(),
        'title': title.trim(),
        'details': details.trim(),
        'location': location.trim(),
        'notes': notes.trim(),
        'eventAt': eventAt,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return _functionMessage(e, tr('events.errors.update_failed_now'));
    } catch (_) {
      return tr('events.errors.update_failed_now');
    }
  }

  Future<String?> cancelEvent(String eventId) async {
    try {
      final callable = _functions.httpsCallable('cancelEvent');
      await callable.call({'eventId': eventId.trim()});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return _functionMessage(e, tr('events.errors.cancel_failed_now'));
    } catch (_) {
      return tr('events.errors.cancel_failed_now');
    }
  }

  Future<String?> toggleInterest(String eventId) async {
    try {
      final callable = _functions.httpsCallable('toggleEventInterest');
      await callable.call({'eventId': eventId.trim()});
      return null;
    } on FirebaseFunctionsException catch (e) {
      return _functionMessage(e, tr('events.errors.interest_update_failed_now'));
    } catch (_) {
      return tr('events.errors.interest_update_failed_now');
    }
  }

  String _functionMessage(
    FirebaseFunctionsException error,
    String fallback,
  ) {
    return cleanErrorMessage(error, fallback: fallback);
  }
}
