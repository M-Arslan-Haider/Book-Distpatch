//
//
// import '../../AppColors.dart';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:permission_handler/permission_handler.dart';
// import '../../constants.dart';
//
// class CameraScreen extends StatelessWidget {
//   final VoidCallback? onNext;
//
//   const CameraScreen({super.key, this.onNext});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           // ── Full-screen gradient background ──────────────────────────
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [AppColors.cyan, AppColors.greenTeal],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//           ),
//
//           // ── Subtle circle decorations on background ──────────────────
//           Positioned(
//             top: -80,
//             left: -80,
//             child: Container(
//               width: 260,
//               height: 260,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.white.withOpacity(0.07),
//               ),
//             ),
//           ),
//           Positioned(
//             bottom: 60,
//             right: -60,
//             child: Container(
//               width: 200,
//               height: 200,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.white.withOpacity(0.06),
//               ),
//             ),
//           ),
//           Positioned(
//             top: 160,
//             right: 30,
//             child: Container(
//               width: 60,
//               height: 60,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.white.withOpacity(0.10),
//               ),
//             ),
//           ),
//
//           // ── Main content ─────────────────────────────────────────────
//           SafeArea(
//             child: Column(
//               children: [
//                 // ── Top header area ─────────────────────────────────
//                 Expanded(
//                   flex: 3,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.stretch,
//                     children: [
//                       // ── Icon + Title centered in gradient area ───
//                       Expanded(
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Container(
//                               padding: const EdgeInsets.all(28),
//                               decoration: BoxDecoration(
//                                 color: Colors.white.withOpacity(0.20),
//                                 shape: BoxShape.circle,
//                                 border: Border.all(
//                                     color: Colors.white.withOpacity(0.40),
//                                     width: 2.5),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: Colors.black.withOpacity(0.12),
//                                     blurRadius: 24,
//                                     offset: const Offset(0, 10),
//                                   ),
//                                 ],
//                               ),
//                               child: const Icon(
//                                 Icons.camera_alt_rounded,
//                                 size: 64,
//                                 color: Colors.white,
//                               ),
//                             ),
//                             const SizedBox(height: 20),
//                             const Text(
//                               'Camera Permission',
//                               style: TextStyle(
//                                 fontSize: 25,
//                                 fontWeight: FontWeight.w700,
//                                 color: Colors.white,
//                                 letterSpacing: 0.2,
//                               ),
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               'Grant access to continue',
//                               style: TextStyle(
//                                 fontSize: 13,
//                                 color: Colors.white.withOpacity(0.75),
//                                 fontWeight: FontWeight.w400,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // ── White bottom sheet card ─────────────────────────
//                 Expanded(
//                   flex: 4,
//                   child: Container(
//                     width: double.infinity,
//                     decoration: const BoxDecoration(
//                       color: Colors.white,
//                       borderRadius:
//                       BorderRadius.vertical(top: Radius.circular(32)),
//                     ),
//                     child: SingleChildScrollView(
//                       padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.center,
//                         children: [
//                           const Text(
//                             'Allow Camera Access',
//                             style: TextStyle(
//                               fontSize: 22,
//                               fontWeight: FontWeight.w800,
//                               color: AppColors.textPrimary,
//                             ),
//                           ),
//                           const SizedBox(height: 6),
//
//                           // ── Accent divider ──────────────────────────
//                           Container(
//                             width: 32,
//                             height: 3,
//                             decoration: BoxDecoration(
//                               color: AppColors.cyan,
//                               borderRadius: BorderRadius.circular(2),
//                             ),
//                           ),
//
//                           SizedBox(height: 14),
//
//                           Center(
//                             child: Text(
//                               'Allow access to use the camera feature.\nThis helps you capture photos.',
//                               textAlign: TextAlign.center,
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: AppColors.textSecondary.withOpacity(0.8),
//                                 height: 1.6,
//                               ),
//                             ),
//                           ),
//
//                           SizedBox(height: 36),
//
//                           // ── Allow Button ────────────────────────────
//                           SizedBox(
//                             width: double.infinity,
//                             height: 54,
//                             child: DecoratedBox(
//                               decoration: BoxDecoration(
//                                 gradient: AppColors.brandGradient,
//                                 borderRadius: BorderRadius.circular(14),
//                                 boxShadow: [
//                                   BoxShadow(
//                                     color: AppColors.cyan.withOpacity(0.40),
//                                     blurRadius: 18,
//                                     offset: const Offset(0, 6),
//                                   ),
//                                 ],
//                               ),
//                               child: ElevatedButton(
//                                 onPressed: () async {
//                                   PermissionStatus status =
//                                   await Permission.camera.request();
//                                   if (status.isGranted) {
//                                     onNext?.call();
//                                   } else {
//                                     Get.snackbar(
//                                       'Permission Required',
//                                       'Please enable camera access in settings.',
//                                       snackPosition: SnackPosition.BOTTOM,
//                                       backgroundColor: AppColors.error,
//                                       colorText: Colors.white,
//                                     );
//                                   }
//                                 },
//                                 style: ElevatedButton.styleFrom(
//                                   backgroundColor: Colors.transparent,
//                                   shadowColor: Colors.transparent,
//                                   foregroundColor: Colors.white,
//                                   shape: RoundedRectangleBorder(
//                                     borderRadius: BorderRadius.circular(14),
//                                   ),
//                                 ),
//                                 child: const Row(
//                                   mainAxisAlignment: MainAxisAlignment.center,
//                                   children: [
//                                     Text(
//                                       'Allow',
//                                       style: TextStyle(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.w700,
//                                         letterSpacing: 0.3,
//                                       ),
//                                     ),
//                                     SizedBox(width: 8),
//                                     Icon(Icons.arrow_forward_rounded, size: 18),
//                                   ],
//                                 ),
//                               ),
//                             ),
//                           ),
//
//                           const SizedBox(height: 16),
//
//                           // ── Footer ───────────────────────────────────
//                           Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(Icons.lock_outline_rounded,
//                                   size: 12,
//                                   color:
//                                   AppColors.textSecondary.withOpacity(0.5)),
//                               const SizedBox(width: 5),
//                               Text(
//                                 'Secured & Encrypted Connection',
//                                 style: TextStyle(
//                                   fontSize: 11,
//                                   color:
//                                   AppColors.textSecondary.withOpacity(0.5),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

////responsive
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../AppColors.dart';
import '../../constants.dart';

class CameraScreen extends StatelessWidget {
  final VoidCallback? onNext;

  const CameraScreen({super.key, this.onNext});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 680;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.cyan, AppColors.greenTeal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Decorative Circles
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            top: 180,
            right: 40,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.12),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Gradient Section
                Expanded(
                  flex: isSmallScreen ? 2 : 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.35),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          size: isSmallScreen ? 58 : 68,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Camera Permission',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 23 : 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Grant access to continue',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.78),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom White Card
                Expanded(
                  flex: isSmallScreen ? 3 : 5,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(40),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        28,
                        isSmallScreen ? 28 : 36,
                        28,
                        32,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Allow Camera Access',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 21 : 23,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Accent Line
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.cyan,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            'We need camera access to capture photos and support attendance & verification features.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.65,
                              color: AppColors.textSecondary.withOpacity(0.85),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Allow Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cyan.withOpacity(0.45),
                                    blurRadius: 22,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () async {
                                  final status = await Permission.camera.request();

                                  if (status.isGranted) {
                                    onNext?.call();
                                  } else if (status.isPermanentlyDenied) {
                                    Get.snackbar(
                                      'Permission Denied',
                                      'Please enable Camera permission from Settings.',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: AppColors.error,
                                      colorText: Colors.white,
                                      duration: const Duration(seconds: 4),
                                    );
                                    await openAppSettings();
                                  } else {
                                    Get.snackbar(
                                      'Permission Required',
                                      'Camera access is needed to continue.',
                                      snackPosition: SnackPosition.BOTTOM,
                                      backgroundColor: AppColors.warning,
                                      colorText: Colors.white,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Allow Camera Access',
                                      style: TextStyle(
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Icon(Icons.arrow_forward_rounded, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Security Note
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 14,
                                color: AppColors.textSecondary.withOpacity(0.6),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Secured & Encrypted',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary.withOpacity(0.6),
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