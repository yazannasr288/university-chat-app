import 'dart:io';

import 'package:easy_localization/easy_localization.dart';

import '../../../core/storage/app_prefs.dart';
import '../../../core/utils/error_message.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/user_repository.dart';

class ProfileController {
  final UserRepository _userRepository;

  AppUser? user;
  bool isLoading = false;
  bool isUploadingProfileImage = false;
  bool isDeletingProfileImage = false;
  String? errorMessage;

  ProfileController({
    UserRepository? userRepository,
  }) : _userRepository = userRepository ?? UserRepository();

  Future<void> _cacheUserSession(AppUser latestUser) async {
    await AppPrefs.saveUserSession(
      name: latestUser.fullName,
      email: latestUser.email,
      role: latestUser.role,
      accountType: latestUser.accountType,
      department: latestUser.department,
      profilepic: latestUser.profilepic,
    );
  }

  Future<void> loadProfile() async {
    isLoading = true;
    errorMessage = null;

    try {
      user = await _userRepository.getCurrentUser();
      if (user == null) {
        errorMessage = 'profile.account_data_was_not_found'.tr();
      } else {
        await _cacheUserSession(user!);
      }
    } catch (_) {
      errorMessage = 'profile.could_not_load_profile_check_connection_try'.tr();
      user = null;
    } finally {
      isLoading = false;
    }
  }

  Future<String?> updateProfileImage({
    required File file,
    String? fileName,
  }) async {
    isUploadingProfileImage = true;
    errorMessage = null;

    try {
      await _userRepository.uploadCurrentUserProfileImage(
        file: file,
        fileName: fileName,
      );
      user = await _userRepository.getCurrentUser();
      if (user != null) {
        await _cacheUserSession(user!);
      }
      return null;
    } catch (error) {
      return cleanErrorMessage(
        error,
        fallback: tr('profile.photo_update_failed'),
      );
    } finally {
      isUploadingProfileImage = false;
    }
  }
  Future<String?> deleteProfileImage() async {
    isDeletingProfileImage = true;
    errorMessage = null;

    try {
      await _userRepository.deleteCurrentUserProfileImage();
      user = await _userRepository.getCurrentUser();
      if (user != null) {
        await _cacheUserSession(user!);
      }
      return null;
    } catch (error) {
      return cleanErrorMessage(
        error,
        fallback: tr('profile.photo_delete_failed'),
      );
    } finally {
      isDeletingProfileImage = false;
    }
  }

}
