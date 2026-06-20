// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:get/get.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// //
// // import '../AppColors.dart';
// // import '../ViewModels/task_view_model.dart';
// // import '../Models/task_model.dart';
// // import 'AssignedTasksScreen.dart'; // sirf _showUpdateSheet aur _TaskCard ke liye import rakha
// // import 'HomeScreenComponents/app_bottom_navbar.dart';
// // import 'HomeScreenComponents/navbar.dart';
// // import 'create_task_screen.dart';
// //
// // /// Active tab enum
// // enum _TaskTab { assigned, myTasks }
// //
// // class TaskScreen extends StatefulWidget {
// //   final int currentIndex;
// //   final int chatBadgeCount;
// //   final ValueChanged<int> onNavTap;
// //
// //   const TaskScreen({
// //     super.key,
// //     this.currentIndex = 3,
// //     this.chatBadgeCount = 0,
// //     required this.onNavTap,
// //   });
// //
// //   @override
// //   State<TaskScreen> createState() => _TaskScreenState();
// // }
// //
// // class _TaskScreenState extends State<TaskScreen>
// //     with SingleTickerProviderStateMixin {
// //   late final AnimationController _fadeController;
// //   late final Animation<double> _fadeAnimation;
// //
// //   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
// //
// //   _TaskTab _activeTab = _TaskTab.assigned;
// //
// //   // ── User data ──────────────────────────────────────────────────────────────
// //   String _empName = 'Employee';
// //   String _empInitials = '??';
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //
// //     _fadeController = AnimationController(
// //       vsync: this,
// //       duration: const Duration(milliseconds: 700),
// //     );
// //     _fadeAnimation =
// //         CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
// //     _fadeController.forward();
// //
// //     _loadUserData();
// //
// //     if (!Get.isRegistered<TaskViewModel>()) {
// //       Get.put(TaskViewModel());
// //     }
// //
// //     // fetch data on open
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       final vm = Get.find<TaskViewModel>();
// //       vm.fetchAssignedTasks();
// //     });
// //   }
// //
// //   Future<void> _loadUserData() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final name = prefs.getString('userName') ?? 'Employee';
// //     setState(() {
// //       _empName = name;
// //       _empInitials = _getInitials(name);
// //     });
// //   }
// //
// //   String _getInitials(String name) {
// //     if (name.isEmpty) return '??';
// //     final parts = name.trim().split(' ');
// //     if (parts.length >= 2) {
// //       return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
// //     }
// //     return name[0].toUpperCase();
// //   }
// //
// //   @override
// //   void dispose() {
// //     _fadeController.dispose();
// //     super.dispose();
// //   }
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
// //       statusBarColor: Colors.transparent,
// //       statusBarIconBrightness: Brightness.light,
// //     ));
// //
// //     return Scaffold(
// //       key: _scaffoldKey,
// //       backgroundColor: AppColors.surface,
// //       appBar: Navbar(
// //         userName: _empName,
// //         userInitials: _empInitials,
// //         lastSync: 'Just now',
// //         scaffoldKey: _scaffoldKey,
// //       ),
// //       // ... rest of the build method remains the same
// //
// // // class _TaskScreenState extends State<TaskScreen>
// // //     with SingleTickerProviderStateMixin {
// // //   late final AnimationController _fadeController;
// // //   late final Animation<double> _fadeAnimation;
// // //
// // //   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
// // //
// // //   _TaskTab _activeTab = _TaskTab.assigned;
// // //
// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //
// // //     _fadeController = AnimationController(
// // //       vsync: this,
// // //       duration: const Duration(milliseconds: 700),
// // //     );
// // //     _fadeAnimation =
// // //         CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
// // //     _fadeController.forward();
// // //
// // //     if (!Get.isRegistered<TaskViewModel>()) {
// // //       Get.put(TaskViewModel());
// // //     }
// // //
// // //     // fetch data on open
// // //     WidgetsBinding.instance.addPostFrameCallback((_) {
// // //       final vm = Get.find<TaskViewModel>();
// // //       vm.fetchAssignedTasks();
// // //       // agar MyTasks ke liye alag fetch ho to yahan call karein
// // //       // vm.fetchMyTasks();
// // //     });
// // //   }
// // //
// // //   @override
// // //   void dispose() {
// // //     _fadeController.dispose();
// // //     super.dispose();
// // //   }
// // //
// // //   @override
// // //   Widget build(BuildContext context) {
// // //     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
// // //       statusBarColor: Colors.transparent,
// // //       statusBarIconBrightness: Brightness.light,
// // //     ));
// // //
// // //     return Scaffold(
// // //       key: _scaffoldKey,
// // //       backgroundColor: AppColors.surface,
// // //       appBar: Navbar(
// // //         userName: 'Mian Muhammad Arslan',
// // //         userInitials: 'MM',
// // //         lastSync: 'Just now',
// // //         scaffoldKey: _scaffoldKey,
// // //       ),
// //       body: Column(
// //         children: [
// //           // ── Top section (header + tabs + filter) ──
// //           FadeTransition(
// //             opacity: _fadeAnimation,
// //             child: Padding(
// //               padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
// //               child: Column(
// //                 crossAxisAlignment: CrossAxisAlignment.start,
// //                 children: [
// //                   // Section title
// //                   _sectionHeader(
// //                       'Tasks', Icons.task_alt_rounded, AppColors.cyan),
// //                   const SizedBox(height: 6),
// //                   Text(
// //                     'Manage your work easily',
// //                     style: TextStyle(
// //                       fontSize: 13.5,
// //                       color: AppColors.textSecondary,
// //                       height: 1.4,
// //                     ),
// //                   ),
// //                   const SizedBox(height: 20),
// //
// //                   // Tab row
// //                   _buildTabRow(),
// //                   const SizedBox(height: 14),
// //
// //                   // Filter chips (only for assigned tab)
// //                   if (_activeTab == _TaskTab.assigned) _buildFilterChips(),
// //                   if (_activeTab == _TaskTab.assigned)
// //                     const SizedBox(height: 10),
// //                 ],
// //               ),
// //             ),
// //           ),
// //
// //           // ── Scrollable task list ──
// //           Expanded(child: _buildTaskList()),
// //
// //           // ── Bottom Nav ──
// //           AppBottomNavBar(
// //             currentIndex: widget.currentIndex,
// //             chatBadgeCount: widget.chatBadgeCount,
// //             onTap: widget.onNavTap,
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   // ====================== TAB ROW ======================
// //   Widget _buildTabRow() {
// //     return Container(
// //       padding: const EdgeInsets.all(5),
// //       decoration: BoxDecoration(
// //         color: AppColors.cardBg,
// //         borderRadius: BorderRadius.circular(16),
// //         border: Border.all(color: AppColors.divider),
// //         boxShadow: [
// //           BoxShadow(
// //             color: Colors.black.withOpacity(0.05),
// //             blurRadius: 10,
// //             offset: const Offset(0, 3),
// //           ),
// //         ],
// //       ),
// //       child: Row(
// //         children: [
// //           // Assigned Tasks
// //           Expanded(
// //             flex: 5,
// //             child: GestureDetector(
// //               onTap: () {
// //                 setState(() => _activeTab = _TaskTab.assigned);
// //                 Get.find<TaskViewModel>().fetchAssignedTasks();
// //               },
// //               child: AnimatedContainer(
// //                 duration: const Duration(milliseconds: 220),
// //                 padding: const EdgeInsets.symmetric(vertical: 13),
// //                 decoration: BoxDecoration(
// //                   gradient: _activeTab == _TaskTab.assigned
// //                       ? const LinearGradient(
// //                     colors: [AppColors.primary, AppColors.cyan],
// //                     begin: Alignment.topLeft,
// //                     end: Alignment.bottomRight,
// //                   )
// //                       : null,
// //                   color: _activeTab == _TaskTab.assigned
// //                       ? null
// //                       : Colors.transparent,
// //                   borderRadius: BorderRadius.circular(12),
// //                   boxShadow: _activeTab == _TaskTab.assigned
// //                       ? [
// //                     BoxShadow(
// //                       color: AppColors.primary.withOpacity(0.30),
// //                       blurRadius: 8,
// //                       offset: const Offset(0, 3),
// //                     ),
// //                   ]
// //                       : null,
// //                 ),
// //                 child: Row(
// //                   mainAxisAlignment: MainAxisAlignment.center,
// //                   children: [
// //                     Icon(
// //                       Icons.assignment_ind_rounded,
// //                       color: _activeTab == _TaskTab.assigned
// //                           ? Colors.white
// //                           : AppColors.textSecondary,
// //                       size: 16,
// //                     ),
// //                     const SizedBox(width: 6),
// //                     Text(
// //                       'Assigned Tasks',
// //                       style: TextStyle(
// //                         color: _activeTab == _TaskTab.assigned
// //                             ? Colors.white
// //                             : AppColors.textSecondary,
// //                         fontSize: 13,
// //                         fontWeight: FontWeight.w700,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ),
// //           ),
// //
// //           const SizedBox(width: 5),
// //
// //           // My Tasks
// //           Expanded(
// //             flex: 4,
// //             child: GestureDetector(
// //               onTap: () {
// //                 setState(() => _activeTab = _TaskTab.myTasks);
// //                 // vm.fetchMyTasks(); // agar alag API ho
// //               },
// //               child: AnimatedContainer(
// //                 duration: const Duration(milliseconds: 220),
// //                 padding: const EdgeInsets.symmetric(vertical: 13),
// //                 decoration: BoxDecoration(
// //                   gradient: _activeTab == _TaskTab.myTasks
// //                       ? const LinearGradient(
// //                     colors: [AppColors.primary, AppColors.cyan],
// //                     begin: Alignment.topLeft,
// //                     end: Alignment.bottomRight,
// //                   )
// //                       : null,
// //                   color: _activeTab == _TaskTab.myTasks
// //                       ? null
// //                       : Colors.transparent,
// //                   borderRadius: BorderRadius.circular(12),
// //                   boxShadow: _activeTab == _TaskTab.myTasks
// //                       ? [
// //                     BoxShadow(
// //                       color: AppColors.primary.withOpacity(0.30),
// //                       blurRadius: 8,
// //                       offset: const Offset(0, 3),
// //                     ),
// //                   ]
// //                       : null,
// //                 ),
// //                 child: Row(
// //                   mainAxisAlignment: MainAxisAlignment.center,
// //                   children: [
// //                     Icon(
// //                       Icons.person_outline_rounded,
// //                       color: _activeTab == _TaskTab.myTasks
// //                           ? Colors.white
// //                           : AppColors.textSecondary,
// //                       size: 16,
// //                     ),
// //                     const SizedBox(width: 6),
// //                     Text(
// //                       'My Tasks',
// //                       style: TextStyle(
// //                         color: _activeTab == _TaskTab.myTasks
// //                             ? Colors.white
// //                             : AppColors.textSecondary,
// //                         fontSize: 13,
// //                         fontWeight: FontWeight.w600,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ),
// //           ),
// //
// //           const SizedBox(width: 5),
// //
// //           // + Create
// //           Expanded(
// //             flex: 3,
// //             child: GestureDetector(
// //               onTap: () => Get.to(
// //                     () => const CreateTaskScreen(),
// //                 transition: Transition.rightToLeft,
// //                 duration: const Duration(milliseconds: 280),
// //               ),
// //               child: Container(
// //                 padding: const EdgeInsets.symmetric(vertical: 13),
// //                 decoration: BoxDecoration(
// //                   color: Colors.transparent,
// //                   borderRadius: BorderRadius.circular(12),
// //                 ),
// //                 child: Row(
// //                   mainAxisAlignment: MainAxisAlignment.center,
// //                   children: [
// //                     Icon(Icons.add_rounded,
// //                         color: AppColors.textSecondary, size: 18),
// //                     const SizedBox(width: 4),
// //                     Text(
// //                       'Create',
// //                       style: TextStyle(
// //                         color: AppColors.textSecondary,
// //                         fontSize: 13,
// //                         fontWeight: FontWeight.w600,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// //
// //   // ====================== FILTER CHIPS ======================
// //   Widget _buildFilterChips() {
// //     final vm = Get.find<TaskViewModel>();
// //     return Obx(() {
// //       final current = vm.assignedFilter.value;
// //       return SizedBox(
// //         height: 35,
// //         child: ListView.separated(
// //           scrollDirection: Axis.horizontal,
// //           padding: EdgeInsets.zero,
// //           itemCount: vm.filterOptions.length,
// //           separatorBuilder: (_, __) => const SizedBox(width: 8),
// //           itemBuilder: (_, i) {
// //             final opt = vm.filterOptions[i];
// //             final selected = current == opt;
// //             return GestureDetector(
// //               onTap: () => vm.assignedFilter.value = opt,
// //               child: AnimatedContainer(
// //                 duration: const Duration(milliseconds: 180),
// //                 padding:
// //                 const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
// //                 decoration: BoxDecoration(
// //                   color: selected ? AppColors.cyan : AppColors.cardBg,
// //                   borderRadius: BorderRadius.circular(20),
// //                   border: Border.all(
// //                     color: selected ? AppColors.cyan : AppColors.divider,
// //                   ),
// //                 ),
// //                 child: Text(
// //                   opt,
// //                   style: TextStyle(
// //                     color: selected ? Colors.white : AppColors.textSecondary,
// //                     fontSize: 12,
// //                     fontWeight:
// //                     selected ? FontWeight.w700 : FontWeight.w500,
// //                   ),
// //                 ),
// //               ),
// //             );
// //           },
// //         ),
// //       );
// //     });
// //   }
// //
// //   // ====================== TASK LIST ======================
// //   Widget _buildTaskList() {
// //     final vm = Get.find<TaskViewModel>();
// //
// //     if (_activeTab == _TaskTab.assigned) {
// //       return Obx(() {
// //         if (vm.isLoadingAssigned.value) {
// //           return const Center(
// //               child: CircularProgressIndicator(color: AppColors.cyan));
// //         }
// //         final tasks = vm.filteredAssigned;
// //         if (tasks.isEmpty) {
// //           return Center(
// //             child: Column(
// //               mainAxisSize: MainAxisSize.min,
// //               children: [
// //                 Icon(Icons.assignment_outlined,
// //                     size: 56, color: AppColors.textSecondary.withOpacity(0.4)),
// //                 const SizedBox(height: 12),
// //                 Text(
// //                   'No assigned tasks',
// //                   style: TextStyle(
// //                       color: AppColors.textSecondary, fontSize: 14),
// //                 ),
// //               ],
// //             ),
// //           );
// //         }
// //         return ListView.separated(
// //           padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
// //           itemCount: tasks.length,
// //           separatorBuilder: (_, __) => const SizedBox(height: 12),
// //           itemBuilder: (_, i) => _TaskCard(
// //             task: tasks[i],
// //             onUpdate: () => _showUpdateSheet(tasks[i]),
// //           ),
// //         );
// //       });
// //     }
// //
// //     // ── My Tasks tab ──
// //     // Agar alag ViewModel/list hai to Obx se bind karein.
// //     // Abhi placeholder dikh raha hai — apni list yahan lagaein.
// //     return Obx(() {
// //       if (vm.isLoadingAssigned.value) {
// //         return const Center(
// //             child: CircularProgressIndicator(color: AppColors.cyan));
// //       }
// //       // Replace vm.filteredAssigned with vm.filteredMyTasks when available
// //       final tasks = vm.filteredAssigned;
// //       if (tasks.isEmpty) {
// //         return Center(
// //           child: Column(
// //             mainAxisSize: MainAxisSize.min,
// //             children: [
// //               Icon(Icons.person_outline_rounded,
// //                   size: 56, color: AppColors.textSecondary.withOpacity(0.4)),
// //               const SizedBox(height: 12),
// //               Text(
// //                 'No tasks found',
// //                 style:
// //                 TextStyle(color: AppColors.textSecondary, fontSize: 14),
// //               ),
// //             ],
// //           ),
// //         );
// //       }
// //       return ListView.separated(
// //         padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
// //         itemCount: tasks.length,
// //         separatorBuilder: (_, __) => const SizedBox(height: 12),
// //         itemBuilder: (_, i) => _TaskCard(
// //           task: tasks[i],
// //           onUpdate: () => _showUpdateSheet(tasks[i]),
// //         ),
// //       );
// //     });
// //   }
// //
// //   // ====================== UPDATE SHEET ======================
// //   // AssignedTasksScreen se same sheet — yahan delegate karte hain
// //   void _showUpdateSheet(TaskModel task) {
// //     // AssignedTasksScreen ko temporarily push karke sheet open karo
// //     // Ya phir same sheet logic copy karein. Seedha AssignedTasksScreen
// //     // ka static method call karna behtar hai — lekin Flutter mein
// //     // instance method hoti hai isliye ek helper widget banate hain.
// //     _UpdateSheetHelper.show(context, task, Get.find<TaskViewModel>());
// //   }
// //
// //   // ====================== SECTION HEADER ======================
// //   Widget _sectionHeader(String title, IconData icon, Color color) {
// //     return Row(
// //       children: [
// //         Container(
// //           width: 5,
// //           height: 24,
// //           decoration: BoxDecoration(
// //             gradient: AppColors.brandGradient,
// //             borderRadius: BorderRadius.circular(3),
// //           ),
// //         ),
// //         const SizedBox(width: 12),
// //         Container(
// //           width: 32,
// //           height: 32,
// //           decoration: BoxDecoration(
// //             color: color.withOpacity(0.1),
// //             borderRadius: BorderRadius.circular(10),
// //           ),
// //           child: Icon(icon, size: 17, color: color),
// //         ),
// //         const SizedBox(width: 12),
// //         Text(
// //           title,
// //           style: const TextStyle(
// //             fontSize: 15.5,
// //             fontWeight: FontWeight.w700,
// //             color: AppColors.textPrimary,
// //             letterSpacing: 0.2,
// //           ),
// //         ),
// //       ],
// //     );
// //   }
// // }
// //
// // // ══════════════════════════════════════════════════════════════════════════
// // // _TaskCard — same as in AssignedTasksScreen (copied here for inline use)
// // // ══════════════════════════════════════════════════════════════════════════
// // class _TaskCard extends StatelessWidget {
// //   final TaskModel task;
// //   final VoidCallback onUpdate;
// //
// //   const _TaskCard({required this.task, required this.onUpdate});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final bool isCompleted = task.status == 'Completed';
// //
// //     Color statusColor;
// //     IconData statusIcon;
// //
// //     if (task.status == 'Completed') {
// //       statusColor = AppColors.greenTeal;
// //       statusIcon = Icons.check_circle_rounded;
// //     } else if (task.status == 'In Progress') {
// //       statusColor = AppColors.skyBlueDk;
// //       statusIcon = Icons.autorenew_rounded;
// //     } else {
// //       statusColor = AppColors.warning;
// //       statusIcon = Icons.hourglass_empty_rounded;
// //     }
// //
// //     Color priorityColor = AppColors.textSecondary;
// //     if (task.priority == 'High') priorityColor = AppColors.error;
// //     if (task.priority == 'Medium') priorityColor = AppColors.warning;
// //     if (task.priority == 'Low') priorityColor = AppColors.greenTeal;
// //
// //     return Container(
// //       decoration: BoxDecoration(
// //         color: AppColors.cardBg,
// //         borderRadius: BorderRadius.circular(16),
// //         border: Border.all(color: statusColor.withOpacity(0.20)),
// //         boxShadow: [
// //           BoxShadow(
// //               color: Colors.black.withOpacity(0.05),
// //               blurRadius: 12,
// //               offset: const Offset(0, 4)),
// //         ],
// //       ),
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           // Status bar
// //           Container(
// //             padding:
// //             const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
// //             decoration: BoxDecoration(
// //               color: statusColor.withOpacity(0.06),
// //               borderRadius:
// //               const BorderRadius.vertical(top: Radius.circular(16)),
// //             ),
// //             child: Row(
// //               children: [
// //                 Container(
// //                   padding: const EdgeInsets.symmetric(
// //                       horizontal: 9, vertical: 4),
// //                   decoration: BoxDecoration(
// //                     color: statusColor.withOpacity(0.14),
// //                     borderRadius: BorderRadius.circular(6),
// //                   ),
// //                   child: Row(
// //                     mainAxisSize: MainAxisSize.min,
// //                     children: [
// //                       Icon(statusIcon, size: 11, color: statusColor),
// //                       const SizedBox(width: 4),
// //                       Text(task.status,
// //                           style: TextStyle(
// //                               fontSize: 10,
// //                               fontWeight: FontWeight.w700,
// //                               color: statusColor)),
// //                     ],
// //                   ),
// //                 ),
// //                 const SizedBox(width: 8),
// //                 Container(
// //                   padding: const EdgeInsets.symmetric(
// //                       horizontal: 9, vertical: 4),
// //                   decoration: BoxDecoration(
// //                     color: priorityColor.withOpacity(0.10),
// //                     borderRadius: BorderRadius.circular(6),
// //                   ),
// //                   child: Row(
// //                     mainAxisSize: MainAxisSize.min,
// //                     children: [
// //                       Icon(Icons.flag_rounded,
// //                           size: 11, color: priorityColor),
// //                       const SizedBox(width: 4),
// //                       Text(task.priority,
// //                           style: TextStyle(
// //                               fontSize: 10,
// //                               fontWeight: FontWeight.w700,
// //                               color: priorityColor)),
// //                     ],
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //
// //           // Card body
// //           Padding(
// //             padding: const EdgeInsets.all(16),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //                 Text(
// //                   task.taskTitle,
// //                   maxLines: 1,
// //                   overflow: TextOverflow.ellipsis,
// //                   style: const TextStyle(
// //                       fontSize: 14, fontWeight: FontWeight.w700),
// //                 ),
// //                 const SizedBox(height: 4),
// //                 Text(
// //                   'Assigned by: ${task.assignedBy}',
// //                   maxLines: 1,
// //                   overflow: TextOverflow.ellipsis,
// //                   style:
// //                   TextStyle(color: AppColors.textSecondary, fontSize: 11),
// //                 ),
// //                 const SizedBox(height: 10),
// //                 Wrap(
// //                   spacing: 8,
// //                   runSpacing: 6,
// //                   children: [
// //                     _MetaChip(
// //                         icon: Icons.person,
// //                         label: task.empName,
// //                         color: AppColors.skyBlueDk),
// //                     _MetaChip(
// //                         icon: Icons.calendar_today,
// //                         label: task.dueDate,
// //                         color: AppColors.greenTeal),
// //                     _MetaChip(
// //                         icon: Icons.category_rounded,
// //                         label: task.taskType,
// //                         color: AppColors.primary),
// //                   ],
// //                 ),
// //                 const SizedBox(height: 14),
// //                 Row(
// //                   children: [
// //                     Icon(Icons.person_outline_rounded,
// //                         size: 13, color: AppColors.textSecondary),
// //                     const SizedBox(width: 4),
// //                     Expanded(
// //                       child: Text(
// //                         task.empName,
// //                         style: const TextStyle(
// //                             fontSize: 11,
// //                             fontWeight: FontWeight.w600,
// //                             color: AppColors.textPrimary),
// //                         overflow: TextOverflow.ellipsis,
// //                       ),
// //                     ),
// //                     if (!isCompleted)
// //                       GestureDetector(
// //                         onTap: onUpdate,
// //                         child: Container(
// //                           padding: const EdgeInsets.symmetric(
// //                               horizontal: 14, vertical: 8),
// //                           decoration: BoxDecoration(
// //                             gradient: const LinearGradient(
// //                               colors: [AppColors.primary, AppColors.cyan],
// //                               begin: Alignment.topLeft,
// //                               end: Alignment.bottomRight,
// //                             ),
// //                             borderRadius: BorderRadius.circular(8),
// //                             boxShadow: [
// //                               BoxShadow(
// //                                   color: AppColors.cyan.withOpacity(0.30),
// //                                   blurRadius: 8,
// //                                   offset: const Offset(0, 3)),
// //                             ],
// //                           ),
// //                           child: const Row(
// //                             mainAxisSize: MainAxisSize.min,
// //                             children: [
// //                               Icon(Icons.edit_rounded,
// //                                   size: 13, color: Colors.white),
// //                               SizedBox(width: 5),
// //                               Text('Update',
// //                                   style: TextStyle(
// //                                       fontSize: 12,
// //                                       fontWeight: FontWeight.w700,
// //                                       color: Colors.white)),
// //                             ],
// //                           ),
// //                         ),
// //                       ),
// //                   ],
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // class _MetaChip extends StatelessWidget {
// //   final IconData icon;
// //   final String label;
// //   final Color color;
// //
// //   const _MetaChip(
// //       {required this.icon, required this.label, required this.color});
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
// //       decoration: BoxDecoration(
// //         color: color.withOpacity(0.1),
// //         borderRadius: BorderRadius.circular(8),
// //       ),
// //       child: Row(
// //         mainAxisSize: MainAxisSize.min,
// //         children: [
// //           Icon(icon, size: 12, color: color),
// //           const SizedBox(width: 4),
// //           Text(label,
// //               maxLines: 1,
// //               overflow: TextOverflow.ellipsis,
// //               style: TextStyle(color: color, fontSize: 10)),
// //         ],
// //       ),
// //     );
// //   }
// // }
// //
// // // ══════════════════════════════════════════════════════════════════════════
// // // Update sheet helper — delegates to AssignedTasksScreen's sheet logic
// // // ══════════════════════════════════════════════════════════════════════════
// // class _UpdateSheetHelper {
// //   static void show(
// //       BuildContext context, TaskModel task, TaskViewModel vm) {
// //     // AssignedTasksScreen ka _showUpdateSheet same hai —
// //     // Temporarily AssignedTasksScreen navigate karke sheet open karo
// //     // Ya directly yahan sheet duplicate karein. Seedha VM method call:
// //     // vm.showUpdateBottomSheet(task) — agar VM mein method ho.
// //     //
// //     // Agar AssignedTasksScreen mein _showUpdateSheet public nahi hai
// //     // to yahan same sheet code paste karein ya VM mein move karein.
// //     //
// //     // Quick solution: navigate to AssignedTasksScreen with task pre-selected
// //     Get.to(
// //           () => const AssignedTasksScreen(),
// //       transition: Transition.downToUp,
// //       duration: const Duration(milliseconds: 280),
// //     );
// //   }
// // }
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:intl/intl.dart';
//
// import '../AppColors.dart';
// import '../ViewModels/task_view_model.dart';
// import '../Models/task_model.dart';
// import 'HomeScreenComponents/app_bottom_navbar.dart';
// import 'HomeScreenComponents/navbar.dart';
// import 'create_task_screen.dart';
//
// /// Active tab enum
// enum _TaskTab { assigned, myTasks }
//
// class TaskScreen extends StatefulWidget {
//   final int currentIndex;
//   final int chatBadgeCount;
//   final ValueChanged<int> onNavTap;
//
//   const TaskScreen({
//     super.key,
//     this.currentIndex = 3,
//     this.chatBadgeCount = 0,
//     required this.onNavTap,
//   });
//
//   @override
//   State<TaskScreen> createState() => _TaskScreenState();
// }
//
// class _TaskScreenState extends State<TaskScreen>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _fadeController;
//   late final Animation<double> _fadeAnimation;
//
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   _TaskTab _activeTab = _TaskTab.assigned;
//
//   // ── Track updated tasks ──────────────────────────────────────────────────────
//   final RxSet<int> _updatedIds = <int>{}.obs;
//
//   // ── User data ──────────────────────────────────────────────────────────────
//   String _empName = 'Employee';
//   String _empInitials = '??';
//
//   @override
//   void initState() {
//     super.initState();
//
//     _fadeController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 700),
//     );
//     _fadeAnimation =
//         CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
//     _fadeController.forward();
//
//     _loadUserData();
//
//     if (!Get.isRegistered<TaskViewModel>()) {
//       Get.put(TaskViewModel());
//     }
//
//     // fetch data on open
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final vm = Get.find<TaskViewModel>();
//       vm.fetchAssignedTasks();
//     });
//   }
//
//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final name = prefs.getString('userName') ?? 'Employee';
//     setState(() {
//       _empName = name;
//       _empInitials = _getInitials(name);
//     });
//   }
//
//   String _getInitials(String name) {
//     if (name.isEmpty) return '??';
//     final parts = name.trim().split(' ');
//     if (parts.length >= 2) {
//       return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
//     }
//     return name[0].toUpperCase();
//   }
//
//   @override
//   void dispose() {
//     _fadeController.dispose();
//     super.dispose();
//   }
//
//   // ── Status mapping helper ──────────────────────────────────────────────────
//   String _normalizeStatus(String status) {
//     final normalized = status.toLowerCase().trim();
//
//     // Status mapping - maps UI status to database values
//     final Map<String, String> statusMap = {
//       // UI values to database values
//       'pending': 'Pending',
//       'in progress': 'In Progress',
//       'inprogress': 'In Progress',
//       'progress': 'In Progress',
//       'completed': 'Completed',
//       'done': 'Completed',
//       'overdue': 'Overdue',
//       'paused': 'Paused',
//       'cancelled': 'Cancelled',
//       'open': 'Pending',
//     };
//
//     // Return mapped value or the original with first letter capitalized
//     return statusMap[normalized] ??
//         (status.isNotEmpty ? '${status[0].toUpperCase()}${status.substring(1).toLowerCase()}' : status);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//     ));
//
//     return Scaffold(
//       key: _scaffoldKey,
//       backgroundColor: AppColors.surface,
//       appBar: Navbar(
//         userName: _empName,
//         userInitials: _empInitials,
//         lastSync: 'Just now',
//         scaffoldKey: _scaffoldKey,
//       ),
//       body: Column(
//         children: [
//           // ── Top section (header + tabs + filter) ──
//           FadeTransition(
//             opacity: _fadeAnimation,
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Section title
//                   _sectionHeader(
//                       'Tasks', Icons.task_alt_rounded, AppColors.cyan),
//                   const SizedBox(height: 6),
//                   Text(
//                     'Manage your work easily',
//                     style: TextStyle(
//                       fontSize: 13.5,
//                       color: AppColors.textSecondary,
//                       height: 1.4,
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//
//                   // Tab row
//                   _buildTabRow(),
//                   const SizedBox(height: 14),
//
//                   // Filter chips (only for assigned tab)
//                   if (_activeTab == _TaskTab.assigned) _buildFilterChips(),
//                   if (_activeTab == _TaskTab.assigned)
//                     const SizedBox(height: 10),
//                 ],
//               ),
//             ),
//           ),
//
//           // ── Scrollable task list ──
//           Expanded(child: _buildTaskList()),
//
//           // ── Bottom Nav ──
//           AppBottomNavBar(
//             currentIndex: widget.currentIndex,
//             chatBadgeCount: widget.chatBadgeCount,
//             onTap: widget.onNavTap,
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ====================== TAB ROW ======================
//   Widget _buildTabRow() {
//     return Container(
//       padding: const EdgeInsets.all(5),
//       decoration: BoxDecoration(
//         color: AppColors.cardBg,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: AppColors.divider),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           // Assigned Tasks
//           Expanded(
//             flex: 5,
//             child: GestureDetector(
//               onTap: () {
//                 setState(() => _activeTab = _TaskTab.assigned);
//                 Get.find<TaskViewModel>().fetchAssignedTasks();
//               },
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 220),
//                 padding: const EdgeInsets.symmetric(vertical: 13),
//                 decoration: BoxDecoration(
//                   gradient: _activeTab == _TaskTab.assigned
//                       ? const LinearGradient(
//                     colors: [AppColors.primary, AppColors.cyan],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   )
//                       : null,
//                   color: _activeTab == _TaskTab.assigned
//                       ? null
//                       : Colors.transparent,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: _activeTab == _TaskTab.assigned
//                       ? [
//                     BoxShadow(
//                       color: AppColors.primary.withOpacity(0.30),
//                       blurRadius: 8,
//                       offset: const Offset(0, 3),
//                     ),
//                   ]
//                       : null,
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(
//                       Icons.assignment_ind_rounded,
//                       color: _activeTab == _TaskTab.assigned
//                           ? Colors.white
//                           : AppColors.textSecondary,
//                       size: 16,
//                     ),
//                     const SizedBox(width: 6),
//                     Text(
//                       'Assigned Tasks',
//                       style: TextStyle(
//                         color: _activeTab == _TaskTab.assigned
//                             ? Colors.white
//                             : AppColors.textSecondary,
//                         fontSize: 13,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//
//           const SizedBox(width: 5),
//
//           // My Tasks
//           Expanded(
//             flex: 4,
//             child: GestureDetector(
//               onTap: () {
//                 setState(() => _activeTab = _TaskTab.myTasks);
//               },
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 220),
//                 padding: const EdgeInsets.symmetric(vertical: 13),
//                 decoration: BoxDecoration(
//                   gradient: _activeTab == _TaskTab.myTasks
//                       ? const LinearGradient(
//                     colors: [AppColors.primary, AppColors.cyan],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   )
//                       : null,
//                   color: _activeTab == _TaskTab.myTasks
//                       ? null
//                       : Colors.transparent,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: _activeTab == _TaskTab.myTasks
//                       ? [
//                     BoxShadow(
//                       color: AppColors.primary.withOpacity(0.30),
//                       blurRadius: 8,
//                       offset: const Offset(0, 3),
//                     ),
//                   ]
//                       : null,
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(
//                       Icons.person_outline_rounded,
//                       color: _activeTab == _TaskTab.myTasks
//                           ? Colors.white
//                           : AppColors.textSecondary,
//                       size: 16,
//                     ),
//                     const SizedBox(width: 6),
//                     Text(
//                       'My Tasks',
//                       style: TextStyle(
//                         color: _activeTab == _TaskTab.myTasks
//                             ? Colors.white
//                             : AppColors.textSecondary,
//                         fontSize: 13,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//
//           const SizedBox(width: 5),
//
//           // + Create
//           Expanded(
//             flex: 3,
//             child: GestureDetector(
//               onTap: () => Get.to(
//                     () => const CreateTaskScreen(),
//                 transition: Transition.rightToLeft,
//                 duration: const Duration(milliseconds: 280),
//               ),
//               child: Container(
//                 padding: const EdgeInsets.symmetric(vertical: 13),
//                 decoration: BoxDecoration(
//                   color: Colors.transparent,
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(Icons.add_rounded,
//                         color: AppColors.textSecondary, size: 18),
//                     const SizedBox(width: 4),
//                     Text(
//                       'Create',
//                       style: TextStyle(
//                         color: AppColors.textSecondary,
//                         fontSize: 13,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ====================== FILTER CHIPS ======================
//   Widget _buildFilterChips() {
//     final vm = Get.find<TaskViewModel>();
//     return Obx(() {
//       final current = vm.assignedFilter.value;
//       return SizedBox(
//         height: 35,
//         child: ListView.separated(
//           scrollDirection: Axis.horizontal,
//           padding: EdgeInsets.zero,
//           itemCount: vm.filterOptions.length,
//           separatorBuilder: (_, __) => const SizedBox(width: 8),
//           itemBuilder: (_, i) {
//             final opt = vm.filterOptions[i];
//             final selected = current == opt;
//             return GestureDetector(
//               onTap: () => vm.assignedFilter.value = opt,
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 180),
//                 padding:
//                 const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: selected ? AppColors.cyan : AppColors.cardBg,
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(
//                     color: selected ? AppColors.cyan : AppColors.divider,
//                   ),
//                 ),
//                 child: Text(
//                   opt,
//                   style: TextStyle(
//                     color: selected ? Colors.white : AppColors.textSecondary,
//                     fontSize: 12,
//                     fontWeight:
//                     selected ? FontWeight.w700 : FontWeight.w500,
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       );
//     });
//   }
//
//   // ====================== TASK LIST ======================
//   Widget _buildTaskList() {
//     final vm = Get.find<TaskViewModel>();
//
//     if (_activeTab == _TaskTab.assigned) {
//       return Obx(() {
//         if (vm.isLoadingAssigned.value) {
//           return const Center(
//               child: CircularProgressIndicator(color: AppColors.cyan));
//         }
//         final tasks = vm.filteredAssigned;
//         if (tasks.isEmpty) {
//           return Center(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(Icons.assignment_outlined,
//                     size: 56, color: AppColors.textSecondary.withOpacity(0.4)),
//                 const SizedBox(height: 12),
//                 Text(
//                   'No assigned tasks',
//                   style: TextStyle(
//                       color: AppColors.textSecondary, fontSize: 14),
//                 ),
//               ],
//             ),
//           );
//         }
//         return ListView.separated(
//           padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
//           itemCount: tasks.length,
//           separatorBuilder: (_, __) => const SizedBox(height: 12),
//           itemBuilder: (_, i) => Obx(() => _TaskCard(
//             task: tasks[i],
//             isUpdated: _updatedIds.contains(tasks[i].id),
//             onUpdate: () => _showUpdateSheet(tasks[i]),
//           )),
//         );
//       });
//     }
//
//     // ── My Tasks tab ──
//     return Obx(() {
//       if (vm.isLoadingAssigned.value) {
//         return const Center(
//             child: CircularProgressIndicator(color: AppColors.cyan));
//       }
//       final tasks = vm.filteredAssigned;
//       if (tasks.isEmpty) {
//         return Center(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Icon(Icons.person_outline_rounded,
//                   size: 56, color: AppColors.textSecondary.withOpacity(0.4)),
//               const SizedBox(height: 12),
//               Text(
//                 'No tasks found',
//                 style:
//                 TextStyle(color: AppColors.textSecondary, fontSize: 14),
//               ),
//             ],
//           ),
//         );
//       }
//       return ListView.separated(
//         padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
//         itemCount: tasks.length,
//         separatorBuilder: (_, __) => const SizedBox(height: 12),
//         itemBuilder: (_, i) => Obx(() => _TaskCard(
//           task: tasks[i],
//           isUpdated: _updatedIds.contains(tasks[i].id),
//           onUpdate: () => _showUpdateSheet(tasks[i]),
//         )),
//       );
//     });
//   }
//
//   // ====================== UPDATE SHEET ======================
//   void _showUpdateSheet(TaskModel task) {
//     debugPrint('🔍 UpdateSheet - ID: ${task.id}, Title: ${task.taskTitle}');
//
//     String selectedStatus = task.status;
//     String selectedPriority = task.priority.isNotEmpty ? task.priority : 'medium';
//     String? selectedCategory = task.category.isNotEmpty ? task.category : null;
//     DateTime? selectedDueDate;
//
//     if (task.dueDate.isNotEmpty) {
//       try {
//         selectedDueDate = DateFormat('dd-MMM-yyyy').parse(task.dueDate);
//       } catch (_) {
//         try {
//           selectedDueDate = DateFormat('dd MMM yyyy').parse(task.dueDate);
//         } catch (_) {}
//       }
//     }
//
//     final commentsController = TextEditingController(text: task.comments);
//     final vm = Get.find<TaskViewModel>();
//
//     Get.bottomSheet(
//       StatefulBuilder(
//         builder: (sheetCtx, setSheetState) => Container(
//           decoration: const BoxDecoration(
//             color: AppColors.surface,
//             borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
//           ),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // ── Drag handle ──
//               Container(
//                 margin: const EdgeInsets.only(top: 12, bottom: 8),
//                 width: 40,
//                 height: 4,
//                 decoration: BoxDecoration(
//                   color: AppColors.divider,
//                   borderRadius: BorderRadius.circular(2),
//                 ),
//               ),
//
//               // ── Gradient header ──
//               Container(
//                 padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
//                 decoration: const BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [AppColors.primary, AppColors.cyan],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   borderRadius: BorderRadius.only(
//                     topLeft: Radius.circular(28),
//                     topRight: Radius.circular(28),
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     Container(
//                       width: 48,
//                       height: 48,
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.2),
//                         borderRadius: BorderRadius.circular(16),
//                       ),
//                       child: const Icon(Icons.edit_note_rounded,
//                           size: 24, color: Colors.white),
//                     ),
//                     const SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           const Text(
//                             'Update Task',
//                             style: TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.w800,
//                               color: Colors.white,
//                               letterSpacing: -0.5,
//                             ),
//                           ),
//                           Text(
//                             task.taskTitle,
//                             style: TextStyle(
//                                 fontSize: 13,
//                                 color: Colors.white.withOpacity(0.85)),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               // ── Form content ──
//               Flexible(
//                 child: SingleChildScrollView(
//                   padding: EdgeInsets.only(
//                     left: 20,
//                     right: 20,
//                     top: 20,
//                     bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Task ID preview
//                       Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(colors: [
//                             AppColors.cyan.withOpacity(0.08),
//                             AppColors.primary.withOpacity(0.08),
//                           ]),
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(
//                               color: AppColors.cyan.withOpacity(0.2)),
//                         ),
//                         child: Row(
//                           children: [
//                             const Icon(Icons.task_alt_rounded,
//                                 size: 20, color: AppColors.cyan),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text('Task ID',
//                                       style: TextStyle(
//                                           fontSize: 10,
//                                           fontWeight: FontWeight.w600,
//                                           color: AppColors.textSecondary)),
//                                   Text('#${task.id}',
//                                       style: const TextStyle(
//                                           fontSize: 14,
//                                           fontWeight: FontWeight.w700,
//                                           color: AppColors.textPrimary)),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//
//                       const SizedBox(height: 24),
//
//                       // ── Status ──
//                       _buildModernSection(
//                         title: 'Status',
//                         icon: Icons.timeline_rounded,
//                         child: Row(
//                           children: ['Pending', 'In Progress', 'Completed'].map((s) {
//                             final selected = selectedStatus == s;
//                             final color = s == 'Pending'
//                                 ? AppColors.warning
//                                 : s == 'In Progress'
//                                 ? AppColors.skyBlueDk
//                                 : AppColors.greenTeal;
//                             return Expanded(
//                               child: GestureDetector(
//                                 onTap: () =>
//                                     setSheetState(() => selectedStatus = s),
//                                 child: AnimatedContainer(
//                                   duration: const Duration(milliseconds: 200),
//                                   margin: const EdgeInsets.only(right: 8),
//                                   padding: const EdgeInsets.symmetric(vertical: 12),
//                                   decoration: BoxDecoration(
//                                     gradient: selected
//                                         ? LinearGradient(
//                                       colors: [
//                                         color.withOpacity(0.9),
//                                         color,
//                                       ],
//                                       begin: Alignment.topLeft,
//                                       end: Alignment.bottomRight,
//                                     )
//                                         : null,
//                                     color: selected ? null : AppColors.cardBg,
//                                     borderRadius: BorderRadius.circular(12),
//                                     border: Border.all(
//                                       color: selected
//                                           ? color
//                                           : AppColors.divider,
//                                       width: selected ? 0 : 1,
//                                     ),
//                                   ),
//                                   child: Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Icon(
//                                         s == 'Pending'
//                                             ? Icons.hourglass_empty_rounded
//                                             : s == 'In Progress'
//                                             ? Icons.autorenew_rounded
//                                             : Icons.check_circle_rounded,
//                                         size: 16,
//                                         color: selected ? Colors.white : color,
//                                       ),
//                                       const SizedBox(width: 6),
//                                       Flexible(
//                                         child: Text(
//                                           s,
//                                           style: TextStyle(
//                                             fontSize: 11,
//                                             fontWeight: FontWeight.w600,
//                                             color: selected
//                                                 ? Colors.white
//                                                 : color,
//                                           ),
//                                           overflow: TextOverflow.ellipsis,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             );
//                           }).toList(),
//                         ),
//                       ),
//
//                       const SizedBox(height: 20),
//
//                       // ── Priority ──
//                       _buildModernSection(
//                         title: 'Priority',
//                         icon: Icons.flag_rounded,
//                         child: Row(
//                           children: ['low', 'medium', 'high'].map((p) {
//                             final selected = selectedPriority == p;
//                             final color = p == 'high'
//                                 ? AppColors.error
//                                 : p == 'medium'
//                                 ? AppColors.warning
//                                 : AppColors.greenTeal;
//                             return Expanded(
//                               child: GestureDetector(
//                                 onTap: () =>
//                                     setSheetState(() => selectedPriority = p),
//                                 child: AnimatedContainer(
//                                   duration: const Duration(milliseconds: 200),
//                                   margin: const EdgeInsets.only(right: 8),
//                                   padding: const EdgeInsets.symmetric(vertical: 12),
//                                   decoration: BoxDecoration(
//                                     color: selected
//                                         ? color.withOpacity(0.12)
//                                         : AppColors.cardBg,
//                                     borderRadius: BorderRadius.circular(12),
//                                     border: Border.all(
//                                       color: selected
//                                           ? color
//                                           : AppColors.divider,
//                                       width: selected ? 1.5 : 1,
//                                     ),
//                                   ),
//                                   child: Column(
//                                     children: [
//                                       Icon(Icons.flag_rounded,
//                                           size: 18, color: color),
//                                       const SizedBox(height: 4),
//                                       Text(
//                                         p,
//                                         style: TextStyle(
//                                           fontSize: 11,
//                                           fontWeight: FontWeight.w600,
//                                           color: color,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             );
//                           }).toList(),
//                         ),
//                       ),
//
//                       const SizedBox(height: 20),
//
//                       // ── Due date ──
//                       _buildModernSection(
//                         title: 'Due Date',
//                         icon: Icons.calendar_today_rounded,
//                         child: GestureDetector(
//                           onTap: () async {
//                             final picked = await showDatePicker(
//                               context: sheetCtx,
//                               initialDate:
//                               selectedDueDate ?? DateTime.now(),
//                               firstDate: DateTime(2020),
//                               lastDate: DateTime(2030),
//                               builder: (ctx, child) => Theme(
//                                 data: Theme.of(ctx).copyWith(
//                                   colorScheme: const ColorScheme.light(
//                                     primary: AppColors.cyan,
//                                     onPrimary: Colors.white,
//                                   ),
//                                 ),
//                                 child: child!,
//                               ),
//                             );
//                             if (picked != null) {
//                               setSheetState(
//                                       () => selectedDueDate = picked);
//                             }
//                           },
//                           child: Container(
//                             padding: const EdgeInsets.all(14),
//                             decoration: BoxDecoration(
//                               color: AppColors.cardBg,
//                               borderRadius: BorderRadius.circular(16),
//                               border: Border.all(
//                                 color: selectedDueDate != null
//                                     ? AppColors.cyan.withOpacity(0.4)
//                                     : AppColors.divider,
//                               ),
//                             ),
//                             child: Row(
//                               children: [
//                                 Container(
//                                   width: 40,
//                                   height: 40,
//                                   decoration: BoxDecoration(
//                                     color: AppColors.cyan.withOpacity(0.1),
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                   child: Icon(
//                                     Icons.calendar_month_rounded,
//                                     color: selectedDueDate != null
//                                         ? AppColors.cyan
//                                         : AppColors.textSecondary,
//                                     size: 20,
//                                   ),
//                                 ),
//                                 const SizedBox(width: 12),
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment:
//                                     CrossAxisAlignment.start,
//                                     children: [
//                                       Text(
//                                         'Due Date',
//                                         style: TextStyle(
//                                           fontSize: 11,
//                                           fontWeight: FontWeight.w500,
//                                           color: selectedDueDate != null
//                                               ? AppColors.cyan
//                                               : AppColors.textSecondary,
//                                           letterSpacing: 0.5,
//                                         ),
//                                       ),
//                                       const SizedBox(height: 4),
//                                       Text(
//                                         selectedDueDate == null
//                                             ? 'Tap to set a deadline'
//                                             : DateFormat('EEEE, dd MMM yyyy')
//                                             .format(selectedDueDate!),
//                                         style: TextStyle(
//                                           fontSize: 14,
//                                           fontWeight: FontWeight.w700,
//                                           color: selectedDueDate == null
//                                               ? AppColors.textSecondary
//                                               : AppColors.textPrimary,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 Icon(Icons.chevron_right_rounded,
//                                     color: AppColors.textSecondary, size: 24),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(height: 20),
//
//                       // ── Comments ──
//                       _buildModernSection(
//                         title: 'Comments',
//                         icon: Icons.comment_rounded,
//                         child: TextField(
//                           controller: commentsController,
//                           maxLines: 4,
//                           style: const TextStyle(
//                               fontSize: 13, color: AppColors.textPrimary),
//                           decoration: InputDecoration(
//                             hintText: 'Add your comments or notes...',
//                             hintStyle: TextStyle(
//                               color: AppColors.textSecondary.withOpacity(0.5),
//                               fontSize: 13,
//                             ),
//                             filled: true,
//                             fillColor: AppColors.cardBg,
//                             border: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(16),
//                               borderSide: BorderSide.none,
//                             ),
//                             enabledBorder: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(16),
//                               borderSide: BorderSide.none,
//                             ),
//                             focusedBorder: OutlineInputBorder(
//                               borderRadius: BorderRadius.circular(16),
//                               borderSide: const BorderSide(
//                                   color: AppColors.cyan, width: 1.5),
//                             ),
//                             contentPadding: const EdgeInsets.all(16),
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(height: 28),
//
//                       // ── Action buttons ──
//                       Row(
//                         children: [
//                           // Cancel
//                           Expanded(
//                             child: GestureDetector(
//                               onTap: () => Get.back(),
//                               child: Container(
//                                 height: 52,
//                                 decoration: BoxDecoration(
//                                   color: AppColors.cardBg,
//                                   borderRadius: BorderRadius.circular(16),
//                                   border:
//                                   Border.all(color: AppColors.divider),
//                                 ),
//                                 child: const Center(
//                                   child: Text(
//                                     'Cancel',
//                                     style: TextStyle(
//                                       fontSize: 15,
//                                       fontWeight: FontWeight.w600,
//                                       color: AppColors.textSecondary,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           // Save
//                           Expanded(
//                             child: Obx(() => GestureDetector(
//                               onTap: vm.isUpdating.value
//                                   ? null
//                                   : () async {
//                                 String? dueDateStr;
//                                 if (selectedDueDate != null) {
//                                   dueDateStr = DateFormat('dd-MMM-yyyy')
//                                       .format(selectedDueDate!)
//                                       .toUpperCase();
//                                 }
//
//                                 // ✅ FIX: Normalize status before sending
//                                 final normalizedStatus = _normalizeStatus(selectedStatus);
//
//                                 debugPrint('🔄 [Update] Original status: $selectedStatus');
//                                 debugPrint('🔄 [Update] Normalized status: $normalizedStatus');
//
//                                 final ok = await vm.updateTask(
//                                   taskId: task.id,
//                                   status: normalizedStatus,
//                                   comments:
//                                   commentsController.text.trim(),
//                                   priority: selectedPriority,
//                                   dueDate: dueDateStr,
//                                   category: selectedCategory,
//                                   isAssigned: true,
//                                 );
//
//                                 if (ok) {
//                                   // Add to updated IDs set
//                                   _updatedIds.add(task.id);
//
//                                   // Refresh the tasks list
//                                   await vm.fetchAssignedTasks();
//
//                                   Get.back();
//                                   Get.showSnackbar(const GetSnackBar(
//                                     message: 'Task updated successfully!',
//                                     duration: Duration(seconds: 2),
//                                     backgroundColor: AppColors.greenTeal,
//                                     icon: Icon(
//                                       Icons.check_circle_outline_rounded,
//                                       color: Colors.white,
//                                     ),
//                                     borderRadius: 10,
//                                     margin: EdgeInsets.all(12),
//                                   ));
//                                 } else {
//                                   Get.showSnackbar(GetSnackBar(
//                                     message: vm.errorMessage.value
//                                         .isNotEmpty
//                                         ? vm.errorMessage.value
//                                         : 'Update failed. Try again.',
//                                     duration: const Duration(seconds: 3),
//                                     backgroundColor: AppColors.error,
//                                     icon: const Icon(
//                                       Icons.error_outline_rounded,
//                                       color: Colors.white,
//                                     ),
//                                     borderRadius: 10,
//                                     margin: const EdgeInsets.all(12),
//                                   ));
//                                 }
//                               },
//                               child: Container(
//                                 height: 52,
//                                 decoration: BoxDecoration(
//                                   gradient: vm.isUpdating.value
//                                       ? null
//                                       : const LinearGradient(
//                                     colors: [
//                                       AppColors.primary,
//                                       AppColors.cyan,
//                                       AppColors.greenTeal,
//                                     ],
//                                     begin: Alignment.topLeft,
//                                     end: Alignment.bottomRight,
//                                   ),
//                                   color: vm.isUpdating.value
//                                       ? AppColors.divider
//                                       : null,
//                                   borderRadius: BorderRadius.circular(16),
//                                   boxShadow: vm.isUpdating.value
//                                       ? []
//                                       : [
//                                     BoxShadow(
//                                       color: AppColors.cyan
//                                           .withOpacity(0.3),
//                                       blurRadius: 12,
//                                       offset: const Offset(0, 4),
//                                     ),
//                                   ],
//                                 ),
//                                 child: Center(
//                                   child: vm.isUpdating.value
//                                       ? const SizedBox(
//                                     width: 22,
//                                     height: 22,
//                                     child: CircularProgressIndicator(
//                                       color: Colors.white,
//                                       strokeWidth: 2.5,
//                                     ),
//                                   )
//                                       : const Row(
//                                     mainAxisAlignment:
//                                     MainAxisAlignment.center,
//                                     children: [
//                                       Icon(Icons.save_rounded,
//                                           color: Colors.white, size: 18),
//                                       SizedBox(width: 8),
//                                       Text(
//                                         'Save Changes',
//                                         style: TextStyle(
//                                           color: Colors.white,
//                                           fontSize: 15,
//                                           fontWeight: FontWeight.w700,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             )),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       enableDrag: true,
//     );
//   }
//
//   // ── Section header helper ───────────────────────────────────────────────────
//   Widget _buildModernSection({
//     required String title,
//     required IconData icon,
//     required Widget child,
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Container(
//               width: 28,
//               height: 28,
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     AppColors.cyan.withOpacity(0.1),
//                     AppColors.primary.withOpacity(0.1),
//                   ],
//                 ),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Icon(icon, size: 16, color: AppColors.cyan),
//             ),
//             const SizedBox(width: 10),
//             Text(
//               title,
//               style: const TextStyle(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w700,
//                 color: AppColors.textPrimary,
//                 letterSpacing: -0.3,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 12),
//         child,
//       ],
//     );
//   }
//
//   // ====================== SECTION HEADER ======================
//   Widget _sectionHeader(String title, IconData icon, Color color) {
//     return Row(
//       children: [
//         Container(
//           width: 5,
//           height: 24,
//           decoration: BoxDecoration(
//             gradient: AppColors.brandGradient,
//             borderRadius: BorderRadius.circular(3),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Container(
//           width: 32,
//           height: 32,
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.1),
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: Icon(icon, size: 17, color: color),
//         ),
//         const SizedBox(width: 12),
//         Text(
//           title,
//           style: const TextStyle(
//             fontSize: 15.5,
//             fontWeight: FontWeight.w700,
//             color: AppColors.textPrimary,
//             letterSpacing: 0.2,
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // ══════════════════════════════════════════════════════════════════════════
// // _TaskCard — Updated with isUpdated flag
// // ══════════════════════════════════════════════════════════════════════════
// class _TaskCard extends StatelessWidget {
//   final TaskModel task;
//   final VoidCallback onUpdate;
//   final bool isUpdated;
//
//   const _TaskCard({
//     required this.task,
//     required this.onUpdate,
//     this.isUpdated = false,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final bool isCompleted = task.status == 'Completed';
//
//     Color statusColor;
//     IconData statusIcon;
//
//     if (task.status == 'Completed') {
//       statusColor = AppColors.greenTeal;
//       statusIcon = Icons.check_circle_rounded;
//     } else if (task.status == 'In Progress') {
//       statusColor = AppColors.skyBlueDk;
//       statusIcon = Icons.autorenew_rounded;
//     } else {
//       statusColor = AppColors.warning;
//       statusIcon = Icons.hourglass_empty_rounded;
//     }
//
//     Color priorityColor = AppColors.textSecondary;
//     if (task.priority == 'High') priorityColor = AppColors.error;
//     if (task.priority == 'Medium') priorityColor = AppColors.warning;
//     if (task.priority == 'Low') priorityColor = AppColors.greenTeal;
//
//     return Container(
//       decoration: BoxDecoration(
//         color: AppColors.cardBg,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: statusColor.withOpacity(0.20)),
//         boxShadow: [
//           BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 12,
//               offset: const Offset(0, 4)),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Status bar
//           Container(
//             padding:
//             const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
//             decoration: BoxDecoration(
//               color: statusColor.withOpacity(0.06),
//               borderRadius:
//               const BorderRadius.vertical(top: Radius.circular(16)),
//             ),
//             child: Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 9, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: statusColor.withOpacity(0.14),
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(statusIcon, size: 11, color: statusColor),
//                       const SizedBox(width: 4),
//                       Text(task.status,
//                           style: TextStyle(
//                               fontSize: 10,
//                               fontWeight: FontWeight.w700,
//                               color: statusColor)),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 9, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: priorityColor.withOpacity(0.10),
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(Icons.flag_rounded,
//                           size: 11, color: priorityColor),
//                       const SizedBox(width: 4),
//                       Text(task.priority,
//                           style: TextStyle(
//                               fontSize: 10,
//                               fontWeight: FontWeight.w700,
//                               color: priorityColor)),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Card body
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   task.taskTitle,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                       fontSize: 14, fontWeight: FontWeight.w700),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   'Assigned by: ${task.assignedBy}',
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style:
//                   TextStyle(color: AppColors.textSecondary, fontSize: 11),
//                 ),
//                 const SizedBox(height: 10),
//                 Wrap(
//                   spacing: 8,
//                   runSpacing: 6,
//                   children: [
//                     _MetaChip(
//                         icon: Icons.person,
//                         label: task.empName,
//                         color: AppColors.skyBlueDk),
//                     _MetaChip(
//                         icon: Icons.calendar_today,
//                         label: task.dueDate,
//                         color: AppColors.greenTeal),
//                     _MetaChip(
//                         icon: Icons.category_rounded,
//                         label: task.taskType,
//                         color: AppColors.primary),
//                   ],
//                 ),
//                 const SizedBox(height: 14),
//                 Row(
//                   children: [
//                     Icon(Icons.person_outline_rounded,
//                         size: 13, color: AppColors.textSecondary),
//                     const SizedBox(width: 4),
//                     Expanded(
//                       child: Text(
//                         task.empName,
//                         style: const TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w600,
//                             color: AppColors.textPrimary),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     // ── Update button — hidden when Completed ──
//                     if (!isCompleted)
//                       GestureDetector(
//                         onTap: onUpdate,
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 14, vertical: 8),
//                           decoration: BoxDecoration(
//                             gradient: isUpdated
//                                 ? null
//                                 : const LinearGradient(
//                               colors: [AppColors.primary, AppColors.cyan],
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                             ),
//                             color: isUpdated ? AppColors.greenTeal : null,
//                             borderRadius: BorderRadius.circular(8),
//                             boxShadow: isUpdated
//                                 ? []
//                                 : [
//                               BoxShadow(
//                                   color: AppColors.cyan.withOpacity(0.30),
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 3)),
//                             ],
//                           ),
//                           child: Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(
//                                   isUpdated ? Icons.check_circle_rounded : Icons.edit_rounded,
//                                   size: 13,
//                                   color: Colors.white
//                               ),
//                               const SizedBox(width: 5),
//                               Text(
//                                 isUpdated ? 'Updated' : 'Update',
//                                 style: const TextStyle(
//                                   fontSize: 12,
//                                   fontWeight: FontWeight.w700,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class _MetaChip extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final Color color;
//
//   const _MetaChip(
//       {required this.icon, required this.label, required this.color});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(icon, size: 12, color: color),
//           const SizedBox(width: 4),
//           Text(label,
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(color: color, fontSize: 10)),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../AppColors.dart';
import '../ViewModels/task_view_model.dart';
import '../Models/task_model.dart';
import 'HomeScreenComponents/app_bottom_navbar.dart';
import 'HomeScreenComponents/navbar.dart';
import 'create_task_screen.dart';

