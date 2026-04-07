// // // // //
// // // // // import 'package:flutter/foundation.dart';
// // // // // import 'package:get/get.dart';
// // // // // import 'package:shared_preferences/shared_preferences.dart';
// // // // // import '../Database/db_helper.dart';
// // // // // import '../Models/LoginModels/login_models.dart';
// // // // // import '../Repositories/LoginRepositories/login_repository.dart';
// // // // // import '../constants.dart';
// // // // //
// // // // // class LoginViewModel extends GetxController {
// // // // //   final LoginRepository _loginRepository = Get.find<LoginRepository>();
// // // // //
// // // // //   var isLoading = false.obs;
// // // // //   var currentUser = Rx<LoginModels?>(null);
// // // // //   var loginError = ''.obs;
// // // // //   var currentCompanyCode = ''.obs;
// // // // //
// // // // //   @override
// // // // //   void onInit() {
// // // // //     super.onInit();
// // // // //     _loadCurrentCompany();
// // // // //   }
// // // // //
// // // // //   Future<void> _loadCurrentCompany() async {
// // // // //     final prefs = await SharedPreferences.getInstance();
// // // // //     currentCompanyCode.value = prefs.getString(prefCompanyCode) ?? '';
// // // // //
// // // // //     if (currentCompanyCode.value.isNotEmpty) {
// // // // //       DBHelper.setCompanyCode(currentCompanyCode.value);
// // // // //       debugPrint('🏢 Loaded company: ${currentCompanyCode.value}');
// // // // //     }
// // // // //   }
// // // // //
// // // // //   Future<bool> login(String employeeId, String password) async {
// // // // //     try {
// // // // //       isLoading.value = true;
// // // // //       loginError.value = '';
// // // // //
// // // // //       debugPrint('🔐 Attempting login for Employee ID: $employeeId');
// // // // //       debugPrint('🏢 Company: ${currentCompanyCode.value}');
// // // // //
// // // // //       final employee = await _loginRepository.getUserByCredentials(employeeId, password);
// // // // //
// // // // //       if (employee != null) {
// // // // //         // ✅ No company_code check needed here
// // // // //         // Backend SQL already ensured: WHERE company_code = :company_code
// // // // //         // Jo bhi result aaya woh is company ka hi employee hai
// // // // //
// // // // //         currentUser.value = employee;
// // // // //
// // // // //         final prefs = await SharedPreferences.getInstance();
// // // // //         await prefs.setString(prefUserId, employeeId);
// // // // //         await prefs.setString(prefUserName, employee.emp_name ?? '');
// // // // //         await prefs.setString(prefUserDesignation, employee.job ?? '');
// // // // //         await prefs.setInt('emp_id', employee.emp_id ?? 0);
// // // // //         await prefs.setBool(prefIsAuthenticated, true);
// // // // //
// // // // //         // GEO_FENCING value save karo future use ke liye
// // // // //         await prefs.setString('geoFencing', employee.geo_fencing ?? '');
// // // // //
// // // // //         final companyCode = prefs.getString(prefCompanyCode) ?? '';
// // // // //         if (companyCode.isNotEmpty) {
// // // // //           DBHelper.setCompanyCode(companyCode);
// // // // //           currentCompanyCode.value = companyCode;
// // // // //         }
// // // // //
// // // // //         debugPrint('✅ Login successful for: ${employee.emp_name} (${employee.job})');
// // // // //         debugPrint('   GEO Fencing: ${employee.geo_fencing}');
// // // // //         return true;
// // // // //       } else {
// // // // //         loginError.value = 'Invalid Employee ID or Password';
// // // // //         return false;
// // // // //       }
// // // // //     } catch (e) {
// // // // //       loginError.value = 'Login failed: ${e.toString()}';
// // // // //       return false;
// // // // //     } finally {
// // // // //       isLoading.value = false;
// // // // //     }
// // // // //   }
// // // // //
// // // // //   String getHomeRoute() {
// // // // //     return routeHome;
// // // // //   }
// // // // //
// // // // //   Future<void> logout() async {
// // // // //     final prefs = await SharedPreferences.getInstance();
// // // // //
// // // // //     await prefs.remove(prefUserId);
// // // // //     await prefs.remove(prefUserName);
// // // // //     await prefs.remove(prefUserDesignation);
// // // // //     await prefs.remove('emp_id');
// // // // //     await prefs.remove('geoFencing');
// // // // //     await prefs.setBool(prefIsAuthenticated, false);
// // // // //
// // // // //     // ✅ Company code mat hatao - next login ke liye rehne do
// // // // //     currentUser.value = null;
// // // // //
// // // // //     Get.offAllNamed(routeCodeScreen);
// // // // //   }
// // // // // }
// // // // import 'package:flutter/foundation.dart';
// // // // import 'package:get/get.dart';
// // // // import 'package:shared_preferences/shared_preferences.dart';
// // // // import '../Database/db_helper.dart';
// // // // import '../Models/LoginModels/login_models.dart';
// // // // import '../Repositories/LoginRepositories/login_repository.dart';
// // // // import '../constants.dart';
// // // //
// // // // class LoginViewModel extends GetxController {
// // // //   final LoginRepository _loginRepository = Get.find<LoginRepository>();
// // // //
// // // //   var isLoading = false.obs;
// // // //   var currentUser = Rx<LoginModels?>(null);
// // // //   var loginError = ''.obs;
// // // //   var currentCompanyCode = ''.obs;
// // // //
// // // //   @override
// // // //   void onInit() {
// // // //     super.onInit();
// // // //     _loadCurrentCompany();
// // // //   }
// // // //
// // // //   Future<void> _loadCurrentCompany() async {
// // // //     final prefs = await SharedPreferences.getInstance();
// // // //     currentCompanyCode.value = prefs.getString(prefCompanyCode) ?? '';
// // // //
// // // //     if (currentCompanyCode.value.isNotEmpty) {
// // // //       DBHelper.setCompanyCode(currentCompanyCode.value);
// // // //       debugPrint('🏢 Loaded company: ${currentCompanyCode.value}');
// // // //     }
// // // //   }
// // // //
// // // //   Future<bool> login(String employeeId, String password) async {
// // // //     try {
// // // //       isLoading.value = true;
// // // //       loginError.value = '';
// // // //
// // // //       debugPrint('🔐 Attempting login for Employee ID: $employeeId');
// // // //       debugPrint('🏢 Company: ${currentCompanyCode.value}');
// // // //
// // // //       final employee = await _loginRepository.getUserByCredentials(employeeId, password);
// // // //
// // // //       if (employee != null) {
// // // //         currentUser.value = employee;
// // // //
// // // //         final prefs = await SharedPreferences.getInstance();
// // // //         await prefs.setString(prefUserId, employeeId);
// // // //         await prefs.setString(prefUserName, employee.emp_name ?? '');
// // // //         await prefs.setString(prefUserDesignation, employee.job ?? '');
// // // //         await prefs.setInt('emp_id', employee.emp_id ?? 0);
// // // //         await prefs.setBool(prefIsAuthenticated, true);
// // // //         await prefs.setString('geoFencing', employee.geo_fencing ?? '');
// // // //
// // // //         final companyCode = prefs.getString(prefCompanyCode) ?? '';
// // // //         if (companyCode.isNotEmpty) {
// // // //           DBHelper.setCompanyCode(companyCode);
// // // //           currentCompanyCode.value = companyCode;
// // // //         }
// // // //
// // // //         debugPrint('✅ Login successful for: ${employee.emp_name} (${employee.job})');
// // // //         debugPrint('   GEO Fencing: ${employee.geo_fencing}');
// // // //
// // // //         // ── Pre-fetch & cache locations while internet is available ──────────
// // // //         // This runs in background after login succeeds; we don't await it so
// // // //         // it never blocks navigation. If it fails the cached data stays intact.
// // // //         _loginRepository
// // // //             .fetchAndCacheLocations(employeeId, currentCompanyCode.value)
// // // //             .catchError((e) {
// // // //           debugPrint('⚠️ Background location cache failed: $e');
// // // //           return null; // keep Dart happy with the Future<void> type
// // // //         });
// // // //
// // // //         return true;
// // // //       } else {
// // // //         loginError.value = 'Invalid Employee ID or Password';
// // // //         return false;
// // // //       }
// // // //     } catch (e) {
// // // //       loginError.value = 'Login failed: ${e.toString()}';
// // // //       return false;
// // // //     } finally {
// // // //       isLoading.value = false;
// // // //     }
// // // //   }
// // // //
// // // //   String getHomeRoute() {
// // // //     return routeHome;
// // // //   }
// // // //
// // // //   Future<void> logout() async {
// // // //     final prefs = await SharedPreferences.getInstance();
// // // //
// // // //     await prefs.remove(prefUserId);
// // // //     await prefs.remove(prefUserName);
// // // //     await prefs.remove(prefUserDesignation);
// // // //     await prefs.remove('emp_id');
// // // //     await prefs.remove('geoFencing');
// // // //     await prefs.setBool(prefIsAuthenticated, false);
// // // //
// // // //     // ✅ Company code mat hatao - next login ke liye rehne do
// // // //     // ✅ cached_locations bhi rehne do - next login pe overwrite ho jayega
// // // //     currentUser.value = null;
// // // //
// // // //     Get.offAllNamed(routeCodeScreen);
// // // //   }
// // // // }
// // //
// // // ///end time
// // // //
// // // // import 'package:flutter/foundation.dart';
// // // // import 'package:get/get.dart';
// // // // import 'package:shared_preferences/shared_preferences.dart';
// // // // import '../Database/db_helper.dart';
// // // // import '../Models/LoginModels/login_models.dart';
// // // // import '../Repositories/LoginRepositories/login_repository.dart';
// // // // import '../constants.dart';
// // // //
// // // // class LoginViewModel extends GetxController {
// // // //   final LoginRepository _loginRepository = Get.find<LoginRepository>();
// // // //
// // // //   var isLoading = false.obs;
// // // //   var currentUser = Rx<LoginModels?>(null);
// // // //   var loginError = ''.obs;
// // // //   var currentCompanyCode = ''.obs;
// // // //
// // // //   @override
// // // //   void onInit() {
// // // //     super.onInit();
// // // //     _loadCurrentCompany();
// // // //   }
// // // //
// // // //   Future<void> _loadCurrentCompany() async {
// // // //     final prefs = await SharedPreferences.getInstance();
// // // //     currentCompanyCode.value = prefs.getString(prefCompanyCode) ?? '';
// // // //
// // // //     if (currentCompanyCode.value.isNotEmpty) {
// // // //       DBHelper.setCompanyCode(currentCompanyCode.value);
// // // //       debugPrint('🏢 Loaded company: ${currentCompanyCode.value}');
// // // //     }
// // // //   }
// // // //
// // // //   Future<bool> login(String employeeId, String password) async {
// // // //     try {
// // // //       isLoading.value = true;
// // // //       loginError.value = '';
// // // //
// // // //       debugPrint('🔐 Attempting login for Employee ID: $employeeId');
// // // //       debugPrint('🏢 Company: ${currentCompanyCode.value}');
// // // //
// // // //       final employee = await _loginRepository.getUserByCredentials(employeeId, password);
// // // //
// // // //       if (employee != null) {
// // // //         // ✅ No company_code check needed here
// // // //         // Backend SQL already ensured: WHERE company_code = :company_code
// // // //         // Jo bhi result aaya woh is company ka hi employee hai
// // // //
// // // //         currentUser.value = employee;
// // // //
// // // //         final prefs = await SharedPreferences.getInstance();
// // // //         await prefs.setString(prefUserId, employeeId);
// // // //         await prefs.setString(prefUserName, employee.emp_name ?? '');
// // // //         await prefs.setString(prefUserDesignation, employee.job ?? '');
// // // //         await prefs.setInt('emp_id', employee.emp_id ?? 0);
// // // //         await prefs.setBool(prefIsAuthenticated, true);
// // // //
// // // //         // GEO_FENCING value save karo future use ke liye
// // // //         await prefs.setString('geoFencing', employee.geo_fencing ?? '');
// // // //
// // // //         final companyCode = prefs.getString(prefCompanyCode) ?? '';
// // // //         if (companyCode.isNotEmpty) {
// // // //           DBHelper.setCompanyCode(companyCode);
// // // //           currentCompanyCode.value = companyCode;
// // // //         }
// // // //
// // // //         debugPrint('✅ Login successful for: ${employee.emp_name} (${employee.job})');
// // // //         debugPrint('   GEO Fencing: ${employee.geo_fencing}');
// // // //         return true;
// // // //       } else {
// // // //         loginError.value = 'Invalid Employee ID or Password';
// // // //         return false;
// // // //       }
// // // //     } catch (e) {
// // // //       loginError.value = 'Login failed: ${e.toString()}';
// // // //       return false;
// // // //     } finally {
// // // //       isLoading.value = false;
// // // //     }
// // // //   }
// // // //
// // // //   String getHomeRoute() {
// // // //     return routeHome;
// // // //   }
// // // //
// // // //   Future<void> logout() async {
// // // //     final prefs = await SharedPreferences.getInstance();
// // // //
// // // //     await prefs.remove(prefUserId);
// // // //     await prefs.remove(prefUserName);
// // // //     await prefs.remove(prefUserDesignation);
// // // //     await prefs.remove('emp_id');
// // // //     await prefs.remove('geoFencing');
// // // //     await prefs.setBool(prefIsAuthenticated, false);
// // // //
// // // //     // ✅ Company code mat hatao - next login ke liye rehne do
// // // //     currentUser.value = null;
// // // //
// // // //     Get.offAllNamed(routeCodeScreen);
// // // //   }
// // // // }
// // // import 'package:flutter/foundation.dart';
// // // import 'package:get/get.dart';
// // // import 'package:shared_preferences/shared_preferences.dart';
// // // import '../Database/db_helper.dart';
// // // import '../Models/LoginModels/login_models.dart';
// // // import '../Repositories/LoginRepositories/login_repository.dart';
// // // import '../constants.dart';
// // //
// // // class LoginViewModel extends GetxController {
// // //   final LoginRepository _loginRepository = Get.find<LoginRepository>();
// // //
// // //   var isLoading = false.obs;
// // //   var currentUser = Rx<LoginModels?>(null);
// // //   var loginError = ''.obs;
// // //   var currentCompanyCode = ''.obs;
// // //
// // //   @override
// // //   void onInit() {
// // //     super.onInit();
// // //     _loadCurrentCompany();
// // //   }
// // //
// // //   Future<void> _loadCurrentCompany() async {
// // //     final prefs = await SharedPreferences.getInstance();
// // //     currentCompanyCode.value = prefs.getString(prefCompanyCode) ?? '';
// // //
// // //     if (currentCompanyCode.value.isNotEmpty) {
// // //       DBHelper.setCompanyCode(currentCompanyCode.value);
// // //       debugPrint('🏢 Loaded company: ${currentCompanyCode.value}');
// // //     }
// // //   }
// // //
// // //   Future<bool> login(String employeeId, String password) async {
// // //     try {
// // //       isLoading.value = true;
// // //       loginError.value = '';
// // //
// // //       debugPrint('🔐 Attempting login for Employee ID: $employeeId');
// // //       debugPrint('🏢 Company: ${currentCompanyCode.value}');
// // //
// // //       final employee = await _loginRepository.getUserByCredentials(employeeId, password);
// // //
// // //       if (employee != null) {
// // //         currentUser.value = employee;
// // //
// // //         final prefs = await SharedPreferences.getInstance();
// // //         await prefs.setString(prefUserId, employeeId);
// // //         await prefs.setString(prefUserName, employee.emp_name ?? '');
// // //         await prefs.setString(prefUserDesignation, employee.job ?? '');
// // //         await prefs.setInt('emp_id', employee.emp_id ?? 0);
// // //         await prefs.setBool(prefIsAuthenticated, true);
// // //         await prefs.setString('geoFencing', employee.geo_fencing ?? '');
// // //
// // //         final companyCode = prefs.getString(prefCompanyCode) ?? '';
// // //         if (companyCode.isNotEmpty) {
// // //           DBHelper.setCompanyCode(companyCode);
// // //           currentCompanyCode.value = companyCode;
// // //         }
// // //
// // //         debugPrint('✅ Login successful for: ${employee.emp_name} (${employee.job})');
// // //         debugPrint('   GEO Fencing: ${employee.geo_fencing}');
// // //
// // //         // ── Pre-fetch & cache locations while internet is available ──────────
// // //         // This runs in background after login succeeds; we don't await it so
// // //         // it never blocks navigation. If it fails the cached data stays intact.
// // //         _loginRepository
// // //             .fetchAndCacheLocations(employeeId, currentCompanyCode.value)
// // //             .catchError((e) {
// // //           debugPrint('⚠️ Background location cache failed: $e');
// // //           return null; // keep Dart happy with the Future<void> type
// // //         });
// // //
// // //         // ── Pre-fetch & cache employee end time for offline clock-out check ──
// // //         // Same pattern: background, non-blocking, safe to fail.
// // //         _loginRepository
// // //             .fetchAndCacheEndTime(employeeId, currentCompanyCode.value)
// // //             .catchError((e) {
// // //           debugPrint('⚠️ Background end time cache failed: $e');
// // //           return null;
// // //         });
// // //
// // //         return true;
// // //       } else {
// // //         loginError.value = 'Invalid Employee ID or Password';
// // //         return false;
// // //       }
// // //     } catch (e) {
// // //       loginError.value = 'Login failed: ${e.toString()}';
// // //       return false;
// // //     } finally {
// // //       isLoading.value = false;
// // //     }
// // //   }
// // //
// // //   String getHomeRoute() {
// // //     return routeHome;
// // //   }
// // //
// // //   Future<void> logout() async {
// // //     final prefs = await SharedPreferences.getInstance();
// // //
// // //     await prefs.remove(prefUserId);
// // //     await prefs.remove(prefUserName);
// // //     await prefs.remove(prefUserDesignation);
// // //     await prefs.remove('emp_id');
// // //     await prefs.remove('geoFencing');
// // //     await prefs.setBool(prefIsAuthenticated, false);
// // //
// // //     // ✅ Company code mat hatao - next login ke liye rehne do
// // //     // ✅ cached_locations bhi rehne do - next login pe overwrite ho jayega
// // //     currentUser.value = null;
// // //
// // //     Get.offAllNamed(routeCodeScreen);
// // //   }
// // // }
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
// //       debugPrint('🔐 Login attempt | emp_id=$employeeId | company=${currentCompanyCode.value}');
// //
// //       // Guard: company code must be set
// //       if (currentCompanyCode.value.isEmpty) {
// //         loginError.value =
// //         'Company code not set. Please go back and enter your company code.';
// //         return false;
// //       }
// //
// //       final employee =
// //       await _loginRepository.getUserByCredentials(employeeId, password);
// //
// //       if (employee != null) {
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
// //         final companyCode = prefs.getString(prefCompanyCode) ?? '';
// //         if (companyCode.isNotEmpty) {
// //           DBHelper.setCompanyCode(companyCode);
// //           currentCompanyCode.value = companyCode;
// //         }
// //
// //         debugPrint('✅ Login success: ${employee.emp_name} (${employee.job})');
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
// //       } else {
// //         // ✅ Clear error: employee ID not found in this company
// //         loginError.value =
// //         'Employee ID "$employeeId" does not belong to company '
// //             '"${currentCompanyCode.value}". '
// //             'Please check your Employee ID or contact your administrator.';
// //         return false;
// //       }
// //     } catch (e) {
// //       loginError.value =
// //       'Login failed. Please check your connection and try again.';
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
// //     // Keep company code & cached employees for next login
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
//     // Try multiple sources to get company code
//     String? companyCode = prefs.getString(prefCompanyCode);
//
//     // If still null, try DBHelper
//     if (companyCode == null || companyCode.isEmpty) {
//       companyCode = DBHelper.getCompanyCode();
//     }
//
//     // If still null, try loading from another key
//     if (companyCode == null || companyCode.isEmpty) {
//       companyCode = prefs.getString('cached_employees_company');
//     }
//
//     currentCompanyCode.value = companyCode ?? '';
//
//     if (currentCompanyCode.value.isNotEmpty) {
//       DBHelper.setCompanyCode(currentCompanyCode.value);
//       debugPrint('🏢 Loaded company: ${currentCompanyCode.value}');
//     } else {
//       debugPrint('⚠️ No company code found in SharedPreferences');
//     }
//   }
//
//   // Public method to refresh company code (can be called from LoginScreen)
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
//       debugPrint('🔐 Login attempt | emp_id=$employeeId');
//
//       // Try to get company code again if empty
//       if (currentCompanyCode.value.isEmpty) {
//         final prefs = await SharedPreferences.getInstance();
//         final freshCompanyCode = prefs.getString(prefCompanyCode) ??
//             DBHelper.getCompanyCode();
//
//         if (freshCompanyCode != null && freshCompanyCode.isNotEmpty) {
//           currentCompanyCode.value = freshCompanyCode;
//           debugPrint('🔄 Retrieved company code on-demand: ${currentCompanyCode.value}');
//         } else {
//           loginError.value = 'Company code not set. Please go back and enter your company code.';
//           debugPrint('❌ Still no company code found');
//           return false;
//         }
//       }
//
//       debugPrint('🏢 Using company: ${currentCompanyCode.value}');
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
//         debugPrint('✅ Login success: ${employee.emp_name} (${employee.job})');
//
//         // Background: cache locations (non-blocking)
//         _loginRepository
//             .fetchAndCacheLocations(employeeId, currentCompanyCode.value)
//             .catchError((e) {
//           debugPrint('⚠️ Background location cache failed: $e');
//           return null;
//         });
//
//         // Background: cache end time (non-blocking)
//         _loginRepository
//             .fetchAndCacheEndTime(employeeId, currentCompanyCode.value)
//             .catchError((e) {
//           debugPrint('⚠️ Background end time cache failed: $e');
//           return null;
//         });
//
//         return true;
//       } else {
//         loginError.value =
//         'Invalid Employee ID or Password for company ${currentCompanyCode.value}\n\n'
//             'Please check:\n'
//             '• Employee ID belongs to this company\n'
//             '• Password is correct\n'
//             '• You have internet connection';
//         return false;
//       }
//     } catch (e) {
//       loginError.value = 'Login failed. Please check your connection and try again.';
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
//     // Keep company code & cached employees for next login
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

  // ── Load company code from every possible source ───────────────────────
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

  /// Can be called from LoginScreen on resume / hot-reload.
  Future<void> refreshCompanyCode() async {
    await _loadCurrentCompany();
    debugPrint('🔄 Company code refreshed: ${currentCompanyCode.value}');
  }

  // ── Main login method ──────────────────────────────────────────────────
  Future<bool> login(String employeeId, String password) async {
    try {
      isLoading.value = true;
      loginError.value = '';

      // Ensure company code is available
      if (currentCompanyCode.value.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final fresh =
            prefs.getString(prefCompanyCode) ?? DBHelper.getCompanyCode();
        if (fresh != null && fresh.isNotEmpty) {
          currentCompanyCode.value = fresh;
        } else {
          loginError.value =
          'Company code not set. Please go back and enter your company code.';
          return false;
        }
      }

      debugPrint(
          '🔐 Login attempt | emp_id=$employeeId | company=${currentCompanyCode.value}');

      final result =
      await _loginRepository.getUserByCredentials(employeeId, password);

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

        debugPrint(
            '✅ Login success: ${employee.emp_name} (${employee.job})');

        // Background: cache locations (non-blocking)
        _loginRepository
            .fetchAndCacheLocations(employeeId, currentCompanyCode.value)
            .catchError((e) {
          debugPrint('⚠️ Background location cache failed: $e');
          return null;
        });

        // Background: cache end time (non-blocking)
        _loginRepository
            .fetchAndCacheEndTime(employeeId, currentCompanyCode.value)
            .catchError((e) {
          debugPrint('⚠️ Background end time cache failed: $e');
          return null;
        });

        return true;
      }

      // ── Set a clear, user-friendly error based on the exact failure ────
      switch (result.status) {
        case LoginStatus.notInCompany:
          loginError.value =
          'Employee ID "$employeeId" does not belong to company '
              '"${result.companyCode ?? currentCompanyCode.value}".\n'
              'Please check your Employee ID or contact your administrator.';
          break;

        case LoginStatus.wrongPassword:
          loginError.value =
          'Incorrect password. Please try again.';
          break;

        case LoginStatus.noCompany:
          loginError.value =
          'Company code not set. Please go back and enter your company code.';
          break;

        case LoginStatus.networkError:
          loginError.value =
          'Could not connect to the server. Please check your internet connection and try again.';
          break;

        default:
          loginError.value = 'Login failed. Please try again.';
      }

      return false;
    } catch (e) {
      loginError.value =
      'An unexpected error occurred. Please try again.';
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
    // Keep company code + cached employees so next login is fast
    currentUser.value = null;
    Get.offAllNamed(routeCodeScreen);
  }
}