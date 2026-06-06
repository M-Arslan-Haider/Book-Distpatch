// //
// // import 'package:GPS_Workforce_Monitor/Screens/sync_status_card_screen.dart';
// // import 'package:GPS_Workforce_Monitor/Screens/task_screen.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:get/get.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// // import 'package:url_launcher/url_launcher.dart';
// // import '../Services/interval_selfie_service.dart';
// // import '../Services/update_check_service.dart';
// // import '../Services/selfie_notification_policy_service.dart';
// // import '../Services/developer_options_check_service.dart';
// //
// // import '../AppColors.dart';
// // import '../ViewModels/attendance_out_view_model.dart';
// // import '../ViewModels/attendance_view_model.dart';
// // import '../ViewModels/break_viewmodel.dart';
// // import '../ViewModels/short_break_viewmodel.dart';
// // import '../ViewModels/location_view_model.dart';
// // import '../ViewModels/task_view_model.dart';
// // import 'HomeScreenComponents/app_bottom_navbar.dart';
// // import 'WidgetDesignes/travel_session_card.dart';
// // import 'leave_report_get_screen.dart';
// // import 'my_task_activity_screen.dart';
// // import 'HomeScreenComponents/navbar.dart';
// // import 'HomeScreenComponents/profile_section.dart';
// // import 'HomeScreenComponents/sidebar_drawer.dart';
// // import 'HomeScreenComponents/timer_card.dart' hide LocationViewModel;
// // import 'leave_screen.dart';
// // import 'location_session_screen.dart';
// // import 'short_break_screen.dart';
// //
// // // ── Responsive helper ────────────────────────────────────────────────────────
// // extension Responsive on BuildContext {
// //   double get screenW => MediaQuery.of(this).size.width;
// //   double get screenH => MediaQuery.of(this).size.height;
// //
// //   double get sf => (screenW / 390).clamp(0.78, 1.25);
// //
// //   double rs(double base) => (base * sf).clamp(base * 0.78, base * 1.25);
// //
// //   EdgeInsets get pagePadding => EdgeInsets.fromLTRB(rs(18), rs(12), rs(18), rs(20));
// //
// //   bool get isSmall  => screenW < 370;
// //   bool get isMedium => screenW >= 370 && screenW < 410;
// //   bool get isLarge  => screenW >= 410;
// // }
// //
// // class HomeScreen extends StatefulWidget {
// //   const HomeScreen({super.key});
// //
// //   @override
// //   State<HomeScreen> createState() => _HomeScreenState();
// // }
// //
// // class _HomeScreenState extends State<HomeScreen>
// //     with TickerProviderStateMixin, WidgetsBindingObserver {
// //   // ── ViewModels ─────────────────────────────────────────────────────────────
// //   final LocationViewModel locationVM              = Get.put(LocationViewModel());
// //   final AttendanceViewModel attendanceViewModel   = Get.put(AttendanceViewModel());
// //   final AttendanceOutViewModel attendanceOutViewModel = Get.put(AttendanceOutViewModel());
// //   final BreakViewModel breakViewModel             = Get.put(BreakViewModel());
// //   final ShortBreakViewModel shortBreakVM          = Get.put(ShortBreakViewModel());
// //   final TaskViewModel taskVM                      = Get.put(TaskViewModel());
// //
// //   // ── State ──────────────────────────────────────────────────────────────────
// //   String _empName  = '';
// //   String _empId    = '';
// //   String _empRole  = '';
// //   int _navIndex = 0;
// //
// //   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
// //
// //   late final AnimationController _fadeCtrl;
// //   late final Animation<double>   _fadeAnim;
// //
// //   // Last sync time for navbar
// //   String _lastSyncTime = 'Just now';
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _fadeCtrl = AnimationController(
// //         vsync: this, duration: const Duration(milliseconds: 500));
// //     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
// //     _fadeCtrl.forward();
// //
// //     WidgetsBinding.instance.addObserver(this);
// //
// //     Get.put(SelfieNotificationPolicyService());
// //     Get.put(IntervalSelfieService());
// //
// //     _loadUserData();
// //     taskVM.fetchAssignedTasks();
// //
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       _checkForUpdate();
// //       _checkDeveloperOptions();
// //     });
// //
// //     FlutterForegroundTask.startService(
// //       notificationTitle: 'Shift Active',
// //       notificationText: 'GPS & time tracking running…',
// //       callback: startCallback,
// //     );
// //   }
// //
// //   @override
// //   void dispose() {
// //     WidgetsBinding.instance.removeObserver(this);
// //     _fadeCtrl.dispose();
// //     super.dispose();
// //   }
// //
// //   @override
// //   void didChangeAppLifecycleState(AppLifecycleState state) {
// //     super.didChangeAppLifecycleState(state);
// //     if (state == AppLifecycleState.resumed) {
// //       debugPrint('🔄 [HOME] App resumed — re-checking developer options...');
// //       _checkDeveloperOptions();
// //     }
// //   }
// //
// //   Future<void> _loadUserData() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     await prefs.reload();
// //     if (!mounted) return;
// //     setState(() {
// //       _empName = prefs.getString('userName')    ?? 'Employee';
// //       _empId   = prefs.getString('userId')      ?? '--';
// //       _empRole = prefs.getString('designation') ?? 'Staff';
// //     });
// //
// //     String empId = prefs.getString('emp_id') ?? '';
// //     if (empId.isEmpty) empId = _empId;
// //     final String companyCode = prefs.getString('company_code') ?? '';
// //
// //     debugPrint('');
// //     debugPrint('══════════════════════════════════════════════════════');
// //     debugPrint('🏠 [HOME] _loadUserData: empId="$empId"  companyCode="$companyCode"');
// //
// //     if (empId.isNotEmpty && companyCode.isNotEmpty) {
// //       SelfieNotificationPolicyService.to.initialize(empId, companyCode);
// //       IntervalSelfieService.to.initialize(empId, companyCode);
// //     } else {
// //       debugPrint('❌ [HOME] empId or companyCode empty — selfie service NOT initialized');
// //     }
// //     debugPrint('══════════════════════════════════════════════════════');
// //     debugPrint('');
// //   }
// //
// //   // ── Force Update Check ────────────────────────────────────────────────────────
// //   Future<void> _checkForUpdate() async {
// //     final required = await UpdateCheckService.isUpdateRequired();
// //     if (required && mounted) _showForceUpdateDialog();
// //   }
// //
// //   void _showForceUpdateDialog() {
// //     showDialog(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (ctx) => PopScope(
// //         canPop: false,
// //         child: Dialog(
// //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
// //           elevation: 0,
// //           backgroundColor: Colors.transparent,
// //           child: Container(
// //             padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
// //             decoration: BoxDecoration(
// //               color: const Color(0xFF1A2235),
// //               borderRadius: BorderRadius.circular(20),
// //               border: Border.all(color: AppColors.cyan.withOpacity(0.30), width: 1),
// //               boxShadow: [BoxShadow(color: AppColors.cyan.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 8))],
// //             ),
// //             child: Column(
// //               mainAxisSize: MainAxisSize.min,
// //               children: [
// //                 Container(
// //                   width: 72, height: 72,
// //                   decoration: BoxDecoration(
// //                     shape: BoxShape.circle,
// //                     gradient: LinearGradient(colors: [AppColors.cyan.withOpacity(0.20), AppColors.greenTeal.withOpacity(0.20)]),
// //                     border: Border.all(color: AppColors.cyan.withOpacity(0.40), width: 1.5),
// //                   ),
// //                   child: const Icon(Icons.system_update_alt_rounded, color: AppColors.cyan, size: 36),
// //                 ),
// //                 const SizedBox(height: 20),
// //                 const Text('Update Required', textAlign: TextAlign.center,
// //                     style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
// //                 const SizedBox(height: 12),
// //                 Text('A newer version is available. Please update to continue.',
// //                     textAlign: TextAlign.center,
// //                     style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13.5, height: 1.55)),
// //                 const SizedBox(height: 28),
// //                 SizedBox(width: double.infinity, height: 50,
// //                   child: DecoratedBox(
// //                     decoration: BoxDecoration(
// //                       gradient: LinearGradient(colors: [AppColors.cyan, AppColors.greenTeal]),
// //                       borderRadius: BorderRadius.circular(12),
// //                       boxShadow: [BoxShadow(color: AppColors.cyan.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
// //                     ),
// //                     child: TextButton.icon(
// //                       onPressed: () async {
// //                         final uri = Uri.parse(UpdateCheckService.playStoreUrl);
// //                         if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
// //                       },
// //                       icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
// //                       label: const Text('Update Now', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Future<void> _checkDeveloperOptions() async {
// //     final result = await DeveloperOptionsCheckService.checkAndPost();
// //     if (result.isDeveloperOptionsEnabled && mounted) _showDeveloperOptionsDialog();
// //   }
// //
// //   void _showDeveloperOptionsDialog() {
// //     showDialog(
// //       context: context,
// //       barrierDismissible: false,
// //       builder: (ctx) => PopScope(
// //         canPop: false,
// //         child: Dialog(
// //           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
// //           elevation: 0,
// //           backgroundColor: Colors.transparent,
// //           child: Container(
// //             padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
// //             decoration: BoxDecoration(
// //               color: const Color(0xFF1A2235),
// //               borderRadius: BorderRadius.circular(20),
// //               border: Border.all(color: AppColors.primary.withOpacity(0.60), width: 1.5),
// //               boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 30, offset: const Offset(0, 8))],
// //             ),
// //             child: Column(
// //               mainAxisSize: MainAxisSize.min,
// //               children: [
// //                 Container(width: 72, height: 72,
// //                   decoration: const BoxDecoration(
// //                     shape: BoxShape.circle,
// //                     gradient: LinearGradient(colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal]),
// //                   ),
// //                   child: const Icon(Icons.developer_mode_rounded, color: Colors.white, size: 36),
// //                 ),
// //                 const SizedBox(height: 20),
// //                 const Text('Developer Options Enabled', textAlign: TextAlign.center,
// //                     style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
// //                 const SizedBox(height: 12),
// //                 Text('Developer Options are currently ON.\nPlease turn them OFF to use the app.',
// //                     textAlign: TextAlign.center,
// //                     style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 13.5, height: 1.6)),
// //                 const SizedBox(height: 28),
// //                 SizedBox(width: double.infinity, height: 50,
// //                   child: DecoratedBox(
// //                     decoration: BoxDecoration(
// //                       gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal]),
// //                       borderRadius: BorderRadius.circular(12),
// //                       boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
// //                     ),
// //                     child: TextButton.icon(
// //                       onPressed: () {
// //                         Navigator.of(ctx).pop();
// //                         const MethodChannel('com.metaxperts.GPS_Workforce_Monitor/location_monitor')
// //                             .invokeMethod('openDeveloperSettings').catchError((_) {});
// //                       },
// //                       icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
// //                       label: const Text('Open Settings', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Future<void> _doSync() async {
// //     setState(() {
// //       _lastSyncTime = 'Just now';
// //     });
// //
// //     Get.showSnackbar(GetSnackBar(
// //       message: 'Syncing data...',
// //       duration: const Duration(seconds: 2),
// //       backgroundColor: AppColors.cyan,
// //       icon: const Icon(Icons.sync, color: Colors.white),
// //       borderRadius: 10,
// //       margin: const EdgeInsets.all(12),
// //     ));
// //
// //     await attendanceViewModel.syncUnposted();
// //     await attendanceOutViewModel.syncUnposted();
// //
// //     setState(() {
// //       _lastSyncTime = DateTime.now().toString().substring(11, 16);
// //     });
// //
// //     Get.showSnackbar(const GetSnackBar(
// //       message: 'Data synced successfully',
// //       duration: Duration(seconds: 2),
// //       backgroundColor: AppColors.greenTeal,
// //       icon: Icon(Icons.check_circle_outline_rounded, color: Colors.white),
// //       borderRadius: 10,
// //       margin: EdgeInsets.all(12),
// //     ));
// //   }
// //
// //   // ══════════════════════════════════════════════════════════════════════════
// //   // MAIN BUILD - FIXED NAVBAR + PROFILE SECTION (NO SCROLL)
// //   // ══════════════════════════════════════════════════════════════════════════
// //   @override
// //   Widget build(BuildContext context) {
// //     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
// //       statusBarColor: Colors.transparent,
// //       statusBarIconBrightness: Brightness.light,
// //     ));
// //
// //     // Get user initials for navbar
// //     String initials = _empName.isNotEmpty ?
// //     _empName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join() : 'AK';
// //     if (initials.length < 2 && _empName.isNotEmpty) initials = _empName.substring(0, 1) + (_empName.length > 1 ? _empName.substring(1, 2) : 'K');
// //     if (initials.isEmpty) initials = 'AK';
// //
// //     return WillPopScope(
// //       onWillPop: () async => false,
// //       child: Scaffold(
// //         key: _scaffoldKey,
// //         drawer: const AppDrawer(),
// //         backgroundColor: AppColors.surface,
// //         // ─── FIXED NAVBAR + PROFILE SECTION AT TOP (NO SCROLL) ────────────────
// //         body: Column(
// //           children: [
// //             // ✅ Navbar - Fixed at top (does NOT scroll)
// //             Navbar(
// //               userName: _empName.isEmpty ? 'Ahmed Khan' : _empName,
// //               userInitials: initials,
// //               lastSync: _lastSyncTime,
// //               scaffoldKey: _scaffoldKey,
// //             ),
// //
// //             // ✅ Profile Section - Navbar ke neeche (Fixed, does NOT scroll)
// //             const ProfileSection(),
// //
// //             // ✅ Main Content - Scrollable area
// //             Expanded(
// //               child: FadeTransition(
// //                 opacity: _fadeAnim,
// //                 child: CustomScrollView(
// //                   physics: const BouncingScrollPhysics(),
// //                   slivers: [
// //                     SliverPadding(
// //                       padding: EdgeInsets.only(
// //                         left: context.rs(18),
// //                         right: context.rs(18),
// //                         top: context.rs(8),
// //                         bottom: context.rs(20),
// //                       ),
// //                       sliver: SliverList(
// //                         delegate: SliverChildListDelegate([
// //                           _buildUnifiedSessionCard(),
// //                           SizedBox(height: context.rs(14)),
// //                           const SelfieGraceButton(),
// //                           const IntervalSelfieButton(),
// //                           SizedBox(height: context.rs(11)),
// //                           _buildQuickActions(),
// //                           SizedBox(height: context.rs(22)),
// //                           Padding(
// //                             padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
// //                             child: SyncStatusCard(onSyncNow: _doSync),
// //                           ),
// //                           SizedBox(height: context.rs(30)),
// //                         ]),
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ),
// //           ],
// //         ),
// //         // Bottom Navigation Bar
// //         bottomNavigationBar: AppBottomNavBar(
// //           currentIndex: _navIndex,
// //           chatBadgeCount: 0,
// //           onTap: (i) => setState(() => _navIndex = i),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // ══════════════════════════════════════════════════════════════════════════
// //   // ALL EXISTING WIDGETS (unchanged from your original code)
// //   // ══════════════════════════════════════════════════════════════════════════
// //
// //   Widget _buildUnifiedSessionCard() {
// //     return Padding(
// //       padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
// //       child: Container(
// //         decoration: BoxDecoration(
// //           color: AppColors.cardBg,
// //           borderRadius: BorderRadius.circular(context.rs(20)),
// //           border: Border.all(color: AppColors.cyan.withOpacity(0.18), width: 1),
// //           boxShadow: [
// //             BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: context.rs(14), offset: Offset(0, context.rs(5))),
// //             BoxShadow(color: AppColors.cyan.withOpacity(0.07), blurRadius: context.rs(18), offset: Offset(0, context.rs(3))),
// //           ],
// //         ),
// //         child: Column(
// //           mainAxisSize: MainAxisSize.min,
// //           children: [
// //             Container(height: 1, margin: EdgeInsets.symmetric(horizontal: context.rs(20)),
// //               decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AppColors.cyan.withOpacity(0.25), Colors.transparent])),
// //             ),
// //             SizedBox(height: context.rs(8)),
// //             const TimerCard(),
// //             _buildDividerWithIcon(),
// //             const TravelSessionCard(),
// //             SizedBox(height: context.rs(10)),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget _buildDividerWithIcon() {
// //     return Padding(
// //       padding: EdgeInsets.symmetric(horizontal: context.rs(20), vertical: context.rs(6)),
// //       child: Row(
// //         children: [
// //           Expanded(child: _gradientLine()),
// //           Container(
// //             margin: EdgeInsets.symmetric(horizontal: context.rs(8)),
// //             padding: EdgeInsets.all(context.rs(4)),
// //             decoration: BoxDecoration(color: AppColors.cyan.withOpacity(0.08), shape: BoxShape.circle),
// //             child: Icon(Icons.swap_vert_rounded, size: context.rs(10), color: AppColors.cyan.withOpacity(0.55)),
// //           ),
// //           Expanded(child: _gradientLine()),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   Widget _buildQuickActions() {
// //     final tileH = context.isSmall ? 88.0 : context.isLarge ? 104.0 : 96.0;
// //
// //     return Padding(
// //       padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           _sectionHeader('Quick Actions', Icons.flash_on_rounded, AppColors.greenTeal),
// //           SizedBox(height: context.rs(12)),
// //           Row(
// //             children: [
// //               _actionTile(
// //                 icon: Icons.calendar_month_rounded,
// //                 label: 'Leave',
// //                 color: AppColors.cyan,
// //                 tileHeight: tileH,
// //                 onTap: () => Get.to(() => LeaveScreen()),
// //               ),
// //               SizedBox(width: context.rs(12)),
// //               _actionTile(
// //                 icon: Icons.task_alt_rounded,
// //                 label: 'Tasks',
// //                 color: AppColors.skyBlueDk,
// //                 tileHeight: tileH,
// //                 onTap: () => Get.to(() => const TaskScreen(), transition: Transition.rightToLeft, duration: const Duration(milliseconds: 300)),
// //               ),
// //             ],
// //           ),
// //           SizedBox(height: context.rs(12)),
// //           Row(
// //             children: [
// //               _breakTile(tileH),
// //               SizedBox(width: context.rs(12)),
// //               _shortBreakActionTile(tileH),
// //             ],
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   Widget _actionTile({
// //     required IconData icon,
// //     required String label,
// //     required Color color,
// //     required VoidCallback onTap,
// //     required double tileHeight,
// //   }) {
// //     final iconBoxSize = context.rs(44);
// //     final iconSize    = context.rs(22);
// //
// //     return Expanded(
// //       child: GestureDetector(
// //         onTap: onTap,
// //         child: Container(
// //           height: tileHeight,
// //           margin: EdgeInsets.symmetric(horizontal: context.rs(2)),
// //           decoration: BoxDecoration(
// //             color: AppColors.cardBg,
// //             borderRadius: BorderRadius.circular(context.rs(12)),
// //             border: Border.all(color: AppColors.divider),
// //             boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: context.rs(10), offset: Offset(0, context.rs(3)))],
// //           ),
// //           child: Column(
// //             mainAxisAlignment: MainAxisAlignment.center,
// //             children: [
// //               Container(
// //                 width: iconBoxSize, height: iconBoxSize,
// //                 decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(context.rs(10))),
// //                 child: Icon(icon, size: iconSize, color: color),
// //               ),
// //               SizedBox(height: context.rs(8)),
// //               Text(label, textAlign: TextAlign.center,
// //                   style: TextStyle(fontSize: context.rs(13), fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   Widget _breakTile(double tileHeight) {
// //     final iconBoxSize = context.rs(44);
// //     final iconSize    = context.rs(22);
// //
// //     return Obx(() {
// //       final onBreak = breakViewModel.isOnBreak.value;
// //       final elapsed = breakViewModel.breakElapsed.value;
// //
// //       return Expanded(
// //         child: GestureDetector(
// //           onTap: onBreak ? breakViewModel.endBreak : breakViewModel.startBreak,
// //           child: Container(
// //             height: tileHeight,
// //             margin: EdgeInsets.symmetric(horizontal: context.rs(2)),
// //             decoration: BoxDecoration(
// //               color: onBreak ? AppColors.warning.withOpacity(0.05) : AppColors.cardBg,
// //               borderRadius: BorderRadius.circular(context.rs(12)),
// //               border: Border.all(color: onBreak ? AppColors.warning.withOpacity(0.3) : AppColors.divider, width: onBreak ? 1.5 : 1),
// //               boxShadow: [BoxShadow(color: onBreak ? AppColors.warning.withOpacity(0.15) : Colors.black.withOpacity(0.04), blurRadius: context.rs(10), offset: Offset(0, context.rs(3)))],
// //             ),
// //             child: Column(
// //               mainAxisAlignment: MainAxisAlignment.center,
// //               children: [
// //                 Container(width: iconBoxSize, height: iconBoxSize,
// //                   decoration: BoxDecoration(color: onBreak ? AppColors.warning.withOpacity(0.15) : AppColors.cyan.withOpacity(0.10), borderRadius: BorderRadius.circular(context.rs(10))),
// //                   child: Icon(onBreak ? Icons.stop_circle_outlined : Icons.free_breakfast, size: iconSize, color: onBreak ? AppColors.warning : AppColors.cyan),
// //                 ),
// //                 SizedBox(height: context.rs(8)),
// //                 Text(onBreak ? elapsed : 'Break', textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
// //                     style: TextStyle(fontSize: context.rs(onBreak ? 12 : 13), fontWeight: FontWeight.w600, color: onBreak ? AppColors.warning : AppColors.textPrimary)),
// //                 if (onBreak) ...[
// //                   SizedBox(height: context.rs(2)),
// //                   Text('Tap to end', style: TextStyle(fontSize: context.rs(9), color: AppColors.warning.withOpacity(0.7), fontWeight: FontWeight.w500)),
// //                 ],
// //               ],
// //             ),
// //           ),
// //         ),
// //       );
// //     });
// //   }
// //
// //   Widget _shortBreakActionTile(double tileHeight) {
// //     final iconBoxSize = context.rs(44);
// //     final iconSize    = context.rs(22);
// //     const color       = Color(0xFFE07B39);
// //
// //     return Obx(() {
// //       final onBreak  = shortBreakVM.isOnShortBreak.value;
// //       final timerStr = shortBreakVM.timerDisplay.value;
// //
// //       return Expanded(
// //         child: GestureDetector(
// //           onTap: () {
// //             if (!attendanceViewModel.isClockedIn.value) {
// //               Get.snackbar('Not Clocked In', 'Please clock in first to use Short Break.',
// //                   snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4),
// //                   backgroundColor: const Color(0xFFE05A5A).withOpacity(0.93), colorText: Colors.white,
// //                   icon: const Icon(Icons.lock_clock_rounded, color: Colors.white));
// //               return;
// //             }
// //             Get.to(() => const ShortBreakScreen(), transition: Transition.rightToLeft, duration: const Duration(milliseconds: 300));
// //           },
// //           child: Container(
// //             height: tileHeight,
// //             margin: EdgeInsets.symmetric(horizontal: context.rs(2)),
// //             decoration: BoxDecoration(
// //               color: onBreak ? color.withOpacity(0.07) : AppColors.cardBg,
// //               borderRadius: BorderRadius.circular(context.rs(12)),
// //               border: Border.all(color: onBreak ? color.withOpacity(0.35) : AppColors.divider, width: onBreak ? 1.5 : 1),
// //               boxShadow: [BoxShadow(color: onBreak ? color.withOpacity(0.18) : Colors.black.withOpacity(0.04), blurRadius: context.rs(10), offset: Offset(0, context.rs(3)))],
// //             ),
// //             child: Column(
// //               mainAxisAlignment: MainAxisAlignment.center,
// //               children: [
// //                 Container(width: iconBoxSize, height: iconBoxSize,
// //                   decoration: BoxDecoration(color: onBreak ? color.withOpacity(0.18) : color.withOpacity(0.10), borderRadius: BorderRadius.circular(context.rs(10))),
// //                   child: Icon(onBreak ? Icons.coffee_rounded : Icons.free_breakfast_outlined, size: iconSize, color: color),
// //                 ),
// //                 SizedBox(height: context.rs(8)),
// //                 Text(onBreak ? (timerStr.isNotEmpty ? timerStr : 'Active') : 'Short Break', textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
// //                     style: TextStyle(fontSize: context.rs(onBreak && timerStr.isNotEmpty ? 12 : 13), fontWeight: FontWeight.w600, color: onBreak ? color : AppColors.textPrimary)),
// //                 if (onBreak) ...[
// //                   SizedBox(height: context.rs(2)),
// //                   Text('Tap to manage', style: TextStyle(fontSize: context.rs(9), color: color.withOpacity(0.7), fontWeight: FontWeight.w500)),
// //                 ],
// //               ],
// //             ),
// //           ),
// //         ),
// //       );
// //     });
// //   }
// //
// //   Widget _sectionHeader(String title, IconData icon, Color color) {
// //     return Row(children: [
// //       Container(width: context.rs(4), height: context.rs(20),
// //           decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(2))),
// //       SizedBox(width: context.rs(8)),
// //       Container(width: context.rs(28), height: context.rs(28),
// //           decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(context.rs(8))),
// //           child: Icon(icon, size: context.rs(14), color: color)),
// //       SizedBox(width: context.rs(8)),
// //       Flexible(child: Text(title, overflow: TextOverflow.ellipsis,
// //           style: TextStyle(color: AppColors.primary, fontSize: context.rs(13), fontWeight: FontWeight.w700, letterSpacing: 0.3))),
// //     ]);
// //   }
// //
// //   Widget _gradientLine() => Container(height: 1,
// //     decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AppColors.divider, Colors.transparent])),
// //   );
// // }
// //
// // // ── Foreground task ──────────────────────────────────────────────────────────
// // void startCallback() {
// //   FlutterForegroundTask.setTaskHandler(MyTaskHandler());
// // }
// //
// // class MyTaskHandler extends TaskHandler {
// //   @override
// //   Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
// //   @override
// //   Future<void> onRepeatEvent(DateTime timestamp) async {}
// //   @override
// //   Future<void> onDestroy(DateTime timestamp, bool restart) async {}
// // }
//
// import 'package:GPS_Workforce_Monitor/Screens/sync_status_card_screen.dart';
// import 'package:GPS_Workforce_Monitor/Screens/task_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../Services/interval_selfie_service.dart';
// import '../Services/update_check_service.dart';
// import '../Services/selfie_notification_policy_service.dart';
// import '../Services/developer_options_check_service.dart';
//
// import '../AppColors.dart';
// import '../ViewModels/attendance_out_view_model.dart';
// import '../ViewModels/attendance_view_model.dart';
// import '../ViewModels/break_viewmodel.dart';
// import '../ViewModels/short_break_viewmodel.dart';
// import '../ViewModels/location_view_model.dart';
// import '../ViewModels/task_view_model.dart';
// import 'HomeScreenComponents/app_bottom_navbar.dart';
// import 'WidgetDesignes/travel_session_card.dart';
// import 'leave_report_get_screen.dart';
// import 'my_task_activity_screen.dart';
// import 'HomeScreenComponents/navbar.dart';
// import 'HomeScreenComponents/profile_section.dart';
// import 'HomeScreenComponents/sidebar_drawer.dart';
// import 'HomeScreenComponents/timer_card.dart' hide LocationViewModel;
// import 'leave_screen.dart';
// import 'location_session_screen.dart';
// import 'short_break_screen.dart';
//
// // ── Responsive helper ────────────────────────────────────────────────────────
// extension Responsive on BuildContext {
//   double get screenW => MediaQuery.of(this).size.width;
//   double get screenH => MediaQuery.of(this).size.height;
//
//   double get sf => (screenW / 390).clamp(0.78, 1.25);
//
//   double rs(double base) => (base * sf).clamp(base * 0.78, base * 1.25);
//
//   EdgeInsets get pagePadding => EdgeInsets.fromLTRB(rs(18), rs(12), rs(18), rs(20));
//
//   bool get isSmall  => screenW < 370;
//   bool get isMedium => screenW >= 370 && screenW < 410;
//   bool get isLarge  => screenW >= 410;
// }
//
// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen>
//     with TickerProviderStateMixin, WidgetsBindingObserver {
//   // ── ViewModels ─────────────────────────────────────────────────────────────
//   final LocationViewModel locationVM              = Get.put(LocationViewModel());
//   final AttendanceViewModel attendanceViewModel   = Get.put(AttendanceViewModel());
//   final AttendanceOutViewModel attendanceOutViewModel = Get.put(AttendanceOutViewModel());
//   final BreakViewModel breakViewModel             = Get.put(BreakViewModel());
//   final ShortBreakViewModel shortBreakVM          = Get.put(ShortBreakViewModel());
//   final TaskViewModel taskVM                      = Get.put(TaskViewModel());
//
//   // ── State ──────────────────────────────────────────────────────────────────
//   String _empName  = '';
//   String _empId    = '';
//   String _empRole  = '';
//   int _navIndex = 0;
//
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   late final AnimationController _fadeCtrl;
//   late final Animation<double>   _fadeAnim;
//
//   // Last sync time for navbar
//   String _lastSyncTime = 'Just now';
//
//   @override
//   void initState() {
//     super.initState();
//     _fadeCtrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 500));
//     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
//     _fadeCtrl.forward();
//
//     WidgetsBinding.instance.addObserver(this);
//
//     Get.put(SelfieNotificationPolicyService());
//     Get.put(IntervalSelfieService());
//
//     _loadUserData();
//     taskVM.fetchAssignedTasks();
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _checkForUpdate();
//       _checkDeveloperOptions();
//     });
//
//     FlutterForegroundTask.startService(
//       notificationTitle: 'Shift Active',
//       notificationText: 'GPS & time tracking running…',
//       callback: startCallback,
//     );
//   }
//
//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     _fadeCtrl.dispose();
//     super.dispose();
//   }
//
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);
//     if (state == AppLifecycleState.resumed) {
//       debugPrint('🔄 [HOME] App resumed — re-checking developer options...');
//       _checkDeveloperOptions();
//     }
//   }
//
//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.reload();
//     if (!mounted) return;
//     setState(() {
//       _empName = prefs.getString('userName')    ?? 'Employee';
//       _empId   = prefs.getString('userId')      ?? '--';
//       _empRole = prefs.getString('designation') ?? 'Staff';
//     });
//
//     String empId = prefs.getString('emp_id') ?? '';
//     if (empId.isEmpty) empId = _empId;
//     final String companyCode = prefs.getString('company_code') ?? '';
//
//     debugPrint('');
//     debugPrint('══════════════════════════════════════════════════════');
//     debugPrint('🏠 [HOME] _loadUserData: empId="$empId"  companyCode="$companyCode"');
//
//     if (empId.isNotEmpty && companyCode.isNotEmpty) {
//       SelfieNotificationPolicyService.to.initialize(empId, companyCode);
//       IntervalSelfieService.to.initialize(empId, companyCode);
//     } else {
//       debugPrint('❌ [HOME] empId or companyCode empty — selfie service NOT initialized');
//     }
//     debugPrint('══════════════════════════════════════════════════════');
//     debugPrint('');
//   }
//
//   // ── Force Update Check ────────────────────────────────────────────────────────
//   Future<void> _checkForUpdate() async {
//     final required = await UpdateCheckService.isUpdateRequired();
//     if (required && mounted) _showForceUpdateDialog();
//   }
//
//   void _showForceUpdateDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) => PopScope(
//         canPop: false,
//         child: Dialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           elevation: 0,
//           backgroundColor: Colors.transparent,
//           child: Container(
//             padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
//             decoration: BoxDecoration(
//               color: const Color(0xFF1A2235),
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(color: AppColors.cyan.withOpacity(0.30), width: 1),
//               boxShadow: [BoxShadow(color: AppColors.cyan.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 8))],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Container(
//                   width: 72, height: 72,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: LinearGradient(colors: [AppColors.cyan.withOpacity(0.20), AppColors.greenTeal.withOpacity(0.20)]),
//                     border: Border.all(color: AppColors.cyan.withOpacity(0.40), width: 1.5),
//                   ),
//                   child: const Icon(Icons.system_update_alt_rounded, color: AppColors.cyan, size: 36),
//                 ),
//                 const SizedBox(height: 20),
//                 const Text('Update Required', textAlign: TextAlign.center,
//                     style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
//                 const SizedBox(height: 12),
//                 Text('A newer version is available. Please update to continue.',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13.5, height: 1.55)),
//                 const SizedBox(height: 28),
//                 SizedBox(width: double.infinity, height: 50,
//                   child: DecoratedBox(
//                     decoration: BoxDecoration(
//                       gradient: LinearGradient(colors: [AppColors.cyan, AppColors.greenTeal]),
//                       borderRadius: BorderRadius.circular(12),
//                       boxShadow: [BoxShadow(color: AppColors.cyan.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
//                     ),
//                     child: TextButton.icon(
//                       onPressed: () async {
//                         final uri = Uri.parse(UpdateCheckService.playStoreUrl);
//                         if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
//                       },
//                       icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
//                       label: const Text('Update Now', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Future<void> _checkDeveloperOptions() async {
//     final result = await DeveloperOptionsCheckService.checkAndPost();
//     if (result.isDeveloperOptionsEnabled && mounted) _showDeveloperOptionsDialog();
//   }
//
//   void _showDeveloperOptionsDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) => PopScope(
//         canPop: false,
//         child: Dialog(
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//           elevation: 0,
//           backgroundColor: Colors.transparent,
//           child: Container(
//             padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
//             decoration: BoxDecoration(
//               color: const Color(0xFF1A2235),
//               borderRadius: BorderRadius.circular(20),
//               border: Border.all(color: AppColors.primary.withOpacity(0.60), width: 1.5),
//               boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 30, offset: const Offset(0, 8))],
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Container(width: 72, height: 72,
//                   decoration: const BoxDecoration(
//                     shape: BoxShape.circle,
//                     gradient: LinearGradient(colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal]),
//                   ),
//                   child: const Icon(Icons.developer_mode_rounded, color: Colors.white, size: 36),
//                 ),
//                 const SizedBox(height: 20),
//                 const Text('Developer Options Enabled', textAlign: TextAlign.center,
//                     style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
//                 const SizedBox(height: 12),
//                 Text('Developer Options are currently ON.\nPlease turn them OFF to use the app.',
//                     textAlign: TextAlign.center,
//                     style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 13.5, height: 1.6)),
//                 const SizedBox(height: 28),
//                 SizedBox(width: double.infinity, height: 50,
//                   child: DecoratedBox(
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal]),
//                       borderRadius: BorderRadius.circular(12),
//                       boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
//                     ),
//                     child: TextButton.icon(
//                       onPressed: () {
//                         Navigator.of(ctx).pop();
//                         const MethodChannel('com.metaxperts.GPS_Workforce_Monitor/location_monitor')
//                             .invokeMethod('openDeveloperSettings').catchError((_) {});
//                       },
//                       icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
//                       label: const Text('Open Settings', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Future<void> _doSync() async {
//     setState(() {
//       _lastSyncTime = 'Just now';
//     });
//
//     Get.showSnackbar(GetSnackBar(
//       message: 'Syncing data...',
//       duration: const Duration(seconds: 2),
//       backgroundColor: AppColors.cyan,
//       icon: const Icon(Icons.sync, color: Colors.white),
//       borderRadius: 10,
//       margin: const EdgeInsets.all(12),
//     ));
//
//     await attendanceViewModel.syncUnposted();
//     await attendanceOutViewModel.syncUnposted();
//
//     setState(() {
//       _lastSyncTime = DateTime.now().toString().substring(11, 16);
//     });
//
//     Get.showSnackbar(const GetSnackBar(
//       message: 'Data synced successfully',
//       duration: Duration(seconds: 2),
//       backgroundColor: AppColors.greenTeal,
//       icon: Icon(Icons.check_circle_outline_rounded, color: Colors.white),
//       borderRadius: 10,
//       margin: EdgeInsets.all(12),
//     ));
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // MAIN BUILD - FIXED NAVBAR + PROFILE SECTION (NO SCROLL)
//   // ══════════════════════════════════════════════════════════════════════════
//   @override
//   Widget build(BuildContext context) {
//     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//     ));
//
//     // Get user initials for navbar
//     String initials = _empName.isNotEmpty ?
//     _empName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join() : 'AK';
//     if (initials.length < 2 && _empName.isNotEmpty) initials = _empName.substring(0, 1) + (_empName.length > 1 ? _empName.substring(1, 2) : 'K');
//     if (initials.isEmpty) initials = 'AK';
//
//     return WillPopScope(
//       onWillPop: () async => false,
//       child: Scaffold(
//         key: _scaffoldKey,
//         drawer: const AppDrawer(),
//         backgroundColor: AppColors.surface,
//         body: Column(
//           children: [
//             // ✅ Navbar - FIXED at top (scroll nahi hoga kabhi)
//             Navbar(
//               userName: _empName.isEmpty ? 'Ahmed Khan' : _empName,
//               userInitials: initials,
//               lastSync: _lastSyncTime,
//               scaffoldKey: _scaffoldKey,
//             ),
//
//             // ✅ Baaki sab SCROLLABLE
//             Expanded(
//               child: FadeTransition(
//                 opacity: _fadeAnim,
//                 child: CustomScrollView(
//                   physics: const BouncingScrollPhysics(),
//                   slivers: [
//
//                     // ✅ ProfileSection - scroll ke saath move karegi
//                     const SliverToBoxAdapter(
//                       child: ProfileSection(),
//                     ),
//
//                     // ✅ Main Content
//                     SliverPadding(
//                       padding: EdgeInsets.only(
//                         left: context.rs(18),
//                         right: context.rs(18),
//                         top: context.rs(8),
//                         bottom: context.rs(20),
//                       ),
//                       sliver: SliverList(
//                         delegate: SliverChildListDelegate([
//                           _buildUnifiedSessionCard(),
//                           SizedBox(height: context.rs(14)),
//                           const SelfieGraceButton(),
//                           const IntervalSelfieButton(),
//                           SizedBox(height: context.rs(11)),
//                           _buildQuickActions(),
//                           SizedBox(height: context.rs(22)),
//                           Padding(
//                             padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
//                             child: SyncStatusCard(onSyncNow: _doSync),
//                           ),
//                           SizedBox(height: context.rs(30)),
//                         ]),
//                       ),
//                     ),
//
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//
//         // ✅ Bottom Navigation Bar
//         bottomNavigationBar: AppBottomNavBar(
//           currentIndex: _navIndex,
//           chatBadgeCount: 0,
//           onTap: (i) => setState(() => _navIndex = i),
//         ),
//       ),
//     );
//   }
//   // ══════════════════════════════════════════════════════════════════════════
//   // ALL EXISTING WIDGETS (unchanged from your original code)
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Widget _buildUnifiedSessionCard() {
//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // TimerCard is now a self-contained dark green card
//           const TimerCard(),
//           SizedBox(height: context.rs(12)),
//           // TravelSessionCard sits cleanly below
//           const TravelSessionCard(),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDividerWithIcon() {
//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: context.rs(20), vertical: context.rs(6)),
//       child: Row(
//         children: [
//           Expanded(child: _gradientLine()),
//           Container(
//             margin: EdgeInsets.symmetric(horizontal: context.rs(8)),
//             padding: EdgeInsets.all(context.rs(4)),
//             decoration: BoxDecoration(color: AppColors.cyan.withOpacity(0.08), shape: BoxShape.circle),
//             child: Icon(Icons.swap_vert_rounded, size: context.rs(10), color: AppColors.cyan.withOpacity(0.55)),
//           ),
//           Expanded(child: _gradientLine()),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildQuickActions() {
//     final tileH = context.isSmall ? 92.0 : context.isLarge ? 108.0 : 100.0;
//
//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // ── Section Header ──────────────────────────────────────────────
//           Row(
//             children: [
//               Container(
//                 width: context.rs(28), height: context.rs(28),
//                 decoration: BoxDecoration(
//                   color: const Color(0xFF3DAF93).withOpacity(0.15),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Icon(Icons.flash_on_rounded, size: context.rs(15), color: const Color(0xFF3DAF93)),
//               ),
//               SizedBox(width: context.rs(8)),
//               Text(
//                 'Quick Actions',
//                 style: TextStyle(
//                   color: const Color(0xFF1A6E59),
//                   fontSize: context.rs(14),
//                   fontWeight: FontWeight.w700,
//                   letterSpacing: 0.2,
//                 ),
//               ),
//             ],
//           ),
//
//           SizedBox(height: context.rs(12)),
//
//           Row(
//             children: [
//               _actionTile(
//                 icon: Icons.calendar_month_rounded,
//                 label: 'Leave',
//                 iconColor: const Color(0xFF3DAF93),
//                 iconBg: const Color(0xFF3DAF93),
//                 tileHeight: tileH,
//                 onTap: () => Get.to(() => LeaveScreen()),
//               ),
//               SizedBox(width: context.rs(12)),
//               _actionTile(
//                 icon: Icons.task_alt_rounded,
//                 label: 'Tasks',
//                 iconColor: const Color(0xFF5B8DEF),
//                 iconBg: const Color(0xFF5B8DEF),
//                 tileHeight: tileH,
//                 onTap: () => Get.to(
//                       () => const TaskScreen(),
//                   transition: Transition.rightToLeft,
//                   duration: const Duration(milliseconds: 300),
//                 ),
//               ),
//             ],
//           ),
//
//           SizedBox(height: context.rs(12)),
//
//           Row(
//             children: [
//               _breakTile(tileH),
//               SizedBox(width: context.rs(12)),
//               _shortBreakActionTile(tileH),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _actionTile({
//     required IconData icon,
//     required String label,
//     required Color iconColor,
//     required Color iconBg,
//     required VoidCallback onTap,
//     required double tileHeight,
//   }) {
//     return Expanded(
//       child: GestureDetector(
//         onTap: onTap,
//         child: Container(
//           height: tileHeight,
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.circular(context.rs(16)),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.06),
//                 blurRadius: context.rs(12),
//                 offset: Offset(0, context.rs(4)),
//               ),
//             ],
//           ),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Container(
//                 width: context.rs(46),
//                 height: context.rs(46),
//                 decoration: BoxDecoration(
//                   color: iconBg,
//                   borderRadius: BorderRadius.circular(context.rs(12)),
//                 ),
//                 child: Icon(icon, size: context.rs(22), color: Colors.white),
//               ),
//               SizedBox(height: context.rs(8)),
//               Text(
//                 label,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   fontSize: context.rs(12),
//                   fontWeight: FontWeight.w600,
//                   color: const Color(0xFF1A2B22),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _breakTile(double tileHeight) {
//     return Obx(() {
//       final onBreak = breakViewModel.isOnBreak.value;
//       final elapsed = breakViewModel.breakElapsed.value;
//       const activeColor = Color(0xFFF59E0B);
//       const idleColor   = Color(0xFF3DAF93);
//
//       return Expanded(
//         child: GestureDetector(
//           onTap: onBreak ? breakViewModel.endBreak : breakViewModel.startBreak,
//           child: Container(
//             height: tileHeight,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(context.rs(16)),
//               border: onBreak
//                   ? Border.all(color: activeColor.withOpacity(0.40), width: 1.5)
//                   : null,
//               boxShadow: [
//                 BoxShadow(
//                   color: onBreak
//                       ? activeColor.withOpacity(0.15)
//                       : Colors.black.withOpacity(0.06),
//                   blurRadius: context.rs(12),
//                   offset: Offset(0, context.rs(4)),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Container(
//                   width: context.rs(46),
//                   height: context.rs(46),
//                   decoration: BoxDecoration(
//                     color: onBreak ? activeColor : idleColor,
//                     borderRadius: BorderRadius.circular(context.rs(12)),
//                   ),
//                   child: Icon(
//                     onBreak ? Icons.stop_circle_outlined : Icons.free_breakfast_rounded,
//                     size: context.rs(22),
//                     color: Colors.white,
//                   ),
//                 ),
//                 SizedBox(height: context.rs(8)),
//                 Text(
//                   onBreak ? elapsed : 'Break',
//                   textAlign: TextAlign.center,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(
//                     fontSize: context.rs(onBreak ? 11 : 12),
//                     fontWeight: FontWeight.w600,
//                     color: onBreak ? activeColor : const Color(0xFF1A2B22),
//                   ),
//                 ),
//                 if (onBreak) ...[
//                   SizedBox(height: context.rs(2)),
//                   Text(
//                     'Tap to end',
//                     style: TextStyle(
//                       fontSize: context.rs(9),
//                       color: activeColor.withOpacity(0.75),
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         ),
//       );
//     });
//   }
//
//   Widget _shortBreakActionTile(double tileHeight) {
//     const color = Color(0xFFE07B39);
//
//     return Obx(() {
//       final onBreak  = shortBreakVM.isOnShortBreak.value;
//       final timerStr = shortBreakVM.timerDisplay.value;
//
//       return Expanded(
//         child: GestureDetector(
//           onTap: () {
//             if (!attendanceViewModel.isClockedIn.value) {
//               Get.snackbar(
//                 'Not Clocked In',
//                 'Please clock in first to use Short Break.',
//                 snackPosition: SnackPosition.BOTTOM,
//                 duration: const Duration(seconds: 4),
//                 backgroundColor: const Color(0xFFE05A5A).withOpacity(0.93),
//                 colorText: Colors.white,
//                 icon: const Icon(Icons.lock_clock_rounded, color: Colors.white),
//               );
//               return;
//             }
//             Get.to(
//                   () => const ShortBreakScreen(),
//               transition: Transition.rightToLeft,
//               duration: const Duration(milliseconds: 300),
//             );
//           },
//           child: Container(
//             height: tileHeight,
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(context.rs(16)),
//               border: onBreak
//                   ? Border.all(color: color.withOpacity(0.40), width: 1.5)
//                   : null,
//               boxShadow: [
//                 BoxShadow(
//                   color: onBreak
//                       ? color.withOpacity(0.15)
//                       : Colors.black.withOpacity(0.06),
//                   blurRadius: context.rs(12),
//                   offset: Offset(0, context.rs(4)),
//                 ),
//               ],
//             ),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Container(
//                   width: context.rs(46),
//                   height: context.rs(46),
//                   decoration: BoxDecoration(
//                     color: color,
//                     borderRadius: BorderRadius.circular(context.rs(12)),
//                   ),
//                   child: Icon(
//                     onBreak ? Icons.coffee_rounded : Icons.free_breakfast_outlined,
//                     size: context.rs(22),
//                     color: Colors.white,
//                   ),
//                 ),
//                 SizedBox(height: context.rs(8)),
//                 Text(
//                   onBreak ? (timerStr.isNotEmpty ? timerStr : 'Active') : 'Short Break',
//                   textAlign: TextAlign.center,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(
//                     fontSize: context.rs(onBreak && timerStr.isNotEmpty ? 11 : 12),
//                     fontWeight: FontWeight.w600,
//                     color: onBreak ? color : const Color(0xFF1A2B22),
//                   ),
//                 ),
//                 if (onBreak) ...[
//                   SizedBox(height: context.rs(2)),
//                   Text(
//                     'Tap to manage',
//                     style: TextStyle(
//                       fontSize: context.rs(9),
//                       color: color.withOpacity(0.75),
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         ),
//       );
//     });
//   }
//
//   Widget _sectionHeader(String title, IconData icon, Color color) {
//     return Row(children: [
//       Container(width: context.rs(4), height: context.rs(20),
//           decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(2))),
//       SizedBox(width: context.rs(8)),
//       Container(width: context.rs(28), height: context.rs(28),
//           decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(context.rs(8))),
//           child: Icon(icon, size: context.rs(14), color: color)),
//       SizedBox(width: context.rs(8)),
//       Flexible(child: Text(title, overflow: TextOverflow.ellipsis,
//           style: TextStyle(color: AppColors.primary, fontSize: context.rs(13), fontWeight: FontWeight.w700, letterSpacing: 0.3))),
//     ]);
//   }
//
//   Widget _gradientLine() => Container(height: 1,
//     decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AppColors.divider, Colors.transparent])),
//   );
// }
//
// // ── Foreground task ──────────────────────────────────────────────────────────
// void startCallback() {
//   FlutterForegroundTask.setTaskHandler(MyTaskHandler());
// }
//
// class MyTaskHandler extends TaskHandler {
//   @override
//   Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
//   @override
//   Future<void> onRepeatEvent(DateTime timestamp) async {}
//   @override
//   Future<void> onDestroy(DateTime timestamp, bool restart) async {}
// }

