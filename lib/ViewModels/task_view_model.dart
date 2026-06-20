// import 'dart:async';
//
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/services.dart';          // ← MethodChannel
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import '../Database/db_helper.dart';
// import '../Models/task_model.dart';
// import '../Repositories/task_repository.dart';
//
// class TaskViewModel extends GetxController {
//
//   final TaskRepository _repository;
//   TaskViewModel({TaskRepository? repository})
//       : _repository = repository ?? TaskRepository();
//
//   // ── MethodChannel — talks to TaskNotificationService.kt ──────────────────
//   static const _notifChannel = MethodChannel('task_notifications');
//
//   // ── Observable lists ──────────────────────────────────────────────────────
//   final RxList<TaskModel> assignedTasks = <TaskModel>[].obs;
//   final RxList<TaskModel> createdTasks  = <TaskModel>[].obs;
//
//   // ── Loading flags ─────────────────────────────────────────────────────────
//   final RxBool isLoadingAssigned = false.obs;
//   final RxBool isLoadingCreated  = false.obs;
//   final RxBool isUpdating        = false.obs;
//   final RxBool isSubmitting      = false.obs;
//
//   // ── Messages ──────────────────────────────────────────────────────────────
//   final RxString errorMessage   = ''.obs;
//   final RxString successMessage = ''.obs;
//
//   // ── Filter (used by Activity screen) ─────────────────────────────────────
//   final RxString     assignedFilter = 'All'.obs;
//   final RxString     createdFilter  = 'All'.obs;
//   final List<String> filterOptions  = ['All', 'Pending', 'In Progress', 'Completed'];
//
//   // ── Polling ───────────────────────────────────────────────────────────────
//   Timer?    _pollingTimer;
//   Set<int>? _knownAssignedIds;   // null = first fetch not done yet
//
//   // ── Computed filtered lists ───────────────────────────────────────────────
//   List<TaskModel> get filteredAssigned {
//     if (assignedFilter.value == 'All') return assignedTasks.toList();
//     return assignedTasks
//         .where((t) => t.status == assignedFilter.value)
//         .toList();
//   }
//
//   List<TaskModel> get filteredCreated {
//     if (createdFilter.value == 'All') return createdTasks.toList();
//     return createdTasks
//         .where((t) => t.status == createdFilter.value)
//         .toList();
//   }
//
//   // ── Stats ─────────────────────────────────────────────────────────────────
//   int get totalAssigned    => assignedTasks.length;
//   int get totalCreated     => createdTasks.length;
//   int get pendingAssigned  => assignedTasks.where((t) => t.status == 'Pending').length;
//   int get doneAssigned     => assignedTasks.where((t) => t.status == 'Completed').length;
//   int get pendingCreated   => createdTasks.where((t) => t.status == 'Pending').length;
//   int get doneCreated      => createdTasks.where((t) => t.status == 'Completed').length;
//
//   // ──────────────────────────────────────────────────────────────────────────
//   //  Lifecycle
//   // ──────────────────────────────────────────────────────────────────────────
//   @override
//   void onInit() {
//     super.onInit();
//     _startPolling();
//   }
//
//   @override
//   void onClose() {
//     _stopPolling();
//     super.onClose();
//   }
//
//   // ──────────────────────────────────────────────────────────────────────────
//   //  Polling — every 5 seconds silently check for new assigned tasks
//   // ──────────────────────────────────────────────────────────────────────────
//   void _startPolling() {
//     _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
//       _pollAssignedTasks();
//     });
//   }
//
//   void _stopPolling() {
//     _pollingTimer?.cancel();
//     _pollingTimer = null;
//   }
//
//   /// Silent fetch — does NOT touch loading flags or error/success messages.
//   Future<void> _pollAssignedTasks() async {
//     final result = await _repository.getAssignedTasks();
//     if (!result.isSuccess || result.data == null) return;
//
//     final freshTasks = result.data!;
//
//     // ── First-time snapshot: just record what exists, no notification ────
//     if (_knownAssignedIds == null) {
//       _knownAssignedIds = freshTasks.map((t) => t.id).toSet();
//       if (assignedTasks.isEmpty) assignedTasks.value = freshTasks;
//       return;
//     }
//
//     // ── Detect brand-new tasks ────────────────────────────────────────────
//     final newTasks = freshTasks
//         .where((t) => !_knownAssignedIds!.contains(t.id))
//         .toList();
//
//     if (newTasks.isNotEmpty) {
//       assignedTasks.value  = freshTasks;
//       _knownAssignedIds    = freshTasks.map((t) => t.id).toSet();
//
//       // Fire a proper Android notification for each new task
//       for (final task in newTasks) {
//         await _showNativeNotification(task);
//       }
//     }
//   }
//
//   /// Calls TaskNotificationService.kt via MethodChannel.
//   Future<void> _showNativeNotification(TaskModel task) async {
//     try {
//       await _notifChannel.invokeMethod('showTaskNotification', {
//         'taskTitle':  task.taskTitle,
//         'taskDesc':   task.taskDescription ?? '',
//         'assignedBy': task.assignedBy      ?? '',
//       });
//       debugPrint('🔔 [ViewModel] Native notification sent for: ${task.taskTitle}');
//     } catch (e) {
//       debugPrint('❌ [ViewModel] MethodChannel error: $e');
//     }
//   }
//
//   // ──────────────────────────────────────────────────────────────────────────
//   //  Fetch both lists in parallel (for Activity screen)
//   // ──────────────────────────────────────────────────────────────────────────
//   Future<void> fetchAllTasks() async {
//     await Future.wait([fetchAssignedTasks(), fetchCreatedTasks()]);
//   }
//
//   // ──────────────────────────────────────────────────────────────────────────
//   //  GET assigned tasks
//   // ──────────────────────────────────────────────────────────────────────────
//   Future<void> fetchAssignedTasks() async {
//     _resetMessages();
//     isLoadingAssigned.value = true;
//
//     final result = await _repository.getAssignedTasks();
//
//     if (result.isSuccess) {
//       assignedTasks.value = result.data ?? [];
//       // Keep known-IDs in sync with manual fetches too
//       _knownAssignedIds = assignedTasks.map((t) => t.id).toSet();
//     } else {
//       errorMessage.value = result.errorMessage;
//     }
//     isLoadingAssigned.value = false;
//   }
//
//   // ──────────────────────────────────────────────────────────────────────────
//   //  GET created tasks
//   // ──────────────────────────────────────────────────────────────────────────
//   Future<void> fetchCreatedTasks() async {
//     _resetMessages();
//     isLoadingCreated.value = true;
//
//     final result = await _repository.getCreatedTasks();
//
//     if (result.isSuccess) {
//       createdTasks.value = result.data ?? [];
//     } else {
//       errorMessage.value = result.errorMessage;
//     }
//     isLoadingCreated.value = false;
//   }
//
//   // ──────────────────────────────────────────────────────────────────────────
//   //  PUT — update task: status + comments + priority + due_date + category ✅
//   // ──────────────────────────────────────────────────────────────────────────
//   Future<bool> updateTask({
//     required int    taskId,
//     required String status,
//     required String comments,
//     required String priority,
//     String? dueDate,
//     String? category,      // ✅ Replaces remarks
//     required bool   isAssigned,
//   }) async {
//     _resetMessages();
//     isUpdating.value = true;
//
//     debugPrint('📝 [ViewModel] Updating task ID: $taskId');
//
//     final prefs   = await SharedPreferences.getInstance();
//     final empId   = int.tryParse(prefs.getString('userId') ?? '') ?? 0;
//
//     final request = UpdateTaskRequest(
//       taskId:       taskId,
//       empId:        empId, // ✅ naye proc ke :emp_id bind var ke liye
//       status:       status,
//       comments:     comments,
//       priority:     priority,
//       dueDate:      dueDate,
//       category:     category, // ✅
//       company_code: DBHelper.getCompanyCode(),
//     );
//
//     final result = await _repository.updateTask(request);
//     isUpdating.value = false;
//
//     if (result.isSuccess) {
//       successMessage.value = 'Task updated successfully!';
//       _updateLocalList(
//         taskId:     taskId,
//         status:     status,
//         comments:   comments,
//         priority:   priority,
//         dueDate:    dueDate,
//         category:   category, // ✅
//         isAssigned: isAssigned,
//       );
//       return true;
//     } else {
//       errorMessage.value = result.errorMessage;
//       return false;
//     }
//   }
//
//   // ── Update list locally so UI refreshes without a full re-fetch ───────────
//   void _updateLocalList({
//     required int    taskId,
//     required String status,
//     required String comments,
//     required String priority,
//     String? dueDate,
//     String? category, // ✅
//     required bool   isAssigned,
//   }) {
//     final list = isAssigned ? assignedTasks : createdTasks;
//     final idx  = list.indexWhere((t) => t.id == taskId);
//     if (idx != -1) {
//       list[idx] = list[idx].copyWith(
//         status:   status,
//         comments: comments,
//         priority: priority,
//         dueDate:  dueDate   ?? list[idx].dueDate,
//         category: category  ?? list[idx].category, // ✅
//       );
//       if (isAssigned) {
//         assignedTasks.refresh();
//       } else {
//         createdTasks.refresh();
//       }
//     }
//   }
//
//   // ──────────────────────────────────────────────────────────────────────────
//   //  POST create task
//   // ──────────────────────────────────────────────────────────────────────────
//   Future<bool> createTask({
//     required int    empId,
//     required String empName,
//     required String taskTitle,
//     required String taskDescription,
//     required String status,
//     required String priority,
//     required String dueDate,
//     required String comments,
//     String taskType = 'SELF',
//   }) async {
//     _resetMessages();
//     isSubmitting.value = true;
//
//     final prefs      = await SharedPreferences.getInstance();
//     final assignedBy = prefs.getString('userName') ?? '';
//
//     final request = CreateTaskRequest(
//       empId:           empId,
//       empName:         empName,
//       taskTitle:       taskTitle,
//       taskDescription: taskDescription,
//       status:          status,
//       priority:        priority,
//       dueDate:         dueDate,
//       comments:        comments,
//       assignedBy:      assignedBy,
//       taskType:        taskType,
//       company_code:    DBHelper.getCompanyCode(),
//     );
//
//     final result = await _repository.createTask(request);
//     isSubmitting.value = false;
//
//     if (result.isSuccess) {
//       successMessage.value = 'Task created successfully!';
//       if (result.data != null) createdTasks.insert(0, result.data!);
//       return true;
//     } else {
//       errorMessage.value = result.errorMessage;
//       return false;
//     }
//   }
//
//   void _resetMessages() {
//     errorMessage.value   = '';
//     successMessage.value = '';
//   }
// }


