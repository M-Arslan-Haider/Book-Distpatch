// // // // // // enum ChatIntent {
// // // // // //   greeting,
// // // // // //   attendanceSummary,
// // // // // //   presentDays,
// // // // // //   lateInfo,
// // // // // //   onTimeInfo,
// // // // // //   earlyExitInfo,
// // // // // //   workingHours,
// // // // // //   halfDays,
// // // // // //   geoViolations,
// // // // // //   offlineEvents,
// // // // // //   holidays,
// // // // // //   leaveInfo,
// // // // // //   dailyDetail,
// // // // // //   unknown,
// // // // // // }
// // // // // //
// // // // // // class IntentDetector {
// // // // // //   static ChatIntent detect(String text) {
// // // // // //     print('=== IntentDetector.detect called ===');
// // // // // //     print('Text: $text');
// // // // // //
// // // // // //     final q = text.toLowerCase().trim();
// // // // // //     print('Lowercase: $q');
// // // // // //
// // // // // //     if (_any(q, ['hi', 'hello', 'hey', 'salam', 'assalam', 'سلام', 'ہیلو'])) {
// // // // // //       print('Intent: greeting');
// // // // // //       return ChatIntent.greeting;
// // // // // //     }
// // // // // //
// // // // // //     if (_any(q, [
// // // // // //       'summary',
// // // // // //       'overall',
// // // // // //       'performance',
// // // // // //       'پرفارمنس',
// // // // // //       'تفصیل',
// // // // // //       'sara hisab',
// // // // // //       'pura hisab',
// // // // // //     ])) {
// // // // // //       print('Intent: attendanceSummary');
// // // // // //       return ChatIntent.attendanceSummary;
// // // // // //     }
// // // // // //
// // // // // //     if (_any(q, ['today', 'yesterday', 'aaj', 'kal', 'آج', 'کل'])) {
// // // // // //       print('Intent: dailyDetail');
// // // // // //       return ChatIntent.dailyDetail;
// // // // // //     }
// // // // // //
// // // // // //     if (_any(q, ['on time', 'ontime', 'وقت پر', 'waqt par', 'waqt pe'])) {
// // // // // //       print('Intent: onTimeInfo');
// // // // // //       return ChatIntent.onTimeInfo;
// // // // // //     }
// // // // // //
// // // // // //     if (_any(q, ['early exit', 'early leave', 'jaldi gaya', 'jaldi chala', 'جلدی'])) {
// // // // // //       print('Intent: earlyExitInfo');
// // // // // //       return ChatIntent.earlyExitInfo;
// // // // // //     }
// // // // // //
// // // // // //     if (_any(q, ['late', 'دیر', 'der se', 'lait'])) {
// // // // // //       print('Intent: lateInfo');
// // // // // //       return ChatIntent.lateInfo;
// // // // // //     }
// // // // // //
// // // // // //     if (_any(q, ['working hour', 'work hour', 'ghante', 'گھنٹے', 'kaam ke ghante'])) {
// // // // // //       print('Intent: workingHours');
// // // // // //       return ChatIntent.workingHours;
// // // // // //     }
// // // // // //
// // // // // //     if (_any(q, ['half day', 'half din', 'آدھا دن'])) {
// // // // // //       print('Intent: halfDays');
// // // // // //       return ChatIntent.halfDays;
// // // // // //     }
// // // // // //
// // // // // //     if (_any(q, ['geo', 'violation', 'geofence', 'geo-fence', 'location rule'])) {
// // // // // //       print('Intent: geoViolations');
// // // // // //       return ChatIntent.geoViolations;
// // // // // //     }
// // // // // //
// // // // // //     if (_any(q, ['offline'])) {
// // // // // //       print('Intent: offlineEvents');
// // // // // //       return ChatIntent.offlineEvents;
// // // // // //     }
// // // // // //
// // // // // //     if (_any(q, ['public holiday', 'govt holiday', 'sarkari chutti', 'holidays this month'])) {
// // // // // //       print('Intent: holidays');
// // // // // //       return ChatIntent.holidays;
// // // // // //     }
// // // // // //
// // // // // //     if (_any(q, ['leave', 'چھٹی', 'chutti'])) {
// // // // // //       print('Intent: leaveInfo');
// // // // // //       return ChatIntent.leaveInfo;
// // // // // //     }
// // // // // //
// // // // // //     if (_any(q, ['present', 'حاضر', 'hazri', 'haziri', 'attendance'])) {
// // // // // //       print('Intent: presentDays');
// // // // // //       return ChatIntent.presentDays;
// // // // // //     }
// // // // // //
// // // // // //     print('Intent: unknown');
// // // // // //     return ChatIntent.unknown;
// // // // // //   }
// // // // // //
// // // // // //   static bool _any(String text, List<String> keywords) {
// // // // // //     final result = keywords.any((k) => text.contains(k));
// // // // // //     if (result) {
// // // // // //       print('Match found: $text contains ${keywords.first}');
// // // // // //     }
// // // // // //     return result;
// // // // // //   }
// // // // // // }
// // // // //
// // // // // enum ChatIntent {
// // // // //   greeting,
// // // // //   attendanceSummary,
// // // // //   presentDays,
// // // // //   presentDates,
// // // // //   lateInfo,
// // // // //   lateDates,
// // // // //   onTimeInfo,
// // // // //   onTimeDates,
// // // // //   earlyExitInfo,
// // // // //   earlyExitDates,
// // // // //   workingHours,
// // // // //   dailyWorkingHours,
// // // // //   halfDays,
// // // // //   halfDayDates,
// // // // //   geoViolations,
// // // // //   geoViolationDates,
// // // // //   offlineEvents,
// // // // //   offlineEventDates,
// // // // //   holidays,
// // // // //   leaveInfo,
// // // // //   leaveDates,
// // // // //   dailyDetail,
// // // // //   unknown,
// // // // // }
// // // // //
// // // // // class IntentDetector {
// // // // //   static ChatIntent detect(String text) {
// // // // //     final q = text.toLowerCase().trim();
// // // // //     print('=== IntentDetector.detect called ===');
// // // // //     print('Text: $text');
// // // // //     print('Lowercase: $q');
// // // // //
// // // // //     // Greeting
// // // // //     if (_any(q, ['hi', 'hello', 'hey', 'salam', 'assalam', 'سلام', 'ہیلو', 'kya haal'])) {
// // // // //       print('Intent: greeting');
// // // // //       return ChatIntent.greeting;
// // // // //     }
// // // // //
// // // // //     // Summary
// // // // //     if (_any(q, ['summary', 'overall', 'performance', 'پرفارمنس', 'تفصیل',
// // // // //       'sara hisab', 'pura hisab', 'total detail', 'complete detail'])) {
// // // // //       print('Intent: attendanceSummary');
// // // // //       return ChatIntent.attendanceSummary;
// // // // //     }
// // // // //
// // // // //     // Daily detail
// // // // //     if (_any(q, ['today', 'yesterday', 'aaj', 'kal', 'آج', 'کل', 'current day', 'today detail'])) {
// // // // //       print('Intent: dailyDetail');
// // // // //       return ChatIntent.dailyDetail;
// // // // //     }
// // // // //
// // // // //     // Present dates (follow-up)
// // // // //     if (_any(q, ['kis kis date', 'kis date', 'kin din', 'which dates',
// // // // //       'kon si dates', 'dates of present'])) {
// // // // //       if (_any(q, ['present', 'hazir', 'حاضر'])) {
// // // // //         print('Intent: presentDates');
// // // // //         return ChatIntent.presentDates;
// // // // //       }
// // // // //     }
// // // // //
// // // // //     // Present days
// // // // //     if (_any(q, ['present', 'حاضر', 'hazri', 'haziri', 'attendance count',
// // // // //       'kitne din hazir', 'present days', 'present din'])) {
// // // // //       print('Intent: presentDays');
// // // // //       return ChatIntent.presentDays;
// // // // //     }
// // // // //
// // // // //     // Late dates (follow-up)
// // // // //     if (_any(q, ['kis date late', 'kis din late', 'late dates', 'which days late'])) {
// // // // //       print('Intent: lateDates');
// // // // //       return ChatIntent.lateDates;
// // // // //     }
// // // // //
// // // // //     // Late info
// // // // //     if (_any(q, ['late', 'دیر', 'der se', 'lait', 'late arrival'])) {
// // // // //       print('Intent: lateInfo');
// // // // //       return ChatIntent.lateInfo;
// // // // //     }
// // // // //
// // // // //     // On-time dates (follow-up)
// // // // //     if (_any(q, ['kis date waqt par', 'on time dates', 'which days on time'])) {
// // // // //       print('Intent: onTimeDates');
// // // // //       return ChatIntent.onTimeDates;
// // // // //     }
// // // // //
// // // // //     // On-time info
// // // // //     if (_any(q, ['on time', 'ontime', 'وقت پر', 'waqt par', 'waqt pe', 'time par'])) {
// // // // //       print('Intent: onTimeInfo');
// // // // //       return ChatIntent.onTimeInfo;
// // // // //     }
// // // // //
// // // // //     // Early exit dates (follow-up)
// // // // //     if (_any(q, ['kis date jaldi', 'early exit dates', 'which days early'])) {
// // // // //       print('Intent: earlyExitDates');
// // // // //       return ChatIntent.earlyExitDates;
// // // // //     }
// // // // //
// // // // //     // Early exit info
// // // // //     if (_any(q, ['early exit', 'early leave', 'jaldi gaya', 'jaldi chala', 'جلدی', 'jaldi nikla'])) {
// // // // //       print('Intent: earlyExitInfo');
// // // // //       return ChatIntent.earlyExitInfo;
// // // // //     }
// // // // //
// // // // //     // Daily working hours
// // // // //     if (_any(q, ['rozana', 'daily working', 'har din', 'per day', 'average hours'])) {
// // // // //       print('Intent: dailyWorkingHours');
// // // // //       return ChatIntent.dailyWorkingHours;
// // // // //     }
// // // // //
// // // // //     // Working hours
// // // // //     if (_any(q, ['working hour', 'work hour', 'ghante', 'گھنٹے', 'kaam ke ghante',
// // // // //       'hours', 'total hours', 'kitne ghante'])) {
// // // // //       print('Intent: workingHours');
// // // // //       return ChatIntent.workingHours;
// // // // //     }
// // // // //
// // // // //     // Half day dates (follow-up)
// // // // //     if (_any(q, ['kis date half', 'half day dates', 'which days half'])) {
// // // // //       print('Intent: halfDayDates');
// // // // //       return ChatIntent.halfDayDates;
// // // // //     }
// // // // //
// // // // //     // Half days
// // // // //     if (_any(q, ['half day', 'half din', 'آدھا دن', 'aadha din'])) {
// // // // //       print('Intent: halfDays');
// // // // //       return ChatIntent.halfDays;
// // // // //     }
// // // // //
// // // // //     // Geo violation dates (follow-up)
// // // // //     if (_any(q, ['kis date violation', 'violation dates', 'which days violation'])) {
// // // // //       print('Intent: geoViolationDates');
// // // // //       return ChatIntent.geoViolationDates;
// // // // //     }
// // // // //
// // // // //     // Geo violations
// // // // //     if (_any(q, ['geo', 'violation', 'geofence', 'geo-fence', 'location rule',
// // // // //       'violate kiya'])) {
// // // // //       print('Intent: geoViolations');
// // // // //       return ChatIntent.geoViolations;
// // // // //     }
// // // // //
// // // // //     // Offline event dates (follow-up)
// // // // //     if (_any(q, ['kis date offline', 'offline dates', 'which days offline'])) {
// // // // //       print('Intent: offlineEventDates');
// // // // //       return ChatIntent.offlineEventDates;
// // // // //     }
// // // // //
// // // // //     // Offline events
// // // // //     if (_any(q, ['offline', 'mode', 'no internet'])) {
// // // // //       print('Intent: offlineEvents');
// // // // //       return ChatIntent.offlineEvents;
// // // // //     }
// // // // //
// // // // //     // Holidays
// // // // //     if (_any(q, ['public holiday', 'govt holiday', 'sarkari chutti',
// // // // //       'holidays this month', 'chutti', 'holiday dates'])) {
// // // // //       print('Intent: holidays');
// // // // //       return ChatIntent.holidays;
// // // // //     }
// // // // //
// // // // //     // Leave dates (follow-up)
// // // // //     if (_any(q, ['kis date chutti', 'leave dates', 'which days leave'])) {
// // // // //       print('Intent: leaveDates');
// // // // //       return ChatIntent.leaveDates;
// // // // //     }
// // // // //
// // // // //     // Leave info
// // // // //     if (_any(q, ['leave', 'چھٹی', 'chutti'])) {
// // // // //       print('Intent: leaveInfo');
// // // // //       return ChatIntent.leaveInfo;
// // // // //     }
// // // // //
// // // // //     print('Intent: unknown');
// // // // //     return ChatIntent.unknown;
// // // // //   }
// // // // //
// // // // //   static bool _any(String text, List<String> keywords) {
// // // // //     return keywords.any((k) => text.contains(k));
// // // // //   }
// // // // // }
// // // //
// // // // enum ChatIntent {
// // // //   greeting,
// // // //   attendanceSummary,
// // // //   presentDays,
// // // //   presentDates,
// // // //   lateInfo,
// // // //   lateDates,
// // // //   onTimeInfo,
// // // //   onTimeDates,
// // // //   earlyExitInfo,
// // // //   earlyExitDates,
// // // //   workingHours,
// // // //   dailyWorkingHours,
// // // //   halfDays,
// // // //   halfDayDates,
// // // //   geoViolations,
// // // //   geoViolationDates,
// // // //   offlineEvents,
// // // //   offlineEventDates,
// // // //   holidays,
// // // //   leaveInfo,
// // // //   leaveDates,
// // // //   dailyDetail,
// // // //   unknown,
// // // // }
// // // //
// // // // class IntentDetector {
// // // //   static ChatIntent detect(String text) {
// // // //     final q = text.toLowerCase().trim();
// // // //     print('=== IntentDetector.detect called ===');
// // // //     print('Text: $text');
// // // //     print('Lowercase: $q');
// // // //
// // // //     // Greeting
// // // //     if (_any(q, ['hi', 'hello', 'hey', 'salam', 'assalam', 'سلام', 'ہیلو', 'kya haal'])) {
// // // //       print('Intent: greeting');
// // // //       return ChatIntent.greeting;
// // // //     }
// // // //
// // // //     // Summary - check for attendance query
// // // //     if (_any(q, ['summary', 'overall', 'performance', 'پرفارمنس', 'تفصیل',
// // // //       'sara hisab', 'pura hisab', 'total detail', 'complete detail',
// // // //       'attendance', 'haziri', 'حاضری', 'report', 'ripot'])) {
// // // //       print('Intent: attendanceSummary');
// // // //       return ChatIntent.attendanceSummary;
// // // //     }
// // // //
// // // //     // Daily detail
// // // //     if (_any(q, ['today', 'yesterday', 'aaj', 'kal', 'آج', 'کل', 'current day', 'today detail'])) {
// // // //       print('Intent: dailyDetail');
// // // //       return ChatIntent.dailyDetail;
// // // //     }
// // // //
// // // //     // Present dates (follow-up)
// // // //     if (_any(q, ['kis kis date', 'kis date', 'kin din', 'which dates',
// // // //       'kon si dates', 'dates of present'])) {
// // // //       if (_any(q, ['present', 'hazir', 'حاضر'])) {
// // // //         print('Intent: presentDates');
// // // //         return ChatIntent.presentDates;
// // // //       }
// // // //     }
// // // //
// // // //     // Present days
// // // //     if (_any(q, ['present', 'حاضر', 'hazri', 'haziri', 'attendance count',
// // // //       'kitne din hazir', 'present days', 'present din', 'kitne din aaye'])) {
// // // //       print('Intent: presentDays');
// // // //       return ChatIntent.presentDays;
// // // //     }
// // // //
// // // //     // Late dates (follow-up)
// // // //     if (_any(q, ['kis date late', 'kis din late', 'late dates', 'which days late'])) {
// // // //       print('Intent: lateDates');
// // // //       return ChatIntent.lateDates;
// // // //     }
// // // //
// // // //     // Late info
// // // //     if (_any(q, ['late', 'دیر', 'der se', 'lait', 'late arrival', 'kitni der'])) {
// // // //       print('Intent: lateInfo');
// // // //       return ChatIntent.lateInfo;
// // // //     }
// // // //
// // // //     // On-time dates (follow-up)
// // // //     if (_any(q, ['kis date waqt par', 'on time dates', 'which days on time'])) {
// // // //       print('Intent: onTimeDates');
// // // //       return ChatIntent.onTimeDates;
// // // //     }
// // // //
// // // //     // On-time info
// // // //     if (_any(q, ['on time', 'ontime', 'وقت پر', 'waqt par', 'waqt pe', 'time par'])) {
// // // //       print('Intent: onTimeInfo');
// // // //       return ChatIntent.onTimeInfo;
// // // //     }
// // // //
// // // //     // Early exit dates (follow-up)
// // // //     if (_any(q, ['kis date jaldi', 'early exit dates', 'which days early'])) {
// // // //       print('Intent: earlyExitDates');
// // // //       return ChatIntent.earlyExitDates;
// // // //     }
// // // //
// // // //     // Early exit info
// // // //     if (_any(q, ['early exit', 'early leave', 'jaldi gaya', 'jaldi chala', 'جلدی', 'jaldi nikla'])) {
// // // //       print('Intent: earlyExitInfo');
// // // //       return ChatIntent.earlyExitInfo;
// // // //     }
// // // //
// // // //     // Daily working hours
// // // //     if (_any(q, ['rozana', 'daily working', 'har din', 'per day', 'average hours'])) {
// // // //       print('Intent: dailyWorkingHours');
// // // //       return ChatIntent.dailyWorkingHours;
// // // //     }
// // // //
// // // //     // Working hours
// // // //     if (_any(q, ['working hour', 'work hour', 'ghante', 'گھنٹے', 'kaam ke ghante',
// // // //       'hours', 'total hours', 'kitne ghante', 'overtime'])) {
// // // //       print('Intent: workingHours');
// // // //       return ChatIntent.workingHours;
// // // //     }
// // // //
// // // //     // Half day dates (follow-up)
// // // //     if (_any(q, ['kis date half', 'half day dates', 'which days half'])) {
// // // //       print('Intent: halfDayDates');
// // // //       return ChatIntent.halfDayDates;
// // // //     }
// // // //
// // // //     // Half days
// // // //     if (_any(q, ['half day', 'half din', 'آدھا دن', 'aadha din'])) {
// // // //       print('Intent: halfDays');
// // // //       return ChatIntent.halfDays;
// // // //     }
// // // //
// // // //     // Geo violation dates (follow-up)
// // // //     if (_any(q, ['kis date violation', 'violation dates', 'which days violation'])) {
// // // //       print('Intent: geoViolationDates');
// // // //       return ChatIntent.geoViolationDates;
// // // //     }
// // // //
// // // //     // Geo violations
// // // //     if (_any(q, ['geo', 'violation', 'geofence', 'geo-fence', 'location rule',
// // // //       'violate kiya', 'violations'])) {
// // // //       print('Intent: geoViolations');
// // // //       return ChatIntent.geoViolations;
// // // //     }
// // // //
// // // //     // Offline event dates (follow-up)
// // // //     if (_any(q, ['kis date offline', 'offline dates', 'which days offline'])) {
// // // //       print('Intent: offlineEventDates');
// // // //       return ChatIntent.offlineEventDates;
// // // //     }
// // // //
// // // //     // Offline events
// // // //     if (_any(q, ['offline', 'mode', 'no internet', 'offline events'])) {
// // // //       print('Intent: offlineEvents');
// // // //       return ChatIntent.offlineEvents;
// // // //     }
// // // //
// // // //     // Holidays
// // // //     if (_any(q, ['public holiday', 'govt holiday', 'sarkari chutti',
// // // //       'holidays this month', 'chutti', 'holiday dates', 'holiday'])) {
// // // //       print('Intent: holidays');
// // // //       return ChatIntent.holidays;
// // // //     }
// // // //
// // // //     // Leave dates (follow-up)
// // // //     if (_any(q, ['kis date chutti', 'leave dates', 'which days leave'])) {
// // // //       print('Intent: leaveDates');
// // // //       return ChatIntent.leaveDates;
// // // //     }
// // // //
// // // //     // Leave info
// // // //     if (_any(q, ['leave', 'چھٹی', 'chutti', 'leaves', 'leave days'])) {
// // // //       print('Intent: leaveInfo');
// // // //       return ChatIntent.leaveInfo;
// // // //     }
// // // //
// // // //     print('Intent: unknown');
// // // //     return ChatIntent.unknown;
// // // //   }
// // // //
// // // //   static bool _any(String text, List<String> keywords) {
// // // //     return keywords.any((k) => text.contains(k));
// // // //   }
// // // // }
// // //
// // //
// // // enum ChatIntent {
// // //   greeting,
// // //   attendanceSummary,
// // //   presentDays,
// // //   presentDates,
// // //   lateInfo,
// // //   lateDates,
// // //   onTimeInfo,
// // //   onTimeDates,
// // //   earlyExitInfo,
// // //   earlyExitDates,
// // //   workingHours,
// // //   dailyWorkingHours,
// // //   halfDays,
// // //   halfDayDates,
// // //   geoViolations,
// // //   geoViolationDates,
// // //   offlineEvents,
// // //   offlineEventDates,
// // //   holidays,
// // //   leaveInfo,
// // //   leaveDates,
// // //   dailyDetail,
// // //   unknown,
// // // }
// // //
// // // class IntentDetector {
// // //   // -------------------------------------------------------------------------
// // //   // Helper to check if ANY keyword matches (with partial matching)
// // //   // This is a STATIC method on the class, NOT inside detect()
// // //   // -------------------------------------------------------------------------
// // //   static bool _any(String text, List<String> keywords) {
// // //     for (final keyword in keywords) {
// // //       // Check exact match
// // //       if (text.contains(keyword)) return true;
// // //
// // //       // Check if keyword parts are in text (for multi-word keywords)
// // //       if (keyword.length > 3) {
// // //         final parts = keyword.split(' ');
// // //         for (final part in parts) {
// // //           if (part.length > 2 && text.contains(part)) return true;
// // //         }
// // //       }
// // //     }
// // //     return false;
// // //   }
// // //
// // //   static ChatIntent detect(String text) {
// // //     final q = text.toLowerCase().trim();
// // //     print('=== IntentDetector.detect called ===');
// // //     print('Text: $text');
// // //     print('Lowercase: $q');
// // //
// // //     // --- Greeting ---
// // //     if (_any(q, [
// // //       'hi', 'hello', 'hey', 'salam', 'assalam', 'asslam',
// // //       'سلام', 'ہیلو', 'kya haal', 'kia hal', 'helo'
// // //     ])) {
// // //       print('Intent: greeting');
// // //       return ChatIntent.greeting;
// // //     }
// // //
// // //     // --- Daily Detail ---
// // //     if (_any(q, [
// // //       'today', 'yesterday', 'aaj', 'kal', 'آج', 'کل',
// // //       'current day', 'today detail', 'aaj ki', 'aaj ka'
// // //     ])) {
// // //       print('Intent: dailyDetail');
// // //       return ChatIntent.dailyDetail;
// // //     }
// // //
// // //     // --- Summary / Attendance ---
// // //     if (_any(q, [
// // //       'summary', 'overall', 'performance', 'پرفارمنس', 'تفصیل',
// // //       'sara hisab', 'pura hisab', 'total detail', 'complete detail',
// // //       'attendance', 'haziri', 'حاضری', 'report', 'ripot',
// // //       'meri attendance', 'my attendance', 'attendance batao',
// // //       'haziri batao', 'حاضری بٹاؤ', 'hisab batao'
// // //     ])) {
// // //       print('Intent: attendanceSummary');
// // //       return ChatIntent.attendanceSummary;
// // //     }
// // //
// // //     // --- Present Dates (follow-up) ---
// // //     if (_any(q, [
// // //       'kis kis date', 'kis date', 'kin din', 'which dates',
// // //       'kon si dates', 'dates of present', 'kis kis din',
// // //       'kin kin dates', 'kis tariq', 'kis tariqon'
// // //     ])) {
// // //       if (_any(q, ['present', 'hazir', 'حاضر', 'hazri', 'aaye', 'gaye'])) {
// // //         print('Intent: presentDates');
// // //         return ChatIntent.presentDates;
// // //       }
// // //     }
// // //
// // //     // --- Present Days ---
// // //     if (_any(q, [
// // //       'present', 'حاضر', 'hazri', 'haziri', 'attendance count',
// // //       'kitne din hazir', 'present days', 'present din',
// // //       'kitne din aaye', 'kitni dafa aaye', 'kitne dafa',
// // //       'kitne din gya', 'kitne din gye'
// // //     ])) {
// // //       print('Intent: presentDays');
// // //       return ChatIntent.presentDays;
// // //     }
// // //
// // //     // --- Late Dates (follow-up) ---
// // //     if (_any(q, [
// // //       'kis date late', 'kis din late', 'late dates',
// // //       'which days late', 'kis dafa late', 'kis din der'
// // //     ])) {
// // //       print('Intent: lateDates');
// // //       return ChatIntent.lateDates;
// // //     }
// // //
// // //     // --- Late Info ---
// // //     if (_any(q, [
// // //       'late', 'دیر', 'der se', 'lait', 'late arrival',
// // //       'kitni der', 'kitni late', 'der aaye', 'late hue',
// // //       'dair', 'dayr', 'layt'
// // //     ])) {
// // //       print('Intent: lateInfo');
// // //       return ChatIntent.lateInfo;
// // //     }
// // //
// // //     // --- On Time Dates (follow-up) ---
// // //     if (_any(q, [
// // //       'kis date waqt par', 'on time dates', 'which days on time',
// // //       'kis din waqt par', 'time par kon'
// // //     ])) {
// // //       print('Intent: onTimeDates');
// // //       return ChatIntent.onTimeDates;
// // //     }
// // //
// // //     // --- On Time Info ---
// // //     if (_any(q, [
// // //       'on time', 'ontime', 'وقت پر', 'waqt par', 'waqt pe',
// // //       'time par', 'waqt per', 'sahi waqt', 'time se'
// // //     ])) {
// // //       print('Intent: onTimeInfo');
// // //       return ChatIntent.onTimeInfo;
// // //     }
// // //
// // //     // --- Early Exit Dates (follow-up) ---
// // //     if (_any(q, [
// // //       'kis date jaldi', 'early exit dates', 'which days early',
// // //       'kis din jaldi', 'jaldi gaye kon', 'jaldi gye'
// // //     ])) {
// // //       print('Intent: earlyExitDates');
// // //       return ChatIntent.earlyExitDates;
// // //     }
// // //
// // //     // --- Early Exit Info ---
// // //     if (_any(q, [
// // //       'early exit', 'early leave', 'jaldi gaya', 'jaldi chala',
// // //       'جلدی', 'jaldi nikla', 'jaldi gya', 'jaldi gye',
// // //       'pehle nikal', 'pehle chala'
// // //     ])) {
// // //       print('Intent: earlyExitInfo');
// // //       return ChatIntent.earlyExitInfo;
// // //     }
// // //
// // //     // --- Daily Working Hours ---
// // //     if (_any(q, [
// // //       'rozana', 'daily working', 'har din', 'per day',
// // //       'average hours', 'daily hours', 'rozana ghante',
// // //       'har roz ke ghante'
// // //     ])) {
// // //       print('Intent: dailyWorkingHours');
// // //       return ChatIntent.dailyWorkingHours;
// // //     }
// // //
// // //     // --- Working Hours ---
// // //     if (_any(q, [
// // //       'working hour', 'work hour', 'ghante', 'گھنٹے',
// // //       'kaam ke ghante', 'hours', 'total hours', 'kitne ghante',
// // //       'overtime', 'kitni hours', 'kitne ghante kaam',
// // //       'kam ke ghante', 'total time'
// // //     ])) {
// // //       print('Intent: workingHours');
// // //       return ChatIntent.workingHours;
// // //     }
// // //
// // //     // --- Half Day Dates (follow-up) ---
// // //     if (_any(q, [
// // //       'kis date half', 'half day dates', 'which days half',
// // //       'kis din half', 'adha din kis', 'aadha din kon'
// // //     ])) {
// // //       print('Intent: halfDayDates');
// // //       return ChatIntent.halfDayDates;
// // //     }
// // //
// // //     // --- Half Days ---
// // //     if (_any(q, [
// // //       'half day', 'half din', 'آدھا دن', 'aadha din',
// // //       'halfday', 'adha din', 'aadhe din'
// // //     ])) {
// // //       print('Intent: halfDays');
// // //       return ChatIntent.halfDays;
// // //     }
// // //
// // //     // --- Geo Violation Dates (follow-up) ---
// // //     if (_any(q, [
// // //       'kis date violation', 'violation dates', 'which days violation',
// // //       'kis din violation', 'geo violation kis', 'violate kya'
// // //     ])) {
// // //       print('Intent: geoViolationDates');
// // //       return ChatIntent.geoViolationDates;
// // //     }
// // //
// // //     // --- Geo Violations ---
// // //     if (_any(q, [
// // //       'geo', 'violation', 'geofence', 'geo-fence', 'location rule',
// // //       'violate kiya', 'violations', 'geo violation',
// // //       'geo violate', 'location violation', 'kya violation hai',
// // //       'koi violation', 'violation hai'
// // //     ])) {
// // //       print('Intent: geoViolations');
// // //       return ChatIntent.geoViolations;
// // //     }
// // //
// // //     // --- Offline Event Dates (follow-up) ---
// // //     if (_any(q, [
// // //       'kis date offline', 'offline dates', 'which days offline',
// // //       'kis din offline', 'offline mode kin'
// // //     ])) {
// // //       print('Intent: offlineEventDates');
// // //       return ChatIntent.offlineEventDates;
// // //     }
// // //
// // //     // --- Offline Events ---
// // //     if (_any(q, [
// // //       'offline', 'mode', 'no internet', 'offline events',
// // //       'offline mode', 'network nahi', 'internet nahi'
// // //     ])) {
// // //       print('Intent: offlineEvents');
// // //       return ChatIntent.offlineEvents;
// // //     }
// // //
// // //     // --- Holidays ---
// // //     if (_any(q, [
// // //       'public holiday', 'govt holiday', 'sarkari chutti',
// // //       'holidays this month', 'chutti', 'holiday dates',
// // //       'holiday', 'holidays', 'sarkari chuti', 'govt chutti'
// // //     ])) {
// // //       print('Intent: holidays');
// // //       return ChatIntent.holidays;
// // //     }
// // //
// // //     // --- Leave Dates (follow-up) ---
// // //     if (_any(q, [
// // //       'kis date chutti', 'leave dates', 'which days leave',
// // //       'kis din chutti', 'chutti kin din', 'leave kin'
// // //     ])) {
// // //       print('Intent: leaveDates');
// // //       return ChatIntent.leaveDates;
// // //     }
// // //
// // //     // --- Leave Info ---
// // //     if (_any(q, [
// // //       'leave', 'چھٹی', 'chutti', 'leaves', 'leave days',
// // //       'chuti', 'chutty', 'kitni chutti', 'chutti li',
// // //       'kitne din chutti', 'leave li'
// // //     ])) {
// // //       print('Intent: leaveInfo');
// // //       return ChatIntent.leaveInfo;
// // //     }
// // //
// // //     print('Intent: unknown');
// // //     return ChatIntent.unknown;
// // //   }
// // // }
// //
// //
// // enum ChatIntent {
// //   greeting,
// //   attendanceSummary,
// //   presentDays,
// //   presentDates,
// //   lateInfo,
// //   lateDates,
// //   onTimeInfo,
// //   onTimeDates,
// //   earlyExitInfo,
// //   earlyExitDates,
// //   workingHours,
// //   dailyWorkingHours,
// //   halfDays,
// //   halfDayDates,
// //   geoViolations,
// //   geoViolationDates,
// //   offlineEvents,
// //   offlineEventDates,
// //   holidays,
// //   leaveInfo,
// //   leaveDates,
// //   dailyDetail,
// //   unknown,
// // }
// //
// // class IntentDetector {
// //   static bool _any(String text, List<String> keywords) {
// //     for (final keyword in keywords) {
// //       if (text.contains(keyword)) return true;
// //       if (keyword.length > 3) {
// //         final parts = keyword.split(' ');
// //         for (final part in parts) {
// //           if (part.length > 2 && text.contains(part)) return true;
// //         }
// //       }
// //     }
// //     return false;
// //   }
// //
// //   static ChatIntent detect(String text) {
// //     final q = text.toLowerCase().trim();
// //     print('=== IntentDetector.detect called ===');
// //     print('Text: $text');
// //     print('Lowercase: $q');
// //
// //     // --- Greeting ---
// //     if (_any(q, [
// //       'hi', 'hello', 'hey', 'salam', 'assalam', 'asslam',
// //       'سلام', 'ہیلو', 'kya haal', 'kia hal', 'helo'
// //     ])) {
// //       print('Intent: greeting');
// //       return ChatIntent.greeting;
// //     }
// //
// //     // --- Daily Detail ---
// //     if (_any(q, [
// //       'today', 'yesterday', 'aaj', 'kal', 'آج', 'کل',
// //       'current day', 'today detail', 'aaj ki', 'aaj ka'
// //     ])) {
// //       print('Intent: dailyDetail');
// //       return ChatIntent.dailyDetail;
// //     }
// //
// //     // --- Summary / Attendance ---
// //     if (_any(q, [
// //       'summary', 'overall', 'performance', 'پرفارمنس', 'تفصیل',
// //       'sara hisab', 'pura hisab', 'total detail', 'complete detail',
// //       'attendance', 'haziri', 'حاضری', 'report', 'ripot',
// //       'meri attendance', 'my attendance', 'attendance batao',
// //       'haziri batao', 'حاضری بٹاؤ', 'hisab batao',
// //       'summary batao', 'خلاصہ'
// //     ])) {
// //       print('Intent: attendanceSummary');
// //       return ChatIntent.attendanceSummary;
// //     }
// //
// //     // --- Present Dates (follow-up) ---
// //     if (_any(q, [
// //       'kis kis date', 'kis date', 'kin din', 'which dates',
// //       'kon si dates', 'dates of present', 'kis kis din',
// //       'kin kin dates', 'kis tariq', 'kis tariqon'
// //     ])) {
// //       if (_any(q, ['present', 'hazir', 'حاضر', 'hazri', 'aaye', 'gaye'])) {
// //         print('Intent: presentDates');
// //         return ChatIntent.presentDates;
// //       }
// //     }
// //
// //     // --- Present Days ---
// //     if (_any(q, [
// //       'present', 'حاضر', 'hazri', 'haziri', 'attendance count',
// //       'kitne din hazir', 'present days', 'present din',
// //       'kitne din aaye', 'kitni dafa aaye', 'kitne dafa',
// //       'kitne din gya', 'kitne din gye', 'present ke'
// //     ])) {
// //       print('Intent: presentDays');
// //       return ChatIntent.presentDays;
// //     }
// //
// //     // --- Late Dates (follow-up) ---
// //     if (_any(q, [
// //       'kis date late', 'kis din late', 'late dates',
// //       'which days late', 'kis dafa late', 'kis din der'
// //     ])) {
// //       print('Intent: lateDates');
// //       return ChatIntent.lateDates;
// //     }
// //
// //     // --- Late Info ---
// //     if (_any(q, [
// //       'late', 'دیر', 'der se', 'lait', 'late arrival',
// //       'kitni der', 'kitni late', 'der aaye', 'late hue',
// //       'dair', 'dayr', 'layt', 'بوئی', 'der aye'
// //     ])) {
// //       print('Intent: lateInfo');
// //       return ChatIntent.lateInfo;
// //     }
// //
// //     // --- On Time Dates (follow-up) ---
// //     if (_any(q, [
// //       'kis date waqt par', 'on time dates', 'which days on time',
// //       'kis din waqt par', 'time par kon'
// //     ])) {
// //       print('Intent: onTimeDates');
// //       return ChatIntent.onTimeDates;
// //     }
// //
// //     // --- On Time Info ---
// //     if (_any(q, [
// //       'on time', 'ontime', 'وقت پر', 'waqt par', 'waqt pe',
// //       'time par', 'waqt per', 'sahi waqt', 'time se'
// //     ])) {
// //       print('Intent: onTimeInfo');
// //       return ChatIntent.onTimeInfo;
// //     }
// //
// //     // --- Early Exit Dates (follow-up) ---
// //     if (_any(q, [
// //       'kis date jaldi', 'early exit dates', 'which days early',
// //       'kis din jaldi', 'jaldi gaye kon', 'jaldi gye'
// //     ])) {
// //       print('Intent: earlyExitDates');
// //       return ChatIntent.earlyExitDates;
// //     }
// //
// //     // --- Early Exit Info ---
// //     if (_any(q, [
// //       'early exit', 'early leave', 'jaldi gaya', 'jaldi chala',
// //       'جلدی', 'jaldi nikla', 'jaldi gya', 'jaldi gye',
// //       'pehle nikal', 'pehle chala'
// //     ])) {
// //       print('Intent: earlyExitInfo');
// //       return ChatIntent.earlyExitInfo;
// //     }
// //
// //     // --- Daily Working Hours ---
// //     if (_any(q, [
// //       'rozana', 'daily working', 'har din', 'per day',
// //       'average hours', 'daily hours', 'rozana ghante',
// //       'har roz ke ghante'
// //     ])) {
// //       print('Intent: dailyWorkingHours');
// //       return ChatIntent.dailyWorkingHours;
// //     }
// //
// //     // --- Working Hours ---
// //     if (_any(q, [
// //       'working hour', 'work hour', 'ghante', 'گھنٹے',
// //       'kaam ke ghante', 'hours', 'total hours', 'kitne ghante',
// //       'overtime', 'kitni hours', 'kitne ghante kaam',
// //       'kam ke ghante', 'total time', 'کام کے گھنٹے'
// //     ])) {
// //       print('Intent: workingHours');
// //       return ChatIntent.workingHours;
// //     }
// //
// //     // --- Half Day Dates (follow-up) ---
// //     if (_any(q, [
// //       'kis date half', 'half day dates', 'which days half',
// //       'kis din half', 'adha din kis', 'aadha din kon'
// //     ])) {
// //       print('Intent: halfDayDates');
// //       return ChatIntent.halfDayDates;
// //     }
// //
// //     // --- Half Days ---
// //     if (_any(q, [
// //       'half day', 'half din', 'آدھا دن', 'aadha din',
// //       'halfday', 'adha din', 'aadhe din'
// //     ])) {
// //       print('Intent: halfDays');
// //       return ChatIntent.halfDays;
// //     }
// //
// //     // --- Geo Violation Dates (follow-up) ---
// //     if (_any(q, [
// //       'kis date violation', 'violation dates', 'which days violation',
// //       'kis din violation', 'geo violation kis', 'violate kya'
// //     ])) {
// //       print('Intent: geoViolationDates');
// //       return ChatIntent.geoViolationDates;
// //     }
// //
// //     // --- Geo Violations ---
// //     if (_any(q, [
// //       'geo', 'violation', 'geofence', 'geo-fence', 'location rule',
// //       'violate kiya', 'violations', 'geo violation',
// //       'geo violate', 'location violation', 'kya violation hai',
// //       'koi violation', 'violation hai'
// //     ])) {
// //       print('Intent: geoViolations');
// //       return ChatIntent.geoViolations;
// //     }
// //
// //     // --- Offline Event Dates (follow-up) ---
// //     if (_any(q, [
// //       'kis date offline', 'offline dates', 'which days offline',
// //       'kis din offline', 'offline mode kin'
// //     ])) {
// //       print('Intent: offlineEventDates');
// //       return ChatIntent.offlineEventDates;
// //     }
// //
// //     // --- Offline Events ---
// //     if (_any(q, [
// //       'offline', 'mode', 'no internet', 'offline events',
// //       'offline mode', 'network nahi', 'internet nahi'
// //     ])) {
// //       print('Intent: offlineEvents');
// //       return ChatIntent.offlineEvents;
// //     }
// //
// //     // --- Holidays ---
// //     if (_any(q, [
// //       'public holiday', 'govt holiday', 'sarkari chutti',
// //       'holidays this month', 'chutti', 'holiday dates',
// //       'holiday', 'holidays', 'sarkari chuti', 'govt chutti'
// //     ])) {
// //       print('Intent: holidays');
// //       return ChatIntent.holidays;
// //     }
// //
// //     // --- Leave Dates (follow-up) ---
// //     if (_any(q, [
// //       'kis date chutti', 'leave dates', 'which days leave',
// //       'kis din chutti', 'chutti kin din', 'leave kin'
// //     ])) {
// //       print('Intent: leaveDates');
// //       return ChatIntent.leaveDates;
// //     }
// //
// //     // --- Leave Info ---
// //     if (_any(q, [
// //       'leave', 'چھٹی', 'chutti', 'leaves', 'leave days',
// //       'chuti', 'chutty', 'kitni chutti', 'chutti li',
// //       'kitne din chutti', 'leave li', 'چھٹی لی'
// //     ])) {
// //       print('Intent: leaveInfo');
// //       return ChatIntent.leaveInfo;
// //     }
// //
// //     print('Intent: unknown');
// //     return ChatIntent.unknown;
// //   }
// // }
//
//
// enum ChatIntent {
//   greeting,
//   attendanceSummary,
//   presentDays,
//   presentDates,
//   lateInfo,
//   lateDates,
//   onTimeInfo,
//   onTimeDates,
//   earlyExitInfo,
//   earlyExitDates,
//   workingHours,
//   dailyWorkingHours,
//   halfDays,
//   halfDayDates,
//   geoViolations,
//   geoViolationDates,
//   offlineEvents,
//   offlineEventDates,
//   holidays,
//   leaveInfo,
//   leaveDates,
//   dailyDetail,
//   unknown,
// }
//
// class IntentDetector {
//   // -------------------------------------------------------------------------
//   // Helper to check if ANY keyword matches
//   // -------------------------------------------------------------------------
//   static bool _any(String text, List<String> keywords) {
//     // FIX: removed the old "split compound keyword into words and match
//     // any single word" fallback. That logic caused generic words like
//     // "late", "din", "violation", "working", "chutti" (which appear inside
//     // compound follow-up phrases such as "late dates", "kin din",
//     // "violation dates", "daily working") to falsely trigger the wrong
//     // (usually follow-up/"dates") intent, since those checks run before
//     // the correct info intent further down. Each section below already
//     // lists the relevant single words explicitly where needed, so a
//     // plain substring check on the full keyword is enough and accurate.
//     for (final keyword in keywords) {
//       if (text.contains(keyword)) return true;
//     }
//     return false;
//   }
//
//   static ChatIntent detect(String text) {
//     final q = text.toLowerCase().trim();
//     print('=== IntentDetector.detect called ===');
//     print('📝 Text: $text');
//     print('🔍 Lowercase: $q');
//
//     // ======================================================================
//     // 1. GREETING
//     // ======================================================================
//     if (_any(q, [
//       'hi', 'hello', 'hey', 'salam', 'assalam', 'asslam', 'salam walekum',
//       'سلام', 'ہیلو', 'kya haal', 'kia hal', 'helo', 'hye', 'hy',
//       'assalam o alaikum', 'السلام علیکم', 'adaab', 'آداب'
//     ])) {
//       print('🎯 Intent: greeting');
//       return ChatIntent.greeting;
//     }
//
//     // ======================================================================
//     // 2. DAILY DETAIL (Today / Yesterday)
//     // ======================================================================
//     if (_any(q, [
//       'today', 'yesterday', 'aaj', 'kal', 'آج', 'کل',
//       'current day', 'today detail', 'aaj ki', 'aaj ka',
//       'today attendance', 'aaj ki haziri', 'today report',
//       'today summary', 'aaj ka hisab', 'آج کی حاضری'
//     ])) {
//       print('🎯 Intent: dailyDetail');
//       return ChatIntent.dailyDetail;
//     }
//
//     // ======================================================================
//     // 3. ATTENDANCE SUMMARY (Full Report)
//     // ======================================================================
//     if (_any(q, [
//       'summary', 'overall', 'performance', 'پرفارمنس', 'تفصیل',
//       'sara hisab', 'pura hisab', 'total detail', 'complete detail',
//       'attendance', 'haziri', 'حاضری', 'report', 'ripot',
//       'meri attendance', 'my attendance', 'attendance batao',
//       'haziri batao', 'حاضری بٹاؤ', 'hisab batao',
//       'summary batao', 'خلاصہ', 'میری حاضری', 'حاضری دکھاؤ',
//       'ریپورٹ', 'attendance summary', 'full report', 'مکمل رپورٹ',
//       'sara account', 'pura account', 'total hisab', 'کامل حساب',
//       'monthly report', 'monthly summary', 'ماہانہ رپورٹ',
//       'my report', 'meri report', 'میری رپورٹ'
//     ])) {
//       print('🎯 Intent: attendanceSummary');
//       return ChatIntent.attendanceSummary;
//     }
//
//     // ======================================================================
//     // 4. PRESENT DATES (Follow-up - Which dates?)
//     // ======================================================================
//     if (_any(q, [
//       'kis kis date', 'kis date', 'kin din', 'which dates',
//       'kon si dates', 'dates of present', 'kis kis din',
//       'kin kin dates', 'kis tariq', 'kis tariqon',
//       'kis kis tariq', 'kon kon si dates', 'kin kin din',
//       'کون سی تاریخیں', 'کون کون سی تاریخ', 'کس کس تاریخ'
//     ])) {
//       if (_any(q, [
//         'present', 'hazir', 'حاضر', 'hazri', 'aaye', 'gaye',
//         'present tha', 'hazir tha', 'حاضر تھا', 'حاضر تھے',
//         'aaya', 'aya', 'gaya', 'gya', 'آیا', 'گیا'
//       ])) {
//         print('🎯 Intent: presentDates');
//         return ChatIntent.presentDates;
//       }
//     }
//
//     // ======================================================================
//     // 5. PRESENT DAYS (Count)
//     // ======================================================================
//     if (_any(q, [
//       'present', 'حاضر', 'hazri', 'haziri', 'attendance count',
//       'kitne din hazir', 'present days', 'present din',
//       'kitne din aaye', 'kitni dafa aaye', 'kitne dafa',
//       'kitne din gya', 'kitne din gye', 'present ke',
//       'kitne din present', 'how many days present',
//       'present count', 'haziri count', 'حاضری کی تعداد',
//       'کتنی دفعہ حاضر', 'کتنی مرتبہ حاضر', 'کتنی بار حاضر',
//       'حاضر ہونے کی تعداد', 'present days count',
//       'kitni bar aaye', 'kitni bar present', 'کتنی بار آئے'
//     ])) {
//       print('🎯 Intent: presentDays');
//       return ChatIntent.presentDays;
//     }
//
//     // ======================================================================
//     // 6. LATE DATES (Follow-up - Which dates late?)
//     // ======================================================================
//     if (_any(q, [
//       'kis date late', 'kis din late', 'late dates',
//       'which days late', 'kis dafa late', 'kis din der',
//       'kis tariq late', 'late kis din', 'کس تاریخ کو دیر',
//       'کون سی تاریخ کو دیر', 'کس کس تاریخ کو دیر',
//       'late hone ki dates', 'دیر ہونے کی تاریخیں'
//     ])) {
//       print('🎯 Intent: lateDates');
//       return ChatIntent.lateDates;
//     }
//
//     // ======================================================================
//     // 7. LATE INFO (Count and total time)
//     // ======================================================================
//     if (_any(q, [
//       'late', 'دیر', 'der se', 'lait', 'late arrival',
//       'kitni der', 'kitni late', 'der aaye', 'late hue',
//       'dair', 'dayr', 'layt', 'بوئی', 'der aye',
//       'دیر سے', 'دیر ہوئی', 'لیٹ', 'late hui',
//       'late kitni', 'der kitni', 'دیر کتنی',
//       'late aaye', 'late gaya', 'late gya', 'دیر سے آیا',
//       'total late', 'total der', 'کل دیر', 'late time',
//       'late hours', 'der hours', 'دیر کے گھنٹے',
//       'kitni dair', 'کتنی دیر', 'late arrival days',
//       'late count', 'late days count', 'دیر کی تعداد'
//     ])) {
//       print('🎯 Intent: lateInfo');
//       return ChatIntent.lateInfo;
//     }
//
//     // ======================================================================
//     // 8. ON-TIME DATES (Follow-up)
//     // ======================================================================
//     if (_any(q, [
//       'kis date waqt par', 'on time dates', 'which days on time',
//       'kis din waqt par', 'time par kon', 'waqt par kis din',
//       'on time kis din', 'وقت پر کس تاریخ', 'وقت پر کون سی تاریخ'
//     ])) {
//       print('🎯 Intent: onTimeDates');
//       return ChatIntent.onTimeDates;
//     }
//
//     // ======================================================================
//     // 9. ON-TIME INFO
//     // ======================================================================
//     if (_any(q, [
//       'on time', 'ontime', 'وقت پر', 'waqt par', 'waqt pe',
//       'time par', 'waqt per', 'sahi waqt', 'time se',
//       'وقت پر آیا', 'waqt par aaye', 'time pe',
//       'on time aaye', 'on time gaya', 'on time gya',
//       'on time days', 'waqt par days', 'وقت پر دن',
//       'kitne din waqt par', 'how many days on time'
//     ])) {
//       print('🎯 Intent: onTimeInfo');
//       return ChatIntent.onTimeInfo;
//     }
//
//     // ======================================================================
//     // 10. EARLY EXIT DATES (Follow-up)
//     // ======================================================================
//     if (_any(q, [
//       'kis date jaldi', 'early exit dates', 'which days early',
//       'kis din jaldi', 'jaldi gaye kon', 'jaldi gye',
//       'jaldi kis din', 'early exit kis din', 'جلدی کس تاریخ',
//       'کس تاریخ کو جلدی', 'کون سی تاریخ کو جلدی'
//     ])) {
//       print('🎯 Intent: earlyExitDates');
//       return ChatIntent.earlyExitDates;
//     }
//
//     // ======================================================================
//     // 11. EARLY EXIT INFO
//     // ======================================================================
//     if (_any(q, [
//       'early exit', 'early leave', 'jaldi gaya', 'jaldi chala',
//       'جلدی', 'jaldi nikla', 'jaldi gya', 'jaldi gye',
//       'pehle nikal', 'pehle chala', 'early exit days',
//       'jaldi nikal gaya', 'early gaye', 'جلدی گئے',
//       'early exit count', 'early leave days', 'جلدی رخصتی',
//       'kitne din jaldi', 'how many days early exit',
//       'jaldi rukhsat', 'جلدی رخصت', 'early out'
//     ])) {
//       print('🎯 Intent: earlyExitInfo');
//       return ChatIntent.earlyExitInfo;
//     }
//
//     // ======================================================================
//     // 12. DAILY WORKING HOURS (Breakdown per day)
//     // ======================================================================
//     if (_any(q, [
//       'rozana', 'daily working', 'har din', 'per day',
//       'average hours', 'daily hours', 'rozana ghante',
//       'har roz ke ghante', 'daily breakdown',
//       'har din ke ghante', 'per day hours',
//       'rozana kaam ke ghante', 'day by day hours',
//       'daily time', 'روزانہ', 'ہر روز کے گھنٹے',
//       'per day working hours', 'har din ka time'
//     ])) {
//       print('🎯 Intent: dailyWorkingHours');
//       return ChatIntent.dailyWorkingHours;
//     }
//
//     // ======================================================================
//     // 13. WORKING HOURS (Total)
//     // ======================================================================
//     if (_any(q, [
//       'working hour', 'work hour', 'ghante', 'گھنٹے',
//       'kaam ke ghante', 'hours', 'total hours', 'kitne ghante',
//       'overtime', 'kitni hours', 'kitne ghante kaam',
//       'kam ke ghante', 'total time', 'کام کے گھنٹے',
//       'working time', 'total working', 'کل گھنٹے',
//       'kitna time', 'کام کے اوقات', 'total ghante',
//       'all hours', 'sare ghante', 'کل وقت',
//       'kaam ka time', 'work time', 'کل کام کے گھنٹے'
//     ])) {
//       print('🎯 Intent: workingHours');
//       return ChatIntent.workingHours;
//     }
//
//     // ======================================================================
//     // 14. HALF DAY DATES (Follow-up)
//     // ======================================================================
//     if (_any(q, [
//       'kis date half', 'half day dates', 'which days half',
//       'kis din half', 'adha din kis', 'aadha din kon',
//       'half day kis din', 'کس تاریخ کو آدھا دن',
//       'کون سی تاریخ کو آدھا دن', 'half days dates'
//     ])) {
//       print('🎯 Intent: halfDayDates');
//       return ChatIntent.halfDayDates;
//     }
//
//     // ======================================================================
//     // 15. HALF DAYS (Count)
//     // ======================================================================
//     if (_any(q, [
//       'half day', 'half din', 'آدھا دن', 'aadha din',
//       'halfday', 'adha din', 'aadhe din', 'half days',
//       'kitne half day', 'kitne adha din', 'half day count',
//       'half days count', 'ادھے دن', 'آدھے دن',
//       'half day kitne', 'aadha din kitne'
//     ])) {
//       print('🎯 Intent: halfDays');
//       return ChatIntent.halfDays;
//     }
//
//     // ======================================================================
//     // 16. GEO VIOLATION DATES (Follow-up)
//     // ======================================================================
//     if (_any(q, [
//       'kis date violation', 'violation dates', 'which days violation',
//       'kis din violation', 'geo violation kis', 'violate kya',
//       'violation kis din', 'کس تاریخ کو خلاف ورزی',
//       'کون سی تاریخ کو خلاف ورزی', 'geo violation dates'
//     ])) {
//       print('🎯 Intent: geoViolationDates');
//       return ChatIntent.geoViolationDates;
//     }
//
//     // ======================================================================
//     // 17. GEO VIOLATIONS
//     // ======================================================================
//     if (_any(q, [
//       'geo', 'violation', 'geofence', 'geo-fence', 'location rule',
//       'violate kiya', 'violations', 'geo violation',
//       'geo violate', 'location violation', 'kya violation hai',
//       'koi violation', 'violation hai', 'geo violations',
//       'location violations', 'geofence violation',
//       'geo issue', 'location issue', 'جیو خلاف ورزی',
//       'خلاف ورزی', 'وائلشن', 'geo problem',
//       'violation count', 'خلاف ورزیاں', 'geofence break'
//     ])) {
//       print('🎯 Intent: geoViolations');
//       return ChatIntent.geoViolations;
//     }
//
//     // ======================================================================
//     // 18. OFFLINE EVENT DATES (Follow-up)
//     // ======================================================================
//     if (_any(q, [
//       'kis date offline', 'offline dates', 'which days offline',
//       'kis din offline', 'offline mode kin', 'offline kis din',
//       'کس تاریخ کو آف لائن', 'کون سی تاریخ کو آف لائن',
//       'offline events dates'
//     ])) {
//       print('🎯 Intent: offlineEventDates');
//       return ChatIntent.offlineEventDates;
//     }
//
//     // ======================================================================
//     // 19. OFFLINE EVENTS
//     // ======================================================================
//     if (_any(q, [
//       'offline', 'mode', 'no internet', 'offline events',
//       'offline mode', 'network nahi', 'internet nahi',
//       'offline count', 'offline kitne', 'آف لائن',
//       'offline data', 'offline records', 'internet connection',
//       'offline times', 'offline frequency', 'آف لائن واقعات',
//       'network issue', 'network problem'
//     ])) {
//       print('🎯 Intent: offlineEvents');
//       return ChatIntent.offlineEvents;
//     }
//
//     // ======================================================================
//     // 20. HOLIDAYS
//     // ======================================================================
//     if (_any(q, [
//       'public holiday', 'govt holiday', 'sarkari chutti',
//       'holidays this month', 'holiday dates',
//       'holiday', 'holidays', 'sarkari chuti', 'govt chutti',
//       'public holidays', 'government holiday', 'چھٹیاں',
//       'سرکاری چھٹی', 'holiday list',
//       'this month holidays', 'is mahine ki chuttiyan',
//       'total holidays', 'kitni chuttiyan', 'holiday count'
//     ])) {
//       print('🎯 Intent: holidays');
//       return ChatIntent.holidays;
//     }
//
//     // ======================================================================
//     // 21. LEAVE DATES (Follow-up)
//     // ======================================================================
//     if (_any(q, [
//       'kis date chutti', 'leave dates', 'which days leave',
//       'kis din chutti', 'chutti kin din', 'leave kin',
//       'kis tariq chutti', 'چھٹی کس تاریخ', 'کون سی تاریخ کو چھٹی',
//       'leave kis din', 'chutti dates', 'چھٹی کی تاریخیں'
//     ])) {
//       print('🎯 Intent: leaveDates');
//       return ChatIntent.leaveDates;
//     }
//
//     // ======================================================================
//     // 22. LEAVE INFO
//     // ======================================================================
//     if (_any(q, [
//       'leave', 'چھٹی', 'chutti', 'leaves', 'leave days',
//       'chuti', 'chutty', 'kitni chutti', 'chutti li',
//       'kitne din chutti', 'leave li', 'چھٹی لی',
//       'total leaves', 'leave count', 'کل چھٹیاں',
//       'kitni leave', 'how many leaves', 'chutti days',
//       'leave taken', 'chutti kitni', 'leave balance',
//       'meri chuttiyan', 'my leaves', 'میری چھٹیاں'
//     ])) {
//       print('🎯 Intent: leaveInfo');
//       return ChatIntent.leaveInfo;
//     }
//
//     // ======================================================================
//     // 23. UNKNOWN - Fallback
//     // ======================================================================
//     print('🎯 Intent: unknown');
//     return ChatIntent.unknown;
//   }
// }

