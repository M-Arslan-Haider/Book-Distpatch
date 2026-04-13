//
//
// /// Login model - company filtering is handled by backend API
// class LoginModels {
//   int? emp_id;
//   String? portal_password;
//   String? emp_name;
//   String? job;
//   String? geo_fencing;
//   String? company_code; // ✅ Added for dual validation
//
//   LoginModels({
//     this.emp_id,
//     this.portal_password,
//     this.emp_name,
//     this.job,
//     this.geo_fencing,
//     this.company_code,
//   });
//
//   factory LoginModels.fromJson(Map<String, dynamic> json) {
//     return LoginModels(
//       emp_id: json['emp_id'],
//       portal_password: json['portal_password'],
//       emp_name: json['emp_name'],
//       job: json['job'],
//       geo_fencing: json['geo_fencing'],
//       company_code: json['company_code'],
//     );
//   }
//
//   Map<String, dynamic> toJson() {
//     return {
//       'emp_id': emp_id,
//       'portal_password': portal_password,
//       'emp_name': emp_name,
//       'job': job,
//       'geo_fencing': geo_fencing,
//       'company_code': company_code,
//     };
//   }
// }
/// Login model - company filtering is handled by backend API
class LoginModels {
  int? emp_id;
  String? portal_password;
  String? emp_name;
  String? job;
  String? geo_fencing;
  String? company_code;

  // New fields for end time, overtime, and shift
  String? end_time;
  String? over_time;
  String? shift;

  LoginModels({
    this.emp_id,
    this.portal_password,
    this.emp_name,
    this.job,
    this.geo_fencing,
    this.company_code,
    this.end_time,
    this.over_time,
    this.shift,
  });

  factory LoginModels.fromJson(Map<String, dynamic> json) {
    return LoginModels(
      emp_id: json['emp_id'],
      portal_password: json['portal_password'],
      emp_name: json['emp_name'],
      job: json['job'],
      geo_fencing: json['geo_fencing'],
      company_code: json['company_code'],
      end_time: json['END_TIME']?.toString() ?? json['end_time']?.toString(),
      over_time: json['OVER_TIME']?.toString() ?? json['over_time']?.toString(),
      shift: json['SHIFT']?.toString() ?? json['shift']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'emp_id': emp_id,
      'portal_password': portal_password,
      'emp_name': emp_name,
      'job': job,
      'geo_fencing': geo_fencing,
      'company_code': company_code,
      'END_TIME': end_time,
      'OVER_TIME': over_time,
      'SHIFT': shift,
    };
  }

  // Helper methods
  bool get isOvertimeAllowed {
    final overtime = over_time?.toLowerCase().trim();
    return overtime == 'yes' || overtime == 'y' || overtime == 'true';
  }

  String get effectiveShift {
    final shiftValue = shift?.toLowerCase().trim();
    if (shiftValue == 'night') return 'Night';
    return 'Day'; // Default to Day for null or any other value
  }

  DateTime? get parsedEndTime {
    if (end_time == null || end_time!.isEmpty) return null;
    final now = DateTime.now();
    final parts = end_time!.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final second = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
    return DateTime(now.year, now.month, now.day, hour, minute, second);
  }
}