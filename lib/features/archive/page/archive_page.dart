import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_page_shell.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../home/widgets/group_tile.dart';
import '../controllers/archive_controller.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  final controller = ArchiveController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _archivedGroupsStream =
      controller.archivedGroupsStream();

  @override
  Widget build(BuildContext context) {
    if ((controller.currentUid ?? '').isEmpty) {
      return AppPageShell(
        title: tr('archive.title'),
        body: AppEmptyState(
          icon: Icons.lock_outline_rounded,
          text: tr('archive.session_expired'),
        ),
      );
    }

    return AppPageShell(
      title: tr('archive.title'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _archivedGroupsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError || !snapshot.hasData) {
            return AppStateView(
              loading: !snapshot.hasData && !snapshot.hasError,
              error: snapshot.hasError ? tr('archive.load_failed') : null,
              empty: false,
              emptyText: '',
              errorIcon: Icons.wifi_off_rounded,
              child: const SizedBox.shrink(),
            );
          }

          final groups = controller.mapGroups(snapshot.data!.docs);

          return AppStateView(
            loading: false,
            error: null,
            empty: groups.isEmpty,
            emptyIcon: Icons.archive_outlined,
            emptyText: tr('archive.empty'),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: groups.length,
              itemBuilder: (_, index) {
                return GroupTile(
                  userName: controller.userName,
                  group: groups[index],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
