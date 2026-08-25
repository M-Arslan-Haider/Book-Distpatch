

import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import '../../AppColors.dart';
import 'followup_model.dart';
import 'visit_model.dart';

class FollowupViewModel extends GetxController {
  static const String _prefsKey = 'gps_followups_v1';

  // ── API Endpoints ─────────────────────────────────────────────────────
  static const String _followupsPostEndpoint = 'http://oracle.metaxperts.net/ords/gps_workforce/cvfollowups/post/';
  static const String _followupsUpdateEndpoint = 'http://oracle.metaxperts.net/ords/gps_workforce/cvfollowupupdate/put/';

  static String getFollowupsGetUrl(String empId, String companyCode) {
    return 'http://oracle.metaxperts.net/ords/gps_workforce/cvfollowupget/get/$empId/$companyCode';
  }

  // ── Employee Info ────────────────────────────────────────────────────
  final RxString empId = ''.obs;
  final RxString empName = ''.obs;
  final RxString companyCode = ''.obs;
  final RxBool isEmployeeLoaded = false.obs;

  // ── Data ─────────────────────────────────────────────────────────────
  final RxList<FollowupModel> followups = <FollowupModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // ── List UI state ────────────────────────────────────────────────────
  final RxString searchQuery = ''.obs;
  final RxString subTab = 'Today'.obs;

  // ── Connectivity ─────────────────────────────────────────────────────
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  // ── Getter for user initials ────────────────────────────────────────
  String get initials {
    final n = empName.value.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return n[0].toUpperCase();
  }

  // ── Helper: Check if online ─────────────────────────────────────────
  Future<bool> _isOnline() async {
    try {
      final r = await _connectivity.checkConnectivity();
      return r.isNotEmpty && r.any((x) => x != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _init();

    // ✅ Internet wapas ane par pending followups auto sync ho jayen
    _connSub = _connectivity.onConnectivityChanged.listen((results) async {
      final online = results.isNotEmpty && results.any((x) => x != ConnectivityResult.none);
      if (online) {
        debugPrint('🌐 [FollowupVM] Internet restored — auto-syncing pending followups');
        await retryUnsyncedFollowups();
        await fetchFollowupsFromServer();
      }
    });
  }

  @override
  void onClose() {
    _connSub?.cancel();
    super.onClose();
  }

  Future<void> _init() async {
    await _loadEmployee();

    final online = await _isOnline();

    if (!online) {
      debugPrint('📴 [FollowupVM] Offline at startup — loading from local cache only');
      await _loadSaved();
      return;
    }

    if (empId.value.isNotEmpty && companyCode.value.isNotEmpty) {
      await fetchFollowupsFromServer();
      await retryUnsyncedFollowups();
    } else {
      await _loadSaved();
    }
  }

  Future<void> _loadEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    empId.value = prefs.getString('userId') ??
        prefs.getString('user_id') ??
        prefs.getString('emp_id') ??
        prefs.getString('empId') ??
        prefs.getString('employee_id') ??
        prefs.getString('employeeId') ??
        '';

    empName.value = prefs.getString('userName') ??
        prefs.getString('user_name') ??
        prefs.getString('name') ??
        prefs.getString('full_name') ??
        prefs.getString('fullName') ??
        '';

    companyCode.value = prefs.getString('companyCode') ??
        prefs.getString('company_code') ??
        '';

    isEmployeeLoaded.value = empId.value.isNotEmpty && empName.value.isNotEmpty;

    debugPrint('👤 [FollowupVM] empId="${empId.value}" empName="${empName.value}" companyCode="${companyCode.value}"');
  }

  /// ── FETCH FROM SERVER ──────────────────────────────────────────────
  Future<void> fetchFollowupsFromServer() async {
    if (empId.value.isEmpty || companyCode.value.isEmpty) {
      debugPrint('⚠️ [FollowupVM] Cannot fetch: empId or companyCode missing');
      await _loadSaved();
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final uri = Uri.parse(getFollowupsGetUrl(empId.value, companyCode.value));
      debugPrint('📤 [FollowupVM] GET: $uri');

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [FollowupVM] GET Response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? data as List? ?? [];

        debugPrint('📥 [FollowupVM] Items count: ${items.length}');

        // ✅ Parse API followups
        final apiFollowups = items.map((e) => _fromServerJson(e)).toList();
        debugPrint('📥 [FollowupVM] Parsed ${apiFollowups.length} followups from API');

        // ✅ Keep local unsynced followups (posted == false)
        final localUnsynced = followups.where((f) => !f.posted).toList();
        debugPrint('📥 [FollowupVM] Local unsynced: ${localUnsynced.length}');

        // ✅ Merge: API followups + local unsynced
        final merged = [...apiFollowups];
        for (final local in localUnsynced) {
          final exists = merged.any((api) => api.fuNo == local.fuNo);
          if (!exists) {
            merged.add(local);
          }
        }

        followups.assignAll(merged);
        await _persist();
        debugPrint('✅ [FollowupVM] Loaded ${apiFollowups.length} from API + ${localUnsynced.length} offline = ${merged.length} total');
      } else {
        errorMessage.value = 'Server error: ${response.statusCode}';
        debugPrint('⚠️ [FollowupVM] GET failed: ${response.statusCode}');
        await _loadSaved();
      }
    } on TimeoutException {
      errorMessage.value = 'Connection timed out. Showing cached data.';
      debugPrint('⌛ [FollowupVM] GET timed out');
      await _loadSaved();
    } catch (e) {
      errorMessage.value = 'Failed to load followups. Please check your connection.';
      debugPrint('❌ [FollowupVM] GET error: $e');
      await _loadSaved();
    } finally {
      isLoading.value = false;
    }
  }

