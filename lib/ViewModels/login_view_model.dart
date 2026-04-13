// //
// //
// // import 'package:flutter/foundation.dart';
// // import 'package:get/get.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import '../Database/db_helper.dart';
// // import '../Models/LoginModels/login_models.dart';
// // import '../Repositories/LoginRepositories/login_repository.dart';
// // import '../constants.dart';
// //
// // class LoginViewModel extends GetxController {
// //   final LoginRepository _loginRepository = Get.find<LoginRepository>();
// //
// //   var isLoading = false.obs;
// //   var currentUser = Rx<LoginModels?>(null);
// //   var loginError = ''.obs;
// //   var currentCompanyCode = ''.obs;
// //
// //   @override
// //   void onInit() {
// //     super.onInit();
// //     _loadCurrentCompany();
// //   }
// //
// //   // ── Load company code from every possible source ───────────────────────
// //   Future<void> _loadCurrentCompany() async {
// //     final prefs = await SharedPreferences.getInstance();
// //
// //     String? code = prefs.getString(prefCompanyCode);
// //     if (code == null || code.isEmpty) code = DBHelper.getCompanyCode();
// //     if (code == null || code.isEmpty) {
// //       code = prefs.getString('cached_employees_company');
// //     }
// //
// //     currentCompanyCode.value = code ?? '';
// //
// //     if (currentCompanyCode.value.isNotEmpty) {
// //       DBHelper.setCompanyCode(currentCompanyCode.value);
// //       debugPrint('🏢 Company loaded: ${currentCompanyCode.value}');
// //     } else {
// //       debugPrint('⚠️ No company code found anywhere');
// //     }
// //   }
// //
// //   /// Can be called from LoginScreen on resume / hot-reload.
// //   Future<void> refreshCompanyCode() async {
// //     await _loadCurrentCompany();
// //     debugPrint('🔄 Company code refreshed: ${currentCompanyCode.value}');
// //   }
// //
// //   // ── Main login method ──────────────────────────────────────────────────
// //   Future<bool> login(String employeeId, String password) async {
// //     try {
// //       isLoading.value = true;
// //       loginError.value = '';
// //
// //       // Ensure company code is available
// //       if (currentCompanyCode.value.isEmpty) {
// //         final prefs = await SharedPreferences.getInstance();
// //         final fresh =
// //             prefs.getString(prefCompanyCode) ?? DBHelper.getCompanyCode();
// //         if (fresh != null && fresh.isNotEmpty) {
// //           currentCompanyCode.value = fresh;
// //         } else {
// //           loginError.value =
// //           'Company code not set. Please go back and enter your company code.';
// //           return false;
// //         }
// //       }
// //
// //       debugPrint(
// //           '🔐 Login attempt | emp_id=$employeeId | company=${currentCompanyCode.value}');
// //
// //       final result =
// //       await _loginRepository.getUserByCredentials(employeeId, password);
// //
// //       if (result.isSuccess) {
// //         final employee = result.user!;
// //         currentUser.value = employee;
// //
// //         final prefs = await SharedPreferences.getInstance();
// //         await prefs.setString(prefUserId, employeeId);
// //         await prefs.setString(prefUserName, employee.emp_name ?? '');
// //         await prefs.setString(prefUserDesignation, employee.job ?? '');
// //         await prefs.setInt('emp_id', employee.emp_id ?? 0);
// //         await prefs.setBool(prefIsAuthenticated, true);
// //         await prefs.setString('geoFencing', employee.geo_fencing ?? '');
// //
// //         debugPrint(
// //             '✅ Login success: ${employee.emp_name} (${employee.job})');
// //
// //         // Background: cache locations (non-blocking)
// //         _loginRepository
// //             .fetchAndCacheLocations(employeeId, currentCompanyCode.value)
// //             .catchError((e) {
// //           debugPrint('⚠️ Background location cache failed: $e');
// //           return null;
// //         });
// //
// //         // Background: cache end time (non-blocking)
// //         _loginRepository
// //             .fetchAndCacheEndTime(employeeId, currentCompanyCode.value)
// //             .catchError((e) {
// //           debugPrint('⚠️ Background end time cache failed: $e');
// //           return null;
// //         });
// //
// //         return true;
// //       }
// //
// //       // ── Set a clear, user-friendly error based on the exact failure ────
// //       switch (result.status) {
// //         case LoginStatus.notInCompany:
// //           loginError.value =
// //           'Employee ID "$employeeId" does not belong to company '
// //               '"${result.companyCode ?? currentCompanyCode.value}".\n'
// //               'Please check your Employee ID or contact your administrator.';
// //           break;
// //
// //         case LoginStatus.wrongPassword:
// //           loginError.value =
// //           'Incorrect password. Please try again.';
// //           break;
// //
// //         case LoginStatus.noCompany:
// //           loginError.value =
// //           'Company code not set. Please go back and enter your company code.';
// //           break;
// //
// //         case LoginStatus.networkError:
// //           loginError.value =
// //           'Could not connect to the server. Please check your internet connection and try again.';
// //           break;
// //
// //         default:
// //           loginError.value = 'Login failed. Please try again.';
// //       }
// //
// //       return false;
// //     } catch (e) {
// //       loginError.value =
// //       'An unexpected error occurred. Please try again.';
// //       debugPrint('❌ Login exception: $e');
// //       return false;
// //     } finally {
// //       isLoading.value = false;
// //     }
// //   }
// //
// //   String getHomeRoute() => routeHome;
// //
// //   Future<void> logout() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     await prefs.remove(prefUserId);
// //     await prefs.remove(prefUserName);
// //     await prefs.remove(prefUserDesignation);
// //     await prefs.remove('emp_id');
// //     await prefs.remove('geoFencing');
// //     await prefs.setBool(prefIsAuthenticated, false);
// //     // Keep company code + cached employees so next login is fast
// //     currentUser.value = null;
// //     Get.offAllNamed(routeCodeScreen);
// //   }
// // }
//
// import 'package:flutter/foundation.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Database/db_helper.dart';
// import '../Models/LoginModels/login_models.dart';
// import '../Repositories/LoginRepositories/login_repository.dart';
// import '../constants.dart';
// import '../ViewModels/attendance_view_model.dart';
//
// class LoginViewModel extends GetxController {
//   final LoginRepository _loginRepository = Get.find<LoginRepository>();
//
//   var isLoading = false.obs;
//   var currentUser = Rx<LoginModels?>(null);
//   var loginError = ''.obs;
//   var currentCompanyCode = ''.obs;
//
//   @override
//   void onInit() {
//     super.onInit();
//     _loadCurrentCompany();
//   }
//
//   Future<void> _loadCurrentCompany() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     String? code = prefs.getString(prefCompanyCode);
//     if (code == null || code.isEmpty) code = DBHelper.getCompanyCode();
//     if (code == null || code.isEmpty) {
//       code = prefs.getString('cached_employees_company');
//     }
//
//     currentCompanyCode.value = code ?? '';
//
//     if (currentCompanyCode.value.isNotEmpty) {
//       DBHelper.setCompanyCode(currentCompanyCode.value);
//       debugPrint('🏢 Company loaded: ${currentCompanyCode.value}');
//     } else {
//       debugPrint('⚠️ No company code found anywhere');
//     }
//   }
//
//   Future<void> refreshCompanyCode() async {
//     await _loadCurrentCompany();
//     debugPrint('🔄 Company code refreshed: ${currentCompanyCode.value}');
//   }
//
//   Future<bool> login(String employeeId, String password) async {
//     try {
//       isLoading.value = true;
//       loginError.value = '';
//
//       if (currentCompanyCode.value.isEmpty) {
//         final prefs = await SharedPreferences.getInstance();
//         final fresh = prefs.getString(prefCompanyCode) ?? DBHelper.getCompanyCode();
//         if (fresh != null && fresh.isNotEmpty) {
//           currentCompanyCode.value = fresh;
//         } else {
//           loginError.value = 'Company code not set. Please go back and enter your company code.';
//           return false;
//         }
//       }
//
//       debugPrint('🔐 Login attempt | emp_id=$employeeId | company=${currentCompanyCode.value}');
//
//       final result = await _loginRepository.getUserByCredentials(employeeId, password);
//
//       if (result.isSuccess) {
//         final employee = result.user!;
//         currentUser.value = employee;
//
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString(prefUserId, employeeId);
//         await prefs.setString(prefUserName, employee.emp_name ?? '');
//         await prefs.setString(prefUserDesignation, employee.job ?? '');
//         await prefs.setInt('emp_id', employee.emp_id ?? 0);
//         await prefs.setBool(prefIsAuthenticated, true);
//         await prefs.setString('geoFencing', employee.geo_fencing ?? '');
//
//         debugPrint('✅ Login success: ${employee.emp_name} (${employee.job})');
//
//         final attendanceVM = Get.find<AttendanceViewModel>();
//
//         final wasRestored = await attendanceVM.checkAndRestoreAttendanceState(
//           empId: employeeId,
//           companyCode: currentCompanyCode.value,
//         );
//
//         if (wasRestored) {
//           debugPrint('🔄 [LoginVM] Attendance state restored for returning employee');
//         } else {
//           debugPrint('✨ [LoginVM] New employee - will start fresh');
//           await attendanceVM.initSerialCounter();
//         }
//
//         _loginRepository
//             .fetchAndCacheLocations(employeeId, currentCompanyCode.value)
//             .catchError((e) {
//           debugPrint('⚠️ Background location cache failed: $e');
//           return null;
//         });
//
//         _loginRepository
//             .fetchAndCacheEndTime(employeeId, currentCompanyCode.value)
//             .catchError((e) {
//           debugPrint('⚠️ Background end time cache failed: $e');
//           return null;
//         });
//
//         return true;
//       }
//
//       switch (result.status) {
//         case LoginStatus.notInCompany:
//           loginError.value = 'Employee ID "$employeeId" does not belong to company '
//               '"${result.companyCode ?? currentCompanyCode.value}".\n'
//               'Please check your Employee ID or contact your administrator.';
//           break;
//         case LoginStatus.wrongPassword:
//           loginError.value = 'Incorrect password. Please try again.';
//           break;
//         case LoginStatus.noCompany:
//           loginError.value = 'Company code not set. Please go back and enter your company code.';
//           break;
//         case LoginStatus.networkError:
//           loginError.value = 'Could not connect to the server. Please check your internet connection and try again.';
//           break;
//         default:
//           loginError.value = 'Login failed. Please try again.';
//       }
//
//       return false;
//     } catch (e) {
//       loginError.value = 'An unexpected error occurred. Please try again.';
//       debugPrint('❌ Login exception: $e');
//       return false;
//     } finally {
//       isLoading.value = false;
//     }
//   }
//
//   String getHomeRoute() => routeHome;
//
//   Future<void> logout() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove(prefUserId);
//     await prefs.remove(prefUserName);
//     await prefs.remove(prefUserDesignation);
//     await prefs.remove('emp_id');
//     await prefs.remove('geoFencing');
//     await prefs.setBool(prefIsAuthenticated, false);
//     currentUser.value = null;
//     Get.offAllNamed(routeCodeScreen);
//   }
// }

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Database/db_helper.dart';
import '../Models/LoginModels/login_models.dart';
import '../Repositories/LoginRepositories/login_repository.dart';
import '../constants.dart';
import '../ViewModels/attendance_view_model.dart';

