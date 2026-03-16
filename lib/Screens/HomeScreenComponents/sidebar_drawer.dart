// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../home_screen.dart';
// import '../login_screen.dart';
// import '../side_drawer_screens/attendance_report.dart';
// import '../side_drawer_screens/profile_view_screen.dart';
//
// class AppDrawer extends StatefulWidget {
//   const AppDrawer({super.key});
//
//   @override
//   State<AppDrawer> createState() => _AppDrawerState();
// }
//
// class _AppDrawerState extends State<AppDrawer>
//     with SingleTickerProviderStateMixin {
//
//   // ── Design tokens ─────────────────────────────────────────────────────────
//   static const Color _primary       = Color(0xFF1A2B6D);
//   static const Color _accent        = Color(0xFF4354E8);
//   static const Color _accentLight   = Color(0xFFEBEEFD);
//   static const Color _surface       = Color(0xFFF5F7FF);
//   static const Color _textPrimary   = Color(0xFF111827);
//   static const Color _textSecondary = Color(0xFF6B7280);
//
//   String _empName = '';
//   String _empId   = '';
//   String _empRole = '';
//
//   late final AnimationController _ctrl;
//   late final Animation<Offset>   _slideAnim;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//     _ctrl = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 380),
//     );
//     _slideAnim = Tween<Offset>(
//       begin: const Offset(-1, 0),
//       end:   Offset.zero,
//     ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
//     _ctrl.forward();
//   }
//
//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }
//
//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.reload();
//     if (mounted) {
//       setState(() {
//         _empName = prefs.getString('userName')    ?? 'Employee';
//         _empId   = prefs.getString('userId')      ?? '--';
//         _empRole = prefs.getString('designation') ?? 'Staff';
//       });
//     }
//   }
//
//   // ── Nav sections — each item uses Get.to(() => ScreenClass()) ─────────────
//   List<_NavSection> get _sections => [
//     _NavSection(header: 'MAIN', items: [
//       _NavItem(
//         icon:  Icons.home_rounded,
//         label: 'Home',
//         onTap: () => Get.off(() => const HomeScreen()),
//       ),
//       _NavItem(
//         icon:  Icons.person_rounded,
//         label: 'Profile',
//         onTap: () => Get.to(() => const EmployeeProfileScreen()),
//       ),
//       _NavItem(
//         icon:  Icons.access_time_rounded,
//         label: 'Attendance',
//         onTap: () => Get.to(() => const AttendanceReportScreen ()),
//       ),
//     // _NavSection(header: 'MANAGEMENT', items: [
//     //   _NavItem(
//     //     icon:  Icons.calendar_month_rounded,
//     //     label: 'Leave',
//     //     onTap: () => Get.to(() => const ()),
//     //   ),
//     //   _NavItem(
//     //     icon:  Icons.task_alt_rounded,
//     //     label: 'Tasks',
//     //     onTap: () => Get.to(() => const ()),
//     //   ),
//     //   _NavItem(
//     //     icon:  Icons.bar_chart_rounded,
//     //     label: 'Reports',
//     //     onTap: () => Get.to(() => const ()),
//     //   ),
//     // ]),
//     // _NavSection(header: 'ACCOUNT', items: [
//     //   _NavItem(
//     //     icon:  Icons.notifications_rounded,
//     //     label: 'Notifications',
//     //     onTap: () => Get.to(() => const ()),
//     //   ),
//     //   _NavItem(
//     //     icon:  Icons.settings_rounded,
//     //     label: 'Settings',
//     //     onTap: () => Get.to(() => const ()),
//     //   ),
//     ]),
//   ];
//
//   // ─────────────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return SlideTransition(
//       position: _slideAnim,
//       child: Drawer(
//         width: 290,
//         backgroundColor: Colors.white,
//         shape: const RoundedRectangleBorder(
//           borderRadius: BorderRadius.only(
//             topRight:    Radius.circular(28),
//             bottomRight: Radius.circular(28),
//           ),
//         ),
//         child: Column(
//           children: [
//             _buildHeader(),
//             Expanded(
//               child: ListView(
//                 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//                 physics: const BouncingScrollPhysics(),
//                 children: [
//                   for (final section in _sections) ...[
//                     _buildSectionHeader(section.header),
//                     for (final item in section.items)
//                       _buildNavTile(item),
//                     const SizedBox(height: 4),
//                   ],
//                 ],
//               ),
//             ),
//             _buildFooter(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Header ────────────────────────────────────────────────────────────────
//   Widget _buildHeader() {
//     final initials = _empName.isNotEmpty
//         ? _empName.trim().split(' ')
//         .take(2).map((w) => w[0].toUpperCase()).join()
//         : 'E';
//
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [Color(0xFF1A2B6D), Color(0xFF4354E8)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.only(
//           topRight:    Radius.circular(28),
//           bottomLeft:  Radius.circular(28),
//           bottomRight: Radius.circular(28),
//         ),
//       ),
//       child: SafeArea(
//         bottom: false,
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const SizedBox(height: 10),
//
//             Row(
//               children: [
//                 // Tapping avatar also goes to ProfileScreen
//                 GestureDetector(
//                   onTap: () {
//                     Get.back();
//                     Get.to(() => const ());
//                   },
//                   child: Stack(
//                     children: [
//                       Container(
//                         width: 62, height: 62,
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.18),
//                           shape: BoxShape.circle,
//                           border: Border.all(
//                               color: Colors.white.withOpacity(0.50),
//                               width: 2.5),
//                         ),
//                         child: Center(
//                           child: Text(initials,
//                               style: const TextStyle(
//                                 color:      Colors.white,
//                                 fontSize:   22,
//                                 fontWeight: FontWeight.w800,
//                               )),
//                         ),
//                       ),
//                       Positioned(
//                         bottom: 2, right: 2,
//                         child: Container(
//                           width: 14, height: 14,
//                           decoration: BoxDecoration(
//                             color: const Color(0xFF22C55E),
//                             shape: BoxShape.circle,
//                             border: Border.all(color: Colors.white, width: 2),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(width: 14),
//
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(_empName,
//                           style: const TextStyle(
//                             color:      Colors.white,
//                             fontSize:   15,
//                             fontWeight: FontWeight.w800,
//                             letterSpacing: 0.2,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis),
//                       const SizedBox(height: 3),
//                       Text(_empRole,
//                           style: TextStyle(
//                               color:    Colors.white.withOpacity(0.72),
//                               fontSize: 12)),
//                     ],
//                   ),
//                 ),
//
//                 // Edit icon → ProfileScreen
//                 GestureDetector(
//                   onTap: () {
//                     Get.back();
//                     Get.to(() => const ());
//                   },
//                   child: Container(
//                     width: 34, height: 34,
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.15),
//                       borderRadius: BorderRadius.circular(10),
//                     ),
//                     child: const Icon(
//                         Icons.edit_rounded, color: Colors.white, size: 16),
//                   ),
//                 ),
//               ],
//             ),
//
//             const SizedBox(height: 14),
//
//             // Employee ID badge
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.15),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.badge_rounded,
//                       size: 13, color: Colors.white.withOpacity(0.8)),
//                   const SizedBox(width: 5),
//                   Text('ID: $_empId',
//                       style: TextStyle(
//                           color:      Colors.white.withOpacity(0.9),
//                           fontSize:   11,
//                           fontWeight: FontWeight.w500,
//                           letterSpacing: 0.4)),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Section label ─────────────────────────────────────────────────────────
//   Widget _buildSectionHeader(String title) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
//       child: Text(title,
//           style: const TextStyle(
//             fontSize:      10.5,
//             fontWeight:    FontWeight.w700,
//             color:         _textSecondary,
//             letterSpacing: 1.4,
//           )),
//     );
//   }
//
//   // ── Nav tile ──────────────────────────────────────────────────────────────
//   Widget _buildNavTile(_NavItem item) {
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 2),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius: BorderRadius.circular(14),
//           splashColor:    _accentLight,
//           highlightColor: _accentLight.withOpacity(0.6),
//           onTap: () {
//             Get.back();   // close drawer
//             item.onTap(); // go to screen
//           },
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
//             child: Row(
//               children: [
//                 Container(
//                   width: 38, height: 38,
//                   decoration: BoxDecoration(
//                     color: _surface,
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Icon(item.icon, size: 20, color: _textSecondary),
//                 ),
//                 const SizedBox(width: 14),
//                 Expanded(
//                   child: Text(item.label,
//                       style: const TextStyle(
//                         fontSize:   14,
//                         fontWeight: FontWeight.w500,
//                         color:      _textPrimary,
//                       )),
//                 ),
//                 Icon(Icons.chevron_right_rounded,
//                     size: 18, color: Colors.grey.shade300),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── Footer ────────────────────────────────────────────────────────────────
//   Widget _buildFooter() {
//     return Column(
//       children: [
//         const Divider(height: 1, thickness: 1, indent: 20, endIndent: 20),
//         const SizedBox(height: 8),
//
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 14),
//           child: Material(
//             color: Colors.transparent,
//             child: InkWell(
//               borderRadius: BorderRadius.circular(14),
//               onTap: _confirmLogout,
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 12, vertical: 11),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 38, height: 38,
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFFFEEEE),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: const Icon(Icons.logout_rounded,
//                           size: 20, color: Color(0xFFEF4444)),
//                     ),
//                     const SizedBox(width: 14),
//                     const Text('Logout',
//                         style: TextStyle(
//                           fontSize:   14,
//                           fontWeight: FontWeight.w600,
//                           color:      Color(0xFFEF4444),
//                         )),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//
//         Padding(
//           padding: const EdgeInsets.only(bottom: 20, top: 8),
//           child: Text('GPS Attendance  •  v1.0.0',
//               style: TextStyle(
//                   fontSize: 10.5,
//                   color: Colors.grey.shade400,
//                   letterSpacing: 0.4)),
//         ),
//       ],
//     );
//   }
//
//   // ── Logout dialog ─────────────────────────────────────────────────────────
//   void _confirmLogout() {
//     Get.defaultDialog(
//       title: 'Logout',
//       titleStyle: const TextStyle(
//           fontWeight: FontWeight.w700, color: _primary, fontSize: 18),
//       middleText: 'Are you sure you want to logout?',
//       middleTextStyle: TextStyle(color: Colors.grey.shade600),
//       textCancel:       'Cancel',
//       textConfirm:      'Logout',
//       confirmTextColor: Colors.white,
//       cancelTextColor:  _primary,
//       buttonColor:      const Color(0xFF1A2B6D),
//       radius: 16,
//       onConfirm: () async {
//         final prefs = await SharedPreferences.getInstance();
//         await prefs.clear();
//         Get.offAll(() => const LoginScreen()); // ← direct class, no route string
//       },
//     );
//   }
// }
//
// // ── Data models ───────────────────────────────────────────────────────────────
// class _NavSection {
//   final String          header;
//   final List<_NavItem>  items;
//   const _NavSection({required this.header, required this.items});
// }
//
// class _NavItem {
//   final IconData     icon;
//   final String       label;
//   final VoidCallback onTap;
//   const _NavItem({
//     required this.icon,
//     required this.label,
//     required this.onTap,
//   });
// }

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../AppColors.dart';
import '../home_screen.dart';
import '../login_screen.dart';
import '../side_drawer_screens/attendance_report.dart';
import '../side_drawer_screens/profile_view_screen.dart';


class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with SingleTickerProviderStateMixin {

  String _empName = '';
  String _empId   = '';
  String _empRole = '';

  late final AnimationController _ctrl;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(-1, 0),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (mounted) {
      setState(() {
        _empName = prefs.getString('userName')    ?? 'Employee';
        _empId   = prefs.getString('userId')      ?? '--';
        _empRole = prefs.getString('designation') ?? 'Staff';
      });
    }
  }

  // ── Nav sections — each item uses Get.to(() => ScreenClass()) ─────────────
  List<_NavSection> get _sections => [
    _NavSection(header: 'MAIN', items: [
      _NavItem(
        icon:  Icons.home_rounded,
        label: 'Home',
        onTap: () => Get.off(() => const HomeScreen()),
      ),
      _NavItem(
        icon:  Icons.person_rounded,
        label: 'Profile',
        onTap: () => Get.to(() => const EmployeeProfileScreen()),
      ),
      _NavItem(
        icon:  Icons.access_time_rounded,
        label: 'Attendance',
        onTap: () => Get.to(() => const AttendanceReportScreen ()),
      ),
      // _NavSection(header: 'MANAGEMENT', items: [
      //   _NavItem(
      //     icon:  Icons.calendar_month_rounded,
      //     label: 'Leave',
      //     onTap: () => Get.to(() => const ()),
      //   ),
      //   _NavItem(
      //     icon:  Icons.task_alt_rounded,
      //     label: 'Tasks',
      //     onTap: () => Get.to(() => const ()),
      //   ),
      //   _NavItem(
      //     icon:  Icons.bar_chart_rounded,
      //     label: 'Reports',
      //     onTap: () => Get.to(() => const ()),
      //   ),
      // ]),
      // _NavSection(header: 'ACCOUNT', items: [
      //   _NavItem(
      //     icon:  Icons.notifications_rounded,
      //     label: 'Notifications',
      //     onTap: () => Get.to(() => const ()),
      //   ),
      //   _NavItem(
      //     icon:  Icons.settings_rounded,
      //     label: 'Settings',
      //     onTap: () => Get.to(() => const ()),
      //   ),
    ]),
  ];

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: Drawer(
        width: 290,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight:    Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final section in _sections) ...[
                    _buildSectionHeader(section.header),
                    for (final item in section.items)
                      _buildNavTile(item),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topRight:    Radius.circular(28),
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),

            // ── Logo ──────────────────────────────────────────────────────
            Center(
              child: Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.cyan.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: AppColors.greenTeal.withOpacity(0.20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    'assets/images/applogo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                // Avatar with themed placeholder image
                GestureDetector(
                  onTap: () {
                    Get.back();
                    Get.to(() => const ());
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 62, height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.cyan.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.cyanLight, AppColors.cyanMid, AppColors.iconBgGreenTeal],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),
                              Image.asset(
                                'assets/icons/download (2)-removebg-preview.jpg',
                                fit: BoxFit.cover,
                                color: AppColors.surface.withOpacity(0.0),
                                colorBlendMode: BlendMode.dstATop,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2, right: 2,
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_empName,
                          style: const TextStyle(
                            color:      Colors.white,
                            fontSize:   15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(_empRole,
                          style: TextStyle(
                              color:    Colors.white.withOpacity(0.72),
                              fontSize: 12)),
                    ],
                  ),
                ),

                // Edit icon → ProfileScreen
                GestureDetector(
                  onTap: () {
                    Get.back();
                    Get.to(() => const ());
                  },
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                        Icons.edit_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Employee ID badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_rounded,
                      size: 13, color: Colors.white.withOpacity(0.8)),
                  const SizedBox(width: 5),
                  Text('ID: $_empId',
                      style: TextStyle(
                          color:      Colors.white.withOpacity(0.9),
                          fontSize:   11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
      child: Text(title,
          style: const TextStyle(
            fontSize:      10.5,
            fontWeight:    FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 1.4,
          )),
    );
  }

  // ── Nav tile ──────────────────────────────────────────────────────────────
  Widget _buildNavTile(_NavItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          splashColor: AppColors.iconBgCyan,
          highlightColor: AppColors.cyanLight,
          onTap: () {
            Get.back();   // close drawer
            item.onTap(); // go to screen
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.iconBgCyan, AppColors.iconBgGreenTeal],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.cyan.withOpacity(0.20),
                      width: 1,
                    ),
                  ),
                  child: Icon(item.icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(item.label,
                      style: const TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      )),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.cyanMid),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Column(
      children: [
        Divider(height: 1, thickness: 1, indent: 20, endIndent: 20, color: AppColors.divider),
        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _confirmLogout,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 11),
                child: Row(
                  children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          size: 20, color: AppColors.error),
                    ),
                    const SizedBox(width: 14),
                    const Text('Logout',
                        style: TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(bottom: 20, top: 8),
          child: Text('GPS Attendance  •  v1.0.0',
              style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary.withOpacity(0.5),
                  letterSpacing: 0.4)),
        ),
      ],
    );
  }

  // ── Logout dialog ─────────────────────────────────────────────────────────
  void _confirmLogout() {
    Get.defaultDialog(
      title: 'Logout',
      titleStyle: const TextStyle(
          fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 18),
      middleText: 'Are you sure you want to logout?',
      middleTextStyle: TextStyle(color: AppColors.textSecondary),
      textCancel:       'Cancel',
      textConfirm:      'Logout',
      confirmTextColor: Colors.white,
      cancelTextColor: AppColors.primary,
      buttonColor: AppColors.cyan,
      radius: 16,
      onConfirm: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        Get.offAll(() => const LoginScreen()); // ← direct class, no route string
      },
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────
class _NavSection {
  final String          header;
  final List<_NavItem>  items;
  const _NavSection({required this.header, required this.items});
}

class _NavItem {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}