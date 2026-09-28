import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart' hide SearchController;

import '../../../core/widgets/app_page_shell.dart';
import '../../../core/widgets/app_state_view.dart';
import '../controllers/search_controller.dart';
import '../widgets/group_card.dart';
import '../widgets/search_input_bar.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController queryController = TextEditingController();
  final SearchController controller = SearchController();

  @override
  void initState() {
    super.initState();
    _handleInit();
  }

  Future<void> _handleInit() async {
    final initFuture = controller.init();
    setState(() {});
    await initFuture;
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    queryController.dispose();
    super.dispose();
  }

  void _handleSearch(String value) {
    controller.search(value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppPageShell(
      title: 'search.title'.tr(),
      body: Column(
        children: [
          SearchInputBar(
            controller: queryController,
            onChanged: _handleSearch,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final noDepartment = controller.userDepartment.isEmpty;
    final noGroups = controller.allGroups.isEmpty;
    final noMatches = controller.filteredGroups.isEmpty;

    return AppStateView(
      loading: controller.isLoading,
      error: controller.errorMessage,
      empty: noDepartment || noGroups || noMatches,
      emptyIcon: noDepartment
          ? Icons.warning_amber_rounded
          : noGroups
              ? Icons.group_off_rounded
              : Icons.search_off_rounded,
      emptyText: noDepartment
          ? 'search.no_department_was_found_user'.tr()
          : noGroups
              ? 'search.no_groups_available_department'.tr()
              : 'search.no_matching_results'.tr(),
      errorIcon: Icons.error_outline_rounded,
      onRetry: controller.errorMessage != null ? _handleInit : null,
      child: ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: controller.filteredGroups.length,
        itemBuilder: (_, index) {
          final group = controller.filteredGroups[index];

          return GroupCard(
            key: ValueKey(group.groupId),
            group: group,
            adminName: controller.adminNameOf(group),
            isJoinedLoader: () => controller.isJoined(group),
            onToggleJoin: () => controller.toggleGroup(group),
          );
        },
      ),
    );
  }
}
