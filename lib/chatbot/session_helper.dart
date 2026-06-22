// import 'package:flutter/cupertino.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../constants.dart';
//
// class SessionHelper {
//   static Future<String> getEmpId() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.reload(); // Same as in leave_view_model
//
//       debugPrint('🔑 [SessionHelper] ALL SharedPrefs keys:');
//       for (final key in prefs.getKeys()) {
//         debugPrint('   $key = ${prefs.get(key)}');
//       }
//
//       // Try all possible keys - same pattern as leave_view_model
//       String empId = prefs.getString('userId') ??
//           prefs.getString('user_id') ??
//           prefs.getString('emp_id') ??
//           prefs.getString('empId') ??
//           prefs.getString('employee_id') ??
//           prefs.getString('employeeId') ??
//           '';
//
//       // If not found as String, try to get as int and convert
//       if (empId.isEmpty) {
//         int? empIdInt = prefs.getInt('emp_id');
//         if (empIdInt != null) {
//           empId = empIdInt.toString();
//           // Save as string for future use
//           await prefs.setString('emp_id', empId);
//           debugPrint('✅ [SessionHelper] Converted emp_id from int to string: $empId');
//         }
//       }
//
//       debugPrint('👤 [SessionHelper] empId: "$empId"');
//       return empId;
//     } catch (e) {
//       debugPrint('❌ [SessionHelper] Error getting emp_id: $e');
//       return '';
//     }
//   }
//
//   static Future<String> getCompanyCode() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.reload();
//
//       String companyCode = prefs.getString('companyCode') ??
//           prefs.getString('company_code') ??
//           prefs.getString(prefCompanyCode) ??
//           '';
//
//       debugPrint('🏢 [SessionHelper] companyCode: "$companyCode"');
//       return companyCode;
//     } catch (e) {
//       debugPrint('❌ [SessionHelper] Error getting company code: $e');
//       return '';
//     }
//   }
//
//   static Future<String> getMonth() async {
//     final now = DateTime.now();
//     return "${now.year}-${now.month.toString().padLeft(2, '0')}";
//   }
// }


import 'package:shared_preferences/shared_preferences.dart';
import '../../constants.dart';

class SessionHelper {
  static Future<String> getEmpId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      print('🔑 [SessionHelper] ALL SharedPrefs keys:');
      for (final key in prefs.getKeys()) {
        print('   $key = ${prefs.get(key)}');
      }

      // Try all possible keys as String first
      String? empId = prefs.getString('userId') ??
          prefs.getString('user_id') ??
          prefs.getString('emp_id') ??
          prefs.getString('empId') ??
          prefs.getString('employee_id') ??
          prefs.getString('employeeId') ??
          '';

      if (empId.isNotEmpty) {
        print('✅ Emp ID found as String: $empId');
        return empId;
      }

      int? empIdInt = prefs.getInt('emp_id');
      if (empIdInt != null) {
        print('✅ Emp ID found as int: $empIdInt, converting to String');
        final empIdStr = empIdInt.toString();
        await prefs.setString('emp_id', empIdStr);
        return empIdStr;
      }

      int? userIdInt = prefs.getInt('userId');
      if (userIdInt != null) {
        print('✅ User ID found as int: $userIdInt, converting to String');
        final empIdStr = userIdInt.toString();
        await prefs.setString('emp_id', empIdStr);
        return empIdStr;
      }

      int? empIdInt2 = prefs.getInt('empId');
      if (empIdInt2 != null) {
        print('✅ empId found as int: $empIdInt2, converting to String');
        final empIdStr = empIdInt2.toString();
        await prefs.setString('emp_id', empIdStr);
        return empIdStr;
      }

