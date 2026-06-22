import 'package:dio/dio.dart';

class AttendanceApiService {
  final Dio dio;

  AttendanceApiService(this.dio);

  Future<Map<String, dynamic>> getDaily({
    required String empId,
    required String companyCode,
    required String month,
  }) async {
    final res = await dio.get(
      'http://oracle.metaxperts.net/ords/gps_workforce/gpsattendancereport/get/',
      queryParameters: {
        'emp_id': empId,
        'company_code': companyCode,
        'month': month,
      },
    );

    return res.data;
  }
}