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
// //   Future<void> _loadCurrentCompany() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     currentCompanyCode.value = prefs.getString(prefCompanyCode) ?? '';
// //
// //     if (currentCompanyCode.value.isNotEmpty) {
// //       DBHelper.setCompanyCode(currentCompanyCode.value);
// //       debugPrint('🏢 Loaded company: ${currentCompanyCode.value}');
// //     }
// //   }
// //
// //   Future<bool> login(String employeeId, String password) async {
// //     try {
// //       isLoading.value = true;
// //       loginError.value = '';
// //
// //       debugPrint('🔐 Attempting login for Employee ID: $employeeId');
// //       debugPrint('🏢 Company: ${currentCompanyCode.value}');
// //
// //       final employee = await _loginRepository.getUserByCredentials(employeeId, password);
// //
// //       if (employee != null) {
// //         // ✅ No company_code check needed here
// //         // Backend SQL already ensured: WHERE company_code = :company_code
// //         // Jo bhi result aaya woh is company ka hi employee hai
// //
// //         currentUser.value = employee;
// //
// //         final prefs = await SharedPreferences.getInstance();
// //         await prefs.setString(prefUserId, employeeId);
// //         await prefs.setString(prefUserName, employee.emp_name ?? '');
// //         await prefs.setString(prefUserDesignation, employee.job ?? '');
// //         await prefs.setInt('emp_id', employee.emp_id ?? 0);
// //         await prefs.setBool(prefIsAuthenticated, true);
// //
// //         // GEO_FENCING value save karo future use ke liye
// //         await prefs.setString('geoFencing', employee.geo_fencing ?? '');
// //
// //         final companyCode = prefs.getString(prefCompanyCode) ?? '';
// //         if (companyCode.isNotEmpty) {
// //           DBHelper.setCompanyCode(companyCode);
// //           currentCompanyCode.value = companyCode;
// //         }
// //
// //         debugPrint('✅ Login successful for: ${employee.emp_name} (${employee.job})');
// //         debugPrint('   GEO Fencing: ${employee.geo_fencing}');
// //         return true;
// //       } else {
// //         loginError.value = 'Invalid Employee ID or Password';
// //         return false;
// //       }
// //     } catch (e) {
// //       loginError.value = 'Login failed: ${e.toString()}';
// //       return false;
// //     } finally {
// //       isLoading.value = false;
// //     }
// //   }
// //
// //   String getHomeRoute() {
// //     return routeHome;
// //   }
// //
// //   Future<void> logout() async {
// //     final prefs = await SharedPreferences.getInstance();
// //
// //     await prefs.remove(prefUserId);
// //     await prefs.remove(prefUserName);
// //     await prefs.remove(prefUserDesignation);
// //     await prefs.remove('emp_id');
// //     await prefs.remove('geoFencing');
// //     await prefs.setBool(prefIsAuthenticated, false);
// //
// //     // ✅ Company code mat hatao - next login ke liye rehne do
// //     currentUser.value = null;
// //
// //     Get.offAllNamed(routeCodeScreen);
// //   }
// // }
// import 'package:flutter/foundation.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Database/db_helper.dart';
// import '../Models/LoginModels/login_models.dart';
// import '../Repositories/LoginRepositories/login_repository.dart';
// import '../constants.dart';
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
//     currentCompanyCode.value = prefs.getString(prefCompanyCode) ?? '';
//
//     if (currentCompanyCode.value.isNotEmpty) {
//       DBHelper.setCompanyCode(currentCompanyCode.value);
//       debugPrint('🏢 Loaded company: ${currentCompanyCode.value}');
//     }
//   }
//
//   Future<bool> login(String employeeId, String password) async {
//     try {
//       isLoading.value = true;
//       loginError.value = '';
//
//       debugPrint('🔐 Attempting login for Employee ID: $employeeId');
//       debugPrint('🏢 Company: ${currentCompanyCode.value}');
//
//       final employee = await _loginRepository.getUserByCredentials(employeeId, password);
//
//       if (employee != null) {
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
//         final companyCode = prefs.getString(prefCompanyCode) ?? '';
//         if (companyCode.isNotEmpty) {
//           DBHelper.setCompanyCode(companyCode);
//           currentCompanyCode.value = companyCode;
//         }
//
//         debugPrint('✅ Login successful for: ${employee.emp_name} (${employee.job})');
//         debugPrint('   GEO Fencing: ${employee.geo_fencing}');
//
//         // ── Pre-fetch & cache locations while internet is available ──────────
//         // This runs in background after login succeeds; we don't await it so
//         // it never blocks navigation. If it fails the cached data stays intact.
//         _loginRepository
//             .fetchAndCacheLocations(employeeId, currentCompanyCode.value)
//             .catchError((e) {
//           debugPrint('⚠️ Background location cache failed: $e');
//           return null; // keep Dart happy with the Future<void> type
//         });
//
//         return true;
//       } else {
//         loginError.value = 'Invalid Employee ID or Password';
//         return false;
//       }
//     } catch (e) {
//       loginError.value = 'Login failed: ${e.toString()}';
//       return false;
//     } finally {
//       isLoading.value = false;
//     }
//   }
//
//   String getHomeRoute() {
//     return routeHome;
//   }
//
//   Future<void> logout() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     await prefs.remove(prefUserId);
//     await prefs.remove(prefUserName);
//     await prefs.remove(prefUserDesignation);
//     await prefs.remove('emp_id');
//     await prefs.remove('geoFencing');
//     await prefs.setBool(prefIsAuthenticated, false);
//
//     // ✅ Company code mat hatao - next login ke liye rehne do
//     // ✅ cached_locations bhi rehne do - next login pe overwrite ho jayega
//     currentUser.value = null;
//
//     Get.offAllNamed(routeCodeScreen);
//   }
// }

