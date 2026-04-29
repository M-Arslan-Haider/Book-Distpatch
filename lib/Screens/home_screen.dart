import 'package:GPS_Workforce_Monitor/Screens/task_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:url_launcher/url_launcher.dart';            // ✅ NEW
import '../Services/update_check_service.dart';             // ✅ NEW
import '../Services/selfie_notification_policy_service.dart'; // ✅ Selfie grace button

import '../AppColors.dart';
import '../ViewModels/attendance_out_view_model.dart';
import '../ViewModels/attendance_view_model.dart';
import '../ViewModels/break_viewmodel.dart';
import '../ViewModels/location_view_model.dart';
import '../ViewModels/task_view_model.dart';
import 'WidgetDesignes/travel_session_card.dart';
import 'leave_report_get_screen.dart';
import 'my_task_activity_screen.dart';
import 'HomeScreenComponents/navbar.dart';
import 'HomeScreenComponents/profile_section.dart';
import 'HomeScreenComponents/sidebar_drawer.dart';
import 'HomeScreenComponents/timer_card.dart' hide LocationViewModel;
import 'leave_screen.dart';
import 'location_session_screen.dart';

// ── Responsive helper ────────────────────────────────────────────────────────
extension Responsive on BuildContext {
  double get screenW => MediaQuery.of(this).size.width;
  double get screenH => MediaQuery.of(this).size.height;

  // Scale factor: 1.0 at 390 px (iPhone 14 base)
  double get sf => (screenW / 390).clamp(0.78, 1.25);

  double rs(double base) => (base * sf).clamp(base * 0.78, base * 1.25);

  // Responsive padding
  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(rs(18), rs(22), rs(18), rs(40));

  // Breakpoints
  bool get isSmall  => screenW < 370;   // e.g. Galaxy A series, older iPhones
  bool get isMedium => screenW >= 370 && screenW < 410;
  bool get isLarge  => screenW >= 410;  // iPhone Plus / Pro Max, Galaxy S Ultra
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── ViewModels ─────────────────────────────────────────────────────────────
  final LocationViewModel locationVM          = Get.put(LocationViewModel());
  final AttendanceViewModel attendanceViewModel   = Get.put(AttendanceViewModel());
  final AttendanceOutViewModel attendanceOutViewModel = Get.put(AttendanceOutViewModel());
  final BreakViewModel breakViewModel         = Get.put(BreakViewModel());
  final TaskViewModel taskVM                  = Get.put(TaskViewModel());

  // ── State ──────────────────────────────────────────────────────────────────
  String _empName  = '';
  String _empId    = '';
  String _empRole  = '';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    // ✅ Register selfie grace service
    Get.put(SelfieNotificationPolicyService());

    _loadUserData();
    taskVM.fetchAssignedTasks();

