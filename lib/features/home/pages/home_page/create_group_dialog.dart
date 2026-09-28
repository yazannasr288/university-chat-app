part of '../home_page.dart';

class _CreateGroupDialog extends StatefulWidget {
  final HomeController controller;

  const _CreateGroupDialog({required this.controller});

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final TextEditingController _nameController = TextEditingController();
  String _audience = AppGroupAudiences.department;
  late String _department;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _department = AppDepartments.values.contains(widget.controller.department)
        ? widget.controller.department
        : AppDepartments.values.first;
  }

  List<String> get _availableAudiences {
    final role = widget.controller.role;
    final accountType = widget.controller.accountType;
    final canCreateDoctorGroups =
        AppRoles.isSystemAdmin(role) ||
        AppRoles.isDean(role) ||
        accountType == 'doctor' ||
        accountType == 'dean';
    final canCreateWorkerGroups = AppRoles.isSystemAdmin(role);

    return <String>[
      AppGroupAudiences.department,
      if (canCreateDoctorGroups) ...<String>[
        AppGroupAudiences.doctorsDepartment,
        AppGroupAudiences.doctorsAll,
      ],
      if (canCreateWorkerGroups) AppGroupAudiences.workers,
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final groupName = _nameController.text.trim();

    if (groupName.isEmpty) {
      showAppSnackBar(
        context,
        'home.group_name_required'.tr(),
        type: SnackType.error,
      );
      return;
    }

    if (groupName.length > 50) {
      showAppSnackBar(
        context,
        'home.group_name_too_long'.tr(),
        type: SnackType.error,
      );
      return;
    }

    final targetDepartment = _audience == AppGroupAudiences.workers
        ? AppDepartments.worker
        : (AppRoles.isSystemAdmin(widget.controller.role)
            ? _department
            : widget.controller.department);

    if (targetDepartment.isEmpty) {
      showAppSnackBar(
        context,
        'home.department_not_set'.tr(),
        type: SnackType.error,
      );
      return;
    }

    setState(() => _creating = true);

    try {
      await widget.controller.createGroup(
        groupName,
        audience: _audience,
        department: targetDepartment,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      showAppSnackBar(
        context,
        cleanErrorMessage(e),
        type: SnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.appCardColorStrong,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: context.appBorder),
      ),
      title: Text(
        'home.create_group'.tr(),
        style: context.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: context.appTextPrimary,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              enabled: !_creating,
              maxLength: 50,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_creating) _createGroup();
              },
              decoration: InputDecoration(
                labelText: 'home.group_name'.tr(),
                hintText: 'home.enter_clear_concise_name'.tr(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _audience,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'home.group_audience'.tr(),
              ),
              items: _availableAudiences
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        AppGroupAudiences.labelKey(value).tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _creating
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        _audience = value;
                        if (value == AppGroupAudiences.workers) {
                          _department = AppDepartments.worker;
                        }
                      });
                    },
            ),
            if (AppRoles.isSystemAdmin(widget.controller.role) &&
                _audience != AppGroupAudiences.workers) ...[
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _department,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'common.department'.tr(),
                ),
                items: AppDepartments.values
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          AppDepartments.labelKey(value).tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _creating
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _department = value);
                      },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _creating ? null : () => Navigator.of(context).pop(false),
          child: Text('common.cancel'.tr()),
        ),
        AppButton(
          text: _creating ? 'home.creating'.tr() : 'home.create'.tr(),
          icon: Icons.add_rounded,
          loading: _creating,
          onPressed: _createGroup,
        ),
      ],
    );
  }
}
