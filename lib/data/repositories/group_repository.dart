import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../core/permissions/app_role_permissions.dart';
import '../../core/constants/app_group_statuses.dart';
import '../../core/constants/app_group_write_permissions.dart';
import '../../core/constants/app_group_audiences.dart';
import '../../core/constants/app_storage_folders.dart';
import '../../core/utils/app_file_metadata.dart';
import '../../core/utils/chat_operation_exception.dart';
import '../../services/app_error_monitor.dart';
import '../../core/permissions/app_roles.dart';
import '../models/chat_message.dart';
import '../models/group_model.dart';

part 'group_repository/attachments.dart';

typedef UploadProgressCallback = void Function(double progress);

class UploadedFileInfo {
  final String url;
  final String storagePath;

  const UploadedFileInfo({required this.url, required this.storagePath});
}

class GroupRepository {
  final CollectionReference<Map<String, dynamic>> _groups;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final Uuid _uuid;

  GroupRepository({
    CollectionReference<Map<String, dynamic>>? groupsCollection,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
    Uuid? uuid,
  })  : _groups = groupsCollection ?? FirebaseFirestore.instance.collection('groups'),
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'),
        _uuid = uuid ?? const Uuid();

  String _buildStorageFileName(File file, {String? fileName}) {
    final extension = AppFileMetadata.extensionWithDotFor(
      file,
      fileName: fileName,
    );

    return '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}$extension';
  }
  DocumentReference<Map<String, dynamic>> _groupDoc(String groupId) =>
      _groups.doc(groupId);

  CollectionReference<Map<String, dynamic>> _messagesRef(String groupId) =>
      _groupDoc(groupId).collection('messages');

  CollectionReference<Map<String, dynamic>> _memberStatesRef(String groupId) =>
      _groupDoc(groupId).collection('memberStates');

  CollectionReference<Map<String, dynamic>> _votesRef({
    required String groupId,
    required String messageId,
  }) =>
      _messagesRef(groupId).doc(messageId).collection('votes');