  /// ✅ Parse server JSON to FollowupModel
  // ── Update _fromServerJson to include rating ──────────────────────────
  FollowupModel _fromServerJson(Map<String, dynamic> j) {
    return FollowupModel(
      id: j['followup_id']?.toString() ?? const Uuid().v4(),
      fuNo: j['followup_no']?.toString() ?? '',
      companyCode: j['company_code']?.toString() ?? companyCode.value,
      visitNo: j['visit_no']?.toString(),
      visitId: j['visit_id']?.toString(),
      customer: j['customer_name']?.toString() ?? '',
      mobile: j['mobile']?.toString() ?? '',
      empId: j['emp_id']?.toString() ?? empId.value,
      empName: j['emp_name']?.toString() ?? empName.value,
      date: j['followup_date']?.toString() ?? '',
      time: j['followup_time']?.toString() ?? '',
      method: j['method']?.toString() ?? 'Phone Call',
      priority: j['priority']?.toString() ?? 'Medium',
      reminder: j['reminder']?.toString() ?? '1 Hour Before',
      purpose: j['purpose']?.toString() ?? '',
      notes: j['notes']?.toString() ?? '',
      status: j['status']?.toString() ?? 'Pending',
      result: j['result']?.toString(),
      resultResponse: j['result_response']?.toString(),
      resultRemarks: j['result_remarks']?.toString(),
      nextFuNo: j['next_fu_id']?.toString(),
      rating: j['rating']?.toString(),  // ✅ NEW
      posted: true,
    );
  }

