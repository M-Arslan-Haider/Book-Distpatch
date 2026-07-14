import 'dart:async';
import 'dart:convert';
import 'dart:ui';
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
import 'Services/play_integrity_service.dart';
import 'Services/power_off_service.dart';
import 'Services/exit_reason_service.dart';
import 'Services/battery_sync.dart';
import 'Services/crash_log_service.dart';
import 'constants.dart';

void main() {
  runZonedGuarded(() async {

    WidgetsFlutterBinding.ensureInitialized();

    // ✅ Initialize Firebase FIRST
    await Firebase.initializeApp();
    debugPrint("🔥 Firebase initialized");

    // ✅ Error handlers - Only Oracle crash logging (no Firebase Crashlytics)
    FlutterError.onError = (errorDetails) {
      CrashLogService.postCrashToServer(
        error: errorDetails.exception.toString(),
        stack: errorDetails.stack.toString(),
        errorType: 'flutter_error',
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      CrashLogService.postCrashToServer(
        error: error.toString(),
        stack: stack.toString(),
        errorType: 'async_error',
      );
      return true;
    };
    debugPrint("🛡️ Oracle crash logging initialized");

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

    // ✅ FRESH INSTALL DETECTION
    final isAppInstalled = prefs.getBool('app_installed_flag') ?? false;
    if (!isAppInstalled) {
      await prefs.clear();
      await prefs.setBool('app_installed_flag', true);
      debugPrint('🆕 Fresh install detected — session cleared');
    }

    // ✅ POWER OFF: Check and post any pending power off event
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
    Get.put(PlayIntegrityService(), permanent: true);

    final loginVM = Get.put(LoginViewModel(), permanent: true);

    // Restore user session if exists
    bool isAuthenticated = prefs.getBool(prefIsAuthenticated) ?? false;
    if (isAuthenticated) {
      loginVM.currentUser.value = LoginModels(
        emp_id: prefs.getInt('emp_id'),
        emp_name: prefs.getString(prefUserName),
        job: prefs.getString(prefUserDesignation),
      );

      // ✅ START BATTERY WATCHER - User is logged in
      _startBatteryWatcher(prefs);
    }

    // ✅ FORCE-STOP DETECTION
    await ExitReasonService.runOnLaunch();

    // Start listening for connectivity changes
    FakeGpsLog.startConnectivityListener();

    // ✅ POWER OFF: auto-sync any pending power-off events
    PowerOffService.startConnectivityListener();

    // Sync any records that were saved during offline session
    await FakeGpsLog.syncPending();

    debugPrint("Running the app...");
    runApp(const MyApp());

  }, (error, stack) {
    // ✅ Zone-level error catcher - Only Oracle logging
    CrashLogService.postCrashToServer(
      error: error.toString(),
      stack: stack.toString(),
      errorType: 'zone_error',
    );
  });
}

// ✅ START BATTERY WATCHER
void _startBatteryWatcher(SharedPreferences prefs) {
  try {
    final empId = prefs.getInt('emp_id')?.toString() ?? '';
    final empName = prefs.getString(prefUserName) ?? '';
    final companyCode = prefs.getString(prefCompanyCode) ?? '';

    debugPrint('🔋 [MAIN] _startBatteryWatcher() called');
    debugPrint('🔋 [MAIN] empId: $empId, empName: $empName, companyCode: $companyCode');

    if (empId.isNotEmpty && empName.isNotEmpty && companyCode.isNotEmpty) {
      debugPrint('🔋 [MAIN] ✅ Starting BatteryLifecycleWatcher...');

      final watcher = BatteryLifecycleWatcher(
        empId: empId,
        empName: empName,
        companyCode: companyCode,
      );
      watcher.start();

      debugPrint('🔋 [MAIN] ✅ BatteryLifecycleWatcher started successfully');
    } else {
      debugPrint('⚠️ [MAIN] Battery watcher not started - incomplete user data');
      debugPrint('   empId: "$empId", empName: "$empName", companyCode: "$companyCode"');
    }
  } catch (e, st) {
    debugPrint('❌ [MAIN] Error starting battery watcher: $e');
    debugPrint('❌ [MAIN] StackTrace: $st');

    // Report to Oracle server
    CrashLogService.postCrashToServer(
      error: e.toString(),
      stack: st.toString(),
      errorType: 'battery_watcher_error',
    );
  }
}

/// ── ✅ Capture pending shutdown time ──
Future<void> _capturePendingShutdownTime() async {
  debugPrint('🔍 [ShutdownCapture] Checking for pending shutdown time...');

  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final pendingMillis = prefs.getInt('pending_shutdown_time');

    if (pendingMillis == null) {
      debugPrint('ℹ️ [ShutdownCapture] No pending shutdown time found');
      return;
    }

    debugPrint('🔍 [ShutdownCapture] Pending millis found: $pendingMillis');

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
      debugPrint('⚠️ [ShutdownCapture] emp_id is empty — discarding record');
      await prefs.remove('pending_shutdown_time');
      return;
    }

    final shutdownTime = DateTime.fromMillisecondsSinceEpoch(pendingMillis);
    final formattedTime =
        '${shutdownTime.year}-${shutdownTime.month.toString().padLeft(2, '0')}-${shutdownTime.day.toString().padLeft(2, '0')}'
        'T${shutdownTime.hour.toString().padLeft(2, '0')}:${shutdownTime.minute.toString().padLeft(2, '0')}:${shutdownTime.second.toString().padLeft(2, '0')}';

    debugPrint('💾 [ShutdownCapture] Shutdown captured → empId=$empId time=$formattedTime');

    await DBHelper().insertPowerOffEvent(
      empId: empId,
      empName: empName,
      companyCode: companyCode,
      eventTime: formattedTime,
    );

    await prefs.remove('pending_shutdown_time');
    debugPrint('🧹 [ShutdownCapture] pending_shutdown_time key cleared');

    debugPrint('📡 [ShutdownCapture] Trying to sync pending power-off event(s)...');
    await PowerOffService.checkAndPostPowerOffEvent();

  } catch (e, stack) {
    debugPrint('❌ [ShutdownCapture] Error: $e');
    debugPrint('❌ [ShutdownCapture] Stack: $stack');

    // Report to Oracle server
    CrashLogService.postCrashToServer(
      error: e.toString(),
      stack: stack.toString(),
      errorType: 'shutdown_capture_error',
    );
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
      navigatorObservers: [AppLifecycleObserver()],
    );
  }
}

