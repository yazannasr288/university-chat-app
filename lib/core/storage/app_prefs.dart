import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../permissions/app_roles.dart';

class AppPrefs {
  AppPrefs._();

  static SharedPreferences? _prefs;
  static const _keyForcedLogoutReason = 'forcedLogoutReason';

  static final ValueNotifier<ThemeMode> themeModeNotifier =
  ValueNotifier<ThemeMode>(ThemeMode.light);
  static Future<void> saveForcedLogoutReason(String reason) async {
    await instance.setString(_keyForcedLogoutReason, reason);
  }

  static Future<String?> consumeForcedLogoutReason() async {
    final value = instance.getString(_keyForcedLogoutReason);
    if (value != null && value.isNotEmpty) {
      await instance.remove(_keyForcedLogoutReason);
      return value;
    }
    return null;
  }
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    themeModeNotifier.value = _readThemeMode();
  }

  static SharedPreferences get instance {
    if (_prefs == null) {
      throw Exception('Call AppPrefs.init() before using AppPrefs');
    }
    return _prefs!;
  }

  static const _keyUserName = 'userName';
  static const _keyUserEmail = 'userEmail';
  static const _keyUserRole = 'userRole';
  static const _keyUserAccountType = 'userAccountType';
  static const _keyUserDepartment = 'userDepartment';
  static const _keyUserProfilePic = 'userProfilePic';
  static const _keyThemeMode = 'themeMode';

  static String get userName => instance.getString(_keyUserName) ?? '';
  static String get userEmail => instance.getString(_keyUserEmail) ?? '';
  static String get userRole => instance.getString(_keyUserRole) ?? AppRoles.user;
  static String get userAccountType =>
      instance.getString(_keyUserAccountType) ?? AppRoles.user;
  static String get userDepartment => instance.getString(_keyUserDepartment) ?? '';
  static String get userProfilePic => instance.getString(_keyUserProfilePic) ?? '';

  static ThemeMode _readThemeMode() {
    final raw = instance.getString(_keyThemeMode) ?? 'light';

    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.light;
    }
  }

  static ThemeMode get themeMode => themeModeNotifier.value;
  static bool get isDarkMode => themeMode == ThemeMode.dark;

  static Future<void> setThemeMode(ThemeMode mode) async {
    final raw = mode == ThemeMode.dark ? 'dark' : 'light';
    await instance.setString(_keyThemeMode, raw);
    themeModeNotifier.value = mode;
  }

  static Future<void> toggleTheme(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }

  static Future<void> saveUserSession({
    required String name,
    required String email,
    required String role,
    String accountType = AppRoles.user,
    String department = '',
    String? profilepic,
  }) async {
    await instance.setString(_keyUserName, name);
    await instance.setString(_keyUserEmail, email);
    await instance.setString(_keyUserRole, role);
    await instance.setString(_keyUserAccountType, accountType);
    await instance.setString(_keyUserDepartment, department);

    if (profilepic != null) {
      await instance.setString(_keyUserProfilePic, profilepic);
    }
  }

  static Future<void> clear() async {
    await instance.remove(_keyUserName);
    await instance.remove(_keyUserEmail);
    await instance.remove(_keyUserRole);
    await instance.remove(_keyUserAccountType);
    await instance.remove(_keyUserDepartment);
    await instance.remove(_keyUserProfilePic);
  }
}
