//
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'Repositories/LoginRepositories/login_repository.dart';
// import 'Screens/PermissionScreens/camera_screen.dart';
// import 'Screens/PermissionScreens/location_screen.dart';
// import 'Screens/PermissionScreens/notification_screen.dart';
// import 'Screens/PermissionScreens/permission_flow.dart';
// import 'Screens/code_screen.dart';
// import 'Screens/home_screen.dart';
// import 'Screens/login_screen.dart';
// import 'Screens/splash_screen.dart';
// import 'ViewModels/login_view_model.dart';
// import 'ViewModels/travel_session_view_model.dart';
// import 'ViewModels/attendance_view_model.dart';
// import 'ViewModels/attendance_out_view_model.dart';
// import 'ViewModels/location_view_model.dart';
// import 'Models/LoginModels/login_models.dart';
// import 'constants.dart';
//
// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//
//   debugPrint("Initializing SharedPreferences main...");
//   final prefs = await SharedPreferences.getInstance();
//   await prefs.reload();
//
//   // Register ALL dependencies
//   Get.put(LoginRepository(), permanent: true);
//
//   // Register ALL ViewModels (order matters - dependencies first)
//   Get.put(LocationViewModel(), permanent: true);
//   Get.put(AttendanceViewModel(), permanent: true);
//   Get.put(AttendanceOutViewModel(), permanent: true);
//   Get.put(TravelViewModel(), permanent: true);
//
//   final loginVM = Get.put(LoginViewModel(), permanent: true);
//
//   // Restore user from SharedPreferences if already logged in
//   bool isAuthenticated = prefs.getBool(prefIsAuthenticated) ?? false;
//   if (isAuthenticated) {
//     loginVM.currentUser.value = LoginModels(
//       emp_id: prefs.getInt('emp_id'),
//       emp_name: prefs.getString(prefUserName),
//       job: prefs.getString(prefUserDesignation),
//     );
//   }
//
//   debugPrint("Running the app...");
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final loginVM = Get.find<LoginViewModel>();
//
//     return GetMaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'GPS Workforce Monitor',
//       // Always start with SplashScreen, it will handle routing logic
//       initialRoute: '/',
//       getPages: [
//         GetPage(name: '/', page: () => const SplashScreen()),
//         GetPage(name: routeCodeScreen, page: () => const CodeScreen()),
//         GetPage(name: '/permissions', page: () => const PermissionsFlow()),
//         GetPage(name: routeCameraScreen, page: () => const CameraScreen()),
//         GetPage(name: '/locationScreen', page: () => const LocationScreen()),
//         GetPage(name: '/notificationScreen', page: () => const NotificationScreen()),
//         GetPage(name: routeLogin, page: () => const LoginScreen()),
//         GetPage(name: routeHome, page: () => const HomeScreen()),
//       ],
//     );
//   }
// }


// ///for different cpmpanies
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Database/db_helper.dart';
import 'Repositories/LoginRepositories/login_repository.dart';
import 'Screens/PermissionScreens/camera_screen.dart';
import 'Screens/PermissionScreens/location_screen.dart';
import 'Screens/PermissionScreens/notification_screen.dart';
import 'Screens/PermissionScreens/permission_flow.dart';
import 'Screens/code_screen.dart';
import 'Screens/home_screen.dart';
import 'Screens/login_screen.dart';
import 'Screens/splash_screen.dart';
import 'ViewModels/login_view_model.dart';
import 'ViewModels/travel_session_view_model.dart';
import 'ViewModels/attendance_view_model.dart';
import 'ViewModels/attendance_out_view_model.dart';
import 'ViewModels/location_view_model.dart';
import 'Models/LoginModels/login_models.dart';
import 'constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint("Initializing SharedPreferences main...");
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  // ✅ Restore company code on app start
  final savedCompanyCode = prefs.getString(prefCompanyCode);
  if (savedCompanyCode != null && savedCompanyCode.isNotEmpty) {
    DBHelper.setCompanyCode(savedCompanyCode);
    debugPrint('🏢 Restored company code: $savedCompanyCode');
  }

  // Register dependencies
  Get.put(LoginRepository(), permanent: true);
  Get.put(LocationViewModel(), permanent: true);
  Get.put(AttendanceViewModel(), permanent: true);
  Get.put(AttendanceOutViewModel(), permanent: true);
  Get.put(TravelViewModel(), permanent: true);

  final loginVM = Get.put(LoginViewModel(), permanent: true);

  // Restore user session if exists
  bool isAuthenticated = prefs.getBool(prefIsAuthenticated) ?? false;
  if (isAuthenticated) {
    loginVM.currentUser.value = LoginModels(
      emp_id: prefs.getInt('emp_id'),
      emp_name: prefs.getString(prefUserName),
      job: prefs.getString(prefUserDesignation),
    );
  }

  debugPrint("Running the app...");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final loginVM = Get.find<LoginViewModel>();

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GPS Workforce Monitor',
      initialRoute: loginVM.currentUser.value != null
          ? loginVM.getHomeRoute()
          : routeCodeScreen,
      getPages: [
        GetPage(name: '/', page: () => const SplashScreen()),
        GetPage(name: routeCodeScreen, page: () => const CodeScreen()),
        GetPage(name: '/permissions', page: () => const PermissionsFlow()),
        GetPage(name: routeCameraScreen, page: () => const CameraScreen()),
        GetPage(name: '/locationScreen', page: () => const LocationScreen()),
        GetPage(name: '/notificationScreen', page: () => const NotificationScreen()),
        GetPage(name: routeLogin, page: () => const LoginScreen()),
        GetPage(name: routeHome, page: () => const HomeScreen()),
      ],
    );
  }
}