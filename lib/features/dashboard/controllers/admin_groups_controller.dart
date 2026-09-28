import '../../../core/constants/app_group_statuses.dart';
import '../../../core/permissions/app_role_permissions.dart';
import '../../../data/models/managed_group_summary.dart';
import '../../../data/repositories/admin_dashboard_repository.dart';

class AdminGroupsController {
  final AdminDashboardRepository _repository;
  final String currentRole;
  final String currentDepartment;
  bool isLoading = false;
  bool hasSearched = false;
  String? errorMessage;
  List<ManagedGroupSummary> groups = [];

  String query = '';
  String selectedDepartment = '';
  String selectedStatus = AppGroupStatuses.all;

  AdminGroupsController({
    AdminDashboardRepository? repository,
    required this.currentRole,
    required this.currentDepartment,
  }) : _repository = repository ?? AdminDashboardRepository() {
    if (!AppRolePermissions.isSystemAdminRole(currentRole)) {
      selectedDepartment = currentDepartment.trim();
    }
  }
  Future<String?> searchGroups() async {
    isLoading = true;
    errorMessage = null;
    try {
      groups = await _repository.listManagedGroups(
        query: query,
        department: selectedDepartment,
        groupStatus: selectedStatus,
      );
      hasSearched = true;
      return null;
    } catch (_) {
      errorMessage = 'dashboard.groups_search_error';
      return errorMessage;
    } finally {
      isLoading = false;
    }
  }

  Future<String?> archiveGroup(String groupId) async {
    final error = await _repository.archiveManagedGroup(groupId);
    if (error == null) {
      await searchGroups();
    }
    return error;
  }

  Future<String?> unarchiveGroup(String groupId) async {
    final error = await _repository.unarchiveManagedGroup(groupId);
    if (error == null) {
      await searchGroups();
    }
    return error;
  }

  Future<String?> deleteGroup(String groupId) async {
    final error = await _repository.deleteManagedGroup(groupId);
    if (error == null) {
      await searchGroups();
    }
    return error;
  }

  void setQuery(String value) => query = value;
  void setDepartment(String value) {
    if (!AppRolePermissions.isSystemAdminRole(currentRole)) {
      selectedDepartment = currentDepartment.trim();
      return;
    }

    selectedDepartment = value;
  }

  void setStatus(String value) => selectedStatus = value;

  void clearFilters() {
    query = '';
    selectedDepartment = AppRolePermissions.isSystemAdminRole(currentRole)
        ? ''
        : currentDepartment.trim();
    selectedStatus = AppGroupStatuses.all;
    groups = [];
    errorMessage = null;
    hasSearched = false;
  }
}
