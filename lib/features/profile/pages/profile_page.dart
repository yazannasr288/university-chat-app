import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_departments.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/app_user.dart';
import '../../auth/pages/change_password_page.dart';
import '../../pin/pages/change_pin_page.dart';
import '../controllers/profile_controller.dart';
import '../widgets/profile_action_tile.dart';
import '../widgets/profile_info_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

enum _ProfileImageAction { camera, gallery, delete }

class _ProfilePageState extends State<ProfilePage> {
  final controller = ProfileController();

  @override
  void initState() {
    super.initState();
    _handleInit();
  }

  Future<void> _handleInit() async {
    final loadFuture = controller.loadProfile();
    setState(() {});
    await loadFuture;
    if (!mounted) return;
    setState(() {});
  }

  void _openChangePin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePinPage()),
    );
  }

  void _openChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
    );
  }

  Future<void> _openProfileImageActions() async {
    final hasImage = controller.user?.profilepic.trim().isNotEmpty ?? false;

    final action = await showModalBottomSheet<_ProfileImageAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: AppSurface.card(
            margin: const EdgeInsets.all(AppSpacing.md),
            color: context.appCardColor,
            borderRadius: AppDecorations.radius(AppRadii.xl),
            boxShadow: AppShadows.card,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  leading: Icon(
                    Icons.photo_camera_rounded,
                    color: context.appPrimary,
                  ),
                  title: Text(tr('profile.take_photo_camera')),
                  onTap: () {
                    Navigator.pop(context, _ProfileImageAction.camera);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_rounded,
                    color: context.appPrimary,
                  ),
                  title: Text(tr('profile.choose_photo_gallery')),
                  onTap: () {
                    Navigator.pop(context, _ProfileImageAction.gallery);
                  },
                ),
                if (hasImage) ...[
                  Divider(height: 1, color: context.appBorder),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    title: Text(tr('profile.delete_photo')),
                    subtitle: Text(tr('profile.delete_photo_subtitle')),
                    onTap: () {
                      Navigator.pop(context, _ProfileImageAction.delete);
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    switch (action) {
      case _ProfileImageAction.camera:
        await _pickAndUploadProfileImage(ImageSource.camera);
        break;
      case _ProfileImageAction.gallery:
        await _pickAndUploadProfileImage(ImageSource.gallery);
        break;
      case _ProfileImageAction.delete:
        await _deleteProfileImage();
        break;
    }
  }

  Future<void> _pickAndUploadProfileImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (picked == null) return;

      setState(() => controller.isUploadingProfileImage = true);
      final error = await controller.updateProfileImage(
        file: File(picked.path),
        fileName: picked.name,
      );

      if (!mounted) return;
      setState(() {});

      if (error != null) {
        showAppSnackBar(context, error, type: SnackType.error);
        return;
      }

      showAppSnackBar(
        context,
        tr('profile.photo_updated'),
        type: SnackType.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {});
      showAppSnackBar(
        context,
        tr('profile.photo_update_failed'),
        type: SnackType.error,
      );
    }
  }

  Future<void> _deleteProfileImage() async {
    if (controller.user?.profilepic.trim().isEmpty ?? true) return;

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: tr('profile.delete_photo'),
      message: tr('profile.delete_photo_confirm_message'),
      cancelText: 'common.cancel'.tr(),
      confirmText: 'common.delete'.tr(),
      confirmColor: AppColors.error,
    );

    if (!confirmed || !mounted) return;

    setState(() => controller.isDeletingProfileImage = true);
    final error = await controller.deleteProfileImage();

    if (!mounted) return;
    setState(() {});

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      return;
    }

    showAppSnackBar(
      context,
      tr('profile.photo_deleted'),
      type: SnackType.success,
    );
  }

  Widget _buildProfileAvatar(AppUser user) {
    return Semantics(
      button: true,
      label: tr('profile.change_or_delete_photo'),
      child: GestureDetector(
        onTap:
            controller.isUploadingProfileImage ||
                    controller.isDeletingProfileImage
                ? null
                : _openProfileImageActions,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AppIconBadge.circle(
              icon: Icons.person_rounded,
              size: 112,
              iconSize: 72,
              gradient: AppGradients.primary,
              color: Colors.white,
              child: ClipOval(
                child: UserAvatar(
                  imageValue: user.profilepic,
                  displayName: user.fullName,
                  radius: 56,
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  fallbackIconSize: 72,
                  fallbackTextStyle: context.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              bottom: 0,
              end: 0,
              child: AppIconBadge.circle(
                icon: Icons.camera_alt_rounded,
                size: 34,
                iconSize: 18,
                color: context.appPrimary,
                backgroundColor: context.appCardColor,
                borderColor: context.appBorder,
                boxShadow: AppShadows.subtle,
                child: controller.isUploadingProfileImage ||
                        controller.isDeletingProfileImage
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading || controller.errorMessage != null || controller.user == null) {
      return AppPageShell(
        title: 'profile.title'.tr(),
        body: AppStateView(
          loading: controller.isLoading,
          error: controller.errorMessage ??
              (controller.user == null
                  ? 'profile.account_data_was_not_found'.tr()
                  : null),
          empty: false,
          emptyText: '',
          errorIcon: Icons.person_off_rounded,
          onRetry: _handleInit,
          child: const SizedBox.shrink(),
        ),
      );
    }

    final user = controller.user!;

    return AppPageShell(
      title: 'profile.title'.tr(),
      body: AppScrollableBody.column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
              _buildProfileAvatar(user),
              const SizedBox(height: AppSpacing.lg),
              Text(
                user.fullName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.textTheme.headlineSmall?.copyWith(fontSize: 24),
              ),
              const SizedBox(height: AppSpacing.xl),
              ProfileInfoCard(
                icon: Icons.person_rounded,
                title: 'common.full_name'.tr(),
                value: user.fullName,
              ),
              ProfileInfoCard(
                icon: Icons.badge_rounded,
                title: 'common.student_id'.tr(),
                value: user.userId,
              ),
              ProfileInfoCard(
                icon: Icons.phone_rounded,
                title: 'common.phone'.tr(),
                value: user.phone,
              ),
              ProfileInfoCard(
                icon: Icons.school_rounded,
                title: 'common.department'.tr(),
                value: tr(AppDepartments.labelKey(user.department)),
              ),
              ProfileInfoCard(
                icon: Icons.security_rounded,
                title: 'common.role'.tr(),
                value: localizedRoleLabel(
                  user.role,
                  accountType: user.accountType,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ProfileActionTile(
                icon: Icons.pin_rounded,
                title: 'pin.change_pin'.tr(),
                subtitle: 'profile.requires_entering_old_pin'.tr(),
                onTap: _openChangePin,
              ),
              ProfileActionTile(
                icon: Icons.lock_reset_rounded,
                title: 'profile.change_password'.tr(),
                subtitle: 'profile.requires_entering_old_password'.tr(),
                onTap: _openChangePassword,
              ),
        ],
      ),
    );
  }
}
