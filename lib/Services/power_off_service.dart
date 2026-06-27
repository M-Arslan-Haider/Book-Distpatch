import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PowerOffService {
  static const String _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/';

  static const String _keyPowerOff     = 'pending_power_off';
  static const String _keyPowerOffTime = 'pending_power_off_time';

  /// App open hone par yeh call karo — main.dart mein
  /// Sirf tab post karta hai jab power off event pending ho
  static Future<void> checkAndPostPowerOffEvent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Kotlin side ki latest values lo

      final pendingJson = prefs.getString(_keyPowerOff);

      // Koi pending event nahi — kuch mat karo
      if (pendingJson == null || pendingJson.isEmpty) {
        debugPrint('[PowerOff] No pending power off event.');
        return;
      }

      debugPrint('[PowerOff] Pending event found: $pendingJson');

      // JSON parse karo
      final Map<String, dynamic> data = jsonDecode(pendingJson);

      // Server ko post karo
      final response = await http
          .post(
        Uri.parse('${_baseUrl}gpspoweroffevent/post/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[PowerOff] Posted successfully → HTTP ${response.statusCode}');

        // Successfully post hua — local clear karo
        await prefs.remove(_keyPowerOff);
        await prefs.remove(_keyPowerOffTime);

        debugPrint('[PowerOff] Local pending event cleared.');
      } else {
        // Server ne reject kiya — next open par try karega
        debugPrint('[PowerOff] Server error → HTTP ${response.statusCode}. Will retry next open.');
      }
    } catch (e) {
      // Network error — next open par try karega (local data safe hai)
      debugPrint('[PowerOff] checkAndPostPowerOffEvent error: $e');
    }
  }
}
  