// // // import 'package:flutter/material.dart';
// // // import 'package:flutter/services.dart';
// // // import 'package:get/get.dart';
// // // import '../../ViewModels/login_view_model.dart';
// // // import '../HomeScreenComponents/navbar.dart';
// // // import '../HomeScreenComponents/sidebar_drawer.dart';
// // // import 'wagers_register_screen.dart';
// // //
// // // // ═══════════════════════════════════════════════════════════════════════════════
// // // // timekeeper_screen.dart
// // // // ═══════════════════════════════════════════════════════════════════════════════
// // //
// // // class TimekeeperScreen extends StatefulWidget {
// // //   const TimekeeperScreen({super.key});
// // //
// // //   @override
// // //   State<TimekeeperScreen> createState() => _TimekeeperScreenState();
// // // }
// // //
// // // class _TimekeeperScreenState extends State<TimekeeperScreen> {
// // //   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
// // //
// // //   static const _bg       = Color(0xFFF4F6FB);
// // //   static const _textMuted = Color(0xFF6B7280);
// // //
// // //   static const _actions = [
// // //     _QuickAction(
// // //       label:    'Wagers Register',
// // //       subtitle: 'Enroll new wager',
// // //       icon:     Icons.person_add_alt_1_rounded,
// // //       color:    Color(0xFF0C6B64),
// // //       accent:   Color(0xFFE0F5F3),
// // //       route:    '/timekeeperRegister',
// // //     ),
// // //     _QuickAction(
// // //       label:    'Wagers Attendance',
// // //       subtitle: 'Mark daily attendance',
// // //       icon:     Icons.fact_check_rounded,
// // //       color:    Color(0xFF2563EB),
// // //       accent:   Color(0xFFEFF6FF),
// // //       route:    '/timekeeperAttendance',
// // //     ),
// // //     _QuickAction(
// // //       label:    'Wagers Terminate',
// // //       subtitle: 'Approve Terminate requests',
// // //       icon:     Icons.event_busy_rounded,
// // //       color:    Color(0xFFD97706),
// // //       accent:   Color(0xFFFFFBEB),
// // //       route:    '/timekeeperTerminate',
// // //     ),
// // //     _QuickAction(
// // //       label:    'Wagers Detail',
// // //       subtitle: 'View wagers detail',
// // //       icon:     Icons.bar_chart_rounded,
// // //       color:    Color(0xFF7C3AED),
// // //       accent:   Color(0xFFF5F3FF),
// // //       route:    '/timekeeperReports',
// // //     ),
// // //   ];
// // //
// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final loginVM = Get.find<LoginViewModel>();
// // //     final name    = loginVM.currentUser.value?.emp_name ?? 'Timekeeper';
// // //
// // //     final parts    = name.trim().split(' ');
// // //     final initials = parts.length >= 2
// // //         ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
// // //         : name.isNotEmpty ? name[0].toUpperCase() : 'TK';
// // //
// // //     return Scaffold(
// // //       key:             _scaffoldKey,
// // //       backgroundColor: _bg,
// // //       appBar: Navbar(
// // //         userName:     name,
// // //         userInitials: initials,
// // //         scaffoldKey:  _scaffoldKey,
// // //       ),
// // //       drawer: AppDrawer(),
// // //       body: Padding(
// // //         padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
// // //         child: Column(
// // //           crossAxisAlignment: CrossAxisAlignment.start,
// // //           children: [
// // //             // ── Section label ──────────────────────────────────────────────
// // //             const Text(
// // //               'QUICK ACTIONS',
// // //               style: TextStyle(
// // //                 fontSize:      12,
// // //                 fontWeight:    FontWeight.w600,
// // //                 color:         _textMuted,
// // //                 letterSpacing: 1.0,
// // //               ),
// // //             ),
// // //
// // //             const SizedBox(height: 14),
// // //
// // //             // ── Action cards — vertical column ─────────────────────────────
// // //             ...List.generate(
// // //               _actions.length,
// // //                   (i) => Padding(
// // //                 padding: EdgeInsets.only(
// // //                   bottom: i < _actions.length - 1 ? 12 : 0,
// // //                 ),
// // //                 child: _ActionCard(action: _actions[i]),
// // //               ),
// // //             ),
// // //           ],
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }
// // //
// // // // ─────────────────────────────────────────────────────────────────────────────
// // // // Action Card  — horizontal row layout
// // // // ─────────────────────────────────────────────────────────────────────────────
// // // class _ActionCard extends StatefulWidget {
// // //   final _QuickAction action;
// // //   const _ActionCard({required this.action});
// // //
// // //   @override
// // //   State<_ActionCard> createState() => _ActionCardState();
// // // }
// // //
// // // class _ActionCardState extends State<_ActionCard>
// // //     with SingleTickerProviderStateMixin {
// // //   late final AnimationController _ctrl;
// // //   late final Animation<double>   _scale;
// // //
// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     _ctrl = AnimationController(
// // //       vsync:           this,
// // //       duration:        const Duration(milliseconds: 100),
// // //       reverseDuration: const Duration(milliseconds: 200),
// // //     );
// // //     _scale = Tween<double>(begin: 1.0, end: 0.97)
// // //         .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
// // //   }
// // //
// // //   @override
// // //   void dispose() {
// // //     _ctrl.dispose();
// // //     super.dispose();
// // //   }
// // //
// // //   void _onTap() {
// // //     HapticFeedback.lightImpact();
// // //     _ctrl.forward().then((_) => _ctrl.reverse());
// // //
// // //     if (widget.action.route == '/timekeeperRegister') {
// // //       Get.to(() => const WagersRegisterScreen());
// // //     }
// // //   }
// // //
// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final a = widget.action;
// // //
// // //     return AnimatedBuilder(
// // //       animation: _scale,
// // //       builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
// // //       child: GestureDetector(
// // //         onTap:       _onTap,
// // //         onTapDown:   (_) => _ctrl.forward(),
// // //         onTapCancel: ()  => _ctrl.reverse(),
// // //         behavior:    HitTestBehavior.opaque,
// // //         child: Container(
// // //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
// // //           decoration: BoxDecoration(
// // //             color:        Colors.white,
// // //             borderRadius: BorderRadius.circular(16),
// // //             boxShadow: [
// // //               BoxShadow(
// // //                 color:        a.color.withOpacity(0.07),
// // //                 blurRadius:   16,
// // //                 spreadRadius: 0,
// // //                 offset:       const Offset(0, 4),
// // //               ),
// // //               BoxShadow(
// // //                 color:      Colors.black.withOpacity(0.03),
// // //                 blurRadius: 6,
// // //                 offset:     const Offset(0, 2),
// // //               ),
// // //             ],
// // //           ),
// // //           child: Row(
// // //             children: [
// // //               // ── Icon bubble ──────────────────────────────────────────────
// // //               Container(
// // //                 width:  48,
// // //                 height: 48,
// // //                 decoration: BoxDecoration(
// // //                   color:        a.accent,
// // //                   borderRadius: BorderRadius.circular(13),
// // //                 ),
// // //                 child: Icon(a.icon, color: a.color, size: 24),
// // //               ),
// // //
// // //               const SizedBox(width: 16),
// // //
// // //               // ── Label + subtitle ─────────────────────────────────────────
// // //               Expanded(
// // //                 child: Column(
// // //                   crossAxisAlignment: CrossAxisAlignment.start,
// // //                   mainAxisSize:       MainAxisSize.min,
// // //                   children: [
// // //                     Text(
// // //                       a.label,
// // //                       style: const TextStyle(
// // //                         fontSize:   15,
// // //                         fontWeight: FontWeight.w700,
// // //                         color:      Color(0xFF1F2937),
// // //                         height:     1.2,
// // //                       ),
// // //                     ),
// // //                     const SizedBox(height: 3),
// // //                     Text(
// // //                       a.subtitle,
// // //                       style: const TextStyle(
// // //                         fontSize:   12,
// // //                         fontWeight: FontWeight.w400,
// // //                         color:      Color(0xFF6B7280),
// // //                       ),
// // //                     ),
// // //                   ],
// // //                 ),
// // //               ),
// // //
// // //               const SizedBox(width: 8),
// // //
// // //               // ── Arrow ────────────────────────────────────────────────────
// // //               Container(
// // //                 width:  32,
// // //                 height: 32,
// // //                 decoration: BoxDecoration(
// // //                   color:        a.accent,
// // //                   borderRadius: BorderRadius.circular(9),
// // //                 ),
// // //                 child: Icon(
// // //                   Icons.arrow_forward_ios_rounded,
// // //                   color: a.color,
// // //                   size:  14,
// // //                 ),
// // //               ),
// // //             ],
// // //           ),
// // //         ),
// // //       ),
// // //     );
// // //   }
// // // }
// // //
// // // // ─────────────────────────────────────────────────────────────────────────────
// // // // Data model
// // // // ─────────────────────────────────────────────────────────────────────────────
// // // class _QuickAction {
// // //   final String   label;
// // //   final String   subtitle;
// // //   final IconData icon;
// // //   final Color    color;
// // //   final Color    accent;
// // //   final String   route;
// // //
// // //   const _QuickAction({
// // //     required this.label,
// // //     required this.subtitle,
// // //     required this.icon,
// // //     required this.color,
// // //     required this.accent,
// // //     required this.route,
// // //   });
// // // }
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:get/get.dart';
// // import '../../ViewModels/login_view_model.dart';
// // import '../HomeScreenComponents/navbar.dart';
// // import '../HomeScreenComponents/sidebar_drawer.dart';
// // import 'wagers_register_screen.dart';
// // import 'wagers_detail_screen.dart';
// //
// // // ═══════════════════════════════════════════════════════════════════════════════
// // // timekeeper_screen.dart
// // // ═══════════════════════════════════════════════════════════════════════════════
// //
// // class TimekeeperScreen extends StatefulWidget {
// //   const TimekeeperScreen({super.key});
// //
// //   @override
// //   State<TimekeeperScreen> createState() => _TimekeeperScreenState();
// // }
// //
// // class _TimekeeperScreenState extends State<TimekeeperScreen> {
// //   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
// //
// //   static const _bg       = Color(0xFFF4F6FB);
// //   static const _textMuted = Color(0xFF6B7280);
// //
// //   static const _actions = [
// //     _QuickAction(
// //       label:    'Wagers Register',
// //       subtitle: 'Enroll new wager',
// //       icon:     Icons.person_add_alt_1_rounded,
// //       color:    Color(0xFF0C6B64),
// //       accent:   Color(0xFFE0F5F3),
// //       route:    '/timekeeperRegister',
// //     ),
// //     _QuickAction(
// //       label:    'Wagers Attendance',
// //       subtitle: 'Mark daily attendance',
// //       icon:     Icons.fact_check_rounded,
// //       color:    Color(0xFF2563EB),
// //       accent:   Color(0xFFEFF6FF),
// //       route:    '/timekeeperAttendance',
// //     ),
// //     _QuickAction(
// //       label:    'Wagers Terminate',
// //       subtitle: 'Approve Terminate requests',
// //       icon:     Icons.event_busy_rounded,
// //       color:    Color(0xFFD97706),
// //       accent:   Color(0xFFFFFBEB),
// //       route:    '/timekeeperTerminate',
// //     ),
// //     _QuickAction(
// //       label:    'Wagers Detail',
// //       subtitle: 'View wagers detail',
// //       icon:     Icons.bar_chart_rounded,
// //       color:    Color(0xFF7C3AED),
// //       accent:   Color(0xFFF5F3FF),
// //       route:    '/timekeeperReports',
// //     ),
// //   ];
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final loginVM = Get.find<LoginViewModel>();
// //     final name    = loginVM.currentUser.value?.emp_name ?? 'Timekeeper';
// //
// //     final parts    = name.trim().split(' ');
// //     final initials = parts.length >= 2
// //         ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
// //         : name.isNotEmpty ? name[0].toUpperCase() : 'TK';
// //
// //     return Scaffold(
// //       key:             _scaffoldKey,
// //       backgroundColor: _bg,
// //       appBar: Navbar(
// //         userName:     name,
// //         userInitials: initials,
// //         scaffoldKey:  _scaffoldKey,
// //       ),
// //       drawer: AppDrawer(),
// //       body: Padding(
// //         padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             // ── Section label ──────────────────────────────────────────────
// //             const Text(
// //               'QUICK ACTIONS',
// //               style: TextStyle(
// //                 fontSize:      12,
// //                 fontWeight:    FontWeight.w600,
// //                 color:         _textMuted,
// //                 letterSpacing: 1.0,
// //               ),
// //             ),
// //
// //             const SizedBox(height: 14),
// //
// //             // ── Action cards — vertical column ─────────────────────────────
// //             ...List.generate(
// //               _actions.length,
// //                   (i) => Padding(
// //                 padding: EdgeInsets.only(
// //                   bottom: i < _actions.length - 1 ? 12 : 0,
// //                 ),
// //                 child: _ActionCard(action: _actions[i]),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Action Card  — horizontal row layout
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _ActionCard extends StatefulWidget {
// //   final _QuickAction action;
// //   const _ActionCard({required this.action});
// //
// //   @override
// //   State<_ActionCard> createState() => _ActionCardState();
// // }
// //
// // class _ActionCardState extends State<_ActionCard>
// //     with SingleTickerProviderStateMixin {
// //   late final AnimationController _ctrl;
// //   late final Animation<double>   _scale;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _ctrl = AnimationController(
// //       vsync:           this,
// //       duration:        const Duration(milliseconds: 100),
// //       reverseDuration: const Duration(milliseconds: 200),
// //     );
// //     _scale = Tween<double>(begin: 1.0, end: 0.97)
// //         .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
// //   }
// //
// //   @override
// //   void dispose() {
// //     _ctrl.dispose();
// //     super.dispose();
// //   }
// //
// //   void _onTap() {
// //     HapticFeedback.lightImpact();
// //     _ctrl.forward().then((_) => _ctrl.reverse());
// //
// //     if (widget.action.route == '/timekeeperRegister') {
// //       Get.to(() => const WagersRegisterScreen());
// //     } else if (widget.action.route == '/timekeeperReports') {
// //       Get.to(() => const WagersDetailScreen());
// //     }
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final a = widget.action;
// //
// //     return AnimatedBuilder(
// //       animation: _scale,
// //       builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
// //       child: GestureDetector(
// //         onTap:       _onTap,
// //         onTapDown:   (_) => _ctrl.forward(),
// //         onTapCancel: ()  => _ctrl.reverse(),
// //         behavior:    HitTestBehavior.opaque,
// //         child: Container(
// //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
// //           decoration: BoxDecoration(
// //             color:        Colors.white,
// //             borderRadius: BorderRadius.circular(16),
// //             boxShadow: [
// //               BoxShadow(
// //                 color:        a.color.withOpacity(0.07),
// //                 blurRadius:   16,
// //                 spreadRadius: 0,
// //                 offset:       const Offset(0, 4),
// //               ),
// //               BoxShadow(
// //                 color:      Colors.black.withOpacity(0.03),
// //                 blurRadius: 6,
// //                 offset:     const Offset(0, 2),
// //               ),
// //             ],
// //           ),
// //           child: Row(
// //             children: [
// //               // ── Icon bubble ──────────────────────────────────────────────
// //               Container(
// //                 width:  48,
// //                 height: 48,
// //                 decoration: BoxDecoration(
// //                   color:        a.accent,
// //                   borderRadius: BorderRadius.circular(13),
// //                 ),
// //                 child: Icon(a.icon, color: a.color, size: 24),
// //               ),
// //
// //               const SizedBox(width: 16),
// //
// //               // ── Label + subtitle ─────────────────────────────────────────
// //               Expanded(
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   mainAxisSize:       MainAxisSize.min,
// //                   children: [
// //                     Text(
// //                       a.label,
// //                       style: const TextStyle(
// //                         fontSize:   15,
// //                         fontWeight: FontWeight.w700,
// //                         color:      Color(0xFF1F2937),
// //                         height:     1.2,
// //                       ),
// //                     ),
// //                     const SizedBox(height: 3),
// //                     Text(
// //                       a.subtitle,
// //                       style: const TextStyle(
// //                         fontSize:   12,
// //                         fontWeight: FontWeight.w400,
// //                         color:      Color(0xFF6B7280),
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //
// //               const SizedBox(width: 8),
// //
// //               // ── Arrow ────────────────────────────────────────────────────
// //               Container(
// //                 width:  32,
// //                 height: 32,
// //                 decoration: BoxDecoration(
// //                   color:        a.accent,
// //                   borderRadius: BorderRadius.circular(9),
// //                 ),
// //                 child: Icon(
// //                   Icons.arrow_forward_ios_rounded,
// //                   color: a.color,
// //                   size:  14,
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Data model
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _QuickAction {
// //   final String   label;
// //   final String   subtitle;
// //   final IconData icon;
// //   final Color    color;
// //   final Color    accent;
// //   final String   route;
// //
// //   const _QuickAction({
// //     required this.label,
// //     required this.subtitle,
// //     required this.icon,
// //     required this.color,
// //     required this.accent,
// //     required this.route,
// //   });
// // }
//
//
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:get/get.dart';
// // import '../../ViewModels/login_view_model.dart';
// // import '../HomeScreenComponents/navbar.dart';
// // import '../HomeScreenComponents/sidebar_drawer.dart';
// // import 'wagers_register_screen.dart';
// //
// // // ═══════════════════════════════════════════════════════════════════════════════
// // // timekeeper_screen.dart
// // // ═══════════════════════════════════════════════════════════════════════════════
// //
// // class TimekeeperScreen extends StatefulWidget {
// //   const TimekeeperScreen({super.key});
// //
// //   @override
// //   State<TimekeeperScreen> createState() => _TimekeeperScreenState();
// // }
// //
// // class _TimekeeperScreenState extends State<TimekeeperScreen> {
// //   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
// //
// //   static const _bg       = Color(0xFFF4F6FB);
// //   static const _textMuted = Color(0xFF6B7280);
// //
// //   static const _actions = [
// //     _QuickAction(
// //       label:    'Wagers Register',
// //       subtitle: 'Enroll new wager',
// //       icon:     Icons.person_add_alt_1_rounded,
// //       color:    Color(0xFF0C6B64),
// //       accent:   Color(0xFFE0F5F3),
// //       route:    '/timekeeperRegister',
// //     ),
// //     _QuickAction(
// //       label:    'Wagers Attendance',
// //       subtitle: 'Mark daily attendance',
// //       icon:     Icons.fact_check_rounded,
// //       color:    Color(0xFF2563EB),
// //       accent:   Color(0xFFEFF6FF),
// //       route:    '/timekeeperAttendance',
// //     ),
// //     _QuickAction(
// //       label:    'Wagers Terminate',
// //       subtitle: 'Approve Terminate requests',
// //       icon:     Icons.event_busy_rounded,
// //       color:    Color(0xFFD97706),
// //       accent:   Color(0xFFFFFBEB),
// //       route:    '/timekeeperTerminate',
// //     ),
// //     _QuickAction(
// //       label:    'Wagers Detail',
// //       subtitle: 'View wagers detail',
// //       icon:     Icons.bar_chart_rounded,
// //       color:    Color(0xFF7C3AED),
// //       accent:   Color(0xFFF5F3FF),
// //       route:    '/timekeeperReports',
// //     ),
// //   ];
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final loginVM = Get.find<LoginViewModel>();
// //     final name    = loginVM.currentUser.value?.emp_name ?? 'Timekeeper';
// //
// //     final parts    = name.trim().split(' ');
// //     final initials = parts.length >= 2
// //         ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
// //         : name.isNotEmpty ? name[0].toUpperCase() : 'TK';
// //
// //     return Scaffold(
// //       key:             _scaffoldKey,
// //       backgroundColor: _bg,
// //       appBar: Navbar(
// //         userName:     name,
// //         userInitials: initials,
// //         scaffoldKey:  _scaffoldKey,
// //       ),
// //       drawer: AppDrawer(),
// //       body: Padding(
// //         padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
// //         child: Column(
// //           crossAxisAlignment: CrossAxisAlignment.start,
// //           children: [
// //             // ── Section label ──────────────────────────────────────────────
// //             const Text(
// //               'QUICK ACTIONS',
// //               style: TextStyle(
// //                 fontSize:      12,
// //                 fontWeight:    FontWeight.w600,
// //                 color:         _textMuted,
// //                 letterSpacing: 1.0,
// //               ),
// //             ),
// //
// //             const SizedBox(height: 14),
// //
// //             // ── Action cards — vertical column ─────────────────────────────
// //             ...List.generate(
// //               _actions.length,
// //                   (i) => Padding(
// //                 padding: EdgeInsets.only(
// //                   bottom: i < _actions.length - 1 ? 12 : 0,
// //                 ),
// //                 child: _ActionCard(action: _actions[i]),
// //               ),
// //             ),
// //           ],
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Action Card  — horizontal row layout
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _ActionCard extends StatefulWidget {
// //   final _QuickAction action;
// //   const _ActionCard({required this.action});
// //
// //   @override
// //   State<_ActionCard> createState() => _ActionCardState();
// // }
// //
// // class _ActionCardState extends State<_ActionCard>
// //     with SingleTickerProviderStateMixin {
// //   late final AnimationController _ctrl;
// //   late final Animation<double>   _scale;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _ctrl = AnimationController(
// //       vsync:           this,
// //       duration:        const Duration(milliseconds: 100),
// //       reverseDuration: const Duration(milliseconds: 200),
// //     );
// //     _scale = Tween<double>(begin: 1.0, end: 0.97)
// //         .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
// //   }
// //
// //   @override
// //   void dispose() {
// //     _ctrl.dispose();
// //     super.dispose();
// //   }
// //
// //   void _onTap() {
// //     HapticFeedback.lightImpact();
// //     _ctrl.forward().then((_) => _ctrl.reverse());
// //
// //     if (widget.action.route == '/timekeeperRegister') {
// //       Get.to(() => const WagersRegisterScreen());
// //     }
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final a = widget.action;
// //
// //     return AnimatedBuilder(
// //       animation: _scale,
// //       builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
// //       child: GestureDetector(
// //         onTap:       _onTap,
// //         onTapDown:   (_) => _ctrl.forward(),
// //         onTapCancel: ()  => _ctrl.reverse(),
// //         behavior:    HitTestBehavior.opaque,
// //         child: Container(
// //           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
// //           decoration: BoxDecoration(
// //             color:        Colors.white,
// //             borderRadius: BorderRadius.circular(16),
// //             boxShadow: [
// //               BoxShadow(
// //                 color:        a.color.withOpacity(0.07),
// //                 blurRadius:   16,
// //                 spreadRadius: 0,
// //                 offset:       const Offset(0, 4),
// //               ),
// //               BoxShadow(
// //                 color:      Colors.black.withOpacity(0.03),
// //                 blurRadius: 6,
// //                 offset:     const Offset(0, 2),
// //               ),
// //             ],
// //           ),
// //           child: Row(
// //             children: [
// //               // ── Icon bubble ──────────────────────────────────────────────
// //               Container(
// //                 width:  48,
// //                 height: 48,
// //                 decoration: BoxDecoration(
// //                   color:        a.accent,
// //                   borderRadius: BorderRadius.circular(13),
// //                 ),
// //                 child: Icon(a.icon, color: a.color, size: 24),
// //               ),
// //
// //               const SizedBox(width: 16),
// //
// //               // ── Label + subtitle ─────────────────────────────────────────
// //               Expanded(
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   mainAxisSize:       MainAxisSize.min,
// //                   children: [
// //                     Text(
// //                       a.label,
// //                       style: const TextStyle(
// //                         fontSize:   15,
// //                         fontWeight: FontWeight.w700,
// //                         color:      Color(0xFF1F2937),
// //                         height:     1.2,
// //                       ),
// //                     ),
// //                     const SizedBox(height: 3),
// //                     Text(
// //                       a.subtitle,
// //                       style: const TextStyle(
// //                         fontSize:   12,
// //                         fontWeight: FontWeight.w400,
// //                         color:      Color(0xFF6B7280),
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //
// //               const SizedBox(width: 8),
// //
// //               // ── Arrow ────────────────────────────────────────────────────
// //               Container(
// //                 width:  32,
// //                 height: 32,
// //                 decoration: BoxDecoration(
// //                   color:        a.accent,
// //                   borderRadius: BorderRadius.circular(9),
// //                 ),
// //                 child: Icon(
// //                   Icons.arrow_forward_ios_rounded,
// //                   color: a.color,
// //                   size:  14,
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// // }
// //
// // // ─────────────────────────────────────────────────────────────────────────────
// // // Data model
// // // ─────────────────────────────────────────────────────────────────────────────
// // class _QuickAction {
// //   final String   label;
// //   final String   subtitle;
// //   final IconData icon;
// //   final Color    color;
// //   final Color    accent;
// //   final String   route;
// //
// //   const _QuickAction({
// //     required this.label,
// //     required this.subtitle,
// //     required this.icon,
// //     required this.color,
// //     required this.accent,
// //     required this.route,
// //   });
// // }
// import 'package:GPS_Workforce_Monitor/Screens/TimeKeeper/wagers_terminate_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import '../../ViewModels/login_view_model.dart';
// import '../HomeScreenComponents/navbar.dart';
// import '../HomeScreenComponents/sidebar_drawer.dart';
// import 'wagers_register_screen.dart';
// import 'wagers_detail_screen.dart';
// import 'wagers_attendance_screen.dart';
//
// // ═══════════════════════════════════════════════════════════════════════════════
// // timekeeper_screen.dart
// // ═══════════════════════════════════════════════════════════════════════════════
//
// class TimekeeperScreen extends StatefulWidget {
//   const TimekeeperScreen({super.key});
//
//   @override
//   State<TimekeeperScreen> createState() => _TimekeeperScreenState();
// }
//
// class _TimekeeperScreenState extends State<TimekeeperScreen> {
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   static const _bg       = Color(0xFFF4F6FB);
//   static const _textMuted = Color(0xFF6B7280);
//
//   static const _actions = [
//     _QuickAction(
//       label:    'Wagers Register',
//       subtitle: 'Enroll new wager',
//       icon:     Icons.person_add_alt_1_rounded,
//       color:    Color(0xFF0C6B64),
//       accent:   Color(0xFFE0F5F3),
//       route:    '/timekeeperRegister',
//     ),
//     _QuickAction(
//       label:    'Wagers Attendance',
//       subtitle: 'Mark daily attendance',
//       icon:     Icons.fact_check_rounded,
//       color:    Color(0xFF2563EB),
//       accent:   Color(0xFFEFF6FF),
//       route:    '/timekeeperAttendance',
//     ),
//     _QuickAction(
//       label:    'Wagers Terminate',
//       subtitle: 'Terminate Wagers',
//       icon:     Icons.event_busy_rounded,
//       color:    Color(0xFFD97706),
//       accent:   Color(0xFFFFFBEB),
//       route:    '/timekeeperTerminate',
//     ),
//     _QuickAction(
//       label:    'Wagers Detail',
//       subtitle: 'View wagers detail',
//       icon:     Icons.bar_chart_rounded,
//       color:    Color(0xFF7C3AED),
//       accent:   Color(0xFFF5F3FF),
//       route:    '/timekeeperReports',
//     ),
//   ];
//
//   @override
//   Widget build(BuildContext context) {
//     final loginVM = Get.find<LoginViewModel>();
//     final name    = loginVM.currentUser.value?.emp_name ?? 'Timekeeper';
//
//     final parts    = name.trim().split(' ');
//     final initials = parts.length >= 2
//         ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
//         : name.isNotEmpty ? name[0].toUpperCase() : 'TK';
//
//     return Scaffold(
//       key:             _scaffoldKey,
//       backgroundColor: _bg,
//       appBar: Navbar(
//         userName:     name,
//         userInitials: initials,
//         scaffoldKey:  _scaffoldKey,
//       ),
//       drawer: AppDrawer(),
//       body: Padding(
//         padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // ── Section label ──────────────────────────────────────────────
//             const Text(
//               'QUICK ACTIONS',
//               style: TextStyle(
//                 fontSize:      12,
//                 fontWeight:    FontWeight.w600,
//                 color:         _textMuted,
//                 letterSpacing: 1.0,
//               ),
//             ),
//
//             const SizedBox(height: 14),
//
//             // ── Action cards — vertical column ─────────────────────────────
//             ...List.generate(
//               _actions.length,
//                   (i) => Padding(
//                 padding: EdgeInsets.only(
//                   bottom: i < _actions.length - 1 ? 12 : 0,
//                 ),
//                 child: _ActionCard(action: _actions[i]),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Action Card  — horizontal row layout
// // ─────────────────────────────────────────────────────────────────────────────
// class _ActionCard extends StatefulWidget {
//   final _QuickAction action;
//   const _ActionCard({required this.action});
//
//   @override
//   State<_ActionCard> createState() => _ActionCardState();
// }
//
// class _ActionCardState extends State<_ActionCard>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _ctrl;
//   late final Animation<double>   _scale;
//
//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//       vsync:           this,
//       duration:        const Duration(milliseconds: 100),
//       reverseDuration: const Duration(milliseconds: 200),
//     );
//     _scale = Tween<double>(begin: 1.0, end: 0.97)
//         .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
//   }
//
//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }
//
//   void _onTap() {
//     HapticFeedback.lightImpact();
//     _ctrl.forward().then((_) => _ctrl.reverse());
//
//     if (widget.action.route == '/timekeeperRegister') {
//       Get.to(() => const WagersRegisterScreen());
//     } else if (widget.action.route == '/timekeeperAttendance') {
//       Get.to(() => const WagersAttendanceScreen());
//     } else if (widget.action.route == '/timekeeperReports') {
//       Get.to(() => const WagersDetailScreen());
//     } else if (widget.action.route == '/timekeeperTerminate') {
//       Get.to(() => const WagersTerminateScreen());
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final a = widget.action;
//
//     return AnimatedBuilder(
//       animation: _scale,
//       builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
//       child: GestureDetector(
//         onTap:       _onTap,
//         onTapDown:   (_) => _ctrl.forward(),
//         onTapCancel: ()  => _ctrl.reverse(),
//         behavior:    HitTestBehavior.opaque,
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//           decoration: BoxDecoration(
//             color:        Colors.white,
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color:        a.color.withOpacity(0.07),
//                 blurRadius:   16,
//                 spreadRadius: 0,
//                 offset:       const Offset(0, 4),
//               ),
//               BoxShadow(
//                 color:      Colors.black.withOpacity(0.03),
//                 blurRadius: 6,
//                 offset:     const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Row(
//             children: [
//               // ── Icon bubble ──────────────────────────────────────────────
//               Container(
//                 width:  48,
//                 height: 48,
//                 decoration: BoxDecoration(
//                   color:        a.accent,
//                   borderRadius: BorderRadius.circular(13),
//                 ),
//                 child: Icon(a.icon, color: a.color, size: 24),
//               ),
//
//               const SizedBox(width: 16),
//
//               // ── Label + subtitle ─────────────────────────────────────────
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize:       MainAxisSize.min,
//                   children: [
//                     Text(
//                       a.label,
//                       style: const TextStyle(
//                         fontSize:   15,
//                         fontWeight: FontWeight.w700,
//                         color:      Color(0xFF1F2937),
//                         height:     1.2,
//                       ),
//                     ),
//                     const SizedBox(height: 3),
//                     Text(
//                       a.subtitle,
//                       style: const TextStyle(
//                         fontSize:   12,
//                         fontWeight: FontWeight.w400,
//                         color:      Color(0xFF6B7280),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(width: 8),
//
//               // ── Arrow ────────────────────────────────────────────────────
//               Container(
//                 width:  32,
//                 height: 32,
//                 decoration: BoxDecoration(
//                   color:        a.accent,
//                   borderRadius: BorderRadius.circular(9),
//                 ),
//                 child: Icon(
//                   Icons.arrow_forward_ios_rounded,
//                   color: a.color,
//                   size:  14,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Data model
// // ─────────────────────────────────────────────────────────────────────────────
// class _QuickAction {
//   final String   label;
//   final String   subtitle;
//   final IconData icon;
//   final Color    color;
//   final Color    accent;
//   final String   route;
//
//   const _QuickAction({
//     required this.label,
//     required this.subtitle,
//     required this.icon,
//     required this.color,
//     required this.accent,
//     required this.route,
//   });
// }


import 'package:book_dispatch/Screens/TimeKeeper/wagers_terminate_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../ViewModels/login_view_model.dart';
import '../HomeScreenComponents/navbar.dart';
import '../HomeScreenComponents/sidebar_drawer.dart';
import 'wagers_register_screen.dart';
import 'wagers_detail_screen.dart';
import 'wagers_attendance_screen.dart';
import '../HomeScreenComponents/app_bottom_navbar.dart'; // Add this import

// ═══════════════════════════════════════════════════════════════════════════════
// timekeeper_screen.dart
// ═══════════════════════════════════════════════════════════════════════════════

class TimekeeperScreen extends StatefulWidget {
  final int currentIndex;
  final int chatBadgeCount;
  final ValueChanged<int> onNavTap;

  const TimekeeperScreen({
    super.key,
    this.currentIndex = 7, // TimeKeeper tab index in _allTabs
    this.chatBadgeCount = 0,
    required this.onNavTap,
  });

  @override
  State<TimekeeperScreen> createState() => _TimekeeperScreenState();
}

class _TimekeeperScreenState extends State<TimekeeperScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _bg       = Color(0xFFF4F6FB);
  static const _textMuted = Color(0xFF6B7280);

  static const _actions = [
    _QuickAction(
      label:    'Wagers Register',
      subtitle: 'Enroll new wager',
      icon:     Icons.person_add_alt_1_rounded,
      color:    Color(0xFF0C6B64),
      accent:   Color(0xFFE0F5F3),
      route:    '/timekeeperRegister',
    ),
    _QuickAction(
      label:    'Wagers Attendance',
      subtitle: 'Mark daily attendance',
      icon:     Icons.fact_check_rounded,
      color:    Color(0xFF2563EB),
      accent:   Color(0xFFEFF6FF),
      route:    '/timekeeperAttendance',
    ),
    _QuickAction(
      label:    'Wagers Terminate',
      subtitle: 'Terminate Wagers',
      icon:     Icons.event_busy_rounded,
      color:    Color(0xFFD97706),
      accent:   Color(0xFFFFFBEB),
      route:    '/timekeeperTerminate',
    ),
    _QuickAction(
      label:    'Wagers Detail',
      subtitle: 'View wagers detail',
      icon:     Icons.bar_chart_rounded,
      color:    Color(0xFF7C3AED),
      accent:   Color(0xFFF5F3FF),
      route:    '/timekeeperReports',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final loginVM = Get.find<LoginViewModel>();
    final name    = loginVM.currentUser.value?.emp_name ?? 'Timekeeper';

    final parts    = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty ? name[0].toUpperCase() : 'TK';

    return Scaffold(
      key:             _scaffoldKey,
      backgroundColor: _bg,
      appBar: Navbar(
        userName:     name,
        userInitials: initials,
        scaffoldKey:  _scaffoldKey,
      ),
      drawer: AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section label ──────────────────────────────────────────────
            const Text(
              'QUICK ACTIONS',
              style: TextStyle(
                fontSize:      12,
                fontWeight:    FontWeight.w600,
                color:         _textMuted,
                letterSpacing: 1.0,
              ),
            ),

            const SizedBox(height: 14),

            // ── Action cards — vertical column ─────────────────────────────
            ...List.generate(
              _actions.length,
                  (i) => Padding(
                padding: EdgeInsets.only(
                  bottom: i < _actions.length - 1 ? 12 : 0,
                ),
                child: _ActionCard(action: _actions[i]),
              ),
            ),
          ],
        ),
      ),
      // ── Bottom navigation bar ────────────────────────────────────────────
      bottomNavigationBar: AppBottomNavBar(
        currentIndex:   widget.currentIndex,
        chatBadgeCount: widget.chatBadgeCount,
        onTap:          widget.onNavTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Card  — horizontal row layout
// ─────────────────────────────────────────────────────────────────────────────
class _ActionCard extends StatefulWidget {
  final _QuickAction action;
  const _ActionCard({required this.action});

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:           this,
      duration:        const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    _ctrl.forward().then((_) => _ctrl.reverse());

    if (widget.action.route == '/timekeeperRegister') {
      Get.to(() => const WagersRegisterScreen());
    } else if (widget.action.route == '/timekeeperAttendance') {
      Get.to(() => const WagersAttendanceScreen());
    } else if (widget.action.route == '/timekeeperReports') {
      Get.to(() => const WagersDetailScreen());
    } else if (widget.action.route == '/timekeeperTerminate') {
      Get.to(() => const WagersTerminateScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.action;

    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTap:       _onTap,
        onTapDown:   (_) => _ctrl.forward(),
        onTapCancel: ()  => _ctrl.reverse(),
        behavior:    HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:        a.color.withOpacity(0.07),
                blurRadius:   16,
                spreadRadius: 0,
                offset:       const Offset(0, 4),
              ),
              BoxShadow(
                color:      Colors.black.withOpacity(0.03),
                blurRadius: 6,
                offset:     const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Icon bubble ──────────────────────────────────────────────
              Container(
                width:  48,
                height: 48,
                decoration: BoxDecoration(
                  color:        a.accent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(a.icon, color: a.color, size: 24),
              ),

              const SizedBox(width: 16),

              // ── Label + subtitle ─────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize:       MainAxisSize.min,
                  children: [
                    Text(
                      a.label,
                      style: const TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.w700,
                        color:      Color(0xFF1F2937),
                        height:     1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      a.subtitle,
                      style: const TextStyle(
                        fontSize:   12,
                        fontWeight: FontWeight.w400,
                        color:      Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── Arrow ────────────────────────────────────────────────────
              Container(
                width:  32,
                height: 32,
                decoration: BoxDecoration(
                  color:        a.accent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: a.color,
                  size:  14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────
class _QuickAction {
  final String   label;
  final String   subtitle;
  final IconData icon;
  final Color    color;
  final Color    accent;
  final String   route;

  const _QuickAction({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.accent,
    required this.route,
  });
}