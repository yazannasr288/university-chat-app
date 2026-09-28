part of '../home_page.dart';

extension on _HomePageState {
  void _configureNotificationNavigation() {
    NotificationService.configureOpenGroupHandler((groupId, groupName) {
      if (!mounted) return;

      final cleanGroupId = groupId.trim();
      if (cleanGroupId.isEmpty) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            userName: controller.userName,
            groupId: cleanGroupId,
            groupName: groupName.trim().isNotEmpty
                ? groupName.trim()
                : cleanGroupId,
          ),
        ),
      );
    });
  }

  Future<void> _handleInit() async {
    _safeSetState(() {
      loading = true;
      initError = null;
    });

    try {
      await controller.load();
      _configureNotificationNavigation();
      _userGroupsStream = controller.userGroupsStream(isActive: true);
      controller.startCurrentUserWatcher(
        onChanged: () {
          if (!mounted) return;
          _safeSetState(() {});
        },
      );
    } catch (e) {
      if (!mounted) return;
      _safeSetState(() {
        loading = false;
        initError = cleanErrorMessage(
          e,
          fallback: 'home.could_not_load_home_page_check_connection'.tr(),
        );
      });
      return;
    }

    if (!mounted) return;

    _safeSetState(() => loading = false);

    controller.startSessionWatcher(
      onSessionInvalid: () {
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (_) => false,
        );
      },
      onSessionForcedLogout: (reason) {
        if (!mounted) return;

        showAppSnackBar(
          context,
          reason,
          type: SnackType.info,
        );
      },
    );
  }

}
