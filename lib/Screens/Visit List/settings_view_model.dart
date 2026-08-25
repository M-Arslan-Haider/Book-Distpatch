// // lib/ViewModels/settings_view_model.dart
//
// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/foundation.dart';
// import 'package:get/get.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
//
// class SettingValue {
//   final int id;
//   final String listKey;
//   final String valueText;
//   final int isActive;
//   final int isProtected;
//   final String? empId;
//   final String? companyCode;
//
//   SettingValue({
//     required this.id,
//     required this.listKey,
//     required this.valueText,
//     required this.isActive,
//     required this.isProtected,
//     this.empId,
//     this.companyCode,
//   });
//
//   factory SettingValue.fromJson(Map<String, dynamic> j) => SettingValue(
//     id: j['ID'] ?? j['id'] ?? 0,
//     listKey: j['LIST_KEY']?.toString() ?? j['list_key']?.toString() ?? '',
//     valueText: j['VALUE_TEXT']?.toString() ?? j['value_text']?.toString() ?? '',
//     isActive: j['IS_ACTIVE'] ?? j['is_active'] ?? 1,
//     isProtected: j['IS_PROTECTED'] ?? j['is_protected'] ?? 0,
//     empId: j['EMP_ID']?.toString() ?? j['emp_id']?.toString(),
//     companyCode: j['COMPANY_CODE']?.toString() ?? j['company_code']?.toString(),
//   );
// }
//
// class SettingsViewModel extends GetxController {
//   static const String _cacheKey = 'gps_settings_v1';
//
//   static String getSettingsUrl(String companyCode) {
//     return 'http://oracle.metaxperts.net/ords/gps_workforce/settings/get/$companyCode';
//   }
//
//   final RxString companyCode = ''.obs;
//   final RxBool isLoading = false.obs;
//   final RxString errorMessage = ''.obs;
//
//   // ── Data Lists from API ──────────────────────────────────────────────
//   final RxList<String> projects = <String>[].obs;
//   final RxList<String> propTypes = <String>[].obs;
//   final RxList<String> visitTypes = <String>[].obs;
//   final RxList<String> categories = <String>[].obs;
//   final RxList<String> leadRatings = <String>[].obs;
//   final RxList<String> leadStatuses = <String>[].obs;
//   final RxList<String> memberships = <String>[].obs;
//   final RxList<String> packages = <String>[].obs;
//   final RxList<String> payTypes = <String>[].obs;
//
//   // ── ALIASES for backward compatibility ──────────────────────────────
//   List<String> get timelines => categories;
//   List<String> get interestLevels => leadRatings;
//   List<String> get responses => leadStatuses;
//   List<String> get nextActions => visitTypes;
//
//   // ── Default fallback values ───────────────────────────────────────────
//   static const List<String> _defaultProjects = [
//     'Green Valley Residencia',
//     'City Business District',
//     'Royal Enclave',
//     'Sialkot Smart City',
//     'Canal View Housing',
//     'Prime Commercial Center',
//   ];
//
//   static const List<String> _defaultPropTypes = [
//     'Residential Plot',
//     'Commercial Plot',
//     'House',
//     'Apartment',
//     'Shop',
//     'Office',
//     'Farmhouse',
//     'Other',
//   ];
//
//   static const List<String> _defaultVisitTypes = [
//     'Office Visit',
//     'Site Visit',
//     'Customer Location',
//     'Online Meeting',
//   ];
//
//   static const List<String> _defaultCategories = [
//     'Immediate',
//     'Within 1 Month',
//     '1–3 Months',
//     '3–6 Months',
//     'More Than 6 Months',
//   ];
//
//   static const List<String> _defaultLeadRatings = [
//     'Hot',
//     'Warm',
//     'Cold',
//   ];
//
//   static const List<String> _defaultLeadStatuses = [
//     'Interested',
//     'Considering',
//     'Not Interested',
//     'Requires More Information',
//     'Decision Pending',
//   ];
//
//   static const List<String> _defaultMemberships = [
//     'Standard Member',
//     'Premium Member',
//     'VIP Member',
//   ];
//
//   static const List<String> _defaultPackages = [
//     'Silver Package',
//     'Platinum Package',
//     'Corporate Package',
//   ];
//
//   static const List<String> _defaultPayTypes = [
//     'Commission to Affiliate',
//     'Commission to Employee',
//     'Incentive',
//     'Salary Payment',
//     'Fuel Expense',
//     'Food Expense',
//     'Other Expense',
//   ];
//
//   @override
//   void onInit() {
//     super.onInit();
//     _loadCompanyAndFetch();
//   }
//
//   Future<void> _loadCompanyAndFetch() async {
//     final prefs = await SharedPreferences.getInstance();
//     companyCode.value = prefs.getString('companyCode') ??
//         prefs.getString('company_code') ?? '';
//
//     debugPrint('🏢 [SettingsVM] Company Code: ${companyCode.value}');
//
//     // Try cache first
//     final cached = await _loadFromCache();
//     if (!cached && companyCode.value.isNotEmpty) {
//       await fetchSettings();
//     } else {
//       _applyFallbacks();
//     }
//   }
//
//   Future<void> fetchSettings() async {
//     if (companyCode.value.isEmpty) {
//       debugPrint('⚠️ [SettingsVM] companyCode missing, using defaults');
//       _setDefaults();
//       return;
//     }
//
//     isLoading.value = true;
//     errorMessage.value = '';
//
//     try {
//       final uri = Uri.parse(getSettingsUrl(companyCode.value));
//       debugPrint('📤 [SettingsVM] GET: $uri');
//
//       final response = await http
//           .get(uri, headers: {'Content-Type': 'application/json'})
//           .timeout(const Duration(seconds: 15));
//
//       debugPrint('📥 [SettingsVM] Response status: ${response.statusCode}');
//
//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final items = data['items'] as List? ?? data as List? ?? [];
//
//         debugPrint('📥 [SettingsVM] Items count: ${items.length}');
//
//         if (items.isNotEmpty) {
//           final values = items.map((e) => SettingValue.fromJson(e)).toList();
//
//           final keys = values.map((v) => v.listKey).toSet();
//           debugPrint('📥 [SettingsVM] List keys found: $keys');
//
//           _parseSettings(values);
//           await _saveToCache();
//
//           // ✅ Debug: Print what was parsed
//           debugPrint('✅ [SettingsVM] projects: ${projects.length} - ${projects}');
//           debugPrint('✅ [SettingsVM] propTypes: ${propTypes.length} - ${propTypes}');
//           debugPrint('✅ [SettingsVM] visitTypes: ${visitTypes.length} - ${visitTypes}');
//         } else {
//           debugPrint('ℹ️ [SettingsVM] No settings found');
//         }
//       } else {
//         debugPrint('⚠️ [SettingsVM] GET failed: ${response.statusCode}');
//       }
//     } catch (e) {
//       debugPrint('❌ [SettingsVM] Error: $e');
//     } finally {
//       isLoading.value = false;
//       _applyFallbacks();
//     }
//   }
//
//   void _parseSettings(List<SettingValue> values) {
//     // ✅ Map all API keys - using exact case from API
//     projects.value = _getValuesByKey(values, 'projects');
//     propTypes.value = _getValuesByKey(values, 'propTypes');
//     visitTypes.value = _getValuesByKey(values, 'visitTypes');
//     categories.value = _getValuesByKey(values, 'categories');
//     leadRatings.value = _getValuesByKey(values, 'leadRatings');
//     leadStatuses.value = _getValuesByKey(values, 'leadStatuses');
//     memberships.value = _getValuesByKey(values, 'memberships');
//     packages.value = _getValuesByKey(values, 'packages');
//     payTypes.value = _getValuesByKey(values, 'payTypes');
//   }
//
//   List<String> _getValuesByKey(List<SettingValue> values, String key) {
//     final result = values
//         .where((v) => v.listKey.toLowerCase() == key.toLowerCase())
//         .map((v) => v.valueText)
//         .toList();
//
//     if (result.isNotEmpty) {
//       debugPrint('🔑 [SettingsVM] Found ${result.length} values for key: "$key" -> $result');
//     }
//     return result;
//   }
//
//   void _applyFallbacks() {
//     if (projects.isEmpty) projects.value = _defaultProjects;
//     if (propTypes.isEmpty) propTypes.value = _defaultPropTypes;
//     if (visitTypes.isEmpty) visitTypes.value = _defaultVisitTypes;
//     if (categories.isEmpty) categories.value = _defaultCategories;
//     if (leadRatings.isEmpty) leadRatings.value = _defaultLeadRatings;
//     if (leadStatuses.isEmpty) leadStatuses.value = _defaultLeadStatuses;
//     if (memberships.isEmpty) memberships.value = _defaultMemberships;
//     if (packages.isEmpty) packages.value = _defaultPackages;
//     if (payTypes.isEmpty) payTypes.value = _defaultPayTypes;
//
//     debugPrint('📋 [SettingsVM] Fallbacks applied');
//   }
//
//   void _setDefaults() {
//     projects.value = _defaultProjects;
//     propTypes.value = _defaultPropTypes;
//     visitTypes.value = _defaultVisitTypes;
//     categories.value = _defaultCategories;
//     leadRatings.value = _defaultLeadRatings;
//     leadStatuses.value = _defaultLeadStatuses;
//     memberships.value = _defaultMemberships;
//     packages.value = _defaultPackages;
//     payTypes.value = _defaultPayTypes;
//   }
//
//   // ── Cache ─────────────────────────────────────────────────────────────
//   Future<bool> _loadFromCache() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final raw = prefs.getString(_cacheKey);
//       if (raw != null && raw.isNotEmpty) {
//         final data = jsonDecode(raw);
//         final items = data['items'] as List? ?? [];
//         if (items.isNotEmpty) {
//           final values = items.map((e) => SettingValue.fromJson(e)).toList();
//           _parseSettings(values);
//           debugPrint('📂 [SettingsVM] Loaded ${values.length} settings from cache');
//           return true;
//         }
//       }
//     } catch (e) {
//       debugPrint('❌ [SettingsVM] Cache load error: $e');
//     }
//     return false;
//   }
//
//   Future<void> _saveToCache() async {
//     try {
//       final allValues = <Map<String, dynamic>>[];
//       allValues.addAll(projects.map((v) => {'list_key': 'projects', 'value_text': v}));
//       allValues.addAll(propTypes.map((v) => {'list_key': 'propTypes', 'value_text': v}));
//       allValues.addAll(visitTypes.map((v) => {'list_key': 'visitTypes', 'value_text': v}));
//       allValues.addAll(categories.map((v) => {'list_key': 'categories', 'value_text': v}));
//       allValues.addAll(leadRatings.map((v) => {'list_key': 'leadRatings', 'value_text': v}));
//       allValues.addAll(leadStatuses.map((v) => {'list_key': 'leadStatuses', 'value_text': v}));
//       allValues.addAll(memberships.map((v) => {'list_key': 'memberships', 'value_text': v}));
//       allValues.addAll(packages.map((v) => {'list_key': 'packages', 'value_text': v}));
//       allValues.addAll(payTypes.map((v) => {'list_key': 'payTypes', 'value_text': v}));
//
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString(_cacheKey, jsonEncode({'items': allValues}));
//     } catch (e) {
//       debugPrint('❌ [SettingsVM] Cache save error: $e');
//     }
//   }
//
//   Future<void> refreshSettings() async {
//     await fetchSettings();
//   }
// }


