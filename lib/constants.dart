//
// import 'package:flutter/material.dart';
//
// // Colors
// const kPrimaryColor = Colors.blue;
// const kPrimaryLightColor = Colors.white;
// final Color darkText = const Color(0xFF1F2937);
// final Color subText = const Color(0xFF1F2937).withValues(alpha: 0.5);
// final Color bgColor = const Color(0xFFF8F9FA);
//
// // SINGLE API ENDPOINTS for all companies
// const String baseApiUrl = 'http://oracle.metaxperts.net/ords/gps_workforce';
// const String companyApiEndpoint = '$baseApiUrl/registeredcompanies/get/';
// const String loginApiEndpoint = '$baseApiUrl/loginget/get/';
// // const String attendanceInApi = '$baseApiUrl/attendanceinpost/post/';
// // const String attendanceOutApi = '$baseApiUrl/attendanceout/post/';
// const String locationApi = '$baseApiUrl/location/post/';
// const String leaveApi = '$baseApiUrl/leaveapplication/post/';
// const String taskApi = '$baseApiUrl/tasks/post/';
//
// // Shared Preferences Keys
// const String prefCompanyCode = 'companyCode';
// const String prefCompanyName = 'companyName';
// const String prefWorkspaceName = 'workspaceName';
// const String prefUserId = 'userId';
// const String prefUserName = 'userName';
// const String prefUserDesignation = 'userDesignation';
// const String prefUserCity = 'userCity';
// const String prefIsAuthenticated = 'isAuthenticated';
// const String prefRememberMe = 'rememberMe';
// const String prefSavedUserId = 'savedUserId';
// const String prefIsClockedIn = 'isClockedIn';
// const String prefClockInTime = 'clockInTime';
// const String prefAttendanceId = 'attendanceId';
// const String prefTotalDistance = 'totalDistance';
// const String prefSecondsPassed = 'secondsPassed';
//
// // Role-based routes
// const String routeLogin = '/login';
// const String routeHome = '/home';
// const String routeCodeScreen = '/CodeScreen';
// const String routePermissions = '/permissions';
// const String routeCameraScreen = '/cameraScreen';
// const String routeLocationScreen = '/locationScreen';
// const String routeNotificationScreen = '/notificationScreen';
//
// // Version
// const String appVersion = '1.0.0';
//
// // API Manager - All APIs use company_code as parameter
// class ApiManager {
//   // Get company validation API (with company_code filter)
//   static String getCompanyApi(String companyCode) {
//     // The API will filter by company_code in the request
//     return '$companyApiEndpoint?company_code=$companyCode';
//   }
//
//   // Get login API (will validate both employee_id and company_code)
//   static String getLoginApi(String companyCode) {
//     // The API will filter by company_code
//     return '$loginApiEndpoint?company_code=$companyCode';
//   }
//
//   // All other APIs remain the same - they'll include company_code in the request body
//   // static String getAttendanceInApi() => attendanceInApi;
//   // static String getAttendanceOutApi() => attendanceOutApi;
//   static String getLocationApi() => locationApi;
//   static String getLeaveApi() => leaveApi;
//   static String getTaskApi() => taskApi;
// }

///firebase
import 'package:flutter/material.dart';

// Colors
const kPrimaryColor = Colors.blue;
const kPrimaryLightColor = Colors.white;
final Color darkText = const Color(0xFF1F2937);
final Color subText = const Color(0xFF1F2937).withValues(alpha: 0.5);
final Color bgColor = const Color(0xFFF8F9FA);

// ⚠️ IMPORTANT: API URLs are NO LONGER hardcoded here!
// All API endpoints are now managed through Firebase Remote Config.
// Use RemoteConfigService methods instead:
//   - RemoteConfigService.getApiBaseUrl()
//   - RemoteConfigService.getLoginApiUrl(companyCode)
//   - RemoteConfigService.getCompanyValidationUrl(companyCode)
//   - RemoteConfigService.getAttendanceInUrl()
//   - RemoteConfigService.getAttendanceOutUrl()
//   - RemoteConfigService.getLocationUrl()
//   - RemoteConfigService.getLeaveUrl()
//   - RemoteConfigService.getTaskUrl()
//   - etc.

// Shared Preferences Keys
const String prefCompanyCode = 'companyCode';
const String prefCompanyName = 'companyName';
const String prefWorkspaceName = 'workspaceName';
const String prefUserId = 'userId';
const String prefUserName = 'userName';
const String prefUserDesignation = 'userDesignation';
const String prefUserCity = 'userCity';
const String prefIsAuthenticated = 'isAuthenticated';
const String prefRememberMe = 'rememberMe';
const String prefSavedUserId = 'savedUserId';
const String prefIsClockedIn = 'isClockedIn';
const String prefClockInTime = 'clockInTime';
const String prefAttendanceId = 'attendanceId';
const String prefTotalDistance = 'totalDistance';
const String prefSecondsPassed = 'secondsPassed';
const String prefIsTimekeeper = 'isTimekeeper';

// Role-based routes
const String routeLogin = '/login';
const String routeHome = '/home';
const String routeCodeScreen = '/CodeScreen';
const String routePermissions = '/permissions';
const String routeCameraScreen = '/cameraScreen';
const String routeLocationScreen = '/locationScreen';
const String routeNotificationScreen = '/notificationScreen';

// Version
const String appVersion = '1.0.0';

// ⚠️ ApiManager class REMOVED
// The ApiManager class with hardcoded URLs has been removed.
// Please use RemoteConfigService for all API URL generation.