

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../AppColors.dart';
import '../ViewModels/break_viewmodel.dart';
import '../ViewModels/short_break_viewmodel.dart';
import '../Models/short_break_model.dart';
import 'HomeScreenComponents/app_bottom_navbar.dart';
import 'HomeScreenComponents/navbar.dart';
import 'HomeScreenComponents/sidebar_drawer.dart';

// ── Break tab index in AppBottomNavBar._allTabs ───────────────────────────────
const int _kBreaksTabIndex = 5;

class BreaksScreen extends StatefulWidget {
  final int    currentIndex;
  final int    chatBadgeCount;
  final ValueChanged<int> onNavTap;

  const BreaksScreen({
    super.key,
    this.currentIndex    = _kBreaksTabIndex,
    this.chatBadgeCount  = 0,
    required this.onNavTap,
  });

  @override
  State<BreaksScreen> createState() => _BreaksScreenState();
}

class _BreaksScreenState extends State<BreaksScreen>
    with SingleTickerProviderStateMixin {

  late final TabController _tabController;
  late final BreakViewModel _breakVM;
  late final ShortBreakViewModel _shortBreakVM;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── User data ──────────────────────────────────────────────────────────────
  String _empName = 'Employee';
  String _empInitials = '??';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _breakVM = Get.put(BreakViewModel());
    _shortBreakVM = Get.put(ShortBreakViewModel());

    _loadUserData();

    // Fetch short break policies on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shortBreakVM.fetchBreakPolicy();
    });

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:           Colors.transparent,
      statusBarIconBrightness:  Brightness.light,
    ));
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('userName') ?? 'Employee';
    setState(() {
      _empName = name;
      _empInitials = _getInitials(name);
    });
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surface,
      // ── Top navbar (same as home) ──────────────────────────────────────
      appBar: Navbar(
        userName: _empName,
        userInitials: _empInitials,
        lastSync: 'Just now',
        scaffoldKey: _scaffoldKey,
      ),
      drawer: const AppDrawer(),
      // ── Body: tab bar view ──────────────────────────────────────────────
      body: Column(
        children: [
          // ── Tab Bar (in header area) ────────────────────────────────────
          _buildTabBar(),
          // ── Tab Bar View ─────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _LunchBreakTab(vm: _breakVM),
                _ShortBreaksTab(vm: _shortBreakVM),
              ],
            ),
          ),
        ],
      ),
      // ── Bottom navbar ────────────────────────────────────────────────────
      bottomNavigationBar: AppBottomNavBar(
        currentIndex:   widget.currentIndex,
        chatBadgeCount: widget.chatBadgeCount,
        onTap:          widget.onNavTap,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB BAR — same style as Breaks app bar but embedded
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider.withOpacity(0.4)),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.cyan.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.symmetric(
              horizontal: 2, vertical: 3),
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: MaterialStateProperty.all(Colors.transparent),
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Lunch Break'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.coffee_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Short Breaks'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// LUNCH BREAK TAB — full inline UI using BreakViewModel
// ══════════════════════════════════════════════════════════════════════════════
class _LunchBreakTab extends StatelessWidget {
  final BreakViewModel vm;
  const _LunchBreakTab({required this.vm});

  static const Color _tealLight = Color(0xFF3DAF93);
  static const Color _tealDark  = Color(0xFF1A6E59);

  // ── Calculate allowed duration from "12:00 PM - 3:00 PM" type string ──────
  String _calculateAllowedDuration(String scheduleInfo) {
    if (scheduleInfo == 'Loading...' ||
        scheduleInfo.contains('Error') ||
        scheduleInfo.contains('not found')) {
      return '-- : --';
    }

    try {
      final parts = scheduleInfo.split(RegExp(r'-|–|to'));
      if (parts.length != 2) return scheduleInfo;

      final start = _parseTime(parts[0].trim());
      final end   = _parseTime(parts[1].trim());
      if (start == null || end == null) return scheduleInfo;

      var startMinutes = start.hour * 60 + start.minute;
      var endMinutes   = end.hour * 60 + end.minute;
      if (endMinutes <= startMinutes) endMinutes += 24 * 60; // overnight safety

      final diff  = endMinutes - startMinutes;
      final hours = diff ~/ 60;
      final mins  = diff % 60;

      if (hours > 0 && mins > 0) return '$hours hr $mins min';
      if (hours > 0) return '$hours ${hours == 1 ? 'hour' : 'hours'}';
      return '$mins minutes';
    } catch (_) {
      return scheduleInfo;
    }
  }

