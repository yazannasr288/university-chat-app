import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_storage_folders.dart';
import '../../core/permissions/app_roles.dart';
import '../../core/services/storage_download_url_cache.dart';
import '../../core/utils/app_file_metadata.dart';
import '../../core/utils/error_message.dart';
import '../../services/app_error_monitor.dart';
import '../models/app_user.dart';

class UserRepository {
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final Uuid _uuid;
  final CollectionReference<Map<String, dynamic>> _users;

  UserRepository({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    Uuid? uuid,
    CollectionReference<Map<String, dynamic>>? usersCollection,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(
          region: 'us-central1',
        ),
        _storage = storage ?? FirebaseStorage.instance,
        _uuid = uuid ?? const Uuid(),
        _users = usersCollection ?? FirebaseFirestore.instance.collection('users');

  String _buildProfileImageStoragePath({
    required String uid,
    required File file,
    String? fileName,
  }) {
    final extension = AppFileMetadata.extensionWithDotFor(
      file,
      fileName: fileName,
    );

    return '${AppStorageFolders.profileImages}/$uid/'
        '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}$extension';
  }

  AppUser _userFromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data() ?? const {});
    data['uid'] = (data['uid'] ?? doc.id).toString();
    return AppUser.fromMap(data);
  }

  Future<void> _cleanupOldProfileImage(String storagePath) async {
    final cleanPath = storagePath.trim().replaceFirst(RegExp(r'^/+'), '');
    if (cleanPath.isEmpty) return;

    try {
      final callable = _functions.httpsCallable('cleanupOldProfileImage');
      await callable.call({'storagePath': cleanPath});
    } catch (error, stackTrace) {
      AppErrorMonitor.recordHandled(
        error,
        stackTrace,
        context: 'cleanup_old_profile_image',
      );
      // لا نفشل تحديث البروفايل بسبب تنظيف ملف قديم. السيرفر سيمنع
      // حذف أي ملف لا يخص المستخدم أو لا يزال مربوطًا بحسابه.
    }
  }

  Future<String> uploadCurrentUserProfileImage({
    required File file,
    String? fileName,
  }) async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'انتهت الجلسة. سجل الدخول مرة أخرى',
      );
    }

    final folder = AppStorageFolders.profileImages;
    final contentType = AppFileMetadata.contentTypeFor(
      file: file,
      folder: folder,
      fileName: fileName,
    );

    if (!AppFileMetadata.isAllowedImageContentType(contentType)) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'نوع الصورة غير مدعوم',
      );
    }

    final size = await file.length();
    if (size > AppFileMetadata.maxBytesForFolder(folder)) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'حجم الصورة أكبر من الحد المسموح',
      );
    }

    final userRef = _users.doc(uid);
    final previousDoc = await userRef.get();
    final previousProfilePic =
        (previousDoc.data()?['profilepic'] ?? '').toString().trim();

    final storagePath = _buildProfileImageStoragePath(
      uid: uid,
      file: file,
      fileName: fileName,
    );

    await _storage.ref(storagePath).putFile(
          file,
          SettableMetadata(contentType: contentType),
        );

    try {
      await userRef.set({'profilepic': storagePath}, SetOptions(merge: true));
    } catch (_) {
      await _cleanupOldProfileImage(storagePath);
      rethrow;
    }

    StorageDownloadUrlCache.invalidate(storagePath);

    if (previousProfilePic.isNotEmpty && previousProfilePic != storagePath) {
      StorageDownloadUrlCache.invalidate(previousProfilePic);
      await _cleanupOldProfileImage(previousProfilePic);
    }

    return storagePath;
  }


  Future<void> deleteCurrentUserProfileImage() async {
    final uid = _auth.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'انتهت الجلسة. سجل الدخول مرة أخرى',
      );
    }

    final userRef = _users.doc(uid);
    final userDoc = await userRef.get();
    final currentProfilePic =
        (userDoc.data()?['profilepic'] ?? '').toString().trim();

    if (currentProfilePic.isEmpty) return;

    await userRef.set({'profilepic': ''}, SetOptions(merge: true));
    StorageDownloadUrlCache.invalidate(currentProfilePic);
    await _cleanupOldProfileImage(currentProfilePic);
  }

  Future<List<AppUser>> listGroupMembersPublic(String groupId) async {
    final cleanGroupId = groupId.trim();
    if (cleanGroupId.isEmpty) return const <AppUser>[];

    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseFunctionsException(
        code: 'unauthenticated',
        message: 'انتهت الجلسة. سجل الدخول مرة أخرى',
      );
    }

    // هذا مهم: يجبر Flutter على تجهيز/تحديث Firebase Auth ID token
    // قبل استدعاء Cloud Function.
    await user.getIdToken(true);

    final callable = _functions.httpsCallable('listGroupMembersPublic');
    final response = await callable.call({'groupId': cleanGroupId});

    final data = Map<String, dynamic>.from(response.data as Map);
    final rawMembers = List<Map<String, dynamic>>.from(
      (data['members'] ?? const []).map((e) => Map<String, dynamic>.from(e)),
    );

    return rawMembers.map((map) {
      return AppUser.fromMap({
        'uid': (map['uid'] ?? '').toString(),
        'fullName': (map['fullName'] ?? '').toString(),
        'userId': (map['userId'] ?? '').toString(),
        'email': '',
        'department': '',
        'phone': '',
        'phoneE164': '',
        'role': (map['role'] ?? AppRoles.user).toString(),
        'accountType': (map['accountType'] ?? AppRoles.user).toString(),
        'accountStatus': 'active',
        'accountStatusReason': '',
        'profilepic': (map['profilepic'] ?? '').toString(),
        'groupIds': [cleanGroupId],
      });
    }).toList();
  }

  Future<AppUser?> getCurrentUser() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return getUserByUid(uid);
  }

  Stream<AppUser?> watchCurrentUser() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream<AppUser?>.value(null);

    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return _userFromDocument(doc);
    });
  }

  Future<AppUser?> getUserByUid(String uid) async {
    final cleanUid = uid.trim();
    if (cleanUid.isEmpty) return null;

    final doc = await _users.doc(cleanUid).get();
    if (!doc.exists) return null;
    return _userFromDocument(doc);
  }

  Future<String> getCurrentUserDepartment() async {
    final user = await getCurrentUser();
    return user?.department ?? '';
  }

  Future<String?> registerStudent({
    required String fullName,
    required String userId,
    required String phone,
    required String department,
    required String password,
    required String accountType,
  }) async {
    try {
      final callable = _functions.httpsCallable('registerStudentByAdmin');
      await callable.call({
        'fullName': fullName.trim(),
        'userId': userId.trim(),
        'phone': phone.trim(),
        'department': department.trim(),
        'password': password.trim(),
        'accountType': accountType.trim().isEmpty ? AppRoles.user : accountType.trim(),
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      return cleanErrorMessage(
        e,
        fallback: tr('auth.could_not_register_user_try_again'),
      );
    } catch (e) {
      return cleanErrorMessage(
        e,
        fallback: tr('auth.could_not_register_user_try_again'),
      );
    }
  }
}
