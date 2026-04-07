//
// /// Login model - company filtering is handled by backend API
// class LoginModels {
//   int? emp_id;
//   String? portal_password;
//   String? emp_name;
//   String? job;
//   String? geo_fencing; // GEO_FENCING field from hr_emp_info
//
//   LoginModels({
//     this.emp_id,
//     this.portal_password,
//     this.emp_name,
//     this.job,
//     this.geo_fencing,
//   });
//
//   factory LoginModels.fromJson(Map<String, dynamic> json) {
//     return LoginModels(
//       emp_id: json['emp_id'],
//       portal_password: json['portal_password'],
//       emp_name: json['emp_name'],
//       job: json['job'],
//       geo_fencing: json['geo_fencing'],
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
  String? company_code; // ✅ Added for dual validation

  LoginModels({
    this.emp_id,
    this.portal_password,
    this.emp_name,
    this.job,
    this.geo_fencing,
    this.company_code,
  });

  factory LoginModels.fromJson(Map<String, dynamic> json) {
    return LoginModels(
      emp_id: json['emp_id'],
      portal_password: json['portal_password'],
      emp_name: json['emp_name'],
      job: json['job'],
      geo_fencing: json['geo_fencing'],
      company_code: json['company_code'],
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
    };
  }
}