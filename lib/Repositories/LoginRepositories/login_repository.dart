//
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

///end time
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../Models/LoginModels/login_models.dart';
import '../../constants.dart';

class LoginRepository extends GetxService {

  // Get login API URL with company_code filter
  Future<String> _getLoginApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final companyCode = prefs.getString(prefCompanyCode) ?? '';

    if (companyCode.isNotEmpty) {
      return ApiManager.getLoginApi(companyCode);
    }

    return loginApiEndpoint;
  }

  // Fetch employees from API - backend filters by company_code automatically
  Future<List<LoginModels>> fetchLoginFromApi() async {
    try {
      final apiUrl = await _getLoginApiUrl();
      debugPrint('📡 Fetching login data from: $apiUrl');

      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to load login data: ${response.statusCode}');
      }

      final Map<String, dynamic> data = json.decode(response.body);
      List<dynamic> items = data['items'] ?? [];

      debugPrint('✅ Fetched ${items.length} users from API');
      return items.map((json) => LoginModels.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ Error fetching login data: $e');
      return [];
    }
  }

  // Fetch and cache locations for a given emp_id + company_code
  // Called right after a successful login while internet is available
  Future<void> fetchAndCacheLocations(String empId, String companyCode) async {
    try {
      debugPrint('📍 [LOCATION CACHE] Fetching locations for emp=$empId  company=$companyCode');

      final response = await http.get(
        Uri.http(
          'oracle.metaxperts.net',
          '/ords/gps_workforce/geofenceinfo/get',
          {
            'emp_id'      : empId,
            'company_code': companyCode,
          },
        ),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body) as Map<String, dynamic>;
        final items = (data['items'] ?? []) as List<dynamic>;

        // Persist raw JSON list so LocationSelectionScreen can read it offline
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_locations', jsonEncode(items));
        await prefs.setString('cached_locations_emp_id', empId);
        debugPrint('✅ [LOCATION CACHE] Cached ${items.length} location(s)');
      } else {
        debugPrint('⚠️ [LOCATION CACHE] Status ${response.statusCode} – cache unchanged');
      }
    } catch (e) {
      debugPrint('⚠️ [LOCATION CACHE] Failed to pre-fetch locations: $e (cached data will be used)');
    }
  }

  // Fetch and cache employee end time for a given emp_id + company_code
  // Called right after a successful login so it is available offline
  Future<void> fetchAndCacheEndTime(String empId, String companyCode) async {
    try {
      debugPrint('⏰ [END TIME CACHE] Fetching end time for emp=$empId  company=$companyCode');

      final response = await http.get(
        Uri.http(
          'oracle.metaxperts.net',
          '/ords/gps_workforce/endtime/get/',
          {
            'emp_id'      : empId,
            'company_code': companyCode,
          },
        ),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      debugPrint('📥 [END TIME CACHE] Status: ${response.statusCode}');
      debugPrint('📥 [END TIME CACHE] Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        String? endTimeStr;

        // Case 1: flat object  { "end_time": "17:30:00", ... }
        if (decoded is Map<String, dynamic>) {
          endTimeStr = _extractEndTimeFromMap(decoded);

          // Case 2: items array  { "items": [ { "end_time": "17:30:00" } ] }
          if (endTimeStr == null) {
            final items = decoded['items'];
            if (items is List && items.isNotEmpty) {
              final first = items.first;
              if (first is Map<String, dynamic>) {
                endTimeStr = _extractEndTimeFromMap(first);
              }
            }
          }
        }

        // Case 3: bare array  [ { "end_time": "17:30:00" } ]
        if (endTimeStr == null && decoded is List && decoded.isNotEmpty) {
          final first = decoded.first;
          if (first is Map<String, dynamic>) {
            endTimeStr = _extractEndTimeFromMap(first);
          }
        }

        if (endTimeStr != null && endTimeStr.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_end_time', endTimeStr);
          await prefs.setString('cached_end_time_emp_id', empId);
          debugPrint('✅ [END TIME CACHE] Cached end time: $endTimeStr');
        } else {
          debugPrint('⚠️ [END TIME CACHE] No end_time field found in response body');
        }
      } else {
        debugPrint('⚠️ [END TIME CACHE] Status ${response.statusCode} – cache unchanged');
      }
    } catch (e, stack) {
      debugPrint('⚠️ [END TIME CACHE] Failed: $e');
      debugPrint('⚠️ [END TIME CACHE] Stack: $stack');
    }
  }

  /// Extracts end-time string from a map, trying common field names.
  String? _extractEndTimeFromMap(Map<String, dynamic> map) {
    for (final key in ['end_time', 'endTime', 'end_hour', 'shift_end', 'time']) {
      final val = map[key];
      if (val != null && val.toString().isNotEmpty) return val.toString();
    }
    return null;
  }

  // Get user by emp_id only - no need to check company_code
  // because backend SQL already does: WHERE company_code = :company_code
  Future<LoginModels?> getUserByCredentials(String userId, String password) async {
    try {
      final apiData = await fetchLoginFromApi();

      int? userIdInt = int.tryParse(userId);

      for (var user in apiData) {
        bool idMatches = false;

        if (userIdInt != null) {
          idMatches = user.emp_id == userIdInt;
        } else {
          idMatches = user.emp_id.toString() == userId;
        }

        if (idMatches) {
          debugPrint('✅ User found: ${user.emp_name}, Role: ${user.job}');
          return user;
        }
      }

      debugPrint('❌ User not found with ID: $userId');
      return null;
    } catch (e) {
      debugPrint('❌ Error in getUserByCredentials: $e');
      return null;
    }
  }
}