// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
//
// import '../AppColors.dart';
// import '../ViewModels/task_view_model.dart';
// import 'AssignedTasksScreen.dart';
//
// import 'create_task_screen.dart';
//
// class TaskScreen extends StatefulWidget {
//   const TaskScreen({super.key});
//
//   @override
//   State<TaskScreen> createState() => _TaskScreenState();
// }
//
// class _TaskScreenState extends State<TaskScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _fadeCtrl;
//   late Animation<double>    _fadeAnim;
//
//   @override
//   void initState() {
//     super.initState();
//     _fadeCtrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 450));
//     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
//     _fadeCtrl.forward();
//
//     // Register the ViewModel once here so child screens can reuse it
//     Get.put(TaskViewModel());
//   }
//
//   @override
//   void dispose() {
//     _fadeCtrl.dispose();
//     super.dispose();
//   }
//
//   // ──────────────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//       statusBarColor:       Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//     ));
//
//     return Scaffold(
//       backgroundColor: AppColors.surface,
//       body: FadeTransition(
//         opacity: _fadeAnim,
//         child: Column(
//           children: [
//             _buildHeader(),
//             Expanded(
//               child: SingleChildScrollView(
//                 physics: const BouncingScrollPhysics(),
//                 padding: const EdgeInsets.fromLTRB(18, 28, 18, 40),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     _sectionHeader(
//                         'What would you like to do?',
//                         Icons.tune_rounded,
//                         AppColors.cyan),
//                     const SizedBox(height: 20),
//
//                     // ── Two main action cards ─────────────────────────────
//                     _buildOptionCard(
//                       icon:        Icons.assignment_ind_rounded,
//                       label:       'MY Tasks',
//                       subtitle:    'View tasks assigned to you',
//                       color:       AppColors.skyBlueDk,
//                       gradientEnd: AppColors.cyan,
//                       onTap: () => Get.to(
//                             () => const AssignedTasksScreen(),
//                         transition:  Transition.rightToLeft,
//                         duration:    const Duration(milliseconds: 300),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//
//                     _buildOptionCard(
//                       icon:        Icons.add_task_rounded,
//                       label:       'Create Task',
//                       subtitle:    'Create a new task',
//                       color:       AppColors.greenTeal,
//                       gradientEnd: AppColors.cyanBright,
//                       onTap: () => Get.to(
//                             () => const CreateTaskScreen(),
//                         transition:  Transition.rightToLeft,
//                         duration:    const Duration(milliseconds: 300),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Header ─────────────────────────────────────────────────────────────────
//   Widget _buildHeader() {
//     return Container(
//       decoration: const BoxDecoration(
//         gradient: LinearGradient(
//           colors: [
//             AppColors.primary,
//             AppColors.cyan,
//             AppColors.cyanBright,
//             AppColors.greenTeal,
//           ],
//           begin: Alignment.topLeft,
//           end:   Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.only(
//           bottomLeft:  Radius.circular(36),
//           bottomRight: Radius.circular(36),
//         ),
//       ),
//       child: Stack(
//         children: [
//           Positioned(top: -50, right: -30,
//               child: _decorCircle(180, AppColors.greenTeal, 0.12)),
//           Positioned(bottom: -40, left: -20,
//               child: _decorCircle(130, Colors.white, 0.10)),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
//               child: Row(
//                 children: [
//                   // Back button
//                   GestureDetector(
//                     onTap: () => Get.back(),
//                     child: Container(
//                       width: 42, height: 42,
//                       decoration: BoxDecoration(
//                         color:        Colors.white.withOpacity(0.12),
//                         borderRadius: BorderRadius.circular(10),
//                         border:       Border.all(color: Colors.white.withOpacity(0.18)),
//                       ),
//                       child: const Icon(
//                           Icons.arrow_back_ios_new_rounded,
//                           color: Colors.white, size: 18),
//                     ),
//                   ),
//                   const SizedBox(width: 14),
//
//                   // Title
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Task Manager',
//                           style: TextStyle(
//                             color:      Colors.white,
//                             fontSize:   18,
//                             fontWeight: FontWeight.w800,
//                             letterSpacing: 0.2,
//                           ),
//                         ),
//                         Text(
//                           'GPS Workforce Monitor System',
//                           style: TextStyle(
//                             color:      Colors.white.withOpacity(0.65),
//                             fontSize:   11,
//                             fontWeight: FontWeight.w400,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   // Task icon badge
//                   Container(
//                     width: 42, height: 42,
//                     decoration: BoxDecoration(
//                       color:        Colors.white.withOpacity(0.12),
//                       borderRadius: BorderRadius.circular(10),
//                       border:       Border.all(color: Colors.white.withOpacity(0.18)),
//                     ),
//                     child: const Icon(
//                         Icons.task_alt_rounded,
//                         color: Colors.white, size: 22),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Big option card ────────────────────────────────────────────────────────
//   Widget _buildOptionCard({
//     required IconData     icon,
//     required String       label,
//     required String       subtitle,
//     required Color        color,
//     required Color        gradientEnd,
//     required VoidCallback onTap,
//   }) {
//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width:  double.infinity,
//         padding: const EdgeInsets.all(22),
//         decoration: BoxDecoration(
//           color:        AppColors.cardBg,
//           borderRadius: BorderRadius.circular(18),
//           border:       Border.all(color: AppColors.divider),
//           boxShadow: [
//             BoxShadow(
//               color:      Colors.black.withOpacity(0.05),
//               blurRadius: 14,
//               offset:     const Offset(0, 5),
//             ),
//           ],
//         ),
//         child: Row(
//           children: [
//             // Icon container with gradient background
//             Container(
//               width: 62, height: 62,
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [color.withOpacity(0.15), gradientEnd.withOpacity(0.08)],
//                   begin:  Alignment.topLeft,
//                   end:    Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(16),
//                 border: Border.all(color: color.withOpacity(0.20)),
//               ),
//               child: Icon(icon, size: 30, color: color),
//             ),
//             const SizedBox(width: 18),
//
//             // Text
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     label,
//                     style: const TextStyle(
//                       color:      AppColors.textPrimary,
//                       fontSize:   16,
//                       fontWeight: FontWeight.w700,
//                       letterSpacing: 0.1,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     subtitle,
//                     style: TextStyle(
//                       color:      AppColors.textSecondary,
//                       fontSize:   12,
//                       fontWeight: FontWeight.w400,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//
//             // Arrow
//             Container(
//               width: 34, height: 34,
//               decoration: BoxDecoration(
//                 color:        color.withOpacity(0.10),
//                 borderRadius: BorderRadius.circular(10),
//               ),
//               child: Icon(
//                 Icons.arrow_forward_ios_rounded,
//                 color: color, size: 16,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   // ── Helpers ────────────────────────────────────────────────────────────────
//   Widget _sectionHeader(String title, IconData icon, Color color) {
//     return Row(children: [
//       Container(
//           width: 4, height: 20,
//           decoration: BoxDecoration(
//               gradient:     AppColors.brandGradient,
//               borderRadius: BorderRadius.circular(2))),
//       const SizedBox(width: 8),
//       Container(
//         width: 28, height: 28,
//         decoration: BoxDecoration(
//             color:        color.withOpacity(0.10),
//             borderRadius: BorderRadius.circular(8)),
//         child: Icon(icon, size: 15, color: color),
//       ),
//       const SizedBox(width: 8),
//       Text(title,
//           style: const TextStyle(
//               color:      AppColors.primary,
//               fontSize:   13,
//               fontWeight: FontWeight.w700,
//               letterSpacing: 0.3)),
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
// }

