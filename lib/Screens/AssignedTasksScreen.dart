
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../AppColors.dart';
import '../ViewModels/task_view_model.dart';
import '../Models/task_model.dart';

class AssignedTasksScreen extends StatefulWidget {
  const AssignedTasksScreen({super.key});

  @override
  State<AssignedTasksScreen> createState() => _AssignedTasksScreenState();
}

class _AssignedTasksScreenState extends State<AssignedTasksScreen>
    with SingleTickerProviderStateMixin {

  final TaskViewModel _vm = Get.find<TaskViewModel>();

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _vm.fetchAssignedTasks();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
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
        opacity: _fadeAnim,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 10),
              _buildFilterChips(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
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
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned Tasks',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Tasks assigned to you',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xAAFFFFFF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              Obx(() => GestureDetector(
                onTap: _vm.fetchAssignedTasks,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _vm.isLoadingAssigned.value
                      ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded,
                      color: Colors.white),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ── FILTER ────────────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return Obx(() {
      final current = _vm.assignedFilter.value;

      return SizedBox(
        height: 35,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _vm.filterOptions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final opt = _vm.filterOptions[i];
            final selected = current == opt;

            return GestureDetector(
              onTap: () => _vm.assignedFilter.value = opt,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.cyan : AppColors.cardBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  opt,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }

  // ── BODY ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    return Obx(() {
      if (_vm.isLoadingAssigned.value) {
        return const Center(
            child: CircularProgressIndicator(color: AppColors.cyan));
      }

      final tasks = _vm.filteredAssigned;

      if (tasks.isEmpty) {
        return const Center(child: Text('No tasks'));
      }

      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _TaskCard(
          task: tasks[i],
          onUpdate: () => _showUpdateSheet(tasks[i]),
        ),
      );
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  Update Bottom Sheet  (same logic as MyTasksActivityScreen)
  // ══════════════════════════════════════════════════════════════════════════
  void _showUpdateSheet(TaskModel task) {
    debugPrint('🔍 AssignedTask - ID: ${task.id}, Title: ${task.taskTitle}');

    String selectedStatus   = task.status;
    String selectedPriority = task.priority.isNotEmpty ? task.priority : 'Medium';
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
              // ── Drag handle ──
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── Gradient header ──
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

              // ── Form content ──
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

                      // Task ID preview
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
                          children: ['Pending', 'In Progress', 'Completed'].map((s) {
                            final selected = selectedStatus == s;
                            final color = s == 'Pending'
                                ? AppColors.warning
                                : s == 'In Progress'
                                ? AppColors.skyBlueDk
                                : AppColors.greenTeal;
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
                                        s == 'Pending'
                                            ? Icons.hourglass_empty_rounded
                                            : s == 'In Progress'
                                            ? Icons.autorenew_rounded
                                            : Icons.check_circle_rounded,
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
                          children: ['Low', 'Medium', 'High'].map((p) {
                            final selected = selectedPriority == p;
                            final color = p == 'High'
                                ? AppColors.error
                                : p == 'Medium'
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
                          // Cancel
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
                          // Save
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

                                final ok = await _vm.updateTask(
                                  taskId: task.id,
                                  status: selectedStatus,
                                  comments:
                                  commentsController.text.trim(),
                                  priority: selectedPriority,
                                  dueDate: dueDateStr,
                                  category: selectedCategory,
                                  isAssigned: true,
                                );

                                if (ok) {
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
                                    message: _vm.errorMessage.value
                                        .isNotEmpty
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
                                      color: AppColors.cyan
                                          .withOpacity(0.3),
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

  // ── Section header helper (matches MyTasksActivityScreen style) ───────────
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
}

// ════════════════════════════════════════════════════════════════════════════
// TASK CARD  — now accepts an onUpdate callback
// ════════════════════════════════════════════════════════════════════════════

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onUpdate;

  const _TaskCard({required this.task, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == 'Completed';

    Color statusColor;
    IconData statusIcon;
    if (isCompleted) {
      statusColor = AppColors.greenTeal;
      statusIcon  = Icons.check_circle_rounded;
    } else if (task.status == 'In Progress') {
      statusColor = AppColors.skyBlueDk;
      statusIcon  = Icons.autorenew_rounded;
    } else {
      statusColor = AppColors.warning;
      statusIcon  = Icons.hourglass_empty_rounded;
    }

    Color priorityColor = AppColors.textSecondary;
    if (task.priority == 'High')   priorityColor = AppColors.error;
    if (task.priority == 'Medium') priorityColor = AppColors.warning;
    if (task.priority == 'Low')    priorityColor = AppColors.greenTeal;

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

          // ── Status bar ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Status badge
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusColor),
                      const SizedBox(width: 4),
                      Text(task.status,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Priority badge
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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

          // ── Card body ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Title
                Text(
                  task.taskTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),

                // Assigned by
                Text(
                  'Assigned by: ${task.assignedBy}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),

                const SizedBox(height: 10),

                // Meta chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MetaChip(
                      icon: Icons.person,
                      label: task.empName,
                      color: AppColors.skyBlueDk,
                    ),
                    _MetaChip(
                      icon: Icons.calendar_today,
                      label: task.dueDate,
                      color: AppColors.greenTeal,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Bottom row: emp name + Update button
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.empName,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // ── Update button — hidden when already Completed ──
                    if (!isCompleted)
                      GestureDetector(
                        onTap: onUpdate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.cyan.withOpacity(0.30),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3)),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded,
                                  size: 13, color: Colors.white),
                              SizedBox(width: 5),
                              Text('Update',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
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

// ── Small chip widget ─────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

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
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 10),
          ),
        ],
      ),
    );
  }
}