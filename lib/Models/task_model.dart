// ════════════════════════════════════════════════════════════════════════════
//  lib/Models/task_model.dart
// ════════════════════════════════════════════════════════════════════════════

class TaskModel {
  final int    id;
  final int    empId;
  final String empName;
  final String taskTitle;
  final String taskDescription;
  final String status;
  final String priority;
  final String dueDate;
  final String comments;
  final String assignedBy;
  final String createdAt;
  final String taskType;
  final String category;

  const TaskModel({
    required this.id,
    required this.empId,
    required this.empName,
    required this.taskTitle,
    required this.taskDescription,
    required this.status,
    required this.priority,
    required this.dueDate,
    required this.comments,
    required this.assignedBy,
    required this.createdAt,
    this.taskType = 'SELF',
    this.category = '',
  });

  // ── Called by repository with its own _v() helper that handles all casing
  factory TaskModel.fromJsonSafe(
      Map<String, dynamic> json,
      dynamic Function(Map<String, dynamic>, String) v,
      ) {
    return TaskModel(
      id:              (v(json, 'id')               as num?)?.toInt() ?? 0,
      empId:           (v(json, 'emp_id')           as num?)?.toInt() ?? 0,
      empName:         v(json, 'emp_name')?.toString()           ?? '',
      taskTitle:       v(json, 'task_title')?.toString()         ?? '',
      taskDescription: v(json, 'task_description')?.toString()   ?? '',
      status:          v(json, 'status')?.toString()             ?? 'Pending',
      priority:        v(json, 'priority')?.toString()           ?? 'Medium',
      dueDate:         v(json, 'due_date')?.toString()           ?? '',
      comments:        v(json, 'comments')?.toString()           ?? '',
      assignedBy:      v(json, 'assigned_by')?.toString()        ?? '',
      createdAt:       v(json, 'created_at')?.toString()         ?? '',
      taskType:        v(json, 'task_type')?.toString()          ?? 'SELF',
      category:        v(json, 'category')?.toString()           ?? '',
    );
  }

  // ── Standard fromJson (kept for compatibility, does case-insensitive scan)
  factory TaskModel.fromJson(Map<String, dynamic> json) {
    dynamic val(String key) {
      if (json.containsKey(key))               return json[key];
      if (json.containsKey(key.toUpperCase())) return json[key.toUpperCase()];
      if (json.containsKey(key.toLowerCase())) return json[key.toLowerCase()];
      for (final k in json.keys) {
        if (k.toLowerCase() == key.toLowerCase()) return json[k];
      }
      return null;
    }

    return TaskModel(
      id:              (val('id')               as num?)?.toInt() ?? 0,
      empId:           (val('emp_id')           as num?)?.toInt() ?? 0,
      empName:         val('emp_name')?.toString()           ?? '',
      taskTitle:       val('task_title')?.toString()         ?? '',
      taskDescription: val('task_description')?.toString()   ?? '',
      status:          val('status')?.toString()             ?? 'Pending',
      priority:        val('priority')?.toString()           ?? 'Medium',
      dueDate:         val('due_date')?.toString()           ?? '',
      comments:        val('comments')?.toString()           ?? '',
      assignedBy:      val('assigned_by')?.toString()        ?? '',
      createdAt:       val('created_at')?.toString()         ?? '',
      taskType:        val('task_type')?.toString()          ?? 'SELF',
      category:        val('category')?.toString()           ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id':               id,
    'emp_id':           empId,
    'emp_name':         empName,
    'task_title':       taskTitle,
    'task_description': taskDescription,
    'status':           status,
    'priority':         priority,
    'due_date':         dueDate,
    'comments':         comments,
    'assigned_by':      assignedBy,
    'created_at':       createdAt,
    'task_type':        taskType,
    'category':         category,
  };

  TaskModel copyWith({
    int?    id,
    int?    empId,
    String? empName,
    String? taskTitle,
    String? taskDescription,
    String? status,
    String? priority,
    String? dueDate,
    String? comments,
    String? assignedBy,
    String? createdAt,
    String? taskType,
    String? category,
  }) {
    return TaskModel(
      id:              id              ?? this.id,
      empId:           empId           ?? this.empId,
      empName:         empName         ?? this.empName,
      taskTitle:       taskTitle       ?? this.taskTitle,
      taskDescription: taskDescription ?? this.taskDescription,
      status:          status          ?? this.status,
      priority:        priority        ?? this.priority,
      dueDate:         dueDate         ?? this.dueDate,
      comments:        comments        ?? this.comments,
      assignedBy:      assignedBy      ?? this.assignedBy,
      createdAt:       createdAt       ?? this.createdAt,
      taskType:        taskType        ?? this.taskType,
      category:        category        ?? this.category,
    );
  }

  @override
  String toString() =>
      'TaskModel(id: $id, empId: $empId, title: $taskTitle, status: $status)';
}

// ════════════════════════════════════════════════════════════════════════════
//  CreateTaskRequest
// ════════════════════════════════════════════════════════════════════════════
class CreateTaskRequest {
  final int    empId;
  final String empName;
  final String taskTitle;
  final String taskDescription;
  final String status;
  final String priority;
  final String dueDate;
  final String comments;
  final String assignedBy;
  final String taskType;

