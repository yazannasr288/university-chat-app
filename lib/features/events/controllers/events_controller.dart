import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/utils/error_message.dart';
import '../../../data/models/app_event.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/event_repository.dart';
import '../../../data/repositories/user_repository.dart';

class EventsController {
  final EventRepository _eventRepository;
  final UserRepository _userRepository;

  bool isLoading = false;
  String? errorMessage;
  AppUser? currentUser;
  List<String> visibilityKeys = [];

  EventsController({
    EventRepository? eventRepository,
    UserRepository? userRepository,
  })  : _eventRepository = eventRepository ?? EventRepository(),
        _userRepository = userRepository ?? UserRepository();

  Future<void> init() async {
    isLoading = true;
    errorMessage = null;

    try {
      currentUser = await _userRepository.getCurrentUser();

      final user = currentUser;
      if (user == null) {
        errorMessage = 'لا يوجد مستخدم مسجل دخول';
        visibilityKeys = [];
        return;
      }

      visibilityKeys = _buildVisibilityKeys(user);
    } catch (e) {
      errorMessage = cleanErrorMessage(e, fallback: 'تعذر تحميل الأحداث حاليا');
      visibilityKeys = [];
    } finally {
      isLoading = false;
    }
  }

  List<String> _buildVisibilityKeys(AppUser user) {
    final result = <String>{
      'all',
      if (user.department.trim().isNotEmpty)
        'dept:${user.department.trim()}',
      ...user.groupIds.map((id) => 'group:${id.trim()}'),
    };

    return result.where((e) => e.trim().isNotEmpty).toList();
  }
  bool get canCreateAnyEvent => AppRolePermissions.canCreateAnyEvent(currentUser);


  Stream<List<AppEvent>> eventsStream() {
    return _eventRepository.watchVisibleEvents(visibilityKeys);
  }

  Stream<Set<String>> interestedIdsStream() {
    final uid = currentUser?.uid ?? '';
    return _eventRepository.watchInterestedEventIds(uid);
  }

  Future<String?> toggleInterest(String eventId) {
    return _eventRepository.toggleInterest(eventId);
  }

  List<AppEvent> mapEvents(dynamic source) {
    if (source == null) return <AppEvent>[];

    if (source is List<AppEvent>) {
      final events = List<AppEvent>.from(source);
      events.sort((a, b) => a.eventAt.compareTo(b.eventAt));
      return events;
    }

    if (source is QuerySnapshot<Map<String, dynamic>>) {
      return _sort(
        source.docs
            .map((doc) => AppEvent.fromMap(doc.id, doc.data()))
            .toList(),
      );
    }

    if (source is List) {
      final events = <AppEvent>[];

      for (final item in source) {
        if (item is AppEvent) {
          events.add(item);
          continue;
        }

        if (item is QueryDocumentSnapshot<Map<String, dynamic>>) {
          events.add(AppEvent.fromMap(item.id, item.data()));
          continue;
        }

        if (item is DocumentSnapshot<Map<String, dynamic>>) {
          final data = item.data();
          if (item.exists && data != null) {
            events.add(AppEvent.fromMap(item.id, data));
          }
          continue;
        }

        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final id = (map['id'] ?? map['eventId'] ?? '').toString();
          if (id.trim().isNotEmpty) {
            events.add(AppEvent.fromMap(id, map));
          }
        }
      }

      return _sort(events);
    }

    return <AppEvent>[];
  }

  List<AppEvent> _sort(List<AppEvent> events) {
    events.sort((a, b) => a.eventAt.compareTo(b.eventAt));
    return events;
  }
}
