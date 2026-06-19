import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../AppColors.dart';
import '../ViewModels/task_view_model.dart';
import '../Models/task_model.dart';
import 'AssignedTasksScreen.dart'; // sirf _showUpdateSheet aur _TaskCard ke liye import rakha
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

    // fetch data on open
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
      // ... rest of the build method remains the same

// class _TaskScreenState extends State<TaskScreen>
//     with SingleTickerProviderStateMixin {
//   late final AnimationController _fadeController;
//   late final Animation<double> _fadeAnimation;
//
//   final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//
//   _TaskTab _activeTab = _TaskTab.assigned;
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
//     if (!Get.isRegistered<TaskViewModel>()) {
//       Get.put(TaskViewModel());
//     }
//
//     // fetch data on open
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final vm = Get.find<TaskViewModel>();
//       vm.fetchAssignedTasks();
//       // agar MyTasks ke liye alag fetch ho to yahan call karein
//       // vm.fetchMyTasks();
//     });
//   }
//
//   @override
//   void dispose() {
//     _fadeController.dispose();
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
//       key: _scaffoldKey,
//       backgroundColor: AppColors.surface,
//       appBar: Navbar(
//         userName: 'Mian Muhammad Arslan',
//         userInitials: 'MM',
//         lastSync: 'Just now',
//         scaffoldKey: _scaffoldKey,
//       ),
      body: Column(
        children: [
          // ── Top section (header + tabs + filter) ──
          FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section title
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

                  // Tab row
                  _buildTabRow(),
                  const SizedBox(height: 14),

                  // Filter chips (only for assigned tab)
                  if (_activeTab == _TaskTab.assigned) _buildFilterChips(),
                  if (_activeTab == _TaskTab.assigned)
                    const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // ── Scrollable task list ──
          Expanded(child: _buildTaskList()),

          // ── Bottom Nav ──
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
          // Assigned Tasks
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

          // My Tasks
          Expanded(
            flex: 4,
            child: GestureDetector(
              onTap: () {
                setState(() => _activeTab = _TaskTab.myTasks);
                // vm.fetchMyTasks(); // agar alag API ho
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

          // + Create
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
      return SizedBox(
        height: 35,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: vm.filterOptions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final opt = vm.filterOptions[i];
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
          itemBuilder: (_, i) => _TaskCard(
            task: tasks[i],
            onUpdate: () => _showUpdateSheet(tasks[i]),
          ),
        );
      });
    }

    // ── My Tasks tab ──
    // Agar alag ViewModel/list hai to Obx se bind karein.
    // Abhi placeholder dikh raha hai — apni list yahan lagaein.
    return Obx(() {
      if (vm.isLoadingAssigned.value) {
        return const Center(
            child: CircularProgressIndicator(color: AppColors.cyan));
      }
      // Replace vm.filteredAssigned with vm.filteredMyTasks when available
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
        itemBuilder: (_, i) => _TaskCard(
          task: tasks[i],
          onUpdate: () => _showUpdateSheet(tasks[i]),
        ),
      );
    });
  }

  // ====================== UPDATE SHEET ======================
  // AssignedTasksScreen se same sheet — yahan delegate karte hain
  void _showUpdateSheet(TaskModel task) {
    // AssignedTasksScreen ko temporarily push karke sheet open karo
    // Ya phir same sheet logic copy karein. Seedha AssignedTasksScreen
    // ka static method call karna behtar hai — lekin Flutter mein
    // instance method hoti hai isliye ek helper widget banate hain.
    _UpdateSheetHelper.show(context, task, Get.find<TaskViewModel>());
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
// _TaskCard — same as in AssignedTasksScreen (copied here for inline use)
// ══════════════════════════════════════════════════════════════════════════
class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onUpdate;

  const _TaskCard({required this.task, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = task.status == 'Completed';

    Color statusColor;
    IconData statusIcon;

    if (task.status == 'Completed') {
      statusColor = AppColors.greenTeal;
      statusIcon = Icons.check_circle_rounded;
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
          // Status bar
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
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

          // Card body
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

// ══════════════════════════════════════════════════════════════════════════
// Update sheet helper — delegates to AssignedTasksScreen's sheet logic
// ══════════════════════════════════════════════════════════════════════════
class _UpdateSheetHelper {
  static void show(
      BuildContext context, TaskModel task, TaskViewModel vm) {
    // AssignedTasksScreen ka _showUpdateSheet same hai —
    // Temporarily AssignedTasksScreen navigate karke sheet open karo
    // Ya directly yahan sheet duplicate karein. Seedha VM method call:
    // vm.showUpdateBottomSheet(task) — agar VM mein method ho.
    //
    // Agar AssignedTasksScreen mein _showUpdateSheet public nahi hai
    // to yahan same sheet code paste karein ya VM mein move karein.
    //
    // Quick solution: navigate to AssignedTasksScreen with task pre-selected
    Get.to(
          () => const AssignedTasksScreen(),
      transition: Transition.downToUp,
      duration: const Duration(milliseconds: 280),
    );
  }
}