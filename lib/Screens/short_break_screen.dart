// lib/Screens/short_break_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../AppColors.dart';

import '../Models/short_break_model.dart';
import '../ViewModels/short_break_viewmodel.dart';

class ShortBreakScreen extends StatelessWidget {
  const ShortBreakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Register VM if not already registered
    final vm = Get.put(ShortBreakViewModel());

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _ShortBreakHeader(),
          Expanded(
            child: Obx(() {
              if (vm.isOnShortBreak.value) {
                return _ActiveBreakView(vm: vm);
              }
              return _BreakSelectionView(vm: vm);
            }),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HEADER — gradient matching home screen
// ══════════════════════════════════════════════════════════════════════════════
class _ShortBreakHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.cyan,
            AppColors.cyanBright,
            AppColors.greenTeal,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            top: -40, right: -20,
            child: _decorCircle(160, AppColors.greenTeal, 0.12),
          ),
          Positioned(
            bottom: -30, left: -10,
            child: _decorCircle(100, Colors.white, 0.08),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Short Break',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          'Select and manage your break',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Break icon
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: const Icon(Icons.coffee_rounded,
                        color: Colors.white, size: 24),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorCircle(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// BREAK SELECTION VIEW — shown when not on break
// ══════════════════════════════════════════════════════════════════════════════
class _BreakSelectionView extends StatelessWidget {
  final ShortBreakViewModel vm;
  const _BreakSelectionView({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // ── Loading ─────────────────────────────────────────────────────────
      if (vm.isLoading.value) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.cyan, strokeWidth: 2.5),
              SizedBox(height: 16),
              Text('Loading break policy…',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        );
      }

      // ── Empty / disabled ─────────────────────────────────────────────────
      if (vm.breakPolicies.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.no_food_outlined,
                      size: 38, color: AppColors.textSecondary.withOpacity(0.45)),
                ),
                const SizedBox(height: 20),
                const Text(
                  'No Short Break Policy',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  vm.statusMessage.value.isNotEmpty
                      ? vm.statusMessage.value
                      : 'Short break is not enabled for your department. Contact your admin.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                _RefreshButton(vm: vm),
              ],
            ),
          ),
        );
      }

      // ── Break cards ──────────────────────────────────────────────────────
      return RefreshIndicator(
        color: AppColors.cyan,
        backgroundColor: AppColors.cardBg,
        onRefresh: vm.fetchBreakPolicy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 40),
          children: [
            // Status message
            if (vm.statusMessage.value.isNotEmpty) ...[
              _StatusBanner(message: vm.statusMessage.value, isSuccess: true),
              const SizedBox(height: 16),
            ],

            // Section label
            Row(children: [
              Container(
                width: 4, height: 20,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text('Available Breaks',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  )),
            ]),
            const SizedBox(height: 16),

            // Break type cards
            ...vm.breakPolicies.map((b) => _BreakCard(breakModel: b, vm: vm)),
          ],
        ),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BREAK CARD
// ══════════════════════════════════════════════════════════════════════════════
class _BreakCard extends StatelessWidget {
  final ShortBreakModel      breakModel;
  final ShortBreakViewModel  vm;
  const _BreakCard({required this.breakModel, required this.vm});

