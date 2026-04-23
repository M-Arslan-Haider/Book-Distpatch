
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../Models/LoginModels/login_models.dart';
import '../../Services/remote_config_service.dart';
import '../../constants.dart';

class LoginRepository extends GetxService {

  static const String prefCachedEndTime = 'cached_end_time';
  static const String prefCachedOvertime = 'cached_overtime';
  static const String prefCachedShift = 'cached_shift';
  static const String prefCachedImageUrl = 'cached_image_url';
  static const String prefCachedDepId = 'cached_dep_id';
  static const String currentAppVersion = "2.2";

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
      final cached = prefs.getString('cached_employees_$savedCompanyCode');

      if (cached != null && cached.isNotEmpty) {
        items = jsonDecode(cached) as List<dynamic>;
      } else {
        final apiUrl = RemoteConfigService.getLoginApiUrl(savedCompanyCode);
        final response = await http
            .get(Uri.parse(apiUrl))
            .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          items = data['items'] ?? [];
          await prefs.setString('cached_employees_$savedCompanyCode', jsonEncode(items));
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

    final body = jsonEncode({
      'emp_id': empId,
      'emp_name': empName,
      'company_code': companyCode,
      'app_version': 2.2,
      'timestamp': DateTime.now().toIso8601String(),
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