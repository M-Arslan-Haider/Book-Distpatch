// //
// // import 'dart:convert';
// // import 'package:flutter/foundation.dart';
// // import 'package:get/get.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:shared_preferences/shared_preferences.dart';
// // import '../../Models/LoginModels/login_models.dart';
// // import '../../constants.dart';
// //
// // class LoginRepository extends GetxService {
// //
// //   // Get login API URL with company_code filter
// //   Future<String> _getLoginApiUrl() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final companyCode = prefs.getString(prefCompanyCode) ?? '';
// //
// //     if (companyCode.isNotEmpty) {
// //       return ApiManager.getLoginApi(companyCode);
// //     }
// //
// //     return loginApiEndpoint;
// //   }
// //
// //   // Fetch employees from API - backend filters by company_code automatically
// //   Future<List<LoginModels>> fetchLoginFromApi() async {
// //     try {
// //       final apiUrl = await _getLoginApiUrl();
// //       debugPrint('📡 Fetching login data from: $apiUrl');
// //
// //       final response = await http
// //           .get(Uri.parse(apiUrl))
// //           .timeout(const Duration(seconds: 30));
// //
// //       if (response.statusCode != 200) {
// //         throw Exception('Failed to load login data: ${response.statusCode}');
// //       }
// //
// //       final Map<String, dynamic> data = json.decode(response.body);
// //       List<dynamic> items = data['items'] ?? [];
// //
// //       debugPrint('✅ Fetched ${items.length} users from API');
// //       return items.map((json) => LoginModels.fromJson(json)).toList();
// //     } catch (e) {
// //       debugPrint('❌ Error fetching login data: $e');
// //       return [];
// //     }
// //   }
// //
// //   // Fetch and cache locations for a given emp_id + company_code
// //   // Called right after a successful login while internet is available
// //   Future<void> fetchAndCacheLocations(String empId, String companyCode) async {
// //     try {
// //       debugPrint('📍 [LOCATION CACHE] Fetching locations for emp=$empId  company=$companyCode');
// //
// //       final response = await http.get(
// //         Uri.http(
// //           'oracle.metaxperts.net',
// //           '/ords/gps_workforce/geofenceinfo/get',
// //           {
// //             'emp_id'      : empId,
// //             'company_code': companyCode,
// //           },
// //         ),
// //         headers: {'Content-Type': 'application/json'},
// //       ).timeout(const Duration(seconds: 15));
// //
// //       if (response.statusCode == 200) {
// //         final data  = jsonDecode(response.body) as Map<String, dynamic>;
// //         final items = (data['items'] ?? []) as List<dynamic>;
// //
// //         // Persist raw JSON list so LocationSelectionScreen can read it offline
// //         final prefs = await SharedPreferences.getInstance();
// //         await prefs.setString('cached_locations', jsonEncode(items));
// //         await prefs.setString('cached_locations_emp_id', empId);
// //         debugPrint('✅ [LOCATION CACHE] Cached ${items.length} location(s)');
// //       } else {
// //         debugPrint('⚠️ [LOCATION CACHE] Status ${response.statusCode} – cache unchanged');
// //       }
// //     } catch (e) {
// //       debugPrint('⚠️ [LOCATION CACHE] Failed to pre-fetch locations: $e (cached data will be used)');
// //     }
// //   }
// //
// //   // Get user by emp_id only - no need to check company_code
// //   // because backend SQL already does: WHERE company_code = :company_code
// //   Future<LoginModels?> getUserByCredentials(String userId, String password) async {
// //     try {
// //       final apiData = await fetchLoginFromApi();
// //
// //       int? userIdInt = int.tryParse(userId);
// //
// //       for (var user in apiData) {
// //         bool idMatches = false;
// //
// //         if (userIdInt != null) {
// //           idMatches = user.emp_id == userIdInt;
// //         } else {
// //           idMatches = user.emp_id.toString() == userId;
// //         }
// //
// //         if (idMatches) {
// //           debugPrint('✅ User found: ${user.emp_name}, Role: ${user.job}');
// //           return user;
// //         }
// //       }
// //
// //       debugPrint('❌ User not found with ID: $userId');
// //       return null;
// //     } catch (e) {
// //       debugPrint('❌ Error in getUserByCredentials: $e');
// //       return null;
// //     }
// //   }
// // }
//
// ///end time
// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../Models/LoginModels/login_models.dart';
// import '../../constants.dart';
//
// class LoginRepository extends GetxService {
//
//   // Get login API URL with company_code filter
//   Future<String> _getLoginApiUrl() async {
//     final prefs = await SharedPreferences.getInstance();
//     final companyCode = prefs.getString(prefCompanyCode) ?? '';
//
//     if (companyCode.isNotEmpty) {
//       return ApiManager.getLoginApi(companyCode);
//     }
//
//     return loginApiEndpoint;
//   }
//
//   // Fetch employees from API - backend filters by company_code automatically
//   Future<List<LoginModels>> fetchLoginFromApi() async {
//     try {
//       final apiUrl = await _getLoginApiUrl();
//       debugPrint('📡 Fetching login data from: $apiUrl');
//
//       final response = await http
//           .get(Uri.parse(apiUrl))
//           .timeout(const Duration(seconds: 30));
//
//       if (response.statusCode != 200) {
//         throw Exception('Failed to load login data: ${response.statusCode}');
//       }
//
//       final Map<String, dynamic> data = json.decode(response.body);
//       List<dynamic> items = data['items'] ?? [];
//
//       debugPrint('✅ Fetched ${items.length} users from API');
//       return items.map((json) => LoginModels.fromJson(json)).toList();
//     } catch (e) {
//       debugPrint('❌ Error fetching login data: $e');
//       return [];
//     }
//   }
//
//   // Fetch and cache locations for a given emp_id + company_code
//   // Called right after a successful login while internet is available
//   Future<void> fetchAndCacheLocations(String empId, String companyCode) async {
//     try {
//       debugPrint('📍 [LOCATION CACHE] Fetching locations for emp=$empId  company=$companyCode');
//
//       final response = await http.get(
//         Uri.http(
//           'oracle.metaxperts.net',
//           '/ords/gps_workforce/geofenceinfo/get',
//           {
//             'emp_id'      : empId,
//             'company_code': companyCode,
//           },
//         ),
//         headers: {'Content-Type': 'application/json'},
//       ).timeout(const Duration(seconds: 15));
//
//       if (response.statusCode == 200) {
//         final data  = jsonDecode(response.body) as Map<String, dynamic>;
//         final items = (data['items'] ?? []) as List<dynamic>;
//
//         // Persist raw JSON list so LocationSelectionScreen can read it offline
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.setString('cached_locations', jsonEncode(items));
//         await prefs.setString('cached_locations_emp_id', empId);
//         debugPrint('✅ [LOCATION CACHE] Cached ${items.length} location(s)');
//       } else {
//         debugPrint('⚠️ [LOCATION CACHE] Status ${response.statusCode} – cache unchanged');
//       }
//     } catch (e) {
//       debugPrint('⚠️ [LOCATION CACHE] Failed to pre-fetch locations: $e (cached data will be used)');
//     }
//   }
//
//   // Fetch and cache employee end time for a given emp_id + company_code
//   // Called right after a successful login so it is available offline
//   Future<void> fetchAndCacheEndTime(String empId, String companyCode) async {
//     try {
//       debugPrint('⏰ [END TIME CACHE] Fetching end time for emp=$empId  company=$companyCode');
//
//       final response = await http.get(
//         Uri.http(
//           'oracle.metaxperts.net',
//           '/ords/gps_workforce/endtime/get/',
//           {
//             'emp_id'      : empId,
//             'company_code': companyCode,
//           },
//         ),
//         headers: {'Accept': 'application/json'},
//       ).timeout(const Duration(seconds: 15));
//
//       debugPrint('📥 [END TIME CACHE] Status: ${response.statusCode}');
//       debugPrint('📥 [END TIME CACHE] Body: ${response.body}');
//
//       if (response.statusCode == 200) {
//         final decoded = jsonDecode(response.body);
//         String? endTimeStr;
//
//         // Case 1: flat object  { "end_time": "17:30:00", ... }
//         if (decoded is Map<String, dynamic>) {
//           endTimeStr = _extractEndTimeFromMap(decoded);
//
//           // Case 2: items array  { "items": [ { "end_time": "17:30:00" } ] }
//           if (endTimeStr == null) {
//             final items = decoded['items'];
//             if (items is List && items.isNotEmpty) {
//               final first = items.first;
//               if (first is Map<String, dynamic>) {
//                 endTimeStr = _extractEndTimeFromMap(first);
//               }
//             }
//           }
//         }
//
//         // Case 3: bare array  [ { "end_time": "17:30:00" } ]
//         if (endTimeStr == null && decoded is List && decoded.isNotEmpty) {
//           final first = decoded.first;
//           if (first is Map<String, dynamic>) {
//             endTimeStr = _extractEndTimeFromMap(first);
//           }
//         }
//
//         if (endTimeStr != null && endTimeStr.isNotEmpty) {
//           final prefs = await SharedPreferences.getInstance();
//           await prefs.setString('cached_end_time', endTimeStr);
//           await prefs.setString('cached_end_time_emp_id', empId);
//           debugPrint('✅ [END TIME CACHE] Cached end time: $endTimeStr');
//         } else {
//           debugPrint('⚠️ [END TIME CACHE] No end_time field found in response body');
//         }
//       } else {
//         debugPrint('⚠️ [END TIME CACHE] Status ${response.statusCode} – cache unchanged');
//       }
//     } catch (e, stack) {
//       debugPrint('⚠️ [END TIME CACHE] Failed: $e');
//       debugPrint('⚠️ [END TIME CACHE] Stack: $stack');
//     }
//   }
//
//   /// Extracts end-time string from a map, trying common field names.
//   String? _extractEndTimeFromMap(Map<String, dynamic> map) {
//     for (final key in ['end_time', 'endTime', 'end_hour', 'shift_end', 'time']) {
//       final val = map[key];
//       if (val != null && val.toString().isNotEmpty) return val.toString();
//     }
//     return null;
//   }
//
//   // Get user by emp_id only - no need to check company_code
//   // because backend SQL already does: WHERE company_code = :company_code
//   Future<LoginModels?> getUserByCredentials(String userId, String password) async {
//     try {
//       final apiData = await fetchLoginFromApi();
//
//       int? userIdInt = int.tryParse(userId);
//
//       for (var user in apiData) {
//         bool idMatches = false;
//
//         if (userIdInt != null) {
//           idMatches = user.emp_id == userIdInt;
//         } else {
//           idMatches = user.emp_id.toString() == userId;
//         }
//
//         if (idMatches) {
//           debugPrint('✅ User found: ${user.emp_name}, Role: ${user.job}');
//           return user;
//         }
//       }
//
//       debugPrint('❌ User not found with ID: $userId');
//       return null;
//     } catch (e) {
//       debugPrint('❌ Error in getUserByCredentials: $e');
//       return null;
//     }
//   }
// }

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
  // Fetches ALL employees for that company_code and caches them locally.
  // ─────────────────────────────────────────────────────────────────────────
  Future<bool> fetchAndCacheEmployeesForCompany(String companyCode) async {
    try {
      final apiUrl = '$loginApiEndpoint?company_code=$companyCode';
      debugPrint('📡 [EMPLOYEE CACHE] Fetching from: $apiUrl');

      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('❌ [EMPLOYEE CACHE] Status: ${response.statusCode}');
        return false;
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> items = data['items'] ?? [];

      debugPrint('✅ [EMPLOYEE CACHE] ${items.length} employees fetched for: $companyCode');

      if (items.isNotEmpty) {
        debugPrint('🔍 [EMPLOYEE CACHE] Sample fields: ${(items.first as Map).keys.toList()}');
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
  // STEP 2 — Called from LoginScreen.
  // Checks emp_id against cached employees of the saved company_code.
  // Returns user if found, null if emp_id not in this company.
  // ─────────────────────────────────────────────────────────────────────────
  Future<LoginModels?> getUserByCredentials(String userId, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCompanyCode = prefs.getString(prefCompanyCode) ?? '';

      if (savedCompanyCode.isEmpty) {
        debugPrint('❌ [LOGIN] No company code saved.');
        return null;
      }

      // Load cached employees
      List<dynamic> items = [];
      final cached = prefs.getString('cached_employees_$savedCompanyCode');

      if (cached != null && cached.isNotEmpty) {
        items = jsonDecode(cached) as List<dynamic>;
        debugPrint('📦 [LOGIN] ${items.length} cached employees for: $savedCompanyCode');
      } else {
        // Fallback: fetch live if cache is missing
        debugPrint('🌐 [LOGIN] Cache miss — fetching live...');
        final apiUrl = '$loginApiEndpoint?company_code=$savedCompanyCode';
        final response = await http
            .get(Uri.parse(apiUrl))
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          items = data['items'] ?? [];
          await prefs.setString('cached_employees_$savedCompanyCode', jsonEncode(items));
          debugPrint('✅ [LOGIN] Fetched ${items.length} employees live');
        } else {
          debugPrint('❌ [LOGIN] Live fetch failed: ${response.statusCode}');
          return null;
        }
      }

      final int? userIdInt = int.tryParse(userId);

      for (var item in items) {
        final map = item as Map<String, dynamic>;
        final user = LoginModels.fromJson(map);

        // Check emp_id
        final bool idMatches = userIdInt != null
            ? user.emp_id == userIdInt
            : user.emp_id.toString() == userId;

        if (!idMatches) continue;

        // ✅ ADD PASSWORD VALIDATION HERE
        final String storedPassword = map['portal_password']?.toString() ?? '';
        final bool passwordMatches = storedPassword == password;

        debugPrint('🔍 emp_id=${user.emp_id} | password check: $passwordMatches');

        if (!passwordMatches) {
          debugPrint('❌ Password mismatch for emp_id: $userId');
          return null;  // Password is wrong
        }

        // Check company_code
        final String rawCompany = (map['company_code'] ?? '').toString().toUpperCase();
        final bool companyMatches = rawCompany.isEmpty ||
            rawCompany == savedCompanyCode.toUpperCase();

        if (companyMatches) {
          debugPrint('✅ Login OK: ${user.emp_name} | ${user.job}');
          return user;
        } else {
          debugPrint('❌ emp_id=$userId found but belongs to wrong company');
          return null;
        }
      }

      debugPrint('❌ emp_id=$userId not found in company=$savedCompanyCode');
      return null;
    } catch (e) {
      debugPrint('❌ Error in getUserByCredentials: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Background: cache locations after successful login
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchAndCacheLocations(String empId, String companyCode) async {
    try {
      debugPrint('📍 [LOCATION CACHE] emp=$empId company=$companyCode');

      final response = await http.get(
        Uri.http('oracle.metaxperts.net', '/ords/gps_workforce/geofenceinfo/get', {
          'emp_id': empId,
          'company_code': companyCode,
        }),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['items'] ?? []) as List<dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_locations', jsonEncode(items));
        await prefs.setString('cached_locations_emp_id', empId);
        debugPrint('✅ [LOCATION CACHE] ${items.length} location(s) cached');
      } else {
        debugPrint('⚠️ [LOCATION CACHE] Status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ [LOCATION CACHE] Failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Background: cache end time after successful login
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> fetchAndCacheEndTime(String empId, String companyCode) async {
    try {
      debugPrint('⏰ [END TIME CACHE] emp=$empId company=$companyCode');

      final response = await http.get(
        Uri.http('oracle.metaxperts.net', '/ords/gps_workforce/endtime/get/', {
          'emp_id': empId,
          'company_code': companyCode,
        }),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('📥 [END TIME] Status: ${response.statusCode} Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        String? endTimeStr;

        if (decoded is Map<String, dynamic>) {
          endTimeStr = _extractEndTimeFromMap(decoded);
          if (endTimeStr == null) {
            final it = decoded['items'];
            if (it is List && it.isNotEmpty && it.first is Map<String, dynamic>) {
              endTimeStr = _extractEndTimeFromMap(it.first as Map<String, dynamic>);
            }
          }
        } else if (decoded is List && decoded.isNotEmpty && decoded.first is Map<String, dynamic>) {
          endTimeStr = _extractEndTimeFromMap(decoded.first as Map<String, dynamic>);
        }

        if (endTimeStr != null && endTimeStr.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_end_time', endTimeStr);
          await prefs.setString('cached_end_time_emp_id', empId);
          debugPrint('✅ [END TIME CACHE] $endTimeStr');
        } else {
          debugPrint('⚠️ [END TIME CACHE] No end_time field found');
        }
      }
    } catch (e, stack) {
      debugPrint('⚠️ [END TIME CACHE] $e\n$stack');
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