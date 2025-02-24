import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../data/preference_controller.dart';
import '../../data/location_response_model.dart';
import '../../navigation/route_names.dart';
import '../../utils/colorful_log.dart';

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'location_tracking',
      initialNotificationTitle: 'Location Tracking',
      initialNotificationContent: 'Tracking in the background...',
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Initialize SharedPreferences in the background isolate
  final prefs = await SharedPreferences.getInstance();
  final String? accessToken = prefs.getString("ACCESS_TOKEN");

  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) {
      service.stopSelf();
    });
  }

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    Dio dio = Dio();
    try {
      await dio.post(
        'http://attendance.iotblitz.com/api/location/track',
        data: {
          "latitude": position.latitude,
          "longitude": position.longitude,
        },
        options: _getAuthHeaders(accessToken),
      );
      print("✅ Location sent: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print(accessToken);
      print("❌ Error sending location: $e");
    }
  });
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  print("✅ iOS background execution started!");
  return true;
}

Options _getAuthHeaders(String? token) => Options(
      headers: {
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

class HomeController extends GetxController {
  final Dio _dio = Dio();
  final _prefs = Get.find<PreferenceController>();
  RxString currentTime = ''.obs;
  Rx<SettingsData?> settingsData = Rx<SettingsData?>(null);
  Rx<ClockInDataObj?> clockInDataObj = Rx<ClockInDataObj?>(null);
  Rx<ClockOutDataObj?> clockOutDataObj = Rx<ClockOutDataObj?>(null);
  RxBool clockInClockOutDataLoading = true.obs;

  bool isWithinRadius(double userLat, double userLon) {
    if (settingsData.value == null) return false;

    const double earthRadius = 6371000;
    double toRadians(double degrees) => degrees * (pi / 180);
    double dLat = toRadians(userLat - settingsData.value!.latitude);
    double dLon = toRadians(userLon - settingsData.value!.longitude);
    double lat1 = toRadians(settingsData.value!.latitude);
    double lat2 = toRadians(userLat);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;
    return distance <= settingsData.value!.redus;
  }

  @override
  void onInit() {
    super.onInit();
    _getSettings();
    _clockInCheck();
    _clockOutCheck();
  }

  @override
  void onReady() {
    initializeService();
    super.onReady();
  }

  void startBackgroundService() async {
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();

    if (!isRunning) {
      service.startService();
      print("📍 Background location tracking started...");
    }
  }

  void stopBackgroundService() {
    // FlutterBackgroundService().invoke("stopService");
    print("❌ Background service stopped.");
  }

  Future<void> clockIn() async {
    try {
      if (!await checkIsWithinCompanyRadius()) return;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            AndroidSettings(accuracy: LocationAccuracy.bestForNavigation),
      );

      final response = await _dio.post(
        'http://attendance.iotblitz.com/api/clock_in',
        options: _getAuthHeaders(_prefs.accessTokens),
        data: {
          "latitude": position.latitude,
          "longitude": position.longitude,
          "location_setting": settingsData.value?.settingsId ?? 0,
        },
      );

      if (response.statusCode == 200) {
        _showSnackbar(
            "Success", response.data['data']['message']?.toString() ?? "");

        startBackgroundService(); // Start location tracking in the background

        await Future.wait([_clockInCheck(), _clockOutCheck()]);
      }
    } catch (e) {
      _handleError("Clock in failed", e);
    }
  }

  Future<void> clockOut() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(accuracy: LocationAccuracy.high),
      );

      final response = await _dio.post(
        'http://attendance.iotblitz.com/api/clock_out',
        options: _getAuthHeaders(_prefs.accessTokens),
        data: {
          "latitude": position.latitude,
          "longitude": position.longitude,
          "location_setting": settingsData.value?.settingsId ?? 0,
        },
      );

      if (response.statusCode == 200) {
        _showSnackbar(
            "Success", response.data['data']['message']?.toString() ?? "");

        stopBackgroundService(); // Stop tracking when clocking out

        await Future.wait([_clockOutCheck(), _clockInCheck()]);
      }
    } catch (e) {
      _handleError("Clock out failed", e);
    }
  }

  Future<bool> checkIsWithinCompanyRadius() async {
    if (settingsData.value == null) {
      _showSnackbar("Error", "Company location settings not available");
      return false;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(accuracy: LocationAccuracy.high),
      );

      bool isWithin = isWithinRadius(position.latitude, position.longitude);
      if (!isWithin) {
        _showSnackbar("Error", "You are not within the company radius!");
      }
      return isWithin;
    } catch (e) {
      _handleError("Location check failed", e);
      return false;
    }
  }

  Future<void> _getSettings() async {
    try {
      final response = await _dio.post(
        'http://attendance.iotblitz.com/api/location/settings',
        options: _getAuthHeaders(_prefs.accessTokens),
      );

      if (response.statusCode == 200) {
        settingsData.value =
            LocationSettingResponse.fromJson(response.data).data?.settingsData;
      }
    } catch (e) {
      _handleError("Failed to get settings", e);
    }
  }

  Future<void> _clockInCheck() async {
    try {
      final response = await _dio.post(
        'http://attendance.iotblitz.com/api/clock_in/check',
        options: _getAuthHeaders(_prefs.accessTokens),
      );
      clockInDataObj.value = ClockInResponse.fromJson(response.data).data;
    } catch (e) {
      _handleError("Clock-in check failed", e);
    }
  }

  Future<void> _clockOutCheck() async {
    try {
      final response = await _dio.post(
        'http://attendance.iotblitz.com/api/clock_in/check_out',
        options: _getAuthHeaders(_prefs.accessTokens),
      );
      clockOutDataObj.value = ClockOutResponse.fromJson(response.data).data;
    } catch (e) {
      _handleError("Clock-out check failed", e);
    }
  }

  void logout() {
    _prefs.clearLoginCred();
    _prefs.changeLoginState(false);
    stopBackgroundService(); // Stop tracking when clocking out
    _showSnackbar("Success", "Logout successful!");
    Get.offAllNamed(RouteNames.login);
  }

  void _showSnackbar(String title, String message) {
    if (Get.isSnackbarOpen) Get.back();
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
    );
  }

  void _handleError(String message, dynamic error) {
    String errorMessage = message;
    if (error is DioException) {
      errorMessage += ": ${error.response?.statusCode ?? 'No response'}";
      ColorLog.yellow("Dio Error: ${error.response?.data}");
    } else {
      errorMessage += ": ${error.toString()}";
    }
    ColorLog.yellow(errorMessage);
    _showSnackbar("Error", errorMessage);
  }
}