import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Database/db_helper.dart';
import '../Models/task_model.dart';
import '../Repositories/task_repository.dart';

class TaskViewModel extends GetxController {

  final TaskRepository _repository;
  TaskViewModel({TaskRepository? repository})
      : _repository = repository ?? TaskRepository();

  // ── MethodChannel — talks to TaskNotificationService.kt ──────────────────
  static const _notifChannel = MethodChannel('task_notifications');

  // ── Observable lists ──────────────────────────────────────────────────────
  final RxList<TaskModel> assignedTasks = <TaskModel>[].obs;
  final RxList<TaskModel> createdTasks  = <TaskModel>[].obs;

  // ── Loading flags ─────────────────────────────────────────────────────────
  final RxBool isLoadingAssigned = false.obs;
  final RxBool isLoadingCreated  = false.obs;
  final RxBool isUpdating        = false.obs;
  final RxBool isSubmitting      = false.obs;

  // ── Messages ──────────────────────────────────────────────────────────────
  final RxString errorMessage   = ''.obs;
  final RxString successMessage = ''.obs;

  // ── Filter (used by Activity screen) ─────────────────────────────────────
  final RxString     assignedFilter = 'All'.obs;
  final RxString     createdFilter  = 'All'.obs;
  final List<String> filterOptions  = ['All', 'Open', 'In Progress', 'Completed', 'Cancelled'];

