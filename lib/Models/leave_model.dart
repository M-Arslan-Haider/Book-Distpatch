import 'dart:typed_data';

class LeaveModel {
  final String id;
  final String leaveId;
  final String empId;
  final String empName;
  final String jobRole;
  final String leaveType;
  final String startDate;
  final String endDate;
  final int totalDays;
  final int isHalfDay;
  final String reason;
  final Uint8List? attachmentData;
  final String? attachmentImage;
  final String applicationDate;
  final String applicationTime;
  final String status;
  final int posted;
  final int hasAttachment;
  final String? company_code;

  // ── NEW: half-day time fields ──────────────────────────────────────────────
  final String? halfDayStartTime; // e.g. "09:00"
  final String? halfDayEndTime;   // e.g. "13:00"

  LeaveModel({
    required this.id,
    required this.leaveId,
    required this.empId,
    required this.empName,
    required this.jobRole,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    this.isHalfDay = 0,
    required this.reason,
    this.attachmentData,
    this.attachmentImage,
    required this.applicationDate,
    required this.applicationTime,
    this.status = 'pending',
    this.posted = 0,
    this.hasAttachment = 0,
    this.company_code,
    this.halfDayStartTime, // ← NEW
    this.halfDayEndTime,   // ← NEW
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'leave_id': leaveId,
      'emp_id': empId,
      'emp_name': empName,
      'job_role': jobRole,
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
      'total_days': totalDays,
      'is_half_day': isHalfDay,
      'reason': reason,
      'attachment_data': attachmentData,
      'attachment_image': attachmentImage,
      'application_date': applicationDate,
      'application_time': applicationTime,
      'status': status,
      'posted': posted,
      'has_attachment': hasAttachment,
      'company_code': company_code,
      'half_day_start_time': halfDayStartTime, // ← NEW
      'half_day_end_time': halfDayEndTime,     // ← NEW
    };
  }

  factory LeaveModel.fromMap(Map<String, dynamic> map) {
    return LeaveModel(
      id: map['id'] ?? '',
      leaveId: map['leave_id'] ?? '',
      empId: map['emp_id'] ?? '',
      empName: map['emp_name'] ?? '',
      jobRole: map['job_role'] ?? '',
      leaveType: map['leave_type'] ?? '',
      startDate: map['start_date'] ?? '',
      endDate: map['end_date'] ?? '',
      totalDays: map['total_days'] ?? 0,
      isHalfDay: map['is_half_day'] ?? 0,
      reason: map['reason'] ?? '',
      attachmentData: map['attachment_data'],
      attachmentImage: map['attachment_image'],
      applicationDate: map['application_date'] ?? '',
      applicationTime: map['application_time'] ?? '',
      status: map['status'] ?? 'pending',
      posted: map['posted'] ?? 0,
      hasAttachment: map['has_attachment'] ?? 0,
      company_code: map['company_code'],
      halfDayStartTime: map['half_day_start_time'], // ← NEW
      halfDayEndTime: map['half_day_end_time'],     // ← NEW
    );
  }

  /// Payload sent to Oracle REST API
  Map<String, dynamic> toApiPayload() {
    return {
      'leave_id': leaveId,
      'emp_id': empId,
      'emp_name': empName,
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
      'total_days': totalDays,
      'is_half_day': isHalfDay,
      'reason': reason,
      'body': (attachmentImage != null && attachmentImage!.isNotEmpty)
          ? attachmentImage
          : null,
      'application_date': applicationDate,
      'application_time': applicationTime,
      'status': status,
      'posted': posted,
      'company_code': company_code,
      'half_day_start_time': halfDayStartTime, // ← NEW
      'half_day_end_time': halfDayEndTime,     // ← NEW
    };
  }
}