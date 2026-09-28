import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_message.dart';
import '../../../data/models/app_event.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/event_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../widgets/event_card.dart';
import 'edit_event_page.dart';

class EventDetailsPage extends StatefulWidget {
  final String eventId;
  final String currentUid;

  const EventDetailsPage({
    super.key,
    required this.eventId,
    required this.currentUid,
  });

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  final EventRepository _eventRepository = EventRepository();
  final UserRepository _userRepository = UserRepository();

  AppUser? _currentUser;
  bool _loadingUser = true;
  String? _userError;
  int _reloadKey = 0;
  bool _cancellingEvent = false;
  bool _togglingInterest = false;
  Future<bool>? _managePermissionFuture;
  String _managePermissionKey = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    setState(() {
      _loadingUser = true;
      _userError = null;
      _currentUser = null;
      _managePermissionFuture = null;
      _managePermissionKey = '';
    });

    try {
      _currentUser = await _userRepository.getCurrentUser();
      if (_currentUser == null) {
        _userError = 'auth.errors.session_expired_sign_in_again'.tr();
      }
    } catch (e) {
      _userError = cleanErrorMessage(
        e,
        fallback: 'legacy.could_not_load_user_data_check_connection'.tr(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingUser = false;
        });
      }
    }
  }

  Future<void> _toggleInterest() async {
    if (_togglingInterest) return;

    setState(() => _togglingInterest = true);
    final error = await _eventRepository.toggleInterest(widget.eventId);

    if (!mounted) return;
    setState(() => _togglingInterest = false);

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    showAppSnackBar(
      context,
      'events.interest_event_has_been_updated'.tr(),
      type: SnackType.success,
    );
  }

  Future<bool> _canManageEvent(AppEvent event) async {
    final user = _currentUser;
    if (user == null) return false;

    if (AppRolePermissions.canManageEventSync(
      user: user,
      createdBy: event.createdBy,
      scopeType: event.scopeType,
      department: event.department,
    )) {
      return true;
    }

    if (event.scopeType == 'group' && event.targetGroupId.trim().isNotEmpty) {
      final groupDoc =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(event.targetGroupId)
              .get();

      if (!groupDoc.exists) return false;

      final groupData = groupDoc.data() ?? <String, dynamic>{};
      final adminId = (groupData['adminId'] ?? '').toString();
      final adminIds =
          (groupData['adminIds'] is List)
              ? (groupData['adminIds'] as List)
                  .map((e) => e.toString())
                  .toList()
              : const <String>[];
      return AppRolePermissions.canManageGroup(
        groupAdminId: adminId,
        groupAdminIds: adminIds,
        currentUid: user.uid,
        currentRole: user.role,
        currentDepartment: user.department,
        groupDepartment: (groupData['department'] ?? '').toString(),
        groupName: (groupData['groupName'] ?? '').toString(),
      );
    }

    return false;
  }

  Future<bool> _canManageFutureFor(AppEvent event) {
    final user = _currentUser;
    final key = <String>[
      widget.eventId,
      event.createdBy,
      event.scopeType,
      event.department,
      event.targetGroupId,
      user?.uid ?? '',
      user?.role ?? '',
      user?.department ?? '',
    ].join('|');

    if (_managePermissionFuture == null || _managePermissionKey != key) {
      _managePermissionKey = key;
      _managePermissionFuture = _canManageEvent(event);
    }

    return _managePermissionFuture!;
  }

  Future<void> _cancelEvent() async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: 'events.cancel_event'.tr(),
      message: 'events.do_want_cancel_event'.tr(),
      cancelText: 'common.cancel'.tr(),
      confirmText: 'events.confirm_cancellation'.tr(),
    );

    if (!confirm) return;

    setState(() => _cancellingEvent = true);
    final error = await _eventRepository.cancelEvent(widget.eventId);

    if (!mounted) return;
    setState(() => _cancellingEvent = false);

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    showAppSnackBar(
      context,
      'events.event_was_cancelled_successfully'.tr(),
      type: SnackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: 'events.event_details'.tr(),
      useBackground: false,
      body: AppScaffoldBackground(
        animate: false,
        child:
            _loadingUser
                ? const AppLoader()
                : _userError != null
                ? AppEmptyState(
                  icon: Icons.lock_outline_rounded,
                  text: _userError!,
                  actionLabel: 'common.retry'.tr(),
                  actionLoading: _loadingUser,
                  onAction: _loadCurrentUser,
                )
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  key: ValueKey(_reloadKey),
                  stream: _eventRepository.watchEventById(widget.eventId),
                  builder: (context, eventSnapshot) {
                    if (eventSnapshot.hasError) {
                      return AppEmptyState(
                        icon: Icons.wifi_off_rounded,
                        text:
                            'events.could_not_load_event_details_check_connection'
                                .tr(),
                        actionLabel: 'common.retry'.tr(),
                        onAction: () => setState(() => _reloadKey++),
                      );
                    }

                    if (!eventSnapshot.hasData) {
                      return const AppLoader();
                    }

                    final doc = eventSnapshot.data!;
                    if (!doc.exists || doc.data() == null) {
                      return AppEmptyState(
                        icon: Icons.event_busy_rounded,
                        text: 'events.event_not_found'.tr(),
                      );
                    }

                    final event = AppEvent.fromMap(doc.id, doc.data()!);

                    return StreamBuilder<Set<String>>(
                      stream: _eventRepository.watchInterestedEventIds(
                        widget.currentUid,
                      ),
                      builder: (context, interestedSnapshot) {
                        if (interestedSnapshot.hasError) {
                          return AppEmptyState(
                            icon: Icons.favorite_border_rounded,
                            text: 'events.unable_load_event_interests'.tr(),
                            actionLabel: 'common.retry'.tr(),
                            onAction: () => setState(() => _reloadKey++),
                          );
                        }

                        final interestedIds =
                            interestedSnapshot.data ?? <String>{};
                        final isInterested = interestedIds.contains(
                          widget.eventId,
                        );

                        return FutureBuilder<bool>(
                          future: _canManageFutureFor(event),
                          builder: (context, manageSnapshot) {
                            final canManage =
                                manageSnapshot.hasError
                                    ? false
                                    : manageSnapshot.data ?? false;

                            return ListView(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.lg,
                              ),
                              children: [
                                if (event.isCancelled)
                                  Container(
                                    margin: const EdgeInsets.fromLTRB(
                                      12,
                                      12,
                                      12,
                                      0,
                                    ),
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(
                                        alpha: 0.10,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.lg,
                                      ),
                                      border: Border.all(
                                        color: AppColors.error.withValues(
                                          alpha: 0.28,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'events.event_has_been_cancelled'.tr(),
                                      style: context.textTheme.titleSmall
                                          ?.copyWith(
                                            color: AppColors.error,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                EventCard(
                                  event: event,
                                  isInterested: isInterested,
                                  onToggleInterest: _toggleInterest,
                                  interestLoading: _togglingInterest,
                                ),
                                if (canManage && !event.isCancelled) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: AppCompactButton(
                                            text: 'events.edit_event'.tr(),
                                            icon: Icons.edit_rounded,
                                            outlined: true,
                                            onPressed:
                                                event.isPast
                                                    ? null
                                                    : () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder:
                                                              (_) =>
                                                                  EditEventPage(
                                                                    event:
                                                                        event,
                                                                  ),
                                                        ),
                                                      );
                                                    },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: AppCompactButton(
                                            text: 'events.cancel_event'.tr(),
                                            icon: Icons.event_busy_rounded,
                                            backgroundColor: AppColors.error,
                                            loading: _cancellingEvent,
                                            onPressed:
                                                event.isPast || _cancellingEvent
                                                    ? null
                                                    : _cancelEvent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
      ),
    );
  }
}