///end time
//
// import 'package:flutter/foundation.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Database/db_helper.dart';
// import '../Models/LoginModels/login_models.dart';
// import '../Repositories/LoginRepositories/login_repository.dart';
// import '../constants.dart';
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
//     currentCompanyCode.value = prefs.getString(prefCompanyCode) ?? '';
//
//     if (currentCompanyCode.value.isNotEmpty) {
//       DBHelper.setCompanyCode(currentCompanyCode.value);
//       debugPrint('🏢 Loaded company: ${currentCompanyCode.value}');
//     }
//   }
//
//   Future<bool> login(String employeeId, String password) async {
//     try {
//       isLoading.value = true;
//       loginError.value = '';
//
//       debugPrint('🔐 Attempting login for Employee ID: $employeeId');
//       debugPrint('🏢 Company: ${currentCompanyCode.value}');
//
//       final employee = await _loginRepository.getUserByCredentials(employeeId, password);
//
//       if (employee != null) {
//         // ✅ No company_code check needed here
//         // Backend SQL already ensured: WHERE company_code = :company_code
//         // Jo bhi result aaya woh is company ka hi employee hai
//
//         currentUser.value = employee;
//
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString(prefUserId, employeeId);
//         await prefs.setString(prefUserName, employee.emp_name ?? '');
//         await prefs.setString(prefUserDesignation, employee.job ?? '');
//         await prefs.setInt('emp_id', employee.emp_id ?? 0);
//         await prefs.setBool(prefIsAuthenticated, true);
//
//         // GEO_FENCING value save karo future use ke liye
//         await prefs.setString('geoFencing', employee.geo_fencing ?? '');
//
//         final companyCode = prefs.getString(prefCompanyCode) ?? '';
//         if (companyCode.isNotEmpty) {
//           DBHelper.setCompanyCode(companyCode);
//           currentCompanyCode.value = companyCode;
//         }
//
//         debugPrint('✅ Login successful for: ${employee.emp_name} (${employee.job})');
//         debugPrint('   GEO Fencing: ${employee.geo_fencing}');
//         return true;
//       } else {
//         loginError.value = 'Invalid Employee ID or Password';
//         return false;
//       }
//     } catch (e) {
//       loginError.value = 'Login failed: ${e.toString()}';
//       return false;
//     } finally {
//       isLoading.value = false;
//     }
//   }
//
//   String getHomeRoute() {
//     return routeHome;
//   }
//
//   Future<void> logout() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     await prefs.remove(prefUserId);
//     await prefs.remove(prefUserName);
//     await prefs.remove(prefUserDesignation);
//     await prefs.remove('emp_id');
//     await prefs.remove('geoFencing');
//     await prefs.setBool(prefIsAuthenticated, false);
//
//     // ✅ Company code mat hatao - next login ke liye rehne do
//     currentUser.value = null;
//
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
    currentCompanyCode.value = prefs.getString(prefCompanyCode) ?? '';

    if (currentCompanyCode.value.isNotEmpty) {
      DBHelper.setCompanyCode(currentCompanyCode.value);
      debugPrint('🏢 Loaded company: ${currentCompanyCode.value}');
    }
  }

  Future<bool> login(String employeeId, String password) async {
    try {
      isLoading.value = true;
      loginError.value = '';

      debugPrint('🔐 Attempting login for Employee ID: $employeeId');
      debugPrint('🏢 Company: ${currentCompanyCode.value}');

      final employee = await _loginRepository.getUserByCredentials(employeeId, password);

      if (employee != null) {
        currentUser.value = employee;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefUserId, employeeId);
        await prefs.setString(prefUserName, employee.emp_name ?? '');
        await prefs.setString(prefUserDesignation, employee.job ?? '');
        await prefs.setInt('emp_id', employee.emp_id ?? 0);
        await prefs.setBool(prefIsAuthenticated, true);
        await prefs.setString('geoFencing', employee.geo_fencing ?? '');

        final companyCode = prefs.getString(prefCompanyCode) ?? '';
        if (companyCode.isNotEmpty) {
          DBHelper.setCompanyCode(companyCode);
          currentCompanyCode.value = companyCode;
        }

        debugPrint('✅ Login successful for: ${employee.emp_name} (${employee.job})');
        debugPrint('   GEO Fencing: ${employee.geo_fencing}');

        // ── Pre-fetch & cache locations while internet is available ──────────
        // This runs in background after login succeeds; we don't await it so
        // it never blocks navigation. If it fails the cached data stays intact.
        _loginRepository
            .fetchAndCacheLocations(employeeId, currentCompanyCode.value)
            .catchError((e) {
          debugPrint('⚠️ Background location cache failed: $e');
          return null; // keep Dart happy with the Future<void> type
        });

        // ── Pre-fetch & cache employee end time for offline clock-out check ──
        // Same pattern: background, non-blocking, safe to fail.
        _loginRepository
            .fetchAndCacheEndTime(employeeId, currentCompanyCode.value)
            .catchError((e) {
          debugPrint('⚠️ Background end time cache failed: $e');
          return null;
        });

        return true;
      } else {
        loginError.value = 'Invalid Employee ID or Password';
        return false;
      }
    } catch (e) {
      loginError.value = 'Login failed: ${e.toString()}';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  String getHomeRoute() {
    return routeHome;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(prefUserId);
    await prefs.remove(prefUserName);
    await prefs.remove(prefUserDesignation);
    await prefs.remove('emp_id');
    await prefs.remove('geoFencing');
    await prefs.setBool(prefIsAuthenticated, false);

    // ✅ Company code mat hatao - next login ke liye rehne do
    // ✅ cached_locations bhi rehne do - next login pe overwrite ho jayega
    currentUser.value = null;

    Get.offAllNamed(routeCodeScreen);
  }
}