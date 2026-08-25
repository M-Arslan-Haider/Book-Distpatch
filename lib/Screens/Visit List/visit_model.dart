

class VisitModel {
  // ── Identity ───────────────────────────────────────────────────────────
  String id;          // ✅ Local numeric ID (1, 2, 3, 4, 5...)
  String visitNo;     // e.g. VIS-2026-0001 (from DB)
  String? dbVisitId;  // Database VISIT_ID (NUMBER) from API response
  String? companyCode;

  // ── Visit Information ─────────────────────────────────────────────────
  String date;
  String time;
  String empId;
  String empName;
  String visitType;
  String status;

  // ── Customer Reference ────────────────────────────────────────────────
  String customerId;
  String customer;

  // ── Customer Information ──────────────────────────────────────────────
  String mobile;
  String email;
  String cnic;
  String address;

  // ── Property Interest ─────────────────────────────────────────────────
  String project;
  String propType;
  String location;
  String propSize;
  double budgetFrom;
  double budgetTo;
  String timeline;

  // ── GPS Information ────────────────────────────────────────────────────
  String gpsStatus;
  double? gpsLat;
  double? gpsLng;
  double? gpsAcc;

  // ── Visit Outcome ──────────────────────────────────────────────────────
  String response;
  String interest;
  String outcome;
  String nextAction;
  String fuDate;
  String fuTime;
  String remarks;

  // ── Attachments ────────────────────────────────────────────────────────
  String? photoBase64;
  String? photoFileName;
  bool hasSignature;

  // ── Meta ───────────────────────────────────────────────────────────────
  bool converted;
  String? leadNo;
  bool posted;

  VisitModel({
    required this.id,
    required this.visitNo,
    this.dbVisitId,
    this.companyCode,
    required this.date,
    required this.time,
    required this.empId,
    required this.empName,
    this.visitType = 'Site Visit',
    this.status = 'Planned',
    this.customerId = '',
    this.customer = '',
    this.mobile = '',
    this.email = '',
    this.cnic = '',
    this.address = '',
    this.project = '',
    this.propType = '',
    this.location = '',
    this.propSize = '',
    this.budgetFrom = 0,
    this.budgetTo = 0,
    this.timeline = '',
    this.gpsStatus = 'Not Captured',
    this.gpsLat,
    this.gpsLng,
    this.gpsAcc,
    this.response = '',
    this.interest = '',
    this.outcome = '',
    this.nextAction = '',
    this.fuDate = '',
    this.fuTime = '',
    this.remarks = '',
    this.photoBase64,
    this.photoFileName,
    this.hasSignature = false,
    this.converted = false,
    this.leadNo,
    this.posted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'visitNo': visitNo,
    'dbVisitId': dbVisitId,
    'companyCode': companyCode,
    'date': date,
    'time': time,
    'empId': empId,
    'empName': empName,
    'visitType': visitType,
    'status': status,
    'customerId': customerId,
    'customer': customer,
    'mobile': mobile,
    'email': email,
    'cnic': cnic,
    'address': address,
    'project': project,
    'propType': propType,
    'location': location,
    'propSize': propSize,
    'budgetFrom': budgetFrom,
    'budgetTo': budgetTo,
    'timeline': timeline,
    'gpsStatus': gpsStatus,
    'gpsLat': gpsLat,
    'gpsLng': gpsLng,
    'gpsAcc': gpsAcc,
    'response': response,
    'interest': interest,
    'outcome': outcome,
    'nextAction': nextAction,
    'fuDate': fuDate,
    'fuTime': fuTime,
    'remarks': remarks,
    'photoBase64': photoBase64,
    'photoFileName': photoFileName,
    'hasSignature': hasSignature,
    'converted': converted,
    'leadNo': leadNo,
    'posted': posted,
  };

  factory VisitModel.fromJson(Map<String, dynamic> j) => VisitModel(
    id: j['id']?.toString() ?? '',
    visitNo: j['visitNo']?.toString() ?? '',
    dbVisitId: j['dbVisitId']?.toString(),
    companyCode: j['companyCode']?.toString(),
    date: j['date']?.toString() ?? '',
    time: j['time']?.toString() ?? '',
    empId: j['empId']?.toString() ?? '',
    empName: j['empName']?.toString() ?? '',
    visitType: j['visitType']?.toString() ?? 'Site Visit',
    status: j['status']?.toString() ?? 'Planned',
    customerId: j['customerId']?.toString() ?? '',
    customer: j['customer']?.toString() ?? '',
    mobile: j['mobile']?.toString() ?? '',
    email: j['email']?.toString() ?? '',
    cnic: j['cnic']?.toString() ?? '',
    address: j['address']?.toString() ?? '',
    project: j['project']?.toString() ?? '',
    propType: j['propType']?.toString() ?? '',
    location: j['location']?.toString() ?? '',
    propSize: j['propSize']?.toString() ?? '',
    budgetFrom: (j['budgetFrom'] as num?)?.toDouble() ?? 0,
    budgetTo: (j['budgetTo'] as num?)?.toDouble() ?? 0,
    timeline: j['timeline']?.toString() ?? '',
    gpsStatus: j['gpsStatus']?.toString() ?? 'Not Captured',
    gpsLat: (j['gpsLat'] as num?)?.toDouble(),
    gpsLng: (j['gpsLng'] as num?)?.toDouble(),
    gpsAcc: (j['gpsAcc'] as num?)?.toDouble(),
    response: j['response']?.toString() ?? '',
    interest: j['interest']?.toString() ?? '',
    outcome: j['outcome']?.toString() ?? '',
    nextAction: j['nextAction']?.toString() ?? '',
    fuDate: j['fuDate']?.toString() ?? '',
    fuTime: j['fuTime']?.toString() ?? '',
    remarks: j['remarks']?.toString() ?? '',
    photoBase64: j['photoBase64']?.toString(),
    photoFileName: j['photoFileName']?.toString(),
    hasSignature: j['hasSignature'] == true,
    converted: j['converted'] == true,
    leadNo: j['leadNo']?.toString(),
    posted: j['posted'] == true,
  );
}