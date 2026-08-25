
class FollowupModel {
  String id; // local uuid
  String fuNo; // e.g. FU-2026-0001
  String? companyCode;

  String? visitNo;      // Display only (e.g., VIS-2026-0023)
  String? visitId;      // ✅ Actual visit_id (NUMBER) for API
  String? leadNo;

  String customer;
  String mobile;
  String empId;
  String empName;

  String date; // yyyy-MM-dd
  String time; // HH:mm
  String method;
  String priority;
  String reminder;
  String purpose;
  String notes;

  String status;
  String? result;
  String? resultResponse;
  String? resultRemarks;
  String? nextFuNo;
  String? rating;  // ✅ NEW: Rating field (e.g., 1-5 stars or Excellent/Good/Average/Poor)

  bool posted;

  FollowupModel({
    required this.id,
    required this.fuNo,
    this.companyCode,
    this.visitNo,
    this.visitId,
    this.leadNo,
    this.customer = '',
    this.mobile = '',
    this.empId = '',
    this.empName = '',
    required this.date,
    required this.time,
    this.method = 'Phone Call',
    this.priority = 'Medium',
    this.reminder = '1 Hour Before',
    this.purpose = '',
    this.notes = '',
    this.status = 'Pending',
    this.result,
    this.resultResponse,
    this.resultRemarks,
    this.nextFuNo,
    this.rating,  // ✅ NEW
    this.posted = false,
  });

  bool get isOverdue {
    if (status != 'Pending') return false;
    final today = DateTime.now();
    final d = DateTime.tryParse(date);
    if (d == null) return false;
    final todayOnly = DateTime(today.year, today.month, today.day);
    return d.isBefore(todayOnly);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fuNo': fuNo,
    'companyCode': companyCode,
    'visitNo': visitNo,
    'visitId': visitId,
    'leadNo': leadNo,
    'customer': customer,
    'mobile': mobile,
    'empId': empId,
    'empName': empName,
    'date': date,
    'time': time,
    'method': method,
    'priority': priority,
    'reminder': reminder,
    'purpose': purpose,
    'notes': notes,
    'status': status,
    'result': result,
    'resultResponse': resultResponse,
    'resultRemarks': resultRemarks,
    'nextFuNo': nextFuNo,
    'rating': rating,  // ✅ NEW
    'posted': posted,
  };

  factory FollowupModel.fromJson(Map<String, dynamic> j) => FollowupModel(
    id: j['id']?.toString() ?? '',
    fuNo: j['fuNo']?.toString() ?? '',
    companyCode: j['companyCode']?.toString(),
    visitNo: j['visitNo']?.toString(),
    visitId: j['visitId']?.toString(),
    leadNo: j['leadNo']?.toString(),
    customer: j['customer']?.toString() ?? '',
    mobile: j['mobile']?.toString() ?? '',
    empId: j['empId']?.toString() ?? '',
    empName: j['empName']?.toString() ?? '',
    date: j['date']?.toString() ?? '',
    time: j['time']?.toString() ?? '',
    method: j['method']?.toString() ?? 'Phone Call',
    priority: j['priority']?.toString() ?? 'Medium',
    reminder: j['reminder']?.toString() ?? '1 Hour Before',
    purpose: j['purpose']?.toString() ?? '',
    notes: j['notes']?.toString() ?? '',
    status: j['status']?.toString() ?? 'Pending',
    result: j['result']?.toString(),
    resultResponse: j['resultResponse']?.toString(),
    resultRemarks: j['resultRemarks']?.toString(),
    nextFuNo: j['nextFuNo']?.toString(),
    rating: j['rating']?.toString(),  // ✅ NEW
    posted: j['posted'] == true,
  );
}