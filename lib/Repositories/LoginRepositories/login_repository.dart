// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:http/io_client.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:device_info_plus/device_info_plus.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../Models/LoginModels/login_models.dart';
// import '../../Services/biometric_service.dart';
// import '../../Services/remote_config_service.dart';
// import '../../constants.dart';
// import '../../Screens/code_screen.dart'; // ← NAYA IMPORT
//
// class LoginRepository extends GetxService {
//
//   static const String prefCachedEndTime = 'cached_end_time';
//   static const String prefCachedOvertime = 'cached_overtime';
//   static const String prefCachedShift = 'cached_shift';
//   static const String prefCachedImageUrl = 'cached_image_url';
//   static const String prefCachedDepId = 'cached_dep_id';
//   static const String prefCachedAllowCheckInBeforeShift = 'cached_allow_check_in_before_shift';
//   static const String prefCachedEntryTime = 'cached_entry_time';
//   static const String prefCachedShiftType = 'cached_shift_type'; // 🌙 Night/Day shift
//   static const String prefCachedWagers = 'cached_wagers'; // 📦 Offline wager-detail cache
//   static const String prefCachedShiftSchedule = 'cached_shift_schedule'; // ✅ Day-wise shift schedule
//   static const String currentAppVersion = "2.4";
//
//   final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
//
//   Future<String> _getDeviceModel() async {
//     try {
//       if (defaultTargetPlatform == TargetPlatform.android) {
//         final androidInfo = await _deviceInfo.androidInfo;
//         return androidInfo.model;
//       } else if (defaultTargetPlatform == TargetPlatform.iOS) {
//         final iosInfo = await _deviceInfo.iosInfo;
//         return iosInfo.model;
//       }
//     } catch (e) {
//       debugPrint('⚠️ Could not get device model: $e');
//     }
//     return 'unknown';
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // DEVICE TOKEN — Single Device Login
//   // Generated once from device hardware IDs and cached in SharedPreferences.
//   // Android: androidInfo.id + model + brand combination
//   // iOS: identifierForVendor
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<String> _getDeviceToken() async {
//     final prefs = await SharedPreferences.getInstance();
//     String? token = prefs.getString('local_device_token');
//     if (token == null || token.isEmpty) {
//       try {
//         if (defaultTargetPlatform == TargetPlatform.android) {
//           final androidInfo = await _deviceInfo.androidInfo;
//           token = '${androidInfo.id}_${androidInfo.model}_${androidInfo.brand}';
//         } else if (defaultTargetPlatform == TargetPlatform.iOS) {
//           final iosInfo = await _deviceInfo.iosInfo;
//           token = iosInfo.identifierForVendor ?? 'ios_unknown';
//         } else {
//           token = 'unknown_device';
//         }
//       } catch (e) {
//         debugPrint('⚠️ [DEVICE TOKEN] Could not generate: $e');
//         token = 'unknown_device';
//       }
//       await prefs.setString('local_device_token', token!);
//       debugPrint('🔑 [DEVICE TOKEN] Generated & cached: $token');
//     } else {
//       debugPrint('🔑 [DEVICE TOKEN] Loaded from cache: $token');
//     }
//     return token!;
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // NIGHT / DAY SHIFT DETECTION HELPERS
//   // ─────────────────────────────────────────────────────────────────────────
//
//   /// Parses "HH:mm", "HH:mm:ss", "H:mm AM/PM" → [hour24, minute] or null.
//   List<int>? _parseTimeLR(String raw) {
//     try {
//       final String upper   = raw.trim().toUpperCase();
//       final bool isPM      = upper.contains('PM');
//       final bool isAM      = upper.contains('AM');
//       final String cleaned = upper
//           .replaceAll('PM', '')
//           .replaceAll('AM', '')
//           .trim();
//       final List<String> parts = cleaned.split(':');
//       if (parts.length < 2) return null;
//       int? hour   = int.tryParse(parts[0].trim());
//       int? minute = int.tryParse(parts[1].trim().split(RegExp(r'\s+'))[0]);
//       if (hour == null || minute == null) return null;
//       if (isPM && hour != 12) hour += 12;
//       if (isAM && hour == 12) hour  = 0;
//       return [hour, minute];
//     } catch (e) {
//       debugPrint('⚠️ [PARSE TIME LR] Error: $e  raw="$raw"');
//       return null;
//     }
//   }
//
//   /// Returns 'Night Shift' when end_time falls BEFORE entry_time
//   /// (i.e. the shift crosses midnight), otherwise returns 'Day Shift'.
//   ///
//   /// Examples:
//   ///   entry=09:00  end=17:00  → Day Shift  ☀️
//   ///   entry=22:00  end=06:00  → Night Shift 🌙  (end < entry → crosses midnight)
//   ///   entry=18:00  end=02:00  → Night Shift 🌙
//   String _detectShiftType(String? entryTime, String? endTime) {
//     debugPrint('');
//     debugPrint('══════════════════════════════════════════════════════');
//     debugPrint('🌙 [SHIFT DETECT] ===== START =====');
//     debugPrint('🌙 [SHIFT DETECT] entry_time raw = "$entryTime"');
//     debugPrint('🌙 [SHIFT DETECT] end_time   raw = "$endTime"');
//
//     if (entryTime == null || entryTime.isEmpty ||
//         endTime   == null || endTime.isEmpty) {
//       debugPrint('🌙 [SHIFT DETECT] ⚠️ One or both times missing → defaulting to Day Shift ☀️');
//       debugPrint('══════════════════════════════════════════════════════');
//       debugPrint('');
//       return 'Day Shift';
//     }
//
//     final List<int>? ep  = _parseTimeLR(entryTime);
//     final List<int>? endp = _parseTimeLR(endTime);
//
//     if (ep == null || endp == null) {
//       debugPrint('🌙 [SHIFT DETECT] ⚠️ Could not parse times → defaulting to Day Shift ☀️');
//       debugPrint('══════════════════════════════════════════════════════');
//       debugPrint('');
//       return 'Day Shift';
//     }
//
//     final int entryTotalMin = ep[0]   * 60 + ep[1];
//     final int endTotalMin   = endp[0] * 60 + endp[1];
//     final bool isNight      = endTotalMin <= entryTotalMin;
//
//     debugPrint('🌙 [SHIFT DETECT] entry parsed → ${ep[0]}h ${ep[1]}m  (totalMin=$entryTotalMin)');
//     debugPrint('🌙 [SHIFT DETECT] end   parsed → ${endp[0]}h ${endp[1]}m  (totalMin=$endTotalMin)');
//     debugPrint('🌙 [SHIFT DETECT] endMin <= entryMin ? $isNight (crosses midnight = night shift)');
//     debugPrint('🌙 [SHIFT DETECT] ✅ RESULT → ${isNight ? "NIGHT SHIFT 🌙" : "DAY SHIFT ☀️"}');
//     debugPrint('══════════════════════════════════════════════════════');
//     debugPrint('');
//
//     return isNight ? 'Night Shift' : 'Day Shift';
//   }
//
//   Future<VersionCheckResult> isCompanyVersionValid(String companyCode) async {
//     try {
//       final apiUrl = RemoteConfigService.getCompanyValidationUrl(companyCode);
//       debugPrint('📡 [VERSION CHECK] URL: $apiUrl');
//
//       final response = await http
//           .get(Uri.parse(apiUrl))
//           .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));
//
//       if (response.statusCode != 200) {
//         return VersionCheckResult.error('Server error. Please try again.');
//       }
//
//       final Map<String, dynamic> data = json.decode(response.body);
//       final List<dynamic> items = data['items'] ?? [];
//
//       if (items.isEmpty) {
//         return VersionCheckResult.error('Company "$companyCode" not found.');
//       }
//
//       Map<String, dynamic>? companyData;
//       for (var item in items) {
//         final map = item as Map<String, dynamic>;
//         if (map['company_code'] == companyCode) {
//           companyData = map;
//           break;
//         }
//       }
//
//       if (companyData == null) {
//         return VersionCheckResult.error('Company not found.');
//       }
//
//       dynamic versionValue = companyData['version'];
//       String companyVersion = versionValue?.toString() ?? '';
//
//       if (companyVersion.endsWith('.0')) {
//         companyVersion = companyVersion.substring(0, companyVersion.length - 2);
//       }
//
//       final isValid = (companyVersion == currentAppVersion);
//
//       if (isValid) {
//         return VersionCheckResult.valid();
//       } else {
//         return VersionCheckResult.mismatch(
//           appVersion: currentAppVersion,
//           requiredVersion: companyVersion,
//         );
//       }
//     } catch (e) {
//       return VersionCheckResult.error('Could not verify app version.');
//     }
//   }
//
//   Future<bool> fetchAndCacheEmployeesForCompany(String companyCode) async {
//     try {
//       final apiUrl = RemoteConfigService.getLoginApiUrl(companyCode);
//       debugPrint('📡 [EMPLOYEE CACHE] Fetching: $apiUrl');
//
//       final response = await http
//           .get(Uri.parse(apiUrl))
//           .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));
//
//       if (response.statusCode != 200) {
//         return false;
//       }
//
//       final Map<String, dynamic> data = json.decode(response.body);
//       final List<dynamic> items = data['items'] ?? [];
//
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('cached_employees_$companyCode', jsonEncode(items));
//       await prefs.setString('cached_employees_company', companyCode);
//
//       return true;
//     } catch (e) {
//       debugPrint('❌ [EMPLOYEE CACHE] Error: $e');
//       return false;
//     }
//   }
//
//   Future<LoginResult> getUserByCredentials(String userId, String password) async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final savedCompanyCode = prefs.getString(prefCompanyCode) ?? '';
//
//       if (savedCompanyCode.isEmpty) {
//         return LoginResult.noCompany();
//       }
//
//       final versionCheck = await isCompanyVersionValid(savedCompanyCode);
//       if (!versionCheck.isValid) {
//         return LoginResult.versionMismatch(versionCheck.message);
//       }
//
//       List<dynamic> items = [];
//
//       try {
//         final apiUrl = RemoteConfigService.getLoginApiUrl(savedCompanyCode);
//         final response = await http
//             .get(Uri.parse(apiUrl))
//             .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));
//
//         if (response.statusCode == 200) {
//           final Map<String, dynamic> data = json.decode(response.body);
//           items = data['items'] ?? [];
//           await prefs.setString('cached_employees_$savedCompanyCode', jsonEncode(items));
//           debugPrint('🌐 [LOGIN] Live data fetched from API');
//         } else {
//           throw Exception('Non-200 status: ${response.statusCode}');
//         }
//       } catch (_) {
//         final cached = prefs.getString('cached_employees_$savedCompanyCode');
//         if (cached != null && cached.isNotEmpty) {
//           items = jsonDecode(cached) as List<dynamic>;
//           debugPrint('📦 [LOGIN] Offline — using cached employee data');
//         } else {
//           return LoginResult.networkError();
//         }
//       }
//
//       final int? userIdInt = int.tryParse(userId);
//
//       for (var item in items) {
//         final map = item as Map<String, dynamic>;
//         final user = LoginModels.fromJson(map);
//
//         final bool idMatches = userIdInt != null
//             ? user.emp_id == userIdInt
//             : user.emp_id.toString() == userId;
//
//         if (!idMatches) continue;
//
//         final String storedPassword = map['portal_password']?.toString() ?? '';
//         if (storedPassword != password) {
//           return LoginResult.wrongPassword();
//         }
//
//         // ── Single Device Login: Device Token Check ───────────────────────
//         final String localToken   = await _getDeviceToken();
//         final String? serverToken = user.device_token;
//         debugPrint('🔑 [DEVICE CHECK] Local  token: $localToken');
//         debugPrint('🔑 [DEVICE CHECK] Server token: $serverToken');
//
//         if (serverToken != null &&
//             serverToken.isNotEmpty &&
//             serverToken != localToken) {
//           debugPrint('❌ [DEVICE CHECK] Token mismatch — login rejected');
//           return LoginResult.deviceConflict();
//         }
//         debugPrint('✅ [DEVICE CHECK] Token OK — proceeding with login');
//         // ─────────────────────────────────────────────────────────────────
//
//         if (user.end_time != null && user.end_time!.isNotEmpty) {
//           await prefs.setString(prefCachedEndTime, user.end_time!);
//         }
//         await prefs.setString(
//           prefCachedOvertime,
//           (user.over_time != null && user.over_time!.isNotEmpty)
//               ? user.over_time!
//               : 'no',
//         );
//         if (user.shift != null && user.shift!.isNotEmpty) {
//           await prefs.setString(prefCachedShift, user.shift!);
//         }
//         if (user.image_url != null && user.image_url!.isNotEmpty) {
//           await prefs.setString(prefCachedImageUrl, user.image_url!);
//         }
//         if (user.dep_id != null && user.dep_id!.isNotEmpty) {
//           await prefs.setString(prefCachedDepId, user.dep_id!);
//         }
//         await prefs.setString(
//           prefCachedAllowCheckInBeforeShift,
//           user.allow_check_in_before_shift ?? 'no',
//         );
//         debugPrint('📦 [LOGIN] allow_check_in_before_shift: ${user.allow_check_in_before_shift}');
//         if (user.entry_time != null && user.entry_time!.isNotEmpty) {
//           await prefs.setString(prefCachedEntryTime, user.entry_time!);
//         }
//         debugPrint('📦 [LOGIN] entry_time: ${user.entry_time}');
//
//         // ── Night / Day Shift Detection ───────────────────────────────────
//         final String shiftType = _detectShiftType(user.entry_time, user.end_time);
//         await prefs.setString(prefCachedShiftType, shiftType);
//         debugPrint('🌙 [LOGIN] Shift type cached: $shiftType');
//         // ─────────────────────────────────────────────────────────────────
//
//         postSignInDetails(
//           empId: userId,
//           empName: user.emp_name ?? '',
//           companyCode: savedCompanyCode,
//           deviceToken: localToken,
//         );
//
//         // ── Refresh location cache at every successful login ──────────────────
//         // Ensures cached_locations is always fresh so that even if the live
//         // geofence fetch later returns 403, the fallback cache has current data.
//         fetchAndCacheLocations(userId, savedCompanyCode);
//         _fetchAndCacheShiftSchedule(userId, savedCompanyCode); // ✅ Day-wise shift schedule
//
//         return LoginResult.success(user);
//       }
//
//       return LoginResult.notInCompany(savedCompanyCode);
//     } catch (e) {
//       return LoginResult.networkError();
//     }
//   }
//
//   Future<void> postSignInDetails({
//     required String empId,
//     required String empName,
//     required String companyCode,
//     String deviceToken = '',
//   }) async {
//     final signInEndpoint = RemoteConfigService.getSignInUrl();
//
//     final deviceModel = await _getDeviceModel();
//
//     String androidVersion = 'unknown';
//     String deviceId = 'unknown';
//     String simInfo = 'unknown';
//
//     try {
//       if (defaultTargetPlatform == TargetPlatform.android) {
//         final androidInfo = await _deviceInfo.androidInfo;
//         androidVersion = androidInfo.version.release;
//         deviceId = androidInfo.id;
//
//         try {
//           final status = await Permission.phone.request();
//           if (status.isGranted) {
//             const simChannel = MethodChannel('sim_info_channel');
//             final String? result = await simChannel.invokeMethod<String>('getSimInfo');
//             simInfo = result ?? 'No SIM';
//           } else {
//             simInfo = 'permission_denied';
//             debugPrint('⚠️ [SIM INFO] Phone permission denied');
//           }
//         } catch (e) {
//           debugPrint('⚠️ Could not get SIM info: $e');
//           simInfo = 'unavailable';
//         }
//       }
//     } catch (e) {
//       debugPrint('⚠️ Could not get Android version/Device ID: $e');
//     }
//
//     final body = jsonEncode({
//       'emp_id':          empId,
//       'emp_name':        empName,
//       'company_code':    companyCode,
//       'app_version':     2.4,
//       'timestamp':       DateTime.now().toIso8601String(),
//       'device_info':     deviceModel,
//       'android_version': androidVersion,
//       'device_id':       deviceId,
//       'sim_info':        simInfo,
//       'device_token':    deviceToken,   // ← Single Device Login token
//     });
//
//     try {
//       final response = await http
//           .post(
//         Uri.parse(signInEndpoint),
//         headers: {'Content-Type': 'application/json'},
//         body: body,
//       )
//           .timeout(const Duration(seconds: 15));
//       debugPrint('📤 [SIGN-IN LOG] Status: ${response.statusCode}');
//       debugPrint('📱 [SIGN-IN LOG] Device model: $deviceModel');
//       debugPrint('📶 [SIGN-IN LOG] SIM info: $simInfo');
//     } catch (e) {
//       debugPrint('⚠️ [SIGN-IN LOG] Failed: $e');
//     }
//   }
//
//   Future<void> fetchAndCacheLocations(String empId, String companyCode) async {
//     try {
//       final locationUrl = RemoteConfigService.getGeofenceUrl(empId, companyCode);
//
//       final response = await http.get(
//         Uri.parse(locationUrl),
//         headers: {'Content-Type': 'application/json'},
//       ).timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body) as Map<String, dynamic>;
//         final items = (data['items'] ?? []) as List<dynamic>;
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString('cached_locations', jsonEncode(items));
//         await prefs.setString('cached_locations_emp_id', empId);
//       }
//     } catch (e) {
//       debugPrint('⚠️ [LOCATION CACHE] Failed: $e');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // WAGER DETAIL — fetched + cached at login time so the Wagers Detail screen
//   // can show data offline. Cache key is scoped per emp_id + company_code.
//   // ─────────────────────────────────────────────────────────────────────────
//   String wagerCacheKey(String empId, String companyCode) =>
//       '${prefCachedWagers}_${empId}_$companyCode';
//
//   Future<bool> fetchAndCacheWagers(String empId, String companyCode) async {
//     try {
//       final uri = Uri.parse(
//         'http://oracle.metaxperts.net/ords/gps_workforce/wagerdetail/get',
//       ).replace(queryParameters: {
//         'emp_id': empId,
//         'company_code': companyCode,
//       });
//
//       debugPrint('📡 [WAGER CACHE] Fetching: $uri');
//
//       final httpClient = HttpClient()
//         ..badCertificateCallback = (cert, host, port) => true;
//       final ioClient = IOClient(httpClient);
//
//       final response = await ioClient
//           .get(uri, headers: {'Content-Type': 'application/json'})
//           .timeout(const Duration(seconds: 15));
//
//       if (response.statusCode != 200) {
//         debugPrint('⚠️ [WAGER CACHE] Non-200: ${response.statusCode}');
//         return false;
//       }
//
//       final decoded = jsonDecode(response.body) as Map<String, dynamic>;
//       final List<dynamic> items = decoded['items'] ?? decoded['data'] ?? [];
//
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString(wagerCacheKey(empId, companyCode), jsonEncode(items));
//
//       debugPrint('✅ [WAGER CACHE] Cached ${items.length} wager record(s) for emp=$empId');
//       return true;
//     } catch (e) {
//       debugPrint('⚠️ [WAGER CACHE] Failed (offline?): $e');
//       return false;
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // DAY-WISE SHIFT SCHEDULE
//   // Endpoint: shiftdetails/get/?emp_id=&company_code=
//   // Response: 7-row items array (one row per day of week)
//   // Converts rows → { "Monday": { working, start_time, end_time, spans_midnight }, ... }
//   // If API returns empty (no shift assigned for this emp) → old cached_entry_time /
//   // cached_end_time stay untouched (automatic fallback, no extra logic needed).
//   // DAY_OF_WEEK "MON"→"Monday" etc., START/END_TIME stored as "HH:mm" (24h).
//   // SPANS_MIDNIGHT "Yes"/"No" → used by _applyTodayScheduleToCache() to set
//   // cached_shift_type without recalculating.
//   // ─────────────────────────────────────────────────────────────────────────
//   /// BreakViewModel calls this to silently refresh cached_shift_schedule
//   /// for already-logged-in users who have old cache without break fields.
//   Future<void> refreshShiftSchedule(String empId, String companyCode) =>
//       _fetchAndCacheShiftSchedule(empId, companyCode);
//
//   // ── Break field extractor helper ─────────────────────────────────────────
//   // map ke andar multiple possible column names mein se pehla non-empty value dhundta hai
//   String _extractFirstNonEmpty(Map<String, dynamic> map, List<String> keys) {
//     for (final k in keys) {
//       final v = map[k]?.toString().trim() ?? '';
//       if (v.isNotEmpty && v != 'null') return v;
//     }
//     return '';
//   }
//
//   Future<void> _fetchAndCacheShiftSchedule(
//       String empId, String companyCode) async {
//     try {
//       final uri = Uri.parse(
//         'http://oracle.metaxperts.net/ords/gps_workforce/shiftdetails/get/',
//       ).replace(queryParameters: {
//         'emp_id':       empId,
//         'company_code': companyCode,
//       });
//
//       debugPrint('📡 [SHIFT SCHEDULE] Fetching: $uri');
//
//       final response = await http
//           .get(uri)
//           .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));
//
//       if (response.statusCode != 200) {
//         debugPrint('⚠️ [SHIFT SCHEDULE] Non-200: ${response.statusCode} — old times unchanged');
//         return;
//       }
//
//       final Map<String, dynamic> data  = json.decode(response.body);
//       final List<dynamic>        items = data['items'] ?? [];
//
//       if (items.isEmpty) {
//         // ✅ Fallback: no shift assigned — old cached_entry_time/cached_end_time stay as-is
//         debugPrint('⚠️ [SHIFT SCHEDULE] No shift data for emp=$empId — using old flat times');
//         return;
//       }
//
//       // 3-letter abbreviation → full English day name
//       const Map<String, String> dayMap = {
//         'MON': 'Monday',   'TUE': 'Tuesday',  'WED': 'Wednesday',
//         'THU': 'Thursday', 'FRI': 'Friday',   'SAT': 'Saturday',
//         'SUN': 'Sunday',
//       };
//
//       // Build keyed map: { "Monday": { working, start_time, end_time, spans_midnight, break_start, break_end } }
//       final Map<String, dynamic> scheduleMap = {};
//
//       debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//       debugPrint('[SHIFT SCHEDULE] 🔍 Raw API keys (first row): ${items.isNotEmpty ? (items[0] as Map).keys.toList() : "N/A"}');
//
//       for (final item in items) {
//         final map        = item as Map<String, dynamic>;
//         final String raw = (map['DAY_OF_WEEK']  ?? map['day_of_week']  ?? '')
//             .toString().toUpperCase().trim();
//         final String day = dayMap[raw] ?? raw;
//         if (day.isEmpty) continue;
//
//         // shift_day_detail columns: break_start, break_end
//         // ORDS lowercases Oracle column names → 'break_start' / 'break_end'
//         // UPPERCASE fallback in case ORDS config differs
//         final String bStart = _extractFirstNonEmpty(map, const [
//           'break_start', 'BREAK_START',
//         ]);
//         final String bEnd = _extractFirstNonEmpty(map, const [
//           'break_end', 'BREAK_END',
//         ]);
//
//         scheduleMap[day] = {
//           'working':        (map['IS_WORKING_DAY'] ?? map['is_working_day'] ?? 'Yes').toString(),
//           'start_time':     (map['START_TIME']      ?? map['start_time']     ?? '').toString(),
//           'end_time':       (map['END_TIME']        ?? map['end_time']       ?? '').toString(),
//           'spans_midnight': (map['SPANS_MIDNIGHT']  ?? map['spans_midnight'] ?? 'No').toString(),
//           // ── Break window per day ────────────────────────────────────────
//           'break_start': bStart,
//           'break_end':   bEnd,
//           // ────────────────────────────────────────────────────────────────
//         };
//
//         debugPrint('[SHIFT SCHEDULE] 📅 $day'
//             ' | shift: ${scheduleMap[day]!['start_time']}–${scheduleMap[day]!['end_time']}'
//             ' | break: ${bStart.isNotEmpty ? bStart : "N/A"}–${bEnd.isNotEmpty ? bEnd : "N/A"}'
//             ' | working: ${scheduleMap[day]!['working']}');
//       }
//       debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString(prefCachedShiftSchedule, jsonEncode(scheduleMap));
//       debugPrint('✅ [SHIFT SCHEDULE] Cached ${scheduleMap.length} days for emp=$empId');
//       debugPrint('[SHIFT SCHEDULE] 🗓️ Full cached schedule: ${jsonEncode(scheduleMap)}');
//     } catch (e) {
//       debugPrint('⚠️ [SHIFT SCHEDULE] Failed (offline?): $e');
//     }
//   }
//
//   Future<String?> getCachedDepId() async {
//     final prefs = await SharedPreferences.getInstance();
//     return prefs.getString(prefCachedDepId);
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // FULL EMPLOYEE DATA LIVE REFRESH
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<void> refreshEmployeeDataIfOnline(String userId, String companyCode) async {
//     try {
//       final apiUrl = RemoteConfigService.getLoginApiUrl(companyCode);
//       debugPrint('📡 [EMP REFRESH] Fetching: $apiUrl');
//
//       final response = await http
//           .get(Uri.parse(apiUrl))
//           .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));
//
//       if (response.statusCode != 200) {
//         debugPrint('⚠️ [EMP REFRESH] Non-200: ${response.statusCode}');
//         return;
//       }
//
//       final Map<String, dynamic> data = json.decode(response.body);
//       final List<dynamic> items = data['items'] ?? [];
//       final int? userIdInt = int.tryParse(userId);
//
//       for (var item in items) {
//         final map = item as Map<String, dynamic>;
//         final user = LoginModels.fromJson(map);
//
//         final bool idMatches = userIdInt != null
//             ? user.emp_id == userIdInt
//             : user.emp_id.toString() == userId;
//
//         if (!idMatches) continue;
//
//         final prefs = await SharedPreferences.getInstance();
//
//         if (user.end_time != null && user.end_time!.isNotEmpty) {
//           await prefs.setString(prefCachedEndTime, user.end_time!);
//         }
//         await prefs.setString(
//           prefCachedOvertime,
//           (user.over_time != null && user.over_time!.isNotEmpty)
//               ? user.over_time!
//               : 'no',
//         );
//         if (user.shift != null && user.shift!.isNotEmpty) {
//           await prefs.setString(prefCachedShift, user.shift!);
//         }
//         if (user.image_url != null && user.image_url!.isNotEmpty) {
//           await prefs.setString(prefCachedImageUrl, user.image_url!);
//         }
//         if (user.dep_id != null && user.dep_id!.isNotEmpty) {
//           await prefs.setString(prefCachedDepId, user.dep_id!);
//         }
//         await prefs.setString(
//           prefCachedAllowCheckInBeforeShift,
//           user.allow_check_in_before_shift ?? 'no',
//         );
//         debugPrint('📦 [EMP REFRESH] allow_check_in_before_shift: ${user.allow_check_in_before_shift}');
//         if (user.entry_time != null && user.entry_time!.isNotEmpty) {
//           await prefs.setString(prefCachedEntryTime, user.entry_time!);
//         }
//         debugPrint('📦 [EMP REFRESH] entry_time: ${user.entry_time}');
//
//         // ── Night / Day Shift Detection ───────────────────────────────────
//         final String shiftType = _detectShiftType(user.entry_time, user.end_time);
//         await prefs.setString(prefCachedShiftType, shiftType);
//         debugPrint('🌙 [EMP REFRESH] Shift type cached: $shiftType');
//         // ─────────────────────────────────────────────────────────────────
//
//         debugPrint('✅ [EMP REFRESH] All fields updated for emp=$userId');
//         await _fetchAndCacheShiftSchedule(userId, companyCode); // ✅ Day-wise shift schedule
//         return;
//       }
//
//       debugPrint('⚠️ [EMP REFRESH] Employee $userId not found in response');
//     } catch (e) {
//       debugPrint('⚠️ [EMP REFRESH] Failed (offline?): $e');
//     }
//   }
//
//   Future<String?> refreshOvertimeIfOnline(String userId, String companyCode) async {
//     try {
//       final apiUrl = RemoteConfigService.getLoginApiUrl(companyCode);
//       debugPrint('📡 [OVERTIME REFRESH] Fetching: $apiUrl');
//
//       final response = await http
//           .get(Uri.parse(apiUrl))
//           .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));
//
//       if (response.statusCode != 200) {
//         debugPrint('⚠️ [OVERTIME REFRESH] Non-200 status: ${response.statusCode}');
//         return null;
//       }
//
//       final Map<String, dynamic> data = json.decode(response.body);
//       final List<dynamic> items = data['items'] ?? [];
//       final int? userIdInt = int.tryParse(userId);
//
//       for (var item in items) {
//         final map = item as Map<String, dynamic>;
//         final user = LoginModels.fromJson(map);
//
//         final bool idMatches = userIdInt != null
//             ? user.emp_id == userIdInt
//             : user.emp_id.toString() == userId;
//
//         if (!idMatches) continue;
//
//         final String newOvertime =
//         (user.over_time != null && user.over_time!.isNotEmpty)
//             ? user.over_time!
//             : 'no';
//
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString(prefCachedOvertime, newOvertime);
//         debugPrint('✅ [OVERTIME REFRESH] Saved latest overtime: $newOvertime');
//         return newOvertime;
//       }
//
//       debugPrint('⚠️ [OVERTIME REFRESH] Employee $userId not found in API response');
//       return null;
//     } catch (e) {
//       debugPrint('⚠️ [OVERTIME REFRESH] Failed (offline?): $e');
//       return null;
//     }
//   }
//
//   Future<void> checkServerLogout(String empId, String companyCode) async {
//     try {
//       final uri = Uri.parse(
//         RemoteConfigService.getLogoutCheckUrl(empId, companyCode),
//       );
//
//       // debugPrint('📡 [LOGOUT CHECK] Calling: $uri');
//
//       final response = await http
//           .get(uri)
//           .timeout(const Duration(seconds: 10));
//
//       // debugPrint('📡 [LOGOUT CHECK] Status code: ${response.statusCode}');
//       // debugPrint('📡 [LOGOUT CHECK] Raw body: ${response.body}');
//
//       if (response.statusCode != 200) {
//         debugPrint('⚠️ [LOGOUT CHECK] Non-200 — skipping');
//         return;
//       }
//
//       final Map<String, dynamic> data = json.decode(response.body);
//       final List<dynamic> items = data['items'] ?? [];
//
//       debugPrint('📡 [LOGOUT CHECK] Items count: ${items.length}');
//
//       if (items.isEmpty) {
//         debugPrint('📡 [LOGOUT CHECK] No records found — no logout');
//         return;
//       }
//
//       for (var item in items) {
//         final map = item as Map<String, dynamic>;
//         debugPrint('📡 [LOGOUT CHECK] Record: $map');
//       }
//
//       // Sab se latest record dhundo REQUEST_TIMESTAMP ke basis par
//       Map<String, dynamic>? latestRecord;
//       DateTime? latestTimestamp;
//
//       for (var item in items) {
//         final map = item as Map<String, dynamic>;
//         final tsRaw = (map['REQUEST_TIMESTAMP'] ?? map['request_timestamp'] ?? '').toString().trim();
//         if (tsRaw.isEmpty) continue;
//         try {
//           final ts = DateTime.parse(tsRaw);
//           if (latestTimestamp == null || ts.isAfter(latestTimestamp)) {
//             latestTimestamp = ts;
//             latestRecord = map;
//           }
//         } catch (_) {
//           debugPrint('⚠️ [LOGOUT CHECK] Could not parse timestamp: $tsRaw');
//         }
//       }
//
//       if (latestRecord == null) {
//         debugPrint('⚠️ [LOGOUT CHECK] No valid timestamp found — no logout');
//         return;
//       }
//
//       final latestStatus = (latestRecord['STATUS'] ?? latestRecord['status'] ?? '').toString().trim().toLowerCase();
//       debugPrint('📡 [LOGOUT CHECK] Latest REQUEST_TIMESTAMP: $latestTimestamp');
//       debugPrint('📡 [LOGOUT CHECK] Latest STATUS value: "$latestStatus"');
//
//       if (latestStatus == 'requested') {
//         debugPrint('🔒 [LOGOUT CHECK] Latest STATUS=Requested — logging out emp=$empId');
//         // PUT API call — latest record ki STATUS aur ACTUAL_TIMESTAMP update karo
//         await _updateLogoutRecord(latestRecord);
//         await _performForcedLogout();
//       } else {
//         debugPrint('📡 [LOGOUT CHECK] Latest STATUS is not Requested — no logout');
//       }
//     } catch (e) {
//       debugPrint('⚠️ [LOGOUT CHECK] Exception: $e');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // PUT API — Latest logout record ki STATUS=Completed aur ACTUAL_TIMESTAMP update karo
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<void> _updateLogoutRecord(Map<String, dynamic> record) async {
//     try {
//       final id = record['ID'] ?? record['id'];
//       final companyCode = record['COMPANY_CODE'] ?? record['company_code'];
//       if (id == null) {
//         debugPrint('⚠️ [LOGOUT UPDATE] ID not found in record — skipping PUT');
//         return;
//       }
//
//       final uri = Uri.parse(
//         RemoteConfigService.getLogoutUpdateUrl(),
//       );
//
//       final body = jsonEncode({
//         'id': id,
//         'status': 'Completed',
//         'company_code': companyCode,
//       });
//
//       debugPrint('📡 [LOGOUT UPDATE] PUT calling: $uri');
//       debugPrint('📡 [LOGOUT UPDATE] Body: $body');
//
//       final response = await http
//           .put(
//         uri,
//         headers: {'Content-Type': 'application/json'},
//         body: body,
//       )
//           .timeout(const Duration(seconds: 10));
//
//       debugPrint('📡 [LOGOUT UPDATE] Response code: ${response.statusCode}');
//       debugPrint('📡 [LOGOUT UPDATE] Response body: ${response.body}');
//
//       if (response.statusCode == 200 || response.statusCode == 204) {
//         debugPrint('✅ [LOGOUT UPDATE] STATUS=Completed aur ACTUAL_TIMESTAMP updated for ID=$id');
//       } else {
//         debugPrint('⚠️ [LOGOUT UPDATE] Failed — status: ${response.statusCode}');
//       }
//     } catch (e) {
//       debugPrint('⚠️ [LOGOUT UPDATE] Exception: $e');
//     }
//   }
//
//   // ─────────────────────────────────────────────────────────────────────────
//   // FORCED LOGOUT HELPER
//   // Biometric keys preserve karta hai, baqi sab clear karta hai.
//   // ─────────────────────────────────────────────────────────────────────────
//   Future<void> _performForcedLogout() async {
//     final prefs = await SharedPreferences.getInstance();
//
//     // Biometric keys save karo
//     final biometricEnabled  = prefs.getBool(prefBiometricEnabled);
//     final biometricUserId   = prefs.getString(prefBiometricUserId);
//     final biometricPassword = prefs.getString(prefBiometricPassword);
//
//     await prefs.clear();
//
//     if (biometricEnabled == true &&
//         biometricUserId   != null &&
//         biometricPassword != null) {
//       await prefs.setBool(prefBiometricEnabled,   true);
//       await prefs.setString(prefBiometricUserId,   biometricUserId);
//       await prefs.setString(prefBiometricPassword, biometricPassword);
//     }
//
//     Get.offAll(() => const CodeScreen());
//   }
// }
//
// enum LoginStatus { success, notInCompany, wrongPassword, noCompany, networkError, versionMismatch, deviceConflict }
//
// class LoginResult {
//   final LoginStatus status;
//   final LoginModels? user;
//   final String? companyCode;
//   final String? errorMessage;
//
//   LoginResult._({required this.status, this.user, this.companyCode, this.errorMessage});
//
//   factory LoginResult.success(LoginModels user) =>
//       LoginResult._(status: LoginStatus.success, user: user);
//
//   factory LoginResult.notInCompany(String code) =>
//       LoginResult._(status: LoginStatus.notInCompany, companyCode: code);
//
//   factory LoginResult.wrongPassword() =>
//       LoginResult._(status: LoginStatus.wrongPassword);
//
//   factory LoginResult.noCompany() =>
//       LoginResult._(status: LoginStatus.noCompany);
//
//   factory LoginResult.networkError() =>
//       LoginResult._(status: LoginStatus.networkError);
//
//   factory LoginResult.versionMismatch([String? message]) =>
//       LoginResult._(status: LoginStatus.versionMismatch, errorMessage: message);
//
//   factory LoginResult.deviceConflict() =>
//       LoginResult._(status: LoginStatus.deviceConflict);
//
//   bool get isSuccess => status == LoginStatus.success;
// }
//
// class VersionCheckResult {
//   final bool isValid;
//   final String message;
//
//   VersionCheckResult._({required this.isValid, required this.message});
//
//   factory VersionCheckResult.valid() =>
//       VersionCheckResult._(isValid: true, message: '');
//
//   factory VersionCheckResult.mismatch({
//     required String appVersion,
//     required String requiredVersion,
//   }) =>
//       VersionCheckResult._(
//         isValid: false,
//         message: 'App version mismatch. Please update the app.',
//       );
//
//   factory VersionCheckResult.error(String reason) =>
//       VersionCheckResult._(isValid: false, message: reason);
// }

///order
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../Models/LoginModels/login_models.dart';
import '../../Services/biometric_service.dart';
import '../../Services/remote_config_service.dart';
import '../../constants.dart';
import '../../Screens/code_screen.dart';

class LoginRepository extends GetxService {

  static const String prefCachedEndTime = 'cached_end_time';
  static const String prefCachedOvertime = 'cached_overtime';
  static const String prefCachedShift = 'cached_shift';
  static const String prefCachedImageUrl = 'cached_image_url';
  static const String prefCachedDepId = 'cached_dep_id';
  static const String prefCachedAllowCheckInBeforeShift = 'cached_allow_check_in_before_shift';
  static const String prefCachedEntryTime = 'cached_entry_time';
  static const String prefCachedShiftType = 'cached_shift_type';
  static const String prefCachedWagers = 'cached_wagers';
  static const String prefCachedShiftSchedule = 'cached_shift_schedule';
  static const String currentAppVersion = "2.4";

  // ── Offline data cache keys ──────────────────────────────────────────────
  static const String prefCachedBrands = 'cached_brands';
  static const String prefCachedProductsPrefix = 'cached_products_';
  static const String prefCachedShopsPrefix = 'cached_shops_';

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

  Future<String> _getDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('local_device_token');
    if (token == null || token.isEmpty) {
      try {
        if (defaultTargetPlatform == TargetPlatform.android) {
          final androidInfo = await _deviceInfo.androidInfo;
          token = '${androidInfo.id}_${androidInfo.model}_${androidInfo.brand}';
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final iosInfo = await _deviceInfo.iosInfo;
          token = iosInfo.identifierForVendor ?? 'ios_unknown';
        } else {
          token = 'unknown_device';
        }
      } catch (e) {
        debugPrint('⚠️ [DEVICE TOKEN] Could not generate: $e');
        token = 'unknown_device';
      }
      await prefs.setString('local_device_token', token!);
      debugPrint('🔑 [DEVICE TOKEN] Generated & cached: $token');
    } else {
      debugPrint('🔑 [DEVICE TOKEN] Loaded from cache: $token');
    }
    return token!;
  }

  List<int>? _parseTimeLR(String raw) {
    try {
      final String upper   = raw.trim().toUpperCase();
      final bool isPM      = upper.contains('PM');
      final bool isAM      = upper.contains('AM');
      final String cleaned = upper
          .replaceAll('PM', '')
          .replaceAll('AM', '')
          .trim();
      final List<String> parts = cleaned.split(':');
      if (parts.length < 2) return null;
      int? hour   = int.tryParse(parts[0].trim());
      int? minute = int.tryParse(parts[1].trim().split(RegExp(r'\s+'))[0]);
      if (hour == null || minute == null) return null;
      if (isPM && hour != 12) hour += 12;
      if (isAM && hour == 12) hour  = 0;
      return [hour, minute];
    } catch (e) {
      debugPrint('⚠️ [PARSE TIME LR] Error: $e  raw="$raw"');
      return null;
    }
  }

  String _detectShiftType(String? entryTime, String? endTime) {
    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('🌙 [SHIFT DETECT] ===== START =====');
    debugPrint('🌙 [SHIFT DETECT] entry_time raw = "$entryTime"');
    debugPrint('🌙 [SHIFT DETECT] end_time   raw = "$endTime"');

    if (entryTime == null || entryTime.isEmpty ||
        endTime   == null || endTime.isEmpty) {
      debugPrint('🌙 [SHIFT DETECT] ⚠️ One or both times missing → defaulting to Day Shift ☀️');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('');
      return 'Day Shift';
    }

    final List<int>? ep  = _parseTimeLR(entryTime);
    final List<int>? endp = _parseTimeLR(endTime);

    if (ep == null || endp == null) {
      debugPrint('🌙 [SHIFT DETECT] ⚠️ Could not parse times → defaulting to Day Shift ☀️');
      debugPrint('══════════════════════════════════════════════════════');
      debugPrint('');
      return 'Day Shift';
    }

    final int entryTotalMin = ep[0]   * 60 + ep[1];
    final int endTotalMin   = endp[0] * 60 + endp[1];
    final bool isNight      = endTotalMin <= entryTotalMin;

    debugPrint('🌙 [SHIFT DETECT] entry parsed → ${ep[0]}h ${ep[1]}m  (totalMin=$entryTotalMin)');
    debugPrint('🌙 [SHIFT DETECT] end   parsed → ${endp[0]}h ${endp[1]}m  (totalMin=$endTotalMin)');
    debugPrint('🌙 [SHIFT DETECT] endMin <= entryMin ? $isNight (crosses midnight = night shift)');
    debugPrint('🌙 [SHIFT DETECT] ✅ RESULT → ${isNight ? "NIGHT SHIFT 🌙" : "DAY SHIFT ☀️"}');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');

    return isNight ? 'Night Shift' : 'Day Shift';
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

  // ═══════════════════════════════════════════════════════════════════════════
  // OFFLINE DATA PRELOADING — Login ke waqt brands, products, shops cache karo
  // ═══════════════════════════════════════════════════════════════════════════

  // Future<void> preloadOfflineData(String empId, String companyCode) async {
  //   debugPrint('📦 [PRELOAD] Starting offline data preload for emp=$empId...');
  //
  //   try {
  //     // 1. Preload Brands
  //     final brands = await _preloadBrands();
  //     debugPrint('📦 [PRELOAD] Cached ${brands.length} brands');
  //
  //     // 2. Preload Shops (for this employee)
  //     final shops = await _preloadShops(empId, companyCode);
  //     debugPrint('📦 [PRELOAD] Cached ${shops.length} shops');
  //
  //     // 3. Preload Products for first 3 brands (most used)
  //     if (brands.isNotEmpty) {
  //       final brandsToPreload = brands.take(3).toList();
  //       for (final brand in brandsToPreload) {
  //         final products = await _preloadProductsForBrand(brand);
  //         debugPrint('📦 [PRELOAD] Cached ${products.length} products for brand "$brand"');
  //       }
  //     }
  //
  //     debugPrint('✅ [PRELOAD] Offline data preload complete!');
  //   } catch (e) {
  //     debugPrint('⚠️ [PRELOAD] Error during preload: $e');
  //   }
  // }
  //
  // Future<List<String>> _preloadBrands() async {
  //   final endpoint = 'http://oracle.metaxperts.net/ords/gps_workforce/brand/get/';
  //   final prefs = await SharedPreferences.getInstance();
  //
  //   try {
  //     final response = await http.get(Uri.parse(endpoint)).timeout(
  //       const Duration(seconds: 10),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       final items = data['items'] as List? ?? [];
  //       await prefs.setString(prefCachedBrands, jsonEncode(items));
  //
  //       return items
  //           .map((item) => (item['brand'] ?? item['BRAND'])?.toString() ?? '')
  //           .where((name) => name.trim().isNotEmpty)
  //           .toList();
  //     }
  //   } catch (e) {
  //     debugPrint('⚠️ [PRELOAD] Brand preload failed: $e');
  //   }
  //   return [];
  // }
  //
  // Future<List<ShopModel>> _preloadShops(String empId, String companyCode) async {
  //   var endpoint = '/addshopget/get/$empId';
  //   if (companyCode.isNotEmpty) {
  //     endpoint += '?company_code=${Uri.encodeQueryComponent(companyCode)}';
  //   }
  //
  //   final prefs = await SharedPreferences.getInstance();
  //   final cachedKey = '$prefCachedShopsPrefix$empId';
  //
  //   try {
  //     final response = await http.get(
  //       Uri.parse('http://oracle.metaxperts.net/ords/gps_workforce$endpoint'),
  //     ).timeout(const Duration(seconds: 15));
  //
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       final items = data['items'] as List? ?? [];
  //       await prefs.setString(cachedKey, jsonEncode(items));
  //
  //       return items
  //           .map((e) => ShopModel.fromJson(e as Map<String, dynamic>))
  //           .toList();
  //     }
  //   } catch (e) {
  //     debugPrint('⚠️ [PRELOAD] Shop preload failed: $e');
  //   }
  //   return [];
  // }
  //
  // Future<List<ProductItem>> _preloadProductsForBrand(String brand) async {
  //   final endpoint = 'http://oracle.metaxperts.net/ords/gps_workforce/products/get/?brand=${Uri.encodeQueryComponent(brand)}';
  //   final prefs = await SharedPreferences.getInstance();
  //   final cachedKey = '${prefCachedProductsPrefix}$brand';
  //
  //   try {
  //     final response = await http.get(Uri.parse(endpoint)).timeout(
  //       const Duration(seconds: 15),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       final items = data['items'] as List? ?? [];
  //       await prefs.setString(cachedKey, jsonEncode(items));
  //
  //       return items
  //           .map((item) => ProductItem.fromJson(item as Map<String, dynamic>))
  //           .toList();
  //     }
  //   } catch (e) {
  //     debugPrint('⚠️ [PRELOAD] Product preload for "$brand" failed: $e');
  //   }
  //   return [];
  // }


  // In the preloadOfflineData() method, update the cache keys:

  Future<void> preloadOfflineData(String empId, String companyCode) async {
    debugPrint('📦 [PRELOAD] Starting offline data preload for emp=$empId...');

    try {
      // 1. Preload Brands
      final brands = await _preloadBrands();
      debugPrint('📦 [PRELOAD] Cached ${brands.length} brands');

      // 2. Preload Shops (for this employee)
      final shops = await _preloadShops(empId, companyCode);
      debugPrint('📦 [PRELOAD] Cached ${shops.length} shops');

      // 3. Preload Products for first 3 brands (most used)
      if (brands.isNotEmpty) {
        final brandsToPreload = brands.take(3).toList();
        for (final brand in brandsToPreload) {
          final products = await _preloadProductsForBrand(brand);
          debugPrint('📦 [PRELOAD] Cached ${products.length} products for brand "$brand"');
        }
      }

      debugPrint('✅ [PRELOAD] Offline data preload complete!');
    } catch (e) {
      debugPrint('⚠️ [PRELOAD] Error during preload: $e');
    }
  }

  Future<List<String>> _preloadBrands() async {
    final endpoint = 'http://oracle.metaxperts.net/ords/gps_workforce/brand/get/';
    final prefs = await SharedPreferences.getInstance();

    try {
      final response = await http.get(Uri.parse(endpoint)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        await prefs.setString('cached_brands', jsonEncode(items));  // ✅ Consistent

        return items
            .map((item) => (item['brand'] ?? item['BRAND'])?.toString() ?? '')
            .where((name) => name.trim().isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ [PRELOAD] Brand preload failed: $e');
    }
    return [];
  }

  Future<List<ShopModel>> _preloadShops(String empId, String companyCode) async {
    var endpoint = '/addshopget/get/$empId';
    if (companyCode.isNotEmpty) {
      endpoint += '?company_code=${Uri.encodeQueryComponent(companyCode)}';
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedKey = 'cached_shops_$empId';  // ✅ Consistent

    try {
      final response = await http.get(
        Uri.parse('http://oracle.metaxperts.net/ords/gps_workforce$endpoint'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        await prefs.setString(cachedKey, jsonEncode(items));

        return items
            .map((e) => ShopModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ [PRELOAD] Shop preload failed: $e');
    }
    return [];
  }

  Future<List<ProductItem>> _preloadProductsForBrand(String brand) async {
    final endpoint = 'http://oracle.metaxperts.net/ords/gps_workforce/products/get/?brand=${Uri.encodeQueryComponent(brand)}';
    final prefs = await SharedPreferences.getInstance();
    final cachedKey = 'cached_products_$brand';  // ✅ Consistent

    try {
      final response = await http.get(Uri.parse(endpoint)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        await prefs.setString(cachedKey, jsonEncode(items));

        return items
            .map((item) => ProductItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('⚠️ [PRELOAD] Product preload for "$brand" failed: $e');
    }
    return [];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GET BRANDS — with offline cache fallback
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<String>> getBrands() async {
    final endpoint = 'http://oracle.metaxperts.net/ords/gps_workforce/brand/get/';
    final prefs = await SharedPreferences.getInstance();

    // Try to load from cache first
    final cachedData = prefs.getString(prefCachedBrands);
    if (cachedData != null && cachedData.isNotEmpty) {
      try {
        final List<dynamic> cachedItems = jsonDecode(cachedData);
        final cachedBrands = cachedItems
            .map((item) => (item['brand'] ?? item['BRAND'])?.toString() ?? '')
            .where((name) => name.trim().isNotEmpty)
            .toList();
        if (cachedBrands.isNotEmpty) {
          debugPrint('📦 [LoginRepository] Loaded ${cachedBrands.length} brands from cache');
          // Refresh in background
          _refreshBrandsInBackground();
          return cachedBrands;
        }
      } catch (e) {
        debugPrint('⚠️ [LoginRepository] Error parsing cached brands: $e');
      }
    }

    try {
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final result = items
            .map((item) => (item['brand'] ?? item['BRAND'])?.toString() ?? '')
            .where((name) => name.trim().isNotEmpty)
            .toList();

        await prefs.setString(prefCachedBrands, jsonEncode(items));
        debugPrint('✅ [LoginRepository] Cached ${result.length} brands');
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('💥 [LoginRepository] Error fetching brands: $e');
      // Fallback to cache
      if (cachedData != null && cachedData.isNotEmpty) {
        try {
          final List<dynamic> cachedItems = jsonDecode(cachedData);
          return cachedItems
              .map((item) => (item['brand'] ?? item['BRAND'])?.toString() ?? '')
              .where((name) => name.trim().isNotEmpty)
              .toList();
        } catch (_) {}
      }
      return [];
    }
  }

  Future<void> _refreshBrandsInBackground() async {
    try {
      final endpoint = 'http://oracle.metaxperts.net/ords/gps_workforce/brand/get/';
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(prefCachedBrands, jsonEncode(items));
        debugPrint('🔄 [LoginRepository] Background brand refresh complete');
      }
    } catch (e) {
      debugPrint('⚠️ [LoginRepository] Background brand refresh failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GET PRODUCTS BY BRAND — with offline cache fallback
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<ProductItem>> getProductsByBrand(String brand) async {
    final endpoint = 'http://oracle.metaxperts.net/ords/gps_workforce/products/get/?brand=${Uri.encodeQueryComponent(brand)}';
    final prefs = await SharedPreferences.getInstance();
    final cachedKey = '${prefCachedProductsPrefix}$brand';
    final cachedData = prefs.getString(cachedKey);

    if (cachedData != null && cachedData.isNotEmpty) {
      try {
        final List<dynamic> cachedItems = jsonDecode(cachedData);
        final cachedProducts = cachedItems
            .map((item) => ProductItem.fromJson(item as Map<String, dynamic>))
            .toList();
        if (cachedProducts.isNotEmpty) {
          debugPrint('📦 [LoginRepository] Loaded ${cachedProducts.length} products for "$brand" from cache');
          _refreshProductsInBackground(brand);
          return cachedProducts;
        }
      } catch (e) {
        debugPrint('⚠️ [LoginRepository] Error parsing cached products: $e');
      }
    }

    try {
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final result = items
            .map((item) => ProductItem.fromJson(item as Map<String, dynamic>))
            .toList();

        await prefs.setString(cachedKey, jsonEncode(items));
        debugPrint('✅ [LoginRepository] Cached ${result.length} products for "$brand"');
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('💥 [LoginRepository] Error fetching products for "$brand": $e');
      if (cachedData != null && cachedData.isNotEmpty) {
        try {
          final List<dynamic> cachedItems = jsonDecode(cachedData);
          return cachedItems
              .map((item) => ProductItem.fromJson(item as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
      return [];
    }
  }

  Future<void> _refreshProductsInBackground(String brand) async {
    try {
      final endpoint = 'http://oracle.metaxperts.net/ords/gps_workforce/products/get/?brand=${Uri.encodeQueryComponent(brand)}';
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('${prefCachedProductsPrefix}$brand', jsonEncode(items));
        debugPrint('🔄 [LoginRepository] Background product refresh complete for "$brand"');
      }
    } catch (e) {
      debugPrint('⚠️ [LoginRepository] Background product refresh failed for "$brand": $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GET SHOPS — with offline cache fallback
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<ShopModel>> getShops(String empId, String companyCode) async {
    var endpoint = '/addshopget/get/$empId';
    if (companyCode.isNotEmpty) {
      endpoint += '?company_code=${Uri.encodeQueryComponent(companyCode)}';
    }

    final prefs = await SharedPreferences.getInstance();
    final cachedKey = '$prefCachedShopsPrefix$empId';
    final cachedData = prefs.getString(cachedKey);

    if (cachedData != null && cachedData.isNotEmpty) {
      try {
        final List<dynamic> cachedItems = jsonDecode(cachedData);
        final cachedShops = cachedItems
            .map((e) => ShopModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (cachedShops.isNotEmpty) {
          debugPrint('📦 [LoginRepository] Loaded ${cachedShops.length} shops from cache');
          _refreshShopsInBackground(empId, companyCode);
          return cachedShops;
        }
      } catch (e) {
        debugPrint('⚠️ [LoginRepository] Error parsing cached shops: $e');
      }
    }

    try {
      final response = await http.get(
        Uri.parse('http://oracle.metaxperts.net/ords/gps_workforce$endpoint'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final result = items
            .map((e) => ShopModel.fromJson(e as Map<String, dynamic>))
            .toList();

        await prefs.setString(cachedKey, jsonEncode(items));
        debugPrint('✅ [LoginRepository] Cached ${result.length} shops');
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('💥 [LoginRepository] Error fetching shops: $e');
      if (cachedData != null && cachedData.isNotEmpty) {
        try {
          final List<dynamic> cachedItems = jsonDecode(cachedData);
          return cachedItems
              .map((e) => ShopModel.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {}
      }
      return [];
    }
  }

  Future<void> _refreshShopsInBackground(String empId, String companyCode) async {
    try {
      var endpoint = '/addshopget/get/$empId';
      if (companyCode.isNotEmpty) {
        endpoint += '?company_code=${Uri.encodeQueryComponent(companyCode)}';
      }
      final response = await http.get(
        Uri.parse('http://oracle.metaxperts.net/ords/gps_workforce$endpoint'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? [];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$prefCachedShopsPrefix$empId', jsonEncode(items));
        debugPrint('🔄 [LoginRepository] Background shop refresh complete');
      }
    } catch (e) {
      debugPrint('⚠️ [LoginRepository] Background shop refresh failed: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // END OF OFFLINE DATA METHODS
  // ═══════════════════════════════════════════════════════════════════════════

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

        final String localToken   = await _getDeviceToken();
        final String? serverToken = user.device_token;
        debugPrint('🔑 [DEVICE CHECK] Local  token: $localToken');
        debugPrint('🔑 [DEVICE CHECK] Server token: $serverToken');

        if (serverToken != null &&
            serverToken.isNotEmpty &&
            serverToken != localToken) {
          debugPrint('❌ [DEVICE CHECK] Token mismatch — login rejected');
          return LoginResult.deviceConflict();
        }
        debugPrint('✅ [DEVICE CHECK] Token OK — proceeding with login');

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
        await prefs.setString(
          prefCachedAllowCheckInBeforeShift,
          user.allow_check_in_before_shift ?? 'no',
        );
        debugPrint('📦 [LOGIN] allow_check_in_before_shift: ${user.allow_check_in_before_shift}');
        if (user.entry_time != null && user.entry_time!.isNotEmpty) {
          await prefs.setString(prefCachedEntryTime, user.entry_time!);
        }
        debugPrint('📦 [LOGIN] entry_time: ${user.entry_time}');

        final String shiftType = _detectShiftType(user.entry_time, user.end_time);
        await prefs.setString(prefCachedShiftType, shiftType);
        debugPrint('🌙 [LOGIN] Shift type cached: $shiftType');

        postSignInDetails(
          empId: userId,
          empName: user.emp_name ?? '',
          companyCode: savedCompanyCode,
          deviceToken: localToken,
        );

        fetchAndCacheLocations(userId, savedCompanyCode);
        _fetchAndCacheShiftSchedule(userId, savedCompanyCode);

        // ✅ OFFLINE DATA PRELOAD — Login ke waqt brands/products/shops cache karo
        unawaited(preloadOfflineData(userId, savedCompanyCode));

        fetchAndCacheWagers(userId, savedCompanyCode);

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
    String deviceToken = '',
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
      'emp_id':          empId,
      'emp_name':        empName,
      'company_code':    companyCode,
      'app_version':     2.4,
      'timestamp':       DateTime.now().toIso8601String(),
      'device_info':     deviceModel,
      'android_version': androidVersion,
      'device_id':       deviceId,
      'sim_info':        simInfo,
      'device_token':    deviceToken,
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

  String wagerCacheKey(String empId, String companyCode) =>
      '${prefCachedWagers}_${empId}_$companyCode';

  Future<bool> fetchAndCacheWagers(String empId, String companyCode) async {
    try {
      final uri = Uri.parse(
        'http://oracle.metaxperts.net/ords/gps_workforce/wagerdetail/get',
      ).replace(queryParameters: {
        'emp_id': empId,
        'company_code': companyCode,
      });

      debugPrint('📡 [WAGER CACHE] Fetching: $uri');

      final httpClient = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      final ioClient = IOClient(httpClient);

      final response = await ioClient
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('⚠️ [WAGER CACHE] Non-200: ${response.statusCode}');
        return false;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic> items = decoded['items'] ?? decoded['data'] ?? [];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(wagerCacheKey(empId, companyCode), jsonEncode(items));

      debugPrint('✅ [WAGER CACHE] Cached ${items.length} wager record(s) for emp=$empId');
      return true;
    } catch (e) {
      debugPrint('⚠️ [WAGER CACHE] Failed (offline?): $e');
      return false;
    }
  }

  Future<void> refreshShiftSchedule(String empId, String companyCode) =>
      _fetchAndCacheShiftSchedule(empId, companyCode);

  String _extractFirstNonEmpty(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k]?.toString().trim() ?? '';
      if (v.isNotEmpty && v != 'null') return v;
    }
    return '';
  }

  Future<void> _fetchAndCacheShiftSchedule(
      String empId, String companyCode) async {
    try {
      final uri = Uri.parse(
        'http://oracle.metaxperts.net/ords/gps_workforce/shiftdetails/get/',
      ).replace(queryParameters: {
        'emp_id':       empId,
        'company_code': companyCode,
      });

      debugPrint('📡 [SHIFT SCHEDULE] Fetching: $uri');

      final response = await http
          .get(uri)
          .timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));

      if (response.statusCode != 200) {
        debugPrint('⚠️ [SHIFT SCHEDULE] Non-200: ${response.statusCode} — old times unchanged');
        return;
      }

      final Map<String, dynamic> data  = json.decode(response.body);
      final List<dynamic>        items = data['items'] ?? [];

      if (items.isEmpty) {
        debugPrint('⚠️ [SHIFT SCHEDULE] No shift data for emp=$empId — using old flat times');
        return;
      }

      const Map<String, String> dayMap = {
        'MON': 'Monday',   'TUE': 'Tuesday',  'WED': 'Wednesday',
        'THU': 'Thursday', 'FRI': 'Friday',   'SAT': 'Saturday',
        'SUN': 'Sunday',
      };

      final Map<String, dynamic> scheduleMap = {};

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[SHIFT SCHEDULE] 🔍 Raw API keys (first row): ${items.isNotEmpty ? (items[0] as Map).keys.toList() : "N/A"}');

      for (final item in items) {
        final map        = item as Map<String, dynamic>;
        final String raw = (map['DAY_OF_WEEK']  ?? map['day_of_week']  ?? '')
            .toString().toUpperCase().trim();
        final String day = dayMap[raw] ?? raw;
        if (day.isEmpty) continue;

        final String bStart = _extractFirstNonEmpty(map, const [
          'break_start', 'BREAK_START',
        ]);
        final String bEnd = _extractFirstNonEmpty(map, const [
          'break_end', 'BREAK_END',
        ]);

        scheduleMap[day] = {
          'working':        (map['IS_WORKING_DAY'] ?? map['is_working_day'] ?? 'Yes').toString(),
          'start_time':     (map['START_TIME']      ?? map['start_time']     ?? '').toString(),
          'end_time':       (map['END_TIME']        ?? map['end_time']       ?? '').toString(),
          'spans_midnight': (map['SPANS_MIDNIGHT']  ?? map['spans_midnight'] ?? 'No').toString(),
          'break_start': bStart,
          'break_end':   bEnd,
        };

        debugPrint('[SHIFT SCHEDULE] 📅 $day'
            ' | shift: ${scheduleMap[day]!['start_time']}–${scheduleMap[day]!['end_time']}'
            ' | break: ${bStart.isNotEmpty ? bStart : "N/A"}–${bEnd.isNotEmpty ? bEnd : "N/A"}'
            ' | working: ${scheduleMap[day]!['working']}');
      }
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefCachedShiftSchedule, jsonEncode(scheduleMap));
      debugPrint('✅ [SHIFT SCHEDULE] Cached ${scheduleMap.length} days for emp=$empId');
      debugPrint('[SHIFT SCHEDULE] 🗓️ Full cached schedule: ${jsonEncode(scheduleMap)}');
    } catch (e) {
      debugPrint('⚠️ [SHIFT SCHEDULE] Failed (offline?): $e');
    }
  }

  Future<String?> getCachedDepId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefCachedDepId);
  }

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
        await prefs.setString(
          prefCachedAllowCheckInBeforeShift,
          user.allow_check_in_before_shift ?? 'no',
        );
        debugPrint('📦 [EMP REFRESH] allow_check_in_before_shift: ${user.allow_check_in_before_shift}');
        if (user.entry_time != null && user.entry_time!.isNotEmpty) {
          await prefs.setString(prefCachedEntryTime, user.entry_time!);
        }
        debugPrint('📦 [EMP REFRESH] entry_time: ${user.entry_time}');

        final String shiftType = _detectShiftType(user.entry_time, user.end_time);
        await prefs.setString(prefCachedShiftType, shiftType);
        debugPrint('🌙 [EMP REFRESH] Shift type cached: $shiftType');

        debugPrint('✅ [EMP REFRESH] All fields updated for emp=$userId');
        await _fetchAndCacheShiftSchedule(userId, companyCode);
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

  Future<void> checkServerLogout(String empId, String companyCode) async {
    try {
      final uri = Uri.parse(
        RemoteConfigService.getLogoutCheckUrl(empId, companyCode),
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

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
        await _updateLogoutRecord(latestRecord);
        await _performForcedLogout();
      } else {
        debugPrint('📡 [LOGOUT CHECK] Latest STATUS is not Requested — no logout');
      }
    } catch (e) {
      debugPrint('⚠️ [LOGOUT CHECK] Exception: $e');
    }
  }

  Future<void> _updateLogoutRecord(Map<String, dynamic> record) async {
    try {
      final id = record['ID'] ?? record['id'];
      final companyCode = record['COMPANY_CODE'] ?? record['company_code'];
      if (id == null) {
        debugPrint('⚠️ [LOGOUT UPDATE] ID not found in record — skipping PUT');
        return;
      }

      final uri = Uri.parse(
        RemoteConfigService.getLogoutUpdateUrl(),
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

  Future<void> _performForcedLogout() async {
    final prefs = await SharedPreferences.getInstance();

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

enum LoginStatus { success, notInCompany, wrongPassword, noCompany, networkError, versionMismatch, deviceConflict }

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

  factory LoginResult.deviceConflict() =>
      LoginResult._(status: LoginStatus.deviceConflict);

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

// ── Lightweight data classes (matching booking_repository) ──────────────

class ProductItem {
  final String id;
  final String name;
  final String brand;
  final String price;

  ProductItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) => ProductItem(
    id: json['id']?.toString() ??
        json['ID']?.toString() ??
        json['product_id']?.toString() ??
        '',
    name: json['product_name']?.toString() ??
        json['PRODUCT_NAME']?.toString() ??
        json['product']?.toString() ??
        json['PRODUCT']?.toString() ??
        json['name']?.toString() ??
        json['NAME']?.toString() ??
        '',
    brand: json['brand']?.toString() ?? json['BRAND']?.toString() ?? '',
    price: json['price']?.toString() ??
        json['PRICE']?.toString() ??
        json['product_price']?.toString() ??
        '0',
  );
}

class ShopModel {
  final String id;
  final String empId;
  final String empName;
  final String companyCode;
  final String shopName;
  final String shopId;
  final String shopType;
  final String ownerName;
  final String contactNumber;
  final String city;
  final String address;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final String? createdDate;
  final String? createdTime;

  const ShopModel({
    required this.id,
    required this.empId,
    required this.empName,
    required this.companyCode,
    required this.shopName,
    required this.shopId,
    required this.shopType,
    required this.ownerName,
    required this.contactNumber,
    required this.city,
    required this.address,
    this.notes,
    this.latitude,
    this.longitude,
    this.createdDate,
    this.createdTime,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return ShopModel(
      id:            json['id']?.toString() ?? '',
      empId:         json['emp_id']?.toString() ?? '',
      empName:       json['emp_name']?.toString() ?? '',
      companyCode:   json['company_code']?.toString() ?? '',
      shopName:      json['shop_name']?.toString() ?? '',
      shopId:        json['shop_id']?.toString() ?? '',
      shopType:      json['shop_type']?.toString() ?? '',
      ownerName:     json['owner_name']?.toString() ?? '',
      contactNumber: json['contact_number']?.toString() ?? '',
      city:          json['city']?.toString() ?? '',
      address:       json['address']?.toString() ?? '',
      notes:         json['notes']?.toString(),
      latitude:      toDouble(json['latitude']),
      longitude:     toDouble(json['longitude']),
      createdDate:   json['created_date']?.toString(),
      createdTime:   json['created_time']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'emp_id': empId,
    'emp_name': empName,
    'company_code': companyCode,
    'shop_name': shopName,
    'shop_id': shopId,
    'shop_type': shopType,
    'owner_name': ownerName,
    'contact_number': contactNumber,
    'city': city,
    'address': address,
    'notes': notes,
    'latitude': latitude,
    'longitude': longitude,
    'created_date': createdDate,
    'created_time': createdTime,
  };
}