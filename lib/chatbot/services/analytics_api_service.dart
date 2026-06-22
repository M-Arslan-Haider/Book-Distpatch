import 'package:dio/dio.dart';

class AnalyticsApiService {
  final Dio dio;

  AnalyticsApiService(this.dio);

  Future<Map<String, dynamic>> getMonthly({
    required String empId,
    required String month,
  }) async {
    final res = await dio.get(
      'http://oracle.metaxperts.net/ords/gps_workforce/attendanceanalytics/get/',
      queryParameters: {
        'emp_id': empId,
        'month': month,
      },
    );

    return res.data;
  }
}