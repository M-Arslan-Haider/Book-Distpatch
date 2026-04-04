// // import 'package:flutter/material.dart';
// //
// // // Colors
// // const kPrimaryColor = Colors.blue;
// // const kPrimaryLightColor = Colors.white;
// // final Color darkText = const Color(0xFF1F2937);
// // final Color subText = const Color(0xFF1F2937).withValues(alpha: 0.5);
// // final Color bgColor = const Color(0xFFF8F9FA);
// //
// // // API Endpoints
// // const String companyApiEndpoint = 'http://oracle.metaxperts.net/ords/production/registeredcompanies/get/';
// // const String loginApiEndpoint = 'http://oracle.metaxperts.net/ords/production/loginget/get/';
// //
// // // Attendance APIs
// // // const String attendanceInApi = 'http://oracle.metaxperts.net/ords/production/attendanceinpost/post/';
// // // const String attendanceOutApi = 'http://oracle.metaxperts.net/ords/production/attendanceout/post/';
// // const String locationApi = 'http://oracle.metaxperts.net/ords/production/location/post/';
// //
// // // Shared Preferences Keys
// // const String prefCompanyCode = 'companyCode';
// // const String prefCompanyName = 'companyName';
// // const String prefWorkspaceName = 'workspaceName';
// // const String prefUserId = 'userId'; // This will store emp_id
// // const String prefUserName = 'userName'; // This will store emp_name
// // const String prefUserDesignation = 'userDesignation'; // This will store job
// // const String prefUserCity = 'userCity';
// // const String prefIsAuthenticated = 'isAuthenticated';
// // const String prefRememberMe = 'rememberMe';
// // const String prefSavedUserId = 'savedUserId';
// // const String prefIsClockedIn = 'isClockedIn';
// // const String prefClockInTime = 'clockInTime';
// // const String prefAttendanceId = 'attendanceId';
// // const String prefTotalDistance = 'totalDistance';
// // const String prefSecondsPassed = 'secondsPassed';
// //
// // // Role-based routes
// // const String routeLogin = '/login';
// // const String routeHome = '/home';
// // const String routeCodeScreen = '/CodeScreen';
// // const String routePermissions = '/permissions';
// // const String routeCameraScreen = '/cameraScreen';
// // const String routeLocationScreen = '/locationScreen';
// // const String routeNotificationScreen = '/notificationScreen';
// //
// // // Version
// // const String appVersion = '1.0.0';
//
// // ///for diferent companes:
// import 'package:flutter/material.dart';
//
// // Colors
// const kPrimaryColor = Colors.blue;
// const kPrimaryLightColor = Colors.white;
// final Color darkText = const Color(0xFF1F2937);
// final Color subText = const Color(0xFF1F2937).withValues(alpha: 0.5);
// final Color bgColor = const Color(0xFFF8F9FA);
//
// // Company-specific APIs (Different for each company)
// // Company 1 APIs
// const String companyApiEndpoint = 'http://oracle.metaxperts.net/ords/production/registeredcompanies/get/';
// const String loginApiEndpoint = 'http://oracle.metaxperts.net/ords/production/loginget/get/';
//
// // Company 2 APIs (Replace with actual links later)
// const String companyApiEndpoint2 = 'http://oracle.metaxperts.net/ords/production2/registeredcompanies/get/';
// const String loginApiEndpoint2 = 'http://oracle.metaxperts.net/ords/production2/loginget/get/';
//
// // Company 3 APIs (Replace with actual links later)
// const String companyApiEndpoint3 = 'http://oracle.metaxperts.net/ords/production3/registeredcompanies/get/';
// const String loginApiEndpoint3 = 'http://oracle.metaxperts.net/ords/production3/loginget/get/';
//
// // Shared APIs (SAME for all companies)
// const String attendanceInApi = 'http://oracle.metaxperts.net/ords/production/attendanceinpost/post/';
// const String attendanceOutApi = 'http://oracle.metaxperts.net/ords/production/attendanceout/post/';
// const String locationApi = 'http://oracle.metaxperts.net/ords/production/location/post/';
// const String leaveApi = 'http://oracle.metaxperts.net/ords/production/leaveapplication/post/';
// const String taskApi = 'http://oracle.metaxperts.net/ords/production/tasks/post/';
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
// // API Manager - Returns different APIs based on company code
// class ApiManager {
//   // Get Company Validation API based on company code
//   static String getCompanyApi(String companyCode) {
//     switch (companyCode.toUpperCase()) {
//       case 'COMPANY2':
//         return companyApiEndpoint2;
//       case 'COMPANY3':
//         return companyApiEndpoint3;
//       default:
//         return companyApiEndpoint;
//     }
//   }
//
//   // Get Login API based on company code
//   static String getLoginApi(String companyCode) {
//     switch (companyCode.toUpperCase()) {
//       case 'COMPANY2':
//         return loginApiEndpoint2;
//       case 'COMPANY3':
//         return loginApiEndpoint3;
//       default:
//         return loginApiEndpoint;
//     }
//   }
//
//   // All these use the SAME API endpoints for all companies
//   static String getAttendanceInApi() => attendanceInApi;
//   static String getAttendanceOutApi() => attendanceOutApi;
//   static String getLocationApi() => locationApi;
//   static String getLeaveApi() => leaveApi;
//   static String getTaskApi() => taskApi;
// }

import 'package:flutter/material.dart';

// Colors
const kPrimaryColor = Colors.blue;
const kPrimaryLightColor = Colors.white;
final Color darkText = const Color(0xFF1F2937);
final Color subText = const Color(0xFF1F2937).withValues(alpha: 0.5);
final Color bgColor = const Color(0xFFF8F9FA);

// SINGLE API ENDPOINTS for all companies
const String baseApiUrl = 'http://oracle.metaxperts.net/ords/gps_workforce';
const String companyApiEndpoint = '$baseApiUrl/registeredcompanies/get/';
const String loginApiEndpoint = '$baseApiUrl/loginget/get/';
// const String attendanceInApi = '$baseApiUrl/attendanceinpost/post/';
// const String attendanceOutApi = '$baseApiUrl/attendanceout/post/';
const String locationApi = '$baseApiUrl/location/post/';
const String leaveApi = '$baseApiUrl/leaveapplication/post/';
const String taskApi = '$baseApiUrl/tasks/post/';

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

// API Manager - All APIs use company_code as parameter
class ApiManager {
  // Get company validation API (with company_code filter)
  static String getCompanyApi(String companyCode) {
    // The API will filter by company_code in the request
    return '$companyApiEndpoint?company_code=$companyCode';
  }

  // Get login API (will validate both employee_id and company_code)
  static String getLoginApi(String companyCode) {
    // The API will filter by company_code
    return '$loginApiEndpoint?company_code=$companyCode';
  }

  // All other APIs remain the same - they'll include company_code in the request body
  // static String getAttendanceInApi() => attendanceInApi;
  // static String getAttendanceOutApi() => attendanceOutApi;
  static String getLocationApi() => locationApi;
  static String getLeaveApi() => leaveApi;
  static String getTaskApi() => taskApi;
}