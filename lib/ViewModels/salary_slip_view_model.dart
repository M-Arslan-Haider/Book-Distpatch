// // ════════════════════════════════════════════════════════════════════════════
// //  lib/ViewModels/salary_slip_view_model.dart
// // ════════════════════════════════════════════════════════════════════════════
//
// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../Models/salary_slip_model.dart';
//
// class SalarySlipViewModel extends GetxController {
//   // ── State ──────────────────────────────────────────────────────────────────
//   final RxList<SalarySlip> slips  = <SalarySlip>[].obs;
//   final RxBool  isLoading         = false.obs;
//   final RxString errorMessage     = ''.obs;
//   final RxString rawResponseDebug = ''.obs;
//   final RxString empId            = ''.obs;
//
//   static const String _baseUrl =
//       'http://oracle.metaxperts.net/ords/production/salaryslip/get';
//
//   // ── Lifecycle ──────────────────────────────────────────────────────────────
//   @override
//   void onInit() {
//     super.onInit();
//     _loadEmpId();
//   }
//
//   // ── Load employee ID from SharedPreferences ────────────────────────────────
//   Future<void> _loadEmpId() async {
//     final prefs = await SharedPreferences.getInstance();
//     empId.value = prefs.getString('userId') ?? '';
//
//     debugPrint('=== SalarySlipVM: empId = "${empId.value}"');
//
//     if (empId.value.isNotEmpty) {
//       fetchSalarySlips();
//     } else {
//       errorMessage.value =
//       'Employee ID not found in session.\nPlease log out and log in again.';
//     }
//   }
//
//   // ── Fetch ──────────────────────────────────────────────────────────────────
//   Future<void> fetchSalarySlips() async {
//     if (empId.value.isEmpty) {
//       errorMessage.value = 'Employee ID is empty. Please log in again.';
//       return;
//     }
//
//     try {
//       isLoading.value    = true;
//       errorMessage.value = '';
//       rawResponseDebug.value = '';
//
//       final uri = Uri.parse(_baseUrl).replace(
//         queryParameters: {'emp_id': empId.value},
//       );
//
//       debugPrint('=== SalarySlipVM: GET $uri');
//
//       final response = await http
//           .get(uri, headers: {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//       })
//           .timeout(const Duration(seconds: 30));
//
//       debugPrint('=== SalarySlipVM: status=${response.statusCode}');
//       debugPrint('=== SalarySlipVM: body=${response.body}');
//
//       // Store for on-screen debug display
//       rawResponseDebug.value =
//       'EmpID : ${empId.value}\n'
//           'URL   : $uri\n'
//           'Status: ${response.statusCode}\n'
//           'Body  :\n${response.body.length > 800 ? response.body.substring(0, 800) + "\n…(truncated)" : response.body}';
//
//       if (response.statusCode == 200) {
//         final decoded = json.decode(response.body);
//         List<dynamic> items = [];
//
//         if (decoded is List) {
//           // Bare JSON array
//           items = decoded;
//         } else if (decoded is Map<String, dynamic>) {
//           // Oracle ORDS can use various wrapper keys
//           items = decoded['items']   as List<dynamic>? ??
//               decoded['rows']    as List<dynamic>? ??
//               decoded['data']    as List<dynamic>? ??
//               decoded['results'] as List<dynamic>? ??
//               decoded['records'] as List<dynamic>? ??
//               [];
//
//           // Fallback: find any list value in the map
//           if (items.isEmpty) {
//             for (final val in decoded.values) {
//               if (val is List && val.isNotEmpty) {
//                 items = val;
//                 break;
//               }
//             }
//           }
//         }
//
//         debugPrint('=== SalarySlipVM: parsed ${items.length} records');
//
//         if (items.isEmpty) {
//           errorMessage.value =
//           'API responded OK but returned 0 records.\n\n'
//               'Full response:\n${response.body}';
//         } else {
//           slips.value = items
//               .map((e) => SalarySlip.fromJson(e as Map<String, dynamic>))
//               .toList();
//           slips.sort((a, b) => b.month.compareTo(a.month));
//         }
//       } else {
//         errorMessage.value =
//         'HTTP ${response.statusCode}\n${response.body}';
//       }
//     } on FormatException catch (e) {
//       errorMessage.value = 'JSON parse error:\n$e';
//     } catch (e) {
//       errorMessage.value = 'Error:\n$e';
//     } finally {
//       isLoading.value = false;
//     }
//   }
// }

