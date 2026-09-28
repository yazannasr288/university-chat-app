import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_localization.dart';
import '../../../core/permissions/app_role_permissions.dart';
import '../../../core/storage/app_prefs.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_icon_badge.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../core/widgets/user_avatar.dart';
import 'home_drawer_item.dart';

class HomeDrawer extends StatelessWidget {
  final String userName;
  final String role;
  final String accountType;
  final String profilepic;
  final VoidCallback onGroups;
  final VoidCallback onProfile;
  final VoidCallback onArchive;
  final VoidCallback onEvents;
  final VoidCallback onSavedMessages;
  final VoidCallback onDownloads;
  final VoidCallback onGpaCalculator;
  final VoidCallback onOpenPortal;
  final VoidCallback onRegister;
  final VoidCallback onLogout;
  final VoidCallback onLanguage;
  final VoidCallback onDashboard;
  final VoidCallback onNotifications;
  final VoidCallback onBilling;

  const HomeDrawer({
    super.key,
    required this.onBilling,
    required this.userName,
    required this.role,
    this.accountType = '',
    this.profilepic = '',
    required this.onGroups,
    required this.onProfile,
    required this.onArchive,
    required this.onEvents,
    required this.onSavedMessages,
    required this.onDownloads,
    required this.onGpaCalculator,
    required this.onOpenPortal,
    required this.onRegister,
    required this.onLogout,
    required this.onLanguage,
    required this.onDashboard,
    required this.onNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
            decoration: const BoxDecoration(
              gradient: AppGradients.brand,
              border: Border(
                bottom: BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
            child: Column(
              children: [
                AppIconBadge.circle(
                  icon: Icons.person_rounded,
                  size: 86,
                  iconSize: 64,
                  color: Colors.white,
                  backgroundColor: context.appMessageMineAlpha,
                  borderColor: context.appMessageMineBorder,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 24,
                      offset: Offset(0, 10),
                      spreadRadius: -6,
                    ),
                  ],
                  child: ClipOval(
                    child: UserAvatar(
                      imageValue:
                          profilepic.trim().isNotEmpty
                              ? profilepic
                              : AppPrefs.userProfilePic,
                      displayName: userName,
                      radius: 43,
                      backgroundColor: context.appMessageMineAlpha,
                      foregroundColor: Colors.white,
                      fallbackIconSize: 64,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  userName,
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                AppStatusChip(
                  label: localizedRoleLabel(role, accountType: accountType),
                  color: Colors.white,
                  backgroundColor: context.appMessageMineAlpha,
                  showBorder: false,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 14),
              children: [
                HomeDrawerItem(
                  icon: Icons.groups_rounded,
                  title: 'home.groups'.tr(),
                  onTap: onGroups,
                ),
                HomeDrawerItem(
                  icon: Icons.event_note_rounded,
                  title: 'events.title'.tr(),
                  onTap: onEvents,
                ),
                HomeDrawerItem(
                  icon: Icons.bookmark_rounded,
                  title: 'saved_messages.title'.tr(),
                  onTap: onSavedMessages,
                ),
                HomeDrawerItem(
                  icon: Icons.download_done_rounded,
                  title: 'downloads.title'.tr(),
                  onTap: onDownloads,
                ),
                HomeDrawerItem(
                  icon: Icons.calculate_rounded,
                  title: 'gpa.title'.tr(),
                  onTap: onGpaCalculator,
                ),
                HomeDrawerItem(
                  icon: Icons.person_rounded,
                  title: 'profile.title'.tr(),
                  onTap: onProfile,
                ),
                if (AppRolePermissions.isNotificationSenderRole(role))
                  HomeDrawerItem(
                    icon: Icons.archive_outlined,
                    title: 'archive.title'.tr(),
                    onTap: onArchive,
                  ),
                HomeDrawerItem(
                  icon: Icons.language_rounded,
                  title: 'common.language.title'.tr(),
                  onTap: onLanguage,
                ),
                HomeDrawerItem(
                  icon: Icons.language_rounded,
                  title: 'web.portal'.tr(),
                  onTap: onOpenPortal,
                ),
                if (AppRolePermissions.isSystemAdminRole(role))
                  HomeDrawerItem(
                    icon: Icons.receipt_long_rounded,
                    title: tr('dashboard.monthly_billing'),
                    onTap: onBilling,
                  ),
                if (AppRolePermissions.isNotificationSenderRole(role))
                  HomeDrawerItem(
                    icon: Icons.notifications_active_rounded,
                    title: 'notifications.title'.tr(),
                    onTap: onNotifications,
                  ),
                if (AppRolePermissions.isSystemAdminRole(role))
                  HomeDrawerItem(
                    icon: Icons.app_registration_rounded,
                    title: 'home.add_user'.tr(),
                    onTap: onRegister,
                  ),
                if (AppRolePermissions.isDashboardRole(role))
                  HomeDrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'dashboard.title'.tr(),
                    onTap: onDashboard,
                  ),
                HomeDrawerItem(
                  icon: Icons.logout_rounded,
                  title: 'auth.logout'.tr(),
                  onTap: onLogout,
                  color: AppColors.error,
                ),
              ],
            ),
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppPrefs.themeModeNotifier,
            builder: (_, themeMode, _) {
              final isDark = themeMode == ThemeMode.dark;

              return AppSurface.card(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                padding: EdgeInsets.zero,
                color: context.appCardColor,
                borderRadius: AppDecorations.radius(AppRadii.lg),
                boxShadow: AppShadows.subtle,
                child: SwitchListTile.adaptive(
                  value: isDark,
                  onChanged: AppPrefs.toggleTheme,
                  secondary: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: context.appPrimary,
                  ),
                  title: Text(
                    'home.dark_mode'.tr(),
                    style: context.textTheme.titleSmall?.copyWith(
                      color: context.appTextPrimary,
                    ),
                  ),
                  subtitle: Text(
                    isDark ? 'home.enabled'.tr() : 'home.disabled'.tr(),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.appTextSecondary,
                    ),
                  ),
                  activeThumbColor: AppColors.accent,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