// Screens/Visit List/settings_view_model.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SettingValue {
  final int id;
  final String listKey;
  final String valueText;
  final int isActive;
  final int isProtected;
  final String? empId;
  final String? companyCode;

  SettingValue({
    required this.id,
    required this.listKey,
    required this.valueText,
    required this.isActive,
    required this.isProtected,
    this.empId,
    this.companyCode,
  });

  factory SettingValue.fromJson(Map<String, dynamic> j) => SettingValue(
    id: j['ID'] ?? j['id'] ?? 0,
    listKey: j['LIST_KEY']?.toString() ?? j['list_key']?.toString() ?? '',
    valueText: j['VALUE_TEXT']?.toString() ?? j['value_text']?.toString() ?? '',
    isActive: j['IS_ACTIVE'] ?? j['is_active'] ?? 1,
    isProtected: j['IS_PROTECTED'] ?? j['is_protected'] ?? 0,
    empId: j['EMP_ID']?.toString() ?? j['emp_id']?.toString(),
    companyCode: j['COMPANY_CODE']?.toString() ?? j['company_code']?.toString(),
  );
}

class SettingsViewModel extends GetxController {
  static const String _cacheKey = 'gps_settings_v1';

  static String getSettingsUrl(String companyCode) {
    return 'http://oracle.metaxperts.net/ords/gps_workforce/settings/get/$companyCode';
  }

