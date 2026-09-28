import '../../../data/models/managed_user.dart';
import '../../../data/repositories/admin_dashboard_repository.dart';

class AdminStudentsController {
  final AdminDashboardRepository _repository;

  bool isLoading = false;
  bool hasSearched = false;
  String? errorMessage;

  List<ManagedUser> users = [];
  final Set<String> selectedUserIds = <String>{};
  bool allowEmptySearch = false;

  String query = '';
  String selectedDepartment = '';
  String selectedAccountStatus = '';
  String selectedRole = '';

  AdminStudentsController({
    AdminDashboardRepository? repository,
  }) : _repository = repository ?? AdminDashboardRepository();

  bool get canSearch {
    if (allowEmptySearch) return true;
    return query.trim().isNotEmpty ||
        selectedDepartment.isNotEmpty ||
        selectedAccountStatus.isNotEmpty ||
        selectedRole.isNotEmpty;
  }

  int get selectedCount => selectedUserIds.length;

  List<ManagedUser> get selectedUsers =>
      users.where((user) => selectedUserIds.contains(user.uid)).toList();

  bool isSelected(String uid) => selectedUserIds.contains(uid);

  Future<String?> searchStudents() async {
    if (!canSearch) {
      errorMessage = null;
      return 'dashboard.students_search_hint';
    }

    isLoading = true;
    errorMessage = null;
    try {
      users = await _repository.listManagedUsers(
        query: query,
        department: selectedDepartment,
        role: selectedRole,
        accountStatus: selectedAccountStatus,
      );
      // Keep selections across searches so admins can build a long recipient list
      // by searching for one student, selecting them, then searching again.
      hasSearched = true;
      return null;
    } catch (_) {
      errorMessage = 'dashboard.students_search_error';
      return errorMessage;
    } finally {
      isLoading = false;
    }
  }

  Future<String?> freezeStudent(String uid) async {
    final error = await _repository.freezeStudent(uid);
    if (error == null) {
      await searchStudents();
    }
    return error;
  }

  Future<String?> unfreezeStudent(String uid) async {
    final error = await _repository.unfreezeStudent(uid);
    if (error == null) {
      await searchStudents();
    }
    return error;
  }

  Future<String?> removeStudent(String uid) async {
    final error = await _repository.removeStudent(uid);
    if (error == null) {
      selectedUserIds.remove(uid);
      await searchStudents();
    }
    return error;
  }

  Future<String?> sendNotificationToSelected({
    required String title,
    required String body,
  }) async {
    if (selectedUserIds.isEmpty) {
      return 'dashboard.select_students_first';
    }

    return _repository.sendNotificationToUsers(
      recipientUids: selectedUserIds.toList(),
      title: title,
      body: body,
    );
  }

  void toggleSelection(String uid, bool selected) {
    if (selected) {
      selectedUserIds.add(uid);
    } else {
      selectedUserIds.remove(uid);
    }
  }

  void toggleSelectAllVisible(bool selected) {
    if (selected) {
      selectedUserIds.addAll(users.map((e) => e.uid));
    } else {
      for (final user in users) {
        selectedUserIds.remove(user.uid);
      }
    }
  }

  void clearSelection() {
    selectedUserIds.clear();
  }

  void setQuery(String value) {
    query = value;
  }

  void setDepartment(String value) {
    selectedDepartment = value;
  }

  void setRole(String value) {
    selectedRole = value;
  }

  void setAccountStatus(String value) {
    selectedAccountStatus = value;
  }

  void clearFilters() {
    query = '';
    selectedDepartment = '';
    selectedAccountStatus = '';
    selectedRole = '';
    users = [];
    errorMessage = null;
    selectedUserIds.clear();
    hasSearched = false;
  }
}
