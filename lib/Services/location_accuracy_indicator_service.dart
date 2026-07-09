import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Shows live GPS accuracy while clocked in.
/// Returns [SizedBox.shrink] when not clocked in — zero overhead.
class LocationAccuracyIndicator extends StatefulWidget {
  final bool isClockedIn;

  const LocationAccuracyIndicator({
    super.key,
    required this.isClockedIn,
  });

  @override
  State<LocationAccuracyIndicator> createState() =>
      _LocationAccuracyIndicatorState();
}

class _LocationAccuracyIndicatorState extends State<LocationAccuracyIndicator>
    with SingleTickerProviderStateMixin {

  // ── State ───────────────────────────────────────────────────────────────────
  StreamSubscription<Position>? _positionSub;
  double? _accuracyMeters;
  bool _isAcquiring = true;
  bool _hasError    = false;

  // ── Pulse animation ─────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  // ── Design constants (matched to TimerCard theme) ────────────────────────────
  static const Color _bg          = Color(0xFF0A2B20);  // same as _timerBox
  static const Color _labelClr    = Color(0xFF7EC8B0);  // same as TimerCard
  static const Color _barInactive = Color(0xFF235C48);  // divider tone

  static const Color _clrExcellent = Color(0xFF4ADE80); // green
  static const Color _clrGood      = Color(0xFF86EFAC); // light green
  static const Color _clrFair      = Color(0xFFFBBF24); // amber
  static const Color _clrPoor      = Color(0xFFEF4444); // red
  static const Color _clrUnknown   = Color(0xFF7EC8B0); // muted teal

  // ══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    if (widget.isClockedIn) _startTracking();
  }

  @override
  void didUpdateWidget(covariant LocationAccuracyIndicator old) {
    super.didUpdateWidget(old);
    if (widget.isClockedIn && !old.isClockedIn) {
      _startTracking();
    } else if (!widget.isClockedIn && old.isClockedIn) {
      _stopTracking();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _stopTracking();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GPS STREAM
  // ══════════════════════════════════════════════════════════════════════════

  void _startTracking() {
    _positionSub?.cancel();
    if (mounted) {
      setState(() {
        _isAcquiring    = true;
        _hasError       = false;
        _accuracyMeters = null;
      });
    }

    try {
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy       : LocationAccuracy.high,
          distanceFilter : 0,   // Update on every GPS fix (accuracy changes too)
        ),
      ).listen(
            (Position pos) {
          if (!mounted) return;
          setState(() {
            _accuracyMeters = pos.accuracy;
            _isAcquiring    = false;
            _hasError       = false;
          });
        },
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _isAcquiring = false;
            _hasError    = true;
          });
        },
        cancelOnError: false,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isAcquiring = false;
          _hasError    = true;
        });
      }
    }
  }

  void _stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACCURACY LEVEL HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  _AccLevel get _level {
    final m = _accuracyMeters;
    if (m == null)  return _AccLevel.unknown;
    if (m <= 10)    return _AccLevel.excellent;
    if (m <= 25)    return _AccLevel.good;
    if (m <= 60)    return _AccLevel.fair;
    return           _AccLevel.poor;
  }

  Color _levelColor(_AccLevel l) {
    switch (l) {
      case _AccLevel.excellent: return _clrExcellent;
      case _AccLevel.good:      return _clrGood;
      case _AccLevel.fair:      return _clrFair;
      case _AccLevel.poor:      return _clrPoor;
      case _AccLevel.unknown:   return _clrUnknown;
    }
  }

  String _levelLabel(_AccLevel l) {
    switch (l) {
      case _AccLevel.excellent: return 'EXCELLENT';
      case _AccLevel.good:      return 'GOOD';
      case _AccLevel.fair:      return 'FAIR';
      case _AccLevel.poor:      return 'POOR';
      case _AccLevel.unknown:   return '';
    }
  }

  int _levelBars(_AccLevel l) {
    switch (l) {
      case _AccLevel.excellent: return 4;
      case _AccLevel.good:      return 3;
      case _AccLevel.fair:      return 2;
      case _AccLevel.poor:      return 1;
      case _AccLevel.unknown:   return 0;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (!widget.isClockedIn) return const SizedBox.shrink();

    final lvl  = _level;
    final clr  = _levelColor(lvl);
    final bars = _levelBars(lvl);
    final lbl  = _levelLabel(lvl);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: clr.withOpacity(0.22),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // ── Signal Bars ────────────────────────────────────────────────
          _SignalBars(activeBars: bars, activeColor: clr),

          const SizedBox(width: 10),

          // ── Label + Value ──────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [

                // "GPS ACCURACY" label row + optional spinner
                Row(
                  children: [
                    const Text(
                      'GPS ACCURACY',
                      style: TextStyle(
                        fontSize    : 8,
                        fontWeight  : FontWeight.w700,
                        color       : _labelClr,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (_isAcquiring) ...[
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 8, height: 8,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: clr,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 3),

                // Value row
                if (_hasError)
                  const Text(
                    'GPS unavailable',
                    style: TextStyle(
                      fontSize   : 11,
                      fontWeight : FontWeight.w600,
                      color      : Color(0xFFEF4444),
                    ),
                  )
                else if (_isAcquiring)
                  const Text(
                    'Acquiring signal…',
                    style: TextStyle(
                      fontSize   : 11,
                      fontWeight : FontWeight.w500,
                      color      : _labelClr,
                    ),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [

                      // Meter value
                      Text(
                        '±${_accuracyMeters!.toStringAsFixed(1)} m',
                        style: const TextStyle(
                          fontSize     : 14,
                          fontWeight   : FontWeight.w700,
                          color        : Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),

                      const SizedBox(width: 7),

                      // Quality badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: clr.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          lbl,
                          style: TextStyle(
                            fontSize     : 8,
                            fontWeight   : FontWeight.w700,
                            color        : clr,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ── Live Pulse Dot ─────────────────────────────────────────────
          if (!_isAcquiring && !_hasError)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: clr.withOpacity(_pulseAnim.value),
                  boxShadow: [
                    BoxShadow(
                      color     : clr.withOpacity(0.35 * _pulseAnim.value),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ENUM
// ══════════════════════════════════════════════════════════════════════════════

enum _AccLevel { excellent, good, fair, poor, unknown }

// ══════════════════════════════════════════════════════════════════════════════
// SIGNAL BARS WIDGET
// ══════════════════════════════════════════════════════════════════════════════

class _SignalBars extends StatelessWidget {
  final int   activeBars;   // 0–4
  final Color activeColor;

  const _SignalBars({
    required this.activeBars,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    // Heights: 6, 10, 14, 18 px — shortest on left, tallest on right
    const heights = [6.0, 10.0, 14.0, 18.0];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        final isActive = i < activeBars;
        return Padding(
          padding: EdgeInsets.only(right: i < 3 ? 2.5 : 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width : 4,
            height: heights[i],
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor
                  : const Color(0xFF235C48), // _barInactive
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        );
      }),
    );
  }
}