/// Active tab enum
enum _TaskTab { assigned, myTasks }

class TaskScreen extends StatefulWidget {
  final int currentIndex;
  final int chatBadgeCount;
  final ValueChanged<int> onNavTap;

  const TaskScreen({
    super.key,
    this.currentIndex = 3,
    this.chatBadgeCount = 0,
    required this.onNavTap,
  });

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  _TaskTab _activeTab = _TaskTab.assigned;

  // ── Track updated tasks ──────────────────────────────────────────────────────
  final RxSet<int> _updatedIds = <int>{}.obs;

  // ── User data ──────────────────────────────────────────────────────────────
  String _empName = 'Employee';
  String _empInitials = '??';

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _loadUserData();

    if (!Get.isRegistered<TaskViewModel>()) {
      Get.put(TaskViewModel());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = Get.find<TaskViewModel>();
      vm.fetchAssignedTasks();
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('userName') ?? 'Employee';
    setState(() {
      _empName = name;
      _empInitials = _getInitials(name);
    });
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ── Helper to convert UI status to backend status ─────────────────────────
  String _getBackendStatus(String uiStatus) {
    if (uiStatus == 'Completed') {
      return 'Done';
    }
    return uiStatus; // Open, In Progress, Cancel remain same
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.surface,
      appBar: Navbar(
        userName: _empName,
        userInitials: _empInitials,
        lastSync: 'Just now',
        scaffoldKey: _scaffoldKey,
      ),
      body: Column(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(
                      'Tasks', Icons.task_alt_rounded, AppColors.cyan),
                  const SizedBox(height: 6),
                  Text(
                    'Manage your work easily',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTabRow(),
                  const SizedBox(height: 14),
                  if (_activeTab == _TaskTab.assigned) _buildFilterChips(),
                  if (_activeTab == _TaskTab.assigned)
                    const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          Expanded(child: _buildTaskList()),
          AppBottomNavBar(
            currentIndex: widget.currentIndex,
            chatBadgeCount: widget.chatBadgeCount,
            onTap: widget.onNavTap,
          ),
        ],
      ),
    );
  }

