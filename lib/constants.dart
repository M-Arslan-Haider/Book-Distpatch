import 'package:flutter/material.dart';

// Colors
const kPrimaryColor = Colors.blue;
const kPrimaryLightColor = Colors.white;
final Color darkText = const Color(0xFF1F2937);
final Color subText = const Color(0xFF1F2937).withValues(alpha: 0.5);
final Color bgColor = const Color(0xFFF8F9FA);

// API Endpoints
const String companyApiEndpoint = 'http://oracle.metaxperts.net/ords/production/registeredcompanies/get/';
const String loginApiEndpoint = 'http://oracle.metaxperts.net/ords/production/loginget/get/';

// Attendance APIs
// const String attendanceInApi = 'http://oracle.metaxperts.net/ords/production/attendanceinpost/post/';
// const String attendanceOutApi = 'http://oracle.metaxperts.net/ords/production/attendanceout/post/';
const String locationApi = 'http://oracle.metaxperts.net/ords/production/location/post/';

// Shared Preferences Keys
const String prefCompanyCode = 'companyCode';
const String prefCompanyName = 'companyName';
const String prefWorkspaceName = 'workspaceName';
const String prefUserId = 'userId'; // This will store emp_id
const String prefUserName = 'userName'; // This will store emp_name
const String prefUserDesignation = 'userDesignation'; // This will store job
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