// ══════════════════════════════════════════════════════════════════════════════
// request_summary_widget.dart  —  Combined Leave + Loan Summary
//
// Leave aur Loan counts jod ke ek hi row mein dikhata hai:
//   Pending  = leave.pending  + loan.pending
//   Approved = leave.approved + loan.approved
//   Rejected = leave.rejected + loan.rejected
//   Total    = leave.total    + loan.total
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../AppColors.dart';
import '../leave_report_get_screen.dart';
import '../loan_history_screen.dart';


class RequestSummaryWidget extends StatelessWidget {
  final String empName;
  final LeaveHistoryViewModel leaveVm;
  final List<LoanRecord> loanRecords;
  final bool loanLoading;

  const RequestSummaryWidget({
    super.key,
    required this.empName,
    required this.leaveVm,
    required this.loanRecords,
    this.loanLoading = false,
  });

  // ── Combined counts (leave + loan jod) ──────────────────────────────────
  int _combined(LeaveHistoryViewModel vm, String status) {
    final leaveCnt = vm.leaves
        .where((l) => l.status.trim().toLowerCase() == status)
        .length;
    final loanCnt = loanRecords
        .where((r) => r.status.trim().toLowerCase() == status)
        .length;
    return leaveCnt + loanCnt;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.cyan,
              AppColors.cyanBright,
              AppColors.greenTeal,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withOpacity(0.30),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // ── Decorative circles ───────────────────────────────────────
            Positioned(
              top: -30, right: -20,
              child: _circle(120, Colors.white, 0.07),
            ),
            Positioned(
              bottom: -20, left: -15,
              child: _circle(90, AppColors.greenTeal, 0.18),
            ),

            // ── Content ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Greeting row ────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.waving_hand_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, ${empName.split(' ').first}!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Manage your leave, half day, and loan/advance\nrequests here.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Combined stats row ───────────────────────────────
                  Obx(() {
                    final isLoading =
                        (leaveVm.isLoading.value && leaveVm.leaves.isEmpty) ||
                            (loanLoading && loanRecords.isEmpty);

                    if (isLoading) {
                      return SizedBox(
                        height: 70,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Colors.white.withOpacity(0.70),
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }

                    final pending  = _combined(leaveVm, 'pending');
                    final approved = _combined(leaveVm, 'approved');
                    final rejected = _combined(leaveVm, 'rejected');
                    final total    = leaveVm.totalLeaves + loanRecords.length;

                    return Row(
                      children: [
                        _StatBox(count: pending,  label: 'PENDING REQUESTS', color: const Color(0xFFFFD166)),
                        const SizedBox(width: 8),
                        _StatBox(count: approved, label: 'APPROVED',          color: const Color(0xFF4ADE80)),
                        const SizedBox(width: 8),
                        _StatBox(count: rejected, label: 'REJECTED',          color: const Color(0xFFFF6B6B)),
                        const SizedBox(width: 8),
                        _StatBox(count: total,    label: 'THIS MONTH',        color: Colors.white),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatBox — single count box
// ─────────────────────────────────────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatBox({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.70),
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
