// ════════════════════════════════════════════════════════════════════════════
//  lib/Screens/assigned_task_screen.dart   ← FINAL FIXED (NO OVERFLOW)
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

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
              SizedBox(height: 10,),
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
        itemBuilder: (_, i) => _TaskCard(task: tasks[i]),
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TASK CARD
// ════════════════════════════════════════════════════════════════════════════

class _TaskCard extends StatefulWidget {
  final TaskModel task;
  const _TaskCard({required this.task});

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.taskTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, // ✅ FIX
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: task.status),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              'Assigned by: ${task.assignedBy}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // ✅ FIX
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),

            const SizedBox(height: 10),

            // ✅ WRAP FIX
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
                _MetaChip(
                  icon: Icons.flag,
                  label: task.priority,
                  color: AppColors.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── SMALL WIDGETS ───────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 10),
      ),
    );
  }
}

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
            overflow: TextOverflow.ellipsis, // ✅ FIX
            style: TextStyle(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}