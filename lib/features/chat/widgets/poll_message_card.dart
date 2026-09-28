import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../data/repositories/group_repository.dart';

class PollMessageCard extends StatefulWidget {
  final String groupId;
  final String messageId;
  final String currentUid;
  final String pollQuestion;
  final List<String> pollOptions;
  final int? pollExpiresAt;
  final bool pollIsClosed;
  final bool sendByMe;

  const PollMessageCard({
    super.key,
    required this.groupId,
    required this.messageId,
    required this.currentUid,
    required this.pollQuestion,
    required this.pollOptions,
    required this.pollExpiresAt,
    required this.pollIsClosed,
    required this.sendByMe,
  });

  @override
  State<PollMessageCard> createState() => _PollMessageCardState();
}

class _PollMessageCardState extends State<PollMessageCard> {
  final GroupRepository _groupRepository = GroupRepository();
  late Stream<QuerySnapshot<Map<String, dynamic>>> _votesStream;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _votesStream = _createVotesStream();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant PollMessageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pollExpiresAt != widget.pollExpiresAt ||
        oldWidget.pollIsClosed != widget.pollIsClosed) {
      _startTimer();
    }
    if (oldWidget.groupId != widget.groupId ||
        oldWidget.messageId != widget.messageId) {
      _votesStream = _createVotesStream();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();

    if (widget.pollIsClosed || widget.pollExpiresAt == null || _expired) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });

      if (_expired) {
        _timer?.cancel();
      }
    });
  }

  bool get _expired {
    final expiresAt = widget.pollExpiresAt;
    if (expiresAt == null) return false;
    return _now.millisecondsSinceEpoch >= expiresAt;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _createVotesStream() {
    return _groupRepository.pollVotesStream(
      groupId: widget.groupId,
      messageId: widget.messageId,
    );
  }

  String get _remainingText {
    final expiresAt = widget.pollExpiresAt;
    if (expiresAt == null) return tr('chat.no_expiry_time');
    final diff = DateTime.fromMillisecondsSinceEpoch(
      expiresAt,
    ).difference(_now);

    if (diff.isNegative || diff.inSeconds <= 0) {
      return tr('chat.poll_ended');
    }

    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);

    if (days > 0) {
      return tr(
        'chat.remaining_value_day_s_value_hour_s',
        args: ['$days', '$hours'],
      );
    }
    if (hours > 0) {
      return tr(
        'chat.remaining_value_hour_s_value_minute_s',
        args: ['$hours', '$minutes'],
      );
    }
    if (minutes > 0) {
      return tr(
        'chat.remaining_value_minute_s_value_second_s',
        args: ['$minutes', '$seconds'],
      );
    }
    return tr('chat.remaining_value_second_s', args: ['$seconds']);
  }

  Future<void> _vote(int optionIndex) async {
    if (_expired || widget.pollIsClosed) return;

    try {
      await _groupRepository.sendPollVote(
        groupId: widget.groupId,
        messageId: widget.messageId,
        uid: widget.currentUid,
        optionIndex: optionIndex,
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'chat.unable_submit_vote_right'.tr(),
        type: SnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = widget.pollIsClosed || _expired;
    final cardColor =
        widget.sendByMe ? context.appMessageMineAlpha : context.appBubbleOther;
    final borderColor =
        widget.sendByMe
            ? context.appMessageMineBorder
            : context.appBubbleOtherBorder;
    final titleColor = widget.sendByMe ? Colors.white : context.appTextPrimary;
    final secondaryTextColor =
        widget.sendByMe ? Colors.white70 : context.appTextSecondary;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _votesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: AppDecorations.rounded(
              color: cardColor,
              borderColor: borderColor,
            ),
            child: Text(
              'chat.could_not_load_votes_right'.tr(),
              style: context.textTheme.bodyMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? const [];
        final votes = docs.map((e) => e.data()).toList();

        final Map<int, int> counts = {};
        for (int i = 0; i < widget.pollOptions.length; i++) {
          counts[i] = 0;
        }

        int? selectedIndex;
        for (final vote in votes) {
          final index = vote['optionIndex'];
          final uid = vote['uid'];
          if (index is int && counts.containsKey(index)) {
            counts[index] = (counts[index] ?? 0) + 1;
          }
          if (uid == widget.currentUid && index is int) {
            selectedIndex = index;
          }
        }

        final totalVotes = votes.length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: AppDecorations.rounded(
            color: cardColor,
            borderColor: borderColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.accent.withValues(
                      alpha: context.isDark ? 0.20 : 0.15,
                    ),
                    child: const Icon(
                      Icons.poll_rounded,
                      size: 18,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.pollQuestion,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.titleSmall?.copyWith(
                        fontSize: 16,
                        color: titleColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _remainingText,
                style: context.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isClosed ? context.scheme.error : secondaryTextColor,
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < widget.pollOptions.length; i++) ...[
                _PollOptionTile(
                  text: widget.pollOptions[i],
                  votes: counts[i] ?? 0,
                  totalVotes: totalVotes,
                  selected: selectedIndex == i,
                  sendByMe: widget.sendByMe,
                  disabled: isClosed,
                  onTap: () => _vote(i),
                ),
                if (i != widget.pollOptions.length - 1)
                  const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              Text(
                tr('chat.total_voters_value', args: ['$totalVotes']),
                style: context.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PollOptionTile extends StatelessWidget {
  final String text;
  final int votes;
  final int totalVotes;
  final bool selected;
  final bool sendByMe;
  final bool disabled;
  final VoidCallback onTap;

  const _PollOptionTile({
    required this.text,
    required this.votes,
    required this.totalVotes,
    required this.selected,
    required this.sendByMe,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percent = totalVotes == 0 ? 0.0 : votes / totalVotes;
    final selectedColor = context.scheme.secondary;
    final tileColor =
        selected
            ? selectedColor.withValues(alpha: context.isDark ? 0.18 : 0.15)
            : (sendByMe
                ? context.appMessageMineAlpha.withValues(alpha: 0.08)
                : context.appSurfaceSoft);
    final tileBorderColor =
        selected
            ? selectedColor
            : (sendByMe ? context.appMessageMineBorder : context.appBorder);
    final textColor = sendByMe ? Colors.white : context.appTextPrimary;
    final metaColor = sendByMe ? Colors.white70 : context.appTextSecondary;
    final progressBackground =
        sendByMe ? context.appMessageMineAlpha : context.appSurfaceAlt;
    final progressColor = sendByMe ? Colors.white : selectedColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: AppDecorations.rounded(
            color: tileColor,
            radius: AppRadii.sm,
            borderColor: tileBorderColor,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      text,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$votes',
                    style: context.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: metaColor,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: selectedColor,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: LinearProgressIndicator(
                  value: percent,
                  minHeight: 8,
                  backgroundColor: progressBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
