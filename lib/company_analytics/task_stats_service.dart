// // import 'package:flutter/foundation.dart';
// // import 'package:get/get.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import '../Database/db_helper.dart';
// //
// // // ═══════════════════════════════════════════════════════════════════════════
// // // task_stats_service.dart
// // //
// // // Fetches task statistics from the Oracle ORDS endpoint:
// // // http://oracle.metaxperts.net/ords/gps_workforce/taskstats/get/
// // //
// // // Parameters: emp_id, company_code
// // // (No "month" param — the underlying query is based on TM_TASKS /
// // // TM_TASK_ASSIGN_DETAIL filtered by emp_id + company_code only; "overdue"
// // // is computed server-side against SYSDATE, not against a selected month.)
// // //
// // // Backing query (for reference):
// // //   SELECT COUNT(*),
// // //          SUM(CASE WHEN x.NORM_STATUS = 'Completed' THEN 1 ELSE 0 END),
// // //          SUM(CASE WHEN x.NORM_STATUS = 'In Progress' THEN 1 ELSE 0 END),
// // //          SUM(CASE WHEN x.NORM_STATUS = 'Pending' THEN 1 ELSE 0 END),
// // //          SUM(CASE WHEN x.NORM_STATUS NOT IN ('Completed','Cancelled')
// // //                    AND x.DUE_DATE < TRUNC(SYSDATE) THEN 1 ELSE 0 END)
// // //   FROM ( ... ) x
// // //
// // // NOTE: the raw SQL has no column aliases, so the exact JSON key names
// // // ORDS will return aren't confirmed yet. fromJson() below tries several
// // // likely key-name variants for each field (same approach already used for
// // // totalMockLocationEvents / totalGpsOffEvents in
// // // attendance_analytics_service_screen.dart) — check the debug logs against
// // // a live response and tell me if a different key needs to be added.
// // // ═══════════════════════════════════════════════════════════════════════════
// //
// // class TaskStatsService extends GetxService {
// //   static const String _baseUrl =
// //       'http://oracle.metaxperts.net/ords/gps_workforce/taskstats/get';
// //
// //   // ─── Fetch task stats for the current employee ──────────────────────────
// //   Future<TaskStatsData?> fetchTaskStats() async {
// //     try {
// //       // Get emp_id from SharedPreferences
// //       final prefs = await SharedPreferences.getInstance();
// //
// //       String empId = '';
// //
// //       String? safeGetString(String key) {
// //         try {
// //           return prefs.getString(key);
// //         } catch (e) {
// //           return null;
// //         }
// //       }
// //
// //       int? safeGetInt(String key) {
// //         try {
// //           return prefs.getInt(key);
// //         } catch (e) {
// //           return null;
// //         }
// //       }
// //
// //       final stringKeys = [
// //         'emp_id',
// //         'empId',
// //         'employee_id',
// //         'employeeId',
// //         'userId',
// //         'user_id'
// //       ];
// //
// //       for (var key in stringKeys) {
// //         final value = safeGetString(key);
// //         if (value != null && value.isNotEmpty) {
// //           empId = value;
// //           break;
// //         }
// //       }
// //
// //       if (empId.isEmpty) {
// //         final intKeys = [
// //           'emp_id',
// //           'empId',
// //           'employee_id',
// //           'employeeId',
// //           'userId',
// //           'user_id'
// //         ];
// //
// //         for (var key in intKeys) {
// //           final value = safeGetInt(key);
// //           if (value != null) {
// //             empId = value.toString();
// //             break;
// //           }
// //         }
// //       }
// //
// //       // Get company_code from DBHelper
// //       final companyCode = DBHelper.getCompanyCode() ?? '';
// //
// //       if (empId.isEmpty || companyCode.isEmpty) {
// //         debugPrint(
// //             '❌ [TaskStatsService] Missing emp_id or company_code (emp: $empId, co: $companyCode)');
// //         return null;
// //       }
// //
// //       debugPrint(
// //           '📡 [TaskStatsService] Fetching data: emp_id=$empId, company_code=$companyCode');
// //
// //       final queryParams = {
// //         'emp_id': empId,
// //         'company_code': companyCode,
// //       };
// //
// //       final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
// //
// //       debugPrint('📡 [TaskStatsService] Full URL: $uri');
// //
// //       final response = await GetConnect().get(uri.toString());
// //
// //       debugPrint('📡 [TaskStatsService] Response status: ${response.statusCode}');
// //       debugPrint('📡 [TaskStatsService] Response body type: ${response.body.runtimeType}');
// //       debugPrint('📡 [TaskStatsService] Response body: ${response.body}');
// //       debugPrint('📡 [TaskStatsService] Response bodyString: ${response.bodyString}');
// //
// //       if (response.body == null) {
// //         debugPrint('❌ [TaskStatsService] Response body is null — check the URL/network '
// //             'tab in DevTools to confirm the request actually reached the server '
// //             'and the ORDS module path is correct.');
// //         return null;
// //       }
// //
// //       if (response.statusCode == 200) {
// //         final data = response.body;
// //
// //         if (data is Map<String, dynamic>) {
// //           debugPrint('📡 [TaskStatsService] Top-level JSON keys: ${data.keys.toList()}');
// //           if (data.containsKey('items') && data['items'] is List) {
// //             final items = data['items'] as List;
// //             debugPrint('📡 [TaskStatsService] items array length: ${items.length}');
// //             if (items.isNotEmpty) {
// //               final item = items[0];
// //               if (item is Map<String, dynamic>) {
// //                 debugPrint('✅ [TaskStatsService] Data received from items array: $item');
// //                 final result = TaskStatsData.fromJson(item);
// //                 debugPrint(
// //                     '✅ [TaskStatsService] FETCH OK — total=${result.totalTasks}, completed=${result.completedTasks}, '
// //                         'inProgress=${result.inProgressTasks}, pending=${result.pendingTasks}, overdue=${result.overdueTasks}');
// //                 return result;
// //               } else {
// //                 debugPrint('⚠️  [TaskStatsService] items[0] is not a Map<String, dynamic>: '
// //                     '$item (type: ${item.runtimeType})');
// //                 return null;
// //               }
// //             } else {
// //               debugPrint('⚠️  [TaskStatsService] Items array is empty — emp_id=$empId / '
// //                   'company_code=$companyCode may have no matching TM_TASK_ASSIGN_DETAIL rows');
// //               return null;
// //             }
// //           } else {
// //             debugPrint('✅ [TaskStatsService] Data received (single object): $data');
// //             final result = TaskStatsData.fromJson(data);
// //             debugPrint(
// //                 '✅ [TaskStatsService] FETCH OK — total=${result.totalTasks}, completed=${result.completedTasks}, '
// //                     'inProgress=${result.inProgressTasks}, pending=${result.pendingTasks}, overdue=${result.overdueTasks}');
// //             return result;
// //           }
// //         } else if (data is List && data.isNotEmpty) {
// //           final item = data[0];
// //           if (item is Map<String, dynamic>) {
// //             debugPrint('✅ [TaskStatsService] Data received (list): $item');
// //             final result = TaskStatsData.fromJson(item);
// //             debugPrint(
// //                 '✅ [TaskStatsService] FETCH OK — total=${result.totalTasks}, completed=${result.completedTasks}, '
// //                     'inProgress=${result.inProgressTasks}, pending=${result.pendingTasks}, overdue=${result.overdueTasks}');
// //             return result;
// //           } else {
// //             debugPrint('⚠️  [TaskStatsService] data[0] is not a Map<String, dynamic>: '
// //                 '$item (type: ${item.runtimeType})');
// //             return null;
// //           }
// //         } else if (data is List && data.isEmpty) {
// //           debugPrint('⚠️  [TaskStatsService] Response is an empty list — no rows returned '
// //               'for emp_id=$empId / company_code=$companyCode');
// //           return null;
// //         } else {
// //           debugPrint(
// //               '⚠️  [TaskStatsService] Unexpected response format: $data (type: ${data.runtimeType})');
// //           return null;
// //         }
// //       } else {
// //         debugPrint(
// //             '❌ [TaskStatsService] Error ${response.statusCode}: ${response.body}');
// //         return null;
// //       }
// //     } catch (e, stackTrace) {
// //       debugPrint('❌ [TaskStatsService] Exception: $e');
// //       debugPrint('❌ [TaskStatsService] StackTrace: $stackTrace');
// //       return null;
// //     }
// //     return null;
// //   }
// // }
// //
// // // ─── Data model ──────────────────────────────────────────────────────────
// // class TaskStatsData {
// //   final int totalTasks;
// //   final int completedTasks;
// //   final int inProgressTasks;
// //   final int pendingTasks;
// //   final int overdueTasks;
// //
// //   TaskStatsData({
// //     required this.totalTasks,
// //     required this.completedTasks,
// //     required this.inProgressTasks,
// //     required this.pendingTasks,
// //     required this.overdueTasks,
// //   });
// //
// //   // ─── Computed properties ──────────────────────────────────────────────
// //
// //   /// % of tasks completed (0-100)
// //   int get completionScore {
// //     if (totalTasks == 0) return 100;
// //     return ((completedTasks / totalTasks) * 100).round().clamp(0, 100);
// //   }
// //
// //   /// Main issue (most pressing problem, mirrors mainIssue in attendance model)
// //   String get mainIssue {
// //     if (overdueTasks > 0) {
// //       return '$overdueTasks task${overdueTasks == 1 ? '' : 's'} overdue';
// //     } else if (pendingTasks > 0) {
// //       return '$pendingTasks task${pendingTasks == 1 ? '' : 's'} pending';
// //     } else if (inProgressTasks > 0) {
// //       return '$inProgressTasks task${inProgressTasks == 1 ? '' : 's'} in progress';
// //     } else {
// //       return 'No major issues detected';
// //     }
// //   }
// //
// //   /// Suggested action
// //   String get suggestedAction {
// //     if (overdueTasks > 0) {
// //       return 'Prioritize overdue tasks to get back on track.';
// //     } else if (pendingTasks > 0) {
// //       return 'Start pending tasks to keep moving on schedule.';
// //     } else {
// //       return 'Keep up the great task completion record!';
// //     }
// //   }
// //
// //   // ─── JSON parsing ────────────────────────────────────────────────────
// //   factory TaskStatsData.fromJson(Map<String, dynamic> json) {
// //     debugPrint('📊 [TaskStats fromJson] Raw JSON: $json');
// //     debugPrint('📊 [TaskStats fromJson] Available keys: ${json.keys.toList()}');
// //
// //     int parseInteger(dynamic value) {
// //       if (value == null) return 0;
// //       if (value is int) return value;
// //       if (value is String) {
// //         final parsed = int.tryParse(value);
// //         return parsed ?? 0;
// //       }
// //       if (value is double) return value.toInt();
// //       debugPrint(
// //           '⚠️ [TaskStats fromJson] Unexpected type for value: $value (${value.runtimeType})');
// //       return 0;
// //     }
// //
// //     final unmatchedFields = <String>[];
// //
// //     // Exact column names aren't confirmed yet (the raw SQL has no
// //     // aliases) — first matching key in the JSON wins for each field.
// //     // Logs which key matched (or that none did) so a live response makes
// //     // it obvious whether the guessed column names are correct.
// //     int parseFirstMatch(String fieldName, List<String> keys) {
// //       for (final key in keys) {
// //         if (json.containsKey(key) && json[key] != null) {
// //           final value = parseInteger(json[key]);
// //           debugPrint("✅ [TaskStats fromJson] $fieldName matched key '$key' -> $value");
// //           return value;
// //         }
// //       }
// //       debugPrint(
// //           "⚠️ [TaskStats fromJson] $fieldName: NO MATCH among $keys — defaulting to 0. "
// //               'If the real column name is different, add it to this list.');
// //       unmatchedFields.add(fieldName);
// //       return 0;
// //     }
// //
// //     final totalTasks = parseFirstMatch('totalTasks', [
// //       'total_tasks',
// //       'total_task',
// //       'total_task_count',
// //       'task_count',
// //       'total',
// //       'count',
// //     ]);
// //
// //     final completedTasks = parseFirstMatch('completedTasks', [
// //       'completed_tasks',
// //       'completed_task_count',
// //       'total_completed',
// //       'completed',
// //       'completed_count',
// //     ]);
// //
// //     final inProgressTasks = parseFirstMatch('inProgressTasks', [
// //       'in_progress_tasks',
// //       'inprogress_tasks',
// //       'in_progress_task_count',
// //       'in_progress',
// //       'inprogress_count',
// //     ]);
// //
// //     final pendingTasks = parseFirstMatch('pendingTasks', [
// //       'pending_tasks',
// //       'pending_task_count',
// //       'pending',
// //       'pending_count',
// //     ]);
// //
// //     final overdueTasks = parseFirstMatch('overdueTasks', [
// //       'overdue_tasks',
// //       'overdue_task_count',
// //       'overdue',
// //       'overdue_count',
// //     ]);
// //
// //     debugPrint(
// //         '📊 [TaskStats fromJson] Parsed: total=$totalTasks, completed=$completedTasks, inProgress=$inProgressTasks, pending=$pendingTasks, overdue=$overdueTasks');
// //
// //     if (unmatchedFields.isNotEmpty) {
// //       debugPrint(
// //           '🚨 [TaskStats fromJson] VERIFY: these fields found NO matching key and are '
// //               'showing 0 — compare against "Available keys" above and tell me the real '
// //               'column names: $unmatchedFields');
// //     } else {
// //       debugPrint('✅ [TaskStats fromJson] All fields matched a key — data looks live.');
// //     }
// //
// //     return TaskStatsData(
// //       totalTasks: totalTasks,
// //       completedTasks: completedTasks,
// //       inProgressTasks: inProgressTasks,
// //       pendingTasks: pendingTasks,
// //       overdueTasks: overdueTasks,
// //     );
// //   }
// // }
//
// import 'package:flutter/foundation.dart';
// import 'package:get/get.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../Database/db_helper.dart';
//
// // ═══════════════════════════════════════════════════════════════════════════
// // task_stats_service.dart
// //
// // Fetches task statistics from the Oracle ORDS endpoint:
// // http://oracle.metaxperts.net/ords/gps_workforce/taskstats/get/
// //
// // Parameters: emp_id, company_code, year (YYYY), month (MM, zero-padded)
// //
// // Backend query (confirmed — now filters by month via START_DATE/DUE_DATE
// // overlap with the selected month, and has explicit column aliases):
// //
// //   SELECT
// //       COUNT(*) AS total,
// //       SUM(CASE WHEN x.NORM_STATUS = 'Completed'   THEN 1 ELSE 0 END) AS completed,
// //       SUM(CASE WHEN x.NORM_STATUS = 'In Progress' THEN 1 ELSE 0 END) AS in_progress,
// //       SUM(CASE WHEN x.NORM_STATUS = 'Pending'     THEN 1 ELSE 0 END) AS pending,
// //       SUM(CASE WHEN x.NORM_STATUS NOT IN ('Completed','Cancelled')
// //                 AND x.DUE_DATE < TRUNC(SYSDATE) THEN 1 ELSE 0 END) AS overdue
// //     FROM (
// //       SELECT
// //         t.TASK_ID,
// //         t.DUE_DATE,
// //         CASE
// //           WHEN UPPER(t.STATUS) IN ('DONE','COMPLETED')        THEN 'Completed'
// //           WHEN UPPER(t.STATUS) IN ('PENDING','OPEN')          THEN 'Pending'
// //           WHEN UPPER(REPLACE(t.STATUS,' ','')) = 'INPROGRESS' THEN 'In Progress'
// //           WHEN UPPER(t.STATUS) IN ('CANCELLED','CANCEL')      THEN 'Cancelled'
// //           ELSE t.STATUS
// //         END AS NORM_STATUS
// //       FROM TM_TASKS t
// //       JOIN TM_TASK_ASSIGN_DETAIL d
// //         ON  d.TASK_ID      = t.TASK_ID
// //         AND d.COMPANY_CODE = t.COMPANY_CODE
// //       WHERE d.EMP_ID       = :emp_id
// //         AND t.COMPANY_CODE = :company_code
// //         AND t.START_DATE <= LAST_DAY(TO_DATE(:year || '-' || :month, 'YYYY-MM'))
// //         AND t.DUE_DATE   >= TRUNC(TO_DATE(:year || '-' || :month, 'YYYY-MM'), 'MM')
// //     ) x
// //
// // Note: this counts any task whose [START_DATE, DUE_DATE] range overlaps
// // the selected month at all (not strictly "due within the month") — a
// // task spanning multiple months will show up in each of them.
// //
// // Column aliases (total / completed / in_progress / pending / overdue) are
// // now explicit in the query, so fromJson() below matches those exact names
// // first. A short list of fallback variants is kept after them in case ORDS
// // returns the keys upper-cased or differently-cased in practice — check the
// // debug logs against a live response to confirm.
// // ═══════════════════════════════════════════════════════════════════════════
//
// class TaskStatsService extends GetxService {
//   static const String _baseUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce/taskstats/get';
//
//   // ─── Fetch task stats for the current employee + month ──────────────────
//   Future<TaskStatsData?> fetchTaskStats({
//     required String year,  // YYYY, e.g., "2026"
//     required String month, // MM (zero-padded), e.g., "05"
//   }) async {
//     try {
//       // Get emp_id from SharedPreferences
//       final prefs = await SharedPreferences.getInstance();
//
//       String empId = '';
//
//       String? safeGetString(String key) {
//         try {
//           return prefs.getString(key);
//         } catch (e) {
//           return null;
//         }
//       }
//
//       int? safeGetInt(String key) {
//         try {
//           return prefs.getInt(key);
//         } catch (e) {
//           return null;
//         }
//       }
//
//       final stringKeys = [
//         'emp_id',
//         'empId',
//         'employee_id',
//         'employeeId',
//         'userId',
//         'user_id'
//       ];
//
//       for (var key in stringKeys) {
//         final value = safeGetString(key);
//         if (value != null && value.isNotEmpty) {
//           empId = value;
//           break;
//         }
//       }
//
//       if (empId.isEmpty) {
//         final intKeys = [
//           'emp_id',
//           'empId',
//           'employee_id',
//           'employeeId',
//           'userId',
//           'user_id'
//         ];
//
//         for (var key in intKeys) {
//           final value = safeGetInt(key);
//           if (value != null) {
//             empId = value.toString();
//             break;
//           }
//         }
//       }
//
//       // Get company_code from DBHelper
//       final companyCode = DBHelper.getCompanyCode() ?? '';
//
//       if (empId.isEmpty || companyCode.isEmpty) {
//         debugPrint(
//             '❌ [TaskStatsService] Missing emp_id or company_code (emp: $empId, co: $companyCode)');
//         return null;
//       }
//
//       debugPrint(
//           '📡 [TaskStatsService] Fetching data: emp_id=$empId, company_code=$companyCode, month=$month');
//
//       final queryParams = {
//         'emp_id': empId,
//         'company_code': companyCode,
//         'month': month,
//       };
//
//       final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
//
//       debugPrint('📡 [TaskStatsService] Full URL: $uri');
//
//       final response = await GetConnect().get(uri.toString());
//
//       debugPrint('📡 [TaskStatsService] Response status: ${response.statusCode}');
//       debugPrint('📡 [TaskStatsService] Response body type: ${response.body.runtimeType}');
//       debugPrint('📡 [TaskStatsService] Response body: ${response.body}');
//       debugPrint('📡 [TaskStatsService] Response bodyString: ${response.bodyString}');
//
//       if (response.body == null) {
//         debugPrint('❌ [TaskStatsService] Response body is null — check the URL/network '
//             'tab in DevTools to confirm the request actually reached the server '
//             'and the ORDS module path is correct.');
//         return null;
//       }
//
//       if (response.statusCode == 200) {
//         final data = response.body;
//
//         if (data is Map<String, dynamic>) {
//           debugPrint('📡 [TaskStatsService] Top-level JSON keys: ${data.keys.toList()}');
//           if (data.containsKey('items') && data['items'] is List) {
//             final items = data['items'] as List;
//             debugPrint('📡 [TaskStatsService] items array length: ${items.length}');
//             if (items.isNotEmpty) {
//               final item = items[0];
//               if (item is Map<String, dynamic>) {
//                 debugPrint('✅ [TaskStatsService] Data received from items array: $item');
//                 final result = TaskStatsData.fromJson(item);
//                 debugPrint(
//                     '✅ [TaskStatsService] FETCH OK — total=${result.totalTasks}, completed=${result.completedTasks}, '
//                         'inProgress=${result.inProgressTasks}, pending=${result.pendingTasks}, overdue=${result.overdueTasks}');
//                 return result;
//               } else {
//                 debugPrint('⚠️  [TaskStatsService] items[0] is not a Map<String, dynamic>: '
//                     '$item (type: ${item.runtimeType})');
//                 return null;
//               }
//             } else {
//               debugPrint('⚠️  [TaskStatsService] Items array is empty — emp_id=$empId / '
//                   'company_code=$companyCode may have no matching TM_TASK_ASSIGN_DETAIL rows');
//               return null;
//             }
//           } else {
//             debugPrint('✅ [TaskStatsService] Data received (single object): $data');
//             final result = TaskStatsData.fromJson(data);
//             debugPrint(
//                 '✅ [TaskStatsService] FETCH OK — total=${result.totalTasks}, completed=${result.completedTasks}, '
//                     'inProgress=${result.inProgressTasks}, pending=${result.pendingTasks}, overdue=${result.overdueTasks}');
//             return result;
//           }
//         } else if (data is List && data.isNotEmpty) {
//           final item = data[0];
//           if (item is Map<String, dynamic>) {
//             debugPrint('✅ [TaskStatsService] Data received (list): $item');
//             final result = TaskStatsData.fromJson(item);
//             debugPrint(
//                 '✅ [TaskStatsService] FETCH OK — total=${result.totalTasks}, completed=${result.completedTasks}, '
//                     'inProgress=${result.inProgressTasks}, pending=${result.pendingTasks}, overdue=${result.overdueTasks}');
//             return result;
//           } else {
//             debugPrint('⚠️  [TaskStatsService] data[0] is not a Map<String, dynamic>: '
//                 '$item (type: ${item.runtimeType})');
//             return null;
//           }
//         } else if (data is List && data.isEmpty) {
//           debugPrint('⚠️  [TaskStatsService] Response is an empty list — no rows returned '
//               'for emp_id=$empId / company_code=$companyCode');
//           return null;
//         } else {
//           debugPrint(
//               '⚠️  [TaskStatsService] Unexpected response format: $data (type: ${data.runtimeType})');
//           return null;
//         }
//       } else {
//         debugPrint(
//             '❌ [TaskStatsService] Error ${response.statusCode}: ${response.body}');
//         return null;
//       }
//     } catch (e, stackTrace) {
//       debugPrint('❌ [TaskStatsService] Exception: $e');
//       debugPrint('❌ [TaskStatsService] StackTrace: $stackTrace');
//       return null;
//     }
//     return null;
//   }
// }
//
// // ─── Data model ──────────────────────────────────────────────────────────
// class TaskStatsData {
//   final int totalTasks;
//   final int completedTasks;
//   final int inProgressTasks;
//   final int pendingTasks;
//   final int overdueTasks;
//
//   TaskStatsData({
//     required this.totalTasks,
//     required this.completedTasks,
//     required this.inProgressTasks,
//     required this.pendingTasks,
//     required this.overdueTasks,
//   });
//
//   // ─── Computed properties ──────────────────────────────────────────────
//
//   /// % of tasks completed (0-100)
//   int get completionScore {
//     if (totalTasks == 0) return 100;
//     return ((completedTasks / totalTasks) * 100).round().clamp(0, 100);
//   }
//
//   /// Main issue (most pressing problem, mirrors mainIssue in attendance model)
//   String get mainIssue {
//     if (overdueTasks > 0) {
//       return '$overdueTasks task${overdueTasks == 1 ? '' : 's'} overdue';
//     } else if (pendingTasks > 0) {
//       return '$pendingTasks task${pendingTasks == 1 ? '' : 's'} pending';
//     } else if (inProgressTasks > 0) {
//       return '$inProgressTasks task${inProgressTasks == 1 ? '' : 's'} in progress';
//     } else {
//       return 'No major issues detected';
//     }
//   }
//
//   /// Suggested action
//   String get suggestedAction {
//     if (overdueTasks > 0) {
//       return 'Prioritize overdue tasks to get back on track.';
//     } else if (pendingTasks > 0) {
//       return 'Start pending tasks to keep moving on schedule.';
//     } else {
//       return 'Keep up the great task completion record!';
//     }
//   }
//
//   // ─── JSON parsing ────────────────────────────────────────────────────
//   factory TaskStatsData.fromJson(Map<String, dynamic> json) {
//     debugPrint('📊 [TaskStats fromJson] Raw JSON: $json');
//     debugPrint('📊 [TaskStats fromJson] Available keys: ${json.keys.toList()}');
//
//     int parseInteger(dynamic value) {
//       if (value == null) return 0;
//       if (value is int) return value;
//       if (value is String) {
//         final parsed = int.tryParse(value);
//         return parsed ?? 0;
//       }
//       if (value is double) return value.toInt();
//       debugPrint(
//           '⚠️ [TaskStats fromJson] Unexpected type for value: $value (${value.runtimeType})');
//       return 0;
//     }
//
//     final unmatchedFields = <String>[];
//
//     // Exact column names aren't confirmed yet (the raw SQL has no
//     // aliases) — first matching key in the JSON wins for each field.
//     // Logs which key matched (or that none did) so a live response makes
//     // it obvious whether the guessed column names are correct.
//     int parseFirstMatch(String fieldName, List<String> keys) {
//       for (final key in keys) {
//         if (json.containsKey(key) && json[key] != null) {
//           final value = parseInteger(json[key]);
//           debugPrint("✅ [TaskStats fromJson] $fieldName matched key '$key' -> $value");
//           return value;
//         }
//       }
//       debugPrint(
//           "⚠️ [TaskStats fromJson] $fieldName: NO MATCH among $keys — defaulting to 0. "
//               'If the real column name is different, add it to this list.');
//       unmatchedFields.add(fieldName);
//       return 0;
//     }
//
//     final totalTasks = parseFirstMatch('totalTasks', [
//       'total_tasks',
//       'total_task',
//       'total_task_count',
//       'task_count',
//       'total',
//       'count',
//     ]);
//
//     final completedTasks = parseFirstMatch('completedTasks', [
//       'completed_tasks',
//       'completed_task_count',
//       'total_completed',
//       'completed',
//       'completed_count',
//     ]);
//
//     final inProgressTasks = parseFirstMatch('inProgressTasks', [
//       'in_progress_tasks',
//       'inprogress_tasks',
//       'in_progress_task_count',
//       'in_progress',
//       'inprogress_count',
//     ]);
//
//     final pendingTasks = parseFirstMatch('pendingTasks', [
//       'pending_tasks',
//       'pending_task_count',
//       'pending',
//       'pending_count',
//     ]);
//
//     final overdueTasks = parseFirstMatch('overdueTasks', [
//       'overdue_tasks',
//       'overdue_task_count',
//       'overdue',
//       'overdue_count',
//     ]);
//
//     debugPrint(
//         '📊 [TaskStats fromJson] Parsed: total=$totalTasks, completed=$completedTasks, inProgress=$inProgressTasks, pending=$pendingTasks, overdue=$overdueTasks');
//
//     if (unmatchedFields.isNotEmpty) {
//       debugPrint(
//           '🚨 [TaskStats fromJson] VERIFY: these fields found NO matching key and are '
//               'showing 0 — compare against "Available keys" above and tell me the real '
//               'column names: $unmatchedFields');
//     } else {
//       debugPrint('✅ [TaskStats fromJson] All fields matched a key — data looks live.');
//     }
//
//     return TaskStatsData(
//       totalTasks: totalTasks,
//       completedTasks: completedTasks,
//       inProgressTasks: inProgressTasks,
//       pendingTasks: pendingTasks,
//       overdueTasks: overdueTasks,
//     );
//   }
// }

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Database/db_helper.dart';

