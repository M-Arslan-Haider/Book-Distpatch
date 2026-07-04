import 'dart:async';
import 'dart:convert';  // ✅ ADDED for jsonEncode
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
import 'Services/exit_reason_service.dart';     // ✅ FORCE-STOP DETECTION
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

  // ── ✅ Capture pending shutdown time ──
  await _capturePendingShutdownTime();

  debugPrint("Initializing SharedPreferences main...");
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  // ✅ FRESH INSTALL DETECTION - MOVED BEFORE PowerOffService
  final isAppInstalled = prefs.getBool('app_installed_flag') ?? false;
  if (!isAppInstalled) {
    await prefs.clear();                              // Wipe stale session
    await prefs.setBool('app_installed_flag', true);  // Mark as installed
    debugPrint('🆕 Fresh install detected — session cleared');
  }
  // ✅ END

  // ✅ POWER OFF: Check and post any pending power off event
  // MOVED AFTER fresh install check so data is not cleared after posting
  await PowerOffService.checkAndPostPowerOffEvent();

  // Restore company code on app start
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

  // ✅ FORCE-STOP DETECTION: read how the process died last time and, if it was
  // a deliberate force stop (or OEM kill / crash), post that event to the server.
  // Additive — reads the OS exit-reason log, dedupes by timestamp, never blocks startup.
  await ExitReasonService.runOnLaunch();

  // Start listening for connectivity changes
  FakeGpsLog.startConnectivityListener();

  // Sync any records that were saved during offline session
  await FakeGpsLog.syncPending();

  debugPrint("Running the app...");
  runApp(const MyApp());
}

/// ── ✅ EXACT COPY from rubyform_orderbooking ──
/// ShutdownReceiver / LocationMonitorService native side par
/// "pending_shutdown_time" key ke andar exact shutdown time (millis)
/// save karta hai. Yahan usko read karke PowerOffService ke through
/// server par post kar dete hain.
Future<void> _capturePendingShutdownTime() async {
  debugPrint('🔍 [ShutdownCapture] Checking for pending shutdown time...');

  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final pendingMillis = prefs.getInt('pending_shutdown_time');

    if (pendingMillis == null) {
      debugPrint('ℹ️ [ShutdownCapture] Koi pending shutdown time nahi mila');
      return;
    }

    debugPrint('🔍 [ShutdownCapture] Pending millis mila: $pendingMillis');

    // Read user data from SharedPreferences
    final empId = prefs.getString('flutter.emp_id') ??
        prefs.getString('emp_id') ??
        prefs.getString('flutter.user_id') ??
        prefs.getString('user_id') ?? '';

    final empName = prefs.getString('flutter.emp_name') ??
        prefs.getString('emp_name') ??
        prefs.getString('flutter.user_name') ??
        prefs.getString('user_name') ?? '';

    final companyCode = prefs.getString('flutter.company_code') ??
        prefs.getString('company_code') ?? '';

    debugPrint('🔍 [ShutdownCapture] empId=$empId empName=$empName companyCode=$companyCode');

    if (empId.isEmpty) {
      debugPrint('⚠️ [ShutdownCapture] emp_id khali hai — record discard kar rahe hain');
      await prefs.remove('pending_shutdown_time');
      return;
    }

    final shutdownTime = DateTime.fromMillisecondsSinceEpoch(pendingMillis);
    final formattedTime =
        '${shutdownTime.year}-${shutdownTime.month.toString().padLeft(2, '0')}-${shutdownTime.day.toString().padLeft(2, '0')}'
        'T${shutdownTime.hour.toString().padLeft(2, '0')}:${shutdownTime.minute.toString().padLeft(2, '0')}:${shutdownTime.second.toString().padLeft(2, '0')}';

    debugPrint('💾 [ShutdownCapture] Shutdown captured → empId=$empId time=$formattedTime');

    // ── Store for PowerOffService to process ──
    final powerOffData = {
      'emp_id': empId,
      'emp_name': empName,
      'company_code': companyCode,
      'power_off': 'yes',
      'event_time': formattedTime,
    };

    await prefs.setString('pending_power_off', jsonEncode(powerOffData));
    await prefs.setString('pending_power_off_time', formattedTime);

    // Clear pending shutdown time so it doesn't fire again
    await prefs.remove('pending_shutdown_time');
    debugPrint('🧹 [ShutdownCapture] pending_shutdown_time key clear kar di');

    // ── Immediately try to post to server ──
    debugPrint('📡 [ShutdownCapture] Trying to post power-off event to server...');
    await PowerOffService.checkAndPostPowerOffEvent();

  } catch (e, stack) {
    debugPrint('❌ [ShutdownCapture] Error: $e');
    debugPrint('❌ [ShutdownCapture] Stack: $stack');
  }
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