class LoginViewModel extends GetxController {
  final LoginRepository _loginRepository = Get.find<LoginRepository>();

  var isLoading = false.obs;
  var currentUser = Rx<LoginModels?>(null);
  var loginError = ''.obs;
  var currentCompanyCode = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _loadCurrentCompany();
  }

  Future<void> _loadCurrentCompany() async {
    final prefs = await SharedPreferences.getInstance();

    String? code = prefs.getString(prefCompanyCode);
    if (code == null || code.isEmpty) code = DBHelper.getCompanyCode();
    if (code == null || code.isEmpty) {
      code = prefs.getString('cached_employees_company');
    }

    currentCompanyCode.value = code ?? '';

    if (currentCompanyCode.value.isNotEmpty) {
      DBHelper.setCompanyCode(currentCompanyCode.value);
      debugPrint('🏢 Company loaded: ${currentCompanyCode.value}');
    } else {
      debugPrint('⚠️ No company code found anywhere');
    }
  }

  Future<void> refreshCompanyCode() async {
    await _loadCurrentCompany();
    debugPrint('🔄 Company code refreshed: ${currentCompanyCode.value}');
  }

  Future<bool> login(String employeeId, String password) async {
    try {
      isLoading.value = true;
      loginError.value = '';

      if (currentCompanyCode.value.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final fresh = prefs.getString(prefCompanyCode) ?? DBHelper.getCompanyCode();
        if (fresh != null && fresh.isNotEmpty) {
          currentCompanyCode.value = fresh;
        } else {
          loginError.value = 'Company code not set. Please go back and enter your company code.';
          return false;
        }
      }

      debugPrint('🔐 Login attempt | emp_id=$employeeId | company=${currentCompanyCode.value}');

      final result = await _loginRepository.getUserByCredentials(employeeId, password);

      if (result.isSuccess) {
        final employee = result.user!;
        currentUser.value = employee;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefUserId, employeeId);
        await prefs.setString(prefUserName, employee.emp_name ?? '');
        await prefs.setString(prefUserDesignation, employee.job ?? '');
        await prefs.setInt('emp_id', employee.emp_id ?? 0);
        await prefs.setBool(prefIsAuthenticated, true);
        await prefs.setString('geoFencing', employee.geo_fencing ?? '');

        // Save new fields from login API
        await prefs.setString('cached_end_time', employee.end_time ?? '');
        await prefs.setString('cached_overtime', employee.over_time ?? '');
        await prefs.setString('cached_shift', employee.shift ?? '');

        debugPrint('✅ Login success: ${employee.emp_name} (${employee.job})');
        debugPrint('📦 Cached end_time: ${employee.end_time}, over_time: ${employee.over_time}, shift: ${employee.shift}');

        final attendanceVM = Get.find<AttendanceViewModel>();

        final wasRestored = await attendanceVM.checkAndRestoreAttendanceState(
          empId: employeeId,
          companyCode: currentCompanyCode.value,
        );

        if (wasRestored) {
          debugPrint('🔄 [LoginVM] Attendance state restored for returning employee');
        } else {
          debugPrint('✨ [LoginVM] New employee - will start fresh');
          await attendanceVM.initSerialCounter();
        }

        _loginRepository
            .fetchAndCacheLocations(employeeId, currentCompanyCode.value)
            .catchError((e) {
          debugPrint('⚠️ Background location cache failed: $e');
          return null;
        });

        return true;
      }

      switch (result.status) {
        case LoginStatus.notInCompany:
          loginError.value = 'Employee ID "$employeeId" does not belong to company '
              '"${result.companyCode ?? currentCompanyCode.value}".\n'
              'Please check your Employee ID or contact your administrator.';
          break;
        case LoginStatus.wrongPassword:
          loginError.value = 'Incorrect password. Please try again.';
          break;
        case LoginStatus.noCompany:
          loginError.value = 'Company code not set. Please go back and enter your company code.';
          break;
        case LoginStatus.networkError:
          loginError.value = 'Could not connect to the server. Please check your internet connection and try again.';
          break;
        default:
          loginError.value = 'Login failed. Please try again.';
      }

      return false;
    } catch (e) {
      loginError.value = 'An unexpected error occurred. Please try again.';
      debugPrint('❌ Login exception: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  String getHomeRoute() => routeHome;

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefUserId);
    await prefs.remove(prefUserName);
    await prefs.remove(prefUserDesignation);
    await prefs.remove('emp_id');
    await prefs.remove('geoFencing');
    await prefs.setBool(prefIsAuthenticated, false);
    currentUser.value = null;
    Get.offAllNamed(routeCodeScreen);
  }
}