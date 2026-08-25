
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Database/db_helper.dart';
import '../Models/LoginModels/login_models.dart';
import '../Repositories/LoginRepositories/login_repository.dart';
import '../Services/biometric_service.dart';
import '../constants.dart';
import '../ViewModels/attendance_view_model.dart';

class LoginViewModel extends GetxController {
  final LoginRepository _loginRepository = Get.find<LoginRepository>();

  var isLoading             = false.obs;
  var currentUser           = Rx<LoginModels?>(null);
  var loginError            = ''.obs;
  var currentCompanyCode    = ''.obs;

  // ── TimeKeeper role ───────────────────────────────────────────────────────
  // Mapped from DB column: TIMEKEEPER (VARCHAR2)
  // ORDS returns it as lowercase key "timekeeper" in the JSON.
  // Accepted truthy values: 'yes', '1', 'true' (case-insensitive)
  var isTimekeeper = false.obs;

  // ── Biometric state ───────────────────────────────────────────────────────
  var isBiometricEnabled = false.obs;
  var biometricModality  = BiometricModality.none.obs;

  String _cachedEmpId    = '';
  String _cachedPassword = '';

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _loadCurrentCompany();
    _loadBiometricState();
    _loadTimekeeperState();
  }

  // ── TimeKeeper state ──────────────────────────────────────────────────────

  Future<void> _loadTimekeeperState() async {
    final prefs = await SharedPreferences.getInstance();
    isTimekeeper.value = prefs.getBool(prefIsTimekeeper) ?? false;
    debugPrint('⏱️ [TIMEKEEPER] Role restored from prefs: ${isTimekeeper.value}');
  }

  // ── Company loading ───────────────────────────────────────────────────────

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

  // ── Password login ────────────────────────────────────────────────────────

  Future<bool> login(String employeeId, String password) async {
    try {
      isLoading.value  = true;
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
        await prefs.setString(prefUserId,          employeeId);
        await prefs.setString(prefUserName,        employee.emp_name ?? '');
        await prefs.setString(prefUserDesignation, employee.job ?? '');
        await prefs.setInt('emp_id',               employee.emp_id ?? 0);
        await prefs.setBool(prefIsAuthenticated,   true);
        await prefs.setString('geoFencing',        employee.geo_fencing ?? '');

        await prefs.setString('cached_end_time',                    employee.end_time ?? '');
        await prefs.setString('cached_overtime',                    employee.over_time ?? '');
        await prefs.setString('cached_shift',                       employee.shift ?? '');
        await prefs.setString('cached_allow_check_in_before_shift', employee.allow_check_in_before_shift ?? 'no');
        await prefs.setString('cached_entry_time',                  employee.entry_time ?? '');

        // ── TIMEKEEPER role ───────────────────────────────────────────────
        // DB column: TIMEKEEPER VARCHAR2(100)
        // ORDS JSON key: "timekeeper"
        // Truthy values: 'yes', '1', 'true'
        final rawTk  = (employee.timekeeper ?? '').toString().trim().toLowerCase();
        final hasTk  = rawTk == 'yes' || rawTk == '1' || rawTk == 'true';
        isTimekeeper.value = hasTk;
        await prefs.setBool(prefIsTimekeeper, hasTk);
        debugPrint('⏱️ [TIMEKEEPER] raw="$rawTk"  granted=$hasTk');
        // ─────────────────────────────────────────────────────────────────

        debugPrint('✅ Login success: ${employee.emp_name} (${employee.job})');
        debugPrint('📦 end_time=${employee.end_time}  over_time=${employee.over_time}  shift=${employee.shift}');
        debugPrint('📦 allow_check_in_before_shift=${employee.allow_check_in_before_shift}  entry_time=${employee.entry_time}');

        _cachedEmpId    = employeeId;
        _cachedPassword = password;

        final attendanceVM = Get.find<AttendanceViewModel>();
        final wasRestored  = await attendanceVM.checkAndRestoreAttendanceState(
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

        // ── Fetch & cache wager detail at login time ───────────────────────
        // So WagersDetailScreen can show data even with no internet later.
        _loginRepository
            .fetchAndCacheWagers(employeeId, currentCompanyCode.value)
            .then((ok) => debugPrint(ok
            ? '✅ [LoginVM] Wager detail cached for offline use'
            : '⚠️ [LoginVM] Wager detail cache skipped (no response/offline)'))
            .catchError((e) {
          debugPrint('⚠️ Background wager cache failed: $e');
          return null;
        });

        return true;
      }

      switch (result.status) {
        case LoginStatus.notInCompany:
          loginError.value = 'Employee ID "$employeeId" does not belong to this company.\n'
              'Please check your Employee ID or contact your administrator.';
          break;
        case LoginStatus.wrongPassword:
          loginError.value = 'Incorrect password. Please try again.';
          break;
        case LoginStatus.noCompany:
          loginError.value = 'Company code not set. Please go back and enter your company code.';
          break;
        case LoginStatus.versionMismatch:
          loginError.value = result.errorMessage?.isNotEmpty == true
              ? result.errorMessage!
              : 'App version mismatch. Please update the app to continue.';
          break;
        case LoginStatus.networkError:
          loginError.value = 'Could not connect to the server. Please check your internet connection and try again.';
          break;
        case LoginStatus.deviceConflict:
          loginError.value = 'This account is already logged in on another device.\nPlease log out from that device first.';
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

  // ── Routing & logout ──────────────────────────────────────────────────────

  String getHomeRoute() => routeHome;

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefUserId);
    await prefs.remove(prefUserName);
    await prefs.remove(prefUserDesignation);
    await prefs.remove('emp_id');
    await prefs.remove('geoFencing');
    await prefs.remove(prefIsTimekeeper);        // ← clear on logout
    await prefs.setBool(prefIsAuthenticated, false);

    currentUser.value  = null;
    isTimekeeper.value = false;                  // ← reset observable
    _cachedEmpId       = '';
    _cachedPassword    = '';

    Get.offAllNamed(routeCodeScreen);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Biometric helpers
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadBiometricState() async {
    final prefs = await SharedPreferences.getInstance();
    isBiometricEnabled.value = prefs.getBool(prefBiometricEnabled) ?? false;
    biometricModality.value  = await BiometricService.getPrimaryModality();
    debugPrint('🔏 Biometric enabled: ${isBiometricEnabled.value}');
    debugPrint('🔏 Biometric modality: ${biometricModality.value}');
  }

  String get biometricLabel {
    switch (biometricModality.value) {
      case BiometricModality.face:        return 'Face ID';
      case BiometricModality.fingerprint: return 'Fingerprint';
      case BiometricModality.none:        return 'Biometric';
    }
  }

  String get _authReason {
    switch (biometricModality.value) {
      case BiometricModality.face:        return 'Look at your phone to sign in';
      case BiometricModality.fingerprint: return 'Scan your fingerprint to sign in';
      case BiometricModality.none:        return 'Authenticate to sign in';
    }
  }

  String get _enableReason {
    switch (biometricModality.value) {
      case BiometricModality.face:        return 'Verify your face to enable Face ID login';
      case BiometricModality.fingerprint: return 'Verify your fingerprint to enable biometric login';
      case BiometricModality.none:        return 'Verify your identity to enable biometric login';
    }
  }

  Future<String> enableBiometricLogin({BiometricModality? chosenModality}) async {
    biometricModality.value = chosenModality ?? await BiometricService.getPrimaryModality();

    final available = await BiometricService.isAvailable();
    if (!available) {
      final lbl = biometricModality.value == BiometricModality.face ? 'Face ID' : 'biometric authentication';
      return 'Your device does not support $lbl, or no biometric has been enrolled in device settings.';
    }

    if (_cachedEmpId.isEmpty || _cachedPassword.isEmpty) {
      return 'Session credentials unavailable. Please log out and sign in with your password once, then try again.';
    }

    final verified = await BiometricService.authenticate(reason: _enableReason);
    if (!verified) {
      return biometricModality.value == BiometricModality.face
          ? 'Face verification failed or was cancelled.'
          : 'Fingerprint verification failed or was cancelled.';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefBiometricEnabled,   true);
    await prefs.setString(prefBiometricUserId,   _cachedEmpId);
    await prefs.setString(prefBiometricPassword, _cachedPassword);
    isBiometricEnabled.value = true;

    debugPrint('✅ $biometricLabel login enabled for: $_cachedEmpId');
    return '';
  }

  Future<void> disableBiometricLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefBiometricEnabled);
    await prefs.remove(prefBiometricUserId);
    await prefs.remove(prefBiometricPassword);
    isBiometricEnabled.value = false;
    debugPrint('🚫 $biometricLabel login disabled');
  }

  Future<bool> loginWithBiometric() async {
    try {
      loginError.value        = '';
      biometricModality.value = await BiometricService.getPrimaryModality();

      final authenticated = await BiometricService.authenticate(reason: _authReason);
      if (!authenticated) {
        loginError.value = biometricModality.value == BiometricModality.face
            ? 'Face ID authentication was cancelled or failed.'
            : 'Biometric authentication was cancelled or failed.';
        return false;
      }

      final prefs    = await SharedPreferences.getInstance();
      final empId    = prefs.getString(prefBiometricUserId)   ?? '';
      final password = prefs.getString(prefBiometricPassword) ?? '';

      if (empId.isEmpty || password.isEmpty) {
        await disableBiometricLogin();
        loginError.value = '$biometricLabel session expired. Please sign in with your password.';
        return false;
      }

      debugPrint('🔓 $biometricLabel login for: $empId');
      return await login(empId, password);
    } catch (e) {
      loginError.value = '$biometricLabel authentication failed. Please try again.';
      debugPrint('❌ loginWithBiometric error: $e');
      return false;
    }
  }
}
