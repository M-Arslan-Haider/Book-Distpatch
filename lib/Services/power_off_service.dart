import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PowerOffService {
  static const String _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/';

  static const String _keyPowerOff      = 'pending_power_off';
  static const String _keyPowerOffTime  = 'pending_power_off_time';
  static const String _keyLastActive    = 'last_active_time';

  /// Har 60 second mein call karo — timer_card se
  static Future<void> saveLastActiveTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final time =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
          'T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      await prefs.setString(_keyLastActive, time);
      debugPrint('[PowerOff] last_active_time saved: $time');
    } catch (e) {
      debugPrint('[PowerOff] saveLastActiveTime error: $e');
    }
  }

  static Future<void> checkAndPostPowerOffEvent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final pendingJson = prefs.getString(_keyPowerOff);

      if (pendingJson == null || pendingJson.isEmpty) {
        debugPrint('[PowerOff] No pending power off event.');
        return;
      }

      debugPrint('[PowerOff] Pending event found: $pendingJson');

      final Map<String, dynamic> data = jsonDecode(pendingJson);

      // Exact power off time override
      final storedPowerOffTime = prefs.getString(_keyPowerOffTime);
      if (storedPowerOffTime != null && storedPowerOffTime.isNotEmpty) {
        data['event_time'] = storedPowerOffTime;
        debugPrint('[PowerOff] event_time set to stored time: $storedPowerOffTime');
      }

      final response = await http
          .post(
        Uri.parse('${_baseUrl}gpspoweroffevent/post/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[PowerOff] Posted successfully → HTTP ${response.statusCode}');
        await prefs.remove(_keyPowerOff);
        await prefs.remove(_keyPowerOffTime);
        await prefs.remove(_keyLastActive);
        debugPrint('[PowerOff] Local pending event cleared.');
      } else {
        debugPrint('[PowerOff] Server error → HTTP ${response.statusCode}. Will retry next open.');
      }
    } catch (e) {
      debugPrint('[PowerOff] checkAndPostPowerOffEvent error: $e');
    }
  }
}
