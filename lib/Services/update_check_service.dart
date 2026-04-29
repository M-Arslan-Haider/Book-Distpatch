// Services/update_check_service.dart
//
// No Firebase. No backend.
// Directly Play Store se latest version fetch karta hai aur
// installed version se compare karta hai.
//
// DEPENDENCY REQUIRED (pubspec.yaml):
//   package_info_plus: ^6.0.0
//   http: ^1.2.0
//   url_launcher: ^6.2.0

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateCheckService {
  // ── ⚠️ Sirf yahan apna package name daalein ──────────────────────────────
  static const String _packageName = 'com.metaxperts.GPS_Workforce_Monitor';

  static String get playStoreUrl =>
      'https://play.google.com/store/apps/details?id=$_packageName';

  // ── Check if update is required ───────────────────────────────────────────
  /// Returns true  → Update popup dikhao
  /// Returns false → App already latest hai, popup mat dikhao
  static Future<bool> isUpdateRequired() async {
    try {
      // 1️⃣ Play Store se latest version fetch karo
      final storeVersion = await _fetchStoreVersion();
      if (storeVersion == null) return false;

      // 2️⃣ Installed version lao
      final packageInfo    = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      // 3️⃣ Compare karo
      return _isVersionOlder(current: currentVersion, minimum: storeVersion);
    } catch (_) {
      // Kabhi bhi error ki wajah se user block na ho
      return false;
    }
  }

  // ── Fetch latest version from Play Store page ─────────────────────────────
  static Future<String?> _fetchStoreVersion() async {
    try {
      final uri = Uri.parse(
          'https://play.google.com/store/apps/details?id=$_packageName&hl=en');

      final response = await http
          .get(uri, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      // Play Store HTML mein version is pattern mein hota hai
      final pattern = RegExp(r'\[\[\["(\d+\.\d+[\.\d]*)"\]\]\]');
      final match   = pattern.firstMatch(response.body);

      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  // ── Version comparison ────────────────────────────────────────────────────
  /// true  → current < minimum  (update chahiye)
  /// false → current >= minimum (sab theek hai)
  static bool _isVersionOlder({
    required String current,
    required String minimum,
  }) {
    final cur = _parse(current);
    final min = _parse(minimum);
    for (int i = 0; i < 3; i++) {
      if (cur[i] < min[i]) return true;
      if (cur[i] > min[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    while (parts.length < 3) parts.add(0);
    return parts.sublist(0, 3);
  }
}