enum ChatIntent {
  greeting,
  attendanceSummary,
  presentDays,
  presentDates,
  lateInfo,
  lateDates,
  onTimeInfo,
  onTimeDates,
  earlyExitInfo,
  earlyExitDates,
  workingHours,
  dailyWorkingHours,
  halfDays,
  halfDayDates,
  geoViolations,
  geoViolationDates,
  offlineEvents,
  offlineEventDates,
  holidays,
  leaveInfo,
  leaveDates,
  dailyDetail,
  unknown,
}

class IntentDetector {
  // -------------------------------------------------------------------------
  // Helper to check if ANY keyword matches
  // -------------------------------------------------------------------------
  static bool _any(String text, List<String> keywords) {
    // FIX: removed the old "split compound keyword into words and match
    // any single word" fallback. That logic caused generic words like
    // "late", "din", "violation", "working", "chutti" (which appear inside
    // compound follow-up phrases such as "late dates", "kin din",
    // "violation dates", "daily working") to falsely trigger the wrong
    // (usually follow-up/"dates") intent, since those checks run before
    // the correct info intent further down. Each section below already
    // lists the relevant single words explicitly where needed, so a
    // plain substring check on the full keyword is enough and accurate.
    for (final keyword in keywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }

  static ChatIntent detect(String text) {
    final q = text.toLowerCase().trim();
    print('=== IntentDetector.detect called ===');
    print('📝 Text: $text');
    print('🔍 Lowercase: $q');

    // ======================================================================
    // 1. GREETING
    // ======================================================================
    if (_any(q, [
      'hi', 'hello', 'hey', 'salam', 'assalam', 'asslam', 'salam walekum',
      'سلام', 'ہیلو', 'kya haal', 'kia hal', 'helo', 'hye', 'hy',
      'assalam o alaikum', 'السلام علیکم', 'adaab', 'آداب'
    ])) {
      print('🎯 Intent: greeting');
      return ChatIntent.greeting;
    }

    // ======================================================================
    // 2. DAILY DETAIL (Today / Yesterday)
    // ======================================================================
    if (_any(q, [
      'today', 'yesterday', 'aaj', 'kal', 'آج', 'کل',
      'current day', 'today detail', 'aaj ki', 'aaj ka',
      'today attendance', 'aaj ki haziri', 'today report',
      'today summary', 'aaj ka hisab', 'آج کی حاضری'
    ])) {
      print('🎯 Intent: dailyDetail');
      return ChatIntent.dailyDetail;
    }

    // ======================================================================
    // 3. ATTENDANCE SUMMARY (Full Report)
    // ======================================================================
    if (_any(q, [
      'summary', 'overall', 'performance', 'پرفارمنس', 'تفصیل',
      'sara hisab', 'pura hisab', 'total detail', 'complete detail',
      'attendance', 'haziri', 'حاضری', 'report', 'ripot',
      'meri attendance', 'my attendance', 'attendance batao',
      'haziri batao', 'حاضری بٹاؤ', 'hisab batao',
      'summary batao', 'خلاصہ', 'میری حاضری', 'حاضری دکھاؤ',
      'ریپورٹ', 'attendance summary', 'full report', 'مکمل رپورٹ',
      'sara account', 'pura account', 'total hisab', 'کامل حساب',
      'monthly report', 'monthly summary', 'ماہانہ رپورٹ',
      'my report', 'meri report', 'میری رپورٹ'
    ])) {
      print('🎯 Intent: attendanceSummary');
      return ChatIntent.attendanceSummary;
    }

    // ======================================================================
    // 4. PRESENT DATES (Follow-up - Which dates?)
    // ======================================================================
    if (_any(q, [
      'kis kis date', 'kis date', 'kin din', 'which dates',
      'kon si dates', 'dates of present', 'kis kis din',
      'kin kin dates', 'kis tariq', 'kis tariqon',
      'kis kis tariq', 'kon kon si dates', 'kin kin din',
      'کون سی تاریخیں', 'کون کون سی تاریخ', 'کس کس تاریخ'
    ])) {
      if (_any(q, [
        'present', 'hazir', 'حاضر', 'hazri', 'aaye', 'gaye',
        'present tha', 'hazir tha', 'حاضر تھا', 'حاضر تھے',
        'aaya', 'aya', 'gaya', 'gya', 'آیا', 'گیا'
      ])) {
        print('🎯 Intent: presentDates');
        return ChatIntent.presentDates;
      }
    }

    // ======================================================================
    // 5. PRESENT DAYS (Count)
    // ======================================================================
    if (_any(q, [
      'present', 'حاضر', 'hazri', 'haziri', 'attendance count',
      'kitne din hazir', 'present days', 'present din',
      'kitne din aaye', 'kitni dafa aaye', 'kitne dafa',
      'kitne din gya', 'kitne din gye', 'present ke',
      'kitne din present', 'how many days present',
      'present count', 'haziri count', 'حاضری کی تعداد',
      'کتنی دفعہ حاضر', 'کتنی مرتبہ حاضر', 'کتنی بار حاضر',
      'حاضر ہونے کی تعداد', 'present days count',
      'kitni bar aaye', 'kitni bar present', 'کتنی بار آئے'
    ])) {
      print('🎯 Intent: presentDays');
      return ChatIntent.presentDays;
    }

    // ======================================================================
    // 6. LATE DATES (Follow-up - Which dates late?)
    // ======================================================================
    if (_any(q, [
      'kis date late', 'kis din late', 'late dates',
      'which days late', 'kis dafa late', 'kis din der',
      'kis tariq late', 'late kis din', 'کس تاریخ کو دیر',
      'کون سی تاریخ کو دیر', 'کس کس تاریخ کو دیر',
      'late hone ki dates', 'دیر ہونے کی تاریخیں'
    ])) {
      print('🎯 Intent: lateDates');
      return ChatIntent.lateDates;
    }

    // ======================================================================
    // 7. LATE INFO (Count and total time)
    // ======================================================================
    if (_any(q, [
      'late', 'دیر', 'der se', 'lait', 'late arrival',
      'kitni der', 'kitni late', 'der aaye', 'late hue',
      'dair', 'dayr', 'layt', 'بوئی', 'der aye',
      'دیر سے', 'دیر ہوئی', 'لیٹ', 'late hui',
      'late kitni', 'der kitni', 'دیر کتنی',
      'late aaye', 'late gaya', 'late gya', 'دیر سے آیا',
      'total late', 'total der', 'کل دیر', 'late time',
      'late hours', 'der hours', 'دیر کے گھنٹے',
      'kitni dair', 'کتنی دیر', 'late arrival days',
      'late count', 'late days count', 'دیر کی تعداد'
    ])) {
      print('🎯 Intent: lateInfo');
      return ChatIntent.lateInfo;
    }

    // ======================================================================
    // 8. ON-TIME DATES (Follow-up)
    // ======================================================================
    if (_any(q, [
      'kis date waqt par', 'on time dates', 'which days on time',
      'kis din waqt par', 'time par kon', 'waqt par kis din',
      'on time kis din', 'وقت پر کس تاریخ', 'وقت پر کون سی تاریخ'
    ])) {
      print('🎯 Intent: onTimeDates');
      return ChatIntent.onTimeDates;
    }

    // ======================================================================
    // 9. ON-TIME INFO
    // ======================================================================
    if (_any(q, [
      'on time', 'ontime', 'وقت پر', 'waqt par', 'waqt pe',
      'time par', 'waqt per', 'sahi waqt', 'time se',
      'وقت پر آیا', 'waqt par aaye', 'time pe',
      'on time aaye', 'on time gaya', 'on time gya',
      'on time days', 'waqt par days', 'وقت پر دن',
      'kitne din waqt par', 'how many days on time'
    ])) {
      print('🎯 Intent: onTimeInfo');
      return ChatIntent.onTimeInfo;
    }

    // ======================================================================
    // 10. EARLY EXIT DATES (Follow-up)
    // ======================================================================
    if (_any(q, [
      'kis date jaldi', 'early exit dates', 'which days early',
      'kis din jaldi', 'jaldi gaye kon', 'jaldi gye',
      'jaldi kis din', 'early exit kis din', 'جلدی کس تاریخ',
      'کس تاریخ کو جلدی', 'کون سی تاریخ کو جلدی'
    ])) {
      print('🎯 Intent: earlyExitDates');
      return ChatIntent.earlyExitDates;
    }

    // ======================================================================
    // 11. EARLY EXIT INFO
    // ======================================================================
    if (_any(q, [
      'early exit', 'early leave', 'jaldi gaya', 'jaldi chala',
      'جلدی', 'jaldi nikla', 'jaldi gya', 'jaldi gye',
      'pehle nikal', 'pehle chala', 'early exit days',
      'jaldi nikal gaya', 'early gaye', 'جلدی گئے',
      'early exit count', 'early leave days', 'جلدی رخصتی',
      'kitne din jaldi', 'how many days early exit',
      'jaldi rukhsat', 'جلدی رخصت', 'early out'
    ])) {
      print('🎯 Intent: earlyExitInfo');
      return ChatIntent.earlyExitInfo;
    }

    // ======================================================================
    // 12. DAILY WORKING HOURS (Breakdown per day)
    // ======================================================================
    if (_any(q, [
      'rozana', 'daily working', 'har din', 'per day',
      'average hours', 'daily hours', 'rozana ghante',
      'har roz ke ghante', 'daily breakdown',
      'har din ke ghante', 'per day hours',
      'rozana kaam ke ghante', 'day by day hours',
      'daily time', 'روزانہ', 'ہر روز کے گھنٹے',
      'per day working hours', 'har din ka time'
    ])) {
      print('🎯 Intent: dailyWorkingHours');
      return ChatIntent.dailyWorkingHours;
    }

    // ======================================================================
    // 13. WORKING HOURS (Total)
    // ======================================================================
    if (_any(q, [
      'working hour', 'work hour', 'ghante', 'گھنٹے',
      'kaam ke ghante', 'hours', 'total hours', 'kitne ghante',
      'overtime', 'kitni hours', 'kitne ghante kaam',
      'kam ke ghante', 'total time', 'کام کے گھنٹے',
      'working time', 'total working', 'کل گھنٹے',
      'kitna time', 'کام کے اوقات', 'total ghante',
      'all hours', 'sare ghante', 'کل وقت',
      'kaam ka time', 'work time', 'کل کام کے گھنٹے'
    ])) {
      print('🎯 Intent: workingHours');
      return ChatIntent.workingHours;
    }

    // ======================================================================
    // 14. HALF DAY DATES (Follow-up)
    // ======================================================================
    if (_any(q, [
      'kis date half', 'half day dates', 'which days half',
      'kis din half', 'adha din kis', 'aadha din kon',
      'half day kis din', 'کس تاریخ کو آدھا دن',
      'کون سی تاریخ کو آدھا دن', 'half days dates'
    ])) {
      print('🎯 Intent: halfDayDates');
      return ChatIntent.halfDayDates;
    }

    // ======================================================================
    // 15. HALF DAYS (Count)
    // ======================================================================
    if (_any(q, [
      'half day', 'half din', 'آدھا دن', 'aadha din',
      'halfday', 'adha din', 'aadhe din', 'half days',
      'kitne half day', 'kitne adha din', 'half day count',
      'half days count', 'ادھے دن', 'آدھے دن',
      'half day kitne', 'aadha din kitne'
    ])) {
      print('🎯 Intent: halfDays');
      return ChatIntent.halfDays;
    }

    // ======================================================================
    // 16. GEO VIOLATION DATES (Follow-up)
    // ======================================================================
    if (_any(q, [
      'kis date violation', 'violation dates', 'which days violation',
      'kis din violation', 'geo violation kis', 'violate kya',
      'violation kis din', 'کس تاریخ کو خلاف ورزی',
      'کون سی تاریخ کو خلاف ورزی', 'geo violation dates'
    ])) {
      print('🎯 Intent: geoViolationDates');
      return ChatIntent.geoViolationDates;
    }

    // ======================================================================
    // 17. GEO VIOLATIONS
    // ======================================================================
    if (_any(q, [
      'geo', 'violation', 'geofence', 'geo-fence', 'location rule',
      'violate kiya', 'violations', 'geo violation',
      'geo violate', 'location violation', 'kya violation hai',
      'koi violation', 'violation hai', 'geo violations',
      'location violations', 'geofence violation',
      'geo issue', 'location issue', 'جیو خلاف ورزی',
      'خلاف ورزی', 'وائلشن', 'geo problem',
      'violation count', 'خلاف ورزیاں', 'geofence break'
    ])) {
      print('🎯 Intent: geoViolations');
      return ChatIntent.geoViolations;
    }

    // ======================================================================
    // 18. OFFLINE EVENT DATES (Follow-up)
    // ======================================================================
    if (_any(q, [
      'kis date offline', 'offline dates', 'which days offline',
      'kis din offline', 'offline mode kin', 'offline kis din',
      'کس تاریخ کو آف لائن', 'کون سی تاریخ کو آف لائن',
      'offline events dates'
    ])) {
      print('🎯 Intent: offlineEventDates');
      return ChatIntent.offlineEventDates;
    }

    // ======================================================================
    // 19. OFFLINE EVENTS
    // ======================================================================
    if (_any(q, [
      'offline', 'mode', 'no internet', 'offline events',
      'offline mode', 'network nahi', 'internet nahi',
      'offline count', 'offline kitne', 'آف لائن',
      'offline data', 'offline records', 'internet connection',
      'offline times', 'offline frequency', 'آف لائن واقعات',
      'network issue', 'network problem'
    ])) {
      print('🎯 Intent: offlineEvents');
      return ChatIntent.offlineEvents;
    }

    // ======================================================================
    // 20. HOLIDAYS
    // ======================================================================
    if (_any(q, [
      'public holiday', 'govt holiday', 'sarkari chutti',
      'holidays this month', 'holiday dates',
      'holiday', 'holidays', 'sarkari chuti', 'govt chutti',
      'public holidays', 'government holiday', 'چھٹیاں',
      'سرکاری چھٹی', 'holiday list',
      'this month holidays', 'is mahine ki chuttiyan',
      'total holidays', 'kitni chuttiyan', 'holiday count'
    ])) {
      print('🎯 Intent: holidays');
      return ChatIntent.holidays;
    }

    // ======================================================================
    // 21. LEAVE DATES (Follow-up)
    // ======================================================================
    if (_any(q, [
      'kis date chutti', 'leave dates', 'which days leave',
      'kis din chutti', 'chutti kin din', 'leave kin',
      'kis tariq chutti', 'چھٹی کس تاریخ', 'کون سی تاریخ کو چھٹی',
      'leave kis din', 'chutti dates', 'چھٹی کی تاریخیں'
    ])) {
      print('🎯 Intent: leaveDates');
      return ChatIntent.leaveDates;
    }

    // ======================================================================
    // 22. LEAVE INFO
    // ======================================================================
    if (_any(q, [
      'leave', 'چھٹی', 'chutti', 'leaves', 'leave days',
      'chuti', 'chutty', 'kitni chutti', 'chutti li',
      'kitne din chutti', 'leave li', 'چھٹی لی',
      'total leaves', 'leave count', 'کل چھٹیاں',
      'kitni leave', 'how many leaves', 'chutti days',
      'leave taken', 'chutti kitni', 'leave balance',
      'meri chuttiyan', 'my leaves', 'میری چھٹیاں'
    ])) {
      print('🎯 Intent: leaveInfo');
      return ChatIntent.leaveInfo;
    }

    // ======================================================================
    // 23. UNKNOWN - Fallback
    // ======================================================================
    print('🎯 Intent: unknown');
    return ChatIntent.unknown;
  }
}