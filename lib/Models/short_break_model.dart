// lib/Models/ShortBreakModels/short_break_model.dart

class ShortBreakModel {
  final String breakType;        // e.g. "Smoke Break" / "Tea Break"
  final int countLimit;          // e.g. 2
  final String shortBreakTime;   // "MM:SS" e.g. "15:00"
  int usedCount;                 // tracked locally per session

  ShortBreakModel({
    required this.breakType,
    required this.countLimit,
    required this.shortBreakTime,
    this.usedCount = 0,
  });

  // ── Parse API response (UPPERCASE keys from Oracle ORDS) ─────────────────
  factory ShortBreakModel.fromJson(Map<String, dynamic> json) {
    return ShortBreakModel(
      breakType: (json['BREAK_TYPE'] ?? json['break_type'] ?? '').toString().trim(),
      countLimit:
      int.tryParse((json['COUNT_LIMIT'] ?? json['count_limit'] ?? '0').toString()) ?? 0,
      shortBreakTime:
      (json['SHORT_BREAK_TIME'] ?? json['short_break_time'] ?? '15:00').toString().trim(),
    );
  }

  // ── Parse "MM:SS" → Duration ──────────────────────────────────────────────
  Duration get maxDuration {
    final parts = shortBreakTime.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]) ?? 15;
      final seconds = int.tryParse(parts[1]) ?? 0;
      return Duration(minutes: minutes, seconds: seconds);
    }
    return const Duration(minutes: 15);
  }

  // ── Display helpers ───────────────────────────────────────────────────────
  String get displayCount  => '$usedCount/$countLimit';
  bool   get canTakeBreak  => usedCount < countLimit;

  /// e.g. "15 min" or "10 min 30 sec"
  String get durationLabel {
    final d = maxDuration;
    if (d.inSeconds % 60 == 0) return '${d.inMinutes} min';
    return '${d.inMinutes} min ${d.inSeconds % 60} sec';
  }
}