//
// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/foundation.dart';
// import 'package:http/http.dart' as http;
// import 'package:http_parser/http_parser.dart';
//
// import '../Database/db_helper.dart';
// import '../Models/leave_model.dart';
// import '../Services/remote_config_service.dart';
//
// class LeaveRepository {
//   static const String _baseUrl =
//       'http://oracle.metaxperts.net/ords/gps_workforce/leavetable/post/';
//
//   // // WITH:
//   // static String get _baseUrl => RemoteConfigService.getLeaveUrl();
//
//   final DBHelper _db = DBHelper();
//
//   // ─── LOCAL DB ──────────────────────────────────────────────────────────────
//
//   Future<bool> saveLocally(LeaveModel leave) async {
//     try {
//       final result = await _db.insert(DBHelper.leaveTable, leave.toMap());
//       debugPrint('✅ [Leave] Saved locally — rows: $result');
//       return result > 0;
//     } catch (e) {
//       debugPrint('❌ [Leave] Local save failed: $e');
//       return false;
//     }
//   }
//
//   Future<List<LeaveModel>> getAllLeaves() async {
//     try {
//       final rows = await _db.getAll(DBHelper.leaveTable);
//       return rows.map((r) => LeaveModel.fromMap(r)).toList();
//     } catch (e) {
//       return [];
//     }
//   }
//
//   Future<List<LeaveModel>> getUnpostedLeaves() async {
//     try {
//       final rows = await _db.getUnposted(DBHelper.leaveTable);
//       return rows.map((r) => LeaveModel.fromMap(r)).toList();
//     } catch (e) {
//       return [];
//     }
//   }
//
//   Future<void> markAsPosted(String leaveId) async {
//     await _db.markAsPosted(DBHelper.leaveTable, 'leave_id', leaveId);
//   }
//
//   // ─── SERVER ────────────────────────────────────────────────────────────────
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // METHOD 1: MULTIPART (SAME AS ATTENDANCE)
//   // Most reliable method — sends image as multipart file, text as fields
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<bool> _postMethod1(LeaveModel leave) async {
//     try {
//       debugPrint('🌐 [LeaveRepo] Method 1: Multipart → $_baseUrl');
//
//       var request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
//
//       // ── TEXT FIELDS (UPPER_CASE — Oracle standard) ──
//       request.fields['LEAVE_ID']           = leave.leaveId;
//       request.fields['EMP_ID']             = leave.empId;
//       request.fields['EMP_NAME']           = leave.empName;
//       request.fields['LEAVE_TYPE']         = leave.leaveType;
//       request.fields['START_DATE']         = leave.startDate;
//       request.fields['END_DATE']           = leave.endDate;
//       request.fields['TOTAL_DAYS']         = leave.totalDays.toString();
//       request.fields['IS_HALF_DAY']        = leave.isHalfDay.toString();
//       request.fields['REASON']             = leave.reason;
//       request.fields['APPLICATION_DATE']   = leave.applicationDate;
//       request.fields['APPLICATION_TIME']   = leave.applicationTime;
//       request.fields['STATUS']             = leave.status;
//       request.fields['POSTED']             = leave.posted.toString();
//       if (leave.company_code != null && leave.company_code!.isNotEmpty) {
//         request.fields['COMPANY_CODE']     = leave.company_code!;
//       }
//
//       // ── TEXT FIELDS (lower_case — fallback) ──
//       request.fields['leave_id']           = leave.leaveId;
//       request.fields['emp_id']             = leave.empId;
//       request.fields['emp_name']           = leave.empName;
//       request.fields['leave_type']         = leave.leaveType;
//       request.fields['start_date']         = leave.startDate;
//       request.fields['end_date']           = leave.endDate;
//       request.fields['total_days']         = leave.totalDays.toString();
//       request.fields['is_half_day']        = leave.isHalfDay.toString();
//       request.fields['reason']             = leave.reason;
//       request.fields['application_date']   = leave.applicationDate;
//       request.fields['application_time']   = leave.applicationTime;
//       request.fields['status']             = leave.status;
//       request.fields['posted']             = leave.posted.toString();
//       if (leave.company_code != null && leave.company_code!.isNotEmpty) {
//         request.fields['company_code']     = leave.company_code!;
//       }
//
//       // ── ATTACHMENT IMAGE ──
//       final Uint8List? attachmentBytes = _getAttachmentBytes(leave.attachmentData, leave.attachmentImage);
//       if (attachmentBytes != null && attachmentBytes.isNotEmpty) {
//         final String filename =
//             'attachment_${leave.empId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
//
//         request.files.add(http.MultipartFile.fromBytes(
//           'ATTACHMENT',
//           attachmentBytes,
//           filename: filename,
//           contentType: MediaType('image', 'jpeg'),
//         ));
//
//         request.files.add(http.MultipartFile.fromBytes(
//           'attachment',
//           attachmentBytes,
//           filename: filename,
//           contentType: MediaType('image', 'jpeg'),
//         ));
//
//         request.files.add(http.MultipartFile.fromBytes(
//           'file',
//           attachmentBytes,
//           filename: filename,
//           contentType: MediaType('image', 'jpeg'),
//         ));
//
//         debugPrint('📎 [LeaveRepo] Attachment added: $filename (${attachmentBytes.length} bytes)');
//       } else {
//         debugPrint('📎 [LeaveRepo] No attachment');
//       }
//
//       debugPrint('📡 [LeaveRepo] Fields: ${request.fields.length}, Files: ${request.files.length}');
//
//       final streamedResponse = await request.send();
//       final response = await http.Response.fromStream(streamedResponse);
//
//       debugPrint('📡 [LeaveRepo] Method1 → ${response.statusCode}: ${response.body}');
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         debugPrint('✅ [LeaveRepo] Method 1 successful!');
//         return true;
//       }
//
//       // Duplicate key → treat as already posted
//       if (response.statusCode == 555 || response.statusCode == 409) {
//         if (response.body.contains('ORA-00001') ||
//             response.body.contains('unique constraint')) {
//           debugPrint('⚠️ [LeaveRepo] Duplicate key — marking as posted');
//           return true;
//         }
//       }
//
//       debugPrint('❌ [LeaveRepo] Method 1 failed: ${response.statusCode}');
//       return false;
//     } catch (e) {
//       debugPrint('❌ [LeaveRepo] Method 1 error: $e');
//       return false;
//     }
//   }
//
//   // ══════════════════════════════════════════════════════════════════════════
//   // METHOD 2: QUERY PARAMS (BACKUP — old approach)
//   // ══════════════════════════════════════════════════════════════════════════
//
//   Future<bool> _postMethod2(LeaveModel leave) async {
//     try {
//       debugPrint('\n=== [LeaveRepo] METHOD 2: QUERY PARAMS (BACKUP) ===');
//
//       final String bodyValue = _buildBase64Body(leave);
//
//       // Build all bind variables as URL query parameters
//       final params = <String, String>{
//         'leave_id':         leave.leaveId,
//         'emp_id':           leave.empId,
//         'emp_name':         leave.empName,
//         'leave_type':       leave.leaveType,
//         'start_date':       leave.startDate,
//         'end_date':         leave.endDate,
//         'total_days':       leave.totalDays.toString(),
//         'is_half_day':      leave.isHalfDay.toString(),
//         'reason':           leave.reason,
//         'body':             bodyValue,
//         'application_date': leave.applicationDate,
//         'application_time': leave.applicationTime,
//         'status':           leave.status,
//         'posted':           leave.posted.toString(),
//         if (leave.company_code != null && leave.company_code!.isNotEmpty)
//           'company_code':   leave.company_code!,
//       };
//
//       // Append all params to URL — ORDS maps these to :bind_variables always
//       final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
//
//       debugPrint('📡 [LeaveRepo] URL (truncated): ${uri.toString().substring(0, uri.toString().length > 200 ? 200 : uri.toString().length)}...');
//       debugPrint('📦 [LeaveRepo] leave_id    : ${leave.leaveId}');
//       debugPrint('📦 [LeaveRepo] emp         : "${leave.empId}" | "${leave.empName}"');
//       debugPrint('📦 [LeaveRepo] leave_type  : "${leave.leaveType}"');
//       debugPrint('📦 [LeaveRepo] start_date  : "${leave.startDate}"');
//       debugPrint('📦 [LeaveRepo] end_date    : "${leave.endDate}"');
//       debugPrint('📦 [LeaveRepo] total_days  : ${leave.totalDays}');
//       debugPrint('📦 [LeaveRepo] is_half_day : ${leave.isHalfDay}');
//       debugPrint('📦 [LeaveRepo] reason      : "${leave.reason}"');
//       debugPrint('📦 [LeaveRepo] body        : ${bodyValue.isEmpty ? "(empty)" : "${bodyValue.length} chars base64"}');
//       debugPrint('📦 [LeaveRepo] status      : "${leave.status}"');
//       debugPrint('📦 [LeaveRepo] posted      : ${leave.posted}');
//
//       final response = await http
//           .post(
//         uri,
//         headers: {'Accept': 'application/json'},
//       )
//           .timeout(const Duration(seconds: 30));
//
//       debugPrint('📥 [LeaveRepo] QueryParams → ${response.statusCode}: "${response.body}"');
//
//       if (response.statusCode == 200 || response.statusCode == 201) {
//         debugPrint('✅ [LeaveRepo] SUCCESS — data should be in LEAVETABLE_APP');
//         return true;
//       }
//       if (_isDuplicate(response)) return true;
//
//       debugPrint('❌ [LeaveRepo] Unexpected status: ${response.statusCode}');
//       return false;
//     } catch (e) {
//       debugPrint('❌ [LeaveRepo] QueryParams error: $e');
//       return false;
//     }
//   }
//
//   // ─── PUBLIC ────────────────────────────────────────────────────────────────
//
//   Future<Map<String, dynamic>> submitLeave(LeaveModel leave) async {
//     if (leave.empId.isEmpty || leave.empName.isEmpty) {
//       debugPrint('❌ [LeaveRepo] empId or empName is empty — aborting');
//       return {'success': false, 'message': 'Employee info is missing'};
//     }
//
//     final saved = await saveLocally(leave);
//     if (!saved) {
//       return {'success': false, 'message': 'Failed to save locally'};
//     }
//
//     // Try Method 1 first (multipart), then fallback to Method 2 (query params)
//     debugPrint('\n=== [LeaveRepo] METHOD 1: MULTIPART ===');
//     final m1 = await _postMethod1(leave);
//     if (m1) {
//       await markAsPosted(leave.leaveId);
//       return {'success': true, 'message': 'Leave submitted successfully'};
//     }
//
//     debugPrint('\n=== [LeaveRepo] METHOD 2: QUERY PARAMS BACKUP ===');
//     final m2 = await _postMethod2(leave);
//     if (m2) {
//       await markAsPosted(leave.leaveId);
//       return {'success': true, 'message': 'Leave submitted successfully'};
//     }
//
//     return {
//       'success': false,
//       'message': 'Leave saved offline. Will sync when available.',
//     };
//   }
//
//   Future<void> syncUnposted() async {
//     final unposted = await getUnpostedLeaves();
//
//     if (unposted.isEmpty) {
//       debugPrint('ℹ️ [LeaveRepo] No unposted records to sync.');
//       return;
//     }
//
//     debugPrint('🔄 [LeaveRepo] Syncing ${unposted.length} unposted leave(s)…');
//
//     for (final leave in unposted) {
//       // Try Method 1 first
//       debugPrint('\n=== [LeaveRepo] METHOD 1: MULTIPART ===');
//       final m1 = await _postMethod1(leave);
//       if (m1) {
//         await markAsPosted(leave.leaveId);
//         debugPrint('✅ [LeaveRepo] Marked as posted: ${leave.leaveId}');
//         continue;
//       }
//
//       // Fallback to Method 2
//       debugPrint('\n=== [LeaveRepo] METHOD 2: QUERY PARAMS BACKUP ===');
//       final m2 = await _postMethod2(leave);
//       if (m2) {
//         await markAsPosted(leave.leaveId);
//         debugPrint('✅ [LeaveRepo] Marked as posted: ${leave.leaveId}');
//       } else {
//         debugPrint('⚠️ [LeaveRepo] Skipped (will retry later): ${leave.leaveId}');
//       }
//     }
//   }
//
//   // ─── HELPERS ───────────────────────────────────────────────────────────────
//
//   String _buildBase64Body(LeaveModel leave) {
//     if (leave.attachmentData != null && leave.attachmentData!.isNotEmpty) {
//       debugPrint('📎 [LeaveRepo] Using attachmentData: ${leave.attachmentData!.length} bytes');
//       return base64Encode(leave.attachmentData!);
//     }
//     if (leave.attachmentImage != null && leave.attachmentImage!.isNotEmpty) {
//       debugPrint('📎 [LeaveRepo] Using attachmentImage (already base64)');
//       return leave.attachmentImage!;
//     }
//     debugPrint('📎 [LeaveRepo] No attachment');
//     return '';
//   }
//
//   /// Helper — attachment can be Uint8List OR base64 String
//   /// Handles both old (String) and new (Uint8List) model formats
//   Uint8List? _getAttachmentBytes(dynamic attachmentData, dynamic attachmentImage) {
//     // Try attachmentData first (raw bytes)
//     if (attachmentData != null) {
//       if (attachmentData is Uint8List && attachmentData.isNotEmpty) {
//         return attachmentData;
//       }
//       if (attachmentData is List<int> && attachmentData.isNotEmpty) {
//         return Uint8List.fromList(attachmentData);
//       }
//     }
//
//     // Fall back to attachmentImage (base64 string)
//     if (attachmentImage != null && attachmentImage is String && attachmentImage.isNotEmpty) {
//       try {
//         return base64Decode(attachmentImage);
//       } catch (e) {
//         debugPrint('⚠️ [LeaveRepo] Failed to decode base64 attachmentImage: $e');
//         return null;
//       }
//     }
//
//     return null;
//   }
//
//   bool _isDuplicate(http.Response r) {
//     if (r.statusCode == 409 || r.statusCode == 555) {
//       if (r.body.contains('ORA-00001') || r.body.contains('unique constraint')) {
//         debugPrint('⚠️ [LeaveRepo] Duplicate key — treating as posted');
//         return true;
//       }
//     }
//     return false;
//   }
// }

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../Database/db_helper.dart';
import '../Models/leave_model.dart';
import '../Services/remote_config_service.dart';

class LeaveRepository {
  // ✅ UPDATED: Using Remote Config for dynamic URL
  static String get _baseUrl => RemoteConfigService.getLeaveUrl();

  final DBHelper _db = DBHelper();

  Future<bool> saveLocally(LeaveModel leave) async {
    try {
      final result = await _db.insert(DBHelper.leaveTable, leave.toMap());
      debugPrint('✅ [Leave] Saved locally — rows: $result');
      return result > 0;
    } catch (e) {
      debugPrint('❌ [Leave] Local save failed: $e');
      return false;
    }
  }

  Future<List<LeaveModel>> getAllLeaves() async {
    try {
      final rows = await _db.getAll(DBHelper.leaveTable);
      return rows.map((r) => LeaveModel.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<LeaveModel>> getUnpostedLeaves() async {
    try {
      final rows = await _db.getUnposted(DBHelper.leaveTable);
      return rows.map((r) => LeaveModel.fromMap(r)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> markAsPosted(String leaveId) async {
    await _db.markAsPosted(DBHelper.leaveTable, 'leave_id', leaveId);
  }

  // ============================================================
  // METHOD 1: MULTIPART
  // ============================================================

  Future<bool> _postMethod1(LeaveModel leave) async {
    try {
      debugPrint('🌐 [LeaveRepo] Method 1: Multipart → $_baseUrl');

      var request = http.MultipartRequest('POST', Uri.parse(_baseUrl));

      // TEXT FIELDS (UPPER_CASE)
      request.fields['LEAVE_ID'] = leave.leaveId;
      request.fields['EMP_ID'] = leave.empId;
      request.fields['EMP_NAME'] = leave.empName;
      request.fields['LEAVE_TYPE'] = leave.leaveType;
      request.fields['START_DATE'] = leave.startDate;
      request.fields['END_DATE'] = leave.endDate;
      request.fields['TOTAL_DAYS'] = leave.totalDays.toString();
      request.fields['IS_HALF_DAY'] = leave.isHalfDay.toString();
      request.fields['REASON'] = leave.reason;
      request.fields['APPLICATION_DATE'] = leave.applicationDate;
      request.fields['APPLICATION_TIME'] = leave.applicationTime;
      request.fields['STATUS'] = leave.status;
      request.fields['POSTED'] = leave.posted.toString();
      if (leave.company_code != null && leave.company_code!.isNotEmpty) {
        request.fields['COMPANY_CODE'] = leave.company_code!;
      }

      // TEXT FIELDS (lower_case)
      request.fields['leave_id'] = leave.leaveId;
      request.fields['emp_id'] = leave.empId;
      request.fields['emp_name'] = leave.empName;
      request.fields['leave_type'] = leave.leaveType;
      request.fields['start_date'] = leave.startDate;
      request.fields['end_date'] = leave.endDate;
      request.fields['total_days'] = leave.totalDays.toString();
      request.fields['is_half_day'] = leave.isHalfDay.toString();
      request.fields['reason'] = leave.reason;
      request.fields['application_date'] = leave.applicationDate;
      request.fields['application_time'] = leave.applicationTime;
      request.fields['status'] = leave.status;
      request.fields['posted'] = leave.posted.toString();
      if (leave.company_code != null && leave.company_code!.isNotEmpty) {
        request.fields['company_code'] = leave.company_code!;
      }

      // ATTACHMENT IMAGE
      final Uint8List? attachmentBytes = _getAttachmentBytes(leave.attachmentData, leave.attachmentImage);
      if (attachmentBytes != null && attachmentBytes.isNotEmpty) {
        final String filename =
            'attachment_${leave.empId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        request.files.add(http.MultipartFile.fromBytes(
          'ATTACHMENT',
          attachmentBytes,
          filename: filename,
          contentType: MediaType('image', 'jpeg'),
        ));

        request.files.add(http.MultipartFile.fromBytes(
          'attachment',
          attachmentBytes,
          filename: filename,
          contentType: MediaType('image', 'jpeg'),
        ));

        request.files.add(http.MultipartFile.fromBytes(
          'file',
          attachmentBytes,
          filename: filename,
          contentType: MediaType('image', 'jpeg'),
        ));

        debugPrint('📎 [LeaveRepo] Attachment added: $filename (${attachmentBytes.length} bytes)');
      } else {
        debugPrint('📎 [LeaveRepo] No attachment');
      }

      debugPrint('📡 [LeaveRepo] Fields: ${request.fields.length}, Files: ${request.files.length}');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📡 [LeaveRepo] Method1 → ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [LeaveRepo] Method 1 successful!');
        return true;
      }

      if (response.statusCode == 409 || response.statusCode == 555) {
        if (response.body.contains('ORA-00001') ||
            response.body.contains('unique constraint')) {
          debugPrint('⚠️ [LeaveRepo] Duplicate key — marking as posted');
          return true;
        }
      }

      debugPrint('❌ [LeaveRepo] Method 1 failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ [LeaveRepo] Method 1 error: $e');
      return false;
    }
  }

  // ============================================================
  // METHOD 2: QUERY PARAMS (BACKUP)
  // ============================================================

  Future<bool> _postMethod2(LeaveModel leave) async {
    try {
      debugPrint('\n=== [LeaveRepo] METHOD 2: QUERY PARAMS (BACKUP) ===');

      final String bodyValue = _buildBase64Body(leave);

      final params = <String, String>{
        'leave_id': leave.leaveId,
        'emp_id': leave.empId,
        'emp_name': leave.empName,
        'leave_type': leave.leaveType,
        'start_date': leave.startDate,
        'end_date': leave.endDate,
        'total_days': leave.totalDays.toString(),
        'is_half_day': leave.isHalfDay.toString(),
        'reason': leave.reason,
        'body': bodyValue,
        'application_date': leave.applicationDate,
        'application_time': leave.applicationTime,
        'status': leave.status,
        'posted': leave.posted.toString(),
        if (leave.company_code != null && leave.company_code!.isNotEmpty)
          'company_code': leave.company_code!,
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

      debugPrint('📡 [LeaveRepo] URL (truncated): ${uri.toString().substring(0, uri.toString().length > 200 ? 200 : uri.toString().length)}...');
      debugPrint('📦 [LeaveRepo] leave_id    : ${leave.leaveId}');
      debugPrint('📦 [LeaveRepo] emp         : "${leave.empId}" | "${leave.empName}"');
      debugPrint('📦 [LeaveRepo] leave_type  : "${leave.leaveType}"');
      debugPrint('📦 [LeaveRepo] start_date  : "${leave.startDate}"');
      debugPrint('📦 [LeaveRepo] end_date    : "${leave.endDate}"');
      debugPrint('📦 [LeaveRepo] total_days  : ${leave.totalDays}');
      debugPrint('📦 [LeaveRepo] is_half_day : ${leave.isHalfDay}');
      debugPrint('📦 [LeaveRepo] reason      : "${leave.reason}"');
      debugPrint('📦 [LeaveRepo] body        : ${bodyValue.isEmpty ? "(empty)" : "${bodyValue.length} chars base64"}');
      debugPrint('📦 [LeaveRepo] status      : "${leave.status}"');
      debugPrint('📦 [LeaveRepo] posted      : ${leave.posted}');

      final response = await http
          .post(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: RemoteConfigService.getApiTimeout()));

      debugPrint('📥 [LeaveRepo] QueryParams → ${response.statusCode}: "${response.body}"');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ [LeaveRepo] SUCCESS');
        return true;
      }
      if (_isDuplicate(response)) return true;

      debugPrint('❌ [LeaveRepo] Unexpected status: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ [LeaveRepo] QueryParams error: $e');
      return false;
    }
  }

  // ============================================================
  // PUBLIC SUBMIT METHOD
  // ============================================================

  Future<Map<String, dynamic>> submitLeave(LeaveModel leave) async {
    if (leave.empId.isEmpty || leave.empName.isEmpty) {
      debugPrint('❌ [LeaveRepo] empId or empName is empty — aborting');
      return {'success': false, 'message': 'Employee info is missing'};
    }

    final saved = await saveLocally(leave);
    if (!saved) {
      return {'success': false, 'message': 'Failed to save locally'};
    }

    debugPrint('\n=== [LeaveRepo] METHOD 1: MULTIPART ===');
    final m1 = await _postMethod1(leave);
    if (m1) {
      await markAsPosted(leave.leaveId);
      return {'success': true, 'message': 'Leave submitted successfully'};
    }

    debugPrint('\n=== [LeaveRepo] METHOD 2: QUERY PARAMS BACKUP ===');
    final m2 = await _postMethod2(leave);
    if (m2) {
      await markAsPosted(leave.leaveId);
      return {'success': true, 'message': 'Leave submitted successfully'};
    }

    return {
      'success': false,
      'message': 'Leave saved offline. Will sync when available.',
    };
  }

  // ============================================================
  // SYNC UNPOSTED
  // ============================================================

  Future<void> syncUnposted() async {
    final unposted = await getUnpostedLeaves();

    if (unposted.isEmpty) {
      debugPrint('ℹ️ [LeaveRepo] No unposted records to sync.');
      return;
    }

    debugPrint('🔄 [LeaveRepo] Syncing ${unposted.length} unposted leave(s)…');

    for (final leave in unposted) {
      debugPrint('\n=== [LeaveRepo] METHOD 1: MULTIPART ===');
      final m1 = await _postMethod1(leave);
      if (m1) {
        await markAsPosted(leave.leaveId);
        debugPrint('✅ [LeaveRepo] Marked as posted: ${leave.leaveId}');
        continue;
      }

      debugPrint('\n=== [LeaveRepo] METHOD 2: QUERY PARAMS BACKUP ===');
      final m2 = await _postMethod2(leave);
      if (m2) {
        await markAsPosted(leave.leaveId);
        debugPrint('✅ [LeaveRepo] Marked as posted: ${leave.leaveId}');
      } else {
        debugPrint('⚠️ [LeaveRepo] Skipped (will retry later): ${leave.leaveId}');
      }
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _buildBase64Body(LeaveModel leave) {
    if (leave.attachmentData != null && leave.attachmentData!.isNotEmpty) {
      debugPrint('📎 [LeaveRepo] Using attachmentData: ${leave.attachmentData!.length} bytes');
      return base64Encode(leave.attachmentData!);
    }
    if (leave.attachmentImage != null && leave.attachmentImage!.isNotEmpty) {
      debugPrint('📎 [LeaveRepo] Using attachmentImage (already base64)');
      return leave.attachmentImage!;
    }
    debugPrint('📎 [LeaveRepo] No attachment');
    return '';
  }

  Uint8List? _getAttachmentBytes(dynamic attachmentData, dynamic attachmentImage) {
    if (attachmentData != null) {
      if (attachmentData is Uint8List && attachmentData.isNotEmpty) {
        return attachmentData;
      }
      if (attachmentData is List<int> && attachmentData.isNotEmpty) {
        return Uint8List.fromList(attachmentData);
      }
    }

    if (attachmentImage != null && attachmentImage is String && attachmentImage.isNotEmpty) {
      try {
        return base64Decode(attachmentImage);
      } catch (e) {
        debugPrint('⚠️ [LeaveRepo] Failed to decode base64 attachmentImage: $e');
        return null;
      }
    }

    return null;
  }

  bool _isDuplicate(http.Response r) {
    if (r.statusCode == 409 || r.statusCode == 555) {
      if (r.body.contains('ORA-00001') || r.body.contains('unique constraint')) {
        debugPrint('⚠️ [LeaveRepo] Duplicate key — treating as posted');
        return true;
      }
    }
    return false;
  }
}