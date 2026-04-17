// login_repository.dart - Fixed version with correct API endpoint

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../Models/LoginModels/login_models.dart';
import '../../constants.dart';

class LoginRepository extends GetxService {

  // SharedPreferences keys for cached employee data
  static const String prefCachedEndTime = 'cached_end_time';
  static const String prefCachedOvertime = 'cached_overtime';
  static const String prefCachedShift = 'cached_shift';
  static const String prefCachedImageUrl = 'cached_image_url';
  static const String prefCachedDepId = 'cached_dep_id';

  // Current app version - static value for comparison
  static const String currentAppVersion = "2.1"; // Using appVersion from constants

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 0 — Check if company version matches current app version
  // Called before login to validate company's app version
  // ─────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────
// STEP 0 — Check if company version matches current app version
// Called before login to validate company's app version
// ─────────────────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────────────────
// STEP 0 — Check if company version matches current app version
// Called before login to validate company's app version
// ─────────────────────────────────────────────────────────────────────────
  Future<VersionCheckResult> isCompanyVersionValid(String companyCode) async {
    try {
      final apiUrl = '$companyApiEndpoint?company_code=$companyCode';
      debugPrint('📡 [VERSION CHECK] Checking version for company: $companyCode');
      debugPrint('📡 [VERSION CHECK] URL: $apiUrl');

      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 30));

