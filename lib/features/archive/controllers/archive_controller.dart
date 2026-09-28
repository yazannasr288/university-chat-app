import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/storage/app_prefs.dart';
import '../../../data/models/group_model.dart';
import '../../../data/repositories/group_repository.dart';

class ArchiveController {
  final GroupRepository _groupRepository;

  ArchiveController({
    GroupRepository? groupRepository,
  }) : _groupRepository = groupRepository ?? GroupRepository();

  String get userName => AppPrefs.userName;

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> archivedGroupsStream() {
    final uid = currentUid;
    if (uid == null || uid.isEmpty) {
      return const Stream.empty();
    }

    return _groupRepository.userGroupsStream(
      uid: uid,
      userName: userName,
      isActive: false,
    );
  }

  List<GroupModel> mapGroups(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final groups = docs.map((e) => GroupModel.fromMap(e.data())).toList();
    groups.sort((a, b) => b.recentMessageTime.compareTo(a.recentMessageTime));
    return groups;
  }
}