  @override
  Widget build(BuildContext context) {
    final exhausted = !breakModel.canTakeBreak;
    final color = exhausted
        ? AppColors.textSecondary
        : _colorForBreakType(breakModel.breakType);

    return Obx(() {
      final loading = vm.isEndingBreak.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GestureDetector(
          onTap: exhausted || loading
              ? null
              : () => _showConfirmDialog(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: exhausted
                  ? AppColors.cardBg.withOpacity(0.7)
                  : AppColors.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: exhausted
                    ? AppColors.divider
                    : color.withOpacity(0.3),
                width: exhausted ? 1 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: exhausted
                      ? Colors.black.withOpacity(0.03)
                      : color.withOpacity(0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon box
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    color: color.withOpacity(exhausted ? 0.05 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _iconForBreakType(breakModel.breakType),
                    size: 26,
                    color: color.withOpacity(exhausted ? 0.4 : 1.0),
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        breakModel.breakType,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: exhausted
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        _InfoChip(
                          icon: Icons.timer_outlined,
                          label: breakModel.durationLabel,
                          color: color,
                          dim: exhausted,
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.repeat_rounded,
                          label: breakModel.displayCount,
                          color: exhausted ? AppColors.error : color,
                          dim: exhausted,
                        ),
                      ]),
                    ],
                  ),
                ),

                // CTA
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: exhausted
                        ? AppColors.divider.withOpacity(0.5)
                        : color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: exhausted
                          ? AppColors.divider
                          : color.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    exhausted ? 'Limit\nReached' : 'Start',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: exhausted
                          ? AppColors.textSecondary.withOpacity(0.5)
                          : color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ── Confirm dialog ─────────────────────────────────────────────────────────
  void _showConfirmDialog(BuildContext context) {
    final color = _colorForBreakType(breakModel.breakType);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2235),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withOpacity(0.25), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.08),
                  ]),
                  border: Border.all(color: color.withOpacity(0.35), width: 1.5),
                ),
                child: Icon(_iconForBreakType(breakModel.breakType),
                    color: color, size: 30),
              ),
              const SizedBox(height: 18),

              // Title
              const Text(
                'Start Break?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),

              // Message
              Text(
                'Do you want to avail this break?\n'
                    '${breakModel.breakType} • ${breakModel.durationLabel}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 13.5,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 26),

              // Buttons
              Row(children: [
                // No
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.15)),
                        color: Colors.white.withOpacity(0.06),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'No',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Yes
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(ctx).pop();
                      vm.startBreak(breakModel);
                    },
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.75)]),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Yes, Start',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Color _colorForBreakType(String type) {
    final t = type.toLowerCase();
    if (t.contains('smoke')) return const Color(0xFFE07B39);
    if (t.contains('tea'))   return AppColors.greenTeal;
    return AppColors.cyan;
  }

  IconData _iconForBreakType(String type) {
    final t = type.toLowerCase();
    if (t.contains('smoke'))  return Icons.smoking_rooms_rounded;
    if (t.contains('tea'))    return Icons.emoji_food_beverage_rounded;
    return Icons.free_breakfast_rounded;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ACTIVE BREAK VIEW — shown while break is running
// ══════════════════════════════════════════════════════════════════════════════
class _ActiveBreakView extends StatelessWidget {
  final ShortBreakViewModel vm;
  const _ActiveBreakView({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isEnding = vm.isEndingBreak.value;

      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Break type pill ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.coffee_rounded,
                        size: 16, color: AppColors.cyan),
                    const SizedBox(width: 8),
                    Text(
                      vm.activeBreakType.value,
                      style: const TextStyle(
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Big countdown ring ──────────────────────────────────────
              _TimerRing(timerDisplay: vm.timerDisplay.value),
              const SizedBox(height: 10),

              Text(
                'Time remaining',
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Obx(() => Text(
                    'Elapsed: ${vm.elapsedDisplay.value}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  )),
                ],
              ),
              const SizedBox(height: 36),

              // ── Info card ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.warning.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.info_outline_rounded,
                          color: AppColors.warning, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Your break is active. Return within the allotted time. '
                            'A selfie will be required on return.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Status message ──────────────────────────────────────────
              if (vm.statusMessage.value.isNotEmpty) ...[
                _StatusBanner(message: vm.statusMessage.value),
                const SizedBox(height: 20),
              ],

              // ── End Break button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: isEnding
                        ? LinearGradient(colors: [
                      AppColors.textSecondary.withOpacity(0.3),
                      AppColors.textSecondary.withOpacity(0.2),
                    ])
                        : const LinearGradient(colors: [
                      Color(0xFFE05A5A),
                      Color(0xFFE0784E),
                    ]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isEnding
                        ? []
                        : [
                      BoxShadow(
                        color: const Color(0xFFE05A5A).withOpacity(0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: TextButton.icon(
                    onPressed: isEnding ? null : () => vm.endBreak(),
                    icon: isEnding
                        ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white70),
                    )
                        : const Icon(Icons.stop_circle_outlined,
                        color: Colors.white, size: 22),
                    label: Text(
                      isEnding ? 'Ending break…' : 'End Break & Take Selfie',
                      style: TextStyle(
                        color: isEnding ? Colors.white54 : Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Countdown ring widget ─────────────────────────────────────────────────────
class _TimerRing extends StatelessWidget {
  final String timerDisplay;
  const _TimerRing({required this.timerDisplay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180, height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          AppColors.cyan.withOpacity(0.08),
          Colors.transparent,
        ]),
        border: Border.all(color: AppColors.cyan.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withOpacity(0.2),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timerDisplay,
            style: const TextStyle(
              color: AppColors.cyan,
              fontSize: 42,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'MM : SS',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.5),
              fontSize: 11,
              letterSpacing: 3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small chips ───────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData  icon;
  final String    label;
  final Color     color;
  final bool      dim;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = dim ? color.withOpacity(0.4) : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c,
            )),
      ]),
    );
  }
}

// ── Status banner ─────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final String message;
  final bool   isSuccess;
  const _StatusBanner({required this.message, this.isSuccess = false});

  @override
  Widget build(BuildContext context) {
    final color = isSuccess ? AppColors.greenTeal : AppColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(
          isSuccess ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
          size: 18, color: color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              )),
        ),
      ]),
    );
  }
}

// ── Refresh button ────────────────────────────────────────────────────────────
class _RefreshButton extends StatelessWidget {
  final ShortBreakViewModel vm;
  const _RefreshButton({required this.vm});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: vm.fetchBreakPolicy,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Retry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}