  const CreateTaskRequest({
    required this.empId,
    required this.empName,
    required this.taskTitle,
    required this.taskDescription,
    required this.status,
    required this.priority,
    required this.dueDate,
    required this.comments,
    required this.assignedBy,
    this.taskType = 'SELF',
  });

  Map<String, dynamic> toJson() {
    final now = DateTime.now();
    final createdAt =
        '${now.day.toString().padLeft(2, '0')}-'
        '${_monthAbbr(now.month)}-'
        '${now.year}';
    return {
      // 'id' removed — Oracle generates ID via sequence/trigger
      'emp_id':           empId,
      'emp_name':         empName,
      'task_title':       taskTitle,
      'task_description': taskDescription,
      'status':           status.isNotEmpty   ? status   : 'Pending',
      'priority':         priority.isNotEmpty ? priority : 'Medium',
      'due_date':         dueDate.isNotEmpty  ? dueDate  : null,
      'comments':         comments.isNotEmpty ? comments : null,
      'assigned_by':      assignedBy,
      'created_at':       createdAt,
      'task_type':        taskType.isNotEmpty ? taskType : 'SELF',
    };
  }

  static String _monthAbbr(int month) => const [
    '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ][month];
}

// ════════════════════════════════════════════════════════════════════════════
//  UpdateTaskRequest
//  ✅ updated_date & updated_time auto-generate at the moment of PUT call.
//     These fields are NEVER shown in the UI — they go straight to the DB.
// ════════════════════════════════════════════════════════════════════════════
class UpdateTaskRequest {
  final int     taskId;
  final String  status;
  final String  comments;
  final String  priority;
  final String? dueDate;
  final String? category;

  const UpdateTaskRequest({
    required this.taskId,
    required this.status,
    required this.comments,
    required this.priority,
    this.dueDate,
    this.category,
  });

  // ── Helpers ────────────────────────────────────────────────────────────────

  static const _months = [
    '', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  /// "03/18/2026" → Oracle DATE column
  static String _currentDate() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}/'
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.year}';
  }

  /// "03/18/2026 16:07:32" → Oracle TIMESTAMP(6) column
  static String _currentTime() {
    final now = DateTime.now();
    return '${now.month.toString().padLeft(2, '0')}/'
        '${now.day.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  // ── Serialise ──────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id':           taskId,
      'task_status':  status,
      'comments':     comments,
      'priority':     priority,
      'updated_date': _currentDate(),  // "2026-03-18"  → Oracle DATE
      'updated_time': _currentTime(),  // "15:56:16"    → Oracle TIMESTAMP
    };
    if (dueDate  != null && dueDate!.isNotEmpty)  map['due_date'] = dueDate;
    if (category != null && category!.isNotEmpty) map['category'] = category;
    return map;
  }
}