  TimeOfDay? _parseTime(String raw) {
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$').firstMatch(cleaned);
    if (match == null) return null;

    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!;

    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;

    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isOnBreak     = vm.isOnBreak.value;
      final isLoading     = vm.isLoading.value;
      final scheduleInfo  = vm.scheduledBreakInfo.value;
      final breakElapsed  = vm.breakElapsed.value;
      final todayBreaks   = vm.todayBreaks;

      return RefreshIndicator(
        color: AppColors.cyan,
        backgroundColor: AppColors.cardBg,
        onRefresh: vm.fetchScheduledBreakTime,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            // ── Today's Break Summary card ─────────────────────────────
            _SummaryCard(
              isOnBreak:    isOnBreak,
              breakElapsed: breakElapsed,
              todayCount:   todayBreaks.length,
              totalMinutes: todayBreaks.fold(
                  0, (s, b) => s + (b.durationMinutes ?? 0)),
            ),
            const SizedBox(height: 16),

            // ── Schedule info card ─────────────────────────────────────
            _InfoCard(
              icon: Icons.info_outline_rounded,
              title: 'Use this when you go for your daily lunch break. '
                  'The app records break out and return time.',
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),

            // ── Allowed window row ─────────────────────────────────────
            // Row(children: [
            //   Expanded(
            //     child: _DetailTile(
            //       label: 'ALLOWED LUNCH WINDOW',
            //       value: scheduleInfo == 'Loading...' ||
            //           scheduleInfo.contains('Error') ||
            //           scheduleInfo.contains('not found')
            //           ? '-- : --'
            //           : scheduleInfo,
            //     ),
            //   ),
            //   const SizedBox(width: 12),
            //   const Expanded(
            //     child: _DetailTile(
            //       label: 'ALLOWED DURATION',
            //       value: '60 minutes',
            //       valueColor: AppColors.cyan,
            //     ),
            //   ),
            // ]),
            // ── Allowed window row ─────────────────────────────────────
            Row(children: [
              Expanded(
                child: _DetailTile(
                  label: 'ALLOWED LUNCH WINDOW',
                  value: scheduleInfo == 'Loading...' ||
                      scheduleInfo.contains('Error') ||
                      scheduleInfo.contains('not found')
                      ? '-- : --'
                      : scheduleInfo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailTile(
                  label: 'ALLOWED DURATION',
                  value: _calculateAllowedDuration(scheduleInfo),
                  valueColor: AppColors.cyan,
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // ── Timer display ──────────────────────────────────────────
            _LunchTimerCard(
              isOnBreak:    isOnBreak,
              breakElapsed: breakElapsed,
              activeBreak:  vm.activeBreak.value,
            ),
            const SizedBox(height: 16),

            // ── Break Out / Return row ─────────────────────────────────
            Row(children: [
              Expanded(
                child: _DetailTile(
                  label: 'BREAK OUT TIME',
                  value: vm.activeBreak.value?.startTime ??
                      (todayBreaks.isNotEmpty
                          ? todayBreaks.last.startTime
                          : '-- : --'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailTile(
                  label: 'RETURN FROM BREAK',
                  value: (vm.activeBreak.value?.endTime?.isNotEmpty == true)
                      ? vm.activeBreak.value!.endTime!
                      : (todayBreaks.isNotEmpty &&
                      todayBreaks.last.endTime != null &&
                      todayBreaks.last.endTime!.isNotEmpty)
                      ? todayBreaks.last.endTime!
                      : '-- : --',
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // ── Start / End buttons ────────────────────────────────────
            Row(children: [
              // Start Lunch Break
              Expanded(
                child: _ActionButton(
                  label:   'Start Lunch Break',
                  icon:    Icons.play_arrow_rounded,
                  enabled: !isOnBreak && !isLoading,
                  onTap:   () => vm.startBreak(),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3DAF93), Color(0xFF1A6E59)],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // End Lunch Break
              Expanded(
                child: _ActionButton(
                  label:   'End Lunch Break',
                  icon:    Icons.stop_rounded,
                  enabled: isOnBreak && !isLoading,
                  onTap:   () => vm.endBreak(),
                  gradient: isOnBreak
                      ? const LinearGradient(
                    colors: [Color(0xFFE05A5A), Color(0xFFE0784E)],
                  )
                      : LinearGradient(colors: [
                    AppColors.textSecondary.withOpacity(0.3),
                    AppColors.textSecondary.withOpacity(0.2),
                  ]),
                ),
              ),
            ]),

            if (isLoading) ...[
              const SizedBox(height: 20),
              const Center(
                child: CircularProgressIndicator(
                    color: AppColors.cyan, strokeWidth: 2.5),
              ),
            ],
          ],
        ),
      );
    });
  }
}

// ── Summary card ───────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final bool   isOnBreak;
  final String breakElapsed;
  final int    todayCount;
  final int    totalMinutes;

  const _SummaryCard({
    required this.isOnBreak,
    required this.breakElapsed,
    required this.todayCount,
    required this.totalMinutes,
  });

  static const Color _tealLight = Color(0xFF3DAF93);
  static const Color _tealDark  = Color(0xFF1A6E59);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_tealLight, _tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _tealDark.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.wb_sunny_rounded,
                color: Colors.white, size: 16),
            const SizedBox(width: 6),
            const Text(
              "Today's Break Summary",
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: _SummaryTile(
                label: 'LUNCH STATUS',
                value: isOnBreak ? 'On Break' : 'Not Started',
                valueColor: isOnBreak
                    ? const Color(0xFFFCD34D)
                    : Colors.white,
              ),
            ),
            Expanded(
              child: _SummaryTile(
                label: 'SHORT BREAK',
                value: 'Not Started',
                valueColor: Colors.white,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _SummaryTile(
                label: 'TOTAL BREAKS',
                value: '$todayCount',
                valueColor: Colors.white,
              ),
            ),
            Expanded(
              child: _SummaryTile(
                label: "TODAY'S TOTAL BREAK TIME",
                value: isOnBreak
                    ? breakElapsed
                    : '$totalMinutes min',
                valueColor: Colors.white,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color  valueColor;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.60),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ── Lunch timer card ─────────────────────────────────────────────────────────
class _LunchTimerCard extends StatelessWidget {
  final bool        isOnBreak;
  final String      breakElapsed;
  final dynamic     activeBreak;

  const _LunchTimerCard({
    required this.isOnBreak,
    required this.breakElapsed,
    required this.activeBreak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1321),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyan.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.cyan.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isOnBreak ? breakElapsed : '00:00:00',
            style: TextStyle(
              color: isOnBreak ? AppColors.cyan : Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              letterSpacing: 4,
            ),
          ),
          if (isOnBreak) ...[
            const SizedBox(height: 6),
            Text(
              'Break in progress',
              style: TextStyle(
                color: AppColors.cyan.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Detail tile ──────────────────────────────────────────────────────────────
class _DetailTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.65),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String   title;
  final Color    color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color.withOpacity(0.6)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: color.withOpacity(0.75),
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String        label;
  final IconData      icon;
  final bool          enabled;
  final VoidCallback? onTap;
  final Gradient      gradient;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(13),
            boxShadow: enabled
                ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color:      Colors.white,
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════════════════════
// SHORT BREAKS TAB — INLINE (no separate screen navigation)
// ══════════════════════════════════════════════════════════════════════════════
class _ShortBreaksTab extends StatelessWidget {
  final ShortBreakViewModel vm;
  const _ShortBreaksTab({required this.vm});

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

      // ── If currently on short break → show active view ────────────────
      if (vm.isOnShortBreak.value) {
        return _ActiveShortBreakView(vm: vm);
      }

      // ── Break cards ──────────────────────────────────────────────────────
      return RefreshIndicator(
        color: AppColors.cyan,
        backgroundColor: AppColors.cardBg,
        onRefresh: vm.fetchBreakPolicy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
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
            ...vm.breakPolicies.map((b) => _ShortBreakCard(
              breakModel: b,
              vm: vm,
            )),
          ],
        ),
      );
    });
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHORT BREAK CARD
// ══════════════════════════════════════════════════════════════════════════════
class _ShortBreakCard extends StatelessWidget {
  final ShortBreakModel      breakModel;
  final ShortBreakViewModel  vm;
  const _ShortBreakCard({required this.breakModel, required this.vm});

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
    if (t.contains('prayer')) return const Color(0xFF6C5B7B);
    return AppColors.cyan;
  }

  IconData _iconForBreakType(String type) {
    final t = type.toLowerCase();
    if (t.contains('smoke'))  return Icons.smoking_rooms_rounded;
    if (t.contains('tea'))    return Icons.emoji_food_beverage_rounded;
    if (t.contains('prayer')) return Icons.self_improvement_rounded;
    return Icons.free_breakfast_rounded;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ACTIVE SHORT BREAK VIEW — shown while break is running
// ══════════════════════════════════════════════════════════════════════════════
class _ActiveShortBreakView extends StatelessWidget {
  final ShortBreakViewModel vm;
  const _ActiveShortBreakView({required this.vm});

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
                  color: const Color(0xFFE07B39).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFE07B39).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.coffee_rounded,
                        size: 16, color: Color(0xFFE07B39)),
                    const SizedBox(width: 8),
                    Text(
                      vm.activeBreakType.value,
                      style: const TextStyle(
                        color: Color(0xFFE07B39),
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
              _ShortTimerRing(timerDisplay: vm.timerDisplay.value),
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
                        'Your short break is active. Return within the allotted time.',
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
                      isEnding ? 'Ending break…' : 'End Short Break',
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

// ── Short Timer Ring ─────────────────────────────────────────────────────────
class _ShortTimerRing extends StatelessWidget {
  final String timerDisplay;
  const _ShortTimerRing({required this.timerDisplay});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFE07B39);
    return Container(
      width: 180, height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          color.withOpacity(0.08),
          Colors.transparent,
        ]),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
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
              color: color,
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