// login_repository.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../Models/LoginModels/login_models.dart';
import '../../Services/biometric_service.dart';
import '../../Services/remote_config_service.dart';
import '../../constants.dart';
import '../../Screens/code_screen.dart'; // ← NAYA IMPORT

class LoginRepository extends GetxService {

  static const String prefCachedEndTime = 'cached_end_time';
  static const String prefCachedOvertime = 'cached_overtime';
  static const String prefCachedShift = 'cached_shift';
  static const String prefCachedImageUrl = 'cached_image_url';
  static const String prefCachedDepId = 'cached_dep_id';
  static const String currentAppVersion = "2.3";

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String> _getDeviceModel() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.model;
      }
    } catch (e) {
      debugPrint('⚠️ Could not get device model: $e');
    }
    return 'unknown';
  }

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<String> _getDeviceModel() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        return androidInfo.model;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        return iosInfo.model;
      }
    } catch (e) {
      debugPrint('⚠️ Could not get device model: $e');
    }
    return 'unknown';
  }

  Future<VersionCheckResult> isCompanyVersionValid(String companyCode) async {
    try {
      final apiUrl = RemoteConfigService.getCompanyValidationUrl(companyCode);
      debugPrint('📡 [VERSION CHECK] URL: $apiUrl');

      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));

      if (response.statusCode != 200) {
        return VersionCheckResult.error('Server error. Please try again.');
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> items = data['items'] ?? [];

      if (items.isEmpty) {
        return VersionCheckResult.error('Company "$companyCode" not found.');
      }

      Map<String, dynamic>? companyData;
      for (var item in items) {
        final map = item as Map<String, dynamic>;
        if (map['company_code'] == companyCode) {
          companyData = map;
          break;
        }
      }

      if (companyData == null) {
        return VersionCheckResult.error('Company not found.');
      }

      dynamic versionValue = companyData['version'];
      String companyVersion = versionValue?.toString() ?? '';

      if (companyVersion.endsWith('.0')) {
        companyVersion = companyVersion.substring(0, companyVersion.length - 2);
      }

      final isValid = (companyVersion == currentAppVersion);

      if (isValid) {
        return VersionCheckResult.valid();
      } else {
        return VersionCheckResult.mismatch(
          appVersion: currentAppVersion,
          requiredVersion: companyVersion,
        );
      }
    } catch (e) {
      return VersionCheckResult.error('Could not verify app version.');
    }
  }

  Future<bool> fetchAndCacheEmployeesForCompany(String companyCode) async {
    try {
      final apiUrl = RemoteConfigService.getLoginApiUrl(companyCode);
      debugPrint('📡 [EMPLOYEE CACHE] Fetching: $apiUrl');

      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));

      if (response.statusCode != 200) {
        return false;
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> items = data['items'] ?? [];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_employees_$companyCode', jsonEncode(items));
      await prefs.setString('cached_employees_company', companyCode);

      return true;
    } catch (e) {
      debugPrint('❌ [EMPLOYEE CACHE] Error: $e');
      return false;
    }
  }

  Future<LoginResult> getUserByCredentials(String userId, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCompanyCode = prefs.getString(prefCompanyCode) ?? '';

      if (savedCompanyCode.isEmpty) {
        return LoginResult.noCompany();
      }

      final versionCheck = await isCompanyVersionValid(savedCompanyCode);
      if (!versionCheck.isValid) {
        return LoginResult.versionMismatch(versionCheck.message);
      }

      List<dynamic> items = [];

      try {
        final apiUrl = RemoteConfigService.getLoginApiUrl(savedCompanyCode);
        final response = await http
            .get(Uri.parse(apiUrl))
            .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          items = data['items'] ?? [];
          await prefs.setString('cached_employees_$savedCompanyCode', jsonEncode(items));
          debugPrint('🌐 [LOGIN] Live data fetched from API');
        } else {
          throw Exception('Non-200 status: ${response.statusCode}');
        }
      } catch (_) {
        final cached = prefs.getString('cached_employees_$savedCompanyCode');
        if (cached != null && cached.isNotEmpty) {
          items = jsonDecode(cached) as List<dynamic>;
          debugPrint('📦 [LOGIN] Offline — using cached employee data');
        } else {
          return LoginResult.networkError();
        }
      }

      final int? userIdInt = int.tryParse(userId);

      for (var item in items) {
        final map = item as Map<String, dynamic>;
        final user = LoginModels.fromJson(map);

        final bool idMatches = userIdInt != null
            ? user.emp_id == userIdInt
            : user.emp_id.toString() == userId;

        if (!idMatches) continue;

        final String storedPassword = map['portal_password']?.toString() ?? '';
        if (storedPassword != password) {
          return LoginResult.wrongPassword();
        }

        if (user.end_time != null && user.end_time!.isNotEmpty) {
          await prefs.setString(prefCachedEndTime, user.end_time!);
        }
        await prefs.setString(
          prefCachedOvertime,
          (user.over_time != null && user.over_time!.isNotEmpty)
              ? user.over_time!
              : 'no',
        );
        if (user.shift != null && user.shift!.isNotEmpty) {
          await prefs.setString(prefCachedShift, user.shift!);
        }
        if (user.image_url != null && user.image_url!.isNotEmpty) {
          await prefs.setString(prefCachedImageUrl, user.image_url!);
        }
        if (user.dep_id != null && user.dep_id!.isNotEmpty) {
          await prefs.setString(prefCachedDepId, user.dep_id!);
        }

        postSignInDetails(
          empId: userId,
          empName: user.emp_name ?? '',
          companyCode: savedCompanyCode,
        );

        return LoginResult.success(user);
      }

      return LoginResult.notInCompany(savedCompanyCode);
    } catch (e) {
      return LoginResult.networkError();
    }
  }

  Future<void> postSignInDetails({
    required String empId,
    required String empName,
    required String companyCode,
  }) async {
    final signInEndpoint = RemoteConfigService.getSignInUrl();

    final deviceModel = await _getDeviceModel();

    String androidVersion = 'unknown';
    String deviceId = 'unknown';
    String simInfo = 'unknown';

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        androidVersion = androidInfo.version.release;
        deviceId = androidInfo.id;

        try {
          final status = await Permission.phone.request();
          if (status.isGranted) {
            const simChannel = MethodChannel('sim_info_channel');
            final String? result = await simChannel.invokeMethod<String>('getSimInfo');
            simInfo = result ?? 'No SIM';
          } else {
            simInfo = 'permission_denied';
            debugPrint('⚠️ [SIM INFO] Phone permission denied');
          }
        } catch (e) {
          debugPrint('⚠️ Could not get SIM info: $e');
          simInfo = 'unavailable';
        }
      }
    } catch (e) {
      debugPrint('⚠️ Could not get Android version/Device ID: $e');
    }

    final body = jsonEncode({
      'emp_id': empId,
      'emp_name': empName,
      'company_code': companyCode,
      'app_version': 2.3,
      'timestamp': DateTime.now().toIso8601String(),
      'device_info': deviceModel,
      'android_version': androidVersion,
      'device_id': deviceId,
      'sim_info': simInfo,
    });

    try {
      final response = await http
          .post(
        Uri.parse(signInEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: body,
      )
          .timeout(const Duration(seconds: 15));
      debugPrint('📤 [SIGN-IN LOG] Status: ${response.statusCode}');
      debugPrint('📱 [SIGN-IN LOG] Device model: $deviceModel');
      debugPrint('📶 [SIGN-IN LOG] SIM info: $simInfo');
    } catch (e) {
      debugPrint('⚠️ [SIGN-IN LOG] Failed: $e');
    }
  }

  Future<void> fetchAndCacheLocations(String empId, String companyCode) async {
    try {
      final locationUrl = RemoteConfigService.getGeofenceUrl(empId, companyCode);

      final response = await http.get(
        Uri.parse(locationUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['items'] ?? []) as List<dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_locations', jsonEncode(items));
        await prefs.setString('cached_locations_emp_id', empId);
      }
    } catch (e) {
      debugPrint('⚠️ [LOCATION CACHE] Failed: $e');
    }
  }

  Future<String?> getCachedDepId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefCachedDepId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FULL EMPLOYEE DATA LIVE REFRESH
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> refreshEmployeeDataIfOnline(String userId, String companyCode) async {
    try {
      final apiUrl = RemoteConfigService.getLoginApiUrl(companyCode);
      debugPrint('📡 [EMP REFRESH] Fetching: $apiUrl');

      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));

      if (response.statusCode != 200) {
        debugPrint('⚠️ [EMP REFRESH] Non-200: ${response.statusCode}');
        return;
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> items = data['items'] ?? [];
      final int? userIdInt = int.tryParse(userId);

      for (var item in items) {
        final map = item as Map<String, dynamic>;
        final user = LoginModels.fromJson(map);

        final bool idMatches = userIdInt != null
            ? user.emp_id == userIdInt
            : user.emp_id.toString() == userId;

        if (!idMatches) continue;

        final prefs = await SharedPreferences.getInstance();

        if (user.end_time != null && user.end_time!.isNotEmpty) {
          await prefs.setString(prefCachedEndTime, user.end_time!);
        }
        await prefs.setString(
          prefCachedOvertime,
          (user.over_time != null && user.over_time!.isNotEmpty)
              ? user.over_time!
              : 'no',
        );
        if (user.shift != null && user.shift!.isNotEmpty) {
          await prefs.setString(prefCachedShift, user.shift!);
        }
        if (user.image_url != null && user.image_url!.isNotEmpty) {
          await prefs.setString(prefCachedImageUrl, user.image_url!);
        }
        if (user.dep_id != null && user.dep_id!.isNotEmpty) {
          await prefs.setString(prefCachedDepId, user.dep_id!);
        }

        debugPrint('✅ [EMP REFRESH] All fields updated for emp=$userId');
        return;
      }

      debugPrint('⚠️ [EMP REFRESH] Employee $userId not found in response');
    } catch (e) {
      debugPrint('⚠️ [EMP REFRESH] Failed (offline?): $e');
    }
  }

  Future<String?> refreshOvertimeIfOnline(String userId, String companyCode) async {
    try {
      final apiUrl = RemoteConfigService.getLoginApiUrl(companyCode);
      debugPrint('📡 [OVERTIME REFRESH] Fetching: $apiUrl');

      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));

      if (response.statusCode != 200) {
        debugPrint('⚠️ [OVERTIME REFRESH] Non-200 status: ${response.statusCode}');
        return null;
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> items = data['items'] ?? [];
      final int? userIdInt = int.tryParse(userId);

      for (var item in items) {
        final map = item as Map<String, dynamic>;
        final user = LoginModels.fromJson(map);

        final bool idMatches = userIdInt != null
            ? user.emp_id == userIdInt
            : user.emp_id.toString() == userId;

        if (!idMatches) continue;

        final String newOvertime =
        (user.over_time != null && user.over_time!.isNotEmpty)
            ? user.over_time!
            : 'no';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefCachedOvertime, newOvertime);
        debugPrint('✅ [OVERTIME REFRESH] Saved latest overtime: $newOvertime');
        return newOvertime;
      }

      debugPrint('⚠️ [OVERTIME REFRESH] Employee $userId not found in API response');
      return null;
    } catch (e) {
      debugPrint('⚠️ [OVERTIME REFRESH] Failed (offline?): $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SERVER FORCED LOGOUT CHECK
  // API: http://oracle.metaxperts.net/ords/gps_workforce/logout/get
  // TimerCard har 5 seconds mein is method ko call karta hai.
  // Agar server pe is employee ka logout record mila → app logout ho jati hai.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> checkServerLogout(String empId, String companyCode) async {
    try {
      final uri = Uri.parse(
        'http://oracle.metaxperts.net/ords/gps_workforce/logout/get'
            '?emp_id=$empId&company_code=$companyCode',
      );

      // debugPrint('📡 [LOGOUT CHECK] Calling: $uri');

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      // debugPrint('📡 [LOGOUT CHECK] Status code: ${response.statusCode}');
      // debugPrint('📡 [LOGOUT CHECK] Raw body: ${response.body}');

      if (response.statusCode != 200) {
        debugPrint('⚠️ [LOGOUT CHECK] Non-200 — skipping');
        return;
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> items = data['items'] ?? [];

      debugPrint('📡 [LOGOUT CHECK] Items count: ${items.length}');

      if (items.isEmpty) {
        debugPrint('📡 [LOGOUT CHECK] No records found — no logout');
        return;
      }

      for (var item in items) {
        final map = item as Map<String, dynamic>;
        debugPrint('📡 [LOGOUT CHECK] Record: $map');
      }

      // Sab se latest record dhundo REQUEST_TIMESTAMP ke basis par
      Map<String, dynamic>? latestRecord;
      DateTime? latestTimestamp;

      for (var item in items) {
        final map = item as Map<String, dynamic>;
        final tsRaw = (map['REQUEST_TIMESTAMP'] ?? map['request_timestamp'] ?? '').toString().trim();
        if (tsRaw.isEmpty) continue;
        try {
          final ts = DateTime.parse(tsRaw);
          if (latestTimestamp == null || ts.isAfter(latestTimestamp)) {
            latestTimestamp = ts;
            latestRecord = map;
          }
        } catch (_) {
          debugPrint('⚠️ [LOGOUT CHECK] Could not parse timestamp: $tsRaw');
        }
      }

      if (latestRecord == null) {
        debugPrint('⚠️ [LOGOUT CHECK] No valid timestamp found — no logout');
        return;
      }

      final latestStatus = (latestRecord['STATUS'] ?? latestRecord['status'] ?? '').toString().trim().toLowerCase();
      debugPrint('📡 [LOGOUT CHECK] Latest REQUEST_TIMESTAMP: $latestTimestamp');
      debugPrint('📡 [LOGOUT CHECK] Latest STATUS value: "$latestStatus"');

      if (latestStatus == 'requested') {
        debugPrint('🔒 [LOGOUT CHECK] Latest STATUS=Requested — logging out emp=$empId');
        // PUT API call — latest record ki STATUS aur ACTUAL_TIMESTAMP update karo
        await _updateLogoutRecord(latestRecord);
        await _performForcedLogout();
      } else {
        debugPrint('📡 [LOGOUT CHECK] Latest STATUS is not Requested — no logout');
      }
    } catch (e) {
      debugPrint('⚠️ [LOGOUT CHECK] Exception: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PUT API — Latest logout record ki STATUS=Completed aur ACTUAL_TIMESTAMP update karo
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _updateLogoutRecord(Map<String, dynamic> record) async {
    try {
      final id = record['ID'] ?? record['id'];
      final companyCode = record['COMPANY_CODE'] ?? record['company_code'];
      if (id == null) {
        debugPrint('⚠️ [LOGOUT UPDATE] ID not found in record — skipping PUT');
        return;
      }

      final uri = Uri.parse(
        'http://oracle.metaxperts.net/ords/gps_workforce/updatelogout/put',
      );

      final body = jsonEncode({
        'id': id,
        'status': 'Completed',
        'company_code': companyCode,
      });

      debugPrint('📡 [LOGOUT UPDATE] PUT calling: $uri');
      debugPrint('📡 [LOGOUT UPDATE] Body: $body');

      final response = await http
          .put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      )
          .timeout(const Duration(seconds: 10));

      debugPrint('📡 [LOGOUT UPDATE] Response code: ${response.statusCode}');
      debugPrint('📡 [LOGOUT UPDATE] Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ [LOGOUT UPDATE] STATUS=Completed aur ACTUAL_TIMESTAMP updated for ID=$id');
      } else {
        debugPrint('⚠️ [LOGOUT UPDATE] Failed — status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ [LOGOUT UPDATE] Exception: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FORCED LOGOUT HELPER
  // Biometric keys preserve karta hai, baqi sab clear karta hai.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _performForcedLogout() async {
    final prefs = await SharedPreferences.getInstance();

    // Biometric keys save karo
    final biometricEnabled  = prefs.getBool(prefBiometricEnabled);
    final biometricUserId   = prefs.getString(prefBiometricUserId);
    final biometricPassword = prefs.getString(prefBiometricPassword);

    await prefs.clear();

    if (biometricEnabled == true &&
        biometricUserId   != null &&
        biometricPassword != null) {
      await prefs.setBool(prefBiometricEnabled,   true);
      await prefs.setString(prefBiometricUserId,   biometricUserId);
      await prefs.setString(prefBiometricPassword, biometricPassword);
    }

    Get.offAll(() => const CodeScreen());
  }
}

enum LoginStatus { success, notInCompany, wrongPassword, noCompany, networkError, versionMismatch }

class LoginResult {
  final LoginStatus status;
  final LoginModels? user;
  final String? companyCode;
  final String? errorMessage;

  LoginResult._({required this.status, this.user, this.companyCode, this.errorMessage});

  factory LoginResult.success(LoginModels user) =>
      LoginResult._(status: LoginStatus.success, user: user);

  factory LoginResult.notInCompany(String code) =>
      LoginResult._(status: LoginStatus.notInCompany, companyCode: code);

  factory LoginResult.wrongPassword() =>
      LoginResult._(status: LoginStatus.wrongPassword);

  factory LoginResult.noCompany() =>
      LoginResult._(status: LoginStatus.noCompany);

  factory LoginResult.networkError() =>
      LoginResult._(status: LoginStatus.networkError);

  factory LoginResult.versionMismatch([String? message]) =>
      LoginResult._(status: LoginStatus.versionMismatch, errorMessage: message);

  bool get isSuccess => status == LoginStatus.success;
}

class VersionCheckResult {
  final bool isValid;
  final String message;

  VersionCheckResult._({required this.isValid, required this.message});

  factory VersionCheckResult.valid() =>
      VersionCheckResult._(isValid: true, message: '');

  factory VersionCheckResult.mismatch({
    required String appVersion,
    required String requiredVersion,
  }) =>
      VersionCheckResult._(
        isValid: false,
        message: 'App version mismatch. Please update the app.',
      );

  factory VersionCheckResult.error(String reason) =>
      VersionCheckResult._(isValid: false, message: reason);
}