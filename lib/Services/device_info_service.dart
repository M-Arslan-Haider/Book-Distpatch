import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
// system_info2 removed — RAM now comes from native via MethodChannel (ActivityManager)

class DeviceInfoService {
  static const String _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/';
  static const String _endpoint = 'deviceinfo/post/';
  static const String _lastSyncKey = 'flutter.device_info_last_sync';

  static const MethodChannel _storageChannel =
  MethodChannel('metaxperts/storage_info');

  // ─── Main Entry Point ───────────────────────────────────────────────────────
  static Future<void> syncDeviceInfoIfNeeded() async {
    try {
      // 1. Online check — offline ho to bilkul skip
      final isOnline = await _isOnline();
      if (!isOnline) {
        debugPrint('[DeviceInfo] Offline — skipping sync');
        return;
      }

      // 2. 7-day interval check
      final shouldSync = await _shouldSync();
      if (!shouldSync) {
        debugPrint('[DeviceInfo] 7-day interval nahi guzra — skipping');
        return;
      }

      // 3. POST karo
      await _postDeviceInfo();
    } catch (e) {
      debugPrint('[DeviceInfo] syncDeviceInfoIfNeeded error: $e');
    }
  }

  // ─── 7-Day Interval Check ───────────────────────────────────────────────────
  static Future<bool> _shouldSync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncStr = prefs.getString(_lastSyncKey);

    if (lastSyncStr == null) return true;

    final lastSync = DateTime.tryParse(lastSyncStr);
    if (lastSync == null) return true;

    final daysDiff = DateTime.now().difference(lastSync).inDays;
    return daysDiff >= 7;
  }

  // ─── Save Last Sync Timestamp ───────────────────────────────────────────────
  static Future<void> _saveLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  // ─── Online Check ───────────────────────────────────────────────────────────
  static Future<bool> _isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  // ─── Fetch Storage + RAM via MethodChannel (single native call) ─────────────
  // Storage: StorageStatsManager (API 26+) with StatFs fallback — no special perms needed
  // RAM:     ActivityManager.MemoryInfo.totalMem / availMem — always accurate device RAM
  static Future<Map<String, String>> _getHardwareInfo() async {
    try {
      final Map<dynamic, dynamic>? result =
      await _storageChannel.invokeMethod<Map>('getStorageInfo');
      if (result == null) throw Exception('null result');
      return {
        'total_storage_gb':
        (result['total_gb'] as double).toStringAsFixed(2),
        'free_storage_gb':
        (result['free_gb'] as double).toStringAsFixed(2),
        'used_storage_gb':
        (result['used_gb'] as double).toStringAsFixed(2),
        // RAM from ActivityManager — actual device RAM, not JVM heap
        'total_ram_gb':
        (result['total_ram_gb'] as double).toStringAsFixed(2),
        'free_ram_gb':
        (result['free_ram_gb'] as double).toStringAsFixed(2),
      };
    } catch (e) {
      debugPrint('[DeviceInfo] Hardware info fetch error: $e');
      return {
        'total_storage_gb': '0.00',
        'free_storage_gb': '0.00',
        'used_storage_gb': '0.00',
        'total_ram_gb': '0.00',
        'free_ram_gb': '0.00',
      };
    }
  }

  // ─── POST to Oracle ORDS ────────────────────────────────────────────────────
  static Future<void> _postDeviceInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final empId = prefs.getInt('emp_id')?.toString() ??
          prefs.getString('emp_id') ?? '';
      final empName = prefs.getString('emp_name') ?? '';
      final companyCode = prefs.getString('company_code') ?? '';

      if (empId.isEmpty) {
        debugPrint('[DeviceInfo] emp_id nahi mila — skipping POST');
        return;
      }

      // Single native call → storage + RAM dono accurate values
      final hardwareInfo = await _getHardwareInfo();
      final packageInfo = await PackageInfo.fromPlatform();

      final payload = {
        'emp_id': empId,
        'emp_name': empName,
        'company_code': companyCode,
        'app_version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
        'total_storage_gb': hardwareInfo['total_storage_gb'],
        'free_storage_gb': hardwareInfo['free_storage_gb'],
        'used_storage_gb': hardwareInfo['used_storage_gb'],
        'total_ram_gb': hardwareInfo['total_ram_gb'],
        'free_ram_gb': hardwareInfo['free_ram_gb'],
        'sync_datetime': DateTime.now().toIso8601String(),
      };

      debugPrint('[DeviceInfo] Posting: $payload');

      final response = await http
          .post(
        Uri.parse('$_baseUrl$_endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[DeviceInfo] ✅ POST success');
        await _saveLastSync();
      } else {
        debugPrint(
            '[DeviceInfo] ❌ POST failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('[DeviceInfo] _postDeviceInfo error: $e');
    }
  }
}