import 'package:GPS_Workforce_Monitor/Screens/sync_status_card_screen.dart';
import 'package:GPS_Workforce_Monitor/Screens/task_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Services/interval_selfie_service.dart';
import '../Services/update_check_service.dart';
import '../Services/selfie_notification_policy_service.dart';
import '../Services/developer_options_check_service.dart';

import '../AppColors.dart';
import '../ViewModels/attendance_out_view_model.dart';
import '../ViewModels/attendance_view_model.dart';
import '../ViewModels/break_viewmodel.dart';
import '../ViewModels/short_break_viewmodel.dart';
import '../ViewModels/location_view_model.dart';
import '../ViewModels/task_view_model.dart';
import 'HomeScreenComponents/app_bottom_navbar.dart';
import 'WidgetDesignes/travel_session_card.dart';
import 'leave_report_get_screen.dart';
import 'my_task_activity_screen.dart';
import 'HomeScreenComponents/navbar.dart';
import 'HomeScreenComponents/profile_section.dart';
import 'HomeScreenComponents/sidebar_drawer.dart';
import 'HomeScreenComponents/timer_card.dart' hide LocationViewModel;
import 'leave_screen.dart';
import 'location_session_screen.dart';
import 'short_break_screen.dart';

// ── Responsive helper ────────────────────────────────────────────────────────
extension Responsive on BuildContext {
  double get screenW => MediaQuery.of(this).size.width;
  double get screenH => MediaQuery.of(this).size.height;

