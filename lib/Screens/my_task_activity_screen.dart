//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
//
// import '../AppColors.dart';
// import '../Models/task_model.dart';
// import '../ViewModels/task_view_model.dart';
//
// class MyTasksActivityScreen extends StatefulWidget {
//   const MyTasksActivityScreen({super.key});
//
//   @override
//   State<MyTasksActivityScreen> createState() => _MyTasksActivityScreenState();
// }
//
// class _MyTasksActivityScreenState extends State<MyTasksActivityScreen>
//     with SingleTickerProviderStateMixin {
//   late TaskViewModel   _vm;
//   late AnimationController _fadeCtrl;
//   late Animation<double>   _fadeAnim;
//
//   final RxString _filter = 'All'.obs;
//
//   @override
//   void initState() {
//     super.initState();
//
//     _fadeCtrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 400));
//     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
//     _fadeCtrl.forward();
//
//     _vm = Get.put(TaskViewModel());
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _vm.fetchAssignedTasks();
//     });
//   }
//
//   @override
//   void dispose() {
//     _fadeCtrl.dispose();
//     super.dispose();
//   }
//
//   // Updated: Now shows all tasks including completed based on filter
//   List<TaskModel> get _filteredTasks {
//     if (_filter.value == 'All') {
//       return _vm.assignedTasks;
//     } else {
//       return _vm.assignedTasks.where((t) => t.status == _filter.value).toList();
//     }
//   }
//
//   // ──────────────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//       statusBarColor:          Colors.transparent,
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
//               child: Obx(() {
//                 if (_vm.isLoadingAssigned.value) {
//                   return const Center(
//                     child: CircularProgressIndicator(color: AppColors.cyan),
//                   );
//                 }
//
//                 return RefreshIndicator(
//                   color:    AppColors.cyan,
//                   onRefresh: () => _vm.fetchAssignedTasks(),
//                   child: CustomScrollView(
//                     physics: const BouncingScrollPhysics(),
//                     slivers: [
//                       SliverToBoxAdapter(
//                         child: Padding(
//                           padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               _buildStatsRow(),
//                               const SizedBox(height: 20),
//                               _buildFilterRow(),
//                               const SizedBox(height: 18),
//                               _sectionHeader(
//                                   'Tasks',
//                                   Icons.task_alt_rounded,
//                                   AppColors.cyan),
//                               const SizedBox(height: 14),
//                             ],
//                           ),
//                         ),
//                       ),
//                       Obx(() {
//                         final tasks = _filteredTasks;
//                         if (tasks.isEmpty) {
//                           return SliverFillRemaining(
//                             child: _buildEmptyState(),
//                           );
//                         }
//                         return SliverPadding(
//                           padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
//                           sliver: SliverList(
//                             delegate: SliverChildBuilderDelegate(
//                                   (_, i) => _buildTaskCard(tasks[i]),
//                               childCount: tasks.length,
//                             ),
//                           ),
//                         );
//                       }),
//                     ],
//                   ),
//                 );
//               }),
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
//           Positioned(
//               top: -50, right: -30,
//               child: _decorCircle(180, AppColors.greenTeal, 0.12)),
//           Positioned(
//               bottom: -40, left: -20,
//               child: _decorCircle(130, Colors.white, 0.10)),
//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
//               child: Row(
//                 children: [
//                   GestureDetector(
//                     onTap: () => Get.back(),
//                     child: Container(
//                       width: 42, height: 42,
//                       decoration: BoxDecoration(
//                         color:        Colors.white.withOpacity(0.12),
//                         borderRadius: BorderRadius.circular(10),
//                         border:       Border.all(
//                             color: Colors.white.withOpacity(0.18)),
//                       ),
//                       child: const Icon(Icons.arrow_back_ios_new_rounded,
//                           color: Colors.white, size: 18),
//                     ),
//                   ),
//                   const SizedBox(width: 14),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'My Task Activity',
//                           style: TextStyle(
//                             color:         Colors.white,
//                             fontSize:      18,
//                             fontWeight:    FontWeight.w800,
//                             letterSpacing: 0.2,
//                           ),
//                         ),
//                         Text(
//                           'All assigned tasks',
//                           style: TextStyle(
//                             color:    Colors.white.withOpacity(0.65),
//                             fontSize: 11,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   GestureDetector(
//                     onTap: () => _vm.fetchAssignedTasks(),
//                     child: Container(
//                       width: 42, height: 42,
//                       decoration: BoxDecoration(
//                         color:        Colors.white.withOpacity(0.12),
//                         borderRadius: BorderRadius.circular(10),
//                         border:       Border.all(
//                             color: Colors.white.withOpacity(0.18)),
//                       ),
//                       child: const Icon(Icons.refresh_rounded,
//                           color: Colors.white, size: 22),
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
//
//   // ── Stats row - Made scrollable horizontally ─────────────────────────────────
//   Widget _buildStatsRow() {
//     return Obx(() {
//       final all        = _vm.assignedTasks.length;
//       final pending    = _vm.assignedTasks
//           .where((t) => t.status == 'Pending').length;
//       final inProgress = _vm.assignedTasks
//           .where((t) => t.status == 'In Progress').length;
//       final completed  = _vm.assignedTasks
//           .where((t) => t.status == 'Completed').length;
//
//       return SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         physics: const BouncingScrollPhysics(),
//         child: Row(
//           children: [
//             _statTile('Total', all.toString(),
//                 AppColors.cyan, Icons.list_alt_rounded),
//             const SizedBox(width: 10),
//             _statTile('Pending', pending.toString(),
//                 AppColors.warning, Icons.hourglass_empty_rounded),
//             const SizedBox(width: 10),
//             _statTile('Progress', inProgress.toString(),
//                 AppColors.skyBlueDk, Icons.autorenew_rounded),
//             const SizedBox(width: 10),
//             _statTile('Completed', completed.toString(),
//                 AppColors.greenTeal, Icons.check_circle_rounded),
//           ],
//         ),
//       );
//     });
//   }
//
//   Widget _statTile(String label, String count, Color color, IconData icon) {
//     return Container(
//       width: 85,
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
//       decoration: BoxDecoration(
//         color: AppColors.cardBg,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: color.withOpacity(0.20)),
//         boxShadow: [
//           BoxShadow(
//               color: color.withOpacity(0.08),
//               blurRadius: 10,
//               offset: const Offset(0, 3))
//         ],
//       ),
//       child: Column(
//         children: [
//           Container(
//             width: 34,
//             height: 34,
//             decoration: BoxDecoration(
//                 color: color.withOpacity(0.12),
//                 borderRadius: BorderRadius.circular(10)),
//             child: Icon(icon, size: 18, color: color),
//           ),
//           const SizedBox(height: 6),
//           Text(count,
//               style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w800,
//                   color: color)),
//           const SizedBox(height: 2),
//           Text(label,
//               style: TextStyle(
//                   fontSize: 9,
//                   fontWeight: FontWeight.w500,
//                   color: AppColors.textSecondary)),
//         ],
//       ),
//     );
//   }
//
//   // ── Filter chips - Made scrollable horizontally ───────────────────────────
//   Widget _buildFilterRow() {
//     return Obx(() => SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       physics: const BouncingScrollPhysics(),
//       child: Row(
//         children: ['All', 'Pending', 'In Progress', 'Completed'].map((f) {
//           final isActive = _filter.value == f;
//           Color c = f == 'Pending'
//               ? AppColors.warning
//               : f == 'In Progress'
//               ? AppColors.skyBlueDk
//               : f == 'Completed'
//               ? AppColors.greenTeal
//               : AppColors.cyan;
//           return Padding(
//             padding: const EdgeInsets.only(right: 8),
//             child: GestureDetector(
//               onTap: () => _filter.value = f,
//               child: AnimatedContainer(
//                 duration: const Duration(milliseconds: 200),
//                 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: isActive ? c.withOpacity(0.12) : AppColors.cardBg,
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(
//                       color: isActive ? c : AppColors.divider,
//                       width: isActive ? 1.5 : 1),
//                 ),
//                 child: Text(
//                   f,
//                   style: TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w700,
//                       color: isActive ? c : AppColors.textSecondary),
//                 ),
//               ),
//             ),
//           );
//         }).toList(),
//       ),
//     ));
//   }
//
//   // ── Task card - Updated to handle completed tasks ──────────────────────────
//   Widget _buildTaskCard(TaskModel task) {
//     final isInProgress = task.status == 'In Progress';
//     final isCompleted = task.status == 'Completed';
//     final isPending = task.status == 'Pending';
//
//     Color statusColor;
//     IconData statusIcon;
//
//     if (isCompleted) {
//       statusColor = AppColors.greenTeal;
//       statusIcon = Icons.check_circle_rounded;
//     } else if (isInProgress) {
//       statusColor = AppColors.skyBlueDk;
//       statusIcon = Icons.autorenew_rounded;
//     } else {
//       statusColor = AppColors.warning;
//       statusIcon = Icons.hourglass_empty_rounded;
//     }
//
//     Color priorityColor = AppColors.textSecondary;
//     if (task.priority == 'High')   priorityColor = AppColors.error;
//     if (task.priority == 'Medium') priorityColor = AppColors.warning;
//     if (task.priority == 'Low')    priorityColor = AppColors.greenTeal;
//
//     return Container(
//       margin: const EdgeInsets.only(bottom: 14),
//       decoration: BoxDecoration(
//         color: AppColors.cardBg,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: statusColor.withOpacity(0.20)),
//         boxShadow: [
//           BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 12,
//               offset: const Offset(0, 4))
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // ── Status bar ──
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
//             decoration: BoxDecoration(
//               color: statusColor.withOpacity(0.06),
//               borderRadius: const BorderRadius.vertical(
//                   top: Radius.circular(16)),
//             ),
//             child: Row(
//               children: [
//                 // Status badge
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
//                 // Priority badge
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: priorityColor.withOpacity(0.10),
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Text(task.priority ?? 'N/A',
//                       style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.w600,
//                           color: priorityColor)),
//                 ),
//                 // Category badge (show if not empty)
//                 if (task.category.isNotEmpty) ...[
//                   const SizedBox(width: 8),
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
//                     decoration: BoxDecoration(
//                       color: AppColors.cyan.withOpacity(0.10),
//                       borderRadius: BorderRadius.circular(6),
//                     ),
//                     child: Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         const Icon(Icons.label_outline_rounded,
//                             size: 10, color: AppColors.cyan),
//                         const SizedBox(width: 3),
//                         Text(task.category,
//                             style: const TextStyle(
//                                 fontSize: 10,
//                                 fontWeight: FontWeight.w600,
//                                 color: AppColors.cyan)),
//                       ],
//                     ),
//                   ),
//                 ],
//                 const Spacer(),
//                 // Due date
//                 if (task.dueDate.isNotEmpty)
//                   Row(
//                     children: [
//                       Icon(Icons.calendar_today_rounded,
//                           size: 11, color: AppColors.textSecondary),
//                       const SizedBox(width: 4),
//                       Text(task.dueDate,
//                           style: TextStyle(
//                               fontSize: 10,
//                               color: AppColors.textSecondary,
//                               fontWeight: FontWeight.w500)),
//                     ],
//                   ),
//               ],
//             ),
//           ),
//
//           // ── Body ──
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // ── Title + ID row ──────────────────────────────────────
//                 Row(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Expanded(
//                       child: Text(
//                         task.taskTitle,
//                         style: const TextStyle(
//                           fontSize: 15,
//                           fontWeight: FontWeight.w700,
//                           color: AppColors.textPrimary,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     // Task ID badge
//                     Container(
//                       padding: const EdgeInsets.symmetric(
//                           horizontal: 8, vertical: 3),
//                       decoration: BoxDecoration(
//                         color: AppColors.primary.withOpacity(0.08),
//                         borderRadius: BorderRadius.circular(6),
//                         border: Border.all(
//                             color: AppColors.primary.withOpacity(0.20)),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(Icons.tag_rounded,
//                               size: 10,
//                               color: AppColors.primary.withOpacity(0.70)),
//                           const SizedBox(width: 3),
//                           Text(
//                             '${task.id}',
//                             style: TextStyle(
//                               fontSize: 10,
//                               fontWeight: FontWeight.w700,
//                               color: AppColors.primary.withOpacity(0.70),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//                 if (task.taskDescription.isNotEmpty) ...[
//                   const SizedBox(height: 6),
//                   Text(
//                     task.taskDescription,
//                     style: TextStyle(
//                       fontSize: 12.5,
//                       color: AppColors.textSecondary,
//                       height: 1.4,
//                     ),
//                     maxLines: 2,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ],
//                 if (task.comments.isNotEmpty) ...[
//                   const SizedBox(height: 10),
//                   Container(
//                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
//                     decoration: BoxDecoration(
//                       color: AppColors.cyan.withOpacity(0.05),
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(color: AppColors.cyan.withOpacity(0.15)),
//                     ),
//                     child: Row(
//                       children: [
//                         Icon(Icons.comment_outlined,
//                             size: 13, color: AppColors.cyan),
//                         const SizedBox(width: 6),
//                         Expanded(
//                           child: Text(
//                             task.comments,
//                             style: TextStyle(
//                                 fontSize: 11.5,
//                                 color: AppColors.textSecondary),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//                 const SizedBox(height: 14),
//                 Row(
//                   children: [
//                     Icon(Icons.person_outline_rounded,
//                         size: 13, color: AppColors.textSecondary),
//                     const SizedBox(width: 4),
//                     Text('By: ',
//                         style: TextStyle(
//                             fontSize: 11, color: AppColors.textSecondary)),
//                     Expanded(
//                       child: Text(
//                         task.assignedBy,
//                         style: const TextStyle(
//                             fontSize: 11, fontWeight: FontWeight.w600,
//                             color: AppColors.textPrimary),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     // Update button - Hide for completed tasks
//                     if (!isCompleted)
//                       GestureDetector(
//                         onTap: () => _showUpdateSheet(task),
//                         child: Container(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 14, vertical: 8),
//                           decoration: BoxDecoration(
//                             gradient: const LinearGradient(
//                               colors: [AppColors.primary, AppColors.cyan],
//                               begin: Alignment.topLeft,
//                               end: Alignment.bottomRight,
//                             ),
//                             borderRadius: BorderRadius.circular(8),
//                             boxShadow: [
//                               BoxShadow(
//                                   color: AppColors.cyan.withOpacity(0.30),
//                                   blurRadius: 8,
//                                   offset: const Offset(0, 3))
//                             ],
//                           ),
//                           child: const Row(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Icon(Icons.edit_rounded, size: 13, color: Colors.white),
//                               SizedBox(width: 5),
//                               Text('Update',
//                                   style: TextStyle(
//                                       fontSize: 12,
//                                       fontWeight: FontWeight.w700,
//                                       color: Colors.white)),
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
//
//   // ══════════════════════════════════════════════════════════════════════════
//   //  Update Bottom Sheet
//   // ══════════════════════════════════════════════════════════════════════════
//   // Updated _showUpdateSheet method with modern redesign
//   void _showUpdateSheet(TaskModel task) {
//     debugPrint('🔍 Task Card - ID: ${task.id}, Title: ${task.taskTitle}');
//
//     String selectedStatus = task.status;
//     String selectedPriority = task.priority ?? 'Medium';
//     String? selectedCategory = task.category.isNotEmpty ? task.category : null;
//     DateTime? selectedDueDate;
//
//     // Parse existing due date if available
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
//     final commentsController = TextEditingController(text: task.comments ?? '');
//     final titleController = TextEditingController(text: task.taskTitle);
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
//               // Drag Handle
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
//               // Header with Gradient
//               Container(
//                 padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
//                 decoration: const BoxDecoration(
//                   gradient: LinearGradient(
//                     colors: [
//                       AppColors.primary,
//                       AppColors.cyan,
//                     ],
//                     begin: Alignment.topLeft,
//                     end: Alignment.bottomRight,
//                   ),
//                   borderRadius: BorderRadius.only(
//                     topLeft: Radius.circular(28),
//                     topRight: Radius.circular(28),
//                   ),
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Container(
//                           width: 48,
//                           height: 48,
//                           decoration: BoxDecoration(
//                             color: Colors.white.withOpacity(0.2),
//                             borderRadius: BorderRadius.circular(16),
//                           ),
//                           child: const Icon(
//                             Icons.edit_note_rounded,
//                             size: 24,
//                             color: Colors.white,
//                           ),
//                         ),
//                         const SizedBox(width: 12),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               const Text(
//                                 'Update Task',
//                                 style: TextStyle(
//                                   fontSize: 20,
//                                   fontWeight: FontWeight.w800,
//                                   color: Colors.white,
//                                   letterSpacing: -0.5,
//                                 ),
//                               ),
//                               Text(
//                                 task.taskTitle,
//                                 style: TextStyle(
//                                   fontSize: 13,
//                                   color: Colors.white.withOpacity(0.85),
//                                 ),
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//
//               // Form Content
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
//                       // Task Title Preview
//                       Container(
//                         padding: const EdgeInsets.all(12),
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             colors: [
//                               AppColors.cyan.withOpacity(0.08),
//                               AppColors.primary.withOpacity(0.08),
//                             ],
//                           ),
//                           borderRadius: BorderRadius.circular(16),
//                           border: Border.all(
//                             color: AppColors.cyan.withOpacity(0.2),
//                           ),
//                         ),
//                         child: Row(
//                           children: [
//                             const Icon(
//                               Icons.task_alt_rounded,
//                               size: 20,
//                               color: AppColors.cyan,
//                             ),
//                             const SizedBox(width: 12),
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text(
//                                     'Task ID',
//                                     style: TextStyle(
//                                       fontSize: 10,
//                                       fontWeight: FontWeight.w600,
//                                       color: AppColors.textSecondary,
//                                     ),
//                                   ),
//                                   Text(
//                                     '#${task.id}',
//                                     style: const TextStyle(
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w700,
//                                       color: AppColors.textPrimary,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//
//                       const SizedBox(height: 24),
//
//                       // Status Section
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
//                                 onTap: () => setSheetState(() => selectedStatus = s),
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
//                                       color: selected ? color : AppColors.divider,
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
//                                       Text(
//                                         s,
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           fontWeight: FontWeight.w600,
//                                           color: selected ? Colors.white : color,
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
//                       // Priority Section
//                       _buildModernSection(
//                         title: 'Priority Level',
//                         icon: Icons.flag_rounded,
//                         child: Row(
//                           children: ['Low', 'Medium', 'High'].map((p) {
//                             final selected = selectedPriority == p;
//                             final color = p == 'High'
//                                 ? const Color(0xFFEF4444)
//                                 : p == 'Medium'
//                                 ? AppColors.warning
//                                 : AppColors.greenTeal;
//                             return Expanded(
//                               child: GestureDetector(
//                                 onTap: () => setSheetState(() => selectedPriority = p),
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
//                                       color: selected ? color : AppColors.divider,
//                                       width: selected ? 0 : 1,
//                                     ),
//                                   ),
//                                   child: Row(
//                                     mainAxisAlignment: MainAxisAlignment.center,
//                                     children: [
//                                       Icon(
//                                         p == 'High'
//                                             ? Icons.arrow_upward_rounded
//                                             : p == 'Medium'
//                                             ? Icons.remove_rounded
//                                             : Icons.arrow_downward_rounded,
//                                         size: 16,
//                                         color: selected ? Colors.white : color,
//                                       ),
//                                       const SizedBox(width: 6),
//                                       Text(
//                                         p,
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           fontWeight: FontWeight.w600,
//                                           color: selected ? Colors.white : color,
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
//                       // Due Date Section
//                       _buildModernSection(
//                         title: 'Due Date',
//                         icon: Icons.calendar_today_rounded,
//                         child: GestureDetector(
//                           onTap: () async {
//                             final picked = await showDatePicker(
//                               context: sheetCtx,
//                               initialDate: selectedDueDate ??
//                                   DateTime.now().add(const Duration(days: 1)),
//                               firstDate: DateTime.now(),
//                               lastDate: DateTime.now().add(const Duration(days: 365)),
//                               builder: (context, child) {
//                                 return Theme(
//                                   data: Theme.of(context).copyWith(
//                                     colorScheme: const ColorScheme.light(
//                                       primary: AppColors.cyan,
//                                       onPrimary: Colors.white,
//                                       surface: AppColors.surface,
//                                     ),
//                                   ),
//                                   child: child!,
//                                 );
//                               },
//                             );
//                             if (picked != null) {
//                               setSheetState(() => selectedDueDate = picked);
//                             }
//                           },
//                           child: Container(
//                             padding: const EdgeInsets.all(16),
//                             decoration: BoxDecoration(
//                               color: AppColors.cardBg,
//                               borderRadius: BorderRadius.circular(16),
//                               border: Border.all(
//                                 color: selectedDueDate != null
//                                     ? AppColors.greenTeal
//                                     : AppColors.divider,
//                                 width: selectedDueDate != null ? 1.5 : 1,
//                               ),
//                             ),
//                             child: Row(
//                               children: [
//                                 Container(
//                                   width: 44,
//                                   height: 44,
//                                   decoration: BoxDecoration(
//                                     gradient: LinearGradient(
//                                       colors: [
//                                         AppColors.greenTeal.withOpacity(0.15),
//                                         AppColors.cyan.withOpacity(0.15),
//                                       ],
//                                     ),
//                                     borderRadius: BorderRadius.circular(12),
//                                   ),
//                                   child: Icon(
//                                     Icons.event_rounded,
//                                     color: selectedDueDate != null
//                                         ? AppColors.greenTeal
//                                         : AppColors.textSecondary,
//                                     size: 22,
//                                   ),
//                                 ),
//                                 const SizedBox(width: 14),
//                                 Expanded(
//                                   child: Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       Text(
//                                         'Select Due Date',
//                                         style: TextStyle(
//                                           fontSize: 11,
//                                           fontWeight: FontWeight.w600,
//                                           color: selectedDueDate != null
//                                               ? AppColors.greenTeal
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
//                                 Icon(
//                                   Icons.chevron_right_rounded,
//                                   color: AppColors.textSecondary,
//                                   size: 24,
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(height: 20),
//
//                       // Comments Section
//                       _buildModernSection(
//                         title: 'Comments',
//                         icon: Icons.comment_rounded,
//                         child: TextField(
//                           controller: commentsController,
//                           maxLines: 4,
//                           style: const TextStyle(
//                             fontSize: 13,
//                             color: AppColors.textPrimary,
//                           ),
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
//                                 color: AppColors.cyan,
//                                 width: 1.5,
//                               ),
//                             ),
//                             contentPadding: const EdgeInsets.all(16),
//                           ),
//                         ),
//                       ),
//
//                       const SizedBox(height: 28),
//
//                       // Action Buttons
//                       Row(
//                         children: [
//                           Expanded(
//                             child: GestureDetector(
//                               onTap: () => Get.back(),
//                               child: Container(
//                                 height: 52,
//                                 decoration: BoxDecoration(
//                                   color: AppColors.cardBg,
//                                   borderRadius: BorderRadius.circular(16),
//                                   border: Border.all(
//                                     color: AppColors.divider,
//                                   ),
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
//                           Expanded(
//                             child: Obx(() => GestureDetector(
//                               onTap: _vm.isUpdating.value
//                                   ? null
//                                   : () async {
//                                 String? dueDateStr;
//                                 if (selectedDueDate != null) {
//                                   dueDateStr = DateFormat('dd-MMM-yyyy')
//                                       .format(selectedDueDate!)
//                                       .toUpperCase();
//                                 }
//
//                                 final ok = await _vm.updateTask(
//                                   taskId: task.id,
//                                   status: selectedStatus,
//                                   comments: commentsController.text.trim(),
//                                   priority: selectedPriority,
//                                   dueDate: dueDateStr,
//                                   category: selectedCategory,
//                                   isAssigned: true,
//                                 );
//
//                                 if (ok) {
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
//                                     message: _vm.errorMessage.value.isNotEmpty
//                                         ? _vm.errorMessage.value
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
//                                   gradient: _vm.isUpdating.value
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
//                                   color: _vm.isUpdating.value
//                                       ? AppColors.divider
//                                       : null,
//                                   borderRadius: BorderRadius.circular(16),
//                                   boxShadow: _vm.isUpdating.value
//                                       ? []
//                                       : [
//                                     BoxShadow(
//                                       color: AppColors.cyan.withOpacity(0.3),
//                                       blurRadius: 12,
//                                       offset: const Offset(0, 4),
//                                     ),
//                                   ],
//                                 ),
//                                 child: Center(
//                                   child: _vm.isUpdating.value
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
//                                       Icon(
//                                         Icons.save_rounded,
//                                         color: Colors.white,
//                                         size: 18,
//                                       ),
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
// // Helper method for modern section design
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
//               child: Icon(
//                 icon,
//                 size: 16,
//                 color: AppColors.cyan,
//               ),
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
//   // ── Empty state ─────────────────────────────────────────────────────────────
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Container(
//             width: 88, height: 88,
//             decoration: BoxDecoration(
//               color: AppColors.greenTeal.withOpacity(0.10),
//               shape: BoxShape.circle,
//             ),
//             child: const Icon(Icons.task_alt_rounded,
//                 size: 40, color: AppColors.greenTeal),
//           ),
//           const SizedBox(height: 18),
//           const Text('No tasks found',
//               style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w700,
//                   color: AppColors.textPrimary)),
//           const SizedBox(height: 6),
//           Text(
//             _filter.value == 'Completed'
//                 ? 'No completed tasks yet.'
//                 : 'No tasks available in this category.',
//             style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
//           ),
//           const SizedBox(height: 24),
//           GestureDetector(
//             onTap: () => _vm.fetchAssignedTasks(),
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//               decoration: BoxDecoration(
//                 color: AppColors.cyan.withOpacity(0.10),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: AppColors.cyan.withOpacity(0.25)),
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.refresh_rounded, size: 16, color: AppColors.cyan),
//                   const SizedBox(width: 6),
//                   Text('Refresh',
//                       style: TextStyle(
//                           fontSize: 13,
//                           fontWeight: FontWeight.w600,
//                           color: AppColors.cyan)),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ── Helpers ─────────────────────────────────────────────────────────────────
//   Widget _sheetLabel(String text) => Text(
//     text,
//     style: TextStyle(
//         fontSize: 12,
//         fontWeight: FontWeight.w600,
//         color: AppColors.textSecondary),
//   );
//
//   Widget _sectionHeader(String title, IconData icon, Color color) {
//     return Row(children: [
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
//               color: AppColors.primary,
//               fontSize: 13,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../AppColors.dart';
import '../Models/task_model.dart';
import '../ViewModels/task_view_model.dart';

class MyTasksActivityScreen extends StatefulWidget {
  const MyTasksActivityScreen({super.key});

  @override
  State<MyTasksActivityScreen> createState() => _MyTasksActivityScreenState();
}

class _MyTasksActivityScreenState extends State<MyTasksActivityScreen>
    with SingleTickerProviderStateMixin {
  late TaskViewModel   _vm;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  final RxString _filter = 'All'.obs;

  // ── Track updated tasks ──────────────────────────────────────────────────────
  final RxSet<int> _updatedIds = <int>{}.obs;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _vm = Get.put(TaskViewModel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm.fetchAssignedTasks();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Status mapping helper ──────────────────────────────────────────────────
  String _normalizeStatus(String status) {
    final normalized = status.toLowerCase().trim();

    // Status mapping - maps UI status to database values (all lowercase)
    final Map<String, String> statusMap = {
      'pending': 'pending',
      'in progress': 'in progress',
      'inprogress': 'in progress',
      'progress': 'in progress',
      'completed': 'completed',
      'done': 'completed',
      'overdue': 'overdue',
      'paused': 'paused',
      'cancelled': 'cancelled',
      'open': 'pending',
    };

    return statusMap[normalized] ?? normalized;
  }

  // ── Display status with proper capitalization ──────────────────────────────
  String _displayStatus(String status) {
    final lower = status.toLowerCase().trim();
    switch (lower) {
      case 'pending':
        return 'Pending';
      case 'in progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'overdue':
        return 'Overdue';
      case 'paused':
        return 'Paused';
      case 'cancelled':
        return 'Cancelled';
      case 'open':
        return 'Pending';
      default:
        return status;
    }
  }

  // Updated: Now shows all tasks including completed based on filter
  List<TaskModel> get _filteredTasks {
    if (_filter.value == 'All') {
      return _vm.assignedTasks;
    } else {
      return _vm.assignedTasks.where((t) => _displayStatus(t.status) == _filter.value).toList();
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Obx(() {
                if (_vm.isLoadingAssigned.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.cyan),
                  );
                }

                return RefreshIndicator(
                  color:    AppColors.cyan,
                  onRefresh: () => _vm.fetchAssignedTasks(),
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatsRow(),
                              const SizedBox(height: 20),
                              _buildFilterRow(),
                              const SizedBox(height: 18),
                              _sectionHeader(
                                  'Tasks',
                                  Icons.task_alt_rounded,
                                  AppColors.cyan),
                              const SizedBox(height: 14),
                            ],
                          ),
                        ),
                      ),
                      Obx(() {
                        final tasks = _filteredTasks;
                        if (tasks.isEmpty) {
                          return SliverFillRemaining(
                            child: _buildEmptyState(),
                          );
                        }
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                                  (_, i) => Obx(() => _buildTaskCard(tasks[i])),
                              childCount: tasks.length,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.cyan,
            AppColors.cyanBright,
            AppColors.greenTeal,
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
              top: -50, right: -30,
              child: _decorCircle(180, AppColors.greenTeal, 0.12)),
          Positioned(
              bottom: -40, left: -20,
              child: _decorCircle(130, Colors.white, 0.10)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border:       Border.all(
                            color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Task Activity',
                          style: TextStyle(
                            color:         Colors.white,
                            fontSize:      18,
                            fontWeight:    FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Text(
                          'All assigned tasks',
                          style: TextStyle(
                            color:    Colors.white.withOpacity(0.65),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _vm.fetchAssignedTasks(),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border:       Border.all(
                            color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Icon(Icons.refresh_rounded,
                          color: Colors.white, size: 22),
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

  // ── Stats row - Made scrollable horizontally ─────────────────────────────────
  Widget _buildStatsRow() {
    return Obx(() {
      final all        = _vm.assignedTasks.length;
      final pending    = _vm.assignedTasks
          .where((t) => t.status.toLowerCase() == 'pending' || t.status == 'Pending').length;
      final inProgress = _vm.assignedTasks
          .where((t) => t.status.toLowerCase() == 'in progress' || t.status == 'In Progress').length;
      final completed  = _vm.assignedTasks
          .where((t) => t.status.toLowerCase() == 'completed' || t.status == 'Completed' || t.status.toLowerCase() == 'done').length;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _statTile('Total', all.toString(),
                AppColors.cyan, Icons.list_alt_rounded),
            const SizedBox(width: 10),
            _statTile('Pending', pending.toString(),
                AppColors.warning, Icons.hourglass_empty_rounded),
            const SizedBox(width: 10),
            _statTile('Progress', inProgress.toString(),
                AppColors.skyBlueDk, Icons.autorenew_rounded),
            const SizedBox(width: 10),
            _statTile('Completed', completed.toString(),
                AppColors.greenTeal, Icons.check_circle_rounded),
          ],
        ),
      );
    });
  }

  Widget _statTile(String label, String count, Color color, IconData icon) {
    return Container(
      width: 85,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 6),
          Text(count,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ── Filter chips - Made scrollable horizontally ───────────────────────────
  Widget _buildFilterRow() {
    return Obx(() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: ['All', 'Pending', 'In Progress', 'Completed'].map((f) {
          final isActive = _filter.value == f;
          Color c = f == 'Pending'
              ? AppColors.warning
              : f == 'In Progress'
              ? AppColors.skyBlueDk
              : f == 'Completed'
              ? AppColors.greenTeal
              : AppColors.cyan;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _filter.value = f,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? c.withOpacity(0.12) : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isActive ? c : AppColors.divider,
                      width: isActive ? 1.5 : 1),
                ),
                child: Text(
                  f,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive ? c : AppColors.textSecondary),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ));
  }

  // ── Task card - Updated to handle completed/cancelled tasks ──────────────────────────
  Widget _buildTaskCard(TaskModel task) {
    final displayStatus = _displayStatus(task.status);
    final isInProgress = displayStatus == 'In Progress';
    final isCompleted = displayStatus == 'Completed';
    final isCancelled = displayStatus == 'Cancelled';
    final isPending = displayStatus == 'Pending';
    final isCompletedOrCancelled = isCompleted || isCancelled;

    Color statusColor;
    IconData statusIcon;

    if (isCompleted) {
      statusColor = AppColors.greenTeal;
      statusIcon = Icons.check_circle_rounded;
    } else if (isCancelled) {
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_rounded;
    } else if (isInProgress) {
      statusColor = AppColors.skyBlueDk;
      statusIcon = Icons.autorenew_rounded;
    } else {
      statusColor = AppColors.warning;
      statusIcon = Icons.hourglass_empty_rounded;
    }

    Color priorityColor = AppColors.textSecondary;
    if (task.priority.toLowerCase() == 'high')   priorityColor = AppColors.error;
    if (task.priority.toLowerCase() == 'medium') priorityColor = AppColors.warning;
    if (task.priority.toLowerCase() == 'low')    priorityColor = AppColors.greenTeal;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isCompletedOrCancelled
                ? (isCancelled ? AppColors.error : AppColors.greenTeal).withOpacity(0.20)
                : statusColor.withOpacity(0.20)
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: (isCompletedOrCancelled
                  ? (isCancelled ? AppColors.error : AppColors.greenTeal)
                  : statusColor).withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isCompletedOrCancelled
                        ? (isCancelled ? AppColors.error : AppColors.greenTeal)
                        : statusColor).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          isCancelled ? Icons.cancel_rounded : statusIcon,
                          size: 11,
                          color: isCompletedOrCancelled
                              ? (isCancelled ? AppColors.error : AppColors.greenTeal)
                              : statusColor
                      ),
                      const SizedBox(width: 4),
                      Text(
                        displayStatus,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isCompletedOrCancelled
                                ? (isCancelled ? AppColors.error : AppColors.greenTeal)
                                : statusColor
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Priority badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(task.priority ?? 'N/A',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: priorityColor)),
                ),
                // Category badge (show if not empty)
                if (task.category.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.label_outline_rounded,
                            size: 10, color: AppColors.cyan),
                        const SizedBox(width: 3),
                        Text(task.category,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.cyan)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                // Due date
                if (task.dueDate.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 11, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(task.dueDate,
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
              ],
            ),
          ),

          // ── Body ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title + ID row ──────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.taskTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Task ID badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.20)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tag_rounded,
                              size: 10,
                              color: AppColors.primary.withOpacity(0.70)),
                          const SizedBox(width: 3),
                          Text(
                            '${task.id}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary.withOpacity(0.70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (task.taskDescription.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    task.taskDescription,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (task.comments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cyan.withOpacity(0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.comment_outlined,
                            size: 13, color: AppColors.cyan),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            task.comments,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('By: ',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    Expanded(
                      child: Text(
                        task.assignedBy,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Update button - Hide for completed/cancelled tasks
                    if (!isCompletedOrCancelled)
                      GestureDetector(
                        onTap: () => _showUpdateSheet(task),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: _updatedIds.contains(task.id)
                                ? null
                                : const LinearGradient(
                              colors: [AppColors.primary, AppColors.cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            color: _updatedIds.contains(task.id)
                                ? AppColors.greenTeal
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: _updatedIds.contains(task.id)
                                ? []
                                : [
                              BoxShadow(
                                  color: AppColors.cyan.withOpacity(0.30),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3))
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  _updatedIds.contains(task.id)
                                      ? Icons.check_circle_rounded
                                      : Icons.edit_rounded,
                                  size: 13,
                                  color: Colors.white
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _updatedIds.contains(task.id) ? 'Updated' : 'Update',
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

  // ══════════════════════════════════════════════════════════════════════════
  //  Update Bottom Sheet - Updated with status normalization
  // ══════════════════════════════════════════════════════════════════════════
  void _showUpdateSheet(TaskModel task) {
    debugPrint('🔍 Task Card - ID: ${task.id}, Title: ${task.taskTitle}');

    // Check if task is already completed or cancelled - prevent update
    final isCompletedOrCancelled = task.status.toLowerCase() == 'completed' ||
        task.status.toLowerCase() == 'cancelled' ||
        task.status == 'Completed' ||
        task.status == 'Cancelled';

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

    String selectedStatus = _displayStatus(task.status);
    String selectedPriority = task.priority.isNotEmpty ? task.priority : 'medium';
    String? selectedCategory = task.category.isNotEmpty ? task.category : null;
    DateTime? selectedDueDate;

    // Parse existing due date if available
    if (task.dueDate.isNotEmpty) {
      try {
        selectedDueDate = DateFormat('dd-MMM-yyyy').parse(task.dueDate);
      } catch (_) {
        try {
          selectedDueDate = DateFormat('dd MMM yyyy').parse(task.dueDate);
        } catch (_) {}
      }
    }

    final commentsController = TextEditingController(text: task.comments ?? '');

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
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header with Gradient
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.cyan,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.edit_note_rounded,
                            size: 24,
                            color: Colors.white,
                          ),
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
                                  color: Colors.white.withOpacity(0.85),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Form Content
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
                      // Task ID Preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.cyan.withOpacity(0.08),
                              AppColors.primary.withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.cyan.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.task_alt_rounded,
                              size: 20,
                              color: AppColors.cyan,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Task ID',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  Text(
                                    '#${task.id}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Status Section - Now shows proper display values
                      _buildModernSection(
                        title: 'Status',
                        icon: Icons.timeline_rounded,
                        child: Row(
                          children: ['Pending', 'In Progress', 'Completed'].map((displayStatus) {
                            final selected = selectedStatus == displayStatus;
                            final color = displayStatus == 'Pending'
                                ? AppColors.warning
                                : displayStatus == 'In Progress'
                                ? AppColors.skyBlueDk
                                : AppColors.greenTeal;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setSheetState(() => selectedStatus = displayStatus),
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
                                      color: selected ? color : AppColors.divider,
                                      width: selected ? 0 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        displayStatus == 'Pending'
                                            ? Icons.hourglass_empty_rounded
                                            : displayStatus == 'In Progress'
                                            ? Icons.autorenew_rounded
                                            : Icons.check_circle_rounded,
                                        size: 16,
                                        color: selected ? Colors.white : color,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        displayStatus,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: selected ? Colors.white : color,
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

                      // Priority Section
                      _buildModernSection(
                        title: 'Priority Level',
                        icon: Icons.flag_rounded,
                        child: Row(
                          children: ['Low', 'Medium', 'High'].map((p) {
                            final selected = selectedPriority == p;
                            final color = p == 'High'
                                ? const Color(0xFFEF4444)
                                : p == 'Medium'
                                ? AppColors.warning
                                : AppColors.greenTeal;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setSheetState(() => selectedPriority = p),
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
                                      color: selected ? color : AppColors.divider,
                                      width: selected ? 0 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        p == 'High'
                                            ? Icons.arrow_upward_rounded
                                            : p == 'Medium'
                                            ? Icons.remove_rounded
                                            : Icons.arrow_downward_rounded,
                                        size: 16,
                                        color: selected ? Colors.white : color,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        p,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: selected ? Colors.white : color,
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

                      // Due Date Section
                      _buildModernSection(
                        title: 'Due Date',
                        icon: Icons.calendar_today_rounded,
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: sheetCtx,
                              initialDate: selectedDueDate ??
                                  DateTime.now().add(const Duration(days: 1)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: AppColors.cyan,
                                      onPrimary: Colors.white,
                                      surface: AppColors.surface,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setSheetState(() => selectedDueDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selectedDueDate != null
                                    ? AppColors.greenTeal
                                    : AppColors.divider,
                                width: selectedDueDate != null ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.greenTeal.withOpacity(0.15),
                                        AppColors.cyan.withOpacity(0.15),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.event_rounded,
                                    color: selectedDueDate != null
                                        ? AppColors.greenTeal
                                        : AppColors.textSecondary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Select Due Date',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: selectedDueDate != null
                                              ? AppColors.greenTeal
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
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textSecondary,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Comments Section
                      _buildModernSection(
                        title: 'Comments',
                        icon: Icons.comment_rounded,
                        child: TextField(
                          controller: commentsController,
                          maxLines: 4,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
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
                                color: AppColors.cyan,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Action Buttons
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
                                  border: Border.all(
                                    color: AppColors.divider,
                                  ),
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
                              onTap: _vm.isUpdating.value
                                  ? null
                                  : () async {
                                String? dueDateStr;
                                if (selectedDueDate != null) {
                                  dueDateStr = DateFormat('dd-MMM-yyyy')
                                      .format(selectedDueDate!)
                                      .toUpperCase();
                                }

                                // Normalize status before sending
                                final normalizedStatus = _normalizeStatus(selectedStatus);

                                debugPrint('🔄 [Update] Original status: $selectedStatus');
                                debugPrint('🔄 [Update] Normalized status: $normalizedStatus');

                                final ok = await _vm.updateTask(
                                  taskId: task.id,
                                  status: normalizedStatus,
                                  comments: commentsController.text.trim(),
                                  priority: selectedPriority.toLowerCase(),
                                  dueDate: dueDateStr,
                                  category: selectedCategory,
                                  isAssigned: true,
                                );

                                if (ok) {
                                  _updatedIds.add(task.id);
                                  await _vm.fetchAssignedTasks();
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
                                    message: _vm.errorMessage.value.isNotEmpty
                                        ? _vm.errorMessage.value
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
                                  gradient: _vm.isUpdating.value
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
                                  color: _vm.isUpdating.value
                                      ? AppColors.divider
                                      : null,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: _vm.isUpdating.value
                                      ? []
                                      : [
                                    BoxShadow(
                                      color: AppColors.cyan.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _vm.isUpdating.value
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
                                      Icon(
                                        Icons.save_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
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

// Helper method for modern section design
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
              child: Icon(
                icon,
                size: 16,
                color: AppColors.cyan,
              ),
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

  // ── Empty state ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: AppColors.greenTeal.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.task_alt_rounded,
                size: 40, color: AppColors.greenTeal),
          ),
          const SizedBox(height: 18),
          const Text('No tasks found',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(
            _filter.value == 'Completed'
                ? 'No completed tasks yet.'
                : 'No tasks available in this category.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _vm.fetchAssignedTasks(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cyan.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cyan.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 16, color: AppColors.cyan),
                  const SizedBox(width: 6),
                  Text('Refresh',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cyan)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _sheetLabel(String text) => Text(
    text,
    style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary),
  );

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
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    ]);
  }

  Widget _decorCircle(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );
}