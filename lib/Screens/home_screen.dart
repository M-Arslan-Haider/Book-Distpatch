//
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// import 'package:lucide_icons/lucide_icons.dart';
//
// import '../AppColors.dart';
// import '../ViewModels/attendance_out_view_model.dart';
// import '../ViewModels/attendance_view_model.dart';
// import '../ViewModels/break_viewmodel.dart';
// import '../ViewModels/location_view_model.dart';
// import 'HomeScreenComponents/navbar.dart';
// import 'HomeScreenComponents/profile_section.dart';
// import 'HomeScreenComponents/sidebar_drawer.dart';
// import 'HomeScreenComponents/timer_card.dart' hide LocationViewModel;
// import 'leave_screen.dart';
//
// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
//
//   // ── Design tokens (mirrored from EmployeeProfileScreen) ────────────────────
//   // Color tokens moved to AppColors   // primary navy
//   //   // gold accent
//   //   // gold tint
//   //   // page background
//   //
//   //
//   //
//   //   // icon-blue accent
//   //
//   //
//   //
//   //   // Added for break
//
//   // ── ViewModels ─────────────────────────────────────────────────────────────
//   final LocationViewModel      locationVM             = Get.put(LocationViewModel());
//   final AttendanceViewModel    attendanceViewModel    = Get.put(AttendanceViewModel());
//   final AttendanceOutViewModel attendanceOutViewModel = Get.put(AttendanceOutViewModel());
//   final BreakViewModel breakViewModel = Get.put(BreakViewModel()); // Added BreakViewModel
//
//   // ── State ──────────────────────────────────────────────────────────────────
//   String _empName = '';
//   String _empId   = '';
//   String _empRole = '';
//
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   late final AnimationController _fadeCtrl;
//   late final Animation<double>    _fadeAnim;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _fadeCtrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 500));
//     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
//     _fadeCtrl.forward();
//
//     _loadUserData();
//
//     FlutterForegroundTask.startService(
//       notificationTitle: 'Shift Active',
//       notificationText:  'GPS & time tracking running…',
//       callback: startCallback,
//     );
//   }
//
//   @override
//   void dispose() {
//     _fadeCtrl.dispose();
//     super.dispose();
//   }
//
//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.reload();
//     setState(() {
//       _empName = prefs.getString('userName')    ?? 'Employee';
//       _empId   = prefs.getString('userId')      ?? '--';
//       _empRole = prefs.getString('designation') ?? 'Staff';
//     });
//   }
//
//   // ──────────────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//     ));
//
//     return WillPopScope(
//       onWillPop: () async => false,
//       child: Scaffold(
//         key:             _scaffoldKey,
//         drawer:          const AppDrawer(),
//         backgroundColor: AppColors.surface,
//         body: FadeTransition(
//           opacity: _fadeAnim,
//           child: CustomScrollView(
//             physics: const BouncingScrollPhysics(),
//             slivers: [
//               SliverToBoxAdapter(child: _buildHeader()),
//               SliverPadding(
//                 padding: const EdgeInsets.fromLTRB(18, 22, 18, 40),
//                 sliver: SliverList(
//                   delegate: SliverChildListDelegate([
//                     const SizedBox(height: 1),
//                     TimerCard(),
//                     const SizedBox(height: 25),
//                     _buildQuickActions(horizontalPadding: 5),
//                   ]),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildQuickActions({required double horizontalPadding}) {
//     return Padding(
//       padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Section header styled like profile screen
//           _sectionHeader('Quick Actions', Icons.flash_on_rounded, AppColors.greenTeal),
//           const SizedBox(height: 12),
//           Row(
//             children: [
//               _actionTile(
//                 icon: Icons.calendar_month_rounded,
//                 label: 'Leave',
//                 color: AppColors.cyan,
//                 onTap: () => Get.to(() => LeaveScreen()),
//               ),
//               const SizedBox(width: 12),
//               _actionTile(
//                 icon: Icons.task_alt_rounded,
//                 label: 'Tasks',
//                 color: AppColors.skyBlueDk,
//                 onTap: () => Get.to(() => ()),
//               ),
//               const SizedBox(width: 12),
//               // ── Break tile — live duration when break is active ──
//               Obx(() {
//                 final onBreak = breakViewModel.isOnBreak.value;
//                 final elapsed = breakViewModel.breakElapsed.value;
//                 return Expanded(
//                   child: GestureDetector(
//                     onTap: () {
//                       if (onBreak) {
//                         breakViewModel.endBreak();
//                       } else {
//                         breakViewModel.startBreak();
//                       }
//                     },
//                     child: Container(
//                       height: 100,
//                       margin: const EdgeInsets.symmetric(horizontal: 2),
//                       decoration: BoxDecoration(
//                         color: onBreak ? AppColors.warning.withOpacity(0.05) : AppColors.cardBg,
//                         borderRadius: BorderRadius.circular(12),
//                         border: Border.all(
//                           color: onBreak ? AppColors.warning.withOpacity(0.3) : AppColors.divider,
//                           width: onBreak ? 1.5 : 1,
//                         ),
//                         boxShadow: [
//                           BoxShadow(
//                             color: onBreak
//                                 ? AppColors.warning.withOpacity(0.15)
//                                 : Colors.black.withOpacity(0.04),
//                             blurRadius: 10,
//                             offset: const Offset(0, 3),
//                           ),
//                         ],
//                       ),
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Container(
//                             width: 48,
//                             height: 48,
//                             decoration: BoxDecoration(
//                               color: onBreak
//                                   ? AppColors.warning.withOpacity(0.15)
//                                   : AppColors.cyan.withOpacity(0.10),
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                             child: Icon(
//                               onBreak
//                                   ? Icons.stop_circle_outlined
//                                   : Icons.free_breakfast,
//                               size: 24,
//                               color: onBreak ? AppColors.warning : AppColors.cyan,
//                             ),
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             onBreak ? elapsed : 'Break',
//                             textAlign: TextAlign.center,
//                             style: TextStyle(
//                               fontSize: onBreak ? 13 : 13,
//                               fontWeight: FontWeight.w600,
//                               color: onBreak ? AppColors.warning : AppColors.textPrimary,
//                             ),
//                           ),
//                           if (onBreak)
//                             Text(
//                               'Tap to end',
//                               style: TextStyle(
//                                 fontSize: 9,
//                                 color: AppColors.warning.withOpacity(0.7),
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 );
//               }),
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
//     required Color color,
//     required VoidCallback onTap,
//   }) {
//     return Expanded(
//       child: GestureDetector(
//         onTap: onTap,
//         child: Container(
//           height: 100,
//           margin: const EdgeInsets.symmetric(horizontal: 2),
//           decoration: BoxDecoration(
//             color: AppColors.cardBg,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: AppColors.divider),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.04),
//                 blurRadius: 10,
//                 offset: const Offset(0, 3),
//               ),
//             ],
//           ),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Container(
//                 width: 48,
//                 height: 48,
//                 decoration: BoxDecoration(
//                   color: color.withOpacity(0.10),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Icon(icon, size: 24, color: color),
//               ),
//               const SizedBox(height: 10),
//               Text(label,
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(
//                     fontSize: 13,
//                     fontWeight: FontWeight.w600,
//                     color: AppColors.textPrimary,
//                   )),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ─── HEADER ────────────────────────────────────────────────────────────────
//   Widget _buildHeader() {
//     return Container(
//       decoration: const BoxDecoration(
//         // Navy → slightly lighter navy — matches profile screen's app bar gradient
//         gradient: LinearGradient(
//           colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.only(
//           bottomLeft:  Radius.circular(36),
//           bottomRight: Radius.circular(36),
//         ),
//       ),
//       child: Stack(
//         children: [
//           // Decorative circles — same as profile screen app bar
//           Positioned(top: -50, right: -30,
//               child: _decorCircle(200, AppColors.greenTeal, 0.12)),
//           Positioned(bottom: -40, left: -20,
//               child: _decorCircle(140, Colors.white, 0.10)),
//
//           SafeArea(
//             child: Column(
//               children: [
//                 _buildTopBar(),
//                 const SizedBox(height: 4),
//                 const ProfileSection(),
//                 const SizedBox(height: 8),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildTopBar() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//       child: Row(
//         children: [
//           // Hamburger button — gold-tinted to match profile's gold accents
//           GestureDetector(
//             onTap: () => _scaffoldKey.currentState?.openDrawer(),
//             child: Container(
//               width: 42, height: 42,
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.12),
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: Colors.white.withOpacity(0.18)),
//               ),
//               child: const Icon(
//                 Icons.menu_rounded,
//                 color: Colors.white,
//                 size: 22,
//               ),
//             ),
//           ),
//           const SizedBox(width: 12),
//
//           // App title
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'GPS Workforce Monitor',
//                   style: TextStyle(
//                     color:      Colors.white,
//                     fontSize:   16,
//                     fontWeight: FontWeight.w800,
//                     letterSpacing: 0.2,
//                   ),
//                 ),
//                 Text(
//                   'GPS Workforce Monitor System',
//                   style: TextStyle(
//                     color:      Colors.white.withOpacity(0.60),
//                     fontSize:   10,
//                     fontWeight: FontWeight.w400,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Sync button
//           GestureDetector(
//             onTap: () async {
//               Get.showSnackbar(GetSnackBar(
//                 message:         'Syncing data...',
//                 duration:        const Duration(seconds: 2),
//                 backgroundColor: AppColors.cyan,
//                 icon:            const Icon(Icons.sync, color: Colors.white),
//                 borderRadius:    10,
//                 margin:          const EdgeInsets.all(12),
//               ));
//               await attendanceViewModel.syncUnposted();
//               await attendanceOutViewModel.syncUnposted();
//               Get.showSnackbar(const GetSnackBar(
//                 message:         'Data synced successfully',
//                 duration:        Duration(seconds: 2),
//                 backgroundColor: AppColors.greenTeal,
//                 icon:            Icon(Icons.check_circle_outline_rounded,
//                     color: Colors.white),
//                 borderRadius:    10,
//                 margin:          EdgeInsets.all(12),
//               ));
//             },
//             child: Container(
//               width: 42, height: 42,
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.12),
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: Colors.white.withOpacity(0.18)),
//               ),
//               child: const Icon(
//                 Icons.sync_rounded,
//                 color: Colors.white,
//                 size: 22,
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Section header — exact style from profile screen ───────────────────────
//   Widget _sectionHeader(String title, IconData icon, Color color) {
//     return Row(children: [
//       // Gold left bar — signature profile screen element
//       Container(
//           width: 4, height: 20,
//           decoration: BoxDecoration(
//               gradient: AppColors.brandGradient,
//               borderRadius: BorderRadius.circular(2))),
//       const SizedBox(width: 8),
//       Container(
//         width: 28, height: 28,
//         decoration: BoxDecoration(
//             color: color.withOpacity(0.10),
//             borderRadius: BorderRadius.circular(8)),
//         child: Icon(icon, size: 15, color: color),
//       ),
//       const SizedBox(width: 8),
//       Text(title,
//           style: const TextStyle(
//               color: AppColors.primary, fontSize: 13,
//               fontWeight: FontWeight.w700, letterSpacing: 0.3)),
//     ]);
//   }
//
//   Widget _decorCircle(double size, Color color, double opacity) => Container(
//     width: size, height: size,
//     decoration: BoxDecoration(
//       shape: BoxShape.circle,
//       color: color.withOpacity(opacity),
//     ),
//   );
//
//   Widget _buildStatsRow() {
//     return Obx(() {
//       final inCount     = attendanceViewModel.allAttendance.length;
//       final outCount    = attendanceOutViewModel.allAttendanceOut.length;
//       final isClockedIn = attendanceViewModel.isClockedIn.value;
//       final elapsed     = attendanceViewModel.elapsedTime.value;
//
//       return Row(
//         children: [
//           _statCard(LucideIcons.logIn, 'Clock-Ins', '$inCount', AppColors.skyBlue),
//           const SizedBox(width: 10),
//           _statCard(LucideIcons.logOut, 'Clock-Outs', '$outCount', AppColors.error),
//           const SizedBox(width: 10),
//           _statCard(LucideIcons.timer,  'Shift Time',
//               isClockedIn ? elapsed : '--:--', AppColors.greenTeal),
//         ],
//       );
//     });
//   }
//
//   Widget _statCard(IconData icon, String label, String value, Color color) =>
//       Expanded(
//         child: Container(
//           padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
//           decoration: BoxDecoration(
//             color: AppColors.cardBg,
//             borderRadius: BorderRadius.circular(12),
//             border: Border.all(color: AppColors.divider),
//             boxShadow: [BoxShadow(
//                 color: Colors.black.withOpacity(0.04),
//                 blurRadius: 10, offset: const Offset(0, 3))],
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Container(
//                 width: 36, height: 36,
//                 decoration: BoxDecoration(
//                     color: color.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(10)),
//                 child: Icon(icon, size: 18, color: color),
//               ),
//               const SizedBox(height: 10),
//               Text(value,
//                   style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.w800,
//                       color: color,
//                       letterSpacing: 0.5)),
//               const SizedBox(height: 2),
//               Text(label,
//                   style: const TextStyle(
//                       fontSize: 11,
//                       color: AppColors.textSecondary,
//                       fontWeight: FontWeight.w500)),
//             ],
//           ),
//         ),
//       );
//
//   Widget _buildSyncCard() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: AppColors.cardBg,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: AppColors.divider),
//         boxShadow: [BoxShadow(
//             color: Colors.black.withOpacity(0.04),
//             blurRadius: 10, offset: const Offset(0, 3))],
//       ),
//       child: Column(
//         children: [
//           Row(
//             children: [
//               Container(
//                 width: 42, height: 42,
//                 decoration: BoxDecoration(
//                     color: AppColors.cyan.withOpacity(0.10),
//                     borderRadius: BorderRadius.circular(10)),
//                 child: Icon(LucideIcons.refreshCw, size: 20, color: AppColors.cyan),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text('Data Sync',
//                         style: TextStyle(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w600,
//                             color: AppColors.primary)),
//                     const SizedBox(height: 2),
//                     Text('Records sync automatically when online',
//                         style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
//                   ],
//                 ),
//               ),
//               GestureDetector(
//                 onTap: () async {
//                   await attendanceViewModel.syncUnposted();
//                   await attendanceOutViewModel.syncUnposted();
//                   Get.snackbar('✅ Synced', 'All records pushed to server',
//                       snackPosition: SnackPosition.TOP,
//                       backgroundColor: AppColors.success,
//                       colorText: Colors.white,
//                       duration: const Duration(seconds: 2));
//                 },
//                 child: DecoratedBox(
//                   decoration: BoxDecoration(
//                     gradient: AppColors.brandGradient,
//                     borderRadius: BorderRadius.circular(10),
//                     boxShadow: [
//                       BoxShadow(
//                         color: AppColors.cyan.withOpacity(0.35),
//                         blurRadius: 12,
//                         offset: const Offset(0, 4),
//                       ),
//                     ],
//                   ),
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//                     child: const Text('Sync Now',
//                         style: TextStyle(
//                             fontSize: 12,
//                             fontWeight: FontWeight.w600,
//                             color: Colors.white)),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 14),
//           Divider(height: 1, color: AppColors.divider),
//           const SizedBox(height: 14),
//           Obx(() {
//             final pendIn  = attendanceViewModel.allAttendance
//                 .where((r) => r.posted == 0).length;
//             final pendOut = attendanceOutViewModel.allAttendanceOut
//                 .where((r) => r.posted == 0).length;
//             return Row(
//               children: [
//                 _pendingChip('Pending IN',  pendIn),
//                 const SizedBox(width: 10),
//                 _pendingChip('Pending OUT', pendOut),
//               ],
//             );
//           }),
//         ],
//       ),
//     );
//   }
//
//   Widget _pendingChip(String label, int count) {
//     final color = count > 0 ? AppColors.error : AppColors.success;
//     return Expanded(
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 10),
//         decoration: BoxDecoration(
//           color: color.withOpacity(0.08),
//           borderRadius: BorderRadius.circular(10),
//           border: Border.all(color: color.withOpacity(0.20)),
//         ),
//         child: Column(
//           children: [
//             Text('$count',
//                 style: TextStyle(
//                     fontSize: 22, fontWeight: FontWeight.w800, color: color)),
//             const SizedBox(height: 2),
//             Text(label,
//                 style: TextStyle(
//                     fontSize: 11, color: color, fontWeight: FontWeight.w500)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLocationCard() {
//     return Obx(() {
//       final lat     = locationVM.globalLatitude1.value;
//       final lng     = locationVM.globalLongitude1.value;
//       final address = locationVM.shopAddress.value;
//       final hasLoc  = lat != 0.0 || lng != 0.0;
//       final color   = hasLoc ? AppColors.success : AppColors.warning;
//
//       return Container(
//         padding: const EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: AppColors.cardBg,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: AppColors.divider),
//           boxShadow: [BoxShadow(
//               color: Colors.black.withOpacity(0.04),
//               blurRadius: 10, offset: const Offset(0, 3))],
//         ),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Container(
//               width: 44, height: 44,
//               decoration: BoxDecoration(
//                   color: color.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(10)),
//               child: Icon(LucideIcons.mapPin, size: 22, color: color),
//             ),
//             const SizedBox(width: 14),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     hasLoc ? 'Location Active' : 'Waiting for GPS…',
//                     style: TextStyle(
//                         fontSize: 14, fontWeight: FontWeight.w600, color: color),
//                   ),
//                   const SizedBox(height: 4),
//                   if (hasLoc) ...[
//                     Text(
//                       address.isNotEmpty ? address : 'Fetching address…',
//                       style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
//                       maxLines: 2, overflow: TextOverflow.ellipsis,
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
//                       style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.4),
//                           fontFeatures: const [FontFeature.tabularFigures()]),
//                     ),
//                   ] else
//                     const Text(
//                       'Enable location services to track your shift',
//                       style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
//                     ),
//                 ],
//               ),
//             ),
//             GestureDetector(
//               onTap: () => locationVM.saveCurrentLocation(),
//               child: Container(
//                 width: 36, height: 36,
//                 decoration: BoxDecoration(
//                     color: AppColors.cyan.withOpacity(0.10),
//                     borderRadius: BorderRadius.circular(10)),
//                 child: Icon(LucideIcons.refreshCw, size: 16, color: AppColors.cyan),
//               ),
//             ),
//           ],
//         ),
//       );
//     });
//   }
//
//   void _showClockInRequiredDialog() {
//     Get.defaultDialog(
//       title: 'Clock In Required',
//       titleStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
//       middleText: 'Please start your shift timer first.',
//       middleTextStyle: const TextStyle(color: AppColors.textSecondary),
//       textConfirm: 'OK',
//       confirmTextColor: Colors.white,
//       buttonColor: AppColors.cyan,
//       radius: 16,
//       onConfirm: Get.back,
//     );
//   }
// }
//
// // ── Foreground task handler ───────────────────────────────────────────────────
// void startCallback() {
//   FlutterForegroundTask.setTaskHandler(MyTaskHandler());
// }
//
// class MyTaskHandler extends TaskHandler {
//   @override Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
//   @override Future<void> onRepeatEvent(DateTime timestamp) async {}
//   @override Future<void> onDestroy(DateTime timestamp, bool restart) async {}
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../AppColors.dart';
import '../ViewModels/attendance_out_view_model.dart';
import '../ViewModels/attendance_view_model.dart';
import '../ViewModels/break_viewmodel.dart';
import '../ViewModels/location_view_model.dart';
import 'HomeScreenComponents/navbar.dart';
import 'HomeScreenComponents/profile_section.dart';
import 'HomeScreenComponents/sidebar_drawer.dart';
import 'HomeScreenComponents/timer_card.dart' hide LocationViewModel;
import 'leave_screen.dart';
import 'location_session_screen.dart'; // Add this import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {

  // ── ViewModels ─────────────────────────────────────────────────────────────
  final LocationViewModel      locationVM             = Get.put(LocationViewModel());
  final AttendanceViewModel    attendanceViewModel    = Get.put(AttendanceViewModel());
  final AttendanceOutViewModel attendanceOutViewModel = Get.put(AttendanceOutViewModel());
  final BreakViewModel breakViewModel = Get.put(BreakViewModel());

  // ── State ──────────────────────────────────────────────────────────────────
  String _empName = '';
  String _empId   = '';
  String _empRole = '';
  String _selectedAddress = '';
  String _selectedLocationName = '';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AnimationController _fadeCtrl;
  late final Animation<double>    _fadeAnim;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _loadUserData();
    _loadSelectedAddress();

    FlutterForegroundTask.startService(
      notificationTitle: 'Shift Active',
      notificationText:  'GPS & time tracking running…',
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
    setState(() {
      _empName = prefs.getString('userName')    ?? 'Employee';
      _empId   = prefs.getString('userId')      ?? '--';
      _empRole = prefs.getString('designation') ?? 'Staff';
    });
  }

  Future<void> _loadSelectedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    setState(() {
      _selectedAddress      = prefs.getString('selected_location_address') ?? '';
      _selectedLocationName = prefs.getString('selected_location_name')    ?? '';
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        key:             _scaffoldKey,
        drawer:          const AppDrawer(),
        backgroundColor: AppColors.surface,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 1),
                    TimerCard(),
                    const SizedBox(height: 20),
                    _buildLocationSelector(), // Added location selector
                    const SizedBox(height: 25),
                    _buildQuickActions(horizontalPadding: 5),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── NEW: Location Selector Card (styled with AppColors) ───────────────────
  Widget _buildLocationSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Get.to(() => LocationSelectionScreen())
                ?.then((_) => _loadSelectedAddress()),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Icon Badge with gradient
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyan.withOpacity(0.30),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Text Block
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label
                        Text(
                          'Select Location',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Location Name (bold)
                        if (_selectedLocationName.isNotEmpty)
                          Text(
                            _selectedLocationName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          )
                        else
                          Text(
                            'Tap to choose your work location',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.cyan,
                            ),
                          ),

                        // Address (below name)
                        if (_selectedAddress.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            _selectedAddress,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary.withOpacity(0.8),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Chevron
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.cyan,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions({required double horizontalPadding}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Quick Actions', Icons.flash_on_rounded, AppColors.greenTeal),
          const SizedBox(height: 12),
          Row(
            children: [
              _actionTile(
                icon: Icons.calendar_month_rounded,
                label: 'Leave',
                color: AppColors.cyan,
                onTap: () => Get.to(() => LeaveScreen()),
              ),
              const SizedBox(width: 12),
              _actionTile(
                icon: Icons.task_alt_rounded,
                label: 'Tasks',
                color: AppColors.skyBlueDk,
                onTap: () => Get.to(() => ()),
              ),
              const SizedBox(width: 12),
              // ── Break tile ──
              Obx(() {
                final onBreak = breakViewModel.isOnBreak.value;
                final elapsed = breakViewModel.breakElapsed.value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (onBreak) {
                        breakViewModel.endBreak();
                      } else {
                        breakViewModel.startBreak();
                      }
                    },
                    child: Container(
                      height: 100,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: onBreak ? AppColors.warning.withOpacity(0.05) : AppColors.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: onBreak ? AppColors.warning.withOpacity(0.3) : AppColors.divider,
                          width: onBreak ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: onBreak
                                ? AppColors.warning.withOpacity(0.15)
                                : Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: onBreak
                                  ? AppColors.warning.withOpacity(0.15)
                                  : AppColors.cyan.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              onBreak
                                  ? Icons.stop_circle_outlined
                                  : Icons.free_breakfast,
                              size: 24,
                              color: onBreak ? AppColors.warning : AppColors.cyan,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            onBreak ? elapsed : 'Break',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: onBreak ? 13 : 13,
                              fontWeight: FontWeight.w600,
                              color: onBreak ? AppColors.warning : AppColors.textPrimary,
                            ),
                          ),
                          if (onBreak)
                            Text(
                              'Tap to end',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.warning.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
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
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 10),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
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
          Positioned(top: -50, right: -30,
              child: _decorCircle(200, AppColors.greenTeal, 0.12)),
          Positioned(bottom: -40, left: -20,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Icon(
                Icons.menu_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GPS Workforce Monitor',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'GPS Workforce Monitor System',
                  style: TextStyle(
                    color:      Colors.white.withOpacity(0.60),
                    fontSize:   10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap: () async {
              Get.showSnackbar(GetSnackBar(
                message:         'Syncing data...',
                duration:        const Duration(seconds: 2),
                backgroundColor: AppColors.cyan,
                icon:            const Icon(Icons.sync, color: Colors.white),
                borderRadius:    10,
                margin:          const EdgeInsets.all(12),
              ));
              await attendanceViewModel.syncUnposted();
              await attendanceOutViewModel.syncUnposted();
              Get.showSnackbar(const GetSnackBar(
                message:         'Data synced successfully',
                duration:        Duration(seconds: 2),
                backgroundColor: AppColors.greenTeal,
                icon:            Icon(Icons.check_circle_outline_rounded,
                    color: Colors.white),
                borderRadius:    10,
                margin:          EdgeInsets.all(12),
              ));
            },
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: const Icon(
                Icons.sync_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              color: AppColors.primary, fontSize: 13,
              fontWeight: FontWeight.w700, letterSpacing: 0.3)),
    ]);
  }

  Widget _decorCircle(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );

  // Keep all your existing helper methods (_buildStatsRow, _buildSyncCard, etc.)
  // ... (rest of your existing code remains the same)

  void _showClockInRequiredDialog() {
    Get.defaultDialog(
      title: 'Clock In Required',
      titleStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
      middleText: 'Please start your shift timer first.',
      middleTextStyle: const TextStyle(color: AppColors.textSecondary),
      textConfirm: 'OK',
      confirmTextColor: Colors.white,
      buttonColor: AppColors.cyan,
      radius: 16,
      onConfirm: Get.back,
    );
  }
}

// ── Foreground task handler ───────────────────────────────────────────────────
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}
  @override Future<void> onRepeatEvent(DateTime timestamp) async {}
  @override Future<void> onDestroy(DateTime timestamp, bool restart) async {}
}