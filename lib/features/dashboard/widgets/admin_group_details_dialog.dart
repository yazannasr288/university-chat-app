import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_departments.dart';
import '../../../core/constants/app_group_write_permissions.dart';
import '../../../core/constants/app_group_audiences.dart';
import '../../../core/localization/app_localization.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_confirm_dialog.dart';
import '../../../core/widgets/app_dropdown_field.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../core/widgets/app_status_chip.dart';
import '../../../core/widgets/app_surface.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controllers/admin_group_details_controller.dart';
import 'add_group_members_dialog.dart';

class AdminGroupDetailsDialog extends StatefulWidget {
  final String groupId;
  final Future<void> Function() onSaved;
  final Future<void> Function() onDeleted;
  final String currentRole;
  final String currentDepartment;

  const AdminGroupDetailsDialog({
    super.key,
    required this.groupId,
    required this.onSaved,
    required this.onDeleted,
    required this.currentRole,
    required this.currentDepartment,
  });

  @override
  State<AdminGroupDetailsDialog> createState() =>
      _AdminGroupDetailsDialogState();
}

class _AdminGroupDetailsDialogState extends State<AdminGroupDetailsDialog> {
  late final AdminGroupDetailsController controller;

  @override
  void initState() {
    controller = AdminGroupDetailsController(
      currentRole: widget.currentRole,
      currentDepartment: widget.currentDepartment,
    );
    super.initState();
    _load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loadFuture = controller.load(widget.groupId);
    setState(() {});
    final error = await loadFuture;
    if (!mounted) return;
    setState(() {});
    if (error != null) {
      showAppSnackBar(context, tr(error), type: SnackType.error);
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    final saveFuture = controller.save();
    setState(() {});
    final error = await saveFuture;
    if (!mounted) return;
    setState(() {});

    if (error != null) {
      final message = error.startsWith('dashboard.') ? tr(error) : error;
      showAppSnackBar(context, message, type: SnackType.error);
      return;
    }

    await widget.onSaved();
    if (!mounted) return;
    showAppSnackBar(
      context,
      tr('dashboard.group_saved_success'),
      type: SnackType.success,
    );
    Navigator.pop(context);
  }

  Future<void> _addMembers() async {
    final selected = await showDialog<List<String>>(
      context: context,
      builder:
          (_) => AddGroupMembersDialog(
            existingUserIds:
                controller.details?.members.map((e) => e.uid).toSet() ??
                const <String>{},
            onSearch: controller.searchCandidateMembers,
          ),
    );

    if (selected == null || selected.isEmpty) return;

    final addMembersFuture = controller.addMembers(selected);
    setState(() {});
    final error = await addMembersFuture;
    if (!mounted) return;
    setState(() {});

    if (error != null) {
      final message = error.startsWith('dashboard.') ? tr(error) : error;
      showAppSnackBar(context, message, type: SnackType.error);
      return;
    }

    await widget.onSaved();
    if (!mounted) return;
    showAppSnackBar(
      context,
      tr('dashboard.group_members_added_success'),
      type: SnackType.success,
    );
  }

  Future<void> _removeMember(String memberUid) async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: tr('dashboard.group_remove_member_title'),
      message: tr('dashboard.group_remove_member_body'),
      cancelText: tr('common.cancel'),
      confirmText: tr('dashboard.group_remove_member'),
    );

    if (!confirm) return;

    final removeMemberFuture = controller.removeMember(memberUid);
    setState(() {});
    final error = await removeMemberFuture;
    if (!mounted) return;
    setState(() {});

    if (error != null) {
      final message = error.startsWith('dashboard.') ? tr(error) : error;
      showAppSnackBar(context, message, type: SnackType.error);
      return;
    }

