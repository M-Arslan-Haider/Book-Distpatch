import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks battery % used during a shift (clock-in → clock-out).
/// Completely separate from battery_sync.dart — does NOT touch it.
class BatteryConsumptionService {
  static const String _keyClockInBattery = 'battery_level_clockin';
  static final Battery _battery = Battery();

  // ── Call at clock-in ──────────────────────────────────────────────────────
  /// Saves current battery % to SharedPreferences.
  static Future<void> saveClockInBattery() async {
    try {
      final level = await _battery.batteryLevel;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyClockInBattery, level);
      debugPrint('🔋 [BatteryConsumption] Clock-in battery saved: $level%');
    } catch (e) {
      debugPrint('⚠️ [BatteryConsumption] saveClockInBattery error: $e');
    }
  }

  // ── Call at clock-out ─────────────────────────────────────────────────────
  /// Returns battery % consumed during shift.
  /// Returns 0 if device was charging or data unavailable.
  static Future<int> getBatteryUsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clockInLevel = prefs.getInt(_keyClockInBattery);

      if (clockInLevel == null) {
        debugPrint('⚠️ [BatteryConsumption] No clock-in battery level found');
        return 0;
      }

      final currentLevel = await _battery.batteryLevel;
      final used = clockInLevel - currentLevel;

      debugPrint('🔋 [BatteryConsumption] '
          'Clock-in: $clockInLevel% | Now: $currentLevel% | Used: ${used < 0 ? 0 : used}%');

      // If device was charging during shift, used will be negative → return 0
      return used < 0 ? 0 : used;
    } catch (e) {
      debugPrint('⚠️ [BatteryConsumption] getBatteryUsed error: $e');
      return 0;
    }
  }

  // ── Call after clock-out ──────────────────────────────────────────────────
  /// Clears saved clock-in battery level.
  static Future<void> clearClockInBattery() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyClockInBattery);
      debugPrint('🧹 [BatteryConsumption] Clock-in battery level cleared');
    } catch (e) {
      debugPrint('⚠️ [BatteryConsumption] clearClockInBattery error: $e');
    }
  }
}