  // ── Polling ───────────────────────────────────────────────────────────────
  Timer?    _pollingTimer;
  Set<int>? _knownAssignedIds;

  // ── Computed filtered lists ───────────────────────────────────────────────
  List<TaskModel> get filteredAssigned {
    if (assignedFilter.value == 'All') return assignedTasks.toList();
    return assignedTasks
        .where((t) => t.status == assignedFilter.value)
        .toList();
  }

  List<TaskModel> get filteredCreated {
    if (createdFilter.value == 'All') return createdTasks.toList();
    return createdTasks
        .where((t) => t.status == createdFilter.value)
        .toList();
  }

  // ── Stats ─────────────────────────────────────────────────────────────────
  int get totalAssigned    => assignedTasks.length;
  int get totalCreated     => createdTasks.length;
  int get openAssigned     => assignedTasks.where((t) => t.status == 'Open').length;
  int get inProgressAssigned => assignedTasks.where((t) => t.status == 'In Progress').length;
  int get doneAssigned     => assignedTasks.where((t) => t.status == 'Done').length;
  int get cancelledAssigned => assignedTasks.where((t) => t.status == 'Cancelled').length;

  // ──────────────────────────────────────────────────────────────────────────
  //  Lifecycle
  // ──────────────────────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    _startPolling();
  }

  @override
  void onClose() {
    _stopPolling();
    super.onClose();
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Polling — every 5 seconds silently check for new assigned tasks
  // ──────────────────────────────────────────────────────────────────────────
  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollAssignedTasks();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Silent fetch — does NOT touch loading flags or error/success messages.
  Future<void> _pollAssignedTasks() async {
    final result = await _repository.getAssignedTasks();
    if (!result.isSuccess || result.data == null) return;

    final freshTasks = result.data!;

    if (_knownAssignedIds == null) {
      _knownAssignedIds = freshTasks.map((t) => t.id).toSet();
      if (assignedTasks.isEmpty) assignedTasks.value = freshTasks;
      return;
    }

    final newTasks = freshTasks
        .where((t) => !_knownAssignedIds!.contains(t.id))
        .toList();

    if (newTasks.isNotEmpty) {
      assignedTasks.value  = freshTasks;
      _knownAssignedIds    = freshTasks.map((t) => t.id).toSet();

      for (final task in newTasks) {
        await _showNativeNotification(task);
      }
    }
  }

  /// Calls TaskNotificationService.kt via MethodChannel.
  Future<void> _showNativeNotification(TaskModel task) async {
    try {
      await _notifChannel.invokeMethod('showTaskNotification', {
        'taskTitle':  task.taskTitle,
        'taskDesc':   task.taskDescription ?? '',
        'assignedBy': task.assignedBy      ?? '',
      });
      debugPrint('🔔 [ViewModel] Native notification sent for: ${task.taskTitle}');
    } catch (e) {
      debugPrint('❌ [ViewModel] MethodChannel error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Fetch both lists in parallel
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> fetchAllTasks() async {
    await Future.wait([fetchAssignedTasks(), fetchCreatedTasks()]);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  GET assigned tasks
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> fetchAssignedTasks() async {
    _resetMessages();
    isLoadingAssigned.value = true;

    final result = await _repository.getAssignedTasks();

    if (result.isSuccess) {
      assignedTasks.value = result.data ?? [];
      _knownAssignedIds = assignedTasks.map((t) => t.id).toSet();
    } else {
      errorMessage.value = result.errorMessage;
    }
    isLoadingAssigned.value = false;
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  GET created tasks
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> fetchCreatedTasks() async {
    _resetMessages();
    isLoadingCreated.value = true;

    final result = await _repository.getCreatedTasks();

    if (result.isSuccess) {
      createdTasks.value = result.data ?? [];
    } else {
      errorMessage.value = result.errorMessage;
    }
    isLoadingCreated.value = false;
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  PUT — update task
  // ──────────────────────────────────────────────────────────────────────────
  Future<bool> updateTask({
    required int    taskId,
    required String status,
    required String comments,
    required String priority,
    String? dueDate,
    String? category,
    required bool   isAssigned,
  }) async {
    _resetMessages();
    isUpdating.value = true;

    debugPrint('📝 [ViewModel] Updating task ID: $taskId');
    debugPrint('🔄 [ViewModel] Status: "$status"');

    final prefs   = await SharedPreferences.getInstance();
    final empId   = int.tryParse(prefs.getString('userId') ?? '') ?? 0;

    final request = UpdateTaskRequest(
      taskId:       taskId,
      empId:        empId,
      status:       status,  // Status: Open, In Progress, Done, Cancelled
      comments:     comments,
      priority:     priority,
      dueDate:      dueDate,
      category:     category,
      company_code: DBHelper.getCompanyCode(),
    );

    final result = await _repository.updateTask(request);
    isUpdating.value = false;

    if (result.isSuccess) {
      successMessage.value = 'Task updated successfully!';
      _updateLocalList(
        taskId:     taskId,
        status:     status,
        comments:   comments,
        priority:   priority,
        dueDate:    dueDate,
        category:   category,
        isAssigned: isAssigned,
      );
      return true;
    } else {
      errorMessage.value = result.errorMessage;
      return false;
    }
  }

  // ── Update list locally ───────────────────────────────────────────────────
  void _updateLocalList({
    required int    taskId,
    required String status,
    required String comments,
    required String priority,
    String? dueDate,
    String? category,
    required bool   isAssigned,
  }) {
    final list = isAssigned ? assignedTasks : createdTasks;
    final idx  = list.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(
        status:   status,
        comments: comments,
        priority: priority,
        dueDate:  dueDate   ?? list[idx].dueDate,
        category: category  ?? list[idx].category,
      );
      if (isAssigned) {
        assignedTasks.refresh();
      } else {
        createdTasks.refresh();
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  POST create task
  // ──────────────────────────────────────────────────────────────────────────
  Future<bool> createTask({
    required int    empId,
    required String empName,
    required String taskTitle,
    required String taskDescription,
    required String status,
    required String priority,
    required String dueDate,
    required String comments,
    String taskType = 'SELF',
  }) async {
    _resetMessages();
    isSubmitting.value = true;

    final prefs      = await SharedPreferences.getInstance();
    final assignedBy = prefs.getString('userName') ?? '';

    debugPrint('📝 [ViewModel] Creating task with status: "$status"');

    final request = CreateTaskRequest(
      empId:           empId,
      empName:         empName,
      taskTitle:       taskTitle,
      taskDescription: taskDescription,
      status:          status,  // Status: Open, In Progress, Done, Cancelled
      priority:        priority,
      dueDate:         dueDate,
      comments:        comments,
      assignedBy:      assignedBy,
      taskType:        taskType,
      company_code:    DBHelper.getCompanyCode(),
    );

    final result = await _repository.createTask(request);
    isSubmitting.value = false;

    if (result.isSuccess) {
      successMessage.value = 'Task created successfully!';
      if (result.data != null) createdTasks.insert(0, result.data!);
      return true;
    } else {
      errorMessage.value = result.errorMessage;
      return false;
    }
  }

  void _resetMessages() {
    errorMessage.value   = '';
    successMessage.value = '';
  }
}