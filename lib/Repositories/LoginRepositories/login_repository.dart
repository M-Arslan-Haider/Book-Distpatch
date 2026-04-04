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
//         // ✅ Backend already filtered by company_code
//         // Sirf emp_id check kafi hai
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