class TaskStatsService extends GetxService {
  static const String _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/taskstats/get';

  // ─── Fetch task stats for the current employee + month ──────────────────
  Future<TaskStatsData?> fetchTaskStats({
    required String month,  // "YYYY-MM" format
  }) async {
    try {
      // Get emp_id from SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      String empId = '';

      String? safeGetString(String key) {
        try {
          return prefs.getString(key);
        } catch (e) {
          return null;
        }
      }

      int? safeGetInt(String key) {
        try {
          return prefs.getInt(key);
        } catch (e) {
          return null;
        }
      }

      final stringKeys = [
        'emp_id',
        'empId',
        'employee_id',
        'employeeId',
        'userId',
        'user_id'
      ];

      for (var key in stringKeys) {
        final value = safeGetString(key);
        if (value != null && value.isNotEmpty) {
          empId = value;
          break;
        }
      }

      if (empId.isEmpty) {
        final intKeys = [
          'emp_id',
          'empId',
          'employee_id',
          'employeeId',
          'userId',
          'user_id'
        ];

        for (var key in intKeys) {
          final value = safeGetInt(key);
          if (value != null) {
            empId = value.toString();
            break;
          }
        }
      }

      // Get company_code from DBHelper
      final companyCode = DBHelper.getCompanyCode() ?? '';

      if (empId.isEmpty || companyCode.isEmpty) {
        debugPrint(
            '❌ [TaskStatsService] Missing emp_id or company_code (emp: $empId, co: $companyCode)');
        return null;
      }

      debugPrint(
          '📡 [TaskStatsService] Fetching data: emp_id=$empId, company_code=$companyCode, month=$month');

      final queryParams = {
        'emp_id': empId,
        'company_code': companyCode,
        'month': month,  // "2026-06"
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      debugPrint('📡 [TaskStatsService] Full URL: $uri');

      final response = await GetConnect().get(uri.toString());

      debugPrint('📡 [TaskStatsService] Response status: ${response.statusCode}');
      debugPrint('📡 [TaskStatsService] Response body type: ${response.body.runtimeType}');
      debugPrint('📡 [TaskStatsService] Response body: ${response.body}');

      if (response.body == null) {
        debugPrint('❌ [TaskStatsService] Response body is null');
        return null;
      }

      if (response.statusCode == 200) {
        final data = response.body;

        if (data is Map<String, dynamic>) {
          debugPrint('📡 [TaskStatsService] Top-level JSON keys: ${data.keys.toList()}');
          if (data.containsKey('items') && data['items'] is List) {
            final items = data['items'] as List;
            debugPrint('📡 [TaskStatsService] items array length: ${items.length}');
            if (items.isNotEmpty) {
              final item = items[0];
              if (item is Map<String, dynamic>) {
                debugPrint('✅ [TaskStatsService] Data received from items array: $item');
                final result = TaskStatsData.fromJson(item);
                return result;
              }
            }
          } else {
            debugPrint('✅ [TaskStatsService] Data received (single object): $data');
            return TaskStatsData.fromJson(data);
          }
        }
      } else {
        debugPrint('❌ [TaskStatsService] Error ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [TaskStatsService] Exception: $e');
      debugPrint('❌ [TaskStatsService] StackTrace: $stackTrace');
      return null;
    }
    return null;
  }
}

class TaskStatsData {
  final int totalTasks;
  final int completedTasks;
  final int inProgressTasks;
  final int pendingTasks;
  final int overdueTasks;
  final double completionPct;

  TaskStatsData({
    required this.totalTasks,
    required this.completedTasks,
    required this.inProgressTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    required this.completionPct,
  });

  int get completionScore => completionPct.round().clamp(0, 100);

  String get mainIssue {
    if (overdueTasks > 0) {
      return '$overdueTasks task${overdueTasks == 1 ? '' : 's'} overdue';
    } else if (pendingTasks > 0) {
      return '$pendingTasks task${pendingTasks == 1 ? '' : 's'} pending';
    } else if (inProgressTasks > 0) {
      return '$inProgressTasks task${inProgressTasks == 1 ? '' : 's'} in progress';
    } else {
      return 'No major issues detected';
    }
  }

  String get suggestedAction {
    if (overdueTasks > 0) {
      return 'Prioritize overdue tasks to get back on track.';
    } else if (pendingTasks > 0) {
      return 'Start pending tasks to keep moving on schedule.';
    } else {
      return 'Keep up the great task completion record!';
    }
  }

  factory TaskStatsData.fromJson(Map<String, dynamic> json) {
    debugPrint('📊 [TaskStats fromJson] Raw JSON: $json');
    debugPrint('📊 [TaskStats fromJson] Available keys: ${json.keys.toList()}');

    int parseInteger(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        return parsed ?? 0;
      }
      if (value is double) return value.toInt();
      return 0;
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        return parsed ?? 0.0;
      }
      return 0.0;
    }

    final total = parseInteger(json['total'] ?? json['total_tasks'] ?? 0);
    final completed = parseInteger(json['completed'] ?? json['completed_tasks'] ?? 0);
    final inProgress = parseInteger(json['in_progress'] ?? json['in_progress_tasks'] ?? 0);
    final pending = parseInteger(json['pending'] ?? json['pending_tasks'] ?? 0);
    final overdue = parseInteger(json['overdue'] ?? json['overdue_tasks'] ?? 0);
    final completionPct = parseDouble(json['completion_pct'] ?? json['completionPercentage'] ?? 0.0);

    return TaskStatsData(
      totalTasks: total,
      completedTasks: completed,
      inProgressTasks: inProgress,
      pendingTasks: pending,
      overdueTasks: overdue,
      completionPct: completionPct,
    );
  }
}