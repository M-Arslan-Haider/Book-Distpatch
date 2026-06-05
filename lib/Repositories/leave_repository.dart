// ignore_for_file: commented_out_code
// (old methods kept as reference above the active class — unchanged)

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../Database/db_helper.dart';
import '../Models/leave_model.dart';
import '../Services/remote_config_service.dart';

class LeaveRepository {
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
      request.fields['LEAVE_ID']          = leave.leaveId;
      request.fields['EMP_ID']            = leave.empId;
      request.fields['EMP_NAME']          = leave.empName;
      request.fields['LEAVE_TYPE']        = leave.leaveType;
      request.fields['START_DATE']        = leave.startDate;
      request.fields['END_DATE']          = leave.endDate;
      request.fields['TOTAL_DAYS']        = leave.totalDays.toString();
      request.fields['IS_HALF_DAY']       = leave.isHalfDay.toString();
      request.fields['REASON']            = leave.reason;
      request.fields['APPLICATION_DATE']  = leave.applicationDate;
      request.fields['APPLICATION_TIME']  = leave.applicationTime;
      request.fields['STATUS']            = leave.status;
      request.fields['POSTED']            = leave.posted.toString();
      if (leave.company_code != null && leave.company_code!.isNotEmpty) {
        request.fields['COMPANY_CODE']    = leave.company_code!;
      }
      // ── NEW: half-day times (UPPER_CASE) ──────────────────────────────────
      if (leave.halfDayStartTime != null && leave.halfDayStartTime!.isNotEmpty) {
        request.fields['HALF_DAY_START_TIME'] = leave.halfDayStartTime!;
      }
      if (leave.halfDayEndTime != null && leave.halfDayEndTime!.isNotEmpty) {
        request.fields['HALF_DAY_END_TIME']   = leave.halfDayEndTime!;
      }

      // TEXT FIELDS (lower_case)
      request.fields['leave_id']          = leave.leaveId;
      request.fields['emp_id']            = leave.empId;
      request.fields['emp_name']          = leave.empName;
      request.fields['leave_type']        = leave.leaveType;
      request.fields['start_date']        = leave.startDate;
      request.fields['end_date']          = leave.endDate;
      request.fields['total_days']        = leave.totalDays.toString();
      request.fields['is_half_day']       = leave.isHalfDay.toString();
      request.fields['reason']            = leave.reason;
      request.fields['application_date']  = leave.applicationDate;
      request.fields['application_time']  = leave.applicationTime;
      request.fields['status']            = leave.status;
      request.fields['posted']            = leave.posted.toString();
      if (leave.company_code != null && leave.company_code!.isNotEmpty) {
        request.fields['company_code']    = leave.company_code!;
      }
      // ── NEW: half-day times (lower_case) ──────────────────────────────────
      if (leave.halfDayStartTime != null && leave.halfDayStartTime!.isNotEmpty) {
        request.fields['half_day_start_time'] = leave.halfDayStartTime!;
      }
      if (leave.halfDayEndTime != null && leave.halfDayEndTime!.isNotEmpty) {
        request.fields['half_day_end_time']   = leave.halfDayEndTime!;
      }

      // ATTACHMENT IMAGE
      final Uint8List? attachmentBytes =
      _getAttachmentBytes(leave.attachmentData, leave.attachmentImage);
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
        'leave_id':         leave.leaveId,
        'emp_id':           leave.empId,
        'emp_name':         leave.empName,
        'leave_type':       leave.leaveType,
        'start_date':       leave.startDate,
        'end_date':         leave.endDate,
        'total_days':       leave.totalDays.toString(),
        'is_half_day':      leave.isHalfDay.toString(),
        'reason':           leave.reason,
        'body':             bodyValue,
        'application_date': leave.applicationDate,
        'application_time': leave.applicationTime,
        'status':           leave.status,
        'posted':           leave.posted.toString(),
        if (leave.company_code != null && leave.company_code!.isNotEmpty)
          'company_code':   leave.company_code!,
        // ── NEW: half-day times ────────────────────────────────────────────
        if (leave.halfDayStartTime != null && leave.halfDayStartTime!.isNotEmpty)
          'half_day_start_time': leave.halfDayStartTime!,
        if (leave.halfDayEndTime != null && leave.halfDayEndTime!.isNotEmpty)
          'half_day_end_time':   leave.halfDayEndTime!,
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

      debugPrint('📡 [LeaveRepo] URL (truncated): ${uri.toString().substring(0, uri.toString().length > 200 ? 200 : uri.toString().length)}...');
      debugPrint('📦 [LeaveRepo] leave_id          : ${leave.leaveId}');
      debugPrint('📦 [LeaveRepo] emp               : "${leave.empId}" | "${leave.empName}"');
      debugPrint('📦 [LeaveRepo] leave_type        : "${leave.leaveType}"');
      debugPrint('📦 [LeaveRepo] start_date        : "${leave.startDate}"');
      debugPrint('📦 [LeaveRepo] end_date          : "${leave.endDate}"');
      debugPrint('📦 [LeaveRepo] total_days        : ${leave.totalDays}');
      debugPrint('📦 [LeaveRepo] is_half_day       : ${leave.isHalfDay}');
      debugPrint('📦 [LeaveRepo] half_day_start    : "${leave.halfDayStartTime}"');
      debugPrint('📦 [LeaveRepo] half_day_end      : "${leave.halfDayEndTime}"');
      debugPrint('📦 [LeaveRepo] reason            : "${leave.reason}"');
      debugPrint('📦 [LeaveRepo] body              : ${bodyValue.isEmpty ? "(empty)" : "${bodyValue.length} chars base64"}');
      debugPrint('📦 [LeaveRepo] status            : "${leave.status}"');
      debugPrint('📦 [LeaveRepo] posted            : ${leave.posted}');

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

    if (attachmentImage != null &&
        attachmentImage is String &&
        attachmentImage.isNotEmpty) {
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
      if (r.body.contains('ORA-00001') ||
          r.body.contains('unique constraint')) {
        debugPrint('⚠️ [LeaveRepo] Duplicate key — treating as posted');
        return true;
      }
    }
    return false;
  }
}