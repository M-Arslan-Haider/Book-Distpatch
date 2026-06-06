// import 'package:GPS_Workforce_Monitor/Screens/code_screen.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../../AppColors.dart';
// import '../../Services/biometric_service.dart';
// import '../../Services/logout_api_service.dart';
// import '../../ViewModels/login_view_model.dart';
// import '../../ViewModels/attendance_view_model.dart';
// import '../SalarySlipScreen.dart';
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
//   String _empName = '';
//   String _empId   = '';
//   String _empRole = '';
//
//   // ── Biometric state ───────────────────────────────────────────────────────
//   bool _biometricEnabled   = false;
//   bool _biometricAvailable = false;
//   bool _biometricToggling  = false;   // prevents double-taps
//
//   /// Resolved once in [_loadUserData]; drives icon & label in the tile.
//   BiometricModality _modality = BiometricModality.none;
//   // ─────────────────────────────────────────────────────────────────────────
//
//   late final AnimationController _ctrl;
//   late final Animation<Offset>   _slideAnim;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUserData();
//     _ctrl = AnimationController(
//       vsync:    this,
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
//     if (!mounted) return;
//
//     // Check hardware + persisted preference + modality
//     final available = await BiometricService.isAvailable();
//     final enabled   = prefs.getBool(prefBiometricEnabled) ?? false;
//     final modality  = await BiometricService.getPrimaryModality();
//
//     if (mounted) {
//       setState(() {
//         _empName = prefs.getString('userName')    ?? 'Employee';
//         _empId   = prefs.getString('userId')      ?? '--';
//         _empRole = prefs.getString('designation') ?? 'Staff';
//
//         _biometricAvailable = available;
//         _biometricEnabled   = enabled;
//         _modality           = modality;
//       });
//     }
//   }
//
//   // ── Adaptive icon & label helpers ─────────────────────────────────────────
//
//   /// Icon for the security tile — face for Face ID devices, fingerprint
//   /// for everything else.
//   IconData get _biometricIcon {
//     switch (_modality) {
//       case BiometricModality.face:
//       case BiometricModality.fingerprint:
//       case BiometricModality.none:
//         return Icons.fingerprint_rounded;
//     }
//   }
//
//   /// "Face ID Login" or "Fingerprint Login"
//   String get _biometricTileTitle {
//     switch (_modality) {
//       case BiometricModality.face:
//       case BiometricModality.fingerprint:
//       case BiometricModality.none:
//         return 'Fingerprint Login';
//     }
//   }
//
//   // ── Nav sections ──────────────────────────────────────────────────────────
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
//         onTap: () => Get.to(() => const AttendanceReportScreen()),
//       ),
//       _NavItem(
//         icon:  Icons.payment,
//         label: 'Salary Slip',
//         onTap: () => Get.to(() => const SalarySlipScreen()),
//       ),
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
//         backgroundColor: AppColors.surface,
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
//
//                   // SECURITY section — only shown when biometric hw is available
//                   if (_biometricAvailable) ...[
//                     _buildSectionHeader('SECURITY'),
//                     _buildBiometricTile(),
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
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
//           begin:  Alignment.topLeft,
//           end:    Alignment.bottomRight,
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
//             // Logo
//             Center(
//               child: Container(
//                 width: 72, height: 72,
//                 decoration: BoxDecoration(
//                   color: Colors.white,
//                   shape: BoxShape.circle,
//                   boxShadow: [
//                     BoxShadow(
//                       color:      AppColors.cyan.withOpacity(0.35),
//                       blurRadius: 16,
//                       offset:     const Offset(0, 6),
//                     ),
//                     BoxShadow(
//                       color:      AppColors.greenTeal.withOpacity(0.20),
//                       blurRadius: 8,
//                       offset:     const Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(8),
//                   child: Image.asset(
//                     'assets/images/applogo.png',
//                     fit: BoxFit.contain,
//                   ),
//                 ),
//               ),
//             ),
//
//             const SizedBox(height: 16),
//
//             Row(
//               children: [
//                 // Avatar
//                 GestureDetector(
//                   onTap: () {
//                     Get.back();
//                     Get.to(() => const EmployeeProfileScreen());
//                   },
//                   child: Stack(
//                     children: [
//                       Container(
//                         width: 62, height: 62,
//                         decoration: BoxDecoration(
//                           shape: BoxShape.circle,
//                           gradient: const LinearGradient(
//                             colors: [AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
//                             begin:  Alignment.topLeft,
//                             end:    Alignment.bottomRight,
//                           ),
//                           border: Border.all(color: Colors.white, width: 2.5),
//                           boxShadow: [
//                             BoxShadow(
//                               color:      AppColors.cyan.withOpacity(0.35),
//                               blurRadius: 12,
//                               offset:     const Offset(0, 4),
//                             ),
//                           ],
//                         ),
//                         child: ClipOval(
//                           child: Stack(
//                             fit: StackFit.expand,
//                             children: [
//                               Container(
//                                 decoration: const BoxDecoration(
//                                   gradient: LinearGradient(
//                                     colors: [AppColors.cyanLight, AppColors.cyanMid, AppColors.iconBgGreenTeal],
//                                     begin:  Alignment.topLeft,
//                                     end:    Alignment.bottomRight,
//                                   ),
//                                 ),
//                               ),
//                               Image.asset(
//                                 'assets/icons/download (2)-removebg-preview.jpg',
//                                 fit:           BoxFit.cover,
//                                 color:         AppColors.surface.withOpacity(0.0),
//                                 colorBlendMode: BlendMode.dstATop,
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                       Positioned(
//                         bottom: 2, right: 2,
//                         child: Container(
//                           width: 14, height: 14,
//                           decoration: BoxDecoration(
//                             color:  AppColors.success,
//                             shape:  BoxShape.circle,
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
//                             color:         Colors.white,
//                             fontSize:      15,
//                             fontWeight:    FontWeight.w800,
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
//               ],
//             ),
//
//             const SizedBox(height: 14),
//
//             // Employee ID badge
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//               decoration: BoxDecoration(
//                 color:        Colors.white.withOpacity(0.15),
//                 borderRadius: BorderRadius.circular(20),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.badge_rounded,
//                       size:  13,
//                       color: Colors.white.withOpacity(0.8)),
//                   const SizedBox(width: 5),
//                   Text('ID: $_empId',
//                       style: TextStyle(
//                           color:         Colors.white.withOpacity(0.9),
//                           fontSize:      11,
//                           fontWeight:    FontWeight.w500,
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
//             color:         AppColors.textSecondary,
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
//           borderRadius:   BorderRadius.circular(14),
//           splashColor:    AppColors.iconBgCyan,
//           highlightColor: AppColors.cyanLight,
//           onTap: () {
//             Get.back();
//             item.onTap();
//           },
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
//             child: Row(
//               children: [
//                 Container(
//                   width: 38, height: 38,
//                   decoration: BoxDecoration(
//                     gradient: const LinearGradient(
//                       colors: [AppColors.iconBgCyan, AppColors.iconBgGreenTeal],
//                       begin:  Alignment.topLeft,
//                       end:    Alignment.bottomRight,
//                     ),
//                     borderRadius: BorderRadius.circular(10),
//                     border: Border.all(
//                       color: AppColors.cyan.withOpacity(0.20),
//                       width: 1,
//                     ),
//                   ),
//                   child: Icon(item.icon, size: 20, color: AppColors.primary),
//                 ),
//                 const SizedBox(width: 14),
//                 Expanded(
//                   child: Text(item.label,
//                       style: const TextStyle(
//                         fontSize:   14,
//                         fontWeight: FontWeight.w500,
//                         color:      AppColors.textPrimary,
//                       )),
//                 ),
//                 Icon(Icons.chevron_right_rounded,
//                     size: 18, color: AppColors.cyanMid),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── Biometric toggle tile ─────────────────────────────────────────────────
//   //  The icon and label adapt automatically:
//   //    • Face ID devices  → face_unlock_rounded icon + "Face ID Login"
//   //    • Fingerprint devices → fingerprint_rounded icon + "Fingerprint Login"
//
//   Widget _buildBiometricTile() {
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 2),
//       decoration: BoxDecoration(
//         color: _biometricEnabled
//             ? AppColors.cyan.withOpacity(0.06)
//             : Colors.transparent,
//         borderRadius: BorderRadius.circular(14),
//         border: _biometricEnabled
//             ? Border.all(color: AppColors.cyan.withOpacity(0.18), width: 1)
//             : null,
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           borderRadius:   BorderRadius.circular(14),
//           splashColor:    AppColors.iconBgCyan,
//           highlightColor: AppColors.cyanLight,
//           onTap: _biometricToggling ? null : _handleBiometricToggle,
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//             child: Row(
//               children: [
//                 // Icon box — filled gradient when enabled
//                 Container(
//                   width: 38, height: 38,
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: _biometricEnabled
//                           ? [AppColors.cyan, AppColors.greenTeal]
//                           : [AppColors.iconBgCyan, AppColors.iconBgGreenTeal],
//                       begin: Alignment.topLeft,
//                       end:   Alignment.bottomRight,
//                     ),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Icon(
//                     // ── Adaptive icon ────────────────────────────────────────
//                     _biometricIcon,
//                     size:  22,
//                     color: _biometricEnabled ? Colors.white : AppColors.primary,
//                   ),
//                 ),
//                 const SizedBox(width: 14),
//
//                 // Label + subtitle
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         // ── Adaptive label ───────────────────────────────────
//                         _biometricTileTitle,
//                         style: const TextStyle(
//                           fontSize:   14,
//                           fontWeight: FontWeight.w500,
//                           color:      AppColors.textPrimary,
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         _biometricEnabled ? 'Enabled' : 'Tap to enable',
//                         style: TextStyle(
//                           fontSize:   11.5,
//                           color: _biometricEnabled
//                               ? AppColors.cyan
//                               : AppColors.textSecondary.withOpacity(0.6),
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // Switch (or loading indicator)
//                 if (_biometricToggling)
//                   const SizedBox(
//                     width: 20, height: 20,
//                     child: CircularProgressIndicator(
//                         strokeWidth: 2, color: AppColors.cyan),
//                   )
//                 else
//                   Transform.scale(
//                     scale: 0.82,
//                     child: Switch(
//                       value:              _biometricEnabled,
//                       onChanged:          (_) => _handleBiometricToggle(),
//                       activeColor:        AppColors.cyan,
//                       activeTrackColor:   AppColors.cyan.withOpacity(0.25),
//                       inactiveThumbColor: AppColors.textSecondary.withOpacity(0.4),
//                       inactiveTrackColor: AppColors.divider,
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   /// Handles the tap/toggle on the biometric tile.
//   Future<void> _handleBiometricToggle() async {
//     if (_biometricToggling) return;
//
//     final loginVM = Get.find<LoginViewModel>();
//
//     if (_biometricEnabled) {
//       // ── Turning OFF: just confirm then disable ───────────────────────────
//       setState(() => _biometricToggling = true);
//       try {
//         final confirmed = await _showConfirmDisableDialog();
//         if (confirmed) {
//           await loginVM.disableBiometricLogin();
//           if (mounted) {
//             setState(() {
//               _biometricEnabled = false;
//               _modality         = BiometricModality.none;
//             });
//           }
//           _showResultSnackbar(
//             title:   'Biometric Login Disabled',
//             message: 'You will need to sign in with your password next time.',
//             isError: false,
//           );
//         }
//       } finally {
//         if (mounted) setState(() => _biometricToggling = false);
//       }
//     } else {
//       // ── Turning ON: first ask the user which method they prefer ──────────
//       // Do NOT set _biometricToggling here — the sheet handles its own spinner
//       final chosen = await _showBiometricChoiceSheet();
//       if (chosen == null) return; // user dismissed without choosing
//
//       setState(() => _biometricToggling = true);
//       try {
//         final error = await loginVM.enableBiometricLogin(chosenModality: chosen);
//
//         if (error.isEmpty) {
//           if (mounted) {
//             setState(() {
//               _biometricEnabled = true;
//               _modality         = chosen;
//             });
//           }
//           _showResultSnackbar(
//             title:   '${loginVM.biometricLabel} Enabled',
//             message: 'You can now sign in with ${loginVM.biometricLabel}.',
//             isError: false,
//           );
//         } else {
//           _showResultSnackbar(
//             title:   'Setup Failed',
//             message: error,
//             isError: true,
//           );
//         }
//       } finally {
//         if (mounted) setState(() => _biometricToggling = false);
//       }
//     }
//   }
//
//   /// Shows a bottom sheet that lets the user pick Face Scan or Fingerprint.
//   /// Returns the chosen [BiometricModality], or null if dismissed.
//   Future<BiometricModality?> _showBiometricChoiceSheet() async {
//     // Always show fingerprint option only
//     const hasFingerprint = true;
//
//     return await showModalBottomSheet<BiometricModality>(
//       context: context,
//       backgroundColor: Colors.transparent,
//       isScrollControlled: true,
//       builder: (_) => Container(
//         decoration: const BoxDecoration(
//           color: AppColors.surface,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//         ),
//         padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Drag handle
//             Container(
//               width: 40, height: 4,
//               decoration: BoxDecoration(
//                 color:        AppColors.divider,
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//             const SizedBox(height: 20),
//
//             // Title
//             const Text(
//               'Choose Login Method',
//               style: TextStyle(
//                 fontSize:   18,
//                 fontWeight: FontWeight.w800,
//                 color:      AppColors.textPrimary,
//               ),
//             ),
//             const SizedBox(height: 6),
//             Text(
//               'Select how you want to sign in next time',
//               style: TextStyle(
//                 fontSize: 13,
//                 color:    AppColors.textSecondary.withOpacity(0.75),
//               ),
//             ),
//             const SizedBox(height: 24),
//
//             // Fingerprint option
//             if (hasFingerprint)
//               _buildChoiceOption(
//                 icon:     Icons.fingerprint_rounded,
//                 title:    'Fingerprint',
//                 subtitle: 'Use your fingerprint to sign in',
//                 onTap:    () => Navigator.of(context).pop(BiometricModality.fingerprint),
//               ),
//
//             const SizedBox(height: 16),
//
//             // Cancel
//             SizedBox(
//               width: double.infinity,
//               child: TextButton(
//                 onPressed: () => Navigator.of(context).pop(null),
//                 style: TextButton.styleFrom(
//                   foregroundColor: AppColors.textSecondary,
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                 ),
//                 child: const Text(
//                   'Cancel',
//                   style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   /// A single tappable option card inside the choice bottom sheet.
//   Widget _buildChoiceOption({
//     required IconData icon,
//     required String   title,
//     required String   subtitle,
//     required VoidCallback onTap,
//   }) {
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         borderRadius: BorderRadius.circular(16),
//         onTap: onTap,
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//           decoration: BoxDecoration(
//             border:       Border.all(color: AppColors.divider, width: 1.3),
//             borderRadius: BorderRadius.circular(16),
//           ),
//           child: Row(
//             children: [
//               // Icon container
//               Container(
//                 width: 48, height: 48,
//                 decoration: BoxDecoration(
//                   gradient: const LinearGradient(
//                     colors: [AppColors.cyan, AppColors.greenTeal],
//                     begin:  Alignment.topLeft,
//                     end:    Alignment.bottomRight,
//                   ),
//                   borderRadius: BorderRadius.circular(13),
//                 ),
//                 child: Icon(icon, color: Colors.white, size: 26),
//               ),
//               const SizedBox(width: 16),
//
//               // Text
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(title,
//                         style: const TextStyle(
//                           fontSize:   15,
//                           fontWeight: FontWeight.w700,
//                           color:      AppColors.textPrimary,
//                         )),
//                     const SizedBox(height: 3),
//                     Text(subtitle,
//                         style: TextStyle(
//                           fontSize: 12.5,
//                           color:    AppColors.textSecondary.withOpacity(0.7),
//                         )),
//                   ],
//                 ),
//               ),
//
//               Icon(Icons.arrow_forward_ios_rounded,
//                   size: 16, color: AppColors.cyanMid),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   /// Confirmation dialog before disabling biometric.
//   Future<bool> _showConfirmDisableDialog() async {
//     bool confirmed = false;
//     await Get.defaultDialog(
//       title: 'Disable ${_biometricTileTitle}',
//       titleStyle: const TextStyle(
//           fontWeight: FontWeight.w700,
//           color:      AppColors.primary,
//           fontSize:   17),
//       middleText: 'Are you sure you want to disable ${_biometricTileTitle.toLowerCase()}?\n'
//           'You will need your password to sign in next time.',
//       middleTextStyle: TextStyle(
//           color: AppColors.textSecondary, fontSize: 13.5, height: 1.5),
//       textCancel:       'Cancel',
//       textConfirm:      'Disable',
//       confirmTextColor: Colors.white,
//       cancelTextColor:  AppColors.primary,
//       buttonColor:      AppColors.error,
//       radius: 16,
//       onConfirm: () {
//         confirmed = true;
//         Get.back();
//       },
//     );
//     return confirmed;
//   }
//
//   void _showResultSnackbar({
//     required String title,
//     required String message,
//     required bool isError,
//   }) {
//     if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
//     Get.snackbar(
//       title,
//       message,
//       backgroundColor: isError ? AppColors.error : AppColors.primary,
//       colorText:       Colors.white,
//       snackPosition:   SnackPosition.TOP,
//       duration:        const Duration(seconds: 4),
//       margin:          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       borderRadius:    12,
//       icon: Icon(
//         isError
//             ? Icons.error_outline_rounded
//             : Icons.check_circle_outline_rounded,
//         color: Colors.white,
//         size:  24,
//       ),
//     );
//   }
//
//   // ── Footer ────────────────────────────────────────────────────────────────
//   Widget _buildFooter() {
//     return Column(
//       children: [
//         Divider(
//             height: 1, thickness: 1,
//             indent: 20, endIndent: 20,
//             color: AppColors.divider),
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
//                         color:        AppColors.error.withOpacity(0.10),
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: const Icon(Icons.logout_rounded,
//                           size: 20, color: AppColors.error),
//                     ),
//                     const SizedBox(width: 14),
//                     const Text('Logout',
//                         style: TextStyle(
//                           fontSize:   14,
//                           fontWeight: FontWeight.w600,
//                           color:      AppColors.error,
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
//           child: Text('GPS Workforce Monitor  •  v2.3',
//               style: TextStyle(
//                   fontSize:      10.5,
//                   color:         AppColors.textSecondary.withOpacity(0.5),
//                   letterSpacing: 0.4)),
//         ),
//       ],
//     );
//   }
//
//   // ── Logout dialog ─────────────────────────────────────────────────────────
//   void _confirmLogout() {
//     // Get the AttendanceViewModel to check if user is clocked in
//     final attendanceViewModel = Get.find<AttendanceViewModel>();
//
//     // Check if user is currently clocked in
//     if (attendanceViewModel.isClockedIn.value) {
//       // Show error message if user is clocked in
//       Get.snackbar(
//         'Cannot Logout',
//         'Please clock out before logging out',
//         backgroundColor: AppColors.error,
//         colorText: Colors.white,
//         snackPosition: SnackPosition.TOP,
//         duration: const Duration(seconds: 4),
//         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         borderRadius: 12,
//         icon: const Icon(
//           Icons.error_outline_rounded,
//           color: Colors.white,
//           size: 24,
//         ),
//       );
//       return;
//     }
//
//     Get.defaultDialog(
//       title: 'Logout',
//       titleStyle: const TextStyle(
//           fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 18),
//       middleText: 'Are you sure you want to logout?',
//       middleTextStyle: TextStyle(color: AppColors.textSecondary),
//       textCancel:       'Cancel',
//       textConfirm:      'Logout',
//       confirmTextColor: Colors.white,
//       cancelTextColor:  AppColors.primary,
//       buttonColor:      AppColors.cyan,
//       radius: 16,
//       onConfirm: () async {
//         final prefs = await SharedPreferences.getInstance();
//
//         // ✅ Post logout data to API BEFORE clearing prefs
//         // (data clear hone ke baad available nahi rahega)
//         await LogoutApiService.postLogout(prefs);
//
//         // Preserve biometric keys so the biometric button survives logout
//         // and shows on the next login screen
//         final biometricEnabled  = prefs.getBool(prefBiometricEnabled);
//         final biometricUserId   = prefs.getString(prefBiometricUserId);
//         final biometricPassword = prefs.getString(prefBiometricPassword);
//
//         // ✅ Offline queue bachao — prefs.clear() se pehle save karo
//         final pendingQueue = prefs.getString(LogoutApiService.pendingLogoutsKey);
//
//         await prefs.clear();
//
//         if (biometricEnabled == true &&
//             biometricUserId   != null &&
//             biometricPassword != null) {
//           await prefs.setBool(prefBiometricEnabled, true);
//           await prefs.setString(prefBiometricUserId,   biometricUserId);
//           await prefs.setString(prefBiometricPassword, biometricPassword);
//         }
//
//         // ✅ Queue wapas restore karo clear ke baad
//         if (pendingQueue != null && pendingQueue.isNotEmpty) {
//           await prefs.setString(LogoutApiService.pendingLogoutsKey, pendingQueue);
//         }
//
//         Get.offAll(() => const CodeScreen());
//       },
//     );
//   }
// }
//
// // ── Data models ───────────────────────────────────────────────────────────────
// class _NavSection {
//   final String         header;
//   final List<_NavItem> items;
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

import 'package:GPS_Workforce_Monitor/Screens/code_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../AppColors.dart';
import '../../Services/biometric_service.dart';
import '../../Services/logout_api_service.dart';
import '../../ViewModels/login_view_model.dart';
import '../../ViewModels/attendance_view_model.dart';
import '../SalarySlipScreen.dart';
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

  // ── Biometric state ───────────────────────────────────────────────────────
  bool _biometricEnabled   = false;
  bool _biometricAvailable = false;
  bool _biometricToggling  = false;   // prevents double-taps

  /// Resolved once in [_loadUserData]; drives icon & label in the tile.
  BiometricModality _modality = BiometricModality.none;
  // ─────────────────────────────────────────────────────────────────────────

  late final AnimationController _ctrl;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _ctrl = AnimationController(
      vsync:    this,
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
    if (!mounted) return;

    // Check hardware + persisted preference + modality
    final available = await BiometricService.isAvailable();
    final enabled   = prefs.getBool(prefBiometricEnabled) ?? false;
    final modality  = await BiometricService.getPrimaryModality();

    if (mounted) {
      setState(() {
        _empName = prefs.getString('userName')    ?? 'Employee';
        _empId   = prefs.getString('userId')      ?? '--';
        _empRole = prefs.getString('designation') ?? 'Staff';

        _biometricAvailable = available;
        _biometricEnabled   = enabled;
        _modality           = modality;
      });
    }
  }

  // ── Adaptive icon & label helpers ─────────────────────────────────────────

  /// Icon for the security tile — face for Face ID devices, fingerprint
  /// for everything else.
  IconData get _biometricIcon {
    switch (_modality) {
      case BiometricModality.face:
      case BiometricModality.fingerprint:
      case BiometricModality.none:
        return Icons.fingerprint_rounded;
    }
  }

  /// "Face ID Login" or "Fingerprint Login"
  String get _biometricTileTitle {
    switch (_modality) {
      case BiometricModality.face:
      case BiometricModality.fingerprint:
      case BiometricModality.none:
        return 'Fingerprint Login';
    }
  }

  // ── Nav sections ──────────────────────────────────────────────────────────
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
        onTap: () => Get.to(() => const AttendanceReportScreen()),
      ),
      _NavItem(
        icon:  Icons.payment,
        label: 'Salary Slip',
        onTap: () => Get.to(() => const SalarySlipScreen()),
      ),
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

                  // SECURITY section — only shown when biometric hw is available
                  if (_biometricAvailable) ...[
                    _buildSectionHeader('SECURITY'),
                    _buildBiometricTile(),
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
          colors: [AppColors.tealLight, AppColors.tealDark],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
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
            const SizedBox(height: 16),

            // User info — no avatar, no logo
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_empName,
                    style: const TextStyle(
                      color:         Colors.white,
                      fontSize:      17,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(_empRole,
                    style: TextStyle(
                        color:    Colors.white.withOpacity(0.75),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400)),
              ],
            ),

            const SizedBox(height: 14),

            // Employee ID badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_rounded,
                      size:  13,
                      color: Colors.white.withOpacity(0.8)),
                  const SizedBox(width: 5),
                  Text('ID: $_empId',
                      style: TextStyle(
                          color:         Colors.white.withOpacity(0.9),
                          fontSize:      11,
                          fontWeight:    FontWeight.w500,
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
            color:         AppColors.textSecondary,
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
          borderRadius:   BorderRadius.circular(14),
          splashColor:    AppColors.iconBgTeal,
          highlightColor: AppColors.tealSurface,
          onTap: () {
            Get.back();
            item.onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.iconBgTeal, AppColors.iconBgGreen],
                      begin:  Alignment.topLeft,
                      end:    Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.tealLight.withOpacity(0.20),
                      width: 1,
                    ),
                  ),
                  child: Icon(item.icon, size: 20, color: AppColors.tealDark),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(item.label,
                      style: const TextStyle(
                        fontSize:   14,
                        fontWeight: FontWeight.w500,
                        color:      AppColors.textPrimary,
                      )),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.tealTint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Biometric toggle tile ─────────────────────────────────────────────────
  //  The icon and label adapt automatically:
  //    • Face ID devices  → face_unlock_rounded icon + "Face ID Login"
  //    • Fingerprint devices → fingerprint_rounded icon + "Fingerprint Login"

  Widget _buildBiometricTile() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: _biometricEnabled
            ? AppColors.tealLight.withOpacity(0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: _biometricEnabled
            ? Border.all(color: AppColors.tealLight.withOpacity(0.18), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:   BorderRadius.circular(14),
          splashColor:    AppColors.iconBgTeal,
          highlightColor: AppColors.tealSurface,
          onTap: _biometricToggling ? null : _handleBiometricToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Icon box — filled gradient when enabled
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _biometricEnabled
                          ? [AppColors.tealLight, AppColors.tealLight]
                          : [AppColors.iconBgTeal, AppColors.iconBgGreen],
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    // ── Adaptive icon ────────────────────────────────────────
                    _biometricIcon,
                    size:  22,
                    color: _biometricEnabled ? Colors.white : AppColors.tealDark,
                  ),
                ),
                const SizedBox(width: 14),

                // Label + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // ── Adaptive label ───────────────────────────────────
                        _biometricTileTitle,
                        style: const TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w500,
                          color:      AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _biometricEnabled ? 'Enabled' : 'Tap to enable',
                        style: TextStyle(
                          fontSize:   11.5,
                          color: _biometricEnabled
                              ? AppColors.tealLight
                              : AppColors.textSecondary.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Switch (or loading indicator)
                if (_biometricToggling)
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.tealLight),
                  )
                else
                  Transform.scale(
                    scale: 0.82,
                    child: Switch(
                      value:              _biometricEnabled,
                      onChanged:          (_) => _handleBiometricToggle(),
                      activeColor:        AppColors.tealLight,
                      activeTrackColor:   AppColors.tealLight.withOpacity(0.25),
                      inactiveThumbColor: AppColors.textSecondary.withOpacity(0.4),
                      inactiveTrackColor: AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Handles the tap/toggle on the biometric tile.
  Future<void> _handleBiometricToggle() async {
    if (_biometricToggling) return;

    final loginVM = Get.find<LoginViewModel>();

    if (_biometricEnabled) {
      // ── Turning OFF: just confirm then disable ───────────────────────────
      setState(() => _biometricToggling = true);
      try {
        final confirmed = await _showConfirmDisableDialog();
        if (confirmed) {
          await loginVM.disableBiometricLogin();
          if (mounted) {
            setState(() {
              _biometricEnabled = false;
              _modality         = BiometricModality.none;
            });
          }
          _showResultSnackbar(
            title:   'Biometric Login Disabled',
            message: 'You will need to sign in with your password next time.',
            isError: false,
          );
        }
      } finally {
        if (mounted) setState(() => _biometricToggling = false);
      }
    } else {
      // ── Turning ON: first ask the user which method they prefer ──────────
      // Do NOT set _biometricToggling here — the sheet handles its own spinner
      final chosen = await _showBiometricChoiceSheet();
      if (chosen == null) return; // user dismissed without choosing

      setState(() => _biometricToggling = true);
      try {
        final error = await loginVM.enableBiometricLogin(chosenModality: chosen);

        if (error.isEmpty) {
          if (mounted) {
            setState(() {
              _biometricEnabled = true;
              _modality         = chosen;
            });
          }
          _showResultSnackbar(
            title:   '${loginVM.biometricLabel} Enabled',
            message: 'You can now sign in with ${loginVM.biometricLabel}.',
            isError: false,
          );
        } else {
          _showResultSnackbar(
            title:   'Setup Failed',
            message: error,
            isError: true,
          );
        }
      } finally {
        if (mounted) setState(() => _biometricToggling = false);
      }
    }
  }

  /// Shows a bottom sheet that lets the user pick Face Scan or Fingerprint.
  /// Returns the chosen [BiometricModality], or null if dismissed.
  Future<BiometricModality?> _showBiometricChoiceSheet() async {
    // Always show fingerprint option only
    const hasFingerprint = true;

    return await showModalBottomSheet<BiometricModality>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Choose Login Method',
              style: TextStyle(
                fontSize:   18,
                fontWeight: FontWeight.w800,
                color:      AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select how you want to sign in next time',
              style: TextStyle(
                fontSize: 13,
                color:    AppColors.textSecondary.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 24),

            // Fingerprint option
            if (hasFingerprint)
              _buildChoiceOption(
                icon:     Icons.fingerprint_rounded,
                title:    'Fingerprint',
                subtitle: 'Use your fingerprint to sign in',
                onTap:    () => Navigator.of(context).pop(BiometricModality.fingerprint),
              ),

            const SizedBox(height: 16),

            // Cancel
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A single tappable option card inside the choice bottom sheet.
  Widget _buildChoiceOption({
    required IconData icon,
    required String   title,
    required String   subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border:       Border.all(color: AppColors.divider, width: 1.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.tealLight, AppColors.tealLight],
                    begin:  Alignment.topLeft,
                    end:    Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                          color:      AppColors.textPrimary,
                        )),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color:    AppColors.textSecondary.withOpacity(0.7),
                        )),
                  ],
                ),
              ),

              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: AppColors.tealTint),
            ],
          ),
        ),
      ),
    );
  }

  /// Confirmation dialog before disabling biometric.
  Future<bool> _showConfirmDisableDialog() async {
    bool confirmed = false;
    await Get.defaultDialog(
      title: 'Disable ${_biometricTileTitle}',
      titleStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          color:      AppColors.tealDark,
          fontSize:   17),
      middleText: 'Are you sure you want to disable ${_biometricTileTitle.toLowerCase()}?\n'
          'You will need your password to sign in next time.',
      middleTextStyle: TextStyle(
          color: AppColors.textSecondary, fontSize: 13.5, height: 1.5),
      textCancel:       'Cancel',
      textConfirm:      'Disable',
      confirmTextColor: Colors.white,
      cancelTextColor:  AppColors.tealDark,
      buttonColor:      AppColors.error,
      radius: 16,
      onConfirm: () {
        confirmed = true;
        Get.back();
      },
    );
    return confirmed;
  }

  void _showResultSnackbar({
    required String title,
    required String message,
    required bool isError,
  }) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    Get.snackbar(
      title,
      message,
      backgroundColor: isError ? AppColors.error : AppColors.tealDark,
      colorText:       Colors.white,
      snackPosition:   SnackPosition.TOP,
      duration:        const Duration(seconds: 4),
      margin:          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      borderRadius:    12,
      icon: Icon(
        isError
            ? Icons.error_outline_rounded
            : Icons.check_circle_outline_rounded,
        color: Colors.white,
        size:  24,
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Column(
      children: [
        Divider(
            height: 1, thickness: 1,
            indent: 20, endIndent: 20,
            color: AppColors.divider),
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
                        color:        AppColors.error.withOpacity(0.10),
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
                          color:      AppColors.error,
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(bottom: 20, top: 8),
          child: Text('GPS Workforce Monitor  •  v2.3',
              style: TextStyle(
                  fontSize:      10.5,
                  color:         AppColors.textSecondary.withOpacity(0.5),
                  letterSpacing: 0.4)),
        ),
      ],
    );
  }

  // ── Logout dialog ─────────────────────────────────────────────────────────
  void _confirmLogout() {
    // Get the AttendanceViewModel to check if user is clocked in
    final attendanceViewModel = Get.find<AttendanceViewModel>();

    // Check if user is currently clocked in
    if (attendanceViewModel.isClockedIn.value) {
      // Show error message if user is clocked in
      Get.snackbar(
        'Cannot Logout',
        'Please clock out before logging out',
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderRadius: 12,
        icon: const Icon(
          Icons.error_outline_rounded,
          color: Colors.white,
          size: 24,
        ),
      );
      return;
    }

    Get.defaultDialog(
      title: 'Logout',
      titleStyle: const TextStyle(
          fontWeight: FontWeight.w700, color: AppColors.tealDark, fontSize: 18),
      middleText: 'Are you sure you want to logout?',
      middleTextStyle: TextStyle(color: AppColors.textSecondary),
      textCancel:       'Cancel',
      textConfirm:      'Logout',
      confirmTextColor: Colors.white,
      cancelTextColor:  AppColors.tealDark,
      buttonColor:      AppColors.tealLight,
      radius: 16,
      onConfirm: () async {
        final prefs = await SharedPreferences.getInstance();

        // ✅ Post logout data to API BEFORE clearing prefs
        // (data clear hone ke baad available nahi rahega)
        await LogoutApiService.postLogout(prefs);

        // Preserve biometric keys so the biometric button survives logout
        // and shows on the next login screen
        final biometricEnabled  = prefs.getBool(prefBiometricEnabled);
        final biometricUserId   = prefs.getString(prefBiometricUserId);
        final biometricPassword = prefs.getString(prefBiometricPassword);

        // ✅ Offline queue bachao — prefs.clear() se pehle save karo
        final pendingQueue = prefs.getString(LogoutApiService.pendingLogoutsKey);

        await prefs.clear();

        if (biometricEnabled == true &&
            biometricUserId   != null &&
            biometricPassword != null) {
          await prefs.setBool(prefBiometricEnabled, true);
          await prefs.setString(prefBiometricUserId,   biometricUserId);
          await prefs.setString(prefBiometricPassword, biometricPassword);
        }

        // ✅ Queue wapas restore karo clear ke baad
        if (pendingQueue != null && pendingQueue.isNotEmpty) {
          await prefs.setString(LogoutApiService.pendingLogoutsKey, pendingQueue);
        }

        Get.offAll(() => const CodeScreen());
      },
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────
class _NavSection {
  final String         header;
  final List<_NavItem> items;
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