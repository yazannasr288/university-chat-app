import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../data/models/group_model.dart';
import '../../home/widgets/group_avatar.dart';

class GroupCard extends StatefulWidget {
  final GroupModel group;
  final Future<bool> Function() isJoinedLoader;
  final Future<String?> Function() onToggleJoin;
  final String adminName;

  const GroupCard({
    super.key,
    required this.group,
    required this.isJoinedLoader,
    required this.onToggleJoin,
    required this.adminName,
  });

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool isJoined = false;
  bool isBusy = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadJoinState();
  }

  @override
  void didUpdateWidget(covariant GroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.group.groupId != widget.group.groupId) {
      isJoined = false;
      isBusy = false;
      loading = true;
      _loadJoinState();
    }
  }

  Future<void> _loadJoinState() async {
    final joined = await widget.isJoinedLoader();
    if (!mounted) return;

    setState(() {
      isJoined = joined;
      loading = false;
    });
  }

  Future<void> _toggle() async {
    if (loading || isBusy) return;

    setState(() => isBusy = true);

    final error = await widget.onToggleJoin();
    if (!mounted) return;

    if (error != null) {
      showAppSnackBar(context, error, type: SnackType.error);
      setState(() => isBusy = false);
      return;
    }

    setState(() {
      isJoined = !isJoined;
      isBusy = false;
    });

    showAppSnackBar(
      context,
      isJoined ? 'search.join_success'.tr() : 'search.leave_success'.tr(),
      type: isJoined ? SnackType.success : SnackType.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppSurface.card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      padding: EdgeInsets.zero,
      color: context.appCardColorStrong,
      borderColor: context.appBorder,
      borderRadius: AppDecorations.radius(AppRadii.lg),
      boxShadow: context.isDark ? const [] : AppShadows.subtle,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: GroupAvatar(
          groupName: widget.group.groupName,
          groupIcon: widget.group.groupIcon,
          radius: 24,
          backgroundColor: context.isDark
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.primarySoft,
          textStyle: context.textTheme.titleSmall?.copyWith(
            color: context.isDark ? AppColors.accent : AppColors.primaryDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        title: Text(
          widget.group.groupName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.titleSmall?.copyWith(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          tr('search.admin_format', args: [widget.adminName]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.appTextSecondary,
          ),
        ),
        trailing: loading
            ? const AppLoader.inline(size: 18, strokeWidth: 2)
            : ElevatedButton(
          onPressed: isBusy ? null : _toggle,
          style: ElevatedButton.styleFrom(
            backgroundColor:
            isJoined ? AppColors.supportNavy : AppColors.primary,
            minimumSize: const Size(86, 42),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: isBusy
              ? const AppLoader.inline(
            size: 18,
            strokeWidth: 2,
            color: Colors.white,
          )
              : FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isJoined ? 'search.joined'.tr() : 'search.join_now'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
