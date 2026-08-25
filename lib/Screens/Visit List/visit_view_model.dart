
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../AppColors.dart';
import 'visit_model.dart';

class VisitViewModel extends GetxController {
  static const String _prefsKey = 'gps_visits_v1';
  static const String _idCounterKey = 'gps_visit_id_counter';

  // ── API Endpoints ─────────────────────────────────────────────────────
  static const String _visitsPostEndpoint = 'http://oracle.metaxperts.net/ords/gps_workforce/cvvisits/post/';
  static const String _visitsUpdateEndpoint = 'http://oracle.metaxperts.net/ords/gps_workforce/cvvisitupdate/put/';

  static String getVisitsGetUrl(String empId, String companyCode) {
    return 'http://oracle.metaxperts.net/ords/gps_workforce/cvvisitget/get/$empId/$companyCode';
  }

  final ImagePicker _picker = ImagePicker();

  // ── Employee Info ─────────────────────────────────────────────────────
  final RxString empId = ''.obs;
  final RxString empName = ''.obs;
  final RxString companyCode = ''.obs;
  final RxBool isEmployeeLoaded = false.obs;

  // ── Data ─────────────────────────────────────────────────────────────
  final RxList<VisitModel> visits = <VisitModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // ── List UI state ────────────────────────────────────────────────────
  final RxString searchQuery = ''.obs;
  final RxString statusFilter = 'All'.obs;

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

