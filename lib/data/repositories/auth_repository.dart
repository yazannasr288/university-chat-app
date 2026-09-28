import '../../core/constants/app_account_statuses.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth;
  final CollectionReference<Map<String, dynamic>> _users;
  final FirebaseFunctions _functions;

  AuthRepository({
    FirebaseAuth? auth,
    CollectionReference<Map<String, dynamic>>? usersCollection,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _users = usersCollection ?? FirebaseFirestore.instance.collection('users'),
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  String _buildEmailFromUserId(String userId) => '${userId.trim()}@wpu.edu';

  String _mapLoginError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return tr('auth.errors.invalid_credentials');
      case 'too-many-requests':
        return tr('auth.errors.too_many_attempts_try_later');
      case 'user-disabled':
        return tr('auth.errors.account_removed');
      default:
        return e.message ?? tr('auth.errors.login_failed');
    }
  }

  String _mapChangePasswordError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return tr('auth.errors.old_password_incorrect');
      case 'weak-password':
        return tr('auth.errors.new_password_weak');
      case 'requires-recent-login':
        return tr('auth.errors.reauth_required');
      default:
        return e.message ?? tr('auth.errors.change_password_failed');
    }
  }

  Future<String?> _refreshAuthSessionWithNewPassword({
    required String email,
    required String newPassword,
  }) async {
    FirebaseAuthException? lastAuthError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: newPassword,
        );
        await userCredential.user?.getIdToken(true);
        return null;
      } on FirebaseAuthException catch (e) {
        lastAuthError = e;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          continue;
        }
      } catch (_) {
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          continue;
        }
        return tr('auth.errors.login_unexpected');
      }
    }

    return lastAuthError == null
        ? tr('auth.errors.login_unexpected')
        : _mapLoginError(lastAuthError);
  }

  Future<String?> login({required String userId, required String password}) async {
    try {
      final email = _buildEmailFromUserId(userId);
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password.trim(),
      );

      final uid = userCredential.user?.uid;
      if (uid == null) return tr('auth.errors.user_data_unavailable');

      final userDoc = await _users.doc(uid).get();
      if (!userDoc.exists) {
        await _auth.signOut();
        return tr('auth.errors.account_not_found_in_database');
      }

      final userData = userDoc.data() ?? {};
      final accountStatus = AppAccountStatuses.normalize(userData['accountStatus']);

      if (AppAccountStatuses.isSuspended(accountStatus)) {
        await _auth.signOut();
        return tr('auth.errors.account_suspended_by_admin');
      }

      if (AppAccountStatuses.isRemoved(accountStatus)) {
        await _auth.signOut();
        return tr('auth.errors.account_removed');
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return _mapLoginError(e);
    } catch (_) {
      return tr('auth.errors.login_unexpected');
    }
  }

  Future<String?> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return tr('auth.errors.no_signed_in_user');

    final email = user.email;
    if (email == null || email.isEmpty) {
      return tr('auth.errors.internal_email_unavailable');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: oldPassword.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      await user.getIdToken(true);

      final cleanNewPassword = newPassword.trim();
      final callable = _functions.httpsCallable('completePasswordChange');
      await callable.call({'newPassword': cleanNewPassword});

      return _refreshAuthSessionWithNewPassword(
        email: email,
        newPassword: cleanNewPassword,
      );
    } on FirebaseAuthException catch (e) {
      return _mapChangePasswordError(e);
    } on FirebaseFunctionsException catch (e) {
      final message = e.message?.trim();
      return message == null || message.isEmpty
          ? tr('auth.error_occurred_while_changing_password')
          : message;
    } catch (_) {
      return tr('auth.error_occurred_while_changing_password');
    }
  }
}
