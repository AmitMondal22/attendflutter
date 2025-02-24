import 'package:attend_master/utils/colorful_log.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../data/preference_controller.dart';
import '../../navigation/route_names.dart';

class LoginController extends GetxController {
  final _prefs = Get.find<PreferenceController>();

  final Dio _dio = Dio();

  @override
  void onReady() async {
    await Permission.notification.request();
    super.onReady();
  }

  Future<void> login(String email, String password) async {
    try {
      final response = await _dio.post(
        'http://attendance.iotblitz.com/auth/login',
        data: {
          "email": email,
          "password": password,
        },
        options: Options(headers: {"Accept": "application/json"}),
      );

      ColorLog.devLog(response.data);

      if (response.statusCode == 200) {
        _prefs.setAccessToken(response.data['data']['token']);
        _prefs.changeLoginState(true);

        Get.toNamed(RouteNames.home);

        Get.snackbar("Success", "Login successful!",
            snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar("Error", "Login failed: ${response.statusMessage}",
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      if (e is DioException) {
        ColorLog.yellow(
            "Dio Error: ${e.response?.statusCode} - ${e.response?.data}");
        Get.snackbar("Error",
            "Login failed: ${e.response?.statusMessage ?? e.toString()}",
            snackPosition: SnackPosition.BOTTOM);
      } else {
        ColorLog.yellow("Unexpected Error: $e");
        Get.snackbar("Error", "Unexpected error occurred: $e",
            snackPosition: SnackPosition.BOTTOM);
      }
    }
  }
}