  double get sf => (screenW / 390).clamp(0.78, 1.25);

  double rs(double base) => (base * sf).clamp(base * 0.78, base * 1.25);

  EdgeInsets get pagePadding => EdgeInsets.fromLTRB(rs(18), rs(12), rs(18), rs(20));

  bool get isSmall  => screenW < 370;
  bool get isMedium => screenW >= 370 && screenW < 410;
  bool get isLarge  => screenW >= 410;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── ViewModels ─────────────────────────────────────────────────────────────
  final LocationViewModel locationVM              = Get.put(LocationViewModel());
  final AttendanceViewModel attendanceViewModel   = Get.put(AttendanceViewModel());
  final AttendanceOutViewModel attendanceOutViewModel = Get.put(AttendanceOutViewModel());
  final BreakViewModel breakViewModel             = Get.put(BreakViewModel());
  final ShortBreakViewModel shortBreakVM          = Get.put(ShortBreakViewModel());
  final TaskViewModel taskVM                      = Get.put(TaskViewModel());

  // ── State ──────────────────────────────────────────────────────────────────
  String _empName  = '';
  String _empId    = '';
  String _empRole  = '';
  int _navIndex = 0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  // Last sync time for navbar
  String _lastSyncTime = 'Just now';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    WidgetsBinding.instance.addObserver(this);