      print('❌ Emp ID not found in SharedPreferences');
      return '';
    } catch (e, stackTrace) {
      print('❌ Error getting emp_id: $e');
      print('Stack trace: $stackTrace');
      return '';
    }
  }

  static Future<String> getCompanyCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      String? companyCode = prefs.getString('companyCode') ??
          prefs.getString('company_code') ??
          prefs.getString(prefCompanyCode) ??
          '';

      if (companyCode.isNotEmpty) {
        return companyCode;
      }

      int? companyCodeInt = prefs.getInt('companyCode');
      if (companyCodeInt != null) {
        final codeStr = companyCodeInt.toString();
        await prefs.setString('companyCode', codeStr);
        return codeStr;
      }

      return '';
    } catch (e) {
      print('❌ Error getting company code: $e');
      return '';
    }
  }

  static Future<String> getMonth() async {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  /// Extract month from user query - FIXED
  static String extractMonthFromQuery(String query) {
    final lower = query.toLowerCase().trim();
    print('🔍 extractMonthFromQuery: "$query"');

    // Month name to number mapping (English)
    final monthMap = {
      'january': '01', 'jan': '01',
      'february': '02', 'feb': '02',
      'march': '03', 'mar': '03',
      'april': '04', 'apr': '04',
      'may': '05',
      'june': '06', 'jun': '06',
      'july': '07', 'jul': '07',
      'august': '08', 'aug': '08',
      'september': '09', 'sep': '09',
      'october': '10', 'oct': '10',
      'november': '11', 'nov': '11',
      'december': '12', 'dec': '12',
    };

    // Urdu month names
    final urduMonthMap = {
      'جنوری': '01', 'فروری': '02', 'مارچ': '03', 'اپریل': '04',
      'مئی': '05', 'جون': '06', 'جولائی': '07', 'اگست': '08',
      'ستمبر': '09', 'اکتوبر': '10', 'نومبر': '11', 'دسمبر': '12',
    };

    // Check for year (4 digits)
    int? year;
    final yearMatch = RegExp(r'(19|20)\d{2}').firstMatch(lower);
    if (yearMatch != null) {
      year = int.tryParse(yearMatch.group(0)!);
      print('✅ Found year: $year');
    }

    // If no year found, use current year
    final now = DateTime.now();
    if (year == null) {
      year = now.year;
      print('📅 Using current year: $year');
    }

    // Check for month name in Urdu script (HIGHEST PRIORITY)
    for (var entry in urduMonthMap.entries) {
      if (lower.contains(entry.key)) {
        print('✅ Found Urdu month: ${entry.key} → ${entry.value}');
        return "$year-${entry.value}";
      }
    }

    // Check for English month names (full or short)
    // Also check for "april" in any context
    for (var entry in monthMap.entries) {
      if (lower.contains(entry.key)) {
        print('✅ Found English month: ${entry.key} → ${entry.value}');
        return "$year-${entry.value}";
      }
    }

    // Check for YYYY-MM format (like 2026-04)
    final dateMatch1 = RegExp(r'(19|20)\d{2}[-/](\d{1,2})').firstMatch(lower);
    if (dateMatch1 != null) {
      final y = dateMatch1.group(0)!.substring(0, 4);
      final m = dateMatch1.group(2)!.padLeft(2, '0');
      print('✅ Found YYYY-MM format: $y-$m');
      return "$y-$m";
    }

    // Check for MM-YYYY format (like 04-2026)
    final dateMatch2 = RegExp(r'(\d{1,2})[-/](19|20)\d{2}').firstMatch(lower);
    if (dateMatch2 != null) {
      final m = dateMatch2.group(1)!.padLeft(2, '0');
      final fullMatch = dateMatch2.group(0)!;
      final y = fullMatch.substring(fullMatch.length - 4);
      print('✅ Found MM-YYYY format: $y-$m');
      return "$y-$m";
    }

    // Default to current month
    final defaultMonth = "${now.year}-${now.month.toString().padLeft(2, '0')}";
    print('📅 Defaulting to current month: $defaultMonth');
    return defaultMonth;
  }
}