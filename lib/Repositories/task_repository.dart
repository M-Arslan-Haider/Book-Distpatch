

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart'             as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Models/task_model.dart';

class RepositoryResult<T> {
  final T?     data;
  final String errorMessage;
  final bool   isSuccess;

  const RepositoryResult._({
    this.data,
    this.errorMessage = '',
    required this.isSuccess,
  });

  factory RepositoryResult.success(T data) =>
      RepositoryResult._(data: data, isSuccess: true);

  factory RepositoryResult.failure(String message) =>
      RepositoryResult._(errorMessage: message, isSuccess: false);
}

class TaskRepository {

  static const String _baseUrl         = 'http://oracle.metaxperts.net/ords/production';
  static const String _postEndpoint    = '/tasks/post/';
  static const String _getEndpoint     = '/task/get';
  static const String _createdEndpoint = '/tasks/created/';
  static const String _updateEndpoint  = '/taskupdate/put';
  static const Duration _timeout       = Duration(seconds: 30);

  Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept':       'application/json',
    };
    if (token.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  String _handleException(Object e) {
    if (e is SocketException) return 'No internet connection.';
    if (e is HttpException)   return 'Server error. Please try again.';
    if (e is FormatException) return 'Unexpected response from server.';
    return 'Something went wrong. Please try again.';
  }

  String _parseOracleError(String body, {required String fallback}) {
    debugPrint('🔴 Oracle error body: $body');
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['message']?.toString() ??
          decoded['title']?.toString()   ??
          decoded['error']?.toString()   ??
          fallback;
    } catch (_) {
      return body.isNotEmpty ? body : fallback;
    }
  }

  // ── Any-casing key reader ─────────────────────────────────────────────────
  static dynamic _val(Map<String, dynamic> j, String key) {
    if (j.containsKey(key))               return j[key];
    if (j.containsKey(key.toUpperCase())) return j[key.toUpperCase()];
    if (j.containsKey(key.toLowerCase())) return j[key.toLowerCase()];
    final lower = key.toLowerCase();
    for (final k in j.keys) {
      if (k.toLowerCase() == lower) return j[k];
    }
    return null;
  }

  TaskModel _taskFromMap(Map<String, dynamic> m) {
    return TaskModel(
      id:              (_val(m, 'id')               as num?)?.toInt() ?? 0,
      empId:           (_val(m, 'emp_id')           as num?)?.toInt() ?? 0,
      empName:         _val(m, 'emp_name')?.toString()           ?? '',
      taskTitle:       _val(m, 'task_title')?.toString()         ?? '',
      taskDescription: _val(m, 'task_description')?.toString()   ?? '',
      status:          _val(m, 'status')?.toString()             ?? 'Pending',
      priority:        _val(m, 'priority')?.toString()           ?? 'Medium',
      dueDate:         _val(m, 'due_date')?.toString()           ?? '',
      comments:        _val(m, 'comments')?.toString()           ?? '',
      assignedBy:      _val(m, 'assigned_by')?.toString()        ?? '',
      createdAt:       _val(m, 'created_at')?.toString()         ?? '',
      taskType:        _val(m, 'task_type')?.toString()          ?? 'SELF',
      category:        _val(m, 'category')?.toString()           ?? '',
    );
  }

  List<TaskModel> _parseList(String body) {
    debugPrint('═══════ RAW ORACLE RESPONSE ═══════');
    debugPrint(body);
    debugPrint('═══════════════════════════════════');

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    List<dynamic> rawList = [];
    for (final key in ['items', 'ITEMS', 'data', 'DATA', 'rows', 'ROWS']) {
      if (decoded.containsKey(key) && decoded[key] is List) {
        rawList = decoded[key] as List<dynamic>;
        debugPrint('📦 Found list under "$key" — ${rawList.length} items');
        break;
      }
    }

    final tasks = <TaskModel>[];
    for (int i = 0; i < rawList.length; i++) {
      final item = rawList[i] as Map<String, dynamic>;
      final task = _taskFromMap(item);
      debugPrint('✅ Parsed ID=${task.id}  title="${task.taskTitle}"');
      tasks.add(task);
    }
    return tasks;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GET assigned tasks
  // ══════════════════════════════════════════════════════════════════════════
  Future<RepositoryResult<List<TaskModel>>> getAssignedTasks() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final empId   = prefs.getString('userId') ?? '';
      final headers = await _headers();
      final uri = Uri.parse('$_baseUrl$_getEndpoint')
          .replace(queryParameters: {'emp_id': empId});

      debugPrint('📡 GET $uri');
      final response = await http.get(uri, headers: headers).timeout(_timeout);
      debugPrint('📬 GET status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return RepositoryResult.success(_parseList(response.body));
      }
      return RepositoryResult.failure(_parseOracleError(response.body,
          fallback: 'Failed to load tasks (${response.statusCode})'));
    } catch (e) {
      return RepositoryResult.failure(_handleException(e));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GET created tasks
  // ══════════════════════════════════════════════════════════════════════════
  Future<RepositoryResult<List<TaskModel>>> getCreatedTasks() async {
    try {
      final prefs      = await SharedPreferences.getInstance();
      final assignedBy = prefs.getString('userName') ?? '';
      final headers    = await _headers();
      final uri = Uri.parse('$_baseUrl$_createdEndpoint')
          .replace(queryParameters: {'assigned_by': assignedBy});

      debugPrint('📡 GET $uri');
      final response = await http.get(uri, headers: headers).timeout(_timeout);
      debugPrint('📬 GET status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return RepositoryResult.success(_parseList(response.body));
      }
      return RepositoryResult.failure(_parseOracleError(response.body,
          fallback: 'Failed to load created tasks (${response.statusCode})'));
    } catch (e) {
      return RepositoryResult.failure(_handleException(e));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  POST create task  ✅ id removed, Oracle generates it via sequence
  // ══════════════════════════════════════════════════════════════════════════
  Future<RepositoryResult<TaskModel>> createTask(CreateTaskRequest request) async {
    try {
      final headers = await _headers();
      final body    = request.toJson();

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📡 [POST] URL  : $_baseUrl$_postEndpoint');
      debugPrint('📡 [POST] Body : ${jsonEncode(body)}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http.post(
        Uri.parse('$_baseUrl$_postEndpoint'),
        headers: headers,
        body:    jsonEncode(body),
      ).timeout(_timeout);

      debugPrint('📬 [POST] Status  : ${response.statusCode}');
      debugPrint('📬 [POST] Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.trim().isEmpty) {
          return RepositoryResult.success(TaskModel(
            id: 0, empId: request.empId, empName: request.empName,
            taskTitle: request.taskTitle, taskDescription: request.taskDescription,
            status: request.status, priority: request.priority,
            dueDate: request.dueDate, comments: request.comments,
            assignedBy: request.assignedBy, createdAt: DateTime.now().toIso8601String(),
          ));
        }
        final decoded  = jsonDecode(response.body) as Map<String, dynamic>;
        final taskData = decoded['data'] as Map<String, dynamic>?;
        return RepositoryResult.success(
          taskData != null
              ? _taskFromMap(taskData)
              : TaskModel(
            id: (_val(decoded, 'id') as num?)?.toInt() ?? 0,
            empId: request.empId, empName: request.empName,
            taskTitle: request.taskTitle, taskDescription: request.taskDescription,
            status: request.status, priority: request.priority,
            dueDate: request.dueDate, comments: request.comments,
            assignedBy: request.assignedBy,
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
      }

      return RepositoryResult.failure(_parseOracleError(response.body,
          fallback: 'Failed to create task (${response.statusCode})'));
    } catch (e) {
      return RepositoryResult.failure(_handleException(e));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PUT update task
  //  ✅ updated_date & updated_time are auto-stamped inside UpdateTaskRequest
  //     and sent to Oracle — they are NOT read from or shown in the UI.
  // ══════════════════════════════════════════════════════════════════════════
  Future<RepositoryResult<TaskModel>> updateTask(UpdateTaskRequest request) async {
    try {
      final headers = await _headers();
      final body = request.toJson();

      // Format dates correctly for Oracle
      final now = DateTime.now();
      // Override the dates with proper format
      body['updated_date'] = DateFormat('dd-MMM-yyyy').format(now).toUpperCase();
      body['updated_time'] = DateFormat('dd-MMM-yyyy HH:mm:ss').format(now).toUpperCase();

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🟡 [PUT] URL          : $_baseUrl$_updateEndpoint');
      debugPrint('🟡 [PUT] Task ID      : ${request.taskId}');
      debugPrint('🟡 [PUT] updated_date : ${body['updated_date']}');
      debugPrint('🟡 [PUT] updated_time : ${body['updated_time']}');
      debugPrint('🟡 [PUT] Full Body    : ${jsonEncode(body)}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final response = await http.put(
        Uri.parse('$_baseUrl$_updateEndpoint'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(_timeout);

      debugPrint('🟡 [PUT] Status  : ${response.statusCode}');
      debugPrint('🟡 [PUT] Response: ${response.body}');

      if (response.statusCode == 200) {
        try {
          if (response.body.trim().isNotEmpty) {
            final decoded  = jsonDecode(response.body) as Map<String, dynamic>;
            final taskData = decoded['data'] as Map<String, dynamic>?;
            if (taskData != null) return RepositoryResult.success(_taskFromMap(taskData));
          }
        } catch (_) {}

        return RepositoryResult.success(TaskModel(
          id: request.taskId, empId: 0, empName: '', taskTitle: '',
          taskDescription: '', status: request.status, priority: request.priority,
          dueDate: request.dueDate ?? '', comments: request.comments,
          assignedBy: '', createdAt: '', category: request.category ?? '',
        ));
      }

      if (response.statusCode == 404) {
        return RepositoryResult.failure('Task not found (ID: ${request.taskId})');
      }

      return RepositoryResult.failure(_parseOracleError(response.body,
          fallback: 'Failed to update task (${response.statusCode})'));
    } catch (e) {
      return RepositoryResult.failure(_handleException(e));
    }
  }
}