///responsive
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../AppColors.dart';
import '../ViewModels/task_view_model.dart';
import 'AssignedTasksScreen.dart';
import 'create_task_screen.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize Animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _fadeController.forward();

    // Register ViewModel
    Get.put(TaskViewModel());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 32, 18, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Task Management', Icons.tune_rounded, AppColors.cyan),
                    const SizedBox(height: 12),
                    Text(
                      'What would you like to do today?',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Option Cards
                    _buildOptionCard(
                      icon: Icons.assignment_ind_rounded,
                      label: 'My Tasks',
                      subtitle: 'View all tasks assigned to you',
                      color: AppColors.skyBlueDk,
                      gradientEnd: AppColors.cyan,
                      onTap: () => Get.to(
                            () => const AssignedTasksScreen(),
                        transition: Transition.rightToLeft,
                        duration: const Duration(milliseconds: 280),
                      ),
                    ),

                    const SizedBox(height: 18),

                    _buildOptionCard(
                      icon: Icons.add_task_rounded,
                      label: 'Create New Task',
                      subtitle: 'Assign a task to team members',
                      color: AppColors.greenTeal,
                      gradientEnd: AppColors.cyanBright,
                      onTap: () => Get.to(
                            () => const CreateTaskScreen(),
                        transition: Transition.rightToLeft,
                        duration: const Duration(milliseconds: 280),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================== HEADER ======================
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -55, right: -35, child: _decorCircle(190, AppColors.greenTeal, 0.13)),
          Positioned(bottom: -45, left: -25, child: _decorCircle(135, Colors.white, 0.09)),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Row(
                children: [
                  // Back Button
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.22)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 19),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Title
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Task Manager',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Organize • Assign • Track',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================== OPTION CARD ======================
  Widget _buildOptionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Color gradientEnd,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.18), gradientEnd.withOpacity(0.10)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================== SECTION HEADER ======================
  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 24,
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _decorCircle(double size, Color color, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );
}