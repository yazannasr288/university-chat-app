import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../data/models/group_model.dart';
import '../../chat/pages/chat_page.dart';
import 'group_avatar.dart';

class GroupTile extends StatelessWidget {
  final String userName;
  final GroupModel group;
  final VoidCallback? onTogglePinned;

  const GroupTile({
    super.key,
    required this.userName,
    required this.group,
    this.onTogglePinned,
  });

  String subtitle(BuildContext context) {
    final recentMessage =
        context.locale.languageCode == 'en'
            ? group.recentMessageEn.trim()
            : group.recentMessage.trim();
    final fallback = group.recentMessage.trim();
    final localizedRecentMessage =
        recentMessage.isNotEmpty ? recentMessage : fallback;

    if (group.recentMessageSender.trim().isEmpty) {
      return localizedRecentMessage.isEmpty
          ? tr('chat.no_messages_yet')
          : localizedRecentMessage;
    }
    return '${group.recentMessageSender}: $localizedRecentMessage';
  }

  String _formatTime(BuildContext context, int timestamp) {
    if (timestamp <= 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final dayDifference =
        DateUtils.dateOnly(now).difference(DateUtils.dateOnly(date)).inDays;
    final locale = context.locale.toString();

    if (dayDifference == 0) {
      return DateFormat.Hm(locale).format(date);
    } else if (dayDifference == 1) {
      return tr('chat.yesterday');
    } else if (dayDifference > 1 && dayDifference < 7) {
      return DateFormat.EEEE(locale).format(date);
    } else {
      return DateFormat.yMd(locale).format(date);
    }
  }

  Widget _buildUnreadBadge(BuildContext context) {
    if (group.unreadCount <= 0) return const SizedBox.shrink();

    final label = group.unreadCount > 99 ? '99+' : group.unreadCount.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: AppDecorations.pill(
        color: AppColors.supportEmerald,
        boxShadow: [
          BoxShadow(
            color: AppColors.supportEmerald.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
            spreadRadius: -4,
          ),
        ],
      ),
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    final timeStr = _formatTime(context, group.recentMessageTime);

    return SizedBox(
      width: 70, // Fixed width to stabilize layout
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timeStr.isNotEmpty)
            Text(
              timeStr,
              maxLines: 1,
              style: context.textTheme.bodySmall?.copyWith(
                color:
                    group.unreadCount > 0
                        ? AppColors.supportEmerald
                        : context.appTextMuted,
                fontWeight: group.unreadCount > 0 ? FontWeight.w800 : null,
                fontSize: 11,
              ),
            ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (group.isPinned)
                Icon(
                  Icons.push_pin_rounded,
                  size: 15,
                  color: context.appPrimary,
                ),
              if (group.isPinned && (group.isMuted || group.unreadCount > 0))
                const SizedBox(width: 4),
              if (group.isMuted)
                Icon(
                  Icons.notifications_off_rounded,
                  size: 15,
                  color: context.appTextMuted,
                ),
              if (group.isMuted && group.unreadCount > 0)
                const SizedBox(width: 4),
              AnimatedSwitcher(
                duration: AppMotion.resolve(context, AppMotion.fast),
                switchInCurve: AppMotion.spring,
                switchOutCurve: AppMotion.exit,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: group.unreadCount > 0
                    ? KeyedSubtree(
                        key: ValueKey<int>(group.unreadCount),
                        child: _buildUnreadBadge(context),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey<String>('no-unread'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSurface.card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: EdgeInsets.zero,
      color: group.unreadCount > 0
          ? Color.alphaBlend(
              context.appPrimary.withValues(
                alpha: context.isDark ? 0.055 : 0.032,
              ),
              context.appCardColor,
            )
          : context.appCardColor,
      borderColor: group.unreadCount > 0
          ? Color.lerp(context.appBorder, context.appPrimary, 0.30)
          : context.appBorder,
      borderRadius: AppDecorations.radius(AppRadii.lg),
      boxShadow: context.isDark
          ? const []
          : group.unreadCount > 0
              ? AppShadows.card
              : AppShadows.subtle,
      child: ListTile(
        onLongPress: onTogglePinned,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => ChatPage(
                    userName: userName,
                    groupId: group.groupId,
                    groupName: group.groupName,
                    initialGroupIcon: group.groupIcon,
                  ),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Hero(
          tag: 'group-avatar-${group.groupId}',
          transitionOnUserGestures: true,
          createRectTween: (begin, end) {
            return MaterialRectCenterArcTween(begin: begin, end: end);
          },
          child: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: group.unreadCount > 0
                  ? AppGradients.gold
                  : AppGradients.primary,
              boxShadow: context.isDark ? const [] : AppShadows.subtle,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.appCardColorStrong,
              ),
              child: GroupAvatar(
                groupName: group.groupName,
                groupIcon: group.groupIcon,
                radius: 25,
              ),
            ),
          ),
        ),
        title: Text(
          group.groupName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.appTextSecondary,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTrailing(context),
            if (onTogglePinned != null)
              PopupMenuButton<String>(
                tooltip:
                    group.isPinned
                        ? 'home.unpin_group'.tr()
                        : 'home.pin_group'.tr(),
                onSelected: (_) => onTogglePinned?.call(),
                itemBuilder:
                    (_) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Row(
                          children: [
                            Icon(
                              group.isPinned
                                  ? Icons.push_pin_outlined
                                  : Icons.push_pin_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              group.isPinned
                                  ? 'home.unpin_group'.tr()
                                  : 'home.pin_group'.tr(),
                            ),
                          ],
                        ),
                      ),
                    ],
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: context.appTextMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
