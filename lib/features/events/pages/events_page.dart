import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_filter_chips.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_page_shell.dart';
import '../../../data/models/app_event.dart';
import '../controllers/events_controller.dart';
import '../widgets/event_card.dart';
import 'create_event_page.dart';
import 'event_details_page.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final controller = EventsController();
  bool showInterestedOnly = false;
  Stream<List<AppEvent>>? _eventsStream;
  Stream<Set<String>>? _interestedIdsStream;
  String? _busyInterestEventId;

  @override
  void initState() {
    super.initState();
    _handleInit();
  }

  Future<void> _handleInit() async {
    _eventsStream = null;
    _interestedIdsStream = null;

    final initFuture = controller.init();
    if (mounted) setState(() {});

    await initFuture;
    if (!mounted) return;

    setState(() {
      _eventsStream = controller.eventsStream();
      _interestedIdsStream = controller.interestedIdsStream();
    });
  }

  Future<void> _toggleInterest(String eventId) async {
    if (_busyInterestEventId != null) return;

    setState(() => _busyInterestEventId = eventId);
    final error = await controller.toggleInterest(eventId);
    if (!mounted) return;
    setState(() => _busyInterestEventId = null);

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    showAppSnackBar(
      context,
      tr('events.interest_updated'),
      type: SnackType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventsStream = _eventsStream;
    final interestedIdsStream = _interestedIdsStream;

    return AppPageShell(
      title: tr('events.title'),
      actions: [
        if (controller.canCreateAnyEvent)
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const CreateEventPage()),
              );
            },
          ),
      ],
      body: AppStateView(
        loading: controller.isLoading ||
            (controller.errorMessage == null &&
                (eventsStream == null || interestedIdsStream == null)),
        error: controller.errorMessage?.tr(),
        empty: false,
        emptyText: '',
        errorIcon: Icons.event_busy_rounded,
        onRetry: controller.errorMessage != null ? _handleInit : null,
        child: Column(
          children: [
            AppFilterChips<bool>(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              values: const [false, true],
              selected: showInterestedOnly,
              labelBuilder: (interestedOnly) => interestedOnly
                  ? tr('events.interested_filter')
                  : tr('events.all_filter'),
              onChanged: (interestedOnly) {
                setState(() => showInterestedOnly = interestedOnly);
              },
            ),
            Expanded(
              child: StreamBuilder<List<AppEvent>>(
                stream: eventsStream,
                builder: (context, eventsSnapshot) {
                  if (eventsSnapshot.hasError || !eventsSnapshot.hasData) {
                    return AppStateView(
                      loading: !eventsSnapshot.hasData && !eventsSnapshot.hasError,
                      error: eventsSnapshot.hasError ? tr('events.load_failed') : null,
                      empty: false,
                      emptyText: '',
                      errorIcon: Icons.event_busy_rounded,
                      onRetry: _handleInit,
                      child: const SizedBox.shrink(),
                    );
                  }

                  return StreamBuilder<Set<String>>(
                    stream: interestedIdsStream,
                    builder: (context, interestedSnapshot) {
                      if (interestedSnapshot.hasError) {
                        return AppStateView(
                          loading: false,
                          error: tr('events.interests_load_failed'),
                          empty: false,
                          emptyText: '',
                          errorIcon: Icons.favorite_border_rounded,
                          onRetry: _handleInit,
                          child: const SizedBox.shrink(),
                        );
                      }

                      final interestedIds =
                          interestedSnapshot.data ?? <String>{};

                      final events = eventsSnapshot.data!
                          .where((event) => !event.isCancelled)
                          .toList();

                      final filtered = showInterestedOnly
                          ? events
                          .where((event) => interestedIds.contains(event.id))
                          .toList()
                          : events;

                      return AppStateView(
                        loading: false,
                        error: null,
                        empty: filtered.isEmpty,
                        emptyIcon: Icons.event_note_rounded,
                        emptyText: showInterestedOnly
                            ? tr('events.empty_interested')
                            : tr('events.empty_available'),
                        child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, index) {
                          final AppEvent event = filtered[index];

                          return EventCard(
                            event: event,
                            isInterested: interestedIds.contains(event.id),
                            onToggleInterest: () => _toggleInterest(event.id),
                            interestLoading: _busyInterestEventId == event.id,
                            onTap: () {
                              final currentUser = controller.currentUser;
                              if (currentUser == null) {
                                showAppSnackBar(
                                  context,
                                  tr('events.no_signed_in_user'),
                                  type: SnackType.error,
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventDetailsPage(
                                    eventId: event.id,
                                    currentUid: currentUser.uid,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
