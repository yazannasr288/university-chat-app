import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/error_message.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loader.dart';
import '../../../data/models/group_model.dart';
import '../../home/widgets/group_avatar.dart';

class ChatForwardSheet extends StatefulWidget {
  final Future<List<GroupModel>> Function() loadGroups;
  final Future<void> Function(GroupModel group) onForward;

  const ChatForwardSheet({
    super.key,
    required this.loadGroups,
    required this.onForward,
  });

  @override
  State<ChatForwardSheet> createState() => _ChatForwardSheetState();
}

class _ChatForwardSheetState extends State<ChatForwardSheet> {
  late final Future<List<GroupModel>> _groupsFuture = widget.loadGroups();
  String _query = '';
  String? _forwardingGroupId;

  Future<void> _forward(GroupModel group) async {
    if (_forwardingGroupId != null) return;

    setState(() => _forwardingGroupId = group.groupId);
    try {
      await widget.onForward(group);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _forwardingGroupId = null);
      showAppSnackBar(context, cleanErrorMessage(e), type: SnackType.error);
    }
  }

  List<GroupModel> _filterGroups(List<GroupModel> groups) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return groups;

    return groups
        .where((group) => group.groupName.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.74,
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: context.appCardColorStrong,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: context.appBorder)),
          boxShadow: AppShadows.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: const Icon(
                    Icons.forward_to_inbox_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'chat.forward_message'.tr(),
                        style: context.textTheme.titleMedium?.copyWith(
                          color: context.appTextPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'chat.choose_group_allowed_send'.tr(),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.appTextSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'search.search_group_hint'.tr(),
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: FutureBuilder<List<GroupModel>>(
                future: _groupsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: AppLoader(),
                    );
                  }

                  if (snapshot.hasError) {
                    return AppEmptyState(
                      icon: Icons.wifi_off_rounded,
                      text: 'chat.unable_load_available_groups'.tr(),
                    );
                  }

                  final groups = _filterGroups(snapshot.data ?? const []);
                  if (groups.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.group_off_rounded,
                      text: 'chat.no_groups_available_forwarding'.tr(),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final isForwarding = _forwardingGroupId == group.groupId;
                      final disabled =
                          _forwardingGroupId != null && !isForwarding;

                      return Opacity(
                        opacity: disabled ? 0.55 : 1,
                        child: Material(
                          color: context.appCardColor,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            onTap: disabled ? null : () => _forward(group),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  GroupAvatar(
                                    groupName: group.groupName,
                                    groupIcon: group.groupIcon,
                                    radius: 23,
                                    backgroundColor: AppColors.primarySoft
                                        .withValues(alpha: 0.50),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      group.groupName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.textTheme.titleSmall
                                          ?.copyWith(
                                            color: context.appTextPrimary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                  ),
                                  if (isForwarding)
                                    const AppLoader.inline(
                                      size: 20,
                                      strokeWidth: 2,
                                    )
                                  else
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                      color: context.appTextMuted,
                                    ),
                                ],
                              ),
                            ),
                          ),
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
