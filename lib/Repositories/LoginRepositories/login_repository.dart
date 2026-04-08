
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../Models/LoginModels/login_models.dart';
import '../../constants.dart';

class LoginRepository extends GetxService {

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
  //   2. Load the cached employee list for that company (backend already
  //      filtered by company_code, so every record here belongs to this company).
  //   3. Find the record whose emp_id matches the entered employee ID.
  //      • Not found  → "Employee ID does not belong to this company."
  //   4. Verify portal_password.
  //      • Mismatch   → "Incorrect password."
  //   5. Both match  → return the LoginModels object (login succeeds).
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

        debugPrint('✅ [LOGIN] ${user.emp_name} | ${user.job} | company=$savedCompanyCode');
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

  Future<void> fetchAndCacheEndTime(String empId, String companyCode) async {
    try {
      debugPrint('⏰ [END TIME CACHE] emp=$empId company=$companyCode');
      final response = await http.get(
        Uri.http('oracle.metaxperts.net', '/ords/gps_workforce/endtime/get/',
            {'emp_id': empId, 'company_code': companyCode}),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        String? endTimeStr;

        if (decoded is Map<String, dynamic>) {
          endTimeStr = _extractEndTimeFromMap(decoded);
          if (endTimeStr == null) {
            final it = decoded['items'];
            if (it is List && it.isNotEmpty && it.first is Map<String, dynamic>) {
              endTimeStr = _extractEndTimeFromMap(
                  it.first as Map<String, dynamic>);
            }
          }
        } else if (decoded is List &&
            decoded.isNotEmpty &&
            decoded.first is Map<String, dynamic>) {
          endTimeStr =
              _extractEndTimeFromMap(decoded.first as Map<String, dynamic>);
        }

        if (endTimeStr != null && endTimeStr.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_end_time', endTimeStr);
          await prefs.setString('cached_end_time_emp_id', empId);
          debugPrint('✅ [END TIME CACHE] $endTimeStr');
        }
      }
    } catch (e) {
      debugPrint('⚠️ [END TIME CACHE] $e');
    }
  }

  String? _extractEndTimeFromMap(Map<String, dynamic> map) {
    for (final key in ['end_time', 'endTime', 'end_hour', 'shift_end', 'time']) {
      final val = map[key];
      if (val != null && val.toString().isNotEmpty) return val.toString();
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result wrapper — gives LoginViewModel precise failure reasons so it can
// show the right error message to the user.
// ─────────────────────────────────────────────────────────────────────────────
enum LoginStatus { success, notInCompany, wrongPassword, noCompany, networkError }

class LoginResult {
  final LoginStatus status;
  final LoginModels? user;
  final String? companyCode; // populated for notInCompany case

  LoginResult._({required this.status, this.user, this.companyCode});

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

  bool get isSuccess => status == LoginStatus.success;
}