// ════════════════════════════════════════════════════════════════════════════
//  lib/ViewModels/salary_slip_view_model.dart
// ════════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../Database/db_helper.dart';          // ← ADDED
import '../Models/salary_slip_model.dart';

class SalarySlipViewModel extends GetxController {
  // ── State ──────────────────────────────────────────────────────────────────
  final RxList<SalarySlip> slips  = <SalarySlip>[].obs;
  final RxBool  isLoading         = false.obs;
  final RxString errorMessage     = ''.obs;
  final RxString rawResponseDebug = ''.obs;
  final RxString empId            = ''.obs;

  static const String _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/salaryslip/get';

  // ── Lifecycle ──────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _loadEmpId();
  }

  // ── Load employee ID from SharedPreferences ────────────────────────────────
  Future<void> _loadEmpId() async {
    final prefs = await SharedPreferences.getInstance();
    empId.value = prefs.getString('userId') ?? '';

    debugPrint('=== SalarySlipVM: empId = "${empId.value}"');

    if (empId.value.isNotEmpty) {
      fetchSalarySlips();
    } else {
      errorMessage.value =
      'Employee ID not found in session.\nPlease log out and log in again.';
    }
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────
  Future<void> fetchSalarySlips() async {
    if (empId.value.isEmpty) {
      errorMessage.value = 'Employee ID is empty. Please log in again.';
      return;
    }

    try {
      isLoading.value    = true;
      errorMessage.value = '';
      rawResponseDebug.value = '';

      final companyCode = DBHelper.getCompanyCode();   // ← ADDED

      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'emp_id':       empId.value,
          'company_code': companyCode,                 // ← ADDED
        },
      );

      debugPrint('=== SalarySlipVM: GET $uri');

      final response = await http
          .get(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      })
          .timeout(const Duration(seconds: 30));

      debugPrint('=== SalarySlipVM: status=${response.statusCode}');
      debugPrint('=== SalarySlipVM: body=${response.body}');

      // Store for on-screen debug display
      rawResponseDebug.value =
      'EmpID       : ${empId.value}\n'
          'Company Code: $companyCode\n'           // ← ADDED
          'URL         : $uri\n'
          'Status      : ${response.statusCode}\n'
          'Body        :\n${response.body.length > 800 ? response.body.substring(0, 800) + "\n…(truncated)" : response.body}';

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        List<dynamic> items = [];

        if (decoded is List) {
          // Bare JSON array
          items = decoded;
        } else if (decoded is Map<String, dynamic>) {
          // Oracle ORDS can use various wrapper keys
          items = decoded['items']   as List<dynamic>? ??
              decoded['rows']    as List<dynamic>? ??
              decoded['data']    as List<dynamic>? ??
              decoded['results'] as List<dynamic>? ??
              decoded['records'] as List<dynamic>? ??
              [];

          // Fallback: find any list value in the map
          if (items.isEmpty) {
            for (final val in decoded.values) {
              if (val is List && val.isNotEmpty) {
                items = val;
                break;
              }
            }
          }
        }

        debugPrint('=== SalarySlipVM: parsed ${items.length} records');

        if (items.isEmpty) {
          errorMessage.value =
          'API responded OK but returned 0 records.\n\n'
              'Full response:\n${response.body}';
        } else {
          slips.value = items
              .map((e) => SalarySlip.fromJson(e as Map<String, dynamic>))
              .toList();
          slips.sort((a, b) => b.month.compareTo(a.month));
        }
      } else {
        errorMessage.value =
        'HTTP ${response.statusCode}\n${response.body}';
      }
    } on FormatException catch (e) {
      errorMessage.value = 'JSON parse error:\n$e';
    } catch (e) {
      errorMessage.value = 'Error:\n$e';
    } finally {
      isLoading.value = false;
    }
  }
}