// import '../../AppColors.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../constants.dart';
//
// class NotificationScreen extends StatelessWidget {
//   final VoidCallback? onNext;
//
//   const NotificationScreen({super.key, this.onNext});
//
//   // ── Design tokens (mirrored from EmployeeProfileScreen) ──────────────────
//   // Color tokens moved to AppColors
//   // see app_colors.dart
//   //
//   //
//   //
//   //
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.surface,
//       body: Stack(
//         children: [
//           // ── Decorative blobs — navy + gold ──────────────────────────────
//           Positioned(
//             top: -100,
//             right: -50,
//             child: Transform.rotate(
//               angle: -0.2,
//               child: Container(
//                 width: 300,
//                 height: 300,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(80),
//                   gradient: LinearGradient(
//                     colors: [
//                       AppColors.cyan.withOpacity(0.14),
//                       AppColors.cyanBright.withOpacity(0.04),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//           Positioned(
//             top: 50,
//             left: -30,
//             child: Container(
//               width: 120,
//               height: 120,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: AppColors.skyBlue.withOpacity(0.10),
//               ),
//             ),
//           ),
//           Positioned(
//             bottom: -60,
//             right: -40,
//             child: Container(
//               width: 160,
//               height: 160,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: AppColors.greenTeal.withOpacity(0.06),
//               ),
//             ),
//           ),
//
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 32),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//
//                   // ── Icon — navy gradient circle with gold border ─────────
//                   Container(
//                     padding: const EdgeInsets.all(28),
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [AppColors.cyan, AppColors.greenTeal],
//                         begin: Alignment.topLeft,
//                         end: Alignment.bottomRight,
//                       ),
//                       shape: BoxShape.circle,
//                       border: Border.all(color: AppColors.cyanBright, width: 2.5),
//                       boxShadow: [
//                         BoxShadow(
//                           color: AppColors.primary.withOpacity(0.28),
//                           blurRadius: 24,
//                           offset: const Offset(0, 10),
//                         ),
//                       ],
//                     ),
//                     child: const Icon(
//                       Icons.notifications_active_rounded,
//                       size: 64,
//                       color: Colors.white,
//                     ),
//                   ),
//
//                   const SizedBox(height: 36),
//
//                   // ── Title ────────────────────────────────────────────────
//                   const Text(
//                     'Notification Permission',
//                     style: TextStyle(
//                       fontSize: 26,
//                       fontWeight: FontWeight.w800,
//                       color: AppColors.primary,
//                       letterSpacing: -0.3,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//
//                   const SizedBox(height: 10),
//
//                   // Gold accent divider
//                   Center(
//                     child: Container(
//                       width: 32, height: 3,
//                       decoration: BoxDecoration(
//                         color: AppColors.cyan,
//                         borderRadius: BorderRadius.circular(2),
//                       ),
//                     ),
//                   ),
//
//                   const SizedBox(height: 14),
//
//                   Text(
//                     'Allow notifications to stay updated with alerts.',
//                     style: TextStyle(
//                       fontSize: 15,
//                       color: AppColors.textSecondary,
//                       height: 1.6,
//                     ),
//                     textAlign: TextAlign.center,
//                   ),
//
//                   const SizedBox(height: 56),
//
//                   // ── Allow Button — navy ──────────────────────────────────
//                   SizedBox(
//                     width: double.infinity,
//                     height: 58,
//                     child: ElevatedButton(
//                       onPressed: () async {
//                         PermissionStatus status =
//                         await Permission.notification.request();
//                         if (status.isGranted) {
//                           onNext?.call();
//                         } else {
//                           Get.snackbar(
//                             'Permission Required',
//                             'Notification permission is required.',
//                             snackPosition: SnackPosition.BOTTOM,
//                             backgroundColor: AppColors.error,
//                             colorText: Colors.white,
//                           );
//                         }
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: AppColors.primary,
//                         foregroundColor: Colors.white,
//                         elevation: 6,
//                         shadowColor: AppColors.cyan.withOpacity(0.40),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(14),
//                         ),
//                       ),
//                       child: const Row(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Text(
//                             'Allow',
//                             style: TextStyle(
//                               fontSize: 17,
//                               fontWeight: FontWeight.w700,
//                               letterSpacing: 0.2,
//                             ),
//                           ),
//                           SizedBox(width: 8),
//                           Icon(Icons.arrow_forward_rounded, size: 20),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


import '../../AppColors.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../constants.dart';

class NotificationScreen extends StatelessWidget {
  final VoidCallback? onNext;

  const NotificationScreen({super.key, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen gradient background ──────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.cyan, AppColors.greenTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Subtle circle decorations on background ──────────────────
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            top: 160,
            right: 30,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Top header area ─────────────────────────────────
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Icon + Title centered in gradient area ───
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.20),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.40),
                                    width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.notifications_active_rounded,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Notification Permission',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Grant access to continue',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.75),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── White bottom sheet card ─────────────────────────
                Expanded(
                  flex: 4,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                      BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Allow Notifications',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // ── Accent divider ──────────────────────────
                          Container(
                            width: 32,
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.cyan,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          const SizedBox(height: 14),

                          Text(
                            'Allow notifications to stay updated with alerts.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary.withOpacity(0.8),
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 36),

                          // ── Allow Button ────────────────────────────
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cyan.withOpacity(0.40),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () async {
                                  PermissionStatus status =
                                  await Permission.notification.request();
                                  if (status.isGranted) {
                                    onNext?.call();
                                  } else {
                                    Get.snackbar(
                                      'Permission Required',
                                      'Notification permission is required.',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: AppColors.error,
                                      colorText: Colors.white,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Allow',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.arrow_forward_rounded, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ── Footer ───────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline_rounded,
                                  size: 12,
                                  color:
                                  AppColors.textSecondary.withOpacity(0.5)),
                              const SizedBox(width: 5),
                              Text(
                                'Secured & Encrypted Connection',
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                  AppColors.textSecondary.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}