    await widget.onSaved();
    if (!mounted) return;
    showAppSnackBar(
      context,
      tr('dashboard.group_member_removed_success'),
      type: SnackType.success,
    );
  }

  Future<void> _toggleArchive() async {
    final wasActive = controller.details?.isActive == true;
    final toggleFuture =
        wasActive ? controller.archiveGroup() : controller.unarchiveGroup();
    setState(() {});
    final error = await toggleFuture;
    if (!mounted) return;
    setState(() {});

    if (error != null) {
      final message = error.startsWith('dashboard.') ? tr(error) : error;
      showAppSnackBar(context, message, type: SnackType.error);
      return;
    }

    await widget.onSaved();
    if (!mounted) return;
    showAppSnackBar(
      context,
      wasActive
          ? tr('dashboard.group_archive_success')
          : tr('dashboard.group_unarchive_success'),
      type: SnackType.success,
    );
  }

  Future<void> _deleteGroup() async {
    final confirm = await showAppConfirmDialog(
      context: context,
      title: tr('dashboard.group_delete_title'),
      message: tr('dashboard.group_delete_body'),
      cancelText: tr('common.cancel'),
      confirmText: tr('dashboard.group_delete'),
    );

    if (!confirm) return;

    final deleteFuture = controller.deleteGroup();
    setState(() {});
    final error = await deleteFuture;
    if (!mounted) return;
    setState(() {});

    if (error != null) {
      final message = error.startsWith('dashboard.') ? tr(error) : error;
      showAppSnackBar(context, message, type: SnackType.error);
      return;
    }

    await widget.onDeleted();
    if (!mounted) return;
    showAppSnackBar(
      context,
      tr('dashboard.group_delete_success'),
      type: SnackType.success,
    );
    Navigator.pop(context);
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> values,
    required ValueChanged<String?> onChanged,
    required String Function(String value) labelBuilder,
  }) {
    return AppDropdownField<String>(
      value: value,
      fallbackValue: values.isEmpty ? null : values.first,
      label: label,
      options:
          values
              .map(
                (item) => AppDropdownOption<String>(
                  value: item,
                  label: labelBuilder(item),
                ),
              )
              .toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = controller.details;
    final bool isInitialLoading = controller.isInitialLoading;
    final bool isBusy =
        controller.isSaving ||
        controller.isMemberActionLoading ||
        controller.isArchiving ||
        controller.isDeleting;

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: AppSurface.card(
        width: 860,
        padding: const EdgeInsets.all(AppSpacing.lg),
        color: context.appCardColorStrong,
        borderRadius: AppDecorations.radius(AppRadii.xl),
        child:
            isInitialLoading && details == null
                ? const SizedBox(height: 260, child: Center(child: AppLoader()))
                : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr('dashboard.group_details'),
                              style: context.textTheme.titleLarge?.copyWith(
                                color: context.appTextPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          AppStatusChip(
                            label: details?.isActive == true
                                ? tr('dashboard.group_status_active')
                                : tr('dashboard.group_status_archived'),
                            color: details?.isActive == true
                                ? AppColors.success
                                : AppColors.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: controller.groupNameController,
                        label: tr('dashboard.group_name'),
                        hint: tr('dashboard.group_name_hint'),
                        icon: Icons.groups_rounded,
                        maxLength: 50,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: tr('home.group_audience'),
                          prefixIcon: const Icon(Icons.visibility_rounded),
                        ),
                        child: Text(
                          tr(
                            AppGroupAudiences.labelKey(
                              details?.audience ??
                                  AppGroupAudiences.department,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _dropdownField(
                        label: tr('dashboard.filter_department'),
                        value: controller.department,
                        values: controller.departments,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => controller.department = value);
                          }
                        },
                        labelBuilder:
                            (value) => tr(AppDepartments.labelKey(value)),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _dropdownField(
                        label: tr('dashboard.group_write_permission'),
                        value: controller.writePermission,
                        values: AppGroupWritePermissions.values,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => controller.writePermission = value);
                          }
                        },
                        labelBuilder:
                            (value) =>
                                tr(AppGroupWritePermissions.labelKey(value)),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppSurface.soft(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        color: context.appSurfaceSoft,
                        borderRadius: AppDecorations.radius(AppRadii.lg),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 420;

                            final summary = Text(
                              tr(
                                'dashboard.group_members_summary',
                                args: ['${details?.members.length ?? 0}'],
                              ),
                              style: context.textTheme.titleSmall?.copyWith(
                                color: context.appTextPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            );

                            final addButton = OutlinedButton.icon(
                              onPressed: isBusy ? null : _addMembers,
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: Text(tr('dashboard.group_add_members')),
                            );

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  summary,
                                  const SizedBox(height: AppSpacing.sm),
                                  addButton,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: summary),
                                const SizedBox(width: AppSpacing.sm),
                                Flexible(child: addButton),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppSurface.soft(
                        padding: EdgeInsets.zero,
                        color: context.appSurfaceSoft,
                        borderRadius: AppDecorations.radius(AppRadii.lg),
                        child: Column(
                          children: [
                            for (final member in details?.members ?? const [])
                              ListTile(
                                dense: true,
                                minLeadingWidth: 40,
                                horizontalTitleGap: 10,
                                contentPadding:
                                    const EdgeInsetsDirectional.fromSTEB(
                                      12,
                                      6,
                                      8,
                                      6,
                                    ),
                                leading: CircleAvatar(
                                  radius: 19,
                                  backgroundColor:
                                      controller.adminIds.contains(member.uid)
                                          ? AppColors.primary.withValues(
                                            alpha: 0.14,
                                          )
                                          : context.appCardColor,
                                  child: Text(
                                    member.fullName.trim().isNotEmpty
                                        ? member.fullName.trim()[0]
                                        : '?',
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: context.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Tooltip(
                                        message: member.fullName,
                                        waitDuration: const Duration(
                                          milliseconds: 500,
                                        ),
                                        child: Text(
                                          member.fullName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          softWrap: false,
                                          style: context.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: context.appTextPrimary,
                                                fontWeight: FontWeight.w800,
                                                height: 1.15,
                                              ),
                                        ),
                                      ),
                                    ),
                                    if (member.uid == controller.adminUid) ...[
                                      const SizedBox(width: 6),
                                      Flexible(
                                        flex: 0,
                                        child: AppStatusChip(
                                          label: 'مدير أساسي',
                                          color: AppColors.accent,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        localizedRoleLabel(
                                          member.role,
                                          accountType: member.accountType,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: context.textTheme.bodySmall
                                            ?.copyWith(
                                              color: context.appTextSecondary,
                                              height: 1.4,
                                            ),
                                      ),
                                      Text(
                                        '${member.department}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: context.textTheme.bodySmall
                                            ?.copyWith(
                                              color: context.appTextSecondary,
                                              height: 1.4,
                                            ),
                                      ),
                                      Text(
                                        '${member.userId}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: false,
                                        style: context.textTheme.bodySmall
                                            ?.copyWith(
                                              color: context.appTextSecondary,
                                              height: 1.4,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: SizedBox(
                                  width: 92,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 40,
                                          minHeight: 40,
                                        ),
                                        onPressed:
                                            isBusy
                                                ? null
                                                : () {
                                                  setState(() {
                                                    if (controller.adminIds
                                                        .contains(member.uid)) {
                                                      // The primary admin cannot be demoted here.
                                                      if (member.uid ==
                                                          controller.adminUid) {
                                                        showAppSnackBar(
                                                          context,
                                                          'لا يمكن إزالة رتبة الأدمن من المدير الأساسي. '
                                                              'اختر مديراً أساسياً آخر أولاً.',
                                                        );
                                                        return;
                                                      }
                                                      controller.adminIds
                                                          .remove(member.uid);
                                                    } else {
                                                      controller.adminIds.add(
                                                        member.uid,
                                                      );
                                                    }
                                                  });
                                                },
                                        icon: Icon(
                                          controller.adminIds.contains(
                                                member.uid,
                                              )
                                              ? Icons.shield_rounded
                                              : Icons.shield_outlined,
                                          color:
                                              controller.adminIds.contains(
                                                    member.uid,
                                                  )
                                                  ? AppColors.primary
                                                  : context.appTextMuted,
                                        ),
                                        tooltip:
                                            controller.adminIds.contains(
                                                  member.uid,
                                                )
                                                ? 'إزالة كأدمن'
                                                : 'إضافة كأدمن',
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(
                                          Icons.more_vert_rounded,
                                        ),
                                        iconSize: 22,
                                        padding: EdgeInsets.zero,
                                        tooltip: 'المزيد',
                                        onSelected: (value) {
                                          if (value == 'make_primary') {
                                            setState(() {
                                              controller.adminUid = member.uid;
                                              if (!controller.adminIds.contains(
                                                member.uid,
                                              )) {
                                                controller.adminIds.add(
                                                  member.uid,
                                                );
                                              }
                                            });
                                          } else if (value == 'remove') {
                                            _removeMember(member.uid);
                                          }
                                        },
                                        itemBuilder:
                                            (context) => [
                                              if (member.uid !=
                                                  controller.adminUid)
                                                PopupMenuItem(
                                                  value: 'make_primary',
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.star_rounded,
                                                        size: 20,
                                                        color: AppColors.accent,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          tr('dashboard.groups.set_primary_admin'),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              if (!controller.adminIds.contains(
                                                member.uid,
                                              ))
                                                PopupMenuItem(
                                                  value: 'remove',
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .person_remove_rounded,
                                                        size: 20,
                                                        color: AppColors.error,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          tr(
                                                            'dashboard.group_remove_member',
                                                          ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppButton(
                            text: tr('dashboard.save_changes'),
                            icon: Icons.save_rounded,
                            loading: controller.isSaving,
                            onPressed: isBusy ? null : _save,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            text:
                                details?.isActive == true
                                    ? tr('dashboard.group_archive')
                                    : tr('dashboard.group_unarchive'),
                            icon:
                                details?.isActive == true
                                    ? Icons.archive_rounded
                                    : Icons.unarchive_rounded,
                            backgroundColor: AppColors.supportNavy,
                            loading: controller.isArchiving,
                            onPressed: isBusy ? null : _toggleArchive,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            text: tr('dashboard.group_delete'),
                            icon: Icons.delete_forever_rounded,
                            backgroundColor: AppColors.error,
                            loading: controller.isDeleting,
                            onPressed: isBusy ? null : _deleteGroup,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
