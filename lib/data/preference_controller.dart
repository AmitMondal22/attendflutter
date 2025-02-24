import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenceController extends GetxController {
  SharedPreferences? _preferences;

  static const _hasViewedOnboardingKey = 'HAS_VIEWED_ONBOARDING';

  //--- AFTER LOGIN ----------------------------

  static const _userId = "USER_ID";
  static const _accessToken = "ACCESS_TOKEN";
  static const _loginStatus = "LOGIN_STATUS";

  @override
  void onReady() async {
    _preferences = await SharedPreferences.getInstance();
    super.onReady();
  }

//----------------------------------------------------------------------------------------------
  // Method to check if the user has viewed the one-time screen (e.g., onboarding)
  bool get hasViewedOnboarding =>
      _preferences?.getBool(_hasViewedOnboardingKey) ?? false;

  // Method to set the flag once the user has viewed the one-time screen
  Future<bool> setHasViewedOnboarding(bool hasViewed) {
    return _preferences!.setBool(_hasViewedOnboardingKey, hasViewed);
  }

  bool get isClockedIn => _preferences?.getBool("isClockedIn") ?? false;

  // Method to set the flag once the user has viewed the one-time screen
  Future<bool> setIsClockedIn(bool isClockedIn) {
    return _preferences!.setBool("_hasViewedOnboardingKey", isClockedIn);
  }

  // Example usage: Call this method after the user finishes the onboarding or one-time screen
  Future<void> completeOnboarding() async {
    await setHasViewedOnboarding(true);
  }

  //---------- WITH LOGIN PREF -------

  Future<bool> setAccessToken(String token) {
    return _preferences!.setString(_accessToken, token);
  }

  String get accessTokens => _preferences!.getString(_accessToken) ?? "";

  String get userID => _preferences!.getString(_userId) ?? "";

  Future<bool> userId(String id) {
    return _preferences!.setString(_userId, id);
  }

  Future<bool> changeLoginState(bool state) {
    return _preferences!.setBool(_loginStatus, state);
  }

  bool get loginStatus {
    return _preferences!.getBool(_loginStatus) ?? false;
  }

  Future<void> clearLoginCred() async {
    await _preferences?.remove(_accessToken);
  }

  Future<void> clearAll() async {
    await _preferences?.clear();
  }
}
