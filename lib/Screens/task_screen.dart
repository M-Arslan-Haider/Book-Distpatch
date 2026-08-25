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
import 'task_chat_screen.dart';

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
    if (uiStatus == 'Cancel') {
      return 'Cancelled';
    }
    return uiStatus; // Open, In Progress remain same
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
    final vm = Get.find<TaskViewModel>();
    return Obx(() {
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
            // ── Assigned Tasks Tab ──
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
                        'Assigned',
                        style: TextStyle(
                          color: _activeTab == _TaskTab.assigned
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      // ── Live count badge ──
                      if (vm.assignedTasks.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _activeTab == _TaskTab.assigned
                                ? Colors.white.withOpacity(0.25)
                                : AppColors.cyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${vm.assignedTasks.length}',
                            style: TextStyle(
                              color: _activeTab == _TaskTab.assigned
                                  ? Colors.white
                                  : AppColors.cyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            // ── My Tasks Tab ──
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
            // ── Create Tab ──
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
    });
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
  // ====================== PROFESSIONAL UPDATE SHEET (DASHBOARD STYLE) ======================
  void _showUpdateSheet(TaskModel task) {
    debugPrint('🔍 UpdateSheet - ID: ${task.id}, Title: ${task.taskTitle}');

    // Check if task is already completed or cancelled
    final isCompletedOrCancelled = task.status == 'Done' || task.status == 'Cancel' || task.status == 'Cancelled' || task.status.toLowerCase() == 'completed';

    if (isCompletedOrCancelled) {
      Get.showSnackbar(const GetSnackBar(
        message: 'This task is already completed or cancelled.',
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.warning,
        borderRadius: 10,
        margin: EdgeInsets.all(12),
        icon: Icon(Icons.warning_amber_rounded, color: Colors.white),
      ));
      return;
    }

    // Data Mapping
    String displayStatus = task.status;
    if (displayStatus == 'Done') displayStatus = 'Completed';

    String selectedStatus = displayStatus;
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
    final vm = Get.find<TaskViewModel>();
    final statusOptions = ['Open', 'In Progress', 'Completed', 'Cancel'];

    Get.bottomSheet(
      StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface, // Clean background
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          // Fixed height for dashboard-like layout
          height: MediaQuery.of(sheetCtx).size.height * 0.92,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Clean Drag Handle ---
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 2),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // --- Minimalist Header ---
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Update Task',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            task.taskTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '#${task.id}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.divider),

              // --- Professional Dashboard Body ---
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 16,
                    bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ================= STATUS SECTION =================
                      _buildProfLabel('Status'),
                      const SizedBox(height: 12),
                      Row(
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
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: GestureDetector(
                                onTap: () => setSheetState(() => selectedStatus = s),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: selected ? color : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected ? color : AppColors.divider,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        s == 'Open' ? Icons.hourglass_empty_rounded
                                            : s == 'In Progress' ? Icons.autorenew_rounded
                                            : s == 'Completed' ? Icons.check_circle_rounded
                                            : Icons.cancel_rounded,
                                        size: 18,
                                        color: selected ? Colors.white : color,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        s,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: selected ? Colors.white : color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // ================= PRIORITY SECTION =================
                      _buildProfLabel('Priority'),
                      const SizedBox(height: 12),
                      Row(
                        children: ['Low', 'Medium', 'High'].map((p) {
                          final selected = selectedPriority == p;
                          final color = p == 'High'
                              ? AppColors.error
                              : p == 'Medium'
                              ? AppColors.warning
                              : AppColors.greenTeal;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: GestureDetector(
                                onTap: () => setSheetState(() => selectedPriority = p),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: selected ? color.withOpacity(0.08) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected ? color : AppColors.divider,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        p == 'High' ? Icons.flag_rounded
                                            : p == 'Medium' ? Icons.flag_outlined
                                            : Icons.flag_outlined,
                                        size: 18,
                                        color: selected ? color : AppColors.textSecondary,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        p,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: selected ? color : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // ================= DUE DATE SECTION =================
                      _buildProfLabel('Due Date'),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: sheetCtx,
                            initialDate: selectedDueDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (context, child) => Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppColors.primary,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) setSheetState(() => selectedDueDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedDueDate == null
                                    ? 'Set due date'
                                    : DateFormat('dd MMM yyyy').format(selectedDueDate!),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: selectedDueDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                                ),
                              ),
                              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ================= COMMENTS SECTION =================
                      _buildProfLabel('Comments'),
                      const SizedBox(height: 12),
                      TextField(
                        controller: commentsController,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Add notes...',
                          hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.6)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ================= ACTION BUTTONS (Fully Professional) =================
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Get.back(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                foregroundColor: AppColors.textSecondary,
                                backgroundColor: Colors.transparent,
                                side: const BorderSide(color: AppColors.divider),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Obx(() => ElevatedButton(
                              onPressed: vm.isUpdating.value ? null : () async {
                                String? dueDateStr;
                                if (selectedDueDate != null) {
                                  dueDateStr = DateFormat('yyyy-MM-dd').format(selectedDueDate!);
                                }
                                final backendStatus = _getBackendStatus(selectedStatus);
                                final ok = await vm.updateTask(
                                  taskId: task.id,
                                  status: backendStatus,
                                  comments: commentsController.text.trim(),
                                  priority: selectedPriority,
                                  dueDate: dueDateStr,
                                  category: selectedCategory,
                                  isAssigned: true,
                                );
                                if (ok) {
                                  _updatedIds.add(task.id);
                                  Get.back();
                                  Get.showSnackbar(const GetSnackBar(
                                    message: 'Task updated successfully!',
                                    duration: Duration(seconds: 2),
                                    backgroundColor: AppColors.greenTeal,
                                    icon: Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                                    borderRadius: 10,
                                    margin: EdgeInsets.all(12),
                                  ));
                                } else {
                                  Get.showSnackbar(GetSnackBar(
                                    message: vm.errorMessage.value.isNotEmpty ? vm.errorMessage.value : 'Update failed.',
                                    duration: const Duration(seconds: 3),
                                    backgroundColor: AppColors.error,
                                    icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
                                    borderRadius: 10,
                                    margin: const EdgeInsets.all(12),
                                  ));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: vm.isUpdating.value
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save_rounded, size: 18),
                                  SizedBox(width: 8),
                                  Text('Save', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                ],
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

  // ====================== PROFESSIONAL SECTION LABEL ======================
  Widget _buildProfLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary.withOpacity(0.9),
          letterSpacing: 0.5,
        ),
      ),
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
// _TaskCard  —  Redesigned: description + left accent bar + clean layout
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
    final bool isCancelled = task.status == 'Cancel' || task.status == 'Cancelled';

    Color statusColor;
    IconData statusIcon;
    String displayStatus = task.status;

    if (isCompleted) {
      statusColor = AppColors.greenTeal;
      statusIcon = Icons.check_circle_rounded;
      displayStatus = 'Completed';
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

    if (displayStatus == 'Done') displayStatus = 'Completed';

    Color priorityColor = AppColors.textSecondary;
    if (task.priority == 'High') priorityColor = AppColors.error;
    if (task.priority == 'Medium') priorityColor = AppColors.warning;
    if (task.priority == 'Low') priorityColor = AppColors.greenTeal;

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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Left status accent bar ─────────────────────────────────
              Container(
                width: 4,
                decoration: BoxDecoration(color: statusColor),
              ),

              // ── Card content ───────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Header: badges + due date ──────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.06),
                      ),
                      child: Row(
                        children: [
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.13),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon,
                                    size: 11, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  displayStatus,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Priority badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
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
                                Text(
                                  task.priority,
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: priorityColor),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Due date (right side of header)
                          if (task.dueDate.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_rounded,
                                    size: 11,
                                    color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  task.dueDate,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    // ── Body ───────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // ── Title + Task ID badge ──────────────────
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  task.taskTitle,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                  AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: AppColors.primary
                                          .withOpacity(0.18)),
                                ),
                                child: Text(
                                  '#${task.id}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary
                                        .withOpacity(0.70),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ── Task Description (auto-height) ─────────
                          if (task.taskDescription.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color:
                                    AppColors.divider.withOpacity(0.7)),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    size: 13,
                                    color: AppColors.textSecondary
                                        .withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      task.taskDescription,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                        height: 1.5,
                                      ),
                                      // No maxLines — auto-adjusts to full description
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 10),

                          // ── Meta chips: employee + task type ───────
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _MetaChip(
                                  icon: Icons.person,
                                  label: task.empName,
                                  color: AppColors.skyBlueDk),
                              _MetaChip(
                                  icon: Icons.category_rounded,
                                  label: task.taskType,
                                  color: AppColors.primary),
                            ],
                          ),

                          // ── Comments (if present) ─────────────────
                          if (task.comments.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.cyan.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color:
                                    AppColors.cyan.withOpacity(0.15)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.comment_outlined,
                                      size: 12, color: AppColors.cyan),
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

                          const SizedBox(height: 12),

                          // ── Bottom row: assigned by + action buttons ──
                          Row(
                            children: [
                              Icon(Icons.person_outline_rounded,
                                  size: 12,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'By: ${task.assignedBy}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                              // ── Messages Button ──
                              if (!isCompleted && !isCancelled) ...[
                                GestureDetector(
                                  onTap: () {
                                    Get.to(
                                          () => TaskChatScreen(task: task),
                                      transition:
                                      Transition.rightToLeft,
                                      duration: const Duration(
                                          milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 11, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withOpacity(0.08),
                                      borderRadius:
                                      BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AppColors.primary
                                              .withOpacity(0.18)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.message_rounded,
                                            size: 13,
                                            color: AppColors.primary),
                                        SizedBox(width: 4),
                                        Text(
                                          'Chat',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // ── Update button ──
                                GestureDetector(
                                  onTap: onUpdate,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      gradient: isUpdated
                                          ? null
                                          : const LinearGradient(
                                        colors: [
                                          AppColors.primary,
                                          AppColors.cyan
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      color: isUpdated
                                          ? AppColors.greenTeal
                                          : null,
                                      borderRadius:
                                      BorderRadius.circular(8),
                                      boxShadow: isUpdated
                                          ? []
                                          : [
                                        BoxShadow(
                                            color: AppColors.cyan
                                                .withOpacity(0.30),
                                            blurRadius: 8,
                                            offset:
                                            const Offset(0, 3)),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isUpdated
                                              ? Icons
                                              .check_circle_rounded
                                              : Icons.edit_rounded,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isUpdated
                                              ? 'Updated'
                                              : 'Update',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
