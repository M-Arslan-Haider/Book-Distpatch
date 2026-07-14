// Services/update_check_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
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
}