// Services/update_check_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:new_version_plus/new_version_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateCheckService {

  static const String _packageName = 'com.metaxperts.bookdispatch';

  // ✅ Home screen yeh use karta hai
  static String get playStoreUrl =>
      'https://play.google.com/store/apps/details?id=$_packageName';

  // ✅ Home screen yeh call karta hai
  static Future<bool> isUpdateRequired() async {
    if (!Platform.isAndroid) return false;

    try {
      final newVersion = NewVersionPlus(androidId: _packageName);
      final status = await newVersion.getVersionStatus();
      return status != null && status.canUpdate;
    } catch (e) {
      debugPrint("Version check failed: $e");
      return false;
    }
  }

  // ✅ "Update Now" button press hone par Oracle APEX ko log karta hai
  static Future<void> postUpdateAction({
    required String empId,
    required String empName,
    required String companyCode,
  }) async {
    try {
      final body = jsonEncode({
        'emp_id'        : empId,
        'emp_name'      : empName,
        'company_code'  : companyCode,
        'action_date'   : DateTime.now().toIso8601String(),
        'update_action' : 'YES',
      });

      final response = await http.post(
        Uri.parse('http://oracle.metaxperts.net/ords/gps_workforce/updateresult/post/'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 10));

      debugPrint('📦 [UPDATE] postUpdateAction status: ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ [UPDATE] postUpdateAction failed: $e');
    }
  }
}