import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../Models/leave_model.dart';
import '../Repositories/leave_repository.dart';

class LeaveViewModel extends GetxController {
  final LeaveRepository _repo = LeaveRepository();
  final ImagePicker _picker = ImagePicker();

  // ─── Employee Info ────────────────────────────────────────────────────────
  final RxString empName = ''.obs;
  final RxString empId   = ''.obs;
  final RxString jobRole = ''.obs;

  // FIX 1: track whether employee data has loaded so canSubmit is accurate
  final RxBool isEmployeeLoaded = false.obs;

  // ─── Form State ───────────────────────────────────────────────────────────
  final RxString selectedLeaveType  = ''.obs;
  final Rx<DateTime?> startDate     = Rx<DateTime?>(null);
  final Rx<DateTime?> endDate       = Rx<DateTime?>(null);
  final RxInt totalDays             = 0.obs;
  final RxBool isHalfDay            = false.obs;
  final RxString halfDayDisplay     = 'No'.obs;
  final RxString reason             = ''.obs;

  // ─── Attachment ───────────────────────────────────────────────────────────
  final Rx<Uint8List?> attachmentBytes    = Rx<Uint8List?>(null);
  final RxString       attachmentBase64   = ''.obs;
  final RxString       attachmentFileName = ''.obs;

  // ─── UI State ─────────────────────────────────────────────────────────────
  final RxBool isLoading   = false.obs;
  final RxBool isSubmitted = false.obs;

  // ─── Serial counter state ──────────────────────────────────────────────────
  int    _serialCounter = 1;
  String _currentMonth  = DateFormat('MMM').format(DateTime.now());

  final List<String> leaveTypes = [
    'Annual Leave',
    'Sick Leave',
    'Casual Leave',
    'Emergency Leave',
    'Maternity Leave',
    'Paternity Leave',
    'Unpaid Leave',
  ];

  @override
  void onInit() {
    super.onInit();
    _loadEmployee();
    _initSerialCounter();
  }

  // ─── PRIVATE – SERIAL COUNTER ─────────────────────────────────────────────

  Future<void> _initSerialCounter() async {
    final prefs = await SharedPreferences.getInstance();
    _serialCounter = prefs.getInt('leaveSerialCounter') ?? 1;
    debugPrint('🔢 [LeaveVM] Loaded serial counter: $_serialCounter');
  }