  final RxString companyCode = ''.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // ── Data Lists from API ──────────────────────────────────────────────
  final RxList<String> projects = <String>[].obs;
  final RxList<String> propTypes = <String>[].obs;
  final RxList<String> visitTypes = <String>[].obs;
  final RxList<String> categories = <String>[].obs;
  final RxList<String> leadRatings = <String>[].obs;
  final RxList<String> leadStatuses = <String>[].obs;
  final RxList<String> memberships = <String>[].obs;
  final RxList<String> packages = <String>[].obs;
  final RxList<String> payTypes = <String>[].obs;

  // ── ALIASES ──────────────────────────────────────────────────────────
  List<String> get timelines => categories;
  List<String> get interestLevels => leadRatings;
  List<String> get responses => leadStatuses;
  List<String> get nextActions => visitTypes;

  // ── Default fallback values ───────────────────────────────────────────
  static const List<String> _defaultProjects = [
    'Green Valley Residencia',
    'City Business District',
    'Royal Enclave',
    'Sialkot Smart City',
    'Canal View Housing',
    'Prime Commercial Center',
  ];

  static const List<String> _defaultPropTypes = [
    'Residential Plot',
    'Commercial Plot',
    'House',
    'Apartment',
    'Shop',
    'Office',
    'Farmhouse',
    'Other',
  ];

