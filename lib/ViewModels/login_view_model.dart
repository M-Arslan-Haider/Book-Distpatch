import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Models/LoginModels/login_models.dart';
import '../Repositories/LoginRepositories/login_repository.dart';
import '../constants.dart';

class LoginViewModel extends GetxController {
  final LoginRepository _loginRepository = Get.find<LoginRepository>();

  var isLoading = false.obs;
  var currentUser = Rx<LoginModels?>(null);
  var loginError = ''.obs;

  Future<bool> login(String employeeId, String password) async {
    try {
      isLoading.value = true;
      loginError.value = '';

      debugPrint('🔐 Attempting login for Employee ID: $employeeId');

      final employee = await _loginRepository.getUserByCredentials(employeeId, password);

      if (employee != null) {
        currentUser.value = employee;

        // Save to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefUserId, employeeId); // Store employee ID
        await prefs.setString(prefUserName, employee.emp_name ?? '');
        await prefs.setString(prefUserDesignation, employee.job ?? '');
        await prefs.setInt('emp_id', employee.emp_id ?? 0); // Store emp_id as integer
        await prefs.setBool(prefIsAuthenticated, true);

        debugPrint('✅ Login successful for Employee: ${employee.emp_name} (${employee.job})');
        debugPrint('   Employee ID: ${employee.emp_id}');
        return true;
      } else {
        loginError.value = 'Invalid Employee ID or Password';
        debugPrint('❌ Login failed: Invalid credentials for Employee ID: $employeeId');
        return false;
      }
    } catch (e) {
      loginError.value = 'Login failed: ${e.toString()}';
      debugPrint('❌ Login error: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  String getHomeRoute() {
    debugPrint('📍 All users redirected to Home Screen');
    return routeHome;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefUserId);
    await prefs.remove(prefUserName);
    await prefs.remove(prefUserDesignation);
    await prefs.remove('emp_id');
    await prefs.setBool(prefIsAuthenticated, false);
    currentUser.value = null;
    Get.offAllNamed(routeCodeScreen);
  }
}