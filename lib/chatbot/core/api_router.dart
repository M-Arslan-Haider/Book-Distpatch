// // import '../services/analytics_api_service.dart';
// // import '../services/attendance_api_service.dart';
// // import '../services/session_helper.dart';
// // import 'intent_detector.dart';
// // import 'response_builder.dart';
// //
// // class ApiRouter {
// //   final AnalyticsApiService analytics;
// //   final AttendanceApiService daily;
// //
// //   ApiRouter(this.analytics, this.daily);
// //
// //   static const _monthlyIntents = {
// //     ChatIntent.attendanceSummary,
// //     ChatIntent.presentDays,
// //     ChatIntent.lateInfo,
// //     ChatIntent.onTimeInfo,
// //     ChatIntent.earlyExitInfo,
// //     ChatIntent.workingHours,
// //     ChatIntent.halfDays,
// //     ChatIntent.geoViolations,
// //     ChatIntent.offlineEvents,
// //     ChatIntent.holidays,
// //     ChatIntent.leaveInfo,
// //   };
// //
// //   Future<String> ask(String message) async {
// //     print('=== ApiRouter.ask called ===');
// //     print('Message: $message');
// //
// //     try {
// //       final intent = IntentDetector.detect(message);
// //       print('Detected intent: $intent');
// //
// //       if (intent == ChatIntent.greeting) {
// //         return "Assalam-o-Alaikum! Aap apni attendance, late days, "
// //             "working hours ya leaves ke baare mein pooch sakte hain.";
// //       }
// //
// //       final empId = await SessionHelper.getEmpId();
// //       print('Employee ID: $empId');
// //       if (empId.isEmpty) {
// //         return "Employee ID nahi mila. Pehle login karein.";
// //       }
// //
// //       final month = await SessionHelper.getMonth();
// //       print('Month: $month');
// //
// //       if (_monthlyIntents.contains(intent)) {
// //         print('Fetching monthly data...');
// //         final data = await analytics.getMonthly(empId: empId, month: month);
// //         print('Monthly data received: ${data.keys}');
// //         print('Data items: ${data['items']}');
// //
// //         final response = ResponseBuilder.buildMonthly(intent, data);
// //         print('Response built: $response');
// //         return response;
// //       }
// //
// //       if (intent == ChatIntent.dailyDetail) {
// //         print('Fetching daily data...');
// //         final company = await SessionHelper.getCompanyCode();
// //         print('Company code: $company');
// //         final data = await daily.getDaily(
// //           empId: empId,
// //           companyCode: company,
// //           month: month,
// //         );
// //         print('Daily data received: ${data.keys}');
// //         final response = ResponseBuilder.buildDaily(data);
// //         print('Response built: $response');
// //         return response;
// //       }
// //
// //       return "Maazrat, mujhe aap ka sawal samajh nahi aaya. Aap 'attendance', "
// //           "'late', 'working hours', 'leave' ya 'today' ke baare mein pooch sakte hain.";
// //     } catch (e, stackTrace) {
// //       print('ERROR in ApiRouter.ask: $e');
// //       print('Stack trace: $stackTrace');
// //       return "Kuch error aa gaya: ${e.toString()}";
// //     }
// //   }
// // }
//
// import '../services/analytics_api_service.dart';
// import '../services/attendance_api_service.dart';
// import '../session_helper.dart';
// import 'intent_detector.dart';
// import 'response_builder.dart';
//
// class ApiRouter {
//   final AnalyticsApiService analytics;
//   final AttendanceApiService daily;
//
//   ApiRouter(this.analytics, this.daily);
//
//   static const _monthlyIntents = {
//     ChatIntent.attendanceSummary,
//     ChatIntent.presentDays,
//     ChatIntent.lateInfo,
//     ChatIntent.onTimeInfo,
//     ChatIntent.earlyExitInfo,
//     ChatIntent.workingHours,
//     ChatIntent.halfDays,
//     ChatIntent.geoViolations,
//     ChatIntent.offlineEvents,
//     ChatIntent.holidays,
//     ChatIntent.leaveInfo,
//   };
//
//   static const _followUpIntents = {
//     ChatIntent.presentDates,
//     ChatIntent.lateDates,
//     ChatIntent.onTimeDates,
//     ChatIntent.earlyExitDates,
//     ChatIntent.dailyWorkingHours,
//     ChatIntent.halfDayDates,
//     ChatIntent.geoViolationDates,
//     ChatIntent.offlineEventDates,
//     ChatIntent.leaveDates,
//   };
//
//   Future<String> ask(String message) async {
//     print('=== ApiRouter.ask called ===');
//     print('Message: $message');
//
//     try {
//       final intent = IntentDetector.detect(message);
//       print('Detected intent: $intent');
//
//       if (intent == ChatIntent.greeting) {
//         return "Assalam-o-Alaikum! Main apni attendance, late days, "
//             "working hours ya leaves ke baare mein pooch sakte hain.\n\n"
//             "Main ye sab bata sakta hoon:\n"
//             "• 📊 Total attendance summary\n"
//             "• ✅ Present days aur dates\n"
//             "• ⏰ Late arrivals aur dates\n"
//             "• 🕐 Waqt par aane ki dates\n"
//             "• 🚪 Early exit aur dates\n"
//             "• ⏱️ Working hours\n"
//             "• 🌗 Half days aur dates\n"
//             "• 📍 Geo violations aur dates\n"
//             "• 📱 Offline events aur dates\n"
//             "• 🏖️ Leave aur dates";
//       }
//
//       final empId = await SessionHelper.getEmpId();
//       if (empId.isEmpty) {
//         return "Employee ID nahi mila. Pehle login karein.";
//       }
//
//       final month = await SessionHelper.getMonth();
//       print('Employee ID: $empId');
//       print('Month: $month');
//
//       if (_monthlyIntents.contains(intent)) {
//         final data = await analytics.getMonthly(empId: empId, month: month);
//         print('Monthly data received: ${data.keys}');
//         return ResponseBuilder.buildMonthly(intent, data);
//       }
//
//       if (_followUpIntents.contains(intent)) {
//         // For follow-up questions, we need daily data
//         final company = await SessionHelper.getCompanyCode();
//         final dailyData = await daily.getDaily(
//           empId: empId,
//           companyCode: company,
//           month: month,
//         );
//         return ResponseBuilder.buildDailyFollowUp(intent, dailyData);
//       }
//
//       if (intent == ChatIntent.dailyDetail) {
//         final company = await SessionHelper.getCompanyCode();
//         print('Fetching daily data...');
//         print('Company code: $company');
//         final data = await daily.getDaily(
//           empId: empId,
//           companyCode: company,
//           month: month,
//         );
//         print('Daily data received: ${data.keys}');
//         final response = ResponseBuilder.buildDaily(data);
//         print('Response built: $response');
//         return response;
//       }
//
//       return "Maazrat, mujhe aap ka sawal samajh nahi aaya.\n\n"
//           "Aap ye pooch sakte hain:\n"
//           "• 'meri attendance batao'\n"
//           "• 'kitne din present raha'\n"
//           "• 'kis kis date ko present tha'\n"
//           "• 'kitni late hui'\n"
//           "• 'kis date ko late aaya'\n"
//           "• 'kitni working hours hain'\n"
//           "• 'kya koi violation hai'\n"
//           "• 'kis date ko violation hui'";
//     } catch (e, stackTrace) {
//       print('ERROR in ApiRouter.ask: $e');
//       print('Stack trace: $stackTrace');
//       return "Kuch error aa gaya: ${e.toString()}";
//     }
//   }
// }