    Get.put(SelfieNotificationPolicyService());
    Get.put(IntervalSelfieService());

    _loadUserData();
    taskVM.fetchAssignedTasks();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
      _checkDeveloperOptions();
    });

    FlutterForegroundTask.startService(
      notificationTitle: 'Shift Active',
      notificationText: 'GPS & time tracking running…',
      callback: startCallback,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('🔄 [HOME] App resumed — re-checking developer options...');
      _checkDeveloperOptions();
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!mounted) return;
    setState(() {
      _empName = prefs.getString('userName')    ?? 'Employee';
      _empId   = prefs.getString('userId')      ?? '--';
      _empRole = prefs.getString('designation') ?? 'Staff';
    });

    String empId = prefs.getString('emp_id') ?? '';
    if (empId.isEmpty) empId = _empId;
    final String companyCode = prefs.getString('company_code') ?? '';

    debugPrint('');
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('🏠 [HOME] _loadUserData: empId="$empId"  companyCode="$companyCode"');

    if (empId.isNotEmpty && companyCode.isNotEmpty) {
      SelfieNotificationPolicyService.to.initialize(empId, companyCode);
      IntervalSelfieService.to.initialize(empId, companyCode);
    } else {
      debugPrint('❌ [HOME] empId or companyCode empty — selfie service NOT initialized');
    }
    debugPrint('══════════════════════════════════════════════════════');
    debugPrint('');
  }

  // ── Force Update Check ────────────────────────────────────────────────────────
  Future<void> _checkForUpdate() async {
    final required = await UpdateCheckService.isUpdateRequired();
    if (required && mounted) _showForceUpdateDialog();
  }

  void _showForceUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2235),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cyan.withOpacity(0.30), width: 1),
              boxShadow: [BoxShadow(color: AppColors.cyan.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [AppColors.cyan.withOpacity(0.20), AppColors.greenTeal.withOpacity(0.20)]),
                    border: Border.all(color: AppColors.cyan.withOpacity(0.40), width: 1.5),
                  ),
                  child: const Icon(Icons.system_update_alt_rounded, color: AppColors.cyan, size: 36),
                ),
                const SizedBox(height: 20),
                const Text('Update Required', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                const SizedBox(height: 12),
                Text('A newer version is available. Please update to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13.5, height: 1.55)),
                const SizedBox(height: 28),
                SizedBox(width: double.infinity, height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.cyan, AppColors.greenTeal]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.cyan.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
                    ),
                    child: TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(UpdateCheckService.playStoreUrl);
                        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 18),
                      label: const Text('Update Now', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkDeveloperOptions() async {
    final result = await DeveloperOptionsCheckService.checkAndPost();
    if (result.isDeveloperOptionsEnabled && mounted) _showDeveloperOptionsDialog();
  }

  void _showDeveloperOptionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2235),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.60), width: 1.5),
              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 30, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 72, height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal]),
                  ),
                  child: const Icon(Icons.developer_mode_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                const Text('Developer Options Enabled', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text('Developer Options are currently ON.\nPlease turn them OFF to use the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 13.5, height: 1.6)),
                const SizedBox(height: 28),
                SizedBox(width: double.infinity, height: 50,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 5))],
                    ),
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        const MethodChannel('com.metaxperts.GPS_Workforce_Monitor/location_monitor')
                            .invokeMethod('openDeveloperSettings').catchError((_) {});
                      },
                      icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 18),
                      label: const Text('Open Settings', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _doSync() async {
    setState(() {
      _lastSyncTime = 'Just now';
    });

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

    setState(() {
      _lastSyncTime = DateTime.now().toString().substring(11, 16);
    });

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
  // MAIN BUILD - FIXED NAVBAR + PROFILE SECTION (NO SCROLL)
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    // Get user initials for navbar
    String initials = _empName.isNotEmpty ?
    _empName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join() : 'AK';
    if (initials.length < 2 && _empName.isNotEmpty) initials = _empName.substring(0, 1) + (_empName.length > 1 ? _empName.substring(1, 2) : 'K');
    if (initials.isEmpty) initials = 'AK';

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawer(),
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            // ✅ Navbar - FIXED at top (scroll nahi hoga kabhi)
            Navbar(
              userName: _empName.isEmpty ? 'Ahmed Khan' : _empName,
              userInitials: initials,
              lastSync: _lastSyncTime,
              scaffoldKey: _scaffoldKey,
            ),

            // ✅ Baaki sab SCROLLABLE
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [

                    // ✅ ProfileSection - scroll ke saath move karegi
                    const SliverToBoxAdapter(
                      child: ProfileSection(),
                    ),

                    // ✅ Main Content
                    SliverPadding(
                      padding: EdgeInsets.only(
                        left: context.rs(18),
                        right: context.rs(18),
                        top: context.rs(8),
                        bottom: context.rs(20),
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildUnifiedSessionCard(),
                          SizedBox(height: context.rs(14)),
                          const SelfieGraceButton(),
                          const IntervalSelfieButton(),
                          SizedBox(height: context.rs(11)),
                          _buildQuickActions(),
                          SizedBox(height: context.rs(22)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
                            child: SyncStatusCard(onSyncNow: _doSync),
                          ),
                          SizedBox(height: context.rs(30)),
                        ]),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ],
        ),

        // ✅ Bottom Navigation Bar
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: _navIndex,
          chatBadgeCount: 0,
          onTap: (i) => setState(() => _navIndex = i),
        ),
      ),
    );
  }
  // ══════════════════════════════════════════════════════════════════════════
  // ALL EXISTING WIDGETS (unchanged from your original code)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildUnifiedSessionCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // TimerCard is now a self-contained dark green card
          const TimerCard(),
          SizedBox(height: context.rs(12)),
          // TravelSessionCard sits cleanly below
          const TravelSessionCard(),
        ],
      ),
    );
  }

  Widget _buildDividerWithIcon() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(20), vertical: context.rs(6)),
      child: Row(
        children: [
          Expanded(child: _gradientLine()),
          Container(
            margin: EdgeInsets.symmetric(horizontal: context.rs(8)),
            padding: EdgeInsets.all(context.rs(4)),
            decoration: BoxDecoration(color: AppColors.cyan.withOpacity(0.08), shape: BoxShape.circle),
            child: Icon(Icons.swap_vert_rounded, size: context.rs(10), color: AppColors.cyan.withOpacity(0.55)),
          ),
          Expanded(child: _gradientLine()),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final tileH = context.isSmall ? 92.0 : context.isLarge ? 108.0 : 100.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.rs(5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Header ──────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: context.rs(28), height: context.rs(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF3DAF93).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.flash_on_rounded, size: context.rs(15), color: const Color(0xFF3DAF93)),
              ),
              SizedBox(width: context.rs(8)),
              Text(
                'Quick Actions',
                style: TextStyle(
                  color: const Color(0xFF1A6E59),
                  fontSize: context.rs(14),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),

          SizedBox(height: context.rs(12)),

          Row(
            children: [
              _actionTile(
                icon: Icons.calendar_month_rounded,
                label: 'Leave',
                iconColor: const Color(0xFF3DAF93),
                iconBg: const Color(0xFF3DAF93),
                tileHeight: tileH,
                onTap: () => Get.to(() => LeaveScreen()),
              ),
              SizedBox(width: context.rs(12)),
              _actionTile(
                icon: Icons.task_alt_rounded,
                label: 'Tasks',
                iconColor: const Color(0xFF5B8DEF),
                iconBg: const Color(0xFF5B8DEF),
                tileHeight: tileH,
                onTap: () => Get.to(
                      () => const TaskScreen(),
                  transition: Transition.rightToLeft,
                  duration: const Duration(milliseconds: 300),
                ),
              ),
            ],
          ),

          SizedBox(height: context.rs(12)),

          Row(
            children: [
              _breakTile(tileH),
              SizedBox(width: context.rs(12)),
              _shortBreakActionTile(tileH),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
    required double tileHeight,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: tileHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(context.rs(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: context.rs(12),
                offset: Offset(0, context.rs(4)),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: context.rs(46),
                height: context.rs(46),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(context.rs(12)),
                ),
                child: Icon(icon, size: context.rs(22), color: Colors.white),
              ),
              SizedBox(height: context.rs(8)),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: context.rs(12),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A2B22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakTile(double tileHeight) {
    return Obx(() {
      final onBreak = breakViewModel.isOnBreak.value;
      final elapsed = breakViewModel.breakElapsed.value;
      const activeColor = Color(0xFFF59E0B);
      const idleColor   = Color(0xFF3DAF93);

      return Expanded(
        child: GestureDetector(
          onTap: onBreak ? breakViewModel.endBreak : breakViewModel.startBreak,
          child: Container(
            height: tileHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(context.rs(16)),
              border: onBreak
                  ? Border.all(color: activeColor.withOpacity(0.40), width: 1.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: onBreak
                      ? activeColor.withOpacity(0.15)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: context.rs(12),
                  offset: Offset(0, context.rs(4)),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: context.rs(46),
                  height: context.rs(46),
                  decoration: BoxDecoration(
                    color: onBreak ? activeColor : idleColor,
                    borderRadius: BorderRadius.circular(context.rs(12)),
                  ),
                  child: Icon(
                    onBreak ? Icons.stop_circle_outlined : Icons.free_breakfast_rounded,
                    size: context.rs(22),
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: context.rs(8)),
                Text(
                  onBreak ? elapsed : 'Break',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.rs(onBreak ? 11 : 12),
                    fontWeight: FontWeight.w600,
                    color: onBreak ? activeColor : const Color(0xFF1A2B22),
                  ),
                ),
                if (onBreak) ...[
                  SizedBox(height: context.rs(2)),
                  Text(
                    'Tap to end',
                    style: TextStyle(
                      fontSize: context.rs(9),
                      color: activeColor.withOpacity(0.75),
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

  Widget _shortBreakActionTile(double tileHeight) {
    const color = Color(0xFFE07B39);

    return Obx(() {
      final onBreak  = shortBreakVM.isOnShortBreak.value;
      final timerStr = shortBreakVM.timerDisplay.value;

      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (!attendanceViewModel.isClockedIn.value) {
              Get.snackbar(
                'Not Clocked In',
                'Please clock in first to use Short Break.',
                snackPosition: SnackPosition.BOTTOM,
                duration: const Duration(seconds: 4),
                backgroundColor: const Color(0xFFE05A5A).withOpacity(0.93),
                colorText: Colors.white,
                icon: const Icon(Icons.lock_clock_rounded, color: Colors.white),
              );
              return;
            }
            Get.to(
                  () => const ShortBreakScreen(),
              transition: Transition.rightToLeft,
              duration: const Duration(milliseconds: 300),
            );
          },
          child: Container(
            height: tileHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(context.rs(16)),
              border: onBreak
                  ? Border.all(color: color.withOpacity(0.40), width: 1.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: onBreak
                      ? color.withOpacity(0.15)
                      : Colors.black.withOpacity(0.06),
                  blurRadius: context.rs(12),
                  offset: Offset(0, context.rs(4)),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: context.rs(46),
                  height: context.rs(46),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(context.rs(12)),
                  ),
                  child: Icon(
                    onBreak ? Icons.coffee_rounded : Icons.free_breakfast_outlined,
                    size: context.rs(22),
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: context.rs(8)),
                Text(
                  onBreak ? (timerStr.isNotEmpty ? timerStr : 'Active') : 'Short Break',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.rs(onBreak && timerStr.isNotEmpty ? 11 : 12),
                    fontWeight: FontWeight.w600,
                    color: onBreak ? color : const Color(0xFF1A2B22),
                  ),
                ),
                if (onBreak) ...[
                  SizedBox(height: context.rs(2)),
                  Text(
                    'Tap to manage',
                    style: TextStyle(
                      fontSize: context.rs(9),
                      color: color.withOpacity(0.75),
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

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(width: context.rs(4), height: context.rs(20),
          decoration: BoxDecoration(gradient: AppColors.brandGradient, borderRadius: BorderRadius.circular(2))),
      SizedBox(width: context.rs(8)),
      Container(width: context.rs(28), height: context.rs(28),
          decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(context.rs(8))),
          child: Icon(icon, size: context.rs(14), color: color)),
      SizedBox(width: context.rs(8)),
      Flexible(child: Text(title, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: AppColors.primary, fontSize: context.rs(13), fontWeight: FontWeight.w700, letterSpacing: 0.3))),
    ]);
  }

  Widget _gradientLine() => Container(height: 1,
    decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AppColors.divider, Colors.transparent])),
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