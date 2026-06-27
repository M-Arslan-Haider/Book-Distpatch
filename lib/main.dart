import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
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
import 'Tracker/Fake_gps_log.dart';
import 'ViewModels/login_view_model.dart';
import 'ViewModels/travel_session_view_model.dart';
import 'ViewModels/attendance_view_model.dart';
import 'ViewModels/attendance_out_view_model.dart';
import 'ViewModels/location_view_model.dart';
import 'Models/LoginModels/login_models.dart';
import 'Services/remote_config_service.dart';
import 'Services/play_integrity_service.dart'; // ✅ NEW
import 'Services/power_off_service.dart';       // ✅ POWER OFF
import 'constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Initialize Firebase FIRST
  await Firebase.initializeApp();
  debugPrint("🔥 Firebase initialized");

  // ✅ Initialize Remote Config service
  await RemoteConfigService.initialize();
  debugPrint("⚙️ Remote Config initialized");

  // ✅ FORCE REFRESH to get latest values from server
  await RemoteConfigService.refresh();
  debugPrint("🔄 Remote Config force refreshed");

  debugPrint("Initializing SharedPreferences main...");
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  // ✅ POWER OFF: Check and post any pending power off event
  // NOTE: Must be BEFORE prefs.clear() — fresh install wipe se pehle post kar do
  await PowerOffService.checkAndPostPowerOffEvent();

  // Restore company code on app start
  final savedCompanyCode = prefs.getString(prefCompanyCode);
  if (savedCompanyCode != null && savedCompanyCode.isNotEmpty) {
    DBHelper.setCompanyCode(savedCompanyCode);
    debugPrint('🏢 Restored company code: $savedCompanyCode');
  }

  // ✅ FRESH INSTALL DETECTION
  final isAppInstalled = prefs.getBool('app_installed_flag') ?? false;
  if (!isAppInstalled) {
    await prefs.clear();                              // Wipe stale session
    await prefs.setBool('app_installed_flag', true);  // Mark as installed
    debugPrint('🆕 Fresh install detected — session cleared');
  }
  // ✅ END

  // Register dependencies
  Get.put(LoginRepository(), permanent: true);
  Get.put(LocationViewModel(), permanent: true);
  Get.put(AttendanceViewModel(), permanent: true);
  Get.put(AttendanceOutViewModel(), permanent: true);
  Get.put(TravelViewModel(), permanent: true);
  Get.put(PlayIntegrityService(), permanent: true); // ✅ NEW
  // Get.find<PlayIntegrityService>().startDebugPrinting();

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

  // Start listening for connectivity changes
  FakeGpsLog.startConnectivityListener();

  // Sync any records that were saved during offline session
  await FakeGpsLog.syncPending();

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
        GetPage(
            name: '/notificationScreen',
            page: () => const NotificationScreen()),
        GetPage(name: routeLogin, page: () => const LoginScreen()),
        GetPage(name: routeHome, page: () => const HomeScreen()),
      ],
    );
  }
}