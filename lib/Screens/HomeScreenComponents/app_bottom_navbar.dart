//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import '../TimeKeeper/time_keeper.dart';
// import '../actions_screen.dart';
// import '../break_screen.dart';
// import '../schedule_hub_screen.dart';
// import '../../ViewModels/login_view_model.dart';
// import '../task_screen.dart';
// import '../company_screen.dart';
//
// // ═══════════════════════════════════════════════════════════════════════════
// // app_bottom_navbar.dart  —  Style 3: Circle Bubble
// //
// // TimeKeeper tab shown only when LoginViewModel.isTimekeeper == true.
// // ═══════════════════════════════════════════════════════════════════════════
//
// class AppBottomNavBar extends StatefulWidget {
//   final int currentIndex;
//   final int chatBadgeCount;
//   final ValueChanged<int> onTap;
//
//   const AppBottomNavBar({
//     super.key,
//     required this.currentIndex,
//     required this.onTap,
//     this.chatBadgeCount = 0,
//   });
//
//   @override
//   State<AppBottomNavBar> createState() => _AppBottomNavBarState();
// }
//
// class _AppBottomNavBarState extends State<AppBottomNavBar>
//     with TickerProviderStateMixin {
//
//   // ── Design Tokens ──────────────────────────────────────────────────────
//   static const _bgColor    = Colors.white60;
//   static const _activeBg   = Color(0xFF14B8A6);
//   static const _activeGlow = Color(0xFF14B8A6);
//   static const _mutedIcon  = Color(0xFF4B5563);
//   static const _activeIcon = Colors.white;
//
//   // ── All possible tabs — TimeKeeper is last, flagged isTimekeeper=true ──
//   static const _allTabs = [
//     _NavTab(icon: Icons.home_outlined,           activeIcon: Icons.home_rounded,        label: 'Home'),
//     _NavTab(icon: Icons.bolt_outlined,           activeIcon: Icons.bolt_rounded,         label: 'Actions'),
//     _NavTab(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month,       label: 'Schedule'),
//     _NavTab(icon: Icons.checklist_outlined,      activeIcon: Icons.checklist_rounded,    label: 'Tasks'),
//     _NavTab(icon: Icons.coffee_outlined,         activeIcon: Icons.coffee_rounded,       label: 'Breaks'),
//     _NavTab(icon: Icons.business_outlined,       activeIcon: Icons.business_rounded,     label: 'Company'),
//     _NavTab(icon: Icons.timer_outlined,          activeIcon: Icons.timer_rounded,        label: 'TimeKeeper', isTimekeeper: true),
//   ];
//
//   static const int _maxTabs = 8; // always allocate controllers for all tabs
//
//   late final List<AnimationController> _pressControllers;
//   late final List<Animation<double>>   _pressAnimations;
//   late final List<AnimationController> _bubbleControllers;
//   late final List<Animation<double>>   _bubbleAnimations;
//
//   // ── Scroll state ──────────────────────────────────────────────────────
//   final ScrollController _scrollController = ScrollController();
//   bool _canScrollLeft = false;   // Arrow on left side
//   bool _canScrollRight = false;  // Arrow on right side
//
//   @override
//   void initState() {
//     super.initState();
//
//     _pressControllers = List.generate(
//       _maxTabs,
//           (i) => AnimationController(
//         vsync: this,
//         duration: const Duration(milliseconds: 120),
//         reverseDuration: const Duration(milliseconds: 200),
//       ),
//     );
//     _pressAnimations = _pressControllers
//         .map((c) => Tween<double>(begin: 1.0, end: 0.88)
//         .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
//         .toList();
//
//     _bubbleControllers = List.generate(
//       _maxTabs,
//           (i) => AnimationController(
//         vsync: this,
//         duration: const Duration(milliseconds: 300),
//         value: i == widget.currentIndex ? 1.0 : 0.0,
//       ),
//     );
//     _bubbleAnimations = _bubbleControllers
//         .map((c) => CurvedAnimation(
//       parent: c,
//       curve: Curves.easeOutBack,
//       reverseCurve: Curves.easeInCubic,
//     ))
//         .toList();
//
//     _scrollController.addListener(_onScroll);
//   }
//
//   void _onScroll() {
//     if (!_scrollController.hasClients) return;
//     final position = _scrollController.position;
//     final maxScroll = position.maxScrollExtent;
//     final pixels = position.pixels;
//
//     final canScrollLeft = maxScroll > 0 && pixels > 4;
//     final canScrollRight = maxScroll > 0 && pixels < maxScroll - 4;
//
//     if (canScrollLeft != _canScrollLeft || canScrollRight != _canScrollRight) {
//       setState(() {
//         _canScrollLeft = canScrollLeft;
//         _canScrollRight = canScrollRight;
//       });
//     }
//   }
//
//   @override
//   void didUpdateWidget(AppBottomNavBar old) {
//     super.didUpdateWidget(old);
//     if (old.currentIndex != widget.currentIndex) {
//       _bubbleControllers[old.currentIndex].reverse();
//       _bubbleControllers[widget.currentIndex].forward();
//     }
//   }
//
//   @override
//   void dispose() {
//     for (final c in _pressControllers) c.dispose();
//     for (final c in _bubbleControllers) c.dispose();
//     _scrollController.dispose();
//     super.dispose();
//   }
//
//   /// Filter tabs: hide TimeKeeper unless the logged-in user has the role.
//   List<_NavTab> _visibleTabs(bool isTimekeeper) =>
//       _allTabs.where((t) => !t.isTimekeeper || isTimekeeper).toList();
//
//   void _handleTap(int visibleIndex, List<_NavTab> tabs) {
//     final tab = tabs[visibleIndex];
//     final allTabIndex = _allTabs.indexOf(tab);
//
//     HapticFeedback.lightImpact();
//     _pressControllers[allTabIndex].forward().then((_) {
//       _pressControllers[allTabIndex].reverse();
//     });
//
//     // ── Actions tab (index 1) ─────────────────────────────────────────────
//     if (allTabIndex == 1) {
//       if (widget.currentIndex == 1) return;
//
//       // ✅ Fix: Check if we can pop before trying
//       final navigator = Navigator.of(context, rootNavigator: true);
//
//       Navigator.push(
//         context,
//         PageRouteBuilder(
//           pageBuilder: (context, animation, secondaryAnimation) => ActionsScreen(
//             currentIndex: 1,
//             chatBadgeCount: widget.chatBadgeCount,
//             onNavTap: (i) {
//               // ✅ Fix: Safe pop with fallback
//               if (navigator.canPop()) {
//                 navigator.pop();
//               }
//               widget.onTap(i);
//             },
//           ),
//           transitionsBuilder: (context, animation, secondaryAnimation, child) {
//             final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
//             final slide = Tween<Offset>(begin: const Offset(0.0, 0.018), end: Offset.zero)
//                 .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
//             final scale = Tween<double>(begin: 0.97, end: 1.0)
//                 .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
//             return FadeTransition(
//               opacity: fade,
//               child: ScaleTransition(
//                 scale: scale,
//                 alignment: Alignment.bottomCenter,
//                 child: SlideTransition(position: slide, child: child),
//               ),
//             );
//           },
//           transitionDuration: const Duration(milliseconds: 260),
//         ),
//       );
//       return;
//     }
//
//     // ── Schedule tab (index 2) ────────────────────────────────────────────
//     if (allTabIndex == 2) {
//       if (widget.currentIndex == 2) return;
//
//       final navigator = Navigator.of(context, rootNavigator: true);
//
//       Navigator.push(
//         context,
//         PageRouteBuilder(
//           pageBuilder: (context, animation, secondaryAnimation) => ScheduleHubScreen(
//             currentIndex: 2,
//             chatBadgeCount: widget.chatBadgeCount,
//             onNavTap: (i) {
//               if (navigator.canPop()) {
//                 navigator.pop();
//               }
//               widget.onTap(i);
//             },
//           ),
//           transitionsBuilder: (context, animation, secondaryAnimation, child) {
//             final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
//             final slide = Tween<Offset>(begin: const Offset(0.0, 0.018), end: Offset.zero)
//                 .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
//             final scale = Tween<double>(begin: 0.97, end: 1.0)
//                 .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
//             return FadeTransition(
//               opacity: fade,
//               child: ScaleTransition(
//                 scale: scale,
//                 alignment: Alignment.bottomCenter,
//                 child: SlideTransition(position: slide, child: child),
//               ),
//             );
//           },
//           transitionDuration: const Duration(milliseconds: 260),
//         ),
//       );
//       return;
//     }
//
//     // ── Tasks tab (index 3) ───────────────────────────────────────────────
//     if (allTabIndex == 3) {
//       if (widget.currentIndex == 3) return;
//
//       final navigator = Navigator.of(context, rootNavigator: true);
//
//       Navigator.push(
//         context,
//         PageRouteBuilder(
//           pageBuilder: (context, animation, secondaryAnimation) => TaskScreen(
//             currentIndex: 3,
//             chatBadgeCount: widget.chatBadgeCount,
//             onNavTap: (i) {
//               if (navigator.canPop()) {
//                 navigator.pop();
//               }
//               widget.onTap(i);
//             },
//           ),
//           transitionsBuilder: (context, animation, secondaryAnimation, child) {
//             final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
//             final scale = Tween<double>(begin: 0.97, end: 1.0)
//                 .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
//             return FadeTransition(
//               opacity: fade,
//               child: ScaleTransition(
//                 scale: scale,
//                 alignment: Alignment.bottomCenter,
//                 child: child,
//               ),
//             );
//           },
//           transitionDuration: const Duration(milliseconds: 260),
//         ),
//       );
//       return;
//     }
//
//     // ── Breaks tab (index 4) ──────────────────────────────────────────────
//     if (allTabIndex == 4) {
//       if (widget.currentIndex == 4) return;
//
//       final navigator = Navigator.of(context, rootNavigator: true);
//
//       Navigator.push(
//         context,
//         PageRouteBuilder(
//           pageBuilder: (_, __, ___) => BreaksScreen(
//             currentIndex: 4,
//             chatBadgeCount: widget.chatBadgeCount,
//             onNavTap: (i) {
//               if (navigator.canPop()) {
//                 navigator.pop();
//               }
//               widget.onTap(i);
//             },
//           ),
//           transitionsBuilder: (_, animation, __, child) {
//             final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
//             final scale = Tween<double>(begin: 0.97, end: 1.0)
//                 .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
//             return FadeTransition(
//               opacity: fade,
//               child: ScaleTransition(
//                 scale: scale,
//                 alignment: Alignment.bottomCenter,
//                 child: child,
//               ),
//             );
//           },
//           transitionDuration: const Duration(milliseconds: 260),
//         ),
//       );
//       return;
//     }
//
//     // ── Company tab (index 5) ─────────────────────────────────────────────
//     if (allTabIndex == 5) {
//       if (widget.currentIndex == 5) return;
//
//       final navigator = Navigator.of(context, rootNavigator: true);
//
//       Navigator.push(
//         context,
//         PageRouteBuilder(
//           pageBuilder: (context, animation, secondaryAnimation) => CompanyScreen(
//             currentIndex: 5,
//             chatBadgeCount: widget.chatBadgeCount,
//             onNavTap: (i) {
//               if (navigator.canPop()) {
//                 navigator.pop();
//               }
//               widget.onTap(i);
//             },
//           ),
//           transitionsBuilder: (context, animation, secondaryAnimation, child) {
//             final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
//             final slide = Tween<Offset>(begin: const Offset(0.0, 0.018), end: Offset.zero)
//                 .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
//             final scale = Tween<double>(begin: 0.97, end: 1.0)
//                 .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
//             return FadeTransition(
//               opacity: fade,
//               child: ScaleTransition(
//                 scale: scale,
//                 alignment: Alignment.bottomCenter,
//                 child: SlideTransition(position: slide, child: child),
//               ),
//             );
//           },
//           transitionDuration: const Duration(milliseconds: 260),
//         ),
//       );
//       return;
//     }
//
//     // ── TimeKeeper tab (index 6) ──────────────────────────────────────────
//     if (tab.isTimekeeper) {
//       if (widget.currentIndex == 6) return;
//
//       final navigator = Navigator.of(context, rootNavigator: true);
//
//       Navigator.push(
//         context,
//         PageRouteBuilder(
//           pageBuilder: (context, animation, secondaryAnimation) => TimekeeperScreen(
//             currentIndex: 6,
//             chatBadgeCount: widget.chatBadgeCount,
//             onNavTap: (i) {
//               if (navigator.canPop()) {
//                 navigator.pop();
//               }
//               widget.onTap(i);
//             },
//           ),
//           transitionsBuilder: (context, animation, secondaryAnimation, child) {
//             final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
//             final slide = Tween<Offset>(begin: const Offset(0.0, 0.018), end: Offset.zero)
//                 .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
//             final scale = Tween<double>(begin: 0.97, end: 1.0)
//                 .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
//             return FadeTransition(
//               opacity: fade,
//               child: ScaleTransition(
//                 scale: scale,
//                 alignment: Alignment.bottomCenter,
//                 child: SlideTransition(position: slide, child: child),
//               ),
//             );
//           },
//           transitionDuration: const Duration(milliseconds: 260),
//         ),
//       );
//       return;
//     }
//
//     // ── Default: Home tab or others ──────────────────────────────────────
//     widget.onTap(allTabIndex);
//   }
//
//
//   /// Builds a single arrow hint widget
//   Widget _buildArrowHint(bool showLeft) {
//     return Positioned(
//       left: showLeft ? 0 : null,
//       right: showLeft ? null : 0,
//       top: 0,
//       bottom: 0,
//       child: IgnorePointer(
//         child: Row(
//           children: [
//             if (showLeft)
//               Container(
//                 width: 30,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.centerLeft,
//                     end: Alignment.centerRight,
//                     colors: [
//                       _bgColor.withOpacity(0.95),
//                       _bgColor.withOpacity(0.0),
//                     ],
//                   ),
//                 ),
//               ),
//             Container(
//               width: 22,
//               height: 22,
//               margin: EdgeInsets.only(
//                 left: showLeft ? 6 : 0,
//                 right: showLeft ? 0 : 6,
//               ),
//               decoration: BoxDecoration(
//                 color: _activeBg,
//                 shape: BoxShape.circle,
//                 boxShadow: [
//                   BoxShadow(
//                     color: _activeGlow.withOpacity(0.35),
//                     blurRadius: 8,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Icon(
//                 showLeft ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
//                 size: 16,
//                 color: Colors.white,
//               ),
//             ),
//             if (!showLeft)
//               Container(
//                 width: 30,
//                 decoration: BoxDecoration(
//                   gradient: LinearGradient(
//                     begin: Alignment.centerLeft,
//                     end: Alignment.centerRight,
//                     colors: [
//                       _bgColor.withOpacity(0.0),
//                       _bgColor.withOpacity(0.95),
//                     ],
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final bottomPadding = MediaQuery.of(context).padding.bottom;
//     final loginVM       = Get.find<LoginViewModel>();
//
//     return Obx(() {
//       final tabs = _visibleTabs(loginVM.isTimekeeper.value);
//
//       WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
//
//       return Container(
//         color: _bgColor,
//         padding: EdgeInsets.only(
//           top: 8,
//           bottom: bottomPadding > 0 ? bottomPadding : 12,
//         ),
//         child: Stack(
//           children: [
//             SingleChildScrollView(
//               controller: _scrollController,
//               scrollDirection: Axis.horizontal,
//               physics: const BouncingScrollPhysics(),
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Row(
//                 children: List.generate(tabs.length, (i) => _buildTab(i, tabs)),
//               ),
//             ),
//
//             // ── Left arrow hint ──────────────────────────────────────────
//             if (_canScrollLeft) _buildArrowHint(true),
//
//             // ── Right arrow hint ─────────────────────────────────────────
//             if (_canScrollRight) _buildArrowHint(false),
//           ],
//         ),
//       );
//     });
//   }
//
//   Widget _buildTab(int visibleIndex, List<_NavTab> tabs) {
//     final tab         = tabs[visibleIndex];
//     final allTabIndex = _allTabs.indexOf(tab);
//     final isActive    = widget.currentIndex == allTabIndex;
//
//     return AnimatedBuilder(
//       animation: _pressAnimations[allTabIndex],
//       builder: (context, child) => Transform.scale(
//         scale: _pressAnimations[allTabIndex].value,
//         child: child,
//       ),
//       child: GestureDetector(
//         onTap: () => _handleTap(visibleIndex, tabs),
//         behavior: HitTestBehavior.opaque,
//         child: SizedBox(
//           width: 60,
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // ── Circle bubble ──────────────────────────────────────────
//               AnimatedBuilder(
//                 animation: _bubbleAnimations[allTabIndex],
//                 builder: (context, _) {
//                   final t = _bubbleAnimations[allTabIndex].value;
//                   return Stack(
//                     alignment: Alignment.center,
//                     children: [
//                       Container(
//                         width: 42,
//                         height: 42,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           color: Color.lerp(Colors.transparent, _activeBg, t),
//                           boxShadow: t > 0.1
//                               ? [
//                             BoxShadow(
//                               color: _activeGlow.withOpacity(0.50 * t),
//                               blurRadius: 18,
//                               spreadRadius: 0,
//                               offset: const Offset(0, 4),
//                             ),
//                           ]
//                               : [],
//                         ),
//                         child: Icon(
//                           isActive ? tab.activeIcon : tab.icon,
//                           size: 20,
//                           color: Color.lerp(_mutedIcon, _activeIcon, t),
//                         ),
//                       ),
//                       if (tab.hasChat && widget.chatBadgeCount > 0)
//                         Positioned(
//                           top: 2,
//                           right: 6,
//                           child: _ChatBadge(count: widget.chatBadgeCount),
//                         ),
//                     ],
//                   );
//                 },
//               ),
//
//               const SizedBox(height: 5),
//
//               // ── Label ──────────────────────────────────────────────────
//               AnimatedDefaultTextStyle(
//                 duration: const Duration(milliseconds: 200),
//                 style: TextStyle(
//                   fontSize: 10,
//                   fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
//                   color: isActive ? _activeBg : _mutedIcon,
//                   letterSpacing: 0.1,
//                   height: 1.0,
//                 ),
//                 child: Text(tab.label, textAlign: TextAlign.center),
//               ),
//
//               const SizedBox(height: 2),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ─────────────────────────────────────────────────────────────────────────────
// // Chat Badge
// // ─────────────────────────────────────────────────────────────────────────────
// class _ChatBadge extends StatefulWidget {
//   final int count;
//   const _ChatBadge({required this.count});
//
//   @override
//   State<_ChatBadge> createState() => _ChatBadgeState();
// }
//
// class _ChatBadgeState extends State<_ChatBadge>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _pulseCtrl;
//   late final Animation<double>   _pulse;
//
//   @override
//   void initState() {
//     super.initState();
//     _pulseCtrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1400),
//     )..repeat(reverse: true);
//     _pulse = Tween<double>(begin: 0.85, end: 1.15)
//         .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
//   }
//
//   @override
//   void dispose() {
//     _pulseCtrl.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return AnimatedBuilder(
//       animation: _pulse,
//       builder: (_, __) => Transform.scale(
//         scale: _pulse.value,
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
//           constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
//           decoration: BoxDecoration(
//             color: const Color(0xFFEF4444),
//             borderRadius: BorderRadius.circular(8),
//             boxShadow: [
//               BoxShadow(
//                 color: const Color(0xFFEF4444).withOpacity(0.4),
//                 blurRadius: 6,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Text(
//             widget.count > 9 ? '9+' : '${widget.count}',
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 7,
//               fontWeight: FontWeight.w800,
//               height: 1.2,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ── Data model ────────────────────────────────────────────────────────────────
// class _NavTab {
//   final IconData icon;
//   final IconData activeIcon;
//   final String   label;
//   final bool     hasChat;
//   final bool     isTimekeeper;
//
//   const _NavTab({
//     required this.icon,
//     required this.activeIcon,
//     required this.label,
//     this.hasChat      = false,
//     this.isTimekeeper = false,
//   });
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../Order and Dispatch/screens/booking_screen.dart';
import '../TimeKeeper/time_keeper.dart';
import '../actions_screen.dart';
import '../break_screen.dart';
import '../schedule_hub_screen.dart';
import '../../ViewModels/login_view_model.dart';
import '../task_screen.dart';
import '../company_screen.dart';


// ═══════════════════════════════════════════════════════════════════════════
// app_bottom_navbar.dart  —  Style 3: Circle Bubble
//
// TimeKeeper tab shown only when LoginViewModel.isTimekeeper == true.
// Order tab added at index 6 (before TimeKeeper).
// ═══════════════════════════════════════════════════════════════════════════

class AppBottomNavBar extends StatefulWidget {
  final int currentIndex;
  final int chatBadgeCount;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.chatBadgeCount = 0,
  });

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar>
    with TickerProviderStateMixin {

  // ── Design Tokens ──────────────────────────────────────────────────────
  static const _bgColor    = Colors.white60;
  static const _activeBg   = Color(0xFF14B8A6);
  static const _activeGlow = Color(0xFF14B8A6);
  static const _mutedIcon  = Color(0xFF4B5563);
  static const _activeIcon = Colors.white;

  // ── All possible tabs — TimeKeeper is last, flagged isTimekeeper=true ──
  static const _allTabs = [
    _NavTab(icon: Icons.home_outlined,           activeIcon: Icons.home_rounded,        label: 'Home'),
    _NavTab(icon: Icons.bolt_outlined,           activeIcon: Icons.bolt_rounded,         label: 'Actions'),
    _NavTab(icon: Icons.calendar_month_outlined, activeIcon: Icons.calendar_month,       label: 'Schedule'),
    _NavTab(icon: Icons.checklist_outlined,      activeIcon: Icons.checklist_rounded,    label: 'Tasks'),
    _NavTab(icon: Icons.coffee_outlined,         activeIcon: Icons.coffee_rounded,       label: 'Breaks'),
    _NavTab(icon: Icons.business_outlined,       activeIcon: Icons.business_rounded,     label: 'Company'),
    _NavTab(icon: Icons.shopping_bag_outlined,   activeIcon: Icons.shopping_bag_rounded, label: 'Booking'),
    _NavTab(icon: Icons.timer_outlined,          activeIcon: Icons.timer_rounded,        label: 'TimeKeeper', isTimekeeper: true),
  ];

  static const int _maxTabs = 8; // always allocate controllers for all tabs

  late final List<AnimationController> _pressControllers;
  late final List<Animation<double>>   _pressAnimations;
  late final List<AnimationController> _bubbleControllers;
  late final List<Animation<double>>   _bubbleAnimations;

  // ── Scroll state ──────────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();
  bool _canScrollLeft = false;   // Arrow on left side
  bool _canScrollRight = false;  // Arrow on right side

  @override
  void initState() {
    super.initState();

    _pressControllers = List.generate(
      _maxTabs,
          (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 120),
        reverseDuration: const Duration(milliseconds: 200),
      ),
    );
    _pressAnimations = _pressControllers
        .map((c) => Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    _bubbleControllers = List.generate(
      _maxTabs,
          (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
        value: i == widget.currentIndex ? 1.0 : 0.0,
      ),
    );
    _bubbleAnimations = _bubbleControllers
        .map((c) => CurvedAnimation(
      parent: c,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    ))
        .toList();

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final pixels = position.pixels;

    final canScrollLeft = maxScroll > 0 && pixels > 4;
    final canScrollRight = maxScroll > 0 && pixels < maxScroll - 4;

    if (canScrollLeft != _canScrollLeft || canScrollRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canScrollLeft;
        _canScrollRight = canScrollRight;
      });
    }
  }

  @override
  void didUpdateWidget(AppBottomNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _bubbleControllers[old.currentIndex].reverse();
      _bubbleControllers[widget.currentIndex].forward();
    }
  }

  @override
  void dispose() {
    for (final c in _pressControllers) c.dispose();
    for (final c in _bubbleControllers) c.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Filter tabs: hide TimeKeeper unless the logged-in user has the role.
  List<_NavTab> _visibleTabs(bool isTimekeeper) =>
      _allTabs.where((t) => !t.isTimekeeper || isTimekeeper).toList();

  void _handleTap(int visibleIndex, List<_NavTab> tabs) {
    final tab = tabs[visibleIndex];
    final allTabIndex = _allTabs.indexOf(tab);

    HapticFeedback.lightImpact();
    _pressControllers[allTabIndex].forward().then((_) {
      _pressControllers[allTabIndex].reverse();
    });

    // ── Actions tab (index 1) ─────────────────────────────────────────────
    if (allTabIndex == 1) {
      if (widget.currentIndex == 1) return;

      final navigator = Navigator.of(context, rootNavigator: true);

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => ActionsScreen(
            currentIndex: 1,
            chatBadgeCount: widget.chatBadgeCount,
            onNavTap: (i) {
              if (navigator.canPop()) {
                navigator.pop();
              }
              widget.onTap(i);
            },
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
            final slide = Tween<Offset>(begin: const Offset(0.0, 0.018), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
            final scale = Tween<double>(begin: 0.97, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: SlideTransition(position: slide, child: child),
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 260),
        ),
      );
      return;
    }

    // ── Schedule tab (index 2) ────────────────────────────────────────────
    if (allTabIndex == 2) {
      if (widget.currentIndex == 2) return;

      final navigator = Navigator.of(context, rootNavigator: true);

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => ScheduleHubScreen(
            currentIndex: 2,
            chatBadgeCount: widget.chatBadgeCount,
            onNavTap: (i) {
              if (navigator.canPop()) {
                navigator.pop();
              }
              widget.onTap(i);
            },
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
            final slide = Tween<Offset>(begin: const Offset(0.0, 0.018), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
            final scale = Tween<double>(begin: 0.97, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: SlideTransition(position: slide, child: child),
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 260),
        ),
      );
      return;
    }

    // ── Tasks tab (index 3) ───────────────────────────────────────────────
    if (allTabIndex == 3) {
      if (widget.currentIndex == 3) return;

      final navigator = Navigator.of(context, rootNavigator: true);

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => TaskScreen(
            currentIndex: 3,
            chatBadgeCount: widget.chatBadgeCount,
            onNavTap: (i) {
              if (navigator.canPop()) {
                navigator.pop();
              }
              widget.onTap(i);
            },
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
            final scale = Tween<double>(begin: 0.97, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 260),
        ),
      );
      return;
    }

    // ── Breaks tab (index 4) ──────────────────────────────────────────────
    if (allTabIndex == 4) {
      if (widget.currentIndex == 4) return;

      final navigator = Navigator.of(context, rootNavigator: true);

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => BreaksScreen(
            currentIndex: 4,
            chatBadgeCount: widget.chatBadgeCount,
            onNavTap: (i) {
              if (navigator.canPop()) {
                navigator.pop();
              }
              widget.onTap(i);
            },
          ),
          transitionsBuilder: (_, animation, __, child) {
            final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
            final scale = Tween<double>(begin: 0.97, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 260),
        ),
      );
      return;
    }

    // ── Company tab (index 5) ─────────────────────────────────────────────
    if (allTabIndex == 5) {
      if (widget.currentIndex == 5) return;

      final navigator = Navigator.of(context, rootNavigator: true);

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => CompanyScreen(
            currentIndex: 5,
            chatBadgeCount: widget.chatBadgeCount,
            onNavTap: (i) {
              if (navigator.canPop()) {
                navigator.pop();
              }
              widget.onTap(i);
            },
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
            final slide = Tween<Offset>(begin: const Offset(0.0, 0.018), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
            final scale = Tween<double>(begin: 0.97, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: SlideTransition(position: slide, child: child),
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 260),
        ),
      );
      return;
    }

    // ── Order tab (index 6) ───────────────────────────────────────────────
    if (allTabIndex == 6) {
      if (widget.currentIndex == 6) return;

      final navigator = Navigator.of(context, rootNavigator: true);

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => BookingScreen(
            currentIndex: 6,
            chatBadgeCount: widget.chatBadgeCount,
            onNavTap: (i) {
              if (navigator.canPop()) {
                navigator.pop();
              }
              widget.onTap(i);
            },
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
            final slide = Tween<Offset>(begin: const Offset(0.0, 0.018), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
            final scale = Tween<double>(begin: 0.97, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: SlideTransition(position: slide, child: child),
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 260),
        ),
      );
      return;
    }

    // ── TimeKeeper tab (index 7) ──────────────────────────────────────────
    if (tab.isTimekeeper) {
      if (widget.currentIndex == 7) return;

      final navigator = Navigator.of(context, rootNavigator: true);

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => TimekeeperScreen(
            currentIndex: 7,
            chatBadgeCount: widget.chatBadgeCount,
            onNavTap: (i) {
              if (navigator.canPop()) {
                navigator.pop();
              }
              widget.onTap(i);
            },
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
            final slide = Tween<Offset>(begin: const Offset(0.0, 0.018), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
            final scale = Tween<double>(begin: 0.97, end: 1.0)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart));
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: SlideTransition(position: slide, child: child),
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 260),
        ),
      );
      return;
    }

    // ── Default: Home tab or others ──────────────────────────────────────
    widget.onTap(allTabIndex);
  }


  /// Builds a single arrow hint widget
  Widget _buildArrowHint(bool showLeft) {
    return Positioned(
      left: showLeft ? 0 : null,
      right: showLeft ? null : 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Row(
          children: [
            if (showLeft)
              Container(
                width: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _bgColor.withOpacity(0.95),
                      _bgColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            Container(
              width: 22,
              height: 22,
              margin: EdgeInsets.only(
                left: showLeft ? 6 : 0,
                right: showLeft ? 0 : 6,
              ),
              decoration: BoxDecoration(
                color: _activeBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _activeGlow.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                showLeft ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            if (!showLeft)
              Container(
                width: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      _bgColor.withOpacity(0.0),
                      _bgColor.withOpacity(0.95),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final loginVM       = Get.find<LoginViewModel>();

    return Obx(() {
      final tabs = _visibleTabs(loginVM.isTimekeeper.value);

      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());

      return Container(
        color: _bgColor,
        padding: EdgeInsets.only(
          top: 8,
          bottom: bottomPadding > 0 ? bottomPadding : 12,
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(tabs.length, (i) => _buildTab(i, tabs)),
              ),
            ),

            // ── Left arrow hint ──────────────────────────────────────────
            if (_canScrollLeft) _buildArrowHint(true),

            // ── Right arrow hint ─────────────────────────────────────────
            if (_canScrollRight) _buildArrowHint(false),
          ],
        ),
      );
    });
  }

  Widget _buildTab(int visibleIndex, List<_NavTab> tabs) {
    final tab         = tabs[visibleIndex];
    final allTabIndex = _allTabs.indexOf(tab);
    final isActive    = widget.currentIndex == allTabIndex;

    return AnimatedBuilder(
      animation: _pressAnimations[allTabIndex],
      builder: (context, child) => Transform.scale(
        scale: _pressAnimations[allTabIndex].value,
        child: child,
      ),
      child: GestureDetector(
        onTap: () => _handleTap(visibleIndex, tabs),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Circle bubble ──────────────────────────────────────────
              AnimatedBuilder(
                animation: _bubbleAnimations[allTabIndex],
                builder: (context, _) {
                  final t = _bubbleAnimations[allTabIndex].value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.lerp(Colors.transparent, _activeBg, t),
                          boxShadow: t > 0.1
                              ? [
                            BoxShadow(
                              color: _activeGlow.withOpacity(0.50 * t),
                              blurRadius: 18,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ]
                              : [],
                        ),
                        child: Icon(
                          isActive ? tab.activeIcon : tab.icon,
                          size: 20,
                          color: Color.lerp(_mutedIcon, _activeIcon, t),
                        ),
                      ),
                      if (tab.hasChat && widget.chatBadgeCount > 0)
                        Positioned(
                          top: 2,
                          right: 6,
                          child: _ChatBadge(count: widget.chatBadgeCount),
                        ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 5),

              // ── Label ──────────────────────────────────────────────────
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? _activeBg : _mutedIcon,
                  letterSpacing: 0.1,
                  height: 1.0,
                ),
                child: Text(tab.label, textAlign: TextAlign.center),
              ),

              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat Badge
// ─────────────────────────────────────────────────────────────────────────────
class _ChatBadge extends StatefulWidget {
  final int count;
  const _ChatBadge({required this.count});

  @override
  State<_ChatBadge> createState() => _ChatBadgeState();
}

class _ChatBadgeState extends State<_ChatBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Transform.scale(
        scale: _pulse.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.5),
          constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            widget.count > 9 ? '9+' : '${widget.count}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 7,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────
class _NavTab {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  final bool     hasChat;
  final bool     isTimekeeper;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.hasChat      = false,
    this.isTimekeeper = false,
  });
}