  Stream<QuerySnapshot<Map<String, dynamic>>> userGroupsStream({
    required String uid,
    required String userName,
    required bool isActive,
  }) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('groupSummaries')
        .where('isActive', isEqualTo: isActive)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> userGroupSummary({
    required String uid,
    required String groupId,
  }) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('groupSummaries')
        .doc(groupId)
        .get();
  }

  Future<void> syncCurrentUserGroups() async {
    final callable = _functions.httpsCallable('syncCurrentUserGroups');
    await callable.call();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> groupStream(String groupId) =>
      _groupDoc(groupId).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> messagesStream(String groupId) {
    return _messagesRef(groupId)
        .orderBy('time', descending: true)
        .limit(30)
        .snapshots();
  }
  Future<List<GroupModel>> getDepartmentGroups(
    String department, {
    bool allDepartments = false,
  }) async {
    final cleanDepartment = department.trim();
    if (cleanDepartment.isEmpty && !allDepartments) {
      return const <GroupModel>[];
    }

    final callable = _functions.httpsCallable('listDepartmentGroups');
    final groupsById = <String, GroupModel>{};
    var cursorGroupName = '';
    var cursorGroupId = '';

    for (var page = 0; page < 20; page++) {
      final response = await callable.call({
        'department': cleanDepartment,
        'allDepartments': allDepartments,
        'limit': 500,
        if (cursorGroupName.isNotEmpty && cursorGroupId.isNotEmpty) ...{
          'cursorGroupName': cursorGroupName,
          'cursorGroupId': cursorGroupId,
        },
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      final rawGroups = List<Map<String, dynamic>>.from(
        (data['groups'] ?? const []).map(
          (e) => Map<String, dynamic>.from(e),
        ),
      );

      for (final rawGroup in rawGroups) {
        final group = GroupModel.fromMap(rawGroup);
        if (group.groupId.trim().isNotEmpty) {
          groupsById[group.groupId] = group;
        }
      }

      final nextCursorRaw = data['nextCursor'];
      if (data['hasMore'] != true || nextCursorRaw is! Map) break;

      final nextCursor = Map<String, dynamic>.from(nextCursorRaw);
      final nextGroupName = nextCursor['groupName']?.toString() ?? '';
      final nextGroupId = nextCursor['groupId']?.toString() ?? '';
      if (nextGroupName.isEmpty || nextGroupId.isEmpty) break;
      if (nextGroupName == cursorGroupName && nextGroupId == cursorGroupId) {
        break;
      }

      cursorGroupName = nextGroupName;
      cursorGroupId = nextGroupId;
    }

    final groups = groupsById.values.toList()
      ..sort((a, b) {
        final byName = a.groupName.compareTo(b.groupName);
        if (byName != 0) return byName;
        return a.groupId.compareTo(b.groupId);
      });
    return groups;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> loadOlderMessages({
    required String groupId,
    required DocumentSnapshot<Map<String, dynamic>> afterDoc,
    int limit = 30,
  }) {
    return loadMessagesPage(
      groupId: groupId,
      afterDoc: afterDoc,
      limit: limit,
    );
  }

  Future<QuerySnapshot<Map<String, dynamic>>> loadMessagesPage({
    required String groupId,
    DocumentSnapshot<Map<String, dynamic>>? afterDoc,
    int limit = 30,
  }) {
    var query = _messagesRef(groupId)
        .orderBy('time', descending: true)
        .limit(limit);

    if (afterDoc != null) {
      query = query.startAfterDocument(afterDoc).limit(limit);
    }

    return query.get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> memberStatesStream(
      String groupId,
      ) {
    return _memberStatesRef(groupId)
        .orderBy(FieldPath.documentId)
        .snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> groupSettingsDocStream({
    required String uid,
    required String groupId,
  }) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('groupSettings')
        .doc(groupId)
        .snapshots();
  }

  Future<void> markGroupsDelivered({required List<GroupModel> groups}) async {
    final payload = groups
        .where(
          (group) =>
              group.groupId.trim().isNotEmpty &&
              group.recentMessageTime > 0 &&
              group.recentMessageTime > group.lastDeliveredMessageTime,
        )
        .take(100)
        .map(
          (group) => {
        'groupId': group.groupId,
        'lastDeliveredMessageTime': group.recentMessageTime,
      },
    )
        .toList();

    if (payload.isEmpty) return;

    final callable = _functions.httpsCallable('markGroupsDelivered');
    await callable.call({'groups': payload});
  }

  Future<void> markGroupRead(String groupId, {int? lastReadMessageTime}) async {
    final callable = _functions.httpsCallable('markGroupRead');

    await callable.call({
      'groupId': groupId,
      if (lastReadMessageTime != null && lastReadMessageTime > 0)
        'lastReadMessageTime': lastReadMessageTime,
    });
  }

  Future<void> setGroupMuted({
    required String groupId,
    required bool muted,
    DateTime? mutedUntil,
  }) async {
    final callable = _functions.httpsCallable(
      'updateGroupNotificationSettings',
    );

    await callable.call({
      'groupId': groupId,
      'muted': muted,
      if (mutedUntil != null) 'mutedUntil': mutedUntil.millisecondsSinceEpoch,
    });
  }

  Future<void> setGroupPinned({
    required String groupId,
    required bool pinned,
  }) async {
    final callable = _functions.httpsCallable(
      'updateGroupNotificationSettings',
    );

    await callable.call({'groupId': groupId, 'pinned': pinned});
  }

  Future<void> createGroup({
    required String groupName,
    String audience = AppGroupAudiences.department,
    String department = '',
  }) async {
    final callable = _functions.httpsCallable('createGroupSafe');
    await callable.call({
      'groupName': groupName.trim(),
      'audience': audience.trim(),
      if (department.trim().isNotEmpty) 'department': department.trim(),
    });
  }

  Future<bool> isUserJoined({
    required String uid,
    required String groupId,
    required String groupName,
  }) async {
    final cleanUid = uid.trim();
    final cleanGroupId = groupId.trim();

    if (cleanUid.isEmpty || cleanGroupId.isEmpty) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(cleanUid)
        .get();
    final userData = userDoc.data();
    final groupIds = (userData?['groupIds'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toSet() ??
        const <String>{};

    return groupIds.contains(cleanGroupId);
  }

  Future<String?> toggleGroup({required String groupId}) async {
    try {
      final callable = _functions.httpsCallable('toggleGroupMembership');
      await callable.call({'groupId': groupId});

      return null;
    } on FirebaseFunctionsException catch (e) {
      return e.message ?? tr('chat.could_not_update_membership');
    } catch (_) {
      return tr('chat.could_not_update_membership');
    }
  }

  Future<List<GroupModel>> getManageableGroups({
    required String uid,
    required String userName,
    required String role,
    String department = '',
  }) async {
    if (AppRolePermissions.canAccessManagedGroupsRole(role)) {
      final callable = _functions.httpsCallable('listManagedGroups');

      final response = await callable.call({
        'department': AppRoles.isSystemAdmin(role) ? department : '',
        'groupStatus': AppGroupStatuses.active,
      });

      final data = Map<String, dynamic>.from(response.data as Map);

      final rawGroups = List<Map<String, dynamic>>.from(
        (data['groups'] ?? const []).map((e) => Map<String, dynamic>.from(e)),
      );

      return rawGroups.map(GroupModel.fromMap).toList();
    }

    final primaryAdminSnapshot = await _groups
        .where('isActive', isEqualTo: true)
        .where('adminId', isEqualTo: uid)
        .orderBy('groupName')
        .get();

    final secondaryAdminSnapshot = await _groups
        .where('isActive', isEqualTo: true)
        .where('adminIds', arrayContains: uid)
        .orderBy('groupName')
        .get();

    final groupsById = <String, GroupModel>{};

    for (final doc in primaryAdminSnapshot.docs) {
      final group = GroupModel.fromMap(doc.data());
      if (group.groupId.trim().isNotEmpty) {
        groupsById[group.groupId] = group;
      }
    }

    for (final doc in secondaryAdminSnapshot.docs) {
      final group = GroupModel.fromMap(doc.data());
      if (group.groupId.trim().isNotEmpty) {
        groupsById[group.groupId] = group;
      }
    }

    final groups = groupsById.values.toList()
      ..sort((a, b) => a.groupName.compareTo(b.groupName));

    return groups;
  }

  Future<void> archiveGroup({
    required String groupId,
    required String adminName,
  }) async {
    final callable = _functions.httpsCallable('archiveManagedGroup');
    await callable.call({'groupId': groupId});
  }

  Future<void> unarchiveGroup(String groupId) async {
    final callable = _functions.httpsCallable('unarchiveManagedGroup');
    await callable.call({'groupId': groupId});
  }

  Future<void> updateWritePermission({
    required String groupId,
    required bool locked,
  }) async {
    final groupDoc = await _groupDoc(groupId).get();
    final data = groupDoc.data() ?? {};

    final callable = _functions.httpsCallable('updateManagedGroupProfile');

    await callable.call({
      'groupId': groupId,
      'groupName': (data['groupName'] ?? '').toString(),
      'department': (data['department'] ?? '').toString(),
      'writePermission': locked
          ? AppGroupWritePermissions.admins
          : AppGroupWritePermissions.all,
      'adminUid': (data['adminId'] ?? '').toString(),
    });
  }

  Future<void> updateGroupIcon({
    required String groupId,
    required File file,
    String? originalFileName,
  }) async {
    final uploaded = await uploadFile(
      groupId: groupId,
      file: file,
      folder: AppStorageFolders.groupIcons,
      fileName: originalFileName,
    );

    try {
      final callable = _functions.httpsCallable('updateGroupIconMeta');

      await callable.call({
        'groupId': groupId,
        'groupIcon': uploaded.url,
        'groupIconPath': uploaded.storagePath,
      });
    } catch (_) {
      try {
        await deleteStorageFile(uploaded.storagePath, groupId: groupId);
      } catch (_) {
      }

      rethrow;
    }
  }

  Future<void> kickMember({
    required String groupId,
    required String memberUid,
  }) async {
    final callable = _functions.httpsCallable('kickGroupMember');
    await callable.call({'groupId': groupId, 'memberUid': memberUid});
  }

  Future<void> deleteGroup(String groupId) async {
    final callable = _functions.httpsCallable('deleteGroupCascade');
    await callable.call({'groupId': groupId});
  }

  Future<void> deleteMessage({
    required String groupId,
    required String messageId,
  }) async {
    final callable = _functions.httpsCallable('deleteMessageCascade');
    await callable.call({'groupId': groupId, 'messageId': messageId});
  }

  Future<List<GroupModel>> listForwardableGroups({
    required String uid,
    required String role,
    required String accountType,
    required String currentGroupId,
    String currentDepartment = '',
  }) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return const <GroupModel>[];

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(cleanUid)
        .collection('groupSummaries')
        .where('isActive', isEqualTo: true)
        .get();

    final groups = snapshot.docs
        .map(
          (doc) => GroupModel.fromMap({
            'groupId': doc.id,
            ...doc.data(),
          }),
        )
        .where((group) => group.groupId.trim().isNotEmpty)
        .where((group) => group.groupId != currentGroupId)
        .where((group) => group.isActive)
        .where((group) {
          final groupName = group.groupName.trim();

          if (groupName == 'main_wpu') {
            return AppRolePermissions.isSystemAdminRole(role);
          }

          if (!AppGroupAudiences.canAccess(
            audience: group.audience,
            role: role,
            accountType: accountType,
            userDepartment: currentDepartment,
            groupDepartment: group.department,
          )) {
            return false;
          }

          if (AppGroupAudiences.isMemberCollaboration(group.audience)) {
            return AppGroupWritePermissions.isOpen(group.writePermission) ||
                (AppGroupWritePermissions.isAdminsOnly(group.writePermission) &&
                    AppRolePermissions.canSendToRestrictedGroup(
                      currentUid: cleanUid,
                      groupAdminId: group.adminId,
                      groupAdminIds: group.adminIds,
                      role: role,
                    ));
          }

          if (groupName.startsWith('main_')) {
            final department = currentDepartment.trim();
            return AppRolePermissions.isSystemAdminRole(role) ||
                ((AppRolePermissions.isDeanRole(role) ||
                        AppRolePermissions.isDepartmentStaffRole(role)) &&
                    department.isNotEmpty &&
                    department == group.department.trim());
          }

          return AppGroupWritePermissions.isOpen(group.writePermission) ||
              (AppGroupWritePermissions.isAdminsOnly(group.writePermission) &&
                  AppRolePermissions.canSendToRestrictedGroup(
                    currentUid: cleanUid,
                    groupAdminId: group.adminId,
                    groupAdminIds: group.adminIds,
                    role: role,
                  ));
        })
        .toList();

    groups.sort((a, b) => a.groupName.compareTo(b.groupName));
    return groups;
  }

  Future<void> forwardMessage({
    required String sourceGroupId,
    required String targetGroupId,
    required String messageId,
  }) async {
    final callable = _functions.httpsCallable('forwardChatMessage');
    await callable.call({
      'sourceGroupId': sourceGroupId.trim(),
      'targetGroupId': targetGroupId.trim(),
      'messageId': messageId.trim(),
    });
  }

  Future<void> sendMessage({
    required String groupId,
    required Map<String, dynamic> data,
    String? messageId,
  }) async {
    final cleanMessageId = messageId?.trim();

    if (cleanMessageId == null || cleanMessageId.isEmpty) {
      await _messagesRef(groupId).add(data);
      return;
    }

    await _messagesRef(groupId).doc(cleanMessageId).set(data);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> pollVotesStream({
    required String groupId,
    required String messageId,
  }) {
    return _votesRef(groupId: groupId, messageId: messageId).snapshots();
  }

  Future<void> sendPollVote({
    required String groupId,
    required String messageId,
    required String uid,
    required int optionIndex,
  }) async {
    await _votesRef(groupId: groupId, messageId: messageId).doc(uid).set({
      'uid': uid,
      'optionIndex': optionIndex,
      'votedAt': FieldValue.serverTimestamp(),
    });
  }



  String get _currentUid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('not-authenticated');
    return user.uid;
  }

  String _savedMessageDocId({
    required String groupId,
    required String messageId,
  }) => '${groupId.trim()}_${messageId.trim()}';

  CollectionReference<Map<String, dynamic>> _savedMessagesRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('savedMessages');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> savedMessagesStream() {
    return _savedMessagesRef(_currentUid)
        .orderBy('savedAt', descending: true)
        .snapshots();
  }

  Future<void> saveMessage({
    required String groupId,
    required String groupName,
    required ChatMessage message,
  }) async {
    final uid = _currentUid;
    final docId = _savedMessageDocId(
      groupId: groupId,
      messageId: message.id,
    );

    await _savedMessagesRef(uid).doc(docId).set({
      'id': docId,
      'uid': uid,
      'groupId': groupId.trim(),
      'groupName': groupName.trim(),
      'messageId': message.id.trim(),
      'message': message.message,
      'type': message.type,
      'sender': message.sender,
      'senderId': message.senderId,
      'time': message.time,
      if (message.fileName?.trim().isNotEmpty == true)
        'fileName': message.fileName!.trim(),
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeSavedMessage({
    required String groupId,
    required String messageId,
  }) async {
    await _savedMessagesRef(_currentUid)
        .doc(_savedMessageDocId(groupId: groupId, messageId: messageId))
        .delete();
  }

  Future<void> _validateUpload({
    required File file,
    required String folder,
    required String contentType,
  }) async {
    final size = await file.length();
    final maxBytes = AppFileMetadata.maxBytesForFolder(folder);

    if (size <= 0) {
      throw Exception(tr('chat.invalid_file'));
    }

    if (size > maxBytes) {
      throw Exception(tr('chat.file_size_exceeds_allowed_limit'));
    }

    if (AppStorageFolders.isImageFolder(folder) &&
        !contentType.startsWith('image/')) {
      throw Exception(tr('chat.unsupported_image_type'));
    }

    if (AppStorageFolders.isVideoFolder(folder) &&
        !contentType.startsWith('video/')) {
      throw Exception(tr('chat.unsupported_video_type'));
    }

    if (AppStorageFolders.isAudioFolder(folder) &&
        !contentType.startsWith('audio/')) {
      throw Exception(tr('chat.unsupported_audio_file_type'));
    }

    if (AppStorageFolders.isGenericFileFolder(folder) &&
        !AppFileMetadata.isAllowedGenericFileContentType(contentType)) {
      throw Exception(tr('chat.unsupported_file_type'));
    }
  }


}