  static const List<String> _defaultVisitTypes = [
    'Office Visit',
    'Site Visit',
    'Customer Location',
    'Online Meeting',
  ];

  static const List<String> _defaultCategories = [
    'Immediate',
    'Within 1 Month',
    '1–3 Months',
    '3–6 Months',
    'More Than 6 Months',
  ];

  static const List<String> _defaultLeadRatings = [
    'Hot',
    'Warm',
    'Cold',
  ];

  static const List<String> _defaultLeadStatuses = [
    'Interested',
    'Considering',
    'Not Interested',
    'Requires More Information',
    'Decision Pending',
  ];

  static const List<String> _defaultMemberships = [
    'Standard Member',
    'Premium Member',
    'VIP Member',
  ];

  static const List<String> _defaultPackages = [
    'Silver Package',
    'Platinum Package',
    'Corporate Package',
  ];

  static const List<String> _defaultPayTypes = [
    'Commission to Affiliate',
    'Commission to Employee',
    'Incentive',
    'Salary Payment',
    'Fuel Expense',
    'Food Expense',
    'Other Expense',
  ];

  @override
  void onInit() {
    super.onInit();
    _loadCompanyAndFetch();
  }

  Future<void> _loadCompanyAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    companyCode.value = prefs.getString('companyCode') ??
        prefs.getString('company_code') ?? '';

    debugPrint('🏢 [SettingsVM] Company Code: ${companyCode.value}');

