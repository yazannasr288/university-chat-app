part of '../home_page.dart';

extension on _HomePageState {
  // Widget _buildTopWelcome() {
  //   final name =
  //       controller.userName.trim().isNotEmpty
  //           ? controller.userName.trim()
  //           : 'home.user'.tr();
  //   final department = controller.department.trim();
  //
  //   return AppSurface.card(
  //     margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
  //     padding: EdgeInsets.zero,
  //     gradient: AppGradients.brand,
  //     borderRadius: AppDecorations.radius(AppRadii.xl),
  //     borderColor: Colors.white.withValues(alpha: 0.10),
  //     boxShadow: context.isDark ? const [] : AppShadows.brandGlow,
  //     child: Stack(
  //       children: [
  //         PositionedDirectional(
  //           top: -52,
  //           end: -34,
  //           child: Container(
  //             width: 160,
  //             height: 160,
  //             decoration: BoxDecoration(
  //               shape: BoxShape.circle,
  //               color: Colors.white.withValues(alpha: 0.085),
  //             ),
  //           ),
  //         ),
  //         PositionedDirectional(
  //           bottom: -46,
  //           start: 52,
  //           child: Container(
  //             width: 128,
  //             height: 92,
  //             decoration: BoxDecoration(
  //               shape: BoxShape.circle,
  //               color: AppColors.accent.withValues(alpha: 0.12),
  //             ),
  //           ),
  //         ),
  //         Padding(
  //           padding: const EdgeInsets.all(AppSpacing.lg),
  //           child: Row(
  //             children: [
  //               Stack(
  //                 clipBehavior: Clip.none,
  //                 children: [
  //                   AppIconBadge(
  //                     icon: Icons.chat_bubble_rounded,
  //                     size: 52,
  //                     iconSize: 25,
  //                     color: Colors.white,
  //                     backgroundColor: Colors.white.withValues(alpha: 0.14),
  //                     borderColor: Colors.white.withValues(alpha: 0.22),
  //                     borderRadius: AppDecorations.radius(AppRadii.lg),
  //                     boxShadow: [
  //                       BoxShadow(
  //                         color: Colors.black.withValues(alpha: 0.10),
  //                         blurRadius: 18,
  //                         offset: const Offset(0, 8),
  //                       ),
  //                     ],
  //                   ),
  //                   PositionedDirectional(
  //                     end: -3,
  //                     bottom: -3,
  //                     child: Container(
  //                       width: 16,
  //                       height: 16,
  //                       decoration: BoxDecoration(
  //                         gradient: AppGradients.gold,
  //                         shape: BoxShape.circle,
  //                         border: Border.all(color: Colors.white, width: 2.2),
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //               const AppGap.horizontal(15),
  //               Expanded(
  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Text(
  //                       tr('home.welcome_user', args: [name]),
  //                       maxLines: 1,
  //                       overflow: TextOverflow.ellipsis,
  //                       style: context.textTheme.titleMedium?.copyWith(
  //                         color: Colors.white,
  //                         fontWeight: FontWeight.w900,
  //                         letterSpacing: -0.15,
  //                       ),
  //                     ),
  //                     const AppGap(5),
  //                     Text(
  //                       department.isEmpty
  //                           ? 'home.groups_and_messages_one_place'.tr()
  //                           : tr(
  //                               'home.department_format',
  //                               args: [
  //                                 tr(AppDepartments.labelKey(department)),
  //                               ],
  //                             ),
  //                       maxLines: 1,
  //                       overflow: TextOverflow.ellipsis,
  //                       style: context.textTheme.bodyMedium?.copyWith(
  //                         color: Colors.white.withValues(alpha: 0.82),
  //                         fontWeight: FontWeight.w700,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _toggleGroupPinned(GroupModel group) async {
    try {
      await controller.setGroupPinned(group, !group.isPinned);
      if (!mounted) return;
      showAppSnackBar(
        context,
        group.isPinned ? 'home.group_unpinned'.tr() : 'home.group_pinned'.tr(),
        type: SnackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, cleanErrorMessage(e), type: SnackType.error);
    }
  }

  void _retryGroupsStream() {
    _safeSetState(() {
      _userGroupsStream = controller.userGroupsStream(isActive: true);
    });
  }

  Widget _buildGroupList(List<GroupModel> groups) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      itemCount: groups.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return AppStaggeredEntrance(
            key: const ValueKey<String>('home-welcome'),
            child: SizedBox(),
          );
        }

        final group = groups[index - 1];
        return AppStaggeredEntrance(
          key: ValueKey<String>('group-entrance-${group.groupId}'),
          index: index,
          maxDelaySteps: 7,
          offsetY: 8,
          child: GroupTile(
            userName: controller.userName,
            group: group,
            onTogglePinned: () => _toggleGroupPinned(group),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    final userGroupsStream = _userGroupsStream;

    if (userGroupsStream == null) {
      return const AppLoader();
    }

    return StreamBuilder<List<GroupModel>>(
      stream: userGroupsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (controller.cachedGroups.isNotEmpty) {
            return _buildGroupList(controller.cachedGroups);
          }
          return AppEmptyState(
            icon: Icons.wifi_off_rounded,
            text: 'home.could_not_load_groups_check_connection_try'.tr(),
            actionLabel: 'common.retry'.tr(),
            onAction: _retryGroupsStream,
          );
        }

        if (!snapshot.hasData) {
          if (controller.cachedGroups.isNotEmpty) {
            return _buildGroupList(controller.cachedGroups);
          }
          return const AppLoader();
        }

        final groups = snapshot.data!;
        if (groups.isEmpty) {
          return AppEmptyState(
            icon: Icons.group_outlined,
            text: 'home.do_not_have_any_groups_yet'.tr(),
            actionLabel: 'home.find_groups'.tr(),
            actionIcon: Icons.search_rounded,
            onAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchPage()),
              );
            },
          );
        }

        return _buildGroupList(groups);
      },
    );
  }
}