// ✅ Global Navigation Observer
class AppLifecycleObserver extends NavigatorObserver {
  DateTime? _lastDialogClosedTime;
  bool _isDialogShowing = false;

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _checkAndShowDialog(route);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _checkAndShowDialog(newRoute);
    }
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _checkAndShowDialog(previousRoute);
    }
  }

  void _checkAndShowDialog(Route route) async {
    if (route.settings.name == routeHome) {
      final prefs = await SharedPreferences.getInstance();
      final alreadyAcknowledged =
          prefs.getBool(AppSetupDialog.prefSetupDialogAcknowledged) ?? false;
      if (alreadyAcknowledged) {
        debugPrint('✅ [Observer] Setup dialog already acknowledged, skipping...');
        return;
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        final context = navigator?.context;
        if (context != null && context.mounted) {
          if (Get.isDialogOpen == true) {
            debugPrint('⚠️ [Observer] Dialog already open, skipping...');
            return;
          }

          if (_isDialogShowing) {
            debugPrint('⚠️ [Observer] Already showing dialog, skipping...');
            return;
          }

          if (_lastDialogClosedTime != null) {
            final elapsed = DateTime.now().difference(_lastDialogClosedTime!);
            if (elapsed.inSeconds < 2) {
              debugPrint('⏳ [Observer] Cooldown active (${elapsed.inMilliseconds}ms), skipping dialog...');
              return;
            }
          }

          debugPrint('📋 [Observer] Showing setup dialog from NavigatorObserver');
          _isDialogShowing = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => const AppSetupDialog(),
          ).then((_) {
            _isDialogShowing = false;
            _lastDialogClosedTime = DateTime.now();
            debugPrint('📋 [Observer] Setup dialog closed at ${_lastDialogClosedTime}');
          });
        }
      });
    }
  }
}