  // ====================== TAB ROW ======================
  Widget _buildTabRow() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: GestureDetector(
              onTap: () {
                setState(() => _activeTab = _TaskTab.assigned);
                Get.find<TaskViewModel>().fetchAssignedTasks();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: _activeTab == _TaskTab.assigned
                      ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.cyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: _activeTab == _TaskTab.assigned
                      ? null
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _activeTab == _TaskTab.assigned
                      ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.assignment_ind_rounded,
                      color: _activeTab == _TaskTab.assigned
                          ? Colors.white
                          : AppColors.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Assigned Tasks',
                      style: TextStyle(
                        color: _activeTab == _TaskTab.assigned
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: () {
                setState(() => _activeTab = _TaskTab.myTasks);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: _activeTab == _TaskTab.myTasks
                      ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.cyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: _activeTab == _TaskTab.myTasks
                      ? null
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _activeTab == _TaskTab.myTasks
                      ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      color: _activeTab == _TaskTab.myTasks
                          ? Colors.white
                          : AppColors.textSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'My Tasks',
                      style: TextStyle(
                        color: _activeTab == _TaskTab.myTasks
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () => Get.to(
                    () => const CreateTaskScreen(),
                transition: Transition.rightToLeft,
                duration: const Duration(milliseconds: 280),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded,
                        color: AppColors.textSecondary, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      'Create',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================== FILTER CHIPS ======================
  Widget _buildFilterChips() {
    final vm = Get.find<TaskViewModel>();
    return Obx(() {
      final current = vm.assignedFilter.value;
      // ✅ Updated filter options
      final filterOptions = ['All', 'Open', 'In Progress', 'Completed', 'Cancel'];
      return SizedBox(
        height: 35,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: filterOptions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final opt = filterOptions[i];
            final selected = current == opt;
            return GestureDetector(
              onTap: () => vm.assignedFilter.value = opt,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.cyan : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.cyan : AppColors.divider,
                  ),
                ),
                child: Text(
                  opt,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  // ====================== TASK LIST ======================
  Widget _buildTaskList() {
    final vm = Get.find<TaskViewModel>();

    if (_activeTab == _TaskTab.assigned) {
      return Obx(() {
        if (vm.isLoadingAssigned.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.cyan));
        }
        final tasks = vm.filteredAssigned;
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_outlined,
                    size: 56, color: AppColors.textSecondary.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text(
                  'No assigned tasks',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => Obx(() => _TaskCard(
            task: tasks[i],
            isUpdated: _updatedIds.contains(tasks[i].id),
            onUpdate: () => _showUpdateSheet(tasks[i]),
          )),
        );
      });
    }

    // ── My Tasks tab ──
    return Obx(() {
      if (vm.isLoadingAssigned.value) {
        return const Center(
            child: CircularProgressIndicator(color: AppColors.cyan));
      }
      final tasks = vm.filteredAssigned;
      if (tasks.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline_rounded,
                  size: 56, color: AppColors.textSecondary.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text(
                'No tasks found',
                style:
                TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => Obx(() => _TaskCard(
          task: tasks[i],
          isUpdated: _updatedIds.contains(tasks[i].id),
          onUpdate: () => _showUpdateSheet(tasks[i]),
        )),
      );
    });
  }

  // ====================== UPDATE SHEET ======================
  void _showUpdateSheet(TaskModel task) {
    debugPrint('🔍 UpdateSheet - ID: ${task.id}, Title: ${task.taskTitle}');

    // Check if task is already completed or cancelled
    final isCompletedOrCancelled = task.status == 'Done' || task.status == 'Cancel';

    if (isCompletedOrCancelled) {
      Get.showSnackbar(const GetSnackBar(
        message: 'This task is already completed or cancelled and cannot be updated.',
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.warning,
        borderRadius: 10,
        margin: EdgeInsets.all(12),
        icon: Icon(Icons.warning_amber_rounded, color: Colors.white),
      ));
      return;
    }

    // ✅ Map backend status to UI display
    String displayStatus = task.status;
    if (displayStatus == 'Done') {
      displayStatus = 'Completed';
    }

    String selectedStatus = displayStatus;
    String selectedPriority = task.priority.isNotEmpty ? task.priority : 'medium';
    String? selectedCategory = task.category.isNotEmpty ? task.category : null;
    DateTime? selectedDueDate;

    if (task.dueDate.isNotEmpty) {
      try {
        selectedDueDate = DateFormat('dd-MMM-yyyy').parse(task.dueDate);
      } catch (_) {
        try {
          selectedDueDate = DateFormat('dd MMM yyyy').parse(task.dueDate);
        } catch (_) {}
      }
    }

    final commentsController = TextEditingController(text: task.comments);
    final vm = Get.find<TaskViewModel>();

    // ✅ Status options: Open, In Progress, Completed, Cancel
    final statusOptions = ['Open', 'In Progress', 'Completed', 'Cancel'];

    Get.bottomSheet(
      StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.cyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.edit_note_rounded,
                          size: 24, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Update Task',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            task.taskTitle,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.85)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            AppColors.cyan.withOpacity(0.08),
                            AppColors.primary.withOpacity(0.08),
                          ]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.cyan.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.task_alt_rounded,
                                size: 20, color: AppColors.cyan),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Task ID',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary)),
                                  Text('#${task.id}',
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Status ──
                      _buildModernSection(
                        title: 'Status',
                        icon: Icons.timeline_rounded,
                        child: Row(
                          children: statusOptions.map((s) {
                            final selected = selectedStatus == s;
                            final color = s == 'Open'
                                ? AppColors.warning
                                : s == 'In Progress'
                                ? AppColors.skyBlueDk
                                : s == 'Completed'
                                ? AppColors.greenTeal
                                : AppColors.error;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setSheetState(() => selectedStatus = s),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: selected
                                        ? LinearGradient(
                                      colors: [
                                        color.withOpacity(0.9),
                                        color,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                        : null,
                                    color: selected ? null : AppColors.cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? color
                                          : AppColors.divider,
                                      width: selected ? 0 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        s == 'Open'
                                            ? Icons.hourglass_empty_rounded
                                            : s == 'In Progress'
                                            ? Icons.autorenew_rounded
                                            : s == 'Completed'
                                            ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                        size: 16,
                                        color: selected ? Colors.white : color,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          s,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? Colors.white
                                                : color,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Priority ──
                      _buildModernSection(
                        title: 'Priority',
                        icon: Icons.flag_rounded,
                        child: Row(
                          children: ['low', 'medium', 'high'].map((p) {
                            final selected = selectedPriority == p;
                            final color = p == 'high'
                                ? AppColors.error
                                : p == 'medium'
                                ? AppColors.warning
                                : AppColors.greenTeal;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setSheetState(() => selectedPriority = p),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? color.withOpacity(0.12)
                                        : AppColors.cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? color
                                          : AppColors.divider,
                                      width: selected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.flag_rounded,
                                          size: 18, color: color),
                                      const SizedBox(height: 4),
                                      Text(
                                        p,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Due date ──
                      _buildModernSection(
                        title: 'Due Date',
                        icon: Icons.calendar_today_rounded,
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: sheetCtx,
                              initialDate:
                              selectedDueDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              builder: (ctx, child) => Theme(
                                data: Theme.of(ctx).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.cyan,
                                    onPrimary: Colors.white,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (picked != null) {
                              setSheetState(
                                      () => selectedDueDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selectedDueDate != null
                                    ? AppColors.cyan.withOpacity(0.4)
                                    : AppColors.divider,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.cyan.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.calendar_month_rounded,
                                    color: selectedDueDate != null
                                        ? AppColors.cyan
                                        : AppColors.textSecondary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Due Date',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: selectedDueDate != null
                                              ? AppColors.cyan
                                              : AppColors.textSecondary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        selectedDueDate == null
                                            ? 'Tap to set a deadline'
                                            : DateFormat('EEEE, dd MMM yyyy')
                                            .format(selectedDueDate!),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: selectedDueDate == null
                                              ? AppColors.textSecondary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color: AppColors.textSecondary, size: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Comments ──
                      _buildModernSection(
                        title: 'Comments',
                        icon: Icons.comment_rounded,
                        child: TextField(
                          controller: commentsController,
                          maxLines: 4,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Add your comments or notes...',
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.5),
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: AppColors.cardBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: AppColors.cyan, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Action buttons ──
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Get.back(),
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border:
                                  Border.all(color: AppColors.divider),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Obx(() => GestureDetector(
                              onTap: vm.isUpdating.value
                                  ? null
                                  : () async {
                                String? dueDateStr;
                                if (selectedDueDate != null) {
                                  dueDateStr = DateFormat('dd-MMM-yyyy')
                                      .format(selectedDueDate!)
                                      .toUpperCase();
                                }

                                // ✅ Convert UI status to backend status
                                final backendStatus = _getBackendStatus(selectedStatus);
                                debugPrint('🔄 [Update] UI Status: $selectedStatus → Backend: $backendStatus');

                                final ok = await vm.updateTask(
                                  taskId: task.id,
                                  status: backendStatus,
                                  comments:
                                  commentsController.text.trim(),
                                  priority: selectedPriority,
                                  dueDate: dueDateStr,
                                  category: selectedCategory,
                                  isAssigned: true,
                                );

                                if (ok) {
                                  _updatedIds.add(task.id);
                                  await vm.fetchAssignedTasks();
                                  Get.back();
                                  Get.showSnackbar(const GetSnackBar(
                                    message: 'Task updated successfully!',
                                    duration: Duration(seconds: 2),
                                    backgroundColor: AppColors.greenTeal,
                                    icon: Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: Colors.white,
                                    ),
                                    borderRadius: 10,
                                    margin: EdgeInsets.all(12),
                                  ));
                                } else {
                                  Get.showSnackbar(GetSnackBar(
                                    message: vm.errorMessage.value
                                        .isNotEmpty
                                        ? vm.errorMessage.value
                                        : 'Update failed. Try again.',
                                    duration: const Duration(seconds: 3),
                                    backgroundColor: AppColors.error,
                                    icon: const Icon(
                                      Icons.error_outline_rounded,
                                      color: Colors.white,
                                    ),
                                    borderRadius: 10,
                                    margin: const EdgeInsets.all(12),
                                  ));
                                }
                              },
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: vm.isUpdating.value
                                      ? null
                                      : const LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.cyan,
                                      AppColors.greenTeal,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  color: vm.isUpdating.value
                                      ? AppColors.divider
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: vm.isUpdating.value
                                      ? []
                                      : [
                                    BoxShadow(
                                      color: AppColors.cyan
                                          .withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: vm.isUpdating.value
                                      ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                      : const Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.save_rounded,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Save Changes',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
    );
  }

  // ── Section header helper ───────────────────────────────────────────────────
  Widget _buildModernSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.cyan.withOpacity(0.1),
                    AppColors.primary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppColors.cyan),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
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
}

// ══════════════════════════════════════════════════════════════════════════
// _TaskCard
// ══════════════════════════════════════════════════════════════════════════
class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onUpdate;
  final bool isUpdated;

  const _TaskCard({
    required this.task,
    required this.onUpdate,
    this.isUpdated = false,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Check for Done (backend) or Completed (UI)
    final bool isCompleted = task.status == 'Done' || task.status == 'Completed';
    final bool isCancelled = task.status == 'Cancel';

    Color statusColor;
    IconData statusIcon;

    if (isCompleted) {
      statusColor = AppColors.greenTeal;
      statusIcon = Icons.check_circle_rounded;
    } else if (isCancelled) {
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_rounded;
    } else if (task.status == 'In Progress') {
      statusColor = AppColors.skyBlueDk;
      statusIcon = Icons.autorenew_rounded;
    } else {
      statusColor = AppColors.warning;
      statusIcon = Icons.hourglass_empty_rounded;
    }

    Color priorityColor = AppColors.textSecondary;
    if (task.priority == 'High') priorityColor = AppColors.error;
    if (task.priority == 'Medium') priorityColor = AppColors.warning;
    if (task.priority == 'Low') priorityColor = AppColors.greenTeal;

    // Display status for UI
    String displayStatus = task.status;
    if (displayStatus == 'Done') {
      displayStatus = 'Completed';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),
                      const SizedBox(width: 4),
                      Text(displayStatus,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_rounded,
                          size: 11, color: priorityColor),
                      const SizedBox(width: 4),
                      Text(task.priority,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: priorityColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.taskTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Assigned by: ${task.assignedBy}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MetaChip(
                        icon: Icons.person,
                        label: task.empName,
                        color: AppColors.skyBlueDk),
                    _MetaChip(
                        icon: Icons.calendar_today,
                        label: task.dueDate,
                        color: AppColors.greenTeal),
                    _MetaChip(
                        icon: Icons.category_rounded,
                        label: task.taskType,
                        color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.empName,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // ── Update button — hidden when Completed or Cancelled ──
                    if (!isCompleted && !isCancelled)
                      GestureDetector(
                        onTap: onUpdate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isUpdated
                                ? null
                                : const LinearGradient(
                              colors: [AppColors.primary, AppColors.cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            color: isUpdated ? AppColors.greenTeal : null,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isUpdated
                                ? []
                                : [
                              BoxShadow(
                                  color: AppColors.cyan.withOpacity(0.30),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  isUpdated ? Icons.check_circle_rounded : Icons.edit_rounded,
                                  size: 13,
                                  color: Colors.white
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isUpdated ? 'Updated' : 'Update',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}