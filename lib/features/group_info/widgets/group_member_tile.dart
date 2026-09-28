import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../core/widgets/user_avatar.dart';

class GroupMemberTile extends StatelessWidget {
  final String memberName;
  final String subtitle;
  final String profilepic;
  final bool canKick;
  final VoidCallback? onKick;

  const GroupMemberTile({
    super.key,
    required this.memberName,
    required this.subtitle,
    this.profilepic = '',
    required this.canKick,
    this.onKick,
  });

  @override
  Widget build(BuildContext context) {
    final avatarBackground =
        context.isDark ? context.appSurfaceSoft : AppColors.primarySoft;
    final avatarTextColor =
        context.isDark ? AppColors.accent : AppColors.primaryDark;

    return AppSurface.card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),
      padding: EdgeInsets.zero,
      color: context.appCardColor,
      borderColor: context.appBorder,
      borderRadius: AppDecorations.radius(AppRadii.lg),
      child: ListTile(
        leading: UserAvatar(
          imageValue: profilepic,
          displayName: memberName,
          radius: 20,
          backgroundColor: avatarBackground,
          foregroundColor: avatarTextColor,
        ),
        title: Text(
          memberName,
          style: context.textTheme.titleSmall?.copyWith(
            color: context.appTextPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.appTextSecondary,
          ),
        ),
        trailing: canKick
            ? IconButton(
                icon: const Icon(
                  Icons.remove_circle_rounded,
                  color: AppColors.error,
                ),
                onPressed: onKick,
              )
            : null,
      ),
    );
  }
}