  /// ── LOAD FROM CACHE ────────────────────────────────────────────────
  Future<void> _loadSaved() async {
    isLoading.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        followups.assignAll(list.map((e) => FollowupModel.fromJson(e)).toList());
        debugPrint('📂 [FollowupVM] Loaded ${followups.length} followups from cache');
      } else {
        debugPrint('📂 [FollowupVM] No cached followups found');
      }
    } catch (e) {
      debugPrint('❌ [FollowupVM] load error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// ✅ Public persist method for manual save
  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(followups.map((f) => f.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(followups.map((f) => f.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  // ── Tabs / filtering ─────────────────────────────────────────────────
  static String _todayIso() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool _matchesTab(FollowupModel f, String tab) {
    final today = _todayIso();
    switch (tab) {
      case 'Today':
        return f.date == today && f.status == 'Pending';
      case 'Upcoming':
        return f.date.compareTo(today) > 0 && (f.status == 'Pending' || f.status == 'Rescheduled');
      case 'Completed':
        return f.status == 'Completed';
      case 'Missed':
        return f.status == 'Missed' || f.isOverdue;
      case 'Rescheduled':
        return f.status == 'Rescheduled';
      case 'All':
      default:
        return true;
    }
  }

  int countByTab(String tab) => followups.where((f) => _matchesTab(f, tab)).length;

  int get dueTodayCount => countByTab('Today') + countByTab('Missed');

  List<FollowupModel> get filtered {
    var rows = followups.where((f) => _matchesTab(f, subTab.value)).toList();
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows
          .where((f) =>
      f.customer.toLowerCase().contains(q) ||
          f.mobile.toLowerCase().contains(q) ||
          f.fuNo.toLowerCase().contains(q))
          .toList();
    }
    rows.sort((a, b) => ('${a.date}${a.time}').compareTo('${b.date}${b.time}'));
    return rows;
  }

  void setSearch(String q) => searchQuery.value = q;
  void setSubTab(String t) => subTab.value = t;

  // ── Numbering ─────────────────────────────────────────────────────────
  String _peekFuNo() {
    final year = DateTime.now().year;
    final next = followups.length + 1;
    return 'FU-$year-${next.toString().padLeft(4, '0')}';
  }

  FollowupModel buildDraft({FollowupModel? editing, VisitModel? presetVisit}) {
    if (editing != null) return editing;
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final f = FollowupModel(
      id: const Uuid().v4(),
      fuNo: _peekFuNo(),
      companyCode: companyCode.value,
      date: DateFormat('yyyy-MM-dd').format(tomorrow),
      time: '11:00',
    );
    if (presetVisit != null) {
      f.visitNo = presetVisit.visitNo;
      f.visitId = presetVisit.dbVisitId;
      f.customer = presetVisit.customer;
      f.mobile = presetVisit.mobile;
      f.empId = presetVisit.empId;
      f.empName = presetVisit.empName;
      f.purpose = 'Follow-up visit — ${presetVisit.project}';
      f.method = presetVisit.visitType == 'Site Visit' ? 'Site Visit' : 'Phone Call';
    } else {
      f.empId = empId.value;
      f.empName = empName.value;
    }
    return f;
  }

  Future<void> autoCreateFromVisit(VisitModel v) async {
    if (v.fuDate.isEmpty) return;
    final exists = followups.any((f) =>
    f.visitNo == v.visitNo && (f.status == 'Pending' || f.status == 'Rescheduled'));
    if (exists) return;

    if (v.dbVisitId == null || v.dbVisitId!.isEmpty) {
      debugPrint('⚠️ [FollowupVM] Visit not synced yet, skipping auto-create follow-up');
      return;
    }

    final f = FollowupModel(
      id: const Uuid().v4(),
      fuNo: _peekFuNo(),
      companyCode: companyCode.value,
      visitNo: v.visitNo,
      visitId: v.dbVisitId,
      customer: v.customer,
      mobile: v.mobile,
      empId: v.empId,
      empName: v.empName,
      date: v.fuDate,
      time: v.fuTime.isEmpty ? '11:00' : v.fuTime,
      method: v.visitType == 'Site Visit' ? 'Site Visit' : 'Phone Call',
      priority: 'Medium',
      reminder: '1 Hour Before',
      purpose: 'Follow-up visit — ${v.project}',
    );
    followups.insert(0, f);
    await _persist();

    final online = await _isOnline();
    if (!online) {
      debugPrint('📴 [FollowupVM] Offline — followup saved locally only: ${f.fuNo}');
      return;
    }

    final synced = await _postToApex(f);
    if (synced) {
      f.posted = true;
      final idx = followups.indexWhere((x) => x.id == f.id);
      if (idx != -1) followups[idx] = f;
      await _persist();
    }
  }

  // ── UPDATE Followup (PUT) ──────────────────────────────────────────
  /// ✅ Update existing followup on server using PUT
  // ── Update updateFollowup to include rating ──────────────────────────
  Future<bool> updateFollowup(FollowupModel f) async {
    try {
      final DateFormat oracleDateFormat = DateFormat('yyyy-MM-dd');

      DateTime? followupDate;
      try {
        followupDate = DateTime.parse(f.date);
      } catch (e) {
        try {
          followupDate = DateFormat('yyyy-MM-dd').parse(f.date);
        } catch (e2) {
          debugPrint('❌ [FollowupVM] Could not parse date: ${f.date}');
          return false;
        }
      }

      final String formattedDate = oracleDateFormat.format(followupDate!);

      final Map<String, dynamic> requestBody = {
        'followup_id': f.id,
        'followup_date': formattedDate,
        'followup_time': f.time,
        'customer_name': f.customer,
        'mobile': f.mobile,
        'emp_id': f.empId,
        'emp_name': f.empName,
        'company_code': f.companyCode ?? '',
        'method': f.method,
        'purpose': f.purpose,
        'priority': f.priority,
        'status': f.status,
        'reminder': f.reminder,
        'notes': f.notes,
        'result': f.result,
        'result_response': f.resultResponse,
        'result_remarks': f.resultRemarks,
        'rating': f.rating,  // ✅ NEW
        'reschedule_count': f.status == 'Rescheduled' ? 1 : 0,
        'edit_count': 0,
      };

      if (f.visitId != null && f.visitId!.isNotEmpty) {
        requestBody['visit_id'] = f.visitId;
      }
      if (f.leadNo != null && f.leadNo!.isNotEmpty) {
        requestBody['lead_id'] = f.leadNo;
      }
      if (f.nextFuNo != null && f.nextFuNo!.isNotEmpty) {
        requestBody['next_fu_id'] = f.nextFuNo;
      }

      requestBody.removeWhere((key, value) => value == null || value.toString().isEmpty);

      debugPrint('📤 [FollowupVM] UPDATE (PUT) to APEX: $requestBody');

      final response = await http
          .put(
        Uri.parse(_followupsUpdateEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [FollowupVM] UPDATE Response (${response.statusCode}): ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final responseData = jsonDecode(response.body);
          if (responseData is Map<String, dynamic>) {
            if (responseData['status'] == 'success') {
              final data = responseData['data'] as Map<String, dynamic>?;
              if (data != null) {
                if (data['followup_no'] != null) {
                  f.fuNo = data['followup_no']?.toString() ?? f.fuNo;
                }
                if (data['followup_id'] != null) {
                  f.id = data['followup_id']?.toString() ?? f.id;
                }
              }
              return true;
            }
          }
        } catch (e) {
          debugPrint('⚠️ [FollowupVM] Could not parse PUT response: $e');
          return true;
        }
        return true;
      } else {
        debugPrint('⚠️ [FollowupVM] PUT failed (${response.statusCode}): ${response.body}');
        return false;
      }
    } on TimeoutException {
      debugPrint('⌛ [FollowupVM] PUT timed out for ${f.fuNo}');
      return false;
    } catch (e) {
      debugPrint('❌ [FollowupVM] PUT error: $e');
      return false;
    }
  }

  // ── CRUD ─────────────────────────────────────────────────────────────
  Future<void> saveFollowup(FollowupModel f, {required bool isNew}) async {
    // Local-first: always keep working offline.
    if (isNew) {
      followups.insert(0, f);
    } else {
      final idx = followups.indexWhere((x) => x.id == f.id);
      if (idx != -1) followups[idx] = f;
    }
    await _persist();

    final online = await _isOnline();

    if (!online) {
      debugPrint('📴 [FollowupVM] Offline — followup saved locally only: ${f.fuNo}');
      Get.snackbar(
        'Saved Offline',
        'Follow-up saved on device. It will sync automatically when you\'re back online.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
      );
      return;
    }

    // ✅ Check if this is an existing followup (posted == true) -> UPDATE
    if (f.posted && f.id.isNotEmpty) {
      final updated = await updateFollowup(f);
      if (updated) {
        f.posted = true;
        final idx = followups.indexWhere((x) => x.id == f.id);
        if (idx != -1) followups[idx] = f;
        await _persist();

        Get.snackbar(
          'Success',
          'Follow-up updated on server: ${f.fuNo}',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.tealDark,
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Warning',
          'Follow-up saved locally but not synced to server.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.warning,
          colorText: Colors.white,
        );
      }
      return;
    }

    // ✅ NEW followup: POST (INSERT)
    final synced = await _postToApex(f);
    if (synced) {
      f.posted = true;
      final idx = followups.indexWhere((x) => x.id == f.id);
      if (idx != -1) followups[idx] = f;
      await _persist();

      Get.snackbar(
        'Success',
        'Follow-up synced to server: ${f.fuNo}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.tealDark,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Warning',
        'Follow-up saved locally but not synced to server.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
      );
    }
  }

  // ── Update _postToApex to include rating ─────────────────────────────
  Future<bool> _postToApex(FollowupModel f) async {
    try {
      final DateFormat oracleDateFormat = DateFormat('yyyy-MM-dd');

      DateTime? followupDate;
      try {
        followupDate = DateTime.parse(f.date);
      } catch (e) {
        try {
          followupDate = DateFormat('yyyy-MM-dd').parse(f.date);
        } catch (e2) {
          debugPrint('❌ [FollowupVM] Could not parse date: ${f.date}');
          return false;
        }
      }

      final String formattedDate = oracleDateFormat.format(followupDate!);

      final Map<String, dynamic> requestBody = {
        'followup_date': formattedDate,
        'followup_time': f.time,
        'customer_name': f.customer,
        'mobile': f.mobile,
      };

      if (f.visitId != null && f.visitId!.isNotEmpty) {
        requestBody['visit_id'] = f.visitId;
      } else {
        debugPrint('⚠️ [FollowupVM] No visit_id found for follow-up: ${f.fuNo}');
        return false;
      }

      if (f.empId.isNotEmpty) requestBody['emp_id'] = f.empId;
      if (f.empName.isNotEmpty) requestBody['emp_name'] = f.empName;
      if (f.companyCode != null && f.companyCode!.isNotEmpty) requestBody['company_code'] = f.companyCode;
      if (f.method.isNotEmpty) requestBody['method'] = f.method;
      if (f.purpose.isNotEmpty) requestBody['purpose'] = f.purpose;
      if (f.priority.isNotEmpty) requestBody['priority'] = f.priority;
      if (f.status.isNotEmpty) requestBody['status'] = f.status;
      if (f.reminder.isNotEmpty) requestBody['reminder'] = f.reminder;
      if (f.notes.isNotEmpty) requestBody['notes'] = f.notes;
      if (f.result != null && f.result!.isNotEmpty) requestBody['result'] = f.result;
      if (f.resultResponse != null && f.resultResponse!.isNotEmpty) requestBody['result_response'] = f.resultResponse;
      if (f.resultRemarks != null && f.resultRemarks!.isNotEmpty) requestBody['result_remarks'] = f.resultRemarks;
      if (f.rating != null && f.rating!.isNotEmpty) requestBody['rating'] = f.rating;  // ✅ NEW
      if (f.leadNo != null && f.leadNo!.isNotEmpty) requestBody['lead_id'] = f.leadNo;
      if (f.nextFuNo != null && f.nextFuNo!.isNotEmpty) requestBody['next_fu_id'] = f.nextFuNo;

      requestBody['reschedule_count'] = f.status == 'Rescheduled' ? 1 : 0;
      requestBody['edit_count'] = 0;

      requestBody.removeWhere((key, value) => value == null || value.toString().isEmpty);

      debugPrint('📤 [FollowupVM] POST to APEX: $requestBody');

      final response = await http
          .post(
        Uri.parse(_followupsPostEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [FollowupVM] APEX Response (${response.statusCode}): ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final responseData = jsonDecode(response.body);
          if (responseData is Map<String, dynamic>) {
            final data = responseData['data'] as Map<String, dynamic>?;
            if (data != null) {
              if (data['followup_no'] != null) {
                f.fuNo = data['followup_no']?.toString() ?? f.fuNo;
                debugPrint('✅ [FollowupVM] APEX followup_no: ${f.fuNo}');
              }
              if (data['followup_id'] != null) {
                f.id = data['followup_id']?.toString() ?? f.id;
                debugPrint('✅ [FollowupVM] APEX followup_id: ${f.id}');
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ [FollowupVM] Could not parse APEX response: $e');
        }
        return true;
      } else {
        debugPrint('⚠️ [FollowupVM] APEX send failed (${response.statusCode}): ${response.body}');
        return false;
      }
    } on TimeoutException {
      debugPrint('⌛ [FollowupVM] APEX send timed out for ${f.fuNo}');
      return false;
    } catch (e) {
      debugPrint('❌ [FollowupVM] APEX send error: $e');
      return false;
    }
  }

  /// Retry sending any unsynced followups
  Future<void> retryUnsyncedFollowups() async {
    final online = await _isOnline();
    if (!online) {
      debugPrint('📴 [FollowupVM] Offline — cannot retry unsynced followups');
      return;
    }

    final unsynced = followups.where((f) => !f.posted).toList();
    if (unsynced.isEmpty) return;

    for (final f in unsynced) {
      final synced = await _postToApex(f);
      if (synced) {
        f.posted = true;
        final idx = followups.indexWhere((x) => x.id == f.id);
        if (idx != -1) followups[idx] = f;
        await _persist();
      }
    }

    await fetchFollowupsFromServer();
  }

  /// ✅ Complete Follow-up (Status: Completed)
  // ── Update completeFollowup method with rating ──────────────────────
  /// ✅ Complete Follow-up (Status: Completed) with Rating
  Future<void> completeFollowup(String id, {
    String? result,
    String? response,
    String? remarks,
    String? rating,  // ✅ NEW
  }) async {
    final idx = followups.indexWhere((f) => f.id == id);
    if (idx == -1) {
      Get.snackbar('Error', 'Follow-up not found',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.error,
          colorText: Colors.white);
      return;
    }

    final f = followups[idx];
    f.status = 'Completed';
    f.result = result ?? 'Successful';
    f.resultResponse = response;
    f.resultRemarks = remarks;
    f.rating = rating;  // ✅ NEW
    f.posted = false; // Mark as unsynced

    followups[idx] = f;
    await _persist();

    final online = await _isOnline();

    if (!online) {
      debugPrint('📴 [FollowupVM] Offline — followup completed locally: ${f.fuNo}');
      Get.snackbar(
        'Saved Offline',
        'Follow-up completed locally. Will sync when online.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
      );
      return;
    }

    final synced = await updateFollowup(f);
    if (synced) {
      f.posted = true;
      followups[idx] = f;
      await _persist();
      Get.snackbar(
        '✅ Completed',
        'Follow-up ${f.fuNo} marked as completed${rating != null ? ' with $rating rating' : ''}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.greenDotDk,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Warning',
        'Follow-up completed locally but not synced to server.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
      );
    }
  }

  /// ✅ Cancel Follow-up (Status: Cancelled)
  Future<void> cancelFollowup(String id, {String? remarks}) async {
    final idx = followups.indexWhere((f) => f.id == id);
    if (idx == -1) {
      Get.snackbar('Error', 'Follow-up not found',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.error,
          colorText: Colors.white);
      return;
    }

    final f = followups[idx];
    f.status = 'Cancelled';
    f.resultRemarks = remarks ?? 'Cancelled by user';
    f.posted = false; // Mark as unsynced

    followups[idx] = f;
    await _persist();

    final online = await _isOnline();

    if (!online) {
      debugPrint('📴 [FollowupVM] Offline — followup cancelled locally: ${f.fuNo}');
      Get.snackbar(
        'Saved Offline',
        'Follow-up cancelled locally. Will sync when online.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
      );
      return;
    }

    final synced = await updateFollowup(f);
    if (synced) {
      f.posted = true;
      followups[idx] = f;
      await _persist();
      Get.snackbar(
        '❌ Cancelled',
        'Follow-up ${f.fuNo} cancelled',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.textSecondary,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Warning',
        'Follow-up cancelled locally but not synced to server.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
      );
    }
  }

  Future<void> reschedule(String id, {required String date, required String time, required String reason}) async {
    final idx = followups.indexWhere((f) => f.id == id);
    if (idx == -1) return;
    final f = followups[idx];
    f.date = date;
    f.time = time;
    f.status = 'Rescheduled';
    f.posted = false;
    followups[idx] = f;
    await _persist();

    final online = await _isOnline();
    if (!online) {
      debugPrint('📴 [FollowupVM] Offline — reschedule saved locally');
      Get.snackbar(
        'Saved Offline',
        'Follow-up rescheduled locally. Will sync when online.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
      );
      return;
    }

    final synced = await updateFollowup(f);
    if (synced) {
      f.posted = true;
      followups[idx] = f;
      await _persist();
    }
  }

  Future<void> deleteFollowup(String id) async {
    followups.removeWhere((f) => f.id == id);
    await _persist();
  }
}