import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../data/models/managed_user.dart';

class AddGroupMembersDialog extends StatefulWidget {
  final Future<List<ManagedUser>> Function(String query) onSearch;
  final Set<String> existingUserIds;

  const AddGroupMembersDialog({
    super.key,
    required this.onSearch,
    required this.existingUserIds,
  });

  @override
  State<AddGroupMembersDialog> createState() => _AddGroupMembersDialogState();
}

class _AddGroupMembersDialogState extends State<AddGroupMembersDialog> {
  final queryController = TextEditingController();
  bool isLoading = false;
  List<ManagedUser> results = const [];
  final Set<String> selectedUserIds = <String>{};

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => isLoading = true);
    final users = await widget.onSearch(queryController.text.trim());
    if (!mounted) return;
    setState(() {
      isLoading = false;
      results = users.where((user) => !widget.existingUserIds.contains(user.uid)).toList();
      selectedUserIds.removeWhere((uid) => !results.any((user) => user.uid == uid));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: Container(
        width: 680,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.appCardColorStrong,
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('dashboard.group_add_members'),
              style: context.textTheme.titleLarge?.copyWith(
                color: context.appTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: queryController,
              decoration: InputDecoration(
                labelText: tr('dashboard.group_member_search'),
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: tr('dashboard.group_search_candidates'),
                    icon: Icons.search_rounded,
                    loading: isLoading,
                    onPressed: isLoading ? null : _search,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    text: tr('dashboard.confirm_selection'),
                    icon: Icons.check_rounded,
                    backgroundColor: AppColors.supportNavy,
                    onPressed: isLoading
                        ? null
                        : () => Navigator.pop(context, selectedUserIds.toList()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 360,
              child: Container(
                decoration: BoxDecoration(
                  color: context.appSurfaceSoft,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: context.appBorder),
                ),
                child: isLoading
                    ? const Center(child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: AppLoader(),
                      ))
                    : results.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Text(
                                tr('dashboard.group_candidates_empty'),
                                style: context.textTheme.bodyMedium?.copyWith(
                                  color: context.appTextSecondary,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final user = results[index];
                              final selected = selectedUserIds.contains(user.uid);
                              return CheckboxListTile(
                                value: selected,
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 2, 8, 2),
                                onChanged: (value) {
                                  setState(() {
                                    if (value == true) {
                                      selectedUserIds.add(user.uid);
                                    } else {
                                      selectedUserIds.remove(user.uid);
                                    }
                                  });
                                },
                                title: Tooltip(
                                  message: user.fullName,
                                  waitDuration: const Duration(milliseconds: 500),
                                  child: Text(
                                    user.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    style: context.textTheme.bodyMedium?.copyWith(
                                      color: context.appTextPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                subtitle: Text(
                                  '${user.userId} • ${user.department}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: context.appTextSecondary,
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