    // ✅ Internet wapas ane par pending visits auto sync ho jayen
    _connSub = _connectivity.onConnectivityChanged.listen((results) async {
      final online = results.isNotEmpty && results.any((x) => x != ConnectivityResult.none);
      if (online) {
        debugPrint('🌐 [VisitVM] Internet restored — auto-syncing pending visits');
        await retryUnsyncedVisits();
        await fetchVisitsFromServer();
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
      debugPrint('📴 [VisitVM] Offline at startup — loading from local cache only');
      await _loadSaved();
      return;
    }

    if (empId.value.isNotEmpty && companyCode.value.isNotEmpty) {
      await fetchVisitsFromServer();
      await retryUnsyncedVisits();
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

    debugPrint('👤 [VisitVM] empId="${empId.value}" empName="${empName.value}" companyCode="${companyCode.value}"');
  }

  /// ── FETCH FROM SERVER ──────────────────────────────────────────────
  Future<void> fetchVisitsFromServer() async {
    if (empId.value.isEmpty || companyCode.value.isEmpty) {
      debugPrint('⚠️ [VisitVM] Cannot fetch: empId or companyCode missing');
      await _loadSaved();
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final uri = Uri.parse(getVisitsGetUrl(empId.value, companyCode.value));
      debugPrint('📤 [VisitVM] GET: $uri');

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [VisitVM] GET Response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? data as List? ?? [];

        // ✅ Parse API visits
        final apiVisits = items.map((e) => _fromServerJson(e)).toList();

        // ✅ Keep local unsynced visits (posted == false)
        final localUnsynced = visits.where((v) => !v.posted).toList();

        // ✅ Merge: API visits + local unsynced
        final merged = [...apiVisits];
        for (final local in localUnsynced) {
          final exists = merged.any((api) => api.visitNo == local.visitNo);
          if (!exists) {
            merged.add(local);
          }
        }

        visits.assignAll(merged);
        await _persist();
        debugPrint('✅ [VisitVM] Loaded ${apiVisits.length} from API + ${localUnsynced.length} offline = ${merged.length} total');
      } else {
        errorMessage.value = 'Server error: ${response.statusCode}';
        debugPrint('⚠️ [VisitVM] GET failed: ${response.statusCode}');
        await _loadSaved();
      }
    } on TimeoutException {
      errorMessage.value = 'Connection timed out. Showing cached data.';
      debugPrint('⌛ [VisitVM] GET timed out');
      await _loadSaved();
    } catch (e) {
      errorMessage.value = 'Failed to load visits. Please check your connection.';
      debugPrint('❌ [VisitVM] GET error: $e');
      await _loadSaved();
    } finally {
      isLoading.value = false;
    }
  }

  VisitModel _fromServerJson(Map<String, dynamic> j) {
    return VisitModel(
      id: j['visit_id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      visitNo: j['visit_no']?.toString() ?? '',
      dbVisitId: j['visit_id']?.toString(),
      companyCode: j['company_code']?.toString() ?? companyCode.value,
      date: j['visit_date']?.toString() ?? '',
      time: j['visit_time']?.toString() ?? '',
      empId: j['emp_id']?.toString() ?? empId.value,
      empName: j['emp_name']?.toString() ?? empName.value,
      visitType: j['visit_type']?.toString() ?? 'Site Visit',
      status: j['status']?.toString() ?? 'Planned',
      customerId: j['customer_id']?.toString() ?? '',
      customer: j['customer_name']?.toString() ?? '',
      mobile: j['mobile']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      cnic: j['cnic']?.toString() ?? '',
      address: j['address']?.toString() ?? '',
      project: j['project_name']?.toString() ?? '',
      propType: j['property_type']?.toString() ?? '',
      location: j['pref_location']?.toString() ?? '',
      propSize: j['property_size']?.toString() ?? '',
      budgetFrom: (j['budget_from'] as num?)?.toDouble() ?? 0,
      budgetTo: (j['budget_to'] as num?)?.toDouble() ?? 0,
      timeline: j['timeline']?.toString() ?? '',
      gpsStatus: j['gps_status']?.toString() ?? 'Not Captured',
      gpsLat: (j['gps_lat'] as num?)?.toDouble(),
      gpsLng: (j['gps_lng'] as num?)?.toDouble(),
      gpsAcc: (j['gps_accuracy_m'] as num?)?.toDouble(),
      response: j['response']?.toString() ?? '',
      interest: j['interest_level']?.toString() ?? '',
      outcome: j['outcome']?.toString() ?? '',
      nextAction: j['next_action']?.toString() ?? '',
      fuDate: j['next_fu_date']?.toString() ?? '',
      fuTime: j['next_fu_time']?.toString() ?? '',
      remarks: j['remarks']?.toString() ?? '',
      photoBase64: null,
      photoFileName: null,
      hasSignature: (j['has_signature'] as int?) == 1,
      converted: (j['is_converted'] as int?) == 1,
      leadNo: j['lead_id']?.toString(),
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
        visits.assignAll(list.map((e) => VisitModel.fromJson(e)).toList());
        debugPrint('📂 [VisitVM] Loaded ${visits.length} visits from cache');
      } else {
        visits.assignAll(_seedData());
        await _persist();
      }
    } catch (e) {
      debugPrint('❌ [VisitVM] load error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  /// ✅ Public persist method for manual save
  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(visits.map((v) => v.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(visits.map((v) => v.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  List<VisitModel> _seedData() => [];

  // ── Generate Numeric ID ──────────────────────────────────────────────
  Future<int> _getNextId() async {
    final prefs = await SharedPreferences.getInstance();
    int nextId = prefs.getInt(_idCounterKey) ?? 1;
    await prefs.setInt(_idCounterKey, nextId + 1);
    return nextId;
  }

  // ── Derived / filtered list ──────────────────────────────────────────
  List<VisitModel> get filtered {
    var rows = visits.toList();
    if (statusFilter.value != 'All') {
      rows = rows.where((v) => v.status == statusFilter.value).toList();
    }
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows
          .where((v) =>
      v.customer.toLowerCase().contains(q) ||
          v.mobile.toLowerCase().contains(q) ||
          v.visitNo.toLowerCase().contains(q) ||
          v.project.toLowerCase().contains(q))
          .toList();
    }
    rows.sort((a, b) => ('${b.date}${b.time}').compareTo('${a.date}${a.time}'));
    return rows;
  }

  int countByStatus(String status) =>
      status == 'All' ? visits.length : visits.where((v) => v.status == status).length;

  int get gpsVerifiedCount => visits.where((v) => v.gpsStatus == 'Verified').length;

  void setSearch(String q) => searchQuery.value = q;
  void setStatusFilter(String s) => statusFilter.value = s;

  // ── Visit numbering ──────────────────────────────────────────────────
  String _peekVisitNo() {
    final year = DateTime.now().year;
    final next = visits.length + 1;
    return 'CV-$year-${next.toString().padLeft(4, '0')}';
  }

  // ── New / Edit visit form state ──────────────────────────────────────
  Future<VisitModel> buildDraft({VisitModel? editing}) async {
    if (editing != null) return editing;
    final now = DateTime.now();
    final nextId = await _getNextId();
    return VisitModel(
      id: nextId.toString(),
      visitNo: _peekVisitNo(),
      companyCode: companyCode.value,
      date: DateFormat('yyyy-MM-dd').format(now),
      time: DateFormat('HH:mm').format(now),
      empId: empId.value,
      empName: empName.value,
      visitType: 'Site Visit',
      customerId: '',
      customer: '',
    );
  }

  // ── GPS capture ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> captureGps() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        Get.snackbar('GPS Off', 'Please enable location services.',
            snackPosition: SnackPosition.TOP);
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        Get.snackbar('Permission Denied', 'Location permission is required to capture GPS.',
            snackPosition: SnackPosition.TOP);
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final acc = pos.accuracy;
      final status = acc <= 250 ? 'Verified' : 'Outside Location';

      return {
        'lat': double.parse(pos.latitude.toStringAsFixed(6)),
        'lng': double.parse(pos.longitude.toStringAsFixed(6)),
        'acc': acc.round(),
        'status': status,
      };
    } catch (e) {
      debugPrint('❌ [VisitVM] GPS capture failed: $e');
      Get.snackbar('GPS Failed', 'Could not get your location.',
          snackPosition: SnackPosition.TOP);
      return null;
    }
  }

  // ── Photo attachment ────────────────────────────────────────────────
  Future<Map<String, String>?> pickPhoto(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 40,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (file == null) return null;
      final Uint8List bytes = await file.readAsBytes();
      return {'base64': base64Encode(bytes), 'name': file.name};
    } catch (e) {
      debugPrint('❌ [VisitVM] photo pick failed: $e');
      return null;
    }
  }

  // ── UPDATE Visit (PUT) ──────────────────────────────────────────────
  /// ✅ Update existing visit on server using PUT
  Future<bool> updateVisit(VisitModel v) async {
    try {
      final DateFormat oracleDateFormat = DateFormat('dd-MMM-yyyy');
      final DateFormat isoDateFormat = DateFormat('yyyy-MM-dd');

      DateTime? visitDate;
      try {
        visitDate = isoDateFormat.parse(v.date);
      } catch (e) {
        try {
          visitDate = DateTime.parse(v.date);
        } catch (e2) {
          debugPrint('❌ [VisitVM] Could not parse date: ${v.date}');
          return false;
        }
      }

      final String formattedDate = oracleDateFormat.format(visitDate!);

      String? formattedFuDate;
      if (v.fuDate.isNotEmpty) {
        try {
          final fuDateTime = isoDateFormat.parse(v.fuDate);
          formattedFuDate = oracleDateFormat.format(fuDateTime);
        } catch (e) {
          formattedFuDate = v.fuDate;
        }
      }

      final Map<String, dynamic> requestBody = {
        'visit_id': v.dbVisitId ?? v.id,
        'visit_date': formattedDate,
        'visit_time': v.time,
        'customer_name': v.customer,
        'mobile': v.mobile,
        'email': v.email,
        'address': v.address,
        'emp_id': v.empId,
        'emp_name': v.empName,
        'company_code': v.companyCode ?? '',
        'visit_type': v.visitType,
        'status': v.status,
        'customer_id': v.customerId.isEmpty ? null : v.customerId,
        'cnic': v.cnic.isEmpty ? null : v.cnic,
        'project_name': v.project,
        'property_type': v.propType,
        'pref_location': v.location.isEmpty ? null : v.location,
        'property_size': v.propSize.isEmpty ? null : v.propSize,
        'budget_from': v.budgetFrom > 0 ? v.budgetFrom : null,
        'budget_to': v.budgetTo > 0 ? v.budgetTo : null,
        'timeline': v.timeline.isEmpty ? null : v.timeline,
        'gps_status': v.gpsStatus,
        'gps_lat': v.gpsLat,
        'gps_lng': v.gpsLng,
        'gps_accuracy_m': v.gpsAcc,
        'response': v.response.isEmpty ? null : v.response,
        'interest_level': v.interest,
        'outcome': v.outcome.isEmpty ? null : v.outcome,
        'next_action': v.nextAction.isEmpty ? null : v.nextAction,
        'next_fu_date': formattedFuDate,
        'next_fu_time': v.fuTime.isEmpty ? null : v.fuTime,
        'remarks': v.remarks.isEmpty ? null : v.remarks,
        'has_photo': v.photoBase64 != null ? 1 : 0,
        'has_signature': v.hasSignature ? 1 : 0,
        'is_converted': v.converted ? 1 : 0,
        'is_deleted': 0,
      };

      requestBody.removeWhere((key, value) =>
      value == null ||
          (value is String && value.isEmpty) ||
          (value is double && value == 0));

      debugPrint('📤 [VisitVM] UPDATE (PUT) to APEX: $requestBody');

      final response = await http
          .put(
        Uri.parse(_visitsUpdateEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [VisitVM] UPDATE Response (${response.statusCode}): ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final responseData = jsonDecode(response.body);
          if (responseData is Map<String, dynamic>) {
            if (responseData['status'] == 'success') {
              final data = responseData['data'] as Map<String, dynamic>?;
              if (data != null) {
                if (data['visit_no'] != null) {
                  v.visitNo = data['visit_no']?.toString() ?? v.visitNo;
                }
                if (data['visit_id'] != null) {
                  v.dbVisitId = data['visit_id']?.toString();
                  v.id = data['visit_id']?.toString() ?? v.id;
                }
              }
              return true;
            }
          }
        } catch (e) {
          debugPrint('⚠️ [VisitVM] Could not parse response: $e');
          return true;
        }
        return true;
      } else {
        debugPrint('⚠️ [VisitVM] UPDATE failed (${response.statusCode}): ${response.body}');
        return false;
      }
    } on TimeoutException {
      debugPrint('⌛ [VisitVM] UPDATE timed out');
      return false;
    } catch (e) {
      debugPrint('❌ [VisitVM] UPDATE error: $e');
      return false;
    }
  }

  // ── Save (offline-first) ────────────────────────────────────────────
  Future<void> saveVisit(VisitModel v, {required bool isNew}) async {
    if (isNew) {
      visits.insert(0, v);
    } else {
      final idx = visits.indexWhere((x) => x.id == v.id);
      if (idx != -1) visits[idx] = v;
    }
    await _persist();

    final online = await _isOnline();

    if (!online) {
      debugPrint('📴 [VisitVM] Offline — visit saved locally only: ${v.visitNo}');
      Get.snackbar(
        'Saved Offline',
        'Visit saved on device. It will sync automatically when you\'re back online.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
      );
      return;
    }

    final synced = await _postToApex(v);
    if (synced) {
      v.posted = true;
      final idx = visits.indexWhere((x) => x.id == v.id);
      if (idx != -1) {
        visits[idx] = v;
      }
      await _persist();

      Get.snackbar(
        'Success',
        'Visit synced to server: ${v.visitNo}',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.tealDark,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Warning',
        'Visit saved locally but not synced to server.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
      );
    }
  }

  Future<bool> _postToApex(VisitModel v) async {
    try {
      final DateFormat oracleDateFormat = DateFormat('dd-MMM-yyyy');

      DateTime? visitDate;
      try {
        visitDate = DateTime.parse(v.date);
      } catch (e) {
        try {
          visitDate = DateFormat('yyyy-MM-dd').parse(v.date);
        } catch (e2) {
          debugPrint('❌ [VisitVM] Could not parse date: ${v.date}');
          return false;
        }
      }

      final String formattedDate = oracleDateFormat.format(visitDate!);

      String? formattedFuDate;
      if (v.fuDate.isNotEmpty) {
        try {
          final fuDateTime = DateTime.parse(v.fuDate);
          formattedFuDate = oracleDateFormat.format(fuDateTime);
        } catch (e) {
          formattedFuDate = v.fuDate;
        }
      }

      final Map<String, dynamic> requestBody = {
        'visit_date': formattedDate,
        'visit_time': v.time,
        'customer_name': v.customer,
        'mobile': v.mobile,
        'emp_id': v.empId,
        'emp_name': v.empName,
        'company_code': v.companyCode ?? '',
        'visit_type': v.visitType,
        'status': v.status,
        'customer_id': v.customerId.isEmpty ? null : v.customerId,
        'email': v.email,
        'cnic': v.cnic,
        'address': v.address,
        'project_name': v.project,
        'property_type': v.propType,
        'pref_location': v.location,
        'property_size': v.propSize,
        'budget_from': v.budgetFrom > 0 ? v.budgetFrom : null,
        'budget_to': v.budgetTo > 0 ? v.budgetTo : null,
        'timeline': v.timeline,
        'gps_status': v.gpsStatus,
        'gps_lat': v.gpsLat,
        'gps_lng': v.gpsLng,
        'gps_accuracy_m': v.gpsAcc,
        'gps_distance_m': null,
        'response': v.response,
        'interest_level': v.interest,
        'outcome': v.outcome,
        'next_action': v.nextAction,
        'next_fu_date': formattedFuDate,
        'next_fu_time': v.fuTime.isEmpty ? null : v.fuTime,
        'remarks': v.remarks,
        'has_photo': v.photoBase64 != null ? 1 : 0,
        'has_signature': v.hasSignature ? 1 : 0,
        'is_converted': v.converted ? 1 : 0,
        'lead_id': null,
        'is_deleted': 0,
      };

      requestBody.removeWhere((key, value) => value == null || value.toString().isEmpty);

      debugPrint('📤 [VisitVM] POST to APEX: $requestBody');

      final response = await http
          .post(
        Uri.parse(_visitsPostEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [VisitVM] APEX Response (${response.statusCode}): ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final responseData = jsonDecode(response.body);
          if (responseData is Map<String, dynamic>) {
            final data = responseData['data'] as Map<String, dynamic>?;
            if (data != null) {
              if (data['visit_no'] != null) {
                v.visitNo = data['visit_no']?.toString() ?? v.visitNo;
                debugPrint('✅ [VisitVM] APEX visit_no: ${v.visitNo}');
              }
              if (data['visit_id'] != null) {
                v.dbVisitId = data['visit_id']?.toString();
                v.id = data['visit_id']?.toString() ?? v.id;
                debugPrint('✅ [VisitVM] APEX visit_id (DB): ${v.dbVisitId}');
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ [VisitVM] Could not parse APEX response: $e');
        }
        return true;
      } else {
        debugPrint('⚠️ [VisitVM] APEX send failed (${response.statusCode}): ${response.body}');
        return false;
      }
    } on TimeoutException {
      debugPrint('⌛ [VisitVM] APEX send timed out for ${v.visitNo}');
      return false;
    } catch (e) {
      debugPrint('❌ [VisitVM] APEX send error: $e');
      return false;
    }
  }

  /// Retry sending any unsynced visits
  Future<void> retryUnsyncedVisits() async {
    final online = await _isOnline();
    if (!online) {
      debugPrint('📴 [VisitVM] Offline — cannot retry unsynced visits');
      return;
    }

    final unsynced = visits.where((v) => !v.posted).toList();
    if (unsynced.isEmpty) return;

    for (final v in unsynced) {
      final synced = await _postToApex(v);
      if (synced) {
        v.posted = true;
        final idx = visits.indexWhere((x) => x.id == v.id);
        if (idx != -1) visits[idx] = v;
        await _persist();
      }
    }

    await fetchVisitsFromServer();
  }

  Future<void> deleteVisit(String id) async {
    visits.removeWhere((v) => v.id == id);
    await _persist();
  }
}