  Future<void> _saveSerialCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('leaveSerialCounter', _serialCounter);
  }

  // ─── PRIVATE – LEAVE ID BUILDER ────────────────────────────────────────────

  String _buildLeaveId({required String empId}) {
    final now    = DateTime.now();
    final day    = DateFormat('dd').format(now);
    final month  = DateFormat('MMM').format(now);
    final serial = _serialCounter.toString().padLeft(3, '0');
    final empPart = empId.padLeft(2, '0');
    final id = 'LV-EMP-$empPart-$day-$month-$serial';
    debugPrint('🆔 Generated ID: $id');
    return id;
  }

  Future<void> _loadEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    // DEBUG: Print ALL keys to find correct job role key
    debugPrint('🔑 [LeaveVM] ALL SharedPrefs keys:');
    for (final key in prefs.getKeys()) {
      debugPrint('   $key = ${prefs.get(key)}');
    }

    // FIX 3: expanded key fallbacks for all common naming conventions
    empName.value = prefs.getString('userName')      ??
        prefs.getString('user_name')     ??
        prefs.getString('name')          ??
        prefs.getString('full_name')     ??
        prefs.getString('fullName')      ?? '';

    empId.value   = prefs.getString('userId')        ??
        prefs.getString('user_id')       ??
        prefs.getString('emp_id')        ??
        prefs.getString('empId')         ??
        prefs.getString('employee_id')   ??
        prefs.getString('employeeId')    ?? '';

    jobRole.value = prefs.getString('designation')   ??
        prefs.getString('jobRole')       ??
        prefs.getString('job_role')      ??
        prefs.getString('position')      ??
        prefs.getString('role')          ?? '';

    debugPrint('👤 [LeaveVM] empName  : "${empName.value}"');
    debugPrint('👤 [LeaveVM] empId    : "${empId.value}"');
    debugPrint('👤 [LeaveVM] jobRole  : "${jobRole.value}"');

    // FIX 4: mark loaded so canSubmit unlocks only after data is ready
    isEmployeeLoaded.value = empId.value.isNotEmpty && empName.value.isNotEmpty;

    if (!isEmployeeLoaded.value) {
      debugPrint('⚠️  [LeaveVM] Employee info NOT found in SharedPrefs — check keys above');
    }
  }

  // FIX 5: canSubmit now guards against empty empId / empName
  bool get canSubmit =>
      isEmployeeLoaded.value &&
          empId.value.isNotEmpty &&
          empName.value.isNotEmpty &&
          selectedLeaveType.isNotEmpty &&
          startDate.value != null &&
          endDate.value != null &&
          reason.value.trim().isNotEmpty &&
          !isLoading.value;

  void setStartDate(DateTime date) {
    startDate.value = date;
    if (endDate.value != null && endDate.value!.isBefore(date)) {
      endDate.value = date;
    }
    _recalcDays();
  }

  void setEndDate(DateTime date) {
    endDate.value = date;
    _recalcDays();
  }

  void _recalcDays() {
    if (startDate.value == null || endDate.value == null) return;
    if (isHalfDay.value) { totalDays.value = 1; return; }
    totalDays.value =
        (endDate.value!.difference(startDate.value!).inDays + 1).clamp(1, 999);
  }

  void toggleHalfDay(bool val) {
    isHalfDay.value      = val;
    halfDayDisplay.value = val ? 'Yes' : 'No';
    if (val && startDate.value != null) {
      endDate.value   = startDate.value;
      totalDays.value = 1;
    } else {
      _recalcDays();
    }
  }

  // Quality 30 + max 512px → ~20–40 KB → base64 ~28–55 KB
  Future<void> pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 30,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      attachmentBytes.value    = bytes;
      attachmentBase64.value   = base64Encode(bytes);
      attachmentFileName.value = file.name;

      debugPrint('📎 [LeaveVM] Attachment: ${file.name}');
      debugPrint('📎 [LeaveVM] Raw bytes : ${bytes.length}');
      debugPrint('📎 [LeaveVM] Base64 len: ${attachmentBase64.value.length} chars');
      debugPrint(attachmentBase64.value.length < 100000
          ? '✅ [LeaveVM] Size OK — will include in server payload'
          : '⚠️  [LeaveVM] Still large — will try multipart');
    } catch (e) {
      debugPrint('❌ [LeaveVM] Image pick failed: $e');
      Get.snackbar('Error', 'Could not pick image',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void removeAttachment() {
    attachmentBytes.value    = null;
    attachmentBase64.value   = '';
    attachmentFileName.value = '';
  }

  // ─── Submit ───────────────────────────────────────────────────────────────
  Future<void> submitLeave() async {
    if (!canSubmit) {
      // FIX 6: surface a clear message when employee info is missing
      if (empId.value.isEmpty || empName.value.isEmpty) {
        Get.snackbar(
          '⚠️ Employee Info Missing',
          'Could not load your profile. Please log out and log in again.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFF1A2B6D),
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
      return;
    }

    isLoading.value = true;
    try {
      // Generate leave ID
      await _initSerialCounter();
      String leaveId = _buildLeaveId(empId: empId.value);

      final now = DateTime.now();
      final leave = LeaveModel(
        id:              const Uuid().v4(),
        leaveId:         leaveId,
        empId:           empId.value,
        empName:         empName.value,
        jobRole:         jobRole.value,
        leaveType:       selectedLeaveType.value,
        startDate:       DateFormat('yyyy-MM-dd').format(startDate.value!),
        endDate:         DateFormat('yyyy-MM-dd').format(endDate.value!),
        totalDays:       totalDays.value,
        isHalfDay:       isHalfDay.value ? 1 : 0,
        reason:          reason.value.trim(),
        attachmentData:  attachmentBytes.value,
        // FIX 7: store null explicitly when no attachment (not empty string)
        attachmentImage: attachmentBase64.value.isNotEmpty
            ? attachmentBase64.value
            : null,
        applicationDate: DateFormat('yyyy-MM-dd').format(now),
        applicationTime: DateFormat('HH:mm:ss').format(now),
        status:          'pending',
        posted:          0,
        hasAttachment:   attachmentBytes.value != null ? 1 : 0,
      );

      debugPrint('📋 [LeaveVM] Submitting leave:');
      debugPrint('   leaveId  : ${leave.leaveId}');
      debugPrint('   empId    : "${leave.empId}"');
      debugPrint('   empName  : "${leave.empName}"');
      debugPrint('   leaveType: "${leave.leaveType}"');
      debugPrint('   startDate: "${leave.startDate}"');
      debugPrint('   endDate  : "${leave.endDate}"');
      debugPrint('   totalDays: ${leave.totalDays}');
      debugPrint('   reason   : "${leave.reason}"');
      debugPrint('   hasAttach: ${leave.hasAttachment}');

      final result = await _repo.submitLeave(leave);

      if (result['success'] == true) {
        Get.snackbar(
            '✅ Submitted',
            'Leave application sent successfully.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFF1A2B6D),
            colorText: Colors.white,
            duration: const Duration(seconds: 3));
      } else {
        Get.snackbar(
            '📥 Saved Offline',
            'Leave saved locally. Will sync when online.',
            snackPosition: SnackPosition.TOP,
            backgroundColor: const Color(0xFFF59E0B),
            colorText: Colors.white,
            duration: const Duration(seconds: 4));
      }

      // Increment serial for next leave
      _serialCounter++;
      await _saveSerialCounter();

      await Future.delayed(const Duration(milliseconds: 600));
      Get.back();
    } catch (e) {
      debugPrint('❌ [LeaveVM] Submit error: $e');
      Get.snackbar('Error', 'Something went wrong. Please try again.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }
}