import '../services/analytics_api_service.dart';
import '../services/attendance_api_service.dart';
import '../session_helper.dart';
import 'intent_detector.dart';
import 'response_builder.dart';

class ApiRouter {
  final AnalyticsApiService analytics;
  final AttendanceApiService daily;

  ApiRouter(this.analytics, this.daily);

  static const _monthlyIntents = {
    ChatIntent.attendanceSummary,
    ChatIntent.presentDays,
    ChatIntent.lateInfo,
    ChatIntent.onTimeInfo,
    ChatIntent.earlyExitInfo,
    ChatIntent.workingHours,
    ChatIntent.halfDays,
    ChatIntent.geoViolations,
    ChatIntent.offlineEvents,
    ChatIntent.holidays,
    ChatIntent.leaveInfo,
  };

  static const _followUpIntents = {
    ChatIntent.presentDates,
    ChatIntent.lateDates,
    ChatIntent.onTimeDates,
    ChatIntent.earlyExitDates,
    ChatIntent.dailyWorkingHours,
    ChatIntent.halfDayDates,
    ChatIntent.geoViolationDates,
    ChatIntent.offlineEventDates,
    ChatIntent.leaveDates,
  };

  Future<String> ask(String message) async {
    print('=== ApiRouter.ask called ===');
    print('Message: $message');

    try {
      final intent = IntentDetector.detect(message);
      print('Detected intent: $intent');

      if (intent == ChatIntent.greeting) {
        return "Assalam-o-Alaikum! Main apni attendance, late days, "
            "working hours ya leaves ke baare mein pooch sakte hain.\n\n"
            "Main ye sab bata sakta hoon:\n"
            "• 📊 Total attendance summary\n"
            "• ✅ Present days aur dates\n"
            "• ⏰ Late arrivals aur dates\n"
            "• 🕐 Waqt par aane ki dates\n"
            "• 🚪 Early exit aur dates\n"
            "• ⏱️ Working hours\n"
            "• 🌗 Half days aur dates\n"
            "• 📍 Geo violations aur dates\n"
            "• 📱 Offline events aur dates\n"
            "• 🏖️ Leave aur dates\n\n"
            "Aap kisi bhi mahine ke baare mein pooch sakte hain, jaise:\n"
            "• 'meri April 2026 ki attendance batao'\n"
            "• 'May 2026 mein kitne din present tha'";
      }

      final empId = await SessionHelper.getEmpId();
      if (empId.isEmpty) {
        return "Employee ID nahi mila. Pehle login karein.";
      }

      // Extract month from the query - now synchronous
      final month = SessionHelper.extractMonthFromQuery(message);
      print('Employee ID: $empId');
      print('Month from query: $month');

      if (_monthlyIntents.contains(intent)) {
        final data = await analytics.getMonthly(empId: empId, month: month);
        print('Monthly data received: ${data.keys}');
        // Pass the month to the response builder
        return ResponseBuilder.buildMonthlyWithMonth(intent, data, month);
      }

      if (_followUpIntents.contains(intent)) {
        // For follow-up questions, we need daily data
        final company = await SessionHelper.getCompanyCode();
        final dailyData = await daily.getDaily(
          empId: empId,
          companyCode: company,
          month: month,
        );
        return ResponseBuilder.buildDailyFollowUp(intent, dailyData);
      }

      if (intent == ChatIntent.dailyDetail) {
        final company = await SessionHelper.getCompanyCode();
        print('Fetching daily data...');
        print('Company code: $company');
        final data = await daily.getDaily(
          empId: empId,
          companyCode: company,
          month: month,
        );
        print('Daily data received: ${data.keys}');
        final response = ResponseBuilder.buildDaily(data);
        print('Response built: $response');
        return response;
      }

      return "Maazrat, mujhe aap ka sawal samajh nahi aaya.\n\n"
          "Aap ye pooch sakte hain:\n"
          "• 'meri attendance batao'\n"
          "• 'meri April 2026 ki attendance batao'\n"
          "• 'kitne din present raha'\n"
          "• 'kis kis date ko present tha'\n"
          "• 'kitni late hui'\n"
          "• 'kis date ko late aaya'\n"
          "• 'kitni working hours hain'\n"
          "• 'kya koi violation hai'\n"
          "• 'kis date ko violation hui'";
    } catch (e, stackTrace) {
      print('ERROR in ApiRouter.ask: $e');
      print('Stack trace: $stackTrace');
      return "Kuch error aa gaya: ${e.toString()}";
    }
  }
}