    // ✅ NEW — Check for mandatory app update after screen renders
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());

    FlutterForegroundTask.startService(
      notificationTitle: 'Shift Active',
      notificationText: 'GPS & time tracking running…',
      callback: startCallback,
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!mounted) return;
    setState(() {
      _empName = prefs.getString('userName')   ?? 'Employee';
      _empId   = prefs.getString('userId')     ?? '--';
      _empRole = prefs.getString('designation') ?? 'Staff';
    });

    // ✅ FIX: Match same fallback logic as timer_card._initializeSelfieServiceAfterShiftEnd
    String empId = prefs.getString('emp_id') ?? '';
    if (empId.isEmpty) empId = _empId; // fallback to userId value
    final String companyCode = prefs.getString('company_code') ?? '';

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('🏠 [HOME] _loadUserData: empId="$empId"  companyCode="$companyCode"');
    debugPrint('🏠 [HOME] selfie service registered = ${Get.isRegistered<SelfieNotificationPolicyService>()}');

    if (empId.isNotEmpty && companyCode.isNotEmpty) {
      debugPrint('🏠 [HOME] Calling SelfieNotificationPolicyService.to.initialize...');
      SelfieNotificationPolicyService.to.initialize(empId, companyCode);
    } else {
      debugPrint('❌ [HOME] empId or companyCode empty — selfie service NOT initialized');
      debugPrint('❌ [HOME] empId="$empId"  companyCode="$companyCode"');
    }
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');
  }

  // ── ✅ NEW: Force Update Check ────────────────────────────────────────────
  Future<void> _checkForUpdate() async {
    final required = await UpdateCheckService.isUpdateRequired();
    if (required && mounted) _showForceUpdateDialog();
  }

  void _showForceUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,   // ← cannot dismiss by tapping outside
      builder: (ctx) => PopScope(
        canPop: false,             // ← back button bhi kaam nahi karega
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2235),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.cyan.withOpacity(0.30),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon ────────────────────────────────────────────
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.cyan.withOpacity(0.20),
                        AppColors.greenTeal.withOpacity(0.20),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.cyan.withOpacity(0.40),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.system_update_alt_rounded,
                    color: AppColors.cyan,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),

                // ── Title ────────────────────────────────────────────
                const Text(
                  'Update Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Message ──────────────────────────────────────────
                Text(
                  'A newer version of GPS Workforce Monitor is available. '
                      'Please update to continue using the app. This version is '
                      'no longer supported.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13.5,
                    height: 1.55,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Update Button ─────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.cyan, AppColors.greenTeal],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyan.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(UpdateCheckService.playStoreUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Update Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Footnote ──────────────────────────────────────────
                Text(
                  'You must update to continue.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.30),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // ─────────────────────────────────────────────────────────────────────────

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    final pad = context.pagePadding;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawer(),
        backgroundColor: AppColors.surface,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: pad,
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: context.rs(1)),
                    _buildUnifiedSessionCard(),
                    SizedBox(height: context.rs(14)),
                    // ✅ Selfie grace button — only visible during grace window
                    const SelfieGraceButton(),
                    SizedBox(height: context.rs(11)),
                    _buildQuickActions(),
                    SizedBox(height: context.rs(22)),
                    const LeaveActivityStrip(),
                    SizedBox(height: context.rs(22)),
                    _buildTaskActivityStrip(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UNIFIED SESSION CARD  (Timer + Travel)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildUnifiedSessionCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(context.rs(20)),
          border: Border.all(
            color: AppColors.cyan.withOpacity(0.18),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: context.rs(14),
              offset: Offset(0, context.rs(5)),
            ),
            BoxShadow(
              color: AppColors.cyan.withOpacity(0.07),
              blurRadius: context.rs(18),
              offset: Offset(0, context.rs(3)),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top accent line
            Container(
              height: 1,
              margin: EdgeInsets.symmetric(horizontal: context.rs(20)),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  AppColors.cyan.withOpacity(0.25),
                  Colors.transparent,
                ]),
              ),
            ),
            SizedBox(height: context.rs(8)),
            const TimerCard(),
            _buildDividerWithIcon(),
            const TravelSessionCard(),
            SizedBox(height: context.rs(10)),
          ],
        ),
      ),
    );
  }

  Widget _buildDividerWithIcon() {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: context.rs(20), vertical: context.rs(6)),
      child: Row(
        children: [
          Expanded(child: _gradientLine()),
          Container(
            margin: EdgeInsets.symmetric(horizontal: context.rs(8)),
            padding: EdgeInsets.all(context.rs(4)),
            decoration: BoxDecoration(
              color: AppColors.cyan.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.swap_vert_rounded,
              size: context.rs(10),
              color: AppColors.cyan.withOpacity(0.55),
            ),
          ),
          Expanded(child: _gradientLine()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildQuickActions() {
    // Tile height scales: 88 on small → 100 on large
    final tileH = context.isSmall ? 88.0 : context.isLarge ? 104.0 : 96.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              'Quick Actions', Icons.flash_on_rounded, AppColors.greenTeal),
          SizedBox(height: context.rs(12)),
          Row(
            children: [
              _actionTile(
                icon: Icons.calendar_month_rounded,
                label: 'Leave',
                color: AppColors.cyan,
                tileHeight: tileH,
                onTap: () => Get.to(() => LeaveScreen()),
              ),
              SizedBox(width: context.rs(12)),
              _actionTile(
                icon: Icons.task_alt_rounded,
                label: 'Tasks',
                color: AppColors.skyBlueDk,
                tileHeight: tileH,
                onTap: () => Get.to(
                      () => const TaskScreen(),
                  transition: Transition.rightToLeft,
                  duration: const Duration(milliseconds: 300),
                ),
              ),
              SizedBox(width: context.rs(12)),
              _breakTile(tileH),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required double tileHeight,
  }) {
    final iconBoxSize = context.rs(44);
    final iconSize    = context.rs(22);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: tileHeight,
          margin: EdgeInsets.symmetric(horizontal: context.rs(2)),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(context.rs(12)),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: context.rs(10),
                offset: Offset(0, context.rs(3)),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: iconBoxSize,
                height: iconBoxSize,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(context.rs(10)),
                ),
                child: Icon(icon, size: iconSize, color: color),
              ),
              SizedBox(height: context.rs(8)),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: context.rs(13),
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakTile(double tileHeight) {
    final iconBoxSize = context.rs(44);
    final iconSize    = context.rs(22);

    return Obx(() {
      final onBreak = breakViewModel.isOnBreak.value;
      final elapsed = breakViewModel.breakElapsed.value;

      return Expanded(
        child: GestureDetector(
          onTap: onBreak
              ? breakViewModel.endBreak
              : breakViewModel.startBreak,
          child: Container(
            height: tileHeight,
            margin: EdgeInsets.symmetric(horizontal: context.rs(2)),
            decoration: BoxDecoration(
              color: onBreak
                  ? AppColors.warning.withOpacity(0.05)
                  : AppColors.cardBg,
              borderRadius: BorderRadius.circular(context.rs(12)),
              border: Border.all(
                color: onBreak
                    ? AppColors.warning.withOpacity(0.3)
                    : AppColors.divider,
                width: onBreak ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: onBreak
                      ? AppColors.warning.withOpacity(0.15)
                      : Colors.black.withOpacity(0.04),
                  blurRadius: context.rs(10),
                  offset: Offset(0, context.rs(3)),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: onBreak
                        ? AppColors.warning.withOpacity(0.15)
                        : AppColors.cyan.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(context.rs(10)),
                  ),
                  child: Icon(
                    onBreak
                        ? Icons.stop_circle_outlined
                        : Icons.free_breakfast,
                    size: iconSize,
                    color: onBreak ? AppColors.warning : AppColors.cyan,
                  ),
                ),
                SizedBox(height: context.rs(8)),
                Text(
                  onBreak ? elapsed : 'Break',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.rs(onBreak ? 12 : 13),
                    fontWeight: FontWeight.w600,
                    color: onBreak ? AppColors.warning : AppColors.textPrimary,
                  ),
                ),
                if (onBreak) ...[
                  SizedBox(height: context.rs(2)),
                  Text(
                    'Tap to end',
                    style: TextStyle(
                      fontSize: context.rs(9),
                      color: AppColors.warning.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TASK ACTIVITY STRIP
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTaskActivityStrip() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
              'Task Overview', Icons.analytics_rounded, AppColors.cyan),
          SizedBox(height: context.rs(12)),
          Obx(() {
            final isLoading  = taskVM.isLoadingAssigned.value;
            final total      = taskVM.assignedTasks.length;
            final pending    = taskVM.assignedTasks.where((t) => t.status == 'Pending').length;
            final inProgress = taskVM.assignedTasks.where((t) => t.status == 'In Progress').length;
            final completed  = taskVM.assignedTasks.where((t) => t.status == 'Completed').length;
            final active     = pending + inProgress;

            return GestureDetector(
              onTap: () => Get.to(
                    () => const MyTasksActivityScreen(),
                transition: Transition.rightToLeft,
                duration: const Duration(milliseconds: 300),
              ),
              child: Container(
                padding: EdgeInsets.all(context.rs(16)),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.cardBg,
                      AppColors.cardBg.withOpacity(0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(context.rs(20)),
                  border: Border.all(
                    color: active > 0
                        ? AppColors.cyan.withOpacity(0.3)
                        : AppColors.divider,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: active > 0
                          ? AppColors.cyan.withOpacity(0.15)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: context.rs(16),
                      offset: Offset(0, context.rs(6)),
                    ),
                  ],
                ),
                child: isLoading
                    ? SizedBox(
                  height: context.rs(120),
                  child: const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.cyan, strokeWidth: 2.5),
                  ),
                )
                    : _taskCardContent(
                  total: total,
                  pending: pending,
                  inProgress: inProgress,
                  completed: completed,
                  active: active,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _taskCardContent({
    required int total,
    required int pending,
    required int inProgress,
    required int completed,
    required int active,
  }) {
    return Column(
      children: [
        // Header row
        Row(
          children: [
            Container(
              width: context.rs(46),
              height: context.rs(46),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(context.rs(14)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cyan.withOpacity(0.4),
                    blurRadius: context.rs(12),
                    offset: Offset(0, context.rs(4)),
                  ),
                ],
              ),
              child: Icon(Icons.assignment_turned_in_rounded,
                  color: Colors.white, size: context.rs(22)),
            ),
            SizedBox(width: context.rs(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task Summary',
                    style: TextStyle(
                      fontSize: context.rs(12),
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: context.rs(2)),
                  Text(
                    total == 0
                        ? 'No tasks assigned'
                        : '$active active • $completed completed',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: context.rs(14),
                      fontWeight: FontWeight.w700,
                      color: active > 0
                          ? AppColors.cyan
                          : AppColors.greenTeal,
                    ),
                  ),
                ],
              ),
            ),
            if (total > 0) ...[
              SizedBox(width: context.rs(8)),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: context.rs(10), vertical: context.rs(5)),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: AppColors.cyan.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.task_alt_rounded,
                        size: context.rs(13), color: AppColors.cyan),
                    SizedBox(width: context.rs(4)),
                    Text(
                      '$total total',
                      style: TextStyle(
                        fontSize: context.rs(11),
                        fontWeight: FontWeight.w600,
                        color: AppColors.cyan,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        if (total > 0) ...[
          SizedBox(height: context.rs(16)),
          // Progress indicators — use LayoutBuilder to avoid overflow
          LayoutBuilder(builder: (ctx, constraints) {
            final indicatorW =
                (constraints.maxWidth - context.rs(12) * 2) / 3;
            return Row(
              children: [
                SizedBox(
                  width: indicatorW,
                  child: _buildProgressIndicator(
                    label: 'Pending',
                    count: pending,
                    total: total,
                    color: AppColors.warning,
                    icon: Icons.hourglass_empty_rounded,
                  ),
                ),
                SizedBox(width: context.rs(12)),
                SizedBox(
                  width: indicatorW,
                  child: _buildProgressIndicator(
                    label: 'In Progress',
                    count: inProgress,
                    total: total,
                    color: AppColors.skyBlueDk,
                    icon: Icons.autorenew_rounded,
                  ),
                ),
                SizedBox(width: context.rs(12)),
                SizedBox(
                  width: indicatorW,
                  child: _buildProgressIndicator(
                    label: 'Completed',
                    count: completed,
                    total: total,
                    color: AppColors.greenTeal,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
              ],
            );
          }),
          SizedBox(height: context.rs(16)),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildActionButton(
                  label: 'View Details',
                  icon: Icons.arrow_forward_rounded,
                  color: AppColors.cyan,
                  onTap: () => Get.to(
                        () => const MyTasksActivityScreen(),
                    transition: Transition.rightToLeft,
                  ),
                ),
              ),
              SizedBox(width: context.rs(10)),
              Expanded(
                flex: 1,
                child: _buildActionButton(
                  label: 'Refresh',
                  icon: Icons.refresh_rounded,
                  color: AppColors.skyBlueDk,
                  onTap: taskVM.fetchAssignedTasks,
                  isCompact: true,
                ),
              ),
            ],
          ),
        ] else ...[
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: context.rs(16)),
              child: Column(
                children: [
                  Icon(
                    Icons.task_alt_rounded,
                    size: context.rs(38),
                    color: AppColors.textSecondary.withOpacity(0.3),
                  ),
                  SizedBox(height: context.rs(8)),
                  Text(
                    'No tasks assigned yet',
                    style: TextStyle(
                      fontSize: context.rs(13),
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: context.rs(12)),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: context.rs(16),
                        vertical: context.rs(8)),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Pull to refresh',
                      style: TextStyle(
                        fontSize: context.rs(12),
                        color: AppColors.cyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressIndicator({
    required String label,
    required int count,
    required int total,
    required Color color,
    required IconData icon,
  }) {
    final pct = total > 0 ? (count / total * 100).toInt() : 0;

    return Container(
      padding: EdgeInsets.all(context.rs(9)),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(context.rs(12)),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: context.rs(13), color: color),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: context.rs(11),
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: context.rs(5)),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: context.rs(10),
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: context.rs(3)),
          Text(
            '$count/$total',
            style: TextStyle(
              fontSize: context.rs(12),
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isCompact = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: context.rs(11),
          horizontal: context.rs(isCompact ? 8 : 12),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(context.rs(12)),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: context.rs(isCompact ? 15 : 17), color: color),
            if (!isCompact) ...[
              SizedBox(width: context.rs(6)),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.rs(12),
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
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
          bottomLeft:  Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
              top: -50,
              right: -30,
              child: _decorCircle(200, AppColors.greenTeal, 0.12)),
          Positioned(
              bottom: -40,
              left: -20,
              child: _decorCircle(140, Colors.white, 0.10)),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 4),
                const ProfileSection(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: context.rs(16), vertical: context.rs(10)),
      child: Row(
        children: [
          _headerIconBtn(
            Icons.menu_rounded,
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          SizedBox(width: context.rs(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GPS Workforce Monitor',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.rs(15),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'GPS Workforce Monitor System',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.60),
                    fontSize: context.rs(10),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          _headerIconBtn(
            Icons.sync_rounded,
            onTap: _doSync,
          ),
        ],
      ),
    );
  }

  Widget _headerIconBtn(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: context.rs(42),
        height: context.rs(42),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(context.rs(10)),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: context.rs(22)),
      ),
    );
  }

  Future<void> _doSync() async {
    Get.showSnackbar(GetSnackBar(
      message: 'Syncing data...',
      duration: const Duration(seconds: 2),
      backgroundColor: AppColors.cyan,
      icon: const Icon(Icons.sync, color: Colors.white),
      borderRadius: 10,
      margin: const EdgeInsets.all(12),
    ));
    await attendanceViewModel.syncUnposted();
    await attendanceOutViewModel.syncUnposted();
    Get.showSnackbar(const GetSnackBar(
      message: 'Data synced successfully',
      duration: Duration(seconds: 2),
      backgroundColor: AppColors.greenTeal,
      icon: Icon(Icons.check_circle_outline_rounded, color: Colors.white),
      borderRadius: 10,
      margin: EdgeInsets.all(12),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
        width: context.rs(4),
        height: context.rs(20),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      SizedBox(width: context.rs(8)),
      Container(
        width: context.rs(28),
        height: context.rs(28),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(context.rs(8)),
        ),
        child: Icon(icon, size: context.rs(14), color: color),
      ),
      SizedBox(width: context.rs(8)),
      Flexible(
        child: Text(
          title,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: context.rs(13),
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    ]);
  }

  Widget _gradientLine() => Container(
    height: 1,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        Colors.transparent,
        AppColors.divider,
        Colors.transparent,
      ]),
    ),
  );

  Widget _decorCircle(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );
}

// ── Foreground task ──────────────────────────────────────────────────────────
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {}
  @override
  Future<void> onDestroy(DateTime timestamp, bool restart) async {}
}