    final cached = await _loadFromCache();
    if (!cached && companyCode.value.isNotEmpty) {
      await fetchSettings();
    } else {
      _applyFallbacks();
    }
  }

  Future<void> fetchSettings() async {
    if (companyCode.value.isEmpty) {
      debugPrint('⚠️ [SettingsVM] companyCode missing, using defaults');
      _setDefaults();
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final uri = Uri.parse(getSettingsUrl(companyCode.value));
      debugPrint('📤 [SettingsVM] GET: $uri');

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('📥 [SettingsVM] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List? ?? data as List? ?? [];

        debugPrint('📥 [SettingsVM] Items count: ${items.length}');

        if (items.isNotEmpty) {
          final values = items.map((e) => SettingValue.fromJson(e)).toList();
          _parseSettings(values);
          await _saveToCache();
          debugPrint('✅ [SettingsVM] Fetched ${items.length} settings from API');
        } else {
          debugPrint('ℹ️ [SettingsVM] No settings found');
          await _loadFromCache();
        }
      } else {
        debugPrint('⚠️ [SettingsVM] GET failed: ${response.statusCode}');
        await _loadFromCache();
      }
    } catch (e) {
      debugPrint('❌ [SettingsVM] Error: $e');
      await _loadFromCache();
    } finally {
      isLoading.value = false;
      _applyFallbacks();
    }
  }

  void _parseSettings(List<SettingValue> values) {
    projects.value = _getValuesByKey(values, 'projects');
    propTypes.value = _getValuesByKey(values, 'propTypes');
    visitTypes.value = _getValuesByKey(values, 'visitTypes');
    categories.value = _getValuesByKey(values, 'categories');
    leadRatings.value = _getValuesByKey(values, 'leadRatings');
    leadStatuses.value = _getValuesByKey(values, 'leadStatuses');
    memberships.value = _getValuesByKey(values, 'memberships');
    packages.value = _getValuesByKey(values, 'packages');
    payTypes.value = _getValuesByKey(values, 'payTypes');
  }

  List<String> _getValuesByKey(List<SettingValue> values, String key) {
    final result = values
        .where((v) => v.listKey.toLowerCase() == key.toLowerCase())
        .map((v) => v.valueText)
        .toList();

    if (result.isNotEmpty) {
      debugPrint('🔑 [SettingsVM] Found ${result.length} values for key: "$key" -> $result');
    }
    return result;
  }

  void _applyFallbacks() {
    if (projects.isEmpty) projects.value = _defaultProjects;
    if (propTypes.isEmpty) propTypes.value = _defaultPropTypes;
    if (visitTypes.isEmpty) visitTypes.value = _defaultVisitTypes;
    if (categories.isEmpty) categories.value = _defaultCategories;
    if (leadRatings.isEmpty) leadRatings.value = _defaultLeadRatings;
    if (leadStatuses.isEmpty) leadStatuses.value = _defaultLeadStatuses;
    if (memberships.isEmpty) memberships.value = _defaultMemberships;
    if (packages.isEmpty) packages.value = _defaultPackages;
    if (payTypes.isEmpty) payTypes.value = _defaultPayTypes;

    debugPrint('📋 [SettingsVM] Fallbacks applied');
  }

  void _setDefaults() {
    projects.value = _defaultProjects;
    propTypes.value = _defaultPropTypes;
    visitTypes.value = _defaultVisitTypes;
    categories.value = _defaultCategories;
    leadRatings.value = _defaultLeadRatings;
    leadStatuses.value = _defaultLeadStatuses;
    memberships.value = _defaultMemberships;
    packages.value = _defaultPackages;
    payTypes.value = _defaultPayTypes;
  }

  /// ── LOAD FROM CACHE (OFFLINE) ──────────────────────────────────────
  Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw);
        final items = data['items'] as List? ?? [];
        if (items.isNotEmpty) {
          final values = items.map((e) => SettingValue.fromJson(e)).toList();
          _parseSettings(values);
          debugPrint('📂 [SettingsVM] Loaded ${values.length} settings from cache');
          return true;
        }
      }
    } catch (e) {
      debugPrint('❌ [SettingsVM] Cache load error: $e');
    }
    return false;
  }

  Future<void> _saveToCache() async {
    try {
      final allValues = <Map<String, dynamic>>[];
      allValues.addAll(projects.map((v) => {'list_key': 'projects', 'value_text': v}));
      allValues.addAll(propTypes.map((v) => {'list_key': 'propTypes', 'value_text': v}));
      allValues.addAll(visitTypes.map((v) => {'list_key': 'visitTypes', 'value_text': v}));
      allValues.addAll(categories.map((v) => {'list_key': 'categories', 'value_text': v}));
      allValues.addAll(leadRatings.map((v) => {'list_key': 'leadRatings', 'value_text': v}));
      allValues.addAll(leadStatuses.map((v) => {'list_key': 'leadStatuses', 'value_text': v}));
      allValues.addAll(memberships.map((v) => {'list_key': 'memberships', 'value_text': v}));
      allValues.addAll(packages.map((v) => {'list_key': 'packages', 'value_text': v}));
      allValues.addAll(payTypes.map((v) => {'list_key': 'payTypes', 'value_text': v}));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode({'items': allValues}));
    } catch (e) {
      debugPrint('❌ [SettingsVM] Cache save error: $e');
    }
  }

  Future<void> refreshSettings() async {
    await fetchSettings();
  }
}