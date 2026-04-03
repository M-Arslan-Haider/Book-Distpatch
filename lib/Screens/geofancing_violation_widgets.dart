// lib/Widgets/geofence_violation_report_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../AppColors.dart';
import '../Models/geofancing_violation_model.dart';
import '../ViewModels/geofancing_violation.dart';


class GeofenceViolationReportWidget extends StatefulWidget {
  const GeofenceViolationReportWidget({super.key});

  @override
  State<GeofenceViolationReportWidget> createState() =>
      _GeofenceViolationReportWidgetState();
}

class _GeofenceViolationReportWidgetState
    extends State<GeofenceViolationReportWidget> {
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = Get.find<GeofenceViolationViewModel>();

    return Obx(() {
      final violations = vm.violations;
      final is_outside = vm.isOutside.value;

      if (violations.isEmpty && !is_outside) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(violations.length, is_outside),
            const SizedBox(height: 8),

            if (is_outside) _buildLiveAlert(vm),

            if (violations.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...violations.reversed.map(
                    (v) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _buildViolationRow(v),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader(int count, bool is_outside) {
    return Row(
      children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(
            color: is_outside ? Colors.red.shade400 : Colors.orange.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: (is_outside ? Colors.red : Colors.orange).withOpacity(0.10),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(
            Icons.gpp_bad_rounded,
            size: 14,
            color: is_outside ? Colors.red.shade600 : Colors.orange.shade700,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Location Violations${count > 0 ? ' ($count)' : ''}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: is_outside ? Colors.red.shade700 : Colors.orange.shade800,
          ),
        ),
      ],
    );
  }

  // ── Live alert ─────────────────────────────────────────────────────────────
  Widget _buildLiveAlert(GeofenceViolationViewModel vm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color:        Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          _PulsingDot(color: Colors.red.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ User is currently OUTSIDE location',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Obx(() => Text(
                  'Outside for: ${vm.currentOutsideDuration}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                )),
              ],
            ),
          ),
          Icon(Icons.location_off_rounded,
              color: Colors.red.shade400, size: 16),
        ],
      ),
    );
  }

  // ── Violation row ──────────────────────────────────────────────────────────
  Widget _buildViolationRow(GeofenceViolation v) {
    final is_open = v.isStillOutside;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: is_open
            ? Colors.red.shade50
            : Colors.orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: is_open
              ? Colors.red.shade200
              : Colors.orange.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── out_time → in_time ─────────────────────────────────────────
          Row(
            children: [
              _TimeBadge(
                icon:  Icons.logout_rounded,
                label: 'Out',
                time:  v.outTimeLabel,
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded,
                  size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              is_open
                  ? _TimeBadge(
                icon:  Icons.radio_button_on_rounded,
                label: 'Back',
                time:  '—',
                color: Colors.grey,
              )
                  : _TimeBadge(
                icon:  Icons.login_rounded,
                label: 'Back',
                time:  v.inTimeLabel,
                color: Colors.green,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color:  is_open
                      ? Colors.red.shade100
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: is_open
                        ? Colors.red.shade300
                        : Colors.green.shade300,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  is_open ? 'Outside' : 'Returned',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: is_open
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── total_out_duration ────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 11,
                  color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                is_open
                    ? 'Duration: ${v.total_out_duration} (ongoing)'
                    : 'Outside for: ${v.total_out_duration}',
                style: TextStyle(
                  fontSize: 10,
                  color: is_open
                      ? Colors.red.shade600
                      : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _TimeBadge extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   time;
  final Color    color;

  const _TimeBadge({
    required this.icon,
    required this.label,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: color.withOpacity(0.7)),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 1),
        Text(time,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color == Colors.grey
                    ? Colors.grey.shade400
                    : color)),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
          shape: BoxShape.circle, color: widget.color),
    ),
  );
}