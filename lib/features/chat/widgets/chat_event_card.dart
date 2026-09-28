import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../data/models/app_event.dart';
import '../../../data/repositories/event_repository.dart';
import '../../events/pages/event_details_page.dart';

class ChatEventCard extends StatefulWidget {
  final String eventId;
  final String currentUid;
  final bool sendByMe;

  const ChatEventCard({
    super.key,
    required this.eventId,
    required this.currentUid,
    required this.sendByMe,
  });

  @override
  State<ChatEventCard> createState() => _ChatEventCardState();
}

class _ChatEventCardState extends State<ChatEventCard> {
  final EventRepository _repository = EventRepository();
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _eventStream;

  @override
  void initState() {
    super.initState();
    _eventStream = _repository.watchEventById(widget.eventId);
  }

  @override
  void didUpdateWidget(covariant ChatEventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) {
      _eventStream = _repository.watchEventById(widget.eventId);
    }
  }

  String _scopeLabel(String scopeType) {
    switch (scopeType) {
      case 'university':
        return 'events.scope_university'.tr();
      case 'department':
        return 'events.scope_department'.tr();
      case 'group':
        return 'events.scope_group'.tr();
      default:
        return 'events.scope_event'.tr();
    }
  }

  String _formatDate(int eventAt) {
    final date = DateTime.fromMillisecondsSinceEpoch(eventAt);
    return DateFormat('yyyy/MM/dd - HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final sendByMe = widget.sendByMe;
    final currentUid = widget.currentUid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _eventStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _EventBubbleSurface(
            sendByMe: sendByMe,
            width: 240,
            child: _EventStateText(
              sendByMe: sendByMe,
              text: 'chat.could_not_load_event_card'.tr(),
            ),
          );
        }

        if (!snapshot.hasData) {
          return _EventBubbleSurface(
            sendByMe: sendByMe,
            width: 240,
            showBorder: false,
            child: const Center(
              child: AppLoader.inline(size: 22, strokeWidth: 2),
            ),
          );
        }

        final doc = snapshot.data!;
        if (!doc.exists || doc.data() == null) {
          return _EventBubbleSurface(
            sendByMe: sendByMe,
            width: 240,
            showBorder: false,
            child: _EventStateText(
              sendByMe: sendByMe,
              text: 'events.event_not_found'.tr(),
            ),
          );
        }

        final event = AppEvent.fromMap(doc.id, doc.data()!);

        return _EventBubbleSurface(
          sendByMe: sendByMe,
          width: 220,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => EventDetailsPage(
                      eventId: event.id,
                      currentUid: currentUid,
                    ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppIconBadge(
                    icon: Icons.event_note_rounded,
                    size: 42,
                    iconSize: 22,
                    color: context.appPrimary,
                    backgroundColor: context.appPrimary.withValues(alpha: 0.15),
                    borderRadius: AppDecorations.radius(AppRadii.sm),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleSmall?.copyWith(
                        color: sendByMe ? Colors.white : context.appTextPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _scopeLabel(event.scopeType),
                style: context.textTheme.bodySmall?.copyWith(
                  color: sendByMe ? Colors.white70 : context.appPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(event.eventAt),
                style: context.textTheme.bodySmall?.copyWith(
                  color: sendByMe ? Colors.white70 : context.appTextSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                event.location,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: sendByMe ? Colors.white70 : context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              AppStatusChip(
                label:
                    event.isCancelled
                        ? 'events.event_has_been_cancelled'.tr()
                        : 'chat.view_event'.tr(),
                color: sendByMe ? Colors.white : context.appPrimary,
                backgroundColor:
                    sendByMe
                        ? context.appMessageMineAlpha
                        : context.appPrimary.withValues(alpha: 0.12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                showBorder: false,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EventBubbleSurface extends StatelessWidget {
  final bool sendByMe;
  final Widget child;
  final double width;
  final bool showBorder;
  final VoidCallback? onTap;

  const _EventBubbleSurface({
    required this.sendByMe,
    required this.child,
    required this.width,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      width: width,
      padding: const EdgeInsets.all(14),
      color: sendByMe ? context.appMessageMineAlpha : context.appSurfaceSoft,
      borderColor:
          showBorder
              ? (sendByMe ? context.appMessageMineBorder : context.appBorder)
              : Colors.transparent,
      borderWidth: showBorder ? 1 : 0,
      borderRadius: AppDecorations.radius(AppRadii.md),
      onTap: onTap,
      child: child,
    );
  }
}

class _EventStateText extends StatelessWidget {
  final bool sendByMe;
  final String text;

  const _EventStateText({required this.sendByMe, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: context.textTheme.bodyMedium?.copyWith(
        color: sendByMe ? Colors.white : context.appTextPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
