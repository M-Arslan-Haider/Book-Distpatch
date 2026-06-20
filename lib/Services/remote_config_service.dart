

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // Default values (used when offline or fetch fails)
  static const Map<String, dynamic> _defaults = {
    // Base URL
    'api_base_url': 'http://oracle.metaxperts.net/ords/gps_workforce',

    // Auth & Company Endpoints
    'company_validation_endpoint': '/registeredcompanies/get/',
    'login_endpoint': '/loginget/get/',
    'sign_in_endpoint': '/sign_in/post/',
    'geofence_endpoint': '/geofenceinfo/get',

    // Attendance Endpoints
    'attendance_in_endpoint': '/attendanceinpost/post/',
    'attendance_out_endpoint': '/attendanceout/post/',
    'attendance_data_endpoint': '/attendancedata1/get',
    'attendance_serial_endpoint': '/attendanceinserial/get/',

    // Location Endpoints
    'location_endpoint': '/location/post/',
    'emplocation_endpoint': '/emplocation/post/',
    'location_bulk_endpoint': 'http://103.149.33.102:8001/location/bulk',

    // Leave Endpoints
    'leave_endpoint': '/leavetable/post/',
    'leaves_get_endpoint': '/leaves/get',

    // Task Endpoints
    'task_endpoint': '/tasks/post/',
    'task_get_endpoint': '/task/get',
    'tasks_created_endpoint': '/tasks/created/',
    'task_update_endpoint': '/taskupdate/put',

    // Other Endpoints
    'break_endpoint': '/employeebreak/post/',
    'salary_slip_endpoint': '/salaryslip/get',
    'geofence_post_endpoint': '/geofencepost/post/',
    'fakegps_endpoint': '/fakegps/post/',

    // ── Selfie Endpoints ──────────────────────────────────────────────────────
    'selfie_policy_endpoint': '/auto_clockout_notification/get/',
    'selfie_post_endpoint': '/selfiepost/post/',

    // ── Interval Selfie Endpoints ─────────────────────────────────────────────
    'presencecheck_get_endpoint': '/presencecheck/get/',
    'presencecheckpost_selfie_endpoint': '/presencecheckpost/selfie/',

    // ── Overtime Endpoint ─────────────────────────────────────────────────────
    'maxot_endpoint': '/maxot/get',

    // ── Logout Endpoints ──────────────────────────────────────────────────────
    'logout_check_endpoint': '/logout/get',
    'logout_update_endpoint': '/updatelogout/put',

    // App Configuration
    'api_timeout_seconds': 30,
    'maintenance_mode': false,
    'force_update_version': '',
    'enable_analytics': true,
  };

  static Future<void> initialize() async {
    try {
      // Set defaults
      await _remoteConfig.setDefaults(_defaults);

      // Configure fetch settings
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(seconds: 10),
      ));

      // Fetch and activate
      await _remoteConfig.fetchAndActivate();

      if (kDebugMode) {
        print('✅ Remote Config initialized successfully');
        print('📡 API Base URL: ${getApiBaseUrl()}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Remote Config initialization failed: $e');
        print('⚠️ Using default values');
      }
    }
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  static String _removeTrailingSlash(String url) {
    return url.replaceAll(RegExp(r'/$'), '');
  }

  // ============================================================
  // BASE URL GETTERS
  // ============================================================

  static String getApiBaseUrl() {
    return _remoteConfig.getString('api_base_url');
  }

  static String getLocationBulkUrl() {
    return _remoteConfig.getString('location_bulk_endpoint');
  }

  // ============================================================
  // AUTH & COMPANY URLS
  // ============================================================

  static String getCompanyValidationUrl(String companyCode) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('company_validation_endpoint');
    return '$baseUrl$endpoint?company_code=$companyCode';
  }

  static String getLoginApiUrl(String companyCode) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('login_endpoint');
    return '$baseUrl$endpoint?company_code=$companyCode';
  }

  static String getSignInUrl() {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('sign_in_endpoint');
    return '$baseUrl$endpoint';
  }

  static String getGeofenceUrl(String empId, String companyCode) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('geofence_endpoint');
    return '$baseUrl$endpoint?emp_id=$empId&company_code=$companyCode';
  }

  // ============================================================
  // ATTENDANCE URLS
  // ============================================================

  static String getAttendanceInUrl() {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('attendance_in_endpoint');
    return '$baseUrl$endpoint';
  }

  static String getAttendanceOutUrl() {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('attendance_out_endpoint');
    return '$baseUrl$endpoint';
  }

  static String getAttendanceDataUrl(String userId) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('attendance_data_endpoint');
    return '$baseUrl$endpoint/get/$userId';
  }

  static String getAttendanceSerialUrl(String empId, String companyCode) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('attendance_in_endpoint');
    final serialEndpoint = endpoint.replaceFirst('/post/', '/get');
    return '$baseUrl$serialEndpoint/$empId?company_code=$companyCode';
  }

  // ============================================================
  // LOCATION URLS
  // ============================================================

  static String getLocationUrl() {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('location_endpoint');
    return '$baseUrl$endpoint';
  }

  static String getEmpLocationUrl() {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('emplocation_endpoint');
    return '$baseUrl$endpoint';
  }

  // ============================================================
  // LEAVE URLS
  // ============================================================

  static String getLeaveUrl() {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('leave_endpoint');
    return '$baseUrl$endpoint';
  }

  static String getLeavesGetUrl(String empId, String companyCode) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('leaves_get_endpoint');
    return '$baseUrl$endpoint?emp_id=$empId&company_code=$companyCode';
  }

  // ============================================================
  // TASK URLS
  // ============================================================

  static String getTaskUrl() {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('task_endpoint');
    return '$baseUrl$endpoint';
  }

  static String getTaskGetUrl(String empId, String companyCode) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('task_get_endpoint');
    return '$baseUrl$endpoint?emp_id=$empId&company_code=$companyCode';
  }

  static String getTasksCreatedUrl(String assignedBy) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('tasks_created_endpoint');
    return '$baseUrl$endpoint?assigned_by=$assignedBy';
  }

  static String getTaskUpdateUrl() {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('task_update_endpoint');
    return '$baseUrl$endpoint';
  }

  // ============================================================
  // OTHER URLS
  // ============================================================

  static String getBreakUrl() {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('break_endpoint');
    return '$baseUrl$endpoint';
  }

  static String getSalarySlipUrl(String empId, String companyCode) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('salary_slip_endpoint');
    return '$baseUrl$endpoint?emp_id=$empId&company_code=$companyCode';
  }

  static String getGeofencePostUrl() {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('geofence_post_endpoint');
    return '$baseUrl$endpoint';
  }

  static String getFakeGpsUrl() {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('fakegps_endpoint');
    return '$baseUrl$endpoint';
  }

  // ============================================================
  // SELFIE URLS
  // ============================================================

  static String getSelfiePolicyUrl(String empId, String companyCode) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('selfie_policy_endpoint');
    return '$baseUrl$endpoint?emp_id=$empId&company_code=$companyCode';
  }

  static String getSelfiePostUrl() {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('selfie_post_endpoint');
    return '$baseUrl$endpoint';
  }

  // ── INTERVAL SELFIE URLS (presencecheck) ─────────────────────────────────

  static String getPresenceCheckGetUrl(String empId, String companyCode) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('presencecheck_get_endpoint');
    return '$baseUrl$endpoint?emp_id=${Uri.encodeComponent(empId)}&company_code=${Uri.encodeComponent(companyCode)}';
  }

  static String getPresenceCheckPostSelfieUrl({
    required String empId,
    required String empName,
    required String companyCode,
    required String imageMimeType,
    required double lat,
    required double lng,
    required String capturedAt,
  }) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('presencecheckpost_selfie_endpoint');
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: {
      'emp_id'         : empId,
      'emp_name'       : empName,
      'company_code'   : companyCode,
      'image_mime_type': imageMimeType,
      'latitude'       : lat.toString(),
      'longitude'      : lng.toString(),
      'captured_at'    : capturedAt,
    });
    return uri.toString();
  }


  // ============================================================
  // OVERTIME URL
  // ============================================================

  static String getMaxOtUrl(String depId) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('maxot_endpoint');
    return '$baseUrl$endpoint?dep_id=$depId';
  }

  // ============================================================
  // LOGOUT URLS
  // ============================================================

  static String getLogoutCheckUrl(String empId, String companyCode) {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('logout_check_endpoint');
    return '$baseUrl$endpoint?emp_id=$empId&company_code=$companyCode';
  }

  static String getLogoutUpdateUrl() {
    final baseUrl = _removeTrailingSlash(getApiBaseUrl());
    final endpoint = _remoteConfig.getString('logout_update_endpoint');
    return '$baseUrl$endpoint';
  }

  // ============================================================
  // CONFIGURATION GETTERS
  // ============================================================

  static int getApiTimeout() {
    return _remoteConfig.getInt('api_timeout_seconds');
  }

  static bool isMaintenanceMode() {
    return _remoteConfig.getBool('maintenance_mode');
  }

  static String getForceUpdateVersion() {
    return _remoteConfig.getString('force_update_version');
  }

  static bool isAnalyticsEnabled() {
    return _remoteConfig.getBool('enable_analytics');
  }

  // ============================================================
  // REFRESH METHOD
  // ============================================================

  static Future<void> refresh() async {
    try {
      await _remoteConfig.fetchAndActivate();
      if (kDebugMode) {
        print('🔄 Remote Config refreshed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Remote Config refresh failed: $e');
      }
    }
  }

  // ============================================================
  // DEBUG METHOD - Get all config
  // ============================================================

  static Map<String, dynamic> getAllConfig() {
    return {
      'api_base_url': getApiBaseUrl(),
      'company_validation_endpoint': _remoteConfig.getString('company_validation_endpoint'),
      'login_endpoint': _remoteConfig.getString('login_endpoint'),
      'sign_in_endpoint': _remoteConfig.getString('sign_in_endpoint'),
      'geofence_endpoint': _remoteConfig.getString('geofence_endpoint'),
      'attendance_in_endpoint': _remoteConfig.getString('attendance_in_endpoint'),
      'attendance_out_endpoint': _remoteConfig.getString('attendance_out_endpoint'),
      'location_endpoint': _remoteConfig.getString('location_endpoint'),
      'leave_endpoint': _remoteConfig.getString('leave_endpoint'),
      'task_endpoint': _remoteConfig.getString('task_endpoint'),
      'selfie_policy_endpoint': _remoteConfig.getString('selfie_policy_endpoint'),
      'selfie_post_endpoint': _remoteConfig.getString('selfie_post_endpoint'),
      'maxot_endpoint': _remoteConfig.getString('maxot_endpoint'),
      'logout_check_endpoint': _remoteConfig.getString('logout_check_endpoint'),
      'logout_update_endpoint': _remoteConfig.getString('logout_update_endpoint'),
      'api_timeout_seconds': getApiTimeout(),
      'maintenance_mode': isMaintenanceMode(),
    };
  }
}