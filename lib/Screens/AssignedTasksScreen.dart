// // //
// // // import 'package:flutter/material.dart';
// // // import 'package:flutter/services.dart';
// // // import 'package:get/get.dart';
// // // import 'package:intl/intl.dart';
// // //
// // // import '../AppColors.dart';
// // // import '../ViewModels/task_view_model.dart';
// // // import '../Models/task_model.dart';
// // //
// // // class AssignedTasksScreen extends StatefulWidget {
// // //   const AssignedTasksScreen({super.key});
// // //
// // //   @override
// // //   State<AssignedTasksScreen> createState() => _AssignedTasksScreenState();
// // // }
// // //
// // // class _AssignedTasksScreenState extends State<AssignedTasksScreen>
// // //     with SingleTickerProviderStateMixin {
// // //
// // //   final TaskViewModel _vm = Get.find<TaskViewModel>();
// // //
// // //   late AnimationController _fadeCtrl;
// // //   late Animation<double> _fadeAnim;
// // //
// // //   @override
// // //   void initState() {
// // //     super.initState();
// // //     _fadeCtrl = AnimationController(
// // //         vsync: this, duration: const Duration(milliseconds: 450));
// // //     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
// // //     _fadeCtrl.forward();
// // //
// // //     WidgetsBinding.instance.addPostFrameCallback((_) {
// // //       _vm.fetchAssignedTasks();
// // //     });
// // //   }
// // //
// // //   @override
// // //   void dispose() {
// // //     _fadeCtrl.dispose();
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
// // //       backgroundColor: AppColors.surface,
// // //       body: FadeTransition(
// // //         opacity: _fadeAnim,
// // //         child: SafeArea(
// // //           top: false,
// // //           child: Column(
// // //             children: [
// // //               _buildHeader(),
// // //               const SizedBox(height: 10),
// // //               _buildFilterChips(),
// // //               Expanded(child: _buildBody()),
// // //             ],
// // //           ),
// // //         ),
// // //       ),
// // //     );
// // //   }
// // //
// // //   // ── HEADER ────────────────────────────────────────────────────────────────
// // //   Widget _buildHeader() {
// // //     return Container(
// // //       decoration: const BoxDecoration(
// // //         gradient: LinearGradient(
// // //           colors: [
// // //             AppColors.primary,
// // //             AppColors.cyan,
// // //             AppColors.cyanBright,
// // //             AppColors.greenTeal,
// // //           ],
// // //         ),
// // //         borderRadius: BorderRadius.only(
// // //           bottomLeft: Radius.circular(36),
// // //           bottomRight: Radius.circular(36),
// // //         ),
// // //       ),
// // //       child: SafeArea(
// // //         child: Padding(
// // //           padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
// // //           child: Row(
// // //             children: [
// // //               GestureDetector(
// // //                 onTap: () => Get.back(),
// // //                 child: Container(
// // //                   width: 42,
// // //                   height: 42,
// // //                   decoration: BoxDecoration(
// // //                     color: Colors.white.withOpacity(0.12),
// // //                     borderRadius: BorderRadius.circular(10),
// // //                   ),
// // //                   child: const Icon(Icons.arrow_back_ios_new_rounded,
// // //                       color: Colors.white, size: 18),
// // //                 ),
// // //               ),
// // //               const SizedBox(width: 14),
// // //
// // //               const Expanded(
// // //                 child: Column(
// // //                   crossAxisAlignment: CrossAxisAlignment.start,
// // //                   children: [
// // //                     Text(
// // //                       'Assigned Tasks',
// // //                       maxLines: 1,
// // //                       overflow: TextOverflow.ellipsis,
// // //                       style: TextStyle(
// // //                         color: Colors.white,
// // //                         fontSize: 18,
// // //                         fontWeight: FontWeight.w800,
// // //                       ),
// // //                     ),
// // //                     Text(
// // //                       'Tasks assigned to you',
// // //                       maxLines: 1,
// // //                       overflow: TextOverflow.ellipsis,
// // //                       style: TextStyle(
// // //                         color: Color(0xAAFFFFFF),
// // //                         fontSize: 11,
// // //                       ),
// // //                     ),
// // //                   ],
// // //                 ),
// // //               ),
// // //
// // //               Obx(() => GestureDetector(
// // //                 onTap: _vm.fetchAssignedTasks,
// // //                 child: Container(
// // //                   width: 42,
// // //                   height: 42,
// // //                   decoration: BoxDecoration(
// // //                     color: Colors.white.withOpacity(0.12),
// // //                     borderRadius: BorderRadius.circular(10),
// // //                   ),
// // //                   child: _vm.isLoadingAssigned.value
// // //                       ? const Padding(
// // //                       padding: EdgeInsets.all(10),
// // //                       child: CircularProgressIndicator(
// // //                           color: Colors.white, strokeWidth: 2))
// // //                       : const Icon(Icons.refresh_rounded,
// // //                       color: Colors.white),
// // //                 ),
// // //               )),
// // //             ],
// // //           ),
// // //         ),
// // //       ),
// // //     );
// // //   }
// // //
// // //   // ── FILTER ────────────────────────────────────────────────────────────────
// // //   Widget _buildFilterChips() {
// // //     return Obx(() {
// // //       final current = _vm.assignedFilter.value;
// // //
// // //       return SizedBox(
// // //         height: 35,
// // //         child: ListView.separated(
// // //           scrollDirection: Axis.horizontal,
// // //           padding: const EdgeInsets.symmetric(horizontal: 16),
// // //           itemCount: _vm.filterOptions.length,
// // //           separatorBuilder: (_, __) => const SizedBox(width: 8),
// // //           itemBuilder: (_, i) {
// // //             final opt = _vm.filterOptions[i];
// // //             final selected = current == opt;
// // //
// // //             return GestureDetector(
// // //               onTap: () => _vm.assignedFilter.value = opt,
// // //               child: Container(
// // //                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
// // //                 decoration: BoxDecoration(
// // //                   color: selected ? AppColors.cyan : AppColors.cardBg,
// // //                   borderRadius: BorderRadius.circular(20),
// // //                 ),
// // //                 child: Text(
// // //                   opt,
// // //                   maxLines: 1,
// // //                   overflow: TextOverflow.ellipsis,
// // //                   style: TextStyle(
// // //                     color: selected ? Colors.white : AppColors.textSecondary,
// // //                     fontSize: 12,
// // //                   ),
// // //                 ),
// // //               ),
// // //             );
// // //           },
// // //         ),
// // //       );
// // //     });
// // //   }
// // //
// // //   // ── BODY ──────────────────────────────────────────────────────────────────
// // //   Widget _buildBody() {
// // //     return Obx(() {
// // //       if (_vm.isLoadingAssigned.value) {
// // //         return const Center(
// // //             child: CircularProgressIndicator(color: AppColors.cyan));
// // //       }
// // //
// // //       final tasks = _vm.filteredAssigned;
// // //
// // //       if (tasks.isEmpty) {
// // //         return const Center(child: Text('No tasks'));
// // //       }
// // //
// // //       return ListView.separated(
// // //         padding: const EdgeInsets.all(16),
// // //         itemCount: tasks.length,
// // //         separatorBuilder: (_, __) => const SizedBox(height: 12),
// // //         itemBuilder: (_, i) => _TaskCard(
// // //           task: tasks[i],
// // //           onUpdate: () => _showUpdateSheet(tasks[i]),
// // //         ),
// // //       );
// // //     });
// // //   }
// // //
// // //   // ══════════════════════════════════════════════════════════════════════════
// // //   //  Update Bottom Sheet  (same logic as MyTasksActivityScreen)
// // //   // ══════════════════════════════════════════════════════════════════════════
// // //   void _showUpdateSheet(TaskModel task) {
// // //     debugPrint('🔍 AssignedTask - ID: ${task.id}, Title: ${task.taskTitle}');
// // //
// // //     String selectedStatus   = task.status;
// // //     String selectedPriority = task.priority.isNotEmpty ? task.priority : 'medium';
// // //     String? selectedCategory = task.category.isNotEmpty ? task.category : null;
// // //     DateTime? selectedDueDate;
// // //
// // //     if (task.dueDate.isNotEmpty) {
// // //       try {
// // //         selectedDueDate = DateFormat('dd-MMM-yyyy').parse(task.dueDate);
// // //       } catch (_) {
// // //         try {
// // //           selectedDueDate = DateFormat('dd MMM yyyy').parse(task.dueDate);
// // //         } catch (_) {}
// // //       }
// // //     }
// // //
// // //     final commentsController = TextEditingController(text: task.comments);
// // //
// // //     Get.bottomSheet(
// // //       StatefulBuilder(
// // //         builder: (sheetCtx, setSheetState) => Container(
// // //           decoration: const BoxDecoration(
// // //             color: AppColors.surface,
// // //             borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
// // //           ),
// // //           child: Column(
// // //             mainAxisSize: MainAxisSize.min,
// // //             children: [
// // //               // ── Drag handle ──
// // //               Container(
// // //                 margin: const EdgeInsets.only(top: 12, bottom: 8),
// // //                 width: 40,
// // //                 height: 4,
// // //                 decoration: BoxDecoration(
// // //                   color: AppColors.divider,
// // //                   borderRadius: BorderRadius.circular(2),
// // //                 ),
// // //               ),
// // //
// // //               // ── Gradient header ──
// // //               Container(
// // //                 padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
// // //                 decoration: const BoxDecoration(
// // //                   gradient: LinearGradient(
// // //                     colors: [AppColors.primary, AppColors.cyan],
// // //                     begin: Alignment.topLeft,
// // //                     end: Alignment.bottomRight,
// // //                   ),
// // //                   borderRadius: BorderRadius.only(
// // //                     topLeft: Radius.circular(28),
// // //                     topRight: Radius.circular(28),
// // //                   ),
// // //                 ),
// // //                 child: Row(
// // //                   children: [
// // //                     Container(
// // //                       width: 48,
// // //                       height: 48,
// // //                       decoration: BoxDecoration(
// // //                         color: Colors.white.withOpacity(0.2),
// // //                         borderRadius: BorderRadius.circular(16),
// // //                       ),
// // //                       child: const Icon(Icons.edit_note_rounded,
// // //                           size: 24, color: Colors.white),
// // //                     ),
// // //                     const SizedBox(width: 12),
// // //                     Expanded(
// // //                       child: Column(
// // //                         crossAxisAlignment: CrossAxisAlignment.start,
// // //                         children: [
// // //                           const Text(
// // //                             'Update Task',
// // //                             style: TextStyle(
// // //                               fontSize: 20,
// // //                               fontWeight: FontWeight.w800,
// // //                               color: Colors.white,
// // //                               letterSpacing: -0.5,
// // //                             ),
// // //                           ),
// // //                           Text(
// // //                             task.taskTitle,
// // //                             style: TextStyle(
// // //                                 fontSize: 13,
// // //                                 color: Colors.white.withOpacity(0.85)),
// // //                             maxLines: 1,
// // //                             overflow: TextOverflow.ellipsis,
// // //                           ),
// // //                         ],
// // //                       ),
// // //                     ),
// // //                   ],
// // //                 ),
// // //               ),
// // //
// // //               // ── Form content ──
// // //               Flexible(
// // //                 child: SingleChildScrollView(
// // //                   padding: EdgeInsets.only(
// // //                     left: 20,
// // //                     right: 20,
// // //                     top: 20,
// // //                     bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
// // //                   ),
// // //                   child: Column(
// // //                     crossAxisAlignment: CrossAxisAlignment.start,
// // //                     children: [
// // //
// // //                       // Task ID preview
// // //                       Container(
// // //                         padding: const EdgeInsets.all(12),
// // //                         decoration: BoxDecoration(
// // //                           gradient: LinearGradient(colors: [
// // //                             AppColors.cyan.withOpacity(0.08),
// // //                             AppColors.primary.withOpacity(0.08),
// // //                           ]),
// // //                           borderRadius: BorderRadius.circular(16),
// // //                           border: Border.all(
// // //                               color: AppColors.cyan.withOpacity(0.2)),
// // //                         ),
// // //                         child: Row(
// // //                           children: [
// // //                             const Icon(Icons.task_alt_rounded,
// // //                                 size: 20, color: AppColors.cyan),
// // //                             const SizedBox(width: 12),
// // //                             Expanded(
// // //                               child: Column(
// // //                                 crossAxisAlignment: CrossAxisAlignment.start,
// // //                                 children: [
// // //                                   const Text('Task ID',
// // //                                       style: TextStyle(
// // //                                           fontSize: 10,
// // //                                           fontWeight: FontWeight.w600,
// // //                                           color: AppColors.textSecondary)),
// // //                                   Text('#${task.id}',
// // //                                       style: const TextStyle(
// // //                                           fontSize: 14,
// // //                                           fontWeight: FontWeight.w700,
// // //                                           color: AppColors.textPrimary)),
// // //                                 ],
// // //                               ),
// // //                             ),
// // //                           ],
// // //                         ),
// // //                       ),
// // //
// // //                       const SizedBox(height: 24),
// // //
// // //                       // ── Status ──
// // //                       _buildModernSection(
// // //                         title: 'Status',
// // //                         icon: Icons.timeline_rounded,
// // //                         child: Row(
// // //                           children: ['Pending', 'In Progress', 'Completed'].map((s) {
// // //                             final selected = selectedStatus == s;
// // //                             final color = s == 'Pending'
// // //                                 ? AppColors.warning
// // //                                 : s == 'In Progress'
// // //                                 ? AppColors.skyBlueDk
// // //                                 : AppColors.greenTeal;
// // //                             return Expanded(
// // //                               child: GestureDetector(
// // //                                 onTap: () =>
// // //                                     setSheetState(() => selectedStatus = s),
// // //                                 child: AnimatedContainer(
// // //                                   duration: const Duration(milliseconds: 200),
// // //                                   margin: const EdgeInsets.only(right: 8),
// // //                                   padding: const EdgeInsets.symmetric(vertical: 12),
// // //                                   decoration: BoxDecoration(
// // //                                     gradient: selected
// // //                                         ? LinearGradient(
// // //                                       colors: [
// // //                                         color.withOpacity(0.9),
// // //                                         color,
// // //                                       ],
// // //                                       begin: Alignment.topLeft,
// // //                                       end: Alignment.bottomRight,
// // //                                     )
// // //                                         : null,
// // //                                     color: selected ? null : AppColors.cardBg,
// // //                                     borderRadius: BorderRadius.circular(12),
// // //                                     border: Border.all(
// // //                                       color: selected
// // //                                           ? color
// // //                                           : AppColors.divider,
// // //                                       width: selected ? 0 : 1,
// // //                                     ),
// // //                                   ),
// // //                                   child: Row(
// // //                                     mainAxisAlignment: MainAxisAlignment.center,
// // //                                     children: [
// // //                                       Icon(
// // //                                         s == 'Pending'
// // //                                             ? Icons.hourglass_empty_rounded
// // //                                             : s == 'In Progress'
// // //                                             ? Icons.autorenew_rounded
// // //                                             : Icons.check_circle_rounded,
// // //                                         size: 16,
// // //                                         color: selected ? Colors.white : color,
// // //                                       ),
// // //                                       const SizedBox(width: 6),
// // //                                       Flexible(
// // //                                         child: Text(
// // //                                           s,
// // //                                           style: TextStyle(
// // //                                             fontSize: 11,
// // //                                             fontWeight: FontWeight.w600,
// // //                                             color: selected
// // //                                                 ? Colors.white
// // //                                                 : color,
// // //                                           ),
// // //                                           overflow: TextOverflow.ellipsis,
// // //                                         ),
// // //                                       ),
// // //                                     ],
// // //                                   ),
// // //                                 ),
// // //                               ),
// // //                             );
// // //                           }).toList(),
// // //                         ),
// // //                       ),
// // //
// // //                       const SizedBox(height: 20),
// // //
// // //                       // ── Priority ──
// // //                       _buildModernSection(
// // //                         title: 'Priority',
// // //                         icon: Icons.flag_rounded,
// // //                         child: Row(
// // //                           children: ['low', 'medium', 'high'].map((p) {
// // //                             final selected = selectedPriority == p;
// // //                             final color = p == 'high'
// // //                                 ? AppColors.error
// // //                                 : p == 'medium'
// // //                                 ? AppColors.warning
// // //                                 : AppColors.greenTeal;
// // //                             return Expanded(
// // //                               child: GestureDetector(
// // //                                 onTap: () =>
// // //                                     setSheetState(() => selectedPriority = p),
// // //                                 child: AnimatedContainer(
// // //                                   duration: const Duration(milliseconds: 200),
// // //                                   margin: const EdgeInsets.only(right: 8),
// // //                                   padding: const EdgeInsets.symmetric(vertical: 12),
// // //                                   decoration: BoxDecoration(
// // //                                     color: selected
// // //                                         ? color.withOpacity(0.12)
// // //                                         : AppColors.cardBg,
// // //                                     borderRadius: BorderRadius.circular(12),
// // //                                     border: Border.all(
// // //                                       color: selected
// // //                                           ? color
// // //                                           : AppColors.divider,
// // //                                       width: selected ? 1.5 : 1,
// // //                                     ),
// // //                                   ),
// // //                                   child: Column(
// // //                                     children: [
// // //                                       Icon(Icons.flag_rounded,
// // //                                           size: 18, color: color),
// // //                                       const SizedBox(height: 4),
// // //                                       Text(
// // //                                         p,
// // //                                         style: TextStyle(
// // //                                           fontSize: 11,
// // //                                           fontWeight: FontWeight.w600,
// // //                                           color: color,
// // //                                         ),
// // //                                       ),
// // //                                     ],
// // //                                   ),
// // //                                 ),
// // //                               ),
// // //                             );
// // //                           }).toList(),
// // //                         ),
// // //                       ),
// // //
// // //                       const SizedBox(height: 20),
// // //
// // //                       // ── Due date ──
// // //                       _buildModernSection(
// // //                         title: 'Due Date',
// // //                         icon: Icons.calendar_today_rounded,
// // //                         child: GestureDetector(
// // //                           onTap: () async {
// // //                             final picked = await showDatePicker(
// // //                               context: sheetCtx,
// // //                               initialDate:
// // //                               selectedDueDate ?? DateTime.now(),
// // //                               firstDate: DateTime(2020),
// // //                               lastDate: DateTime(2030),
// // //                               builder: (ctx, child) => Theme(
// // //                                 data: Theme.of(ctx).copyWith(
// // //                                   colorScheme: const ColorScheme.light(
// // //                                     primary: AppColors.cyan,
// // //                                     onPrimary: Colors.white,
// // //                                   ),
// // //                                 ),
// // //                                 child: child!,
// // //                               ),
// // //                             );
// // //                             if (picked != null) {
// // //                               setSheetState(
// // //                                       () => selectedDueDate = picked);
// // //                             }
// // //                           },
// // //                           child: Container(
// // //                             padding: const EdgeInsets.all(14),
// // //                             decoration: BoxDecoration(
// // //                               color: AppColors.cardBg,
// // //                               borderRadius: BorderRadius.circular(16),
// // //                               border: Border.all(
// // //                                 color: selectedDueDate != null
// // //                                     ? AppColors.cyan.withOpacity(0.4)
// // //                                     : AppColors.divider,
// // //                               ),
// // //                             ),
// // //                             child: Row(
// // //                               children: [
// // //                                 Container(
// // //                                   width: 40,
// // //                                   height: 40,
// // //                                   decoration: BoxDecoration(
// // //                                     color: AppColors.cyan.withOpacity(0.1),
// // //                                     borderRadius: BorderRadius.circular(12),
// // //                                   ),
// // //                                   child: Icon(
// // //                                     Icons.calendar_month_rounded,
// // //                                     color: selectedDueDate != null
// // //                                         ? AppColors.cyan
// // //                                         : AppColors.textSecondary,
// // //                                     size: 20,
// // //                                   ),
// // //                                 ),
// // //                                 const SizedBox(width: 12),
// // //                                 Expanded(
// // //                                   child: Column(
// // //                                     crossAxisAlignment:
// // //                                     CrossAxisAlignment.start,
// // //                                     children: [
// // //                                       Text(
// // //                                         'Due Date',
// // //                                         style: TextStyle(
// // //                                           fontSize: 11,
// // //                                           fontWeight: FontWeight.w500,
// // //                                           color: selectedDueDate != null
// // //                                               ? AppColors.cyan
// // //                                               : AppColors.textSecondary,
// // //                                           letterSpacing: 0.5,
// // //                                         ),
// // //                                       ),
// // //                                       const SizedBox(height: 4),
// // //                                       Text(
// // //                                         selectedDueDate == null
// // //                                             ? 'Tap to set a deadline'
// // //                                             : DateFormat('EEEE, dd MMM yyyy')
// // //                                             .format(selectedDueDate!),
// // //                                         style: TextStyle(
// // //                                           fontSize: 14,
// // //                                           fontWeight: FontWeight.w700,
// // //                                           color: selectedDueDate == null
// // //                                               ? AppColors.textSecondary
// // //                                               : AppColors.textPrimary,
// // //                                         ),
// // //                                       ),
// // //                                     ],
// // //                                   ),
// // //                                 ),
// // //                                 Icon(Icons.chevron_right_rounded,
// // //                                     color: AppColors.textSecondary, size: 24),
// // //                               ],
// // //                             ),
// // //                           ),
// // //                         ),
// // //                       ),
// // //
// // //                       const SizedBox(height: 20),
// // //
// // //                       // ── Comments ──
// // //                       _buildModernSection(
// // //                         title: 'Comments',
// // //                         icon: Icons.comment_rounded,
// // //                         child: TextField(
// // //                           controller: commentsController,
// // //                           maxLines: 4,
// // //                           style: const TextStyle(
// // //                               fontSize: 13, color: AppColors.textPrimary),
// // //                           decoration: InputDecoration(
// // //                             hintText: 'Add your comments or notes...',
// // //                             hintStyle: TextStyle(
// // //                               color: AppColors.textSecondary.withOpacity(0.5),
// // //                               fontSize: 13,
// // //                             ),
// // //                             filled: true,
// // //                             fillColor: AppColors.cardBg,
// // //                             border: OutlineInputBorder(
// // //                               borderRadius: BorderRadius.circular(16),
// // //                               borderSide: BorderSide.none,
// // //                             ),
// // //                             enabledBorder: OutlineInputBorder(
// // //                               borderRadius: BorderRadius.circular(16),
// // //                               borderSide: BorderSide.none,
// // //                             ),
// // //                             focusedBorder: OutlineInputBorder(
// // //                               borderRadius: BorderRadius.circular(16),
// // //                               borderSide: const BorderSide(
// // //                                   color: AppColors.cyan, width: 1.5),
// // //                             ),
// // //                             contentPadding: const EdgeInsets.all(16),
// // //                           ),
// // //                         ),
// // //                       ),
// // //
// // //                       const SizedBox(height: 28),
// // //
// // //                       // ── Action buttons ──
// // //                       Row(
// // //                         children: [
// // //                           // Cancel
// // //                           Expanded(
// // //                             child: GestureDetector(
// // //                               onTap: () => Get.back(),
// // //                               child: Container(
// // //                                 height: 52,
// // //                                 decoration: BoxDecoration(
// // //                                   color: AppColors.cardBg,
// // //                                   borderRadius: BorderRadius.circular(16),
// // //                                   border:
// // //                                   Border.all(color: AppColors.divider),
// // //                                 ),
// // //                                 child: const Center(
// // //                                   child: Text(
// // //                                     'Cancel',
// // //                                     style: TextStyle(
// // //                                       fontSize: 15,
// // //                                       fontWeight: FontWeight.w600,
// // //                                       color: AppColors.textSecondary,
// // //                                     ),
// // //                                   ),
// // //                                 ),
// // //                               ),
// // //                             ),
// // //                           ),
// // //                           const SizedBox(width: 12),
// // //                           // Save
// // //                           Expanded(
// // //                             child: Obx(() => GestureDetector(
// // //                               onTap: _vm.isUpdating.value
// // //                                   ? null
// // //                                   : () async {
// // //                                 String? dueDateStr;
// // //                                 if (selectedDueDate != null) {
// // //                                   dueDateStr = DateFormat('dd-MMM-yyyy')
// // //                                       .format(selectedDueDate!)
// // //                                       .toUpperCase();
// // //                                 }
// // //
// // //                                 final ok = await _vm.updateTask(
// // //                                   taskId: task.id,
// // //                                   status: selectedStatus,
// // //                                   comments:
// // //                                   commentsController.text.trim(),
// // //                                   priority: selectedPriority,
// // //                                   dueDate: dueDateStr,
// // //                                   category: selectedCategory,
// // //                                   isAssigned: true,
// // //                                 );
// // //
// // //                                 if (ok) {
// // //                                   Get.back();
// // //                                   Get.showSnackbar(const GetSnackBar(
// // //                                     message: 'Task updated successfully!',
// // //                                     duration: Duration(seconds: 2),
// // //                                     backgroundColor: AppColors.greenTeal,
// // //                                     icon: Icon(
// // //                                       Icons.check_circle_outline_rounded,
// // //                                       color: Colors.white,
// // //                                     ),
// // //                                     borderRadius: 10,
// // //                                     margin: EdgeInsets.all(12),
// // //                                   ));
// // //                                 } else {
// // //                                   Get.showSnackbar(GetSnackBar(
// // //                                     message: _vm.errorMessage.value
// // //                                         .isNotEmpty
// // //                                         ? _vm.errorMessage.value
// // //                                         : 'Update failed. Try again.',
// // //                                     duration: const Duration(seconds: 3),
// // //                                     backgroundColor: AppColors.error,
// // //                                     icon: const Icon(
// // //                                       Icons.error_outline_rounded,
// // //                                       color: Colors.white,
// // //                                     ),
// // //                                     borderRadius: 10,
// // //                                     margin: const EdgeInsets.all(12),
// // //                                   ));
// // //                                 }
// // //                               },
// // //                               child: Container(
// // //                                 height: 52,
// // //                                 decoration: BoxDecoration(
// // //                                   gradient: _vm.isUpdating.value
// // //                                       ? null
// // //                                       : const LinearGradient(
// // //                                     colors: [
// // //                                       AppColors.primary,
// // //                                       AppColors.cyan,
// // //                                       AppColors.greenTeal,
// // //                                     ],
// // //                                     begin: Alignment.topLeft,
// // //                                     end: Alignment.bottomRight,
// // //                                   ),
// // //                                   color: _vm.isUpdating.value
// // //                                       ? AppColors.divider
// // //                                       : null,
// // //                                   borderRadius: BorderRadius.circular(16),
// // //                                   boxShadow: _vm.isUpdating.value
// // //                                       ? []
// // //                                       : [
// // //                                     BoxShadow(
// // //                                       color: AppColors.cyan
// // //                                           .withOpacity(0.3),
// // //                                       blurRadius: 12,
// // //                                       offset: const Offset(0, 4),
// // //                                     ),
// // //                                   ],
// // //                                 ),
// // //                                 child: Center(
// // //                                   child: _vm.isUpdating.value
// // //                                       ? const SizedBox(
// // //                                     width: 22,
// // //                                     height: 22,
// // //                                     child: CircularProgressIndicator(
// // //                                       color: Colors.white,
// // //                                       strokeWidth: 2.5,
// // //                                     ),
// // //                                   )
// // //                                       : const Row(
// // //                                     mainAxisAlignment:
// // //                                     MainAxisAlignment.center,
// // //                                     children: [
// // //                                       Icon(Icons.save_rounded,
// // //                                           color: Colors.white, size: 18),
// // //                                       SizedBox(width: 8),
// // //                                       Text(
// // //                                         'Save Changes',
// // //                                         style: TextStyle(
// // //                                           color: Colors.white,
// // //                                           fontSize: 15,
// // //                                           fontWeight: FontWeight.w700,
// // //                                         ),
// // //                                       ),
// // //                                     ],
// // //                                   ),
// // //                                 ),
// // //                               ),
// // //                             )),
// // //                           ),
// // //                         ],
// // //                       ),
// // //                     ],
// // //                   ),
// // //                 ),
// // //               ),
// // //             ],
// // //           ),
// // //         ),
// // //       ),
// // //       isScrollControlled: true,
// // //       backgroundColor: Colors.transparent,
// // //       enableDrag: true,
// // //     );
// // //   }
// // //
// // //   // ── Section header helper (matches MyTasksActivityScreen style) ───────────
// // //   Widget _buildModernSection({
// // //     required String title,
// // //     required IconData icon,
// // //     required Widget child,
// // //   }) {
// // //     return Column(
// // //       crossAxisAlignment: CrossAxisAlignment.start,
// // //       children: [
// // //         Row(
// // //           children: [
// // //             Container(
// // //               width: 28,
// // //               height: 28,
// // //               decoration: BoxDecoration(
// // //                 gradient: LinearGradient(
// // //                   colors: [
// // //                     AppColors.cyan.withOpacity(0.1),
// // //                     AppColors.primary.withOpacity(0.1),
// // //                   ],
// // //                 ),
// // //                 borderRadius: BorderRadius.circular(8),
// // //               ),
// // //               child: Icon(icon, size: 16, color: AppColors.cyan),
// // //             ),
// // //             const SizedBox(width: 10),
// // //             Text(
// // //               title,
// // //               style: const TextStyle(
// // //                 fontSize: 14,
// // //                 fontWeight: FontWeight.w700,
// // //                 color: AppColors.textPrimary,
// // //                 letterSpacing: -0.3,
// // //               ),
// // //             ),
// // //           ],
// // //         ),
// // //         const SizedBox(height: 12),
// // //         child,
// // //       ],
// // //     );
// // //   }
// // // }
// // //
// // // // ════════════════════════════════════════════════════════════════════════════
// // // // TASK CARD  — now accepts an onUpdate callback
// // // // ════════════════════════════════════════════════════════════════════════════
// // //
// // // class _TaskCard extends StatelessWidget {
// // //   final TaskModel task;
// // //   final VoidCallback onUpdate;
// // //
// // //   const _TaskCard({required this.task, required this.onUpdate});
// // //
// // //   @override
// // //   Widget build(BuildContext context) {
// // //     final isCompleted = task.status == 'Completed';
// // //
// // //     Color statusColor;
// // //     IconData statusIcon;
// // //     if (isCompleted) {
// // //       statusColor = AppColors.greenTeal;
// // //       statusIcon  = Icons.check_circle_rounded;
// // //     } else if (task.status == 'In Progress') {
// // //       statusColor = AppColors.skyBlueDk;
// // //       statusIcon  = Icons.autorenew_rounded;
// // //     } else {
// // //       statusColor = AppColors.warning;
// // //       statusIcon  = Icons.hourglass_empty_rounded;
// // //     }
// // //
// // //     Color priorityColor = AppColors.textSecondary;
// // //     if (task.priority == 'high')   priorityColor = AppColors.error;
// // //     if (task.priority == 'medium') priorityColor = AppColors.warning;
// // //     if (task.priority == 'low')    priorityColor = AppColors.greenTeal;
// // //
// // //     return Container(
// // //       decoration: BoxDecoration(
// // //         color: AppColors.cardBg,
// // //         borderRadius: BorderRadius.circular(16),
// // //         border: Border.all(color: statusColor.withOpacity(0.20)),
// // //         boxShadow: [
// // //           BoxShadow(
// // //               color: Colors.black.withOpacity(0.05),
// // //               blurRadius: 12,
// // //               offset: const Offset(0, 4)),
// // //         ],
// // //       ),
// // //       child: Column(
// // //         crossAxisAlignment: CrossAxisAlignment.start,
// // //         children: [
// // //
// // //           // ── Status bar ──
// // //           Container(
// // //             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
// // //             decoration: BoxDecoration(
// // //               color: statusColor.withOpacity(0.06),
// // //               borderRadius:
// // //               const BorderRadius.vertical(top: Radius.circular(16)),
// // //             ),
// // //             child: Row(
// // //               children: [
// // //                 // Status badge
// // //                 Container(
// // //                   padding:
// // //                   const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
// // //                   decoration: BoxDecoration(
// // //                     color: statusColor.withOpacity(0.14),
// // //                     borderRadius: BorderRadius.circular(6),
// // //                   ),
// // //                   child: Row(
// // //                     mainAxisSize: MainAxisSize.min,
// // //                     children: [
// // //                       Icon(statusIcon, size: 11, color: statusColor),
// // //                       const SizedBox(width: 4),
// // //                       Text(task.status,
// // //                           style: TextStyle(
// // //                               fontSize: 10,
// // //                               fontWeight: FontWeight.w700,
// // //                               color: statusColor)),
// // //                     ],
// // //                   ),
// // //                 ),
// // //                 const SizedBox(width: 8),
// // //                 // Priority badge
// // //                 Container(
// // //                   padding:
// // //                   const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
// // //                   decoration: BoxDecoration(
// // //                     color: priorityColor.withOpacity(0.10),
// // //                     borderRadius: BorderRadius.circular(6),
// // //                   ),
// // //                   child: Row(
// // //                     mainAxisSize: MainAxisSize.min,
// // //                     children: [
// // //                       Icon(Icons.flag_rounded,
// // //                           size: 11, color: priorityColor),
// // //                       const SizedBox(width: 4),
// // //                       Text(task.priority,
// // //                           style: TextStyle(
// // //                               fontSize: 10,
// // //                               fontWeight: FontWeight.w700,
// // //                               color: priorityColor)),
// // //                     ],
// // //                   ),
// // //                 ),
// // //               ],
// // //             ),
// // //           ),
// // //
// // //           // ── Card body ──
// // //           Padding(
// // //             padding: const EdgeInsets.all(16),
// // //             child: Column(
// // //               crossAxisAlignment: CrossAxisAlignment.start,
// // //               children: [
// // //
// // //                 // Title
// // //                 Text(
// // //                   task.taskTitle,
// // //                   maxLines: 1,
// // //                   overflow: TextOverflow.ellipsis,
// // //                   style: const TextStyle(
// // //                       fontSize: 14, fontWeight: FontWeight.w700),
// // //                 ),
// // //                 const SizedBox(height: 4),
// // //
// // //                 // Assigned by
// // //                 Text(
// // //                   'Assigned by: ${task.assignedBy}',
// // //                   maxLines: 1,
// // //                   overflow: TextOverflow.ellipsis,
// // //                   style: TextStyle(
// // //                       color: AppColors.textSecondary, fontSize: 11),
// // //                 ),
// // //
// // //                 const SizedBox(height: 10),
// // //
// // //                 // Meta chips
// // //                 Wrap(
// // //                   spacing: 8,
// // //                   runSpacing: 6,
// // //                   children: [
// // //                     _MetaChip(
// // //                       icon: Icons.person,
// // //                       label: task.empName,
// // //                       color: AppColors.skyBlueDk,
// // //                     ),
// // //                     _MetaChip(
// // //                       icon: Icons.calendar_today,
// // //                       label: task.dueDate,
// // //                       color: AppColors.greenTeal,
// // //                     ),
// // //                   ],
// // //                 ),
// // //
// // //                 const SizedBox(height: 14),
// // //
// // //                 // Bottom row: emp name + Update button
// // //                 Row(
// // //                   children: [
// // //                     Icon(Icons.person_outline_rounded,
// // //                         size: 13, color: AppColors.textSecondary),
// // //                     const SizedBox(width: 4),
// // //                     Expanded(
// // //                       child: Text(
// // //                         task.empName,
// // //                         style: const TextStyle(
// // //                             fontSize: 11, fontWeight: FontWeight.w600,
// // //                             color: AppColors.textPrimary),
// // //                         overflow: TextOverflow.ellipsis,
// // //                       ),
// // //                     ),
// // //
// // //                     // ── Update button — hidden when already Completed ──
// // //                     if (!isCompleted)
// // //                       GestureDetector(
// // //                         onTap: onUpdate,
// // //                         child: Container(
// // //                           padding: const EdgeInsets.symmetric(
// // //                               horizontal: 14, vertical: 8),
// // //                           decoration: BoxDecoration(
// // //                             gradient: const LinearGradient(
// // //                               colors: [AppColors.primary, AppColors.cyan],
// // //                               begin: Alignment.topLeft,
// // //                               end: Alignment.bottomRight,
// // //                             ),
// // //                             borderRadius: BorderRadius.circular(8),
// // //                             boxShadow: [
// // //                               BoxShadow(
// // //                                   color: AppColors.cyan.withOpacity(0.30),
// // //                                   blurRadius: 8,
// // //                                   offset: const Offset(0, 3)),
// // //                             ],
// // //                           ),
// // //                           child: const Row(
// // //                             mainAxisSize: MainAxisSize.min,
// // //                             children: [
// // //                               Icon(Icons.edit_rounded,
// // //                                   size: 13, color: Colors.white),
// // //                               SizedBox(width: 5),
// // //                               Text('Update',
// // //                                   style: TextStyle(
// // //                                       fontSize: 12,
// // //                                       fontWeight: FontWeight.w700,
// // //                                       color: Colors.white)),
// // //                             ],
// // //                           ),
// // //                         ),
// // //                       ),
// // //                   ],
// // //                 ),
// // //               ],
// // //             ),
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // // }
// // //
// // // // ── Small chip widget ─────────────────────────────────────────────────────
// // //
// // // class _MetaChip extends StatelessWidget {
// // //   final IconData icon;
// // //   final String label;
// // //   final Color color;
// // //
// // //   const _MetaChip({
// // //     required this.icon,
// // //     required this.label,
// // //     required this.color,
// // //   });
// // //
// // //   @override
// // //   Widget build(BuildContext context) {
// // //     return Container(
// // //       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
// // //       decoration: BoxDecoration(
// // //         color: color.withOpacity(0.1),
// // //         borderRadius: BorderRadius.circular(8),
// // //       ),
// // //       child: Row(
// // //         mainAxisSize: MainAxisSize.min,
// // //         children: [
// // //           Icon(icon, size: 12, color: color),
// // //           const SizedBox(width: 4),
// // //           Text(
// // //             label,
// // //             maxLines: 1,
// // //             overflow: TextOverflow.ellipsis,
// // //             style: TextStyle(color: color, fontSize: 10),
// // //           ),
// // //         ],
// // //       ),
// // //     );
// // //   }
// // // }
// //
// // import 'package:flutter/material.dart';
// // import 'package:flutter/services.dart';
// // import 'package:get/get.dart';
// // import 'package:intl/intl.dart';
// //
// // import '../AppColors.dart';
// // import '../ViewModels/task_view_model.dart';
// // import '../Models/task_model.dart';
// //
// // class AssignedTasksScreen extends StatefulWidget {
// //   const AssignedTasksScreen({super.key});
// //
// //   @override
// //   State<AssignedTasksScreen> createState() => _AssignedTasksScreenState();
// // }
// //
// // class _AssignedTasksScreenState extends State<AssignedTasksScreen>
// //     with SingleTickerProviderStateMixin {
// //
// //   final TaskViewModel _vm = Get.find<TaskViewModel>();
// //
// //   // ── Track which tasks have already been updated once ──────────────────────
// //   final Set<int> _updatedIds = {};
// //
// //   late AnimationController _fadeCtrl;
// //   late Animation<double> _fadeAnim;
// //
// //   @override
// //   void initState() {
// //     super.initState();
// //     _fadeCtrl = AnimationController(
// //         vsync: this, duration: const Duration(milliseconds: 450));
// //     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
// //     _fadeCtrl.forward();
// //
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       _vm.fetchAssignedTasks();
// //     });
// //   }
// //
// //   @override
// //   void dispose() {
// //     _fadeCtrl.dispose();
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
// //       backgroundColor: AppColors.surface,
// //       body: FadeTransition(
// //         opacity: _fadeAnim,
// //         child: SafeArea(
// //           top: false,
// //           child: Column(
// //             children: [
// //               _buildHeader(),
// //               const SizedBox(height: 10),
// //               _buildFilterChips(),
// //               Expanded(child: _buildBody()),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // ── HEADER ────────────────────────────────────────────────────────────────
// //   Widget _buildHeader() {
// //     return Container(
// //       decoration: const BoxDecoration(
// //         gradient: LinearGradient(
// //           colors: [
// //             AppColors.primary,
// //             AppColors.cyan,
// //             AppColors.cyanBright,
// //             AppColors.greenTeal,
// //           ],
// //         ),
// //         borderRadius: BorderRadius.only(
// //           bottomLeft: Radius.circular(36),
// //           bottomRight: Radius.circular(36),
// //         ),
// //       ),
// //       child: SafeArea(
// //         child: Padding(
// //           padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
// //           child: Row(
// //             children: [
// //               GestureDetector(
// //                 onTap: () => Get.back(),
// //                 child: Container(
// //                   width: 42,
// //                   height: 42,
// //                   decoration: BoxDecoration(
// //                     color: Colors.white.withOpacity(0.12),
// //                     borderRadius: BorderRadius.circular(10),
// //                   ),
// //                   child: const Icon(Icons.arrow_back_ios_new_rounded,
// //                       color: Colors.white, size: 18),
// //                 ),
// //               ),
// //               const SizedBox(width: 14),
// //
// //               const Expanded(
// //                 child: Column(
// //                   crossAxisAlignment: CrossAxisAlignment.start,
// //                   children: [
// //                     Text(
// //                       'Assigned Tasks',
// //                       maxLines: 1,
// //                       overflow: TextOverflow.ellipsis,
// //                       style: TextStyle(
// //                         color: Colors.white,
// //                         fontSize: 18,
// //                         fontWeight: FontWeight.w800,
// //                       ),
// //                     ),
// //                     Text(
// //                       'Tasks assigned to you',
// //                       maxLines: 1,
// //                       overflow: TextOverflow.ellipsis,
// //                       style: TextStyle(
// //                         color: Color(0xAAFFFFFF),
// //                         fontSize: 11,
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //
// //               Obx(() => GestureDetector(
// //                 onTap: _vm.fetchAssignedTasks,
// //                 child: Container(
// //                   width: 42,
// //                   height: 42,
// //                   decoration: BoxDecoration(
// //                     color: Colors.white.withOpacity(0.12),
// //                     borderRadius: BorderRadius.circular(10),
// //                   ),
// //                   child: _vm.isLoadingAssigned.value
// //                       ? const Padding(
// //                       padding: EdgeInsets.all(10),
// //                       child: CircularProgressIndicator(
// //                           color: Colors.white, strokeWidth: 2))
// //                       : const Icon(Icons.refresh_rounded,
// //                       color: Colors.white),
// //                 ),
// //               )),
// //             ],
// //           ),
// //         ),
// //       ),
// //     );
// //   }
// //
// //   // ── FILTER ────────────────────────────────────────────────────────────────
// //   Widget _buildFilterChips() {
// //     return Obx(() {
// //       final current = _vm.assignedFilter.value;
// //
// //       return SizedBox(
// //         height: 35,
// //         child: ListView.separated(
// //           scrollDirection: Axis.horizontal,
// //           padding: const EdgeInsets.symmetric(horizontal: 16),
// //           itemCount: _vm.filterOptions.length,
// //           separatorBuilder: (_, __) => const SizedBox(width: 8),
// //           itemBuilder: (_, i) {
// //             final opt = _vm.filterOptions[i];
// //             final selected = current == opt;
// //
// //             return GestureDetector(
// //               onTap: () => _vm.assignedFilter.value = opt,
// //               child: Container(
// //                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
// //                 decoration: BoxDecoration(
// //                   color: selected ? AppColors.cyan : AppColors.cardBg,
// //                   borderRadius: BorderRadius.circular(20),
// //                 ),
// //                 child: Text(
// //                   opt,
// //                   maxLines: 1,
// //                   overflow: TextOverflow.ellipsis,
// //                   style: TextStyle(
// //                     color: selected ? Colors.white : AppColors.textSecondary,
// //                     fontSize: 12,
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
// //   // ── BODY ──────────────────────────────────────────────────────────────────
// //   Widget _buildBody() {
// //     return Obx(() {
// //       if (_vm.isLoadingAssigned.value) {
// //         return const Center(
// //             child: CircularProgressIndicator(color: AppColors.cyan));
// //       }
// //
// //       final tasks = _vm.filteredAssigned;
// //
// //       if (tasks.isEmpty) {
// //         return const Center(child: Text('No tasks'));
// //       }
// //
// //       return ListView.separated(
// //         padding: const EdgeInsets.all(16),
// //         itemCount: tasks.length,
// //         separatorBuilder: (_, __) => const SizedBox(height: 12),
// //         itemBuilder: (_, i) => _TaskCard(
// //           task: tasks[i],
// //           isUpdated: _updatedIds.contains(tasks[i].id),
// //           onUpdate: () => _showUpdateSheet(tasks[i]),
// //         ),
// //       );
// //     });
// //   }
// //
// //   // ══════════════════════════════════════════════════════════════════════════
// //   //  Update Bottom Sheet  (same logic as MyTasksActivityScreen)
// //   // ══════════════════════════════════════════════════════════════════════════
// //   void _showUpdateSheet(TaskModel task) {
// //     debugPrint('🔍 AssignedTask - ID: ${task.id}, Title: ${task.taskTitle}');
// //
// //     String selectedStatus   = task.status;
// //     String selectedPriority = task.priority.isNotEmpty ? task.priority : 'medium';
// //     String? selectedCategory = task.category.isNotEmpty ? task.category : null;
// //     DateTime? selectedDueDate;
// //
// //     if (task.dueDate.isNotEmpty) {
// //       try {
// //         selectedDueDate = DateFormat('dd-MMM-yyyy').parse(task.dueDate);
// //       } catch (_) {
// //         try {
// //           selectedDueDate = DateFormat('dd MMM yyyy').parse(task.dueDate);
// //         } catch (_) {}
// //       }
// //     }
// //
// //     final commentsController = TextEditingController(text: task.comments);
// //
// //     Get.bottomSheet(
// //       StatefulBuilder(
// //         builder: (sheetCtx, setSheetState) => Container(
// //           decoration: const BoxDecoration(
// //             color: AppColors.surface,
// //             borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
// //           ),
// //           child: Column(
// //             mainAxisSize: MainAxisSize.min,
// //             children: [
// //               // ── Drag handle ──
// //               Container(
// //                 margin: const EdgeInsets.only(top: 12, bottom: 8),
// //                 width: 40,
// //                 height: 4,
// //                 decoration: BoxDecoration(
// //                   color: AppColors.divider,
// //                   borderRadius: BorderRadius.circular(2),
// //                 ),
// //               ),
// //
// //               // ── Gradient header ──
// //               Container(
// //                 padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
// //                 decoration: const BoxDecoration(
// //                   gradient: LinearGradient(
// //                     colors: [AppColors.primary, AppColors.cyan],
// //                     begin: Alignment.topLeft,
// //                     end: Alignment.bottomRight,
// //                   ),
// //                   borderRadius: BorderRadius.only(
// //                     topLeft: Radius.circular(28),
// //                     topRight: Radius.circular(28),
// //                   ),
// //                 ),
// //                 child: Row(
// //                   children: [
// //                     Container(
// //                       width: 48,
// //                       height: 48,
// //                       decoration: BoxDecoration(
// //                         color: Colors.white.withOpacity(0.2),
// //                         borderRadius: BorderRadius.circular(16),
// //                       ),
// //                       child: const Icon(Icons.edit_note_rounded,
// //                           size: 24, color: Colors.white),
// //                     ),
// //                     const SizedBox(width: 12),
// //                     Expanded(
// //                       child: Column(
// //                         crossAxisAlignment: CrossAxisAlignment.start,
// //                         children: [
// //                           const Text(
// //                             'Update Task',
// //                             style: TextStyle(
// //                               fontSize: 20,
// //                               fontWeight: FontWeight.w800,
// //                               color: Colors.white,
// //                               letterSpacing: -0.5,
// //                             ),
// //                           ),
// //                           Text(
// //                             task.taskTitle,
// //                             style: TextStyle(
// //                                 fontSize: 13,
// //                                 color: Colors.white.withOpacity(0.85)),
// //                             maxLines: 1,
// //                             overflow: TextOverflow.ellipsis,
// //                           ),
// //                         ],
// //                       ),
// //                     ),
// //                   ],
// //                 ),
// //               ),
// //
// //               // ── Form content ──
// //               Flexible(
// //                 child: SingleChildScrollView(
// //                   padding: EdgeInsets.only(
// //                     left: 20,
// //                     right: 20,
// //                     top: 20,
// //                     bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
// //                   ),
// //                   child: Column(
// //                     crossAxisAlignment: CrossAxisAlignment.start,
// //                     children: [
// //
// //                       // Task ID preview
// //                       Container(
// //                         padding: const EdgeInsets.all(12),
// //                         decoration: BoxDecoration(
// //                           gradient: LinearGradient(colors: [
// //                             AppColors.cyan.withOpacity(0.08),
// //                             AppColors.primary.withOpacity(0.08),
// //                           ]),
// //                           borderRadius: BorderRadius.circular(16),
// //                           border: Border.all(
// //                               color: AppColors.cyan.withOpacity(0.2)),
// //                         ),
// //                         child: Row(
// //                           children: [
// //                             const Icon(Icons.task_alt_rounded,
// //                                 size: 20, color: AppColors.cyan),
// //                             const SizedBox(width: 12),
// //                             Expanded(
// //                               child: Column(
// //                                 crossAxisAlignment: CrossAxisAlignment.start,
// //                                 children: [
// //                                   const Text('Task ID',
// //                                       style: TextStyle(
// //                                           fontSize: 10,
// //                                           fontWeight: FontWeight.w600,
// //                                           color: AppColors.textSecondary)),
// //                                   Text('#${task.id}',
// //                                       style: const TextStyle(
// //                                           fontSize: 14,
// //                                           fontWeight: FontWeight.w700,
// //                                           color: AppColors.textPrimary)),
// //                                 ],
// //                               ),
// //                             ),
// //                           ],
// //                         ),
// //                       ),
// //
// //                       const SizedBox(height: 24),
// //
// //                       // ── Status ──
// //                       _buildModernSection(
// //                         title: 'Status',
// //                         icon: Icons.timeline_rounded,
// //                         child: Row(
// //                           children: ['Pending', 'In Progress', 'Completed'].map((s) {
// //                             final selected = selectedStatus == s;
// //                             final color = s == 'Pending'
// //                                 ? AppColors.warning
// //                                 : s == 'In Progress'
// //                                 ? AppColors.skyBlueDk
// //                                 : AppColors.greenTeal;
// //                             return Expanded(
// //                               child: GestureDetector(
// //                                 onTap: () =>
// //                                     setSheetState(() => selectedStatus = s),
// //                                 child: AnimatedContainer(
// //                                   duration: const Duration(milliseconds: 200),
// //                                   margin: const EdgeInsets.only(right: 8),
// //                                   padding: const EdgeInsets.symmetric(vertical: 12),
// //                                   decoration: BoxDecoration(
// //                                     gradient: selected
// //                                         ? LinearGradient(
// //                                       colors: [
// //                                         color.withOpacity(0.9),
// //                                         color,
// //                                       ],
// //                                       begin: Alignment.topLeft,
// //                                       end: Alignment.bottomRight,
// //                                     )
// //                                         : null,
// //                                     color: selected ? null : AppColors.cardBg,
// //                                     borderRadius: BorderRadius.circular(12),
// //                                     border: Border.all(
// //                                       color: selected
// //                                           ? color
// //                                           : AppColors.divider,
// //                                       width: selected ? 0 : 1,
// //                                     ),
// //                                   ),
// //                                   child: Row(
// //                                     mainAxisAlignment: MainAxisAlignment.center,
// //                                     children: [
// //                                       Icon(
// //                                         s == 'Pending'
// //                                             ? Icons.hourglass_empty_rounded
// //                                             : s == 'In Progress'
// //                                             ? Icons.autorenew_rounded
// //                                             : Icons.check_circle_rounded,
// //                                         size: 16,
// //                                         color: selected ? Colors.white : color,
// //                                       ),
// //                                       const SizedBox(width: 6),
// //                                       Flexible(
// //                                         child: Text(
// //                                           s,
// //                                           style: TextStyle(
// //                                             fontSize: 11,
// //                                             fontWeight: FontWeight.w600,
// //                                             color: selected
// //                                                 ? Colors.white
// //                                                 : color,
// //                                           ),
// //                                           overflow: TextOverflow.ellipsis,
// //                                         ),
// //                                       ),
// //                                     ],
// //                                   ),
// //                                 ),
// //                               ),
// //                             );
// //                           }).toList(),
// //                         ),
// //                       ),
// //
// //                       const SizedBox(height: 20),
// //
// //                       // ── Priority ──
// //                       _buildModernSection(
// //                         title: 'Priority',
// //                         icon: Icons.flag_rounded,
// //                         child: Row(
// //                           children: ['low', 'medium', 'high'].map((p) {
// //                             final selected = selectedPriority == p;
// //                             final color = p == 'high'
// //                                 ? AppColors.error
// //                                 : p == 'medium'
// //                                 ? AppColors.warning
// //                                 : AppColors.greenTeal;
// //                             return Expanded(
// //                               child: GestureDetector(
// //                                 onTap: () =>
// //                                     setSheetState(() => selectedPriority = p),
// //                                 child: AnimatedContainer(
// //                                   duration: const Duration(milliseconds: 200),
// //                                   margin: const EdgeInsets.only(right: 8),
// //                                   padding: const EdgeInsets.symmetric(vertical: 12),
// //                                   decoration: BoxDecoration(
// //                                     color: selected
// //                                         ? color.withOpacity(0.12)
// //                                         : AppColors.cardBg,
// //                                     borderRadius: BorderRadius.circular(12),
// //                                     border: Border.all(
// //                                       color: selected
// //                                           ? color
// //                                           : AppColors.divider,
// //                                       width: selected ? 1.5 : 1,
// //                                     ),
// //                                   ),
// //                                   child: Column(
// //                                     children: [
// //                                       Icon(Icons.flag_rounded,
// //                                           size: 18, color: color),
// //                                       const SizedBox(height: 4),
// //                                       Text(
// //                                         p,
// //                                         style: TextStyle(
// //                                           fontSize: 11,
// //                                           fontWeight: FontWeight.w600,
// //                                           color: color,
// //                                         ),
// //                                       ),
// //                                     ],
// //                                   ),
// //                                 ),
// //                               ),
// //                             );
// //                           }).toList(),
// //                         ),
// //                       ),
// //
// //                       const SizedBox(height: 20),
// //
// //                       // ── Due date ──
// //                       _buildModernSection(
// //                         title: 'Due Date',
// //                         icon: Icons.calendar_today_rounded,
// //                         child: GestureDetector(
// //                           onTap: () async {
// //                             final picked = await showDatePicker(
// //                               context: sheetCtx,
// //                               initialDate:
// //                               selectedDueDate ?? DateTime.now(),
// //                               firstDate: DateTime(2020),
// //                               lastDate: DateTime(2030),
// //                               builder: (ctx, child) => Theme(
// //                                 data: Theme.of(ctx).copyWith(
// //                                   colorScheme: const ColorScheme.light(
// //                                     primary: AppColors.cyan,
// //                                     onPrimary: Colors.white,
// //                                   ),
// //                                 ),
// //                                 child: child!,
// //                               ),
// //                             );
// //                             if (picked != null) {
// //                               setSheetState(
// //                                       () => selectedDueDate = picked);
// //                             }
// //                           },
// //                           child: Container(
// //                             padding: const EdgeInsets.all(14),
// //                             decoration: BoxDecoration(
// //                               color: AppColors.cardBg,
// //                               borderRadius: BorderRadius.circular(16),
// //                               border: Border.all(
// //                                 color: selectedDueDate != null
// //                                     ? AppColors.cyan.withOpacity(0.4)
// //                                     : AppColors.divider,
// //                               ),
// //                             ),
// //                             child: Row(
// //                               children: [
// //                                 Container(
// //                                   width: 40,
// //                                   height: 40,
// //                                   decoration: BoxDecoration(
// //                                     color: AppColors.cyan.withOpacity(0.1),
// //                                     borderRadius: BorderRadius.circular(12),
// //                                   ),
// //                                   child: Icon(
// //                                     Icons.calendar_month_rounded,
// //                                     color: selectedDueDate != null
// //                                         ? AppColors.cyan
// //                                         : AppColors.textSecondary,
// //                                     size: 20,
// //                                   ),
// //                                 ),
// //                                 const SizedBox(width: 12),
// //                                 Expanded(
// //                                   child: Column(
// //                                     crossAxisAlignment:
// //                                     CrossAxisAlignment.start,
// //                                     children: [
// //                                       Text(
// //                                         'Due Date',
// //                                         style: TextStyle(
// //                                           fontSize: 11,
// //                                           fontWeight: FontWeight.w500,
// //                                           color: selectedDueDate != null
// //                                               ? AppColors.cyan
// //                                               : AppColors.textSecondary,
// //                                           letterSpacing: 0.5,
// //                                         ),
// //                                       ),
// //                                       const SizedBox(height: 4),
// //                                       Text(
// //                                         selectedDueDate == null
// //                                             ? 'Tap to set a deadline'
// //                                             : DateFormat('EEEE, dd MMM yyyy')
// //                                             .format(selectedDueDate!),
// //                                         style: TextStyle(
// //                                           fontSize: 14,
// //                                           fontWeight: FontWeight.w700,
// //                                           color: selectedDueDate == null
// //                                               ? AppColors.textSecondary
// //                                               : AppColors.textPrimary,
// //                                         ),
// //                                       ),
// //                                     ],
// //                                   ),
// //                                 ),
// //                                 Icon(Icons.chevron_right_rounded,
// //                                     color: AppColors.textSecondary, size: 24),
// //                               ],
// //                             ),
// //                           ),
// //                         ),
// //                       ),
// //
// //                       const SizedBox(height: 20),
// //
// //                       // ── Comments ──
// //                       _buildModernSection(
// //                         title: 'Comments',
// //                         icon: Icons.comment_rounded,
// //                         child: TextField(
// //                           controller: commentsController,
// //                           maxLines: 4,
// //                           style: const TextStyle(
// //                               fontSize: 13, color: AppColors.textPrimary),
// //                           decoration: InputDecoration(
// //                             hintText: 'Add your comments or notes...',
// //                             hintStyle: TextStyle(
// //                               color: AppColors.textSecondary.withOpacity(0.5),
// //                               fontSize: 13,
// //                             ),
// //                             filled: true,
// //                             fillColor: AppColors.cardBg,
// //                             border: OutlineInputBorder(
// //                               borderRadius: BorderRadius.circular(16),
// //                               borderSide: BorderSide.none,
// //                             ),
// //                             enabledBorder: OutlineInputBorder(
// //                               borderRadius: BorderRadius.circular(16),
// //                               borderSide: BorderSide.none,
// //                             ),
// //                             focusedBorder: OutlineInputBorder(
// //                               borderRadius: BorderRadius.circular(16),
// //                               borderSide: const BorderSide(
// //                                   color: AppColors.cyan, width: 1.5),
// //                             ),
// //                             contentPadding: const EdgeInsets.all(16),
// //                           ),
// //                         ),
// //                       ),
// //
// //                       const SizedBox(height: 28),
// //
// //                       // ── Action buttons ──
// //                       Row(
// //                         children: [
// //                           // Cancel
// //                           Expanded(
// //                             child: GestureDetector(
// //                               onTap: () => Get.back(),
// //                               child: Container(
// //                                 height: 52,
// //                                 decoration: BoxDecoration(
// //                                   color: AppColors.cardBg,
// //                                   borderRadius: BorderRadius.circular(16),
// //                                   border:
// //                                   Border.all(color: AppColors.divider),
// //                                 ),
// //                                 child: const Center(
// //                                   child: Text(
// //                                     'Cancel',
// //                                     style: TextStyle(
// //                                       fontSize: 15,
// //                                       fontWeight: FontWeight.w600,
// //                                       color: AppColors.textSecondary,
// //                                     ),
// //                                   ),
// //                                 ),
// //                               ),
// //                             ),
// //                           ),
// //                           const SizedBox(width: 12),
// //                           // Save
// //                           Expanded(
// //                             child: Obx(() => GestureDetector(
// //                               onTap: _vm.isUpdating.value
// //                                   ? null
// //                                   : () async {
// //                                 String? dueDateStr;
// //                                 if (selectedDueDate != null) {
// //                                   dueDateStr = DateFormat('dd-MMM-yyyy')
// //                                       .format(selectedDueDate!)
// //                                       .toUpperCase();
// //                                 }
// //
// //                                 final ok = await _vm.updateTask(
// //                                   taskId: task.id,
// //                                   status: selectedStatus,
// //                                   comments:
// //                                   commentsController.text.trim(),
// //                                   priority: selectedPriority,
// //                                   dueDate: dueDateStr,
// //                                   category: selectedCategory,
// //                                   isAssigned: true,
// //                                 );
// //
// //                                 if (ok) {
// //                                   setState(() => _updatedIds.add(task.id));
// //                                   Get.back();
// //                                   Get.showSnackbar(const GetSnackBar(
// //                                     message: 'Task updated successfully!',
// //                                     duration: Duration(seconds: 2),
// //                                     backgroundColor: AppColors.greenTeal,
// //                                     icon: Icon(
// //                                       Icons.check_circle_outline_rounded,
// //                                       color: Colors.white,
// //                                     ),
// //                                     borderRadius: 10,
// //                                     margin: EdgeInsets.all(12),
// //                                   ));
// //                                 } else {
// //                                   Get.showSnackbar(GetSnackBar(
// //                                     message: _vm.errorMessage.value
// //                                         .isNotEmpty
// //                                         ? _vm.errorMessage.value
// //                                         : 'Update failed. Try again.',
// //                                     duration: const Duration(seconds: 3),
// //                                     backgroundColor: AppColors.error,
// //                                     icon: const Icon(
// //                                       Icons.error_outline_rounded,
// //                                       color: Colors.white,
// //                                     ),
// //                                     borderRadius: 10,
// //                                     margin: const EdgeInsets.all(12),
// //                                   ));
// //                                 }
// //                               },
// //                               child: Container(
// //                                 height: 52,
// //                                 decoration: BoxDecoration(
// //                                   gradient: _vm.isUpdating.value
// //                                       ? null
// //                                       : const LinearGradient(
// //                                     colors: [
// //                                       AppColors.primary,
// //                                       AppColors.cyan,
// //                                       AppColors.greenTeal,
// //                                     ],
// //                                     begin: Alignment.topLeft,
// //                                     end: Alignment.bottomRight,
// //                                   ),
// //                                   color: _vm.isUpdating.value
// //                                       ? AppColors.divider
// //                                       : null,
// //                                   borderRadius: BorderRadius.circular(16),
// //                                   boxShadow: _vm.isUpdating.value
// //                                       ? []
// //                                       : [
// //                                     BoxShadow(
// //                                       color: AppColors.cyan
// //                                           .withOpacity(0.3),
// //                                       blurRadius: 12,
// //                                       offset: const Offset(0, 4),
// //                                     ),
// //                                   ],
// //                                 ),
// //                                 child: Center(
// //                                   child: _vm.isUpdating.value
// //                                       ? const SizedBox(
// //                                     width: 22,
// //                                     height: 22,
// //                                     child: CircularProgressIndicator(
// //                                       color: Colors.white,
// //                                       strokeWidth: 2.5,
// //                                     ),
// //                                   )
// //                                       : const Row(
// //                                     mainAxisAlignment:
// //                                     MainAxisAlignment.center,
// //                                     children: [
// //                                       Icon(Icons.save_rounded,
// //                                           color: Colors.white, size: 18),
// //                                       SizedBox(width: 8),
// //                                       Text(
// //                                         'Save Changes',
// //                                         style: TextStyle(
// //                                           color: Colors.white,
// //                                           fontSize: 15,
// //                                           fontWeight: FontWeight.w700,
// //                                         ),
// //                                       ),
// //                                     ],
// //                                   ),
// //                                 ),
// //                               ),
// //                             )),
// //                           ),
// //                         ],
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               ),
// //             ],
// //           ),
// //         ),
// //       ),
// //       isScrollControlled: true,
// //       backgroundColor: Colors.transparent,
// //       enableDrag: true,
// //     );
// //   }
// //
// //   // ── Section header helper (matches MyTasksActivityScreen style) ───────────
// //   Widget _buildModernSection({
// //     required String title,
// //     required IconData icon,
// //     required Widget child,
// //   }) {
// //     return Column(
// //       crossAxisAlignment: CrossAxisAlignment.start,
// //       children: [
// //         Row(
// //           children: [
// //             Container(
// //               width: 28,
// //               height: 28,
// //               decoration: BoxDecoration(
// //                 gradient: LinearGradient(
// //                   colors: [
// //                     AppColors.cyan.withOpacity(0.1),
// //                     AppColors.primary.withOpacity(0.1),
// //                   ],
// //                 ),
// //                 borderRadius: BorderRadius.circular(8),
// //               ),
// //               child: Icon(icon, size: 16, color: AppColors.cyan),
// //             ),
// //             const SizedBox(width: 10),
// //             Text(
// //               title,
// //               style: const TextStyle(
// //                 fontSize: 14,
// //                 fontWeight: FontWeight.w700,
// //                 color: AppColors.textPrimary,
// //                 letterSpacing: -0.3,
// //               ),
// //             ),
// //           ],
// //         ),
// //         const SizedBox(height: 12),
// //         child,
// //       ],
// //     );
// //   }
// // }
// //
// // // ════════════════════════════════════════════════════════════════════════════
// // // TASK CARD  — now accepts an onUpdate callback
// // // ════════════════════════════════════════════════════════════════════════════
// //
// // class _TaskCard extends StatelessWidget {
// //   final TaskModel task;
// //   final VoidCallback onUpdate;
// //   final bool isUpdated;
// //
// //   const _TaskCard({
// //     required this.task,
// //     required this.onUpdate,
// //     required this.isUpdated,
// //   });
// //
// //   @override
// //   Widget build(BuildContext context) {
// //     final isCompleted = task.status == 'Completed';
// //
// //     Color statusColor;
// //     IconData statusIcon;
// //     if (isCompleted) {
// //       statusColor = AppColors.greenTeal;
// //       statusIcon  = Icons.check_circle_rounded;
// //     } else if (task.status == 'In Progress') {
// //       statusColor = AppColors.skyBlueDk;
// //       statusIcon  = Icons.autorenew_rounded;
// //     } else {
// //       statusColor = AppColors.warning;
// //       statusIcon  = Icons.hourglass_empty_rounded;
// //     }
// //
// //     Color priorityColor = AppColors.textSecondary;
// //     if (task.priority == 'high')   priorityColor = AppColors.error;
// //     if (task.priority == 'medium') priorityColor = AppColors.warning;
// //     if (task.priority == 'low')    priorityColor = AppColors.greenTeal;
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
// //
// //           // ── Status bar ──
// //           Container(
// //             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
// //             decoration: BoxDecoration(
// //               color: statusColor.withOpacity(0.06),
// //               borderRadius:
// //               const BorderRadius.vertical(top: Radius.circular(16)),
// //             ),
// //             child: Row(
// //               children: [
// //                 // Status badge
// //                 Container(
// //                   padding:
// //                   const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
// //                 // Priority badge
// //                 Container(
// //                   padding:
// //                   const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
// //           // ── Card body ──
// //           Padding(
// //             padding: const EdgeInsets.all(16),
// //             child: Column(
// //               crossAxisAlignment: CrossAxisAlignment.start,
// //               children: [
// //
// //                 // Title
// //                 Text(
// //                   task.taskTitle,
// //                   maxLines: 1,
// //                   overflow: TextOverflow.ellipsis,
// //                   style: const TextStyle(
// //                       fontSize: 14, fontWeight: FontWeight.w700),
// //                 ),
// //                 const SizedBox(height: 4),
// //
// //                 // Assigned by
// //                 Text(
// //                   'Assigned by: ${task.assignedBy}',
// //                   maxLines: 1,
// //                   overflow: TextOverflow.ellipsis,
// //                   style: TextStyle(
// //                       color: AppColors.textSecondary, fontSize: 11),
// //                 ),
// //
// //                 const SizedBox(height: 10),
// //
// //                 // Meta chips
// //                 Wrap(
// //                   spacing: 8,
// //                   runSpacing: 6,
// //                   children: [
// //                     _MetaChip(
// //                       icon: Icons.person,
// //                       label: task.empName,
// //                       color: AppColors.skyBlueDk,
// //                     ),
// //                     _MetaChip(
// //                       icon: Icons.calendar_today,
// //                       label: task.dueDate,
// //                       color: AppColors.greenTeal,
// //                     ),
// //                   ],
// //                 ),
// //
// //                 const SizedBox(height: 14),
// //
// //                 // Bottom row: emp name + Update button
// //                 Row(
// //                   children: [
// //                     Icon(Icons.person_outline_rounded,
// //                         size: 13, color: AppColors.textSecondary),
// //                     const SizedBox(width: 4),
// //                     Expanded(
// //                       child: Text(
// //                         task.empName,
// //                         style: const TextStyle(
// //                             fontSize: 11, fontWeight: FontWeight.w600,
// //                             color: AppColors.textPrimary),
// //                         overflow: TextOverflow.ellipsis,
// //                       ),
// //                     ),
// //
// //                     // ── Update button — hidden when Completed or already updated ──
// //                     if (!isCompleted && !isUpdated)
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
// // // ── Small chip widget ─────────────────────────────────────────────────────
// //
// // class _MetaChip extends StatelessWidget {
// //   final IconData icon;
// //   final String label;
// //   final Color color;
// //
// //   const _MetaChip({
// //     required this.icon,
// //     required this.label,
// //     required this.color,
// //   });
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
// //           Text(
// //             label,
// //             maxLines: 1,
// //             overflow: TextOverflow.ellipsis,
// //             style: TextStyle(color: color, fontSize: 10),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }
//
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:intl/intl.dart';
//
// import '../AppColors.dart';
// import '../ViewModels/task_view_model.dart';
// import '../Models/task_model.dart';
//
// class AssignedTasksScreen extends StatefulWidget {
//   const AssignedTasksScreen({super.key});
//
//   @override
//   State<AssignedTasksScreen> createState() => _AssignedTasksScreenState();
// }
//
// class _AssignedTasksScreenState extends State<AssignedTasksScreen>
//     with SingleTickerProviderStateMixin {
//
//   final TaskViewModel _vm = Get.find<TaskViewModel>();
//
//   // ── Track which tasks have already been updated once ──────────────────────
//   final RxSet<int> _updatedIds = <int>{}.obs;
//
//   late AnimationController _fadeCtrl;
//   late Animation<double> _fadeAnim;
//
//   @override
//   void initState() {
//     super.initState();
//     _fadeCtrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 450));
//     _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
//     _fadeCtrl.forward();
//
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
//   @override
//   Widget build(BuildContext context) {
//     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.light,
//     ));
//
//     return Scaffold(
//       backgroundColor: AppColors.surface,
//       body: FadeTransition(
//         opacity: _fadeAnim,
//         child: SafeArea(
//           top: false,
//           child: Column(
//             children: [
//               _buildHeader(),
//               const SizedBox(height: 10),
//               _buildFilterChips(),
//               Expanded(child: _buildBody()),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── HEADER ────────────────────────────────────────────────────────────────
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
//         ),
//         borderRadius: BorderRadius.only(
//           bottomLeft: Radius.circular(36),
//           bottomRight: Radius.circular(36),
//         ),
//       ),
//       child: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
//           child: Row(
//             children: [
//               GestureDetector(
//                 onTap: () => Get.back(),
//                 child: Container(
//                   width: 42,
//                   height: 42,
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.12),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: const Icon(Icons.arrow_back_ios_new_rounded,
//                       color: Colors.white, size: 18),
//                 ),
//               ),
//               const SizedBox(width: 14),
//
//               const Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Assigned Tasks',
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 18,
//                         fontWeight: FontWeight.w800,
//                       ),
//                     ),
//                     Text(
//                       'Tasks assigned to you',
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(
//                         color: Color(0xAAFFFFFF),
//                         fontSize: 11,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               Obx(() => GestureDetector(
//                 onTap: _vm.fetchAssignedTasks,
//                 child: Container(
//                   width: 42,
//                   height: 42,
//                   decoration: BoxDecoration(
//                     color: Colors.white.withOpacity(0.12),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: _vm.isLoadingAssigned.value
//                       ? const Padding(
//                       padding: EdgeInsets.all(10),
//                       child: CircularProgressIndicator(
//                           color: Colors.white, strokeWidth: 2))
//                       : const Icon(Icons.refresh_rounded,
//                       color: Colors.white),
//                 ),
//               )),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // ── FILTER ────────────────────────────────────────────────────────────────
//   Widget _buildFilterChips() {
//     return Obx(() {
//       final current = _vm.assignedFilter.value;
//
//       return SizedBox(
//         height: 35,
//         child: ListView.separated(
//           scrollDirection: Axis.horizontal,
//           padding: const EdgeInsets.symmetric(horizontal: 16),
//           itemCount: _vm.filterOptions.length,
//           separatorBuilder: (_, __) => const SizedBox(width: 8),
//           itemBuilder: (_, i) {
//             final opt = _vm.filterOptions[i];
//             final selected = current == opt;
//
//             return GestureDetector(
//               onTap: () => _vm.assignedFilter.value = opt,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
//                 decoration: BoxDecoration(
//                   color: selected ? AppColors.cyan : AppColors.cardBg,
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Text(
//                   opt,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(
//                     color: selected ? Colors.white : AppColors.textSecondary,
//                     fontSize: 12,
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
//   // ── BODY ──────────────────────────────────────────────────────────────────
//   Widget _buildBody() {
//     return Obx(() {
//       if (_vm.isLoadingAssigned.value) {
//         return const Center(
//             child: CircularProgressIndicator(color: AppColors.cyan));
//       }
//
//       final tasks = _vm.filteredAssigned;
//
//       if (tasks.isEmpty) {
//         return const Center(child: Text('No tasks'));
//       }
//
//       return ListView.separated(
//         padding: const EdgeInsets.all(16),
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
//   // ══════════════════════════════════════════════════════════════════════════
//   //  Update Bottom Sheet  (same logic as MyTasksActivityScreen)
//   // ══════════════════════════════════════════════════════════════════════════
//   void _showUpdateSheet(TaskModel task) {
//     debugPrint('🔍 AssignedTask - ID: ${task.id}, Title: ${task.taskTitle}');
//
//     String selectedStatus   = task.status;
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
//
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
//                                   comments:
//                                   commentsController.text.trim(),
//                                   priority: selectedPriority,
//                                   dueDate: dueDateStr,
//                                   category: selectedCategory,
//                                   isAssigned: true,
//                                 );
//
//                                 if (ok) {
//                                   // ✅ FIX: Add to updated IDs set (reactive)
//                                   _updatedIds.add(task.id);
//
//                                   // ✅ FIX: Refresh the tasks list to show updated data
//                                   await _vm.fetchAssignedTasks();
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
//                                     message: _vm.errorMessage.value
//                                         .isNotEmpty
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
//                                       color: AppColors.cyan
//                                           .withOpacity(0.3),
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
//   // ── Section header helper (matches MyTasksActivityScreen style) ───────────
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
// }
//
// // ════════════════════════════════════════════════════════════════════════════
// // TASK CARD  — now accepts an onUpdate callback
// // ════════════════════════════════════════════════════════════════════════════
//
// class _TaskCard extends StatelessWidget {
//   final TaskModel task;
//   final VoidCallback onUpdate;
//   final bool isUpdated;
//
//   const _TaskCard({
//     required this.task,
//     required this.onUpdate,
//     required this.isUpdated,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final isCompleted = task.status == 'Completed';
//
//     Color statusColor;
//     IconData statusIcon;
//     if (isCompleted) {
//       statusColor = AppColors.greenTeal;
//       statusIcon  = Icons.check_circle_rounded;
//     } else if (task.status == 'In Progress') {
//       statusColor = AppColors.skyBlueDk;
//       statusIcon  = Icons.autorenew_rounded;
//     } else {
//       statusColor = AppColors.warning;
//       statusIcon  = Icons.hourglass_empty_rounded;
//     }
//
//     Color priorityColor = AppColors.textSecondary;
//     if (task.priority == 'high')   priorityColor = AppColors.error;
//     if (task.priority == 'medium') priorityColor = AppColors.warning;
//     if (task.priority == 'low')    priorityColor = AppColors.greenTeal;
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
//
//           // ── Status bar ──
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
//             decoration: BoxDecoration(
//               color: statusColor.withOpacity(0.06),
//               borderRadius:
//               const BorderRadius.vertical(top: Radius.circular(16)),
//             ),
//             child: Row(
//               children: [
//                 // Status badge
//                 Container(
//                   padding:
//                   const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
//                   padding:
//                   const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
//           // ── Card body ──
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//
//                 // Title
//                 Text(
//                   task.taskTitle,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                       fontSize: 14, fontWeight: FontWeight.w700),
//                 ),
//                 const SizedBox(height: 4),
//
//                 // Assigned by
//                 Text(
//                   'Assigned by: ${task.assignedBy}',
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(
//                       color: AppColors.textSecondary, fontSize: 11),
//                 ),
//
//                 const SizedBox(height: 10),
//
//                 // Meta chips
//                 Wrap(
//                   spacing: 8,
//                   runSpacing: 6,
//                   children: [
//                     _MetaChip(
//                       icon: Icons.person,
//                       label: task.empName,
//                       color: AppColors.skyBlueDk,
//                     ),
//                     _MetaChip(
//                       icon: Icons.calendar_today,
//                       label: task.dueDate,
//                       color: AppColors.greenTeal,
//                     ),
//                   ],
//                 ),
//
//                 const SizedBox(height: 14),
//
//                 // Bottom row: emp name + Update button
//                 Row(
//                   children: [
//                     Icon(Icons.person_outline_rounded,
//                         size: 13, color: AppColors.textSecondary),
//                     const SizedBox(width: 4),
//                     Expanded(
//                       child: Text(
//                         task.empName,
//                         style: const TextStyle(
//                             fontSize: 11, fontWeight: FontWeight.w600,
//                             color: AppColors.textPrimary),
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//
//                     // ── Update button — hidden when Completed ──
//                     // ✅ FIX: Show button even if updated, but change appearance
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
// // ── Small chip widget ─────────────────────────────────────────────────────
//
// class _MetaChip extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final Color color;
//
//   const _MetaChip({
//     required this.icon,
//     required this.label,
//     required this.color,
//   });
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
//           Text(
//             label,
//             maxLines: 1,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(color: color, fontSize: 10),
//           ),
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

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen>
    with SingleTickerProviderStateMixin {
  final TaskViewModel _vm = Get.find<TaskViewModel>();

  // ── Double-tap guard ───────────────────────────────────────────────────────
  bool _isPosting = false;

  // ── Controllers ────────────────────────────────────────────────────────────
  final _formKey            = GlobalKey<FormState>();
  final _empIdCtrl          = TextEditingController();
  final _empNameCtrl        = TextEditingController();
  final _taskTitleCtrl      = TextEditingController();
  final _taskDescCtrl       = TextEditingController();
  final _commentsCtrl       = TextEditingController();

  // ── Dropdown values ─────────────────────────────────────────────────────────
  String _status   = 'Open';
  String _priority = 'medium';
  String _taskType = 'SELF'; // ✅ NEW — matches previous default in TaskViewModel.createTask()

  final List<String> _statusOptions   = ['Open', 'In Progress', 'Done', 'Cancel'];
  final List<String> _priorityOptions = ['low', 'medium', 'high'];
  final List<String> _taskTypeOptions = ['SELF', 'ok', 'OFFICE', 'OTHER']; // ✅ NEW

  // ── Date ───────────────────────────────────────────────────────────────────
  DateTime? _dueDate;
  String get _dueDateStr =>
      _dueDate == null ? '' : DateFormat('dd-MMM-yyyy').format(_dueDate!).toUpperCase();

  // ── Animation ──────────────────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late Animation<double>    _fadeAnim;

  // ── Initialization flag ────────────────────────────────────────────────────
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _loadEmployeeData();
  }

  void _initializeAnimation() {
    if (!_isInitialized) {
      _fadeCtrl = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 450));
      _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
      _fadeCtrl.forward();
      _isInitialized = true;
    }
  }

  Future<void> _loadEmployeeData() async {
    final prefs = await SharedPreferences.getInstance();
    final empId   = prefs.getString('userId')   ?? '';
    final empName = prefs.getString('userName') ?? '';
    if (mounted) {
      setState(() {
        _empIdCtrl.text   = empId;
        _empNameCtrl.text = empName;
      });
    }
  }

  @override
  void dispose() {
    _empIdCtrl.dispose();
    _empNameCtrl.dispose();
    _taskTitleCtrl.dispose();
    _taskDescCtrl.dispose();
    _commentsCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Responsive helpers ─────────────────────────────────────────────────────
  double get _screenWidth => MediaQuery.of(context).size.width;
  double get _screenHeight => MediaQuery.of(context).size.height;
  bool get _isMobile => _screenWidth < 600;
  bool get _isTablet => _screenWidth >= 600 && _screenWidth < 900;
  bool get _isDesktop => _screenWidth >= 900;

  double _responsivePadding() {
    if (_isMobile) return 16;
    if (_isTablet) return 20;
    return 24;
  }

  double _responsiveSpacing() {
    if (_isMobile) return 14;
    if (_isTablet) return 16;
    return 18;
  }

  double _responsiveFontSize(double mobileSize) {
    if (_isMobile) return mobileSize;
    if (_isTablet) return mobileSize + 1;
    return mobileSize + 2;
  }

  // ── Date picker ────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate:   DateTime.now(),
      lastDate:    DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
              primary:   AppColors.cyan,
              onPrimary: Colors.white,
              surface:   Colors.white,
              onSurface: AppColors.textPrimary,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) {
      Get.showSnackbar(const GetSnackBar(
        message:         'Please select a due date.',
        duration:        Duration(seconds: 2),
        backgroundColor: AppColors.warning,
        borderRadius:    10,
        margin:          EdgeInsets.all(12),
        icon:            Icon(Icons.warning_amber_rounded, color: Colors.white),
      ));
      return;
    }

    if (_isPosting) return;
    _isPosting = true;

    final success = await _vm.createTask(
      empId:           int.tryParse(_empIdCtrl.text.trim()) ?? 0,
      empName:         _empNameCtrl.text.trim(),
      taskTitle:       _taskTitleCtrl.text.trim(),
      taskDescription: _taskDescCtrl.text.trim(),
      status:          _status,
      priority:        _priority,
      dueDate:         _dueDateStr,
      comments:        _commentsCtrl.text.trim(),
      taskType:        _taskType, // ✅ NEW — sends the dropdown-selected type
    );

    _isPosting = false;

    if (success) {
      Get.back();
      await Future.delayed(const Duration(milliseconds: 300));
      Get.showSnackbar(const GetSnackBar(
        message:         'Task created successfully!',
        duration:        Duration(seconds: 3),
        backgroundColor: AppColors.greenTeal,
        borderRadius:    10,
        margin:          EdgeInsets.all(12),
        icon:            Icon(Icons.check_circle_outline_rounded,
            color: Colors.white),
      ));
    } else {
      Get.showSnackbar(GetSnackBar(
        message:         _vm.errorMessage.value.isNotEmpty
            ? _vm.errorMessage.value
            : 'Something went wrong.',
        duration:        const Duration(seconds: 3),
        backgroundColor: const Color(0xFFEF4444),
        borderRadius:    10,
        margin:          const EdgeInsets.all(12),
        icon:            const Icon(Icons.error_outline_rounded,
            color: Colors.white),
      ));
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Ensure animation is initialized before build
    _initializeAnimation();

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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  _responsivePadding(),
                  _responsiveSpacing() + 10,
                  _responsivePadding(),
                  _responsiveSpacing() + 26,
                ),
                child: _isDesktop
                    ? _buildDesktopLayout()
                    : _buildMobileTabletLayout(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Desktop Layout (2-column) ──────────────────────────────────────────────
  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildFormColumn(isLeftColumn: true),
        ),
        SizedBox(width: _responsiveSpacing() * 2),
        Expanded(
          child: _buildFormColumn(isLeftColumn: false),
        ),
      ],
    );
  }

  // ── Mobile/Tablet Layout (single column) ───────────────────────────────────
  Widget _buildMobileTabletLayout() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Employee Info',
              Icons.person_rounded, AppColors.skyBlueDk),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller:  _empIdCtrl,
            label:       'Employee ID',
            hint:        'Loading...',
            icon:        Icons.badge_rounded,
            iconColor:   AppColors.skyBlueDk,
            readOnly:    true,
            validator:   (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Employee ID not found' : null,
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _empNameCtrl,
            label:      'Employee Name',
            hint:       'Loading...',
            icon:       Icons.person_outline_rounded,
            iconColor:  AppColors.skyBlueDk,
            readOnly:   true,
            validator:  (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Employee name not found' : null,
          ),
          SizedBox(height: _responsiveSpacing() * 1.5),
          _sectionHeader('Task Details',
              Icons.task_alt_rounded, AppColors.cyan),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _taskTitleCtrl,
            label:      'Task Title',
            hint:       'Enter task title',
            icon:       Icons.title_rounded,
            iconColor:  AppColors.cyan,
            validator:  (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Task title is required' : null,
          ),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _taskDescCtrl,
            label:      'Task Description',
            hint:       'Describe the task in detail...',
            icon:       Icons.description_rounded,
            iconColor:  AppColors.cyan,
            maxLines:   _isMobile ? 3 : 4,
            validator:  (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Description is required' : null,
          ),
          SizedBox(height: _responsiveSpacing() * 1.5),
          _sectionHeader('Status & Priority',
              Icons.tune_rounded, AppColors.greenTeal),
          SizedBox(height: _responsiveSpacing()),
          _buildStatusPriorityRow(),
          SizedBox(height: _responsiveSpacing()),
          _buildDatePicker(),
          SizedBox(height: _responsiveSpacing() * 1.5),
          _sectionHeader('Comments',
              Icons.comment_rounded, AppColors.cyanBright),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _commentsCtrl,
            label:      'Comments (Optional)',
            hint:       'Add any notes or remarks...',
            icon:       Icons.sticky_note_2_outlined,
            iconColor:  AppColors.cyanBright,
            maxLines:   _isMobile ? 2 : 3,
          ),
          SizedBox(height: _responsiveSpacing() * 2),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  // ── Desktop form column ────────────────────────────────────────────────────
  Widget _buildFormColumn({required bool isLeftColumn}) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isLeftColumn
            ? [
          _sectionHeader('Employee Info',
              Icons.person_rounded, AppColors.skyBlueDk),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller:  _empIdCtrl,
            label:       'Employee ID',
            hint:        'Loading...',
            icon:        Icons.badge_rounded,
            iconColor:   AppColors.skyBlueDk,
            readOnly:    true,
            validator:   (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Employee ID not found' : null,
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _empNameCtrl,
            label:      'Employee Name',
            hint:       'Loading...',
            icon:       Icons.person_outline_rounded,
            iconColor:  AppColors.skyBlueDk,
            readOnly:   true,
            validator:  (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Employee name not found' : null,
          ),
          SizedBox(height: _responsiveSpacing() * 1.5),
          _sectionHeader('Task Details',
              Icons.task_alt_rounded, AppColors.cyan),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _taskTitleCtrl,
            label:      'Task Title',
            hint:       'Enter task title',
            icon:       Icons.title_rounded,
            iconColor:  AppColors.cyan,
            validator:  (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Task title is required' : null,
          ),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _taskDescCtrl,
            label:      'Task Description',
            hint:       'Describe the task in detail...',
            icon:       Icons.description_rounded,
            iconColor:  AppColors.cyan,
            maxLines:   4,
            validator:  (v) =>
            (v == null || v.trim().isEmpty)
                ? 'Description is required' : null,
          ),
        ]
            : [
          _sectionHeader('Status & Priority',
              Icons.tune_rounded, AppColors.greenTeal),
          SizedBox(height: _responsiveSpacing()),
          _buildStatusPriorityColumn(),
          SizedBox(height: _responsiveSpacing()),
          _buildDatePicker(),
          SizedBox(height: _responsiveSpacing() * 1.5),
          _sectionHeader('Comments',
              Icons.comment_rounded, AppColors.cyanBright),
          SizedBox(height: _responsiveSpacing()),
          _buildTextField(
            controller: _commentsCtrl,
            label:      'Comments (Optional)',
            hint:       'Add any notes or remarks...',
            icon:       Icons.sticky_note_2_outlined,
            iconColor:  AppColors.cyanBright,
            maxLines:   3,
          ),
          SizedBox(height: _responsiveSpacing() * 2),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  // ── Status & Priority Row (mobile/tablet) ──────────────────────────────────
  Widget _buildStatusPriorityRow() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label:    'Status',
                value:    _status,
                items:    _statusOptions,
                icon:     Icons.circle_rounded,
                color:    _statusColor(_status),
                onChanged: (v) => setState(() => _status = v!),
              ),
            ),
            SizedBox(width: _responsiveSpacing()),
            Expanded(
              child: _buildDropdown(
                label:    'Priority',
                value:    _priority,
                items:    _priorityOptions,
                icon:     Icons.flag_rounded,
                color:    _priorityColor(_priority),
                onChanged: (v) => setState(() => _priority = v!),
              ),
            ),
          ],
        ),
        SizedBox(height: _responsiveSpacing()),
        // ✅ NEW — Task Type dropdown
        _buildDropdown(
          label:    'Task Type',
          value:    _taskType,
          items:    _taskTypeOptions,
          icon:     Icons.category_rounded,
          color:    AppColors.primary,
          onChanged: (v) => setState(() => _taskType = v!),
        ),
      ],
    );
  }

  // ── Status & Priority Column (desktop) ─────────────────────────────────────
  Widget _buildStatusPriorityColumn() {
    return Column(
      children: [
        _buildDropdown(
          label:    'Status',
          value:    _status,
          items:    _statusOptions,
          icon:     Icons.circle_rounded,
          color:    _statusColor(_status),
          onChanged: (v) => setState(() => _status = v!),
        ),
        SizedBox(height: _responsiveSpacing()),
        _buildDropdown(
          label:    'Priority',
          value:    _priority,
          items:    _priorityOptions,
          icon:     Icons.flag_rounded,
          color:    _priorityColor(_priority),
          onChanged: (v) => setState(() => _priority = v!),
        ),
        SizedBox(height: _responsiveSpacing()),
        // ✅ NEW — Task Type dropdown
        _buildDropdown(
          label:    'Task Type',
          value:    _taskType,
          items:    _taskTypeOptions,
          icon:     Icons.category_rounded,
          color:    AppColors.primary,
          onChanged: (v) => setState(() => _taskType = v!),
        ),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.cyan, AppColors.cyanBright, AppColors.greenTeal],
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -50, right: -30,
              child: _decorCircle(180, AppColors.greenTeal, 0.12)),
          Positioned(bottom: -40, left: -20,
              child: _decorCircle(130, Colors.white, 0.10)),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                _responsivePadding(),
                12,
                _responsivePadding(),
                _responsiveSpacing() + 4,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border:       Border.all(color: Colors.white.withOpacity(0.18)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  SizedBox(width: _responsiveSpacing()),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create Task',
                            style: TextStyle(
                              color:      Colors.white,
                              fontSize:   _responsiveFontSize(18),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            )),
                        Text('Assign a new task to an employee',
                            style: TextStyle(
                              color:      const Color(0xAAFFFFFF),
                              fontSize:   _responsiveFontSize(11),
                              fontWeight: FontWeight.w400,
                            )),
                      ],
                    ),
                  ),
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: const Icon(Icons.add_task_rounded,
                        color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Text field ─────────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String                label,
    required String                hint,
    required IconData              icon,
    required Color                 iconColor,
    int                            maxLines  = 1,
    bool                           readOnly  = false,
    String? Function(String?)?     validator,
    TextInputType                  keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller:   controller,
        maxLines:     maxLines,
        readOnly:     readOnly,
        keyboardType: keyboardType,
        validator:    validator,
        style: TextStyle(
          color:      AppColors.textPrimary,
          fontSize:   _responsiveFontSize(13),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText:  hint,
          labelStyle: TextStyle(
            color:    iconColor,
            fontSize: _responsiveFontSize(12),
            fontWeight: FontWeight.w600,
          ),
          hintStyle: TextStyle(
            color:    AppColors.textSecondary,
            fontSize: _responsiveFontSize(12),
          ),
          prefixIcon: Icon(icon, color: iconColor, size: 20),
          suffixIcon: readOnly
              ? Icon(Icons.lock_outline_rounded,
              color: AppColors.textSecondary.withOpacity(0.4), size: 16)
              : null,
          filled:      readOnly,
          fillColor:   readOnly
              ? AppColors.surface.withOpacity(0.6)
              : Colors.transparent,
          border:         InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
              horizontal: _responsivePadding(), vertical: _responsiveSpacing()),
          errorStyle: TextStyle(fontSize: _responsiveFontSize(10)),
        ),
      ),
    );
  }

  // ── Dropdown ────────────────────────────────────────────────────────────────
  Widget _buildDropdown({
    required String         label,
    required String         value,
    required List<String>   items,
    required IconData       icon,
    required Color          color,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: _responsivePadding() * 0.75, vertical: 4),
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset:     const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              label,
              style: TextStyle(
                color:      color,
                fontSize:   _responsiveFontSize(10),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value:         value,
              isExpanded:    true,
              icon:          Icon(Icons.keyboard_arrow_down_rounded,
                  color: color, size: 18),
              style: TextStyle(
                color:      AppColors.textPrimary,
                fontSize:   _responsiveFontSize(13),
                fontWeight: FontWeight.w600,
              ),
              onChanged:     onChanged,
              items: items.map((item) {
                return DropdownMenuItem(
                  value: item,
                  child: Row(
                    children: [
                      Icon(icon, size: 13,
                          color: item == value ? color : AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(item),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Date picker tile ────────────────────────────────────────────────────────
  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: _responsivePadding(),
            vertical: _responsiveSpacing()),
        decoration: BoxDecoration(
          color:        AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(
            color: _dueDate != null ? AppColors.greenTeal : AppColors.divider,
          ),
          boxShadow: [
            BoxShadow(
              color:      Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset:     const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                color: _dueDate != null ? AppColors.greenTeal : AppColors.textSecondary,
                size: 20),
            SizedBox(width: _responsiveSpacing()),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Due Date',
                    style: TextStyle(
                      color:      _dueDate != null
                          ? AppColors.greenTeal
                          : AppColors.textSecondary,
                      fontSize:   _responsiveFontSize(10),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _dueDate == null
                        ? 'Tap to select due date'
                        : DateFormat('dd MMM yyyy').format(_dueDate!),
                    style: TextStyle(
                      color:      _dueDate == null
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontSize:   _responsiveFontSize(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textSecondary, size: 14),
          ],
        ),
      ),
    );
  }

  // ── Submit button ───────────────────────────────────────────────────────────
  Widget _buildSubmitButton() {
    return Obx(() => GestureDetector(
      onTap: _vm.isSubmitting.value ? null : _submit,
      child: Container(
        width:  double.infinity,
        height: _isMobile ? 48 : 54,
        decoration: BoxDecoration(
          gradient: _vm.isSubmitting.value
              ? LinearGradient(colors: [
            AppColors.cyan.withOpacity(0.5),
            AppColors.greenTeal.withOpacity(0.5),
          ])
              : const LinearGradient(
            colors: [AppColors.cyan, AppColors.greenTeal],
            begin:  Alignment.centerLeft,
            end:    Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:      AppColors.cyan.withOpacity(0.35),
              blurRadius: 14,
              offset:     const Offset(0, 5),
            ),
          ],
        ),
        child: Center(
          child: _vm.isSubmitting.value
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
              SizedBox(width: _responsiveSpacing()),
              Text('Submitting...',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   _responsiveFontSize(15),
                    fontWeight: FontWeight.w700,
                  )),
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_upload_rounded,
                  color: Colors.white, size: 20),
              SizedBox(width: _responsiveSpacing()),
              Text('Submit Task',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   _responsiveFontSize(15),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  )),
            ],
          ),
        ),
      ),
    ));
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
              gradient:     AppColors.brandGradient,
              borderRadius: BorderRadius.circular(2))),
      SizedBox(width: _responsiveSpacing() * 0.5),
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
            color:        color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 15, color: color),
      ),
      SizedBox(width: _responsiveSpacing() * 0.5),
      Expanded(
        child: Text(title,
            style: TextStyle(
                color:      AppColors.primary,
                fontSize:   _responsiveFontSize(13),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      ),
    ]);
  }

  Widget _decorCircle(double size, Color color, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withOpacity(opacity),
    ),
  );

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'done':        return AppColors.greenTeal;
      case 'in progress': return AppColors.cyan;
      case 'cancel':      return AppColors.error;
      default:            return AppColors.warning; // open
    }
  }

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':   return const Color(0xFFEF4444);
      case 'medium': return AppColors.warning;
      default:       return AppColors.greenTeal;
    }
  }
}