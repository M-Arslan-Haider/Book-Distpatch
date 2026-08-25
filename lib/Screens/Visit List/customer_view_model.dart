
import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../AppColors.dart';
import 'customer_model.dart';

class CustomerViewModel extends GetxController {
  static const String _prefsKey = 'gps_customers_v1';

  // ── API Endpoints ─────────────────────────────────────────────────────
  static const String _customersPostEndpoint = 'http://oracle.metaxperts.net/ords/gps_workforce/customer/post/';

  // ✅ Updated: Only company_code needed
  static String getCustomersGetUrl(String companyCode) {
    return 'http://oracle.metaxperts.net/ords/gps_workforce/customerget/get/$companyCode';
  }

  // ── Employee Info ─────────────────────────────────────────────────────
  final RxString empId = ''.obs;
  final RxString empName = ''.obs;
  final RxString companyCode = ''.obs;
  final RxBool isEmployeeLoaded = false.obs;

  // ✅ MAIN: Only API customers (no local duplicates)
  final RxList<CustomerModel> customers = <CustomerModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;
  final RxString errorMessage = ''.obs;

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

    // ✅ Internet wapas ane par pending customers auto sync ho jayen
    _connSub = _connectivity.onConnectivityChanged.listen((results) async {
      final online = results.isNotEmpty && results.any((x) => x != ConnectivityResult.none);
      if (online) {
        debugPrint('🌐 [CustomerVM] Internet restored — auto-syncing pending customers');
        await retryUnsyncedCustomers();
        await fetchCustomersFromServer();
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
      debugPrint('📴 [CustomerVM] Offline at startup — loading from local cache only');
      await _loadSaved();
      return;
    }

    // ✅ Updated: Only check companyCode
    if (companyCode.value.isNotEmpty) {
      await fetchCustomersFromServer();
      await retryUnsyncedCustomers();
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

    debugPrint('👤 [CustomerVM] empId="${empId.value}" empName="${empName.value}" companyCode="${companyCode.value}"');
  }

  /// ── FETCH FROM SERVER ──────────────────────────────────────────────
  Future<void> fetchCustomersFromServer() async {
    // ✅ Updated: Only check companyCode
    if (companyCode.value.isEmpty) {
      debugPrint('⚠️ [CustomerVM] Cannot fetch: companyCode missing');
      await _loadSaved();
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      // ✅ Updated: Only companyCode parameter
      final uri = Uri.parse(getCustomersGetUrl(companyCode.value));
      debugPrint('📤 [CustomerVM] GET: $uri');

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [CustomerVM] GET Response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? data as List? ?? [];

        // ✅ Parse API customers
        final apiCustomers = items.map((e) => _fromServerJson(e)).toList();

        // ✅ Keep local unsynced customers (posted == false)
        final localUnsynced = customers.where((c) => !c.posted).toList();

        // ✅ Merge: API customers + local unsynced
        final merged = [...apiCustomers];
        for (final local in localUnsynced) {
          final exists = merged.any((api) => api.mobile == local.mobile);
          if (!exists) {
            merged.add(local);
          }
        }

        customers.assignAll(merged);
        await _persist();
        debugPrint('✅ [CustomerVM] Loaded ${apiCustomers.length} from API + ${localUnsynced.length} offline = ${merged.length} total');
      } else {
        errorMessage.value = 'Server error: ${response.statusCode}';
        debugPrint('⚠️ [CustomerVM] GET failed: ${response.statusCode}');
        await _loadSaved();
      }
    } on TimeoutException {
      errorMessage.value = 'Connection timed out. Showing cached data.';
      debugPrint('⌛ [CustomerVM] GET timed out');
      await _loadSaved();
    } catch (e) {
      errorMessage.value = 'Failed to load customers. Please check your connection.';
      debugPrint('❌ [CustomerVM] GET error: $e');
      await _loadSaved();
    } finally {
      isLoading.value = false;
    }
  }

  CustomerModel _fromServerJson(Map<String, dynamic> j) {
    return CustomerModel(
      id: j['customer_id']?.toString() ?? const Uuid().v4(),
      empId: j['emp_id']?.toString() ?? empId.value,
      empName: j['emp_name']?.toString() ?? empName.value,
      companyCode: j['company_code']?.toString() ?? companyCode.value,
      customerNo: j['customer_no']?.toString() ?? '',
      name: j['customer_name']?.toString() ?? '',
      mobile: j['mobile_number']?.toString() ?? '',
      altMobile: j['alt_mobile']?.toString() ?? '',
      email: j['email']?.toString() ?? '',
      address: j['address']?.toString() ?? '',
      city: j['city']?.toString() ?? '',
      remarks: j['remarks']?.toString() ?? '',
      posted: true,
    );
  }

  /// ── LOAD FROM CACHE (OFFLINE) ──────────────────────────────────────
  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        customers.assignAll(list.map((e) => CustomerModel.fromJson(e)).toList());
        debugPrint('📂 [CustomerVM] Loaded ${customers.length} customers from cache');
      }
    } catch (e) {
      debugPrint('❌ [CustomerVM] load error: $e');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(customers.map((c) => c.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  // ── Filtering ─────────────────────────────────────────────────────────
  List<CustomerModel> get filtered {
    var rows = customers.toList();
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      rows = rows.where((c) =>
      c.name.toLowerCase().contains(q) ||
          c.mobile.toLowerCase().contains(q) ||
          (c.customerNo?.toLowerCase().contains(q) ?? false)
      ).toList();
    }
    rows.sort((a, b) => a.name.compareTo(b.name));
    return rows;
  }

  void setSearch(String q) => searchQuery.value = q;

  // ── Build Draft ──────────────────────────────────────────────────────
  CustomerModel buildDraft() {
    return CustomerModel(
      id: const Uuid().v4(),
      companyCode: companyCode.value,
      empId: empId.value,
      empName: empName.value,
    );
  }

  // ── SAVE ─────────────────────────────────────────────────────────────
  Future<bool> saveCustomer(CustomerModel c, {required bool isNew}) async {
    isLoading.value = true;

    try {
      final online = await _isOnline();

      if (!online) {
        if (isNew) {
          c.posted = false;
          customers.insert(0, c);
          await _persist();
        }
        Get.snackbar(
          'Saved Offline',
          'Customer saved on device. It will sync automatically when you\'re back online.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.warning,
          colorText: Colors.white,
        );
        return true;
      }

      final synced = await _postToApex(c);

      if (synced) {
        await fetchCustomersFromServer();
        return true;
      } else {
        if (isNew) {
          c.posted = false;
          customers.insert(0, c);
          await _persist();
        }
        Get.snackbar(
          'Warning',
          'Customer saved locally but not synced to server.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.warning,
          colorText: Colors.white,
        );
        return false;
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> _postToApex(CustomerModel c) async {
    try {
      final Map<String, dynamic> requestBody = {
        'customer_name': c.name,
        'mobile_number': c.mobile,
        'alt_mobile': c.altMobile,
        'email': c.email,
        'address': c.address,
        'city': c.city,
        'remarks': c.remarks,
        'emp_id': c.empId,
        'emp_name': c.empName,
        'company_code': c.companyCode ?? '',
      };

      requestBody.removeWhere((key, value) => value == null || value.toString().isEmpty);

      debugPrint('📤 [CustomerVM] POST to APEX: $requestBody');

      final response = await http
          .post(
        Uri.parse(_customersPostEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [CustomerVM] APEX Response (${response.statusCode}): ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Get.snackbar(
          'Success',
          'Customer saved to server',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.tealDark,
          colorText: Colors.white,
        );
        return true;
      } else {
        debugPrint('⚠️ [CustomerVM] APEX send failed (${response.statusCode}): ${response.body}');
        return false;
      }
    } on TimeoutException {
      debugPrint('⌛ [CustomerVM] APEX send timed out for ${c.name}');
      return false;
    } catch (e) {
      debugPrint('❌ [CustomerVM] APEX send error: $e');
      return false;
    }
  }

  Future<void> retryUnsyncedCustomers() async {
    final unsynced = customers.where((c) => !c.posted).toList();
    if (unsynced.isEmpty) return;

    final online = await _isOnline();
    if (!online) {
      debugPrint('📴 [CustomerVM] Offline — cannot retry unsynced customers');
      return;
    }

    for (final c in unsynced) {
      final synced = await _postToApex(c);
      if (synced) {
        c.posted = true;
        final idx = customers.indexWhere((x) => x.id == c.id);
        if (idx != -1) customers[idx] = c;
        await _persist();
      }
    }

    await fetchCustomersFromServer();
  }

  Future<void> deleteCustomer(String id) async {
    customers.removeWhere((c) => c.id == id);
    await _persist();
  }

  CustomerModel? findById(String id) {
    try {
      return customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}