      debugPrint('📡 [VERSION CHECK] Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('❌ [VERSION CHECK] HTTP ${response.statusCode}');
        return VersionCheckResult.error('Server returned status ${response.statusCode}. Please try again.');
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> items = data['items'] ?? [];

      if (items.isEmpty) {
        debugPrint('❌ [VERSION CHECK] Company not found: $companyCode');
        return VersionCheckResult.error('Company "$companyCode" was not found. Please verify your company code.');
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
        debugPrint('❌ [VERSION CHECK] Company $companyCode not found in items');
        return VersionCheckResult.error('Company "$companyCode" was not found. Please verify your company code.');
      }

      debugPrint('📡 [VERSION CHECK] Full company data: $companyData');

      dynamic versionValue = companyData['version'];
      String companyVersion = '';

      if (versionValue != null) {
        if (versionValue is int) {
          companyVersion = versionValue.toString();
        } else if (versionValue is double) {
          companyVersion = versionValue.toString();
          if (companyVersion.endsWith('.0')) {
            companyVersion = companyVersion.substring(0, companyVersion.length - 2);
          }
        } else {
          companyVersion = versionValue.toString();
        }
      }

      debugPrint('📡 [VERSION CHECK] Company version (raw): $versionValue');
      debugPrint('📡 [VERSION CHECK] Company version (string): $companyVersion');
      debugPrint('📡 [VERSION CHECK] App version: $currentAppVersion');

      final isValid = (companyVersion == currentAppVersion);

      if (isValid) {
        debugPrint('✅ [VERSION CHECK] Version matches! Login allowed.');
        return VersionCheckResult.valid();
      } else {
        debugPrint('❌ [VERSION CHECK] Version mismatch! Login denied.');
        return VersionCheckResult.mismatch(
          appVersion: currentAppVersion,
          requiredVersion: companyVersion,
        );
      }
    } catch (e) {
      debugPrint('❌ [VERSION CHECK] Error: $e');
      return VersionCheckResult.error('Could not verify app version. Please check your connection and try again.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — Called from CodeScreen after company code is validated.
  // Fetches ALL employees for that company_code from the backend and caches
  // them locally. Backend SQL: WHERE company_code = :company_code
  // So only employees of this company are returned — no cross-company leakage.
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> fetchAndCacheEmployeesForCompany(String companyCode) async {
    try {
      final apiUrl = '$loginApiEndpoint?company_code=$companyCode';
      debugPrint('📡 [EMPLOYEE CACHE] Fetching: $apiUrl');

      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('❌ [EMPLOYEE CACHE] HTTP ${response.statusCode}');
        return false;
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> items = data['items'] ?? [];

      debugPrint('✅ [EMPLOYEE CACHE] ${items.length} employees for company: $companyCode');

      // Debug: Check if dep_id exists in first item
      if (items.isNotEmpty) {
        final firstItem = items.first as Map<String, dynamic>;
        debugPrint('📝 [EMPLOYEE CACHE] First employee fields: ${firstItem.keys}');
        debugPrint('📝 [EMPLOYEE CACHE] dep_id value: ${firstItem['dep_id'] ?? firstItem['DEP_ID']}');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_employees_$companyCode', jsonEncode(items));
      await prefs.setString('cached_employees_company', companyCode);

      return true;
    } catch (e) {
      debugPrint('❌ [EMPLOYEE CACHE] Error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — Called from LoginScreen when user taps Sign In.
  //
  // Logic:
  //   1. Load the saved company_code from SharedPreferences.
  //   2. FIRST: Check if company version matches current app version
  //      • If not match → "App version outdated. Please update app."
  //   3. Load the cached employee list for that company (backend already
  //      filtered by company_code, so every record here belongs to this company).
  //   4. Find the record whose emp_id matches the entered employee ID.
  //      • Not found  → "Employee ID does not belong to this company."
  //   5. Verify portal_password.
  //      • Mismatch   → "Incorrect password."
  //   6. Both match  → return the LoginModels object (login succeeds).
  // ─────────────────────────────────────────────────────────────────────────
  Future<LoginResult> getUserByCredentials(
      String userId, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCompanyCode = prefs.getString(prefCompanyCode) ?? '';

      if (savedCompanyCode.isEmpty) {
        debugPrint('❌ [LOGIN] No company code saved.');
        return LoginResult.noCompany();
      }

      // ── FIRST: Check company version ──────────────────────────────────────
      final versionCheck = await isCompanyVersionValid(savedCompanyCode);
      if (!versionCheck.isValid) {
        debugPrint('❌ [LOGIN] Version check failed for company: $savedCompanyCode — \${versionCheck.message}');
        return LoginResult.versionMismatch(versionCheck.message);
      }

      // ── Load cached employees (or fetch live as fallback) ──────────────
      List<dynamic> items = [];
      final cached = prefs.getString('cached_employees_$savedCompanyCode');

      if (cached != null && cached.isNotEmpty) {
        items = jsonDecode(cached) as List<dynamic>;
        debugPrint('📦 [LOGIN] ${items.length} cached employees for: $savedCompanyCode');
      } else {
        debugPrint('🌐 [LOGIN] Cache miss — fetching live...');
        final apiUrl = '$loginApiEndpoint?company_code=$savedCompanyCode';
        final response = await http
            .get(Uri.parse(apiUrl))
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          items = data['items'] ?? [];
          await prefs.setString(
              'cached_employees_$savedCompanyCode', jsonEncode(items));
          debugPrint('✅ [LOGIN] Live fetch: ${items.length} employees');
        } else {
          debugPrint('❌ [LOGIN] Live fetch failed: ${response.statusCode}');
          return LoginResult.networkError();
        }
      }

      // ── Search for matching emp_id ─────────────────────────────────────
      final int? userIdInt = int.tryParse(userId);

      for (var item in items) {
        final map = item as Map<String, dynamic>;
        final user = LoginModels.fromJson(map);

        final bool idMatches = userIdInt != null
            ? user.emp_id == userIdInt
            : user.emp_id.toString() == userId;

        if (!idMatches) continue;

        // emp_id found — now check password
        final String storedPassword =
            map['portal_password']?.toString() ?? '';
        if (storedPassword != password) {
          debugPrint('❌ [LOGIN] Wrong password for emp_id=$userId');
          return LoginResult.wrongPassword();
        }

        // Save end_time, over_time, and shift to SharedPreferences
        if (user.end_time != null && user.end_time!.isNotEmpty) {
          await prefs.setString(prefCachedEndTime, user.end_time!);
          debugPrint('✅ [LOGIN] Cached end_time: ${user.end_time}');
        }
        if (user.over_time != null && user.over_time!.isNotEmpty) {
          await prefs.setString(prefCachedOvertime, user.over_time!);
          debugPrint('✅ [LOGIN] Cached over_time: ${user.over_time}');
        }
        if (user.shift != null && user.shift!.isNotEmpty) {
          await prefs.setString(prefCachedShift, user.shift!);
          debugPrint('✅ [LOGIN] Cached shift: ${user.shift}');
        }
        if (user.image_url != null && user.image_url!.isNotEmpty) {
          await prefs.setString(prefCachedImageUrl, user.image_url!);
          debugPrint('🖼️ [LOGIN] Cached image_url: ${user.image_url}');
        } else {
          debugPrint('🖼️ [LOGIN] No profile image for emp_id=$userId');
        }

        // Save dep_id to SharedPreferences
        if (user.dep_id != null && user.dep_id!.isNotEmpty) {
          await prefs.setString(prefCachedDepId, user.dep_id!);
          debugPrint('📁 [LOGIN] Cached dep_id: ${user.dep_id}');
        } else {
          debugPrint('📁 [LOGIN] No dep_id for emp_id=$userId');
        }

        debugPrint('✅ [LOGIN] ${user.emp_name} | ${user.job} | company=$savedCompanyCode | dep_id=${user.dep_id}');

        // Fire-and-forget: log sign-in event to APP_SIGN_IN_DETAILS
        postSignInDetails(
          empId: userId,
          empName: user.emp_name ?? '',
          companyCode: savedCompanyCode,
        );

        return LoginResult.success(user);
      }

      // emp_id was not in the cached list for this company_code
      debugPrint('❌ [LOGIN] emp_id=$userId not found in company=$savedCompanyCode');
      return LoginResult.notInCompany(savedCompanyCode);
    } catch (e) {
      debugPrint('❌ [LOGIN] Exception: $e');
      return LoginResult.networkError();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 3 — Fire-and-forget: POST sign-in event to APP_SIGN_IN_DETAILS.
  // Called after a successful credential check. Failures are logged only —
  // they never affect the login flow.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> postSignInDetails({
    required String empId,
    required String empName,
    required String companyCode,
  }) async {
    const String signInEndpoint =
        'http://oracle.metaxperts.net/ords/gps_workforce/sign_in/post/';

    final body = jsonEncode({
      'emp_id': empId,
      'emp_name': empName,
      'company_code': companyCode,
      'app_version': 2.1,
      'timestamp': DateTime.now().toIso8601String(),
    });

    debugPrint('📤 [SIGN-IN LOG] Posting to $signInEndpoint');
    debugPrint('📤 [SIGN-IN LOG] Payload: $body');

    try {
      final response = await http
          .post(
        Uri.parse(signInEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: body,
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('📤 [SIGN-IN LOG] Response status: ${response.statusCode}');
      debugPrint('📤 [SIGN-IN LOG] Response body:   ${response.body}');
    } catch (e) {
      debugPrint('⚠️ [SIGN-IN LOG] Failed (non-blocking): $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Background helpers — called after successful login (non-blocking)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> fetchAndCacheLocations(String empId, String companyCode) async {
    try {
      debugPrint('📍 [LOCATION CACHE] emp=$empId company=$companyCode');
      final response = await http.get(
        Uri.http('oracle.metaxperts.net', '/ords/gps_workforce/geofenceinfo/get',
            {'emp_id': empId, 'company_code': companyCode}),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['items'] ?? []) as List<dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_locations', jsonEncode(items));
        await prefs.setString('cached_locations_emp_id', empId);
        debugPrint('✅ [LOCATION CACHE] ${items.length} location(s) cached');
      }
    } catch (e) {
      debugPrint('⚠️ [LOCATION CACHE] Failed: $e');
    }
  }

  // Helper method to get cached dep_id
  Future<String?> getCachedDepId() async {
    final prefs = await SharedPreferences.getInstance();
    final depId = prefs.getString(prefCachedDepId);
    debugPrint('📁 [GET CACHED] Retrieved dep_id: $depId');
    return depId;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result wrapper — gives LoginViewModel precise failure reasons so it can
// show the right error message to the user.
// ─────────────────────────────────────────────────────────────────────────────
enum LoginStatus { success, notInCompany, wrongPassword, noCompany, networkError, versionMismatch }

class LoginResult {
  final LoginStatus status;
  final LoginModels? user;
  final String? companyCode; // populated for notInCompany case
  final String? errorMessage; // populated for versionMismatch and other errors

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

// ─────────────────────────────────────────────────────────────────────────────
// Version check result — carries validity flag and a human-readable message
// for display in the Snackbar when a mismatch occurs.
// ─────────────────────────────────────────────────────────────────────────────
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
        message: 'App version mismatch: your app is v$appVersion but this company requires v$requiredVersion. Please update the app to continue.',
      );

  factory VersionCheckResult.error(String reason) =>
      VersionCheckResult._(isValid: false, message: reason);
}