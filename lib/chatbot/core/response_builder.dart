// //
// //
// // import 'intent_detector.dart';
// //
// // class ResponseBuilder {
// //   static Map<String, dynamic> lastResponseData = {};
// //
// //   // ---------------------------------------------------------------------------
// //   // Monthly analytics response - Bilingual (Urdu + English)
// //   // ---------------------------------------------------------------------------
// //
// //   static String buildMonthly(ChatIntent intent, Map<String, dynamic> response) {
// //     print('=== ResponseBuilder.buildMonthly called ===');
// //     print('Intent: $intent');
// //
// //     try {
// //       final items = response['items'];
// //
// //       if (items == null || items.isEmpty) {
// //         return _bilingual(
// //           urdu: 'اس مہینے کی حاضری کا ڈیٹا نہیں ملا۔ بعد میں دوبارہ کوشش کریں۔',
// //           english: 'No attendance data found for this month. Please try again later.',
// //         );
// //       }
// //
// //       final data = items[0];
// //       lastResponseData = data;
// //
// //       // ---------- helpers ----------
// //       String str(String key, {String def = '0'}) {
// //         try {
// //           final v = data[key];
// //           return v?.toString() ?? def;
// //         } catch (_) {
// //           return def;
// //         }
// //       }
// //
// //       int num(String key, {int def = 0}) {
// //         try {
// //           final v = data[key];
// //           if (v == null) return def;
// //           if (v is int) return v;
// //           if (v is double) return v.toInt();
// //           if (v is bool) return v ? 1 : 0;
// //           if (v is String) return int.tryParse(v) ?? def;
// //           return def;
// //         } catch (_) {
// //           return def;
// //         }
// //       }
// //       // -----------------------------
// //
// //       switch (intent) {
// //         case ChatIntent.presentDays:
// //           final days = num("present_days");
// //           if (days == 0) {
// //             return _bilingual(
// //               urdu: 'آپ اس مہینے کسی دن حاضر نہیں رہے۔',
// //               english: 'You were not present on any day this month.',
// //             );
// //           }
// //           return _bilingual(
// //             urdu: 'آپ اس مہینے $days دن حاضر رہے ہیں۔',
// //             english: 'You were present for $days days this month.',
// //           );
// //
// //         case ChatIntent.lateInfo:
// //           final days = num("late_arrival_days");
// //           final time = str("total_late_time", def: "0:00:00");
// //           if (days == 0) {
// //             return _bilingual(
// //               urdu: 'آپ اس مہینے کسی دن دیر سے نہیں آئے۔',
// //               english: 'You were not late on any day this month.',
// //             );
// //           }
// //           final formattedTime = _formatTime(time);
// //           return _bilingual(
// //             urdu: 'آپ $days دن دیر سے آئے۔\nکل دیری کا وقت: $formattedTime۔',
// //             english: 'You were late for $days days.\nTotal late time: $formattedTime.',
// //           );
// //
// //         case ChatIntent.onTimeInfo:
// //           final days = num("on_time_arrival_days");
// //           return _bilingual(
// //             urdu: 'آپ $days دن وقت پر آئے۔',
// //             english: 'You arrived on time for $days days.',
// //           );
// //
// //         case ChatIntent.earlyExitInfo:
// //           final days = num("early_exit_days");
// //           final time = str("total_early_exit_time", def: "0:00:00");
// //           if (days == 0) {
// //             return _bilingual(
// //               urdu: 'آپ اس مہینے کسی دن جلدی نہیں گئے۔',
// //               english: 'You did not leave early on any day this month.',
// //             );
// //           }
// //           final formattedTime = _formatTime(time);
// //           return _bilingual(
// //             urdu: 'آپ $days دن جلدی گئے۔\nکل جلدی رخصتی کا وقت: $formattedTime۔',
// //             english: 'You left early for $days days.\nTotal early exit time: $formattedTime.',
// //           );
// //
// //         case ChatIntent.workingHours:
// //           final hours = str("total_working_hours", def: "0:00:00");
// //           final days = num("present_days");
// //           if (days == 0 || hours == "0:00:00") {
// //             return _bilingual(
// //               urdu: 'اس مہینے کوئی کام کے گھنٹے نہیں ہیں۔',
// //               english: 'No working hours this month.',
// //             );
// //           }
// //           final formattedHours = _formatTime(hours);
// //           final avg = _calculateAverage(hours, days);
// //           return _bilingual(
// //             urdu: 'اس مہینے آپ کے کل کام کے گھنٹے: $formattedHours۔\nاوسط روزانہ: $avg۔',
// //             english: 'Total working hours this month: $formattedHours.\nAverage daily: $avg.',
// //           );
// //
// //         case ChatIntent.halfDays:
// //           final days = num("half_days");
// //           if (days == 0) {
// //             return _bilingual(
// //               urdu: 'اس مہینے کوئی ادھا دن نہیں ہے۔',
// //               english: 'No half days this month.',
// //             );
// //           }
// //           return _bilingual(
// //             urdu: 'اس مہینے آپ کے $days ادھے دن ہیں۔',
// //             english: 'You have $days half days this month.',
// //           );
// //
// //         case ChatIntent.geoViolations:
// //           final violations = num("total_geo_violations");
// //           if (violations == 0) {
// //             return _bilingual(
// //               urdu: 'اس مہینے کوئی جگہ کی خلاف ورزی نہیں ہے۔',
// //               english: 'No geo violations this month.',
// //             );
// //           }
// //           return _bilingual(
// //             urdu: 'آپ نے $violations بار جگہ کا اصول توڑا۔',
// //             english: 'You violated geo rules $violations times.',
// //           );
// //
// //         case ChatIntent.offlineEvents:
// //           final events = num("total_offline_events");
// //           if (events == 0) {
// //             return _bilingual(
// //               urdu: 'اس مہینے کوئی آف لائن واقعہ نہیں ہے۔',
// //               english: 'No offline events this month.',
// //             );
// //           }
// //           return _bilingual(
// //             urdu: 'آپ $events بار آف لائن موڈ میں ریکارڈ ہوئے۔',
// //             english: 'You were recorded in offline mode $events times.',
// //           );
// //
// //         case ChatIntent.holidays:
// //           final holidays = num("total_holidays");
// //           return _bilingual(
// //             urdu: 'اس مہینے کل $holidays چھٹیاں ہیں۔',
// //             english: 'There are $holidays holidays this month.',
// //           );
// //
// //         case ChatIntent.leaveInfo:
// //           final days = num("total_leave_days");
// //           if (days == 0) {
// //             return _bilingual(
// //               urdu: 'آپ نے اس مہینے کوئی چھٹی نہیں لی۔',
// //               english: 'You did not take any leave this month.',
// //             );
// //           }
// //           return _bilingual(
// //             urdu: 'آپ نے اس مہینے $days دن کی چھٹی لی۔',
// //             english: 'You took $days days of leave this month.',
// //           );
// //
// //         case ChatIntent.attendanceSummary:
// //           final present = num("present_days");
// //           final late = num("late_arrival_days");
// //           final onTime = num("on_time_arrival_days");
// //           final earlyExit = num("early_exit_days");
// //           final halfDays = num("half_days");
// //           final hours = str("total_working_hours", def: "0:00:00");
// //           final violations = num("total_geo_violations");
// //           final leaveDays = num("total_leave_days");
// //           final formattedHours = _formatTime(hours);
// //
// //           return _bilingual(
// //             urdu: 'اس مہینے کی حاضری کا خلاصہ:\n'
// //                 '• حاضر: $present دن\n'
// //                 '• دیر سے: $late دن\n'
// //                 '• وقت پر: $onTime دن\n'
// //                 '• جلدی گئے: $earlyExit دن\n'
// //                 '• ادھے دن: $halfDays\n'
// //                 '• کل کام کے گھنٹے: $formattedHours\n'
// //                 '• جگہ کی خلاف ورزیاں: $violations\n'
// //                 '• چھٹی: $leaveDays دن',
// //             english: 'Attendance Summary for this month:\n'
// //                 '• Present: $present days\n'
// //                 '• Late: $late days\n'
// //                 '• On Time: $onTime days\n'
// //                 '• Early Exit: $earlyExit days\n'
// //                 '• Half Days: $halfDays\n'
// //                 '• Total Working Hours: $formattedHours\n'
// //                 '• Geo Violations: $violations\n'
// //                 '• Leave: $leaveDays days',
// //           );
// //
// //         default:
// //           return _bilingual(
// //             urdu: 'معذرت، یہ ڈیٹا ابھی دستیاب نہیں ہے۔ بعد میں دوبارہ پوچھیں۔',
// //             english: 'Sorry, this data is not available yet. Please ask again later.',
// //           );
// //       }
// //     } catch (e, st) {
// //       print('ERROR in buildMonthly: $e\n$st');
// //       return _bilingual(
// //         urdu: 'ڈیٹا حاصل کرنے میں مسئلہ ہوا۔ بعد میں دوبارہ کوشش کریں۔',
// //         english: 'Error fetching data. Please try again later.',
// //       );
// //     }
// //   }
// //
// //   /// Helper to combine Urdu and English responses with a separator
// //   static String _bilingual({required String urdu, required String english}) {
// //     return '$urdu\n\n---\n\n$english';
// //   }
// //
// //   /// Format time from HH:MM:SS to readable format
// //   static String _formatTime(String timeStr) {
// //     try {
// //       if (timeStr == '0:00:00' || timeStr == '00:00:00') {
// //         return '0 hours';
// //       }
// //
// //       final parts = timeStr.split(':');
// //       if (parts.length < 2) return timeStr;
// //
// //       int hours = 0;
// //       int minutes = 0;
// //       int seconds = 0;
// //
// //       if (parts.length == 3) {
// //         hours = int.tryParse(parts[0]) ?? 0;
// //         minutes = int.tryParse(parts[1]) ?? 0;
// //         seconds = int.tryParse(parts[2]) ?? 0;
// //       } else if (parts.length == 2) {
// //         hours = int.tryParse(parts[0]) ?? 0;
// //         minutes = int.tryParse(parts[1]) ?? 0;
// //       }
// //
// //       List<String> result = [];
// //
// //       if (hours > 0) {
// //         result.add('$hours hours');
// //       }
// //       if (minutes > 0) {
// //         result.add('$minutes minutes');
// //       }
// //       if (seconds > 0) {
// //         result.add('$seconds seconds');
// //       }
// //
// //       if (result.isEmpty) return '0 hours';
// //
// //       if (result.length == 1) {
// //         return result.first;
// //       } else if (result.length == 2) {
// //         return '${result[0]}, ${result[1]}';
// //       } else {
// //         return '${result[0]}, ${result[1]}, ${result[2]}';
// //       }
// //     } catch (e) {
// //       print('Error formatting time: $e');
// //       return timeStr;
// //     }
// //   }
// //
// //   static String _calculateAverage(String totalHours, int days) {
// //     if (days == 0) return '0 hours';
// //     try {
// //       final parts = totalHours.split(':');
// //       if (parts.length >= 2) {
// //         final h = int.tryParse(parts[0]) ?? 0;
// //         final m = int.tryParse(parts[1]) ?? 0;
// //         final s = parts.length == 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
// //
// //         final totalSeconds = (h * 3600) + (m * 60) + s;
// //         final avgSeconds = totalSeconds ~/ days;
// //
// //         final avgHours = avgSeconds ~/ 3600;
// //         final avgMinutes = (avgSeconds % 3600) ~/ 60;
// //         final avgSecondsRem = avgSeconds % 60;
// //
// //         List<String> result = [];
// //         if (avgHours > 0) result.add('$avgHours hours');
// //         if (avgMinutes > 0) result.add('$avgMinutes minutes');
// //         if (avgSecondsRem > 0) result.add('$avgSecondsRem seconds');
// //
// //         if (result.isEmpty) return '0 hours';
// //         if (result.length == 1) return result.first;
// //         if (result.length == 2) return '${result[0]}, ${result[1]}';
// //         return '${result[0]}, ${result[1]}, ${result[2]}';
// //       }
// //     } catch (e) {
// //       return totalHours;
// //     }
// //     return totalHours;
// //   }
// //
// //   // ---------------------------------------------------------------------------
// //   // Daily attendance response
// //   // ---------------------------------------------------------------------------
// //
// //   static String buildDaily(Map<String, dynamic> response) {
// //     print('=== ResponseBuilder.buildDaily called ===');
// //     try {
// //       final items = response['items'];
// //
// //       if (items == null || items.isEmpty) {
// //         return _bilingual(
// //           urdu: 'آج کی حاضری کا ریکارڈ نہیں ملا۔',
// //           english: 'No attendance record found for today.',
// //         );
// //       }
// //
// //       final today = items.last;
// //
// //       final status = today['STATUS_TEXT']?.toString() ?? 'N/A';
// //       final firstIn = today['FIRST_IN']?.toString() ?? 'N/A';
// //       final lastOut = today['LAST_OUT']?.toString() ?? 'N/A';
// //       final totalStay = today['total_stay']?.toString() ?? 'N/A';
// //       final lateTime = today['late_time']?.toString() ?? 'N/A';
// //       final earlyExit = today['early_exit']?.toString() ?? 'N/A';
// //       final dayType = today['day_type']?.toString() ?? 'N/A';
// //       final violations = today['geo_violations'] ?? 0;
// //       final offline = today['offline_events'] ?? 0;
// //
// //       return _bilingual(
// //         urdu: 'آج کی حاضری کی تفصیل:\n'
// //             'حالت: $status\n'
// //             'پہلی آمد: $firstIn\n'
// //             'آخری روانگی: $lastOut\n'
// //             'کل وقت: $totalStay\n'
// //             'دیری: $lateTime\n'
// //             'جلدی رخصتی: $earlyExit\n'
// //             'دن کی قسم: $dayType\n'
// //             'جگہ کی خلاف ورزیاں: $violations\n'
// //             'آف لائن واقعات: $offline',
// //         english: 'Today\'s Attendance Detail:\n'
// //             'Status: $status\n'
// //             'First In: $firstIn\n'
// //             'Last Out: $lastOut\n'
// //             'Total Time: $totalStay\n'
// //             'Late: $lateTime\n'
// //             'Early Exit: $earlyExit\n'
// //             'Day Type: $dayType\n'
// //             'Geo Violations: $violations\n'
// //             'Offline Events: $offline',
// //       );
// //     } catch (e) {
// //       print('ERROR in buildDaily: $e');
// //       return _bilingual(
// //         urdu: 'آج کا ڈیٹا حاصل کرنے میں مسئلہ ہوا۔ بعد میں دوبارہ کوشش کریں۔',
// //         english: 'Error fetching today\'s data. Please try again later.',
// //       );
// //     }
// //   }
// //
// //   // ---------------------------------------------------------------------------
// //   // Follow-up date queries
// //   // ---------------------------------------------------------------------------
// //
// //   static String buildDailyFollowUp(ChatIntent intent, Map<String, dynamic> response) {
// //     try {
// //       final items = response['items'];
// //
// //       if (items == null || items.isEmpty) {
// //         return _bilingual(
// //           urdu: 'کوئی ڈیٹا نہیں ملا۔ بعد میں دوبارہ پوچھیں۔',
// //           english: 'No data found. Please ask again later.',
// //         );
// //       }
// //
// //       final data = items.length > 30 ? items.sublist(items.length - 30) : items;
// //
// //       List<String> matched = [];
// //
// //       for (var day in data) {
// //         try {
// //           final date = day['work_date']?.toString() ?? '';
// //           if (date.isEmpty) continue;
// //
// //           switch (intent) {
// //             case ChatIntent.presentDates:
// //               final status = day['status_text']?.toString().toLowerCase() ?? '';
// //               final onLeave = day['on_leave']?.toString().toLowerCase() == 'yes';
// //               final holiday = day['day_type']?.toString().toLowerCase() == 'holiday';
// //               if ((status.contains('on time') || status.contains('late') || status == 'half day') &&
// //                   !onLeave &&
// //                   !holiday) {
// //                 matched.add(date);
// //               }
// //               break;
// //
// //             case ChatIntent.lateDates:
// //               final lt = day['late_time']?.toString() ?? '';
// //               if (lt != '00:00:00' && lt != 'N/A' && lt.isNotEmpty) {
// //                 final formatted = _formatTime(lt);
// //                 matched.add('$date (Late: $formatted)');
// //               }
// //               break;
// //
// //             case ChatIntent.onTimeDates:
// //               final status = day['status_text']?.toString().toLowerCase() ?? '';
// //               if (status == 'on time') matched.add(date);
// //               break;
// //
// //             case ChatIntent.earlyExitDates:
// //               final ee = day['early_exit']?.toString() ?? '';
// //               if (ee != '00:00:00' && ee != 'N/A' && ee.isNotEmpty) {
// //                 final formatted = _formatTime(ee);
// //                 matched.add('$date (Early Exit: $formatted)');
// //               }
// //               break;
// //
// //             case ChatIntent.dailyWorkingHours:
// //               final stay = day['total_stay']?.toString() ?? 'N/A';
// //               final status = day['status_text']?.toString() ?? 'N/A';
// //               final formatted = stay != 'N/A' ? _formatTime(stay) : stay;
// //               matched.add('$date: $formatted ($status)');
// //               break;
// //
// //             case ChatIntent.halfDayDates:
// //               final status = day['status_text']?.toString().toLowerCase() ?? '';
// //               if (status == 'half day') {
// //                 final stay = day['total_stay']?.toString() ?? 'N/A';
// //                 final formatted = stay != 'N/A' ? _formatTime(stay) : stay;
// //                 matched.add('$date ($formatted)');
// //               }
// //               break;
// //
// //             case ChatIntent.geoViolationDates:
// //               final v = day['geo_violations'] ?? 0;
// //               if (v > 0) matched.add('$date ($v violations)');
// //               break;
// //
// //             case ChatIntent.offlineEventDates:
// //               final oe = day['offline_events'] ?? 0;
// //               if (oe > 0) matched.add('$date ($oe events)');
// //               break;
// //
// //             case ChatIntent.leaveDates:
// //               if (day['on_leave']?.toString().toLowerCase() == 'yes') {
// //                 matched.add(date);
// //               }
// //               break;
// //
// //             default:
// //               return _bilingual(
// //                 urdu: 'یہ ڈیٹا ابھی دستیاب نہیں ہے۔',
// //                 english: 'This data is not available yet.',
// //               );
// //           }
// //         } catch (e) {
// //           print('Error processing day: $e');
// //         }
// //       }
// //
// //       if (matched.isEmpty) {
// //         switch (intent) {
// //           case ChatIntent.presentDates:
// //             return _bilingual(
// //               urdu: 'آپ اس مہینے کسی دن حاضر نہیں رہے۔',
// //               english: 'You were not present on any day this month.',
// //             );
// //           case ChatIntent.lateDates:
// //             return _bilingual(
// //               urdu: 'آپ اس مہینے کسی دن دیر سے نہیں آئے۔',
// //               english: 'You were not late on any day this month.',
// //             );
// //           case ChatIntent.onTimeDates:
// //             return _bilingual(
// //               urdu: 'آپ اس مہینے کسی دن وقت پر نہیں آئے۔',
// //               english: 'You did not arrive on time any day this month.',
// //             );
// //           case ChatIntent.earlyExitDates:
// //             return _bilingual(
// //               urdu: 'آپ اس مہینے کسی دن جلدی نہیں گئے۔',
// //               english: 'You did not leave early any day this month.',
// //             );
// //           case ChatIntent.dailyWorkingHours:
// //             return _bilingual(
// //               urdu: 'کام کے گھنٹوں کا کوئی ڈیٹا نہیں ملا۔',
// //               english: 'No working hours data found.',
// //             );
// //           case ChatIntent.halfDayDates:
// //             return _bilingual(
// //               urdu: 'اس مہینے کوئی ادھا دن نہیں ہے۔',
// //               english: 'No half days this month.',
// //             );
// //           case ChatIntent.geoViolationDates:
// //             return _bilingual(
// //               urdu: 'اس مہینے کوئی جگہ کی خلاف ورزی نہیں ہے۔',
// //               english: 'No geo violations this month.',
// //             );
// //           case ChatIntent.offlineEventDates:
// //             return _bilingual(
// //               urdu: 'اس مہینے کوئی آف لائن واقعہ نہیں ہے۔',
// //               english: 'No offline events this month.',
// //             );
// //           case ChatIntent.leaveDates:
// //             return _bilingual(
// //               urdu: 'آپ نے اس مہینے کوئی چھٹی نہیں لی۔',
// //               english: 'You did not take any leave this month.',
// //             );
// //           default:
// //             return _bilingual(
// //               urdu: 'کوئی مطابق ریکارڈ نہیں ملا۔',
// //               english: 'No matching records found.',
// //             );
// //         }
// //       }
// //
// //       final display = matched.length > 15 ? matched.sublist(0, 15) : matched;
// //       final suffix = matched.length > 15 ? '\n... and ${matched.length - 15} more dates.' : '';
// //
// //       String title;
// //       switch (intent) {
// //         case ChatIntent.presentDates:
// //           title = 'You were present on these dates:';
// //           break;
// //         case ChatIntent.lateDates:
// //           title = 'You were late on these dates:';
// //           break;
// //         case ChatIntent.onTimeDates:
// //           title = 'You arrived on time on these dates:';
// //           break;
// //         case ChatIntent.earlyExitDates:
// //           title = 'You left early on these dates:';
// //           break;
// //         case ChatIntent.dailyWorkingHours:
// //           title = 'Daily working hours:';
// //           break;
// //         case ChatIntent.halfDayDates:
// //           title = 'Half days on these dates:';
// //           break;
// //         case ChatIntent.geoViolationDates:
// //           title = 'Geo violations on these dates:';
// //           break;
// //         case ChatIntent.offlineEventDates:
// //           title = 'Offline events on these dates:';
// //           break;
// //         case ChatIntent.leaveDates:
// //           title = 'Leave on these dates:';
// //           break;
// //         default:
// //           title = 'Dates:';
// //       }
// //
// //       return '$title\n${display.map((d) => '• $d').join('\n')}$suffix';
// //     } catch (e) {
// //       print('ERROR in buildDailyFollowUp: $e');
// //       return _bilingual(
// //         urdu: 'ڈیٹا حاصل کرنے میں مسئلہ ہوا۔ بعد میں دوبارہ کوشش کریں۔',
// //         english: 'Error fetching data. Please try again later.',
// //       );
// //     }
// //   }
// //
// //   // ---------------------------------------------------------------------------
// //   // Monthly + month header
// //   // ---------------------------------------------------------------------------
// //
// //   static String buildMonthlyWithMonth(ChatIntent intent, Map<String, dynamic> response, String month) {
// //     try {
// //       final formattedMonth = _formatMonthDisplay(month);
// //       final base = buildMonthly(intent, response);
// //       return '$formattedMonth کی حاضری:\n$base';
// //     } catch (e) {
// //       print('ERROR in buildMonthlyWithMonth: $e');
// //       return _bilingual(
// //         urdu: 'ڈیٹا حاصل کرنے میں مسئلہ ہوا۔ بعد میں دوبارہ کوشش کریں۔',
// //         english: 'Error fetching data. Please try again later.',
// //       );
// //     }
// //   }
// //
// //   static String _formatMonthDisplay(String month) {
// //     try {
// //       final parts = month.split('-');
// //       if (parts.length == 2) {
// //         final year = parts[0];
// //         final monthNum = int.tryParse(parts[1]) ?? 1;
// //         if (monthNum < 1 || monthNum > 12) return month;
// //
// //         const monthNames = [
// //           'جنوری', 'فروری', 'مارچ', 'اپریل',
// //           'مئی', 'جون', 'جولائی', 'اگست',
// //           'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر',
// //         ];
// //         return '${monthNames[monthNum - 1]} $year';
// //       }
// //       return month;
// //     } catch (e) {
// //       return month;
// //     }
// //   }
// //
// //   // ---------------------------------------------------------------------------
// //   // Utility methods
// //   // ---------------------------------------------------------------------------
// //
// //   static String cleanText(String text) {
// //     text = text.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
// //     text = text.replaceAll(RegExp(r'\*(.+?)\*'), r'$1');
// //     text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
// //     return text;
// //   }
// //
// //   static String prepareForSpeech(String text) {
// //     // Remove the English part if present (only speak Urdu)
// //     if (text.contains('---')) {
// //       text = text.split('---')[0].trim();
// //     }
// //     text = text.replaceAll('•', '');
// //     text = text.replaceAll('\n', '۔ ');
// //     text = cleanText(text);
// //     return text.trim();
// //   }
// //
// //   static String formatError(String error) =>
// //       'معذرت، کچھ مسئلہ پیش آیا: $error۔ بعد میں دوبارہ کوشش کریں۔';
// //
// //   static String formatSuccess(String message) => 'ٹھیک ہے، $message';
// //
// //   static bool hasMarkdown(String text) => text.contains('**') || text.contains('*');
// // }
//
//
//
// import 'intent_detector.dart';
//
// class ResponseBuilder {
//   static Map<String, dynamic> lastResponseData = {};
//
//   // ---------------------------------------------------------------------------
//   // Monthly analytics response - Bilingual (Urdu + English)
//   // ---------------------------------------------------------------------------
//
//   static String buildMonthly(ChatIntent intent, Map<String, dynamic> response) {
//     print('=== ResponseBuilder.buildMonthly called ===');
//     print('Intent: $intent');
//     print('Response keys: ${response.keys}');
//
//     try {
//       final items = response['items'];
//
//       // ✅ Check if data exists
//       if (items == null || items.isEmpty) {
//         return _bilingual(
//           urdu: '⚠️ اس مہینے کی حاضری کا ڈیٹا نہیں ملا۔ براہ کرم بعد میں دوبارہ کوشش کریں۔',
//           english: '⚠️ No attendance data found for this month. Please try again later.',
//         );
//       }
//
//       // ✅ Take first item from items array
//       final data = items[0];
//       print('Data keys: ${data.keys}');
//       lastResponseData = data;
//
//       // ---------- Safe value extractors ----------
//       String getString(String key, {String def = '0'}) {
//         try {
//           final v = data[key];
//           if (v == null) return def;
//           if (v is String) return v;
//           return v.toString();
//         } catch (_) {
//           return def;
//         }
//       }
//
//       int getInt(String key, {int def = 0}) {
//         try {
//           final v = data[key];
//           if (v == null) return def;
//           if (v is int) return v;
//           if (v is double) return v.toInt();
//           if (v is bool) return v ? 1 : 0;
//           if (v is String) return int.tryParse(v) ?? def;
//           return def;
//         } catch (_) {
//           return def;
//         }
//       }
//       // ------------------------------------------
//
//       switch (intent) {
//       // ============================================================
//         case ChatIntent.presentDays:
//           final days = getInt("present_days");
//           if (days == 0) {
//             return _bilingual(
//               urdu: '❌ آپ اس مہینے کسی دن حاضر نہیں رہے۔',
//               english: '❌ You were not present on any day this month.',
//             );
//           }
//           return _bilingual(
//             urdu: '✅ آپ اس مہینے **$days** دن حاضر رہے ہیں۔',
//             english: '✅ You were present for **$days** days this month.',
//           );
//
//       // ============================================================
//         case ChatIntent.presentDates:
//         // ✅ This is handled by buildDailyFollowUp
//         // But if called directly, show message
//           return _bilingual(
//             urdu: '📅 حاضر ہونے کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو حاضر تھے؟" پوچھیں۔',
//             english: '📅 Ask "Which dates was I present?" to see the dates.',
//           );
//
//       // ============================================================
//         case ChatIntent.lateInfo:
//           final days = getInt("late_arrival_days");
//           final time = getString("total_late_time", def: "0:00:00");
//           if (days == 0) {
//             return _bilingual(
//               urdu: '✅ آپ اس مہینے کسی دن دیر سے نہیں آئے۔',
//               english: '✅ You were not late on any day this month.',
//             );
//           }
//           final formattedTime = _formatTime(time);
//           return _bilingual(
//             urdu: '⏰ آپ **$days** دن دیر سے آئے۔\nکل دیری کا وقت: **$formattedTime**۔',
//             english: '⏰ You were late for **$days** days.\nTotal late time: **$formattedTime**.',
//           );
//
//       // ============================================================
//         case ChatIntent.lateDates:
//           return _bilingual(
//             urdu: '📅 دیر سے آنے کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو دیر ہوئی؟" پوچھیں۔',
//             english: '📅 Ask "Which dates was I late?" to see the dates.',
//           );
//
//       // ============================================================
//         case ChatIntent.onTimeInfo:
//           final days = getInt("on_time_arrival_days");
//           return _bilingual(
//             urdu: '✅ آپ **$days** دن وقت پر آئے۔',
//             english: '✅ You arrived on time for **$days** days.',
//           );
//
//       // ============================================================
//         case ChatIntent.onTimeDates:
//           return _bilingual(
//             urdu: '📅 وقت پر آنے کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو وقت پر آئے؟" پوچھیں۔',
//             english: '📅 Ask "Which dates was I on time?" to see the dates.',
//           );
//
//       // ============================================================
//         case ChatIntent.earlyExitInfo:
//           final days = getInt("early_exit_days");
//           final time = getString("total_early_exit_time", def: "0:00:00");
//           if (days == 0) {
//             return _bilingual(
//               urdu: '✅ آپ اس مہینے کسی دن جلدی نہیں گئے۔',
//               english: '✅ You did not leave early on any day this month.',
//             );
//           }
//           final formattedTime = _formatTime(time);
//           return _bilingual(
//             urdu: '🚪 آپ **$days** دن جلدی گئے۔\nکل جلدی رخصتی کا وقت: **$formattedTime**۔',
//             english: '🚪 You left early for **$days** days.\nTotal early exit time: **$formattedTime**.',
//           );
//
//       // ============================================================
//         case ChatIntent.earlyExitDates:
//           return _bilingual(
//             urdu: '📅 جلدی جانے کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو جلدی گئے؟" پوچھیں۔',
//             english: '📅 Ask "Which dates did I leave early?" to see the dates.',
//           );
//
//       // ============================================================
//         case ChatIntent.workingHours:
//           final hours = getString("total_working_hours", def: "0:00:00");
//           final days = getInt("present_days");
//           if (days == 0 || hours == "0:00:00") {
//             return _bilingual(
//               urdu: '⏱️ اس مہینے کوئی کام کے گھنٹے نہیں ہیں۔',
//               english: '⏱️ No working hours this month.',
//             );
//           }
//           final formattedHours = _formatTime(hours);
//           final avg = _calculateAverage(hours, days);
//           return _bilingual(
//             urdu: '⏱️ اس مہینے آپ کے کل کام کے گھنٹے: **$formattedHours**۔\nاوسط روزانہ: **$avg**۔',
//             english: '⏱️ Total working hours this month: **$formattedHours**.\nAverage daily: **$avg**.',
//           );
//
//       // ============================================================
//         case ChatIntent.dailyWorkingHours:
//           return _bilingual(
//             urdu: '📊 روزانہ کام کے گھنٹے دیکھنے کے لیے "روزانہ کتنے گھنٹے؟" پوچھیں۔',
//             english: '📊 Ask "Daily working hours?" to see breakdown.',
//           );
//
//       // ============================================================
//         case ChatIntent.halfDays:
//           final days = getInt("half_days");
//           if (days == 0) {
//             return _bilingual(
//               urdu: '❌ اس مہینے کوئی ادھا دن نہیں ہے۔',
//               english: '❌ No half days this month.',
//             );
//           }
//           return _bilingual(
//             urdu: '🌗 اس مہینے آپ کے **$days** ادھے دن ہیں۔',
//             english: '🌗 You have **$days** half days this month.',
//           );
//
//       // ============================================================
//         case ChatIntent.halfDayDates:
//           return _bilingual(
//             urdu: '📅 ادھے دن کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو ادھا دن تھا؟" پوچھیں۔',
//             english: '📅 Ask "Which dates were half days?" to see the dates.',
//           );
//
//       // ============================================================
//         case ChatIntent.geoViolations:
//           final violations = getInt("total_geo_violations");
//           if (violations == 0) {
//             return _bilingual(
//               urdu: '✅ اس مہینے کوئی جگہ کی خلاف ورزی نہیں ہے۔',
//               english: '✅ No geo violations this month.',
//             );
//           }
//           return _bilingual(
//             urdu: '📍 آپ نے **$violations** بار جگہ کا اصول توڑا۔',
//             english: '📍 You violated geo rules **$violations** times.',
//           );
//
//       // ============================================================
//         case ChatIntent.geoViolationDates:
//           return _bilingual(
//             urdu: '📅 خلاف ورزی کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو خلاف ورزی ہوئی؟" پوچھیں۔',
//             english: '📅 Ask "Which dates had violations?" to see the dates.',
//           );
//
//       // ============================================================
//         case ChatIntent.offlineEvents:
//           final events = getInt("total_offline_events");
//           if (events == 0) {
//             return _bilingual(
//               urdu: '✅ اس مہینے کوئی آف لائن واقعہ نہیں ہے۔',
//               english: '✅ No offline events this month.',
//             );
//           }
//           return _bilingual(
//             urdu: '📱 آپ **$events** بار آف لائن موڈ میں ریکارڈ ہوئے۔',
//             english: '📱 You were recorded in offline mode **$events** times.',
//           );
//
//       // ============================================================
//         case ChatIntent.offlineEventDates:
//           return _bilingual(
//             urdu: '📅 آف لائن واقعات کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو آف لائن تھا؟" پوچھیں۔',
//             english: '📅 Ask "Which dates were offline events?" to see the dates.',
//           );
//
//       // ============================================================
//         case ChatIntent.holidays:
//           final holidays = getInt("total_holidays");
//           return _bilingual(
//             urdu: '🏖️ اس مہینے کل **$holidays** چھٹیاں ہیں۔',
//             english: '🏖️ There are **$holidays** holidays this month.',
//           );
//
//       // ============================================================
//         case ChatIntent.leaveInfo:
//           final days = getInt("total_leave_days");
//           if (days == 0) {
//             return _bilingual(
//               urdu: '❌ آپ نے اس مہینے کوئی چھٹی نہیں لی۔',
//               english: '❌ You did not take any leave this month.',
//             );
//           }
//           return _bilingual(
//             urdu: '🏖️ آپ نے اس مہینے **$days** دن کی چھٹی لی۔',
//             english: '🏖️ You took **$days** days of leave this month.',
//           );
//
//       // ============================================================
//         case ChatIntent.leaveDates:
//           return _bilingual(
//             urdu: '📅 چھٹی کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو چھٹی تھی؟" پوچھیں۔',
//             english: '📅 Ask "Which dates was I on leave?" to see the dates.',
//           );
//
//       // ============================================================
//         case ChatIntent.attendanceSummary:
//           final present = getInt("present_days");
//           final late = getInt("late_arrival_days");
//           final onTime = getInt("on_time_arrival_days");
//           final earlyExit = getInt("early_exit_days");
//           final halfDays = getInt("half_days");
//           final hours = getString("total_working_hours", def: "0:00:00");
//           final violations = getInt("total_geo_violations");
//           final leaveDays = getInt("total_leave_days");
//           final formattedHours = _formatTime(hours);
//
//           return _bilingual(
//             urdu: '📊 **اس مہینے کی حاضری کا خلاصہ**\n\n'
//                 '✅ حاضر: **$present** دن\n'
//                 '⏰ دیر سے: **$late** دن\n'
//                 '🕐 وقت پر: **$onTime** دن\n'
//                 '🚪 جلدی گئے: **$earlyExit** دن\n'
//                 '🌗 ادھے دن: **$halfDays**\n'
//                 '⏱️ کل کام کے گھنٹے: **$formattedHours**\n'
//                 '📍 جگہ کی خلاف ورزیاں: **$violations**\n'
//                 '🏖️ چھٹی: **$leaveDays** دن',
//             english: '📊 **Attendance Summary for this month**\n\n'
//                 '✅ Present: **$present** days\n'
//                 '⏰ Late: **$late** days\n'
//                 '🕐 On Time: **$onTime** days\n'
//                 '🚪 Early Exit: **$earlyExit** days\n'
//                 '🌗 Half Days: **$halfDays**\n'
//                 '⏱️ Total Working Hours: **$formattedHours**\n'
//                 '📍 Geo Violations: **$violations**\n'
//                 '🏖️ Leave: **$leaveDays** days',
//           );
//
//       // ============================================================
//         default:
//           return _bilingual(
//             urdu: '⚠️ معذرت، یہ ڈیٹا ابھی دستیاب نہیں ہے۔ بعد میں دوبارہ پوچھیں۔',
//             english: '⚠️ Sorry, this data is not available yet. Please ask again later.',
//           );
//       }
//     } catch (e, st) {
//       print('❌ ERROR in buildMonthly: $e\n$st');
//       return _bilingual(
//         urdu: '⚠️ ڈیٹا حاصل کرنے میں مسئلہ ہوا۔ بعد میں دوبارہ کوشش کریں۔\nError: $e',
//         english: '⚠️ Error fetching data. Please try again later.\nError: $e',
//       );
//     }
//   }
//
//   /// Helper to combine Urdu and English responses with a separator
//   static String _bilingual({required String urdu, required String english}) {
//     return '$urdu\n\n---\n\n$english';
//   }
//
//   /// Format time from HH:MM:SS to readable format
//   static String _formatTime(String timeStr) {
//     try {
//       if (timeStr == '0:00:00' || timeStr == '00:00:00' || timeStr == 'N/A') {
//         return '0 hours';
//       }
//
//       final parts = timeStr.split(':');
//       if (parts.length < 2) return timeStr;
//
//       int hours = 0;
//       int minutes = 0;
//       int seconds = 0;
//
//       if (parts.length == 3) {
//         hours = int.tryParse(parts[0]) ?? 0;
//         minutes = int.tryParse(parts[1]) ?? 0;
//         seconds = int.tryParse(parts[2]) ?? 0;
//       } else if (parts.length == 2) {
//         hours = int.tryParse(parts[0]) ?? 0;
//         minutes = int.tryParse(parts[1]) ?? 0;
//       }
//
//       List<String> result = [];
//
//       if (hours > 0) {
//         result.add('$hours hours');
//       }
//       if (minutes > 0) {
//         result.add('$minutes minutes');
//       }
//       if (seconds > 0) {
//         result.add('$seconds seconds');
//       }
//
//       if (result.isEmpty) return '0 hours';
//
//       if (result.length == 1) {
//         return result.first;
//       } else if (result.length == 2) {
//         return '${result[0]}, ${result[1]}';
//       } else {
//         return '${result[0]}, ${result[1]}, ${result[2]}';
//       }
//     } catch (e) {
//       print('Error formatting time: $e');
//       return timeStr;
//     }
//   }
//
//   static String _calculateAverage(String totalHours, int days) {
//     if (days == 0) return '0 hours';
//     try {
//       final parts = totalHours.split(':');
//       if (parts.length >= 2) {
//         final h = int.tryParse(parts[0]) ?? 0;
//         final m = int.tryParse(parts[1]) ?? 0;
//         final s = parts.length == 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
//
//         final totalSeconds = (h * 3600) + (m * 60) + s;
//         final avgSeconds = totalSeconds ~/ days;
//
//         final avgHours = avgSeconds ~/ 3600;
//         final avgMinutes = (avgSeconds % 3600) ~/ 60;
//         final avgSecondsRem = avgSeconds % 60;
//
//         List<String> result = [];
//         if (avgHours > 0) result.add('$avgHours hours');
//         if (avgMinutes > 0) result.add('$avgMinutes minutes');
//         if (avgSecondsRem > 0) result.add('$avgSecondsRem seconds');
//
//         if (result.isEmpty) return '0 hours';
//         if (result.length == 1) return result.first;
//         if (result.length == 2) return '${result[0]}, ${result[1]}';
//         return '${result[0]}, ${result[1]}, ${result[2]}';
//       }
//     } catch (e) {
//       return totalHours;
//     }
//     return totalHours;
//   }
//
//   // ---------------------------------------------------------------------------
//   // Daily attendance response
//   // ---------------------------------------------------------------------------
//
//   static String buildDaily(Map<String, dynamic> response) {
//     print('=== ResponseBuilder.buildDaily called ===');
//     try {
//       final items = response['items'];
//
//       if (items == null || items.isEmpty) {
//         return _bilingual(
//           urdu: '📅 آج کی حاضری کا ریکارڈ نہیں ملا۔',
//           english: '📅 No attendance record found for today.',
//         );
//       }
//
//       final today = items.last;
//
//       // ✅ Use correct keys from API
//       final status = today['STATUS_TEXT']?.toString() ?? 'N/A';
//       final firstIn = today['FIRST_IN']?.toString() ?? 'N/A';
//       final lastOut = today['LAST_OUT']?.toString() ?? 'N/A';
//       final totalStay = today['total_stay']?.toString() ?? 'N/A';
//       final lateTime = today['late_time']?.toString() ?? 'N/A';
//       final earlyExit = today['early_exit']?.toString() ?? 'N/A';
//       final dayType = today['day_type']?.toString() ?? 'N/A';
//       final violations = today['geo_violations'] ?? 0;
//       final offline = today['offline_events'] ?? 0;
//
//       return _bilingual(
//         urdu: '📅 **آج کی حاضری کی تفصیل**\n\n'
//             '📌 حالت: **$status**\n'
//             '🚪 پہلی آمد: **$firstIn**\n'
//             '🚪 آخری روانگی: **$lastOut**\n'
//             '⏱️ کل وقت: **$totalStay**\n'
//             '⏰ دیری: **$lateTime**\n'
//             '🚪 جلدی رخصتی: **$earlyExit**\n'
//             '📅 دن کی قسم: **$dayType**\n'
//             '📍 جگہ کی خلاف ورزیاں: **$violations**\n'
//             '📱 آف لائن واقعات: **$offline**',
//         english: '📅 **Today\'s Attendance Detail**\n\n'
//             '📌 Status: **$status**\n'
//             '🚪 First In: **$firstIn**\n'
//             '🚪 Last Out: **$lastOut**\n'
//             '⏱️ Total Time: **$totalStay**\n'
//             '⏰ Late: **$lateTime**\n'
//             '🚪 Early Exit: **$earlyExit**\n'
//             '📅 Day Type: **$dayType**\n'
//             '📍 Geo Violations: **$violations**\n'
//             '📱 Offline Events: **$offline**',
//       );
//     } catch (e) {
//       print('ERROR in buildDaily: $e');
//       return _bilingual(
//         urdu: '⚠️ آج کا ڈیٹا حاصل کرنے میں مسئلہ ہوا۔ بعد میں دوبارہ کوشش کریں۔',
//         english: '⚠️ Error fetching today\'s data. Please try again later.',
//       );
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // Follow-up date queries - FIXED with correct data keys
//   // ---------------------------------------------------------------------------
//
//   static String buildDailyFollowUp(ChatIntent intent, Map<String, dynamic> response) {
//     print('=== ResponseBuilder.buildDailyFollowUp called ===');
//     print('Intent: $intent');
//
//     try {
//       final items = response['items'];
//
//       if (items == null || items.isEmpty) {
//         return _bilingual(
//           urdu: '⚠️ کوئی ڈیٹا نہیں ملا۔ بعد میں دوبارہ پوچھیں۔',
//           english: '⚠️ No data found. Please ask again later.',
//         );
//       }
//
//       // ✅ Take last 30 days
//       final data = items.length > 30 ? items.sublist(items.length - 30) : items;
//       print('Total days to process: ${data.length}');
//
//       List<String> matched = [];
//
//       for (var day in data) {
//         try {
//           final date = day['work_date']?.toString() ?? '';
//           if (date.isEmpty) continue;
//
//           // ✅ Extract values safely
//           final status = day['status_text']?.toString().toLowerCase() ?? '';
//           final onLeave = day['on_leave']?.toString().toLowerCase() == 'yes';
//           final holiday = day['day_type']?.toString().toLowerCase() == 'holiday';
//           final lateTime = day['late_time']?.toString() ?? '';
//           final earlyExitTime = day['early_exit']?.toString() ?? '';
//           final totalStay = day['total_stay']?.toString() ?? '';
//           final geoViolations = (day['geo_violations'] ?? 0) as int;
//           final offlineEvents = (day['offline_events'] ?? 0) as int;
//
//           switch (intent) {
//           // ==========================================================
//             case ChatIntent.presentDates:
//             // ✅ Present if: on time, late, or half day (AND not on leave, not holiday)
//               if ((status.contains('on time') ||
//                   status.contains('late') ||
//                   status == 'half day') &&
//                   !onLeave &&
//                   !holiday) {
//                 matched.add(date);
//               }
//               break;
//
//           // ==========================================================
//             case ChatIntent.lateDates:
//             // ✅ Late if late_time is not 00:00:00
//               if (lateTime != '00:00:00' && lateTime != 'N/A' && lateTime.isNotEmpty) {
//                 final formatted = _formatTime(lateTime);
//                 matched.add('$date (Late: $formatted)');
//               }
//               break;
//
//           // ==========================================================
//             case ChatIntent.onTimeDates:
//             // ✅ On time if status_text is exactly "on time"
//               if (status == 'on time') {
//                 matched.add(date);
//               }
//               break;
//
//           // ==========================================================
//             case ChatIntent.earlyExitDates:
//             // ✅ Early exit if early_exit is not 00:00:00
//               if (earlyExitTime != '00:00:00' && earlyExitTime != 'N/A' && earlyExitTime.isNotEmpty) {
//                 final formatted = _formatTime(earlyExitTime);
//                 matched.add('$date (Early Exit: $formatted)');
//               }
//               break;
//
//           // ==========================================================
//             case ChatIntent.dailyWorkingHours:
//             // ✅ Show daily hours
//               final stay = totalStay != 'N/A' ? _formatTime(totalStay) : totalStay;
//               matched.add('$date: $stay ($status)');
//               break;
//
//           // ==========================================================
//             case ChatIntent.halfDayDates:
//             // ✅ Half day if status_text is "half day"
//               if (status == 'half day') {
//                 final stay = totalStay != 'N/A' ? _formatTime(totalStay) : totalStay;
//                 matched.add('$date ($stay)');
//               }
//               break;
//
//           // ==========================================================
//             case ChatIntent.geoViolationDates:
//             // ✅ Geo violations if > 0
//               if (geoViolations > 0) {
//                 matched.add('$date ($geoViolations violations)');
//               }
//               break;
//
//           // ==========================================================
//             case ChatIntent.offlineEventDates:
//             // ✅ Offline events if > 0
//               if (offlineEvents > 0) {
//                 matched.add('$date ($offlineEvents events)');
//               }
//               break;
//
//           // ==========================================================
//             case ChatIntent.leaveDates:
//             // ✅ Leave if on_leave is "yes"
//               if (onLeave) {
//                 matched.add(date);
//               }
//               break;
//
//             default:
//             // Do nothing for other intents
//               break;
//           }
//         } catch (e) {
//           print('Error processing day: $e');
//         }
//       }
//
//       // ✅ If no matches found
//       if (matched.isEmpty) {
//         return _buildEmptyResponse(intent);
//       }
//
//       // ✅ Format response
//       final display = matched.length > 15 ? matched.sublist(0, 15) : matched;
//       final suffix = matched.length > 15
//           ? '\n... اور ${matched.length - 15} مزید تاریخیں ہیں۔'
//           : '';
//
//       String title = _getTitleForIntent(intent);
//
//       // ✅ Return bilingual response
//       return _bilingual(
//         urdu: '$title\n${display.map((d) => '• $d').join('\n')}$suffix',
//         english: '$title\n${display.map((d) => '• $d').join('\n')}$suffix',
//       );
//
//     } catch (e, st) {
//       print('❌ ERROR in buildDailyFollowUp: $e\n$st');
//       return _bilingual(
//         urdu: '⚠️ ڈیٹا حاصل کرنے میں مسئلہ ہوا۔ بعد میں دوبارہ کوشش کریں۔',
//         english: '⚠️ Error fetching data. Please try again later.',
//       );
//     }
//   }
//
//   // ✅ Helper to build empty response
//   static String _buildEmptyResponse(ChatIntent intent) {
//     switch (intent) {
//       case ChatIntent.presentDates:
//         return _bilingual(
//           urdu: '❌ آپ اس مہینے کسی دن حاضر نہیں رہے۔',
//           english: '❌ You were not present on any day this month.',
//         );
//       case ChatIntent.lateDates:
//         return _bilingual(
//           urdu: '✅ آپ اس مہینے کسی دن دیر سے نہیں آئے۔',
//           english: '✅ You were not late on any day this month.',
//         );
//       case ChatIntent.onTimeDates:
//         return _bilingual(
//           urdu: '❌ آپ اس مہینے کسی دن وقت پر نہیں آئے۔',
//           english: '❌ You did not arrive on time any day this month.',
//         );
//       case ChatIntent.earlyExitDates:
//         return _bilingual(
//           urdu: '✅ آپ اس مہینے کسی دن جلدی نہیں گئے۔',
//           english: '✅ You did not leave early any day this month.',
//         );
//       case ChatIntent.dailyWorkingHours:
//         return _bilingual(
//           urdu: '⚠️ کام کے گھنٹوں کا کوئی ڈیٹا نہیں ملا۔',
//           english: '⚠️ No working hours data found.',
//         );
//       case ChatIntent.halfDayDates:
//         return _bilingual(
//           urdu: '❌ اس مہینے کوئی ادھا دن نہیں ہے۔',
//           english: '❌ No half days this month.',
//         );
//       case ChatIntent.geoViolationDates:
//         return _bilingual(
//           urdu: '✅ اس مہینے کوئی جگہ کی خلاف ورزی نہیں ہے۔',
//           english: '✅ No geo violations this month.',
//         );
//       case ChatIntent.offlineEventDates:
//         return _bilingual(
//           urdu: '✅ اس مہینے کوئی آف لائن واقعہ نہیں ہے۔',
//           english: '✅ No offline events this month.',
//         );
//       case ChatIntent.leaveDates:
//         return _bilingual(
//           urdu: '❌ آپ نے اس مہینے کوئی چھٹی نہیں لی۔',
//           english: '❌ You did not take any leave this month.',
//         );
//       default:
//         return _bilingual(
//           urdu: '⚠️ کوئی مطابق ریکارڈ نہیں ملا۔',
//           english: '⚠️ No matching records found.',
//         );
//     }
//   }
//
//   // ✅ Helper to get title for intent
//   static String _getTitleForIntent(ChatIntent intent) {
//     switch (intent) {
//       case ChatIntent.presentDates:
//         return '📅 **آپ ان تاریخوں کو حاضر رہے:**';
//       case ChatIntent.lateDates:
//         return '⏰ **آپ ان تاریخوں کو دیر سے آئے:**';
//       case ChatIntent.onTimeDates:
//         return '🕐 **آپ ان تاریخوں کو وقت پر آئے:**';
//       case ChatIntent.earlyExitDates:
//         return '🚪 **آپ ان تاریخوں کو جلدی گئے:**';
//       case ChatIntent.dailyWorkingHours:
//         return '⏱️ **روزانہ کام کے گھنٹے:**';
//       case ChatIntent.halfDayDates:
//         return '🌗 **ان تاریخوں پر ادھے دن:**';
//       case ChatIntent.geoViolationDates:
//         return '📍 **ان تاریخوں کو جگہ کی خلاف ورزیاں:**';
//       case ChatIntent.offlineEventDates:
//         return '📱 **ان تاریخوں کو آف لائن واقعات:**';
//       case ChatIntent.leaveDates:
//         return '🏖️ **آپ نے ان تاریخوں پر چھٹی لی:**';
//       default:
//         return '📅 **تاریخیں:**';
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // Monthly + month header
//   // ---------------------------------------------------------------------------
//
//   static String buildMonthlyWithMonth(ChatIntent intent, Map<String, dynamic> response, String month) {
//     try {
//       final formattedMonth = _formatMonthDisplay(month);
//       final base = buildMonthly(intent, response);
//       return '📅 **$formattedMonth**\n\n$base';
//     } catch (e) {
//       print('ERROR in buildMonthlyWithMonth: $e');
//       return _bilingual(
//         urdu: '⚠️ ڈیٹا حاصل کرنے میں مسئلہ ہوا۔ بعد میں دوبارہ کوشش کریں۔',
//         english: '⚠️ Error fetching data. Please try again later.',
//       );
//     }
//   }
//
//   static String _formatMonthDisplay(String month) {
//     try {
//       final parts = month.split('-');
//       if (parts.length == 2) {
//         final year = parts[0];
//         final monthNum = int.tryParse(parts[1]) ?? 1;
//         if (monthNum < 1 || monthNum > 12) return month;
//
//         const monthNames = [
//           'جنوری', 'فروری', 'مارچ', 'اپریل',
//           'مئی', 'جون', 'جولائی', 'اگست',
//           'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر',
//         ];
//         return '${monthNames[monthNum - 1]} $year';
//       }
//       return month;
//     } catch (e) {
//       return month;
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // Utility methods
//   // ---------------------------------------------------------------------------
//
//   static String cleanText(String text) {
//     text = text.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
//     text = text.replaceAll(RegExp(r'\*(.+?)\*'), r'$1');
//     text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
//     return text;
//   }
//
//   static String prepareForSpeech(String text) {
//     if (text.contains('---')) {
//       text = text.split('---')[0].trim();
//     }
//     text = text.replaceAll('•', '');
//     text = text.replaceAll('\n', '۔ ');
//     text = cleanText(text);
//     return text.trim();
//   }
//
//   static String formatError(String error) =>
//       '⚠️ معذرت، کچھ مسئلہ پیش آیا: $error۔ بعد میں دوبارہ کوشش کریں۔';
//
//   static String formatSuccess(String message) => '✅ ٹھیک ہے، $message';
//
//   static bool hasMarkdown(String text) => text.contains('**') || text.contains('*');
// }


import 'intent_detector.dart';

class ResponseBuilder {
  static Map<String, dynamic> lastResponseData = {};

  // ---------------------------------------------------------------------------
  // Monthly analytics response - Bilingual (Urdu + English)
  // ---------------------------------------------------------------------------

  static String buildMonthly(ChatIntent intent, Map<String, dynamic> response) {
    print('=== ResponseBuilder.buildMonthly called ===');
    print('Intent: $intent');
    print('Response keys: ${response.keys}');

    try {
      final items = response['items'];

      // ✅ Check if data exists
      if (items == null || items.isEmpty) {
        return _bilingual(
          urdu: '⚠️ اس مہینے کی حاضری کا ڈیٹا نہیں ملا۔ براہ کرم بعد میں دوبارہ کوشش کریں۔',
          english: '⚠️ No attendance data found for this month. Please try again later.',
        );
      }

      // ✅ Take first item from items array
      final data = items[0];
      print('Data keys: ${data.keys}');
      lastResponseData = data;

      // ---------- Safe value extractors ----------
      String getString(String key, {String def = '0'}) {
        try {
          final v = data[key];
          if (v == null) return def;
          if (v is String) return v;
          return v.toString();
        } catch (_) {
          return def;
        }
      }

      int getInt(String key, {int def = 0}) {
        try {
          final v = data[key];
          if (v == null) return def;
          if (v is int) return v;
          if (v is double) return v.toInt();
          if (v is bool) return v ? 1 : 0;
          if (v is String) return int.tryParse(v) ?? def;
          return def;
        } catch (_) {
          return def;
        }
      }
      // ------------------------------------------

      switch (intent) {
      // ============================================================
        case ChatIntent.presentDays:
          final days = getInt("present_days");
          if (days == 0) {
            return _bilingual(
              urdu: '❌ آپ اس مہینے کسی دن حاضر نہیں رہے۔',
              english: '❌ You were not present on any day this month.',
            );
          }
          return _bilingual(
            urdu: '✅ آپ اس مہینے **$days** دن حاضر رہے ہیں۔',
            english: '✅ You were present for **$days** days this month.',
          );

      // ============================================================
        case ChatIntent.presentDates:
        // ✅ This is handled by buildDailyFollowUp
        // But if called directly, show message
          return _bilingual(
            urdu: '📅 حاضر ہونے کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو حاضر تھے؟" پوچھیں۔',
            english: '📅 Ask "Which dates was I present?" to see the dates.',
          );

      // ============================================================
        case ChatIntent.lateInfo:
          final days = getInt("late_arrival_days");
          final time = getString("total_late_time", def: "0:00:00");
          if (days == 0) {
            return _bilingual(
              urdu: '✅ آپ اس مہینے کسی دن دیر سے نہیں آئے۔',
              english: '✅ You were not late on any day this month.',
            );
          }
          final formattedTime = _formatTime(time);
          final formattedTimeUrdu = _formatTimeUrdu(time);
          return _bilingual(
            urdu: '⏰ آپ **$days** دن دیر سے آئے۔\nکل دیری کا وقت: **$formattedTimeUrdu**۔',
            english: '⏰ You were late for **$days** days.\nTotal late time: **$formattedTime**.',
          );

      // ============================================================
        case ChatIntent.lateDates:
          return _bilingual(
            urdu: '📅 دیر سے آنے کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو دیر ہوئی؟" پوچھیں۔',
            english: '📅 Ask "Which dates was I late?" to see the dates.',
          );

      // ============================================================
        case ChatIntent.onTimeInfo:
          final days = getInt("on_time_arrival_days");
          return _bilingual(
            urdu: '✅ آپ **$days** دن وقت پر آئے۔',
            english: '✅ You arrived on time for **$days** days.',
          );

      // ============================================================
        case ChatIntent.onTimeDates:
          return _bilingual(
            urdu: '📅 وقت پر آنے کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو وقت پر آئے؟" پوچھیں۔',
            english: '📅 Ask "Which dates was I on time?" to see the dates.',
          );

      // ============================================================
        case ChatIntent.earlyExitInfo:
          final days = getInt("early_exit_days");
          final time = getString("total_early_exit_time", def: "0:00:00");
          if (days == 0) {
            return _bilingual(
              urdu: '✅ آپ اس مہینے کسی دن جلدی نہیں گئے۔',
              english: '✅ You did not leave early on any day this month.',
            );
          }
          final formattedTime = _formatTime(time);
          final formattedTimeUrdu = _formatTimeUrdu(time);
          return _bilingual(
            urdu: '🚪 آپ **$days** دن جلدی گئے۔\nکل جلدی رخصتی کا وقت: **$formattedTimeUrdu**۔',
            english: '🚪 You left early for **$days** days.\nTotal early exit time: **$formattedTime**.',
          );

      // ============================================================
        case ChatIntent.earlyExitDates:
          return _bilingual(
            urdu: '📅 جلدی جانے کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو جلدی گئے؟" پوچھیں۔',
            english: '📅 Ask "Which dates did I leave early?" to see the dates.',
          );

      // ============================================================
        case ChatIntent.workingHours:
          final hours = getString("total_working_hours", def: "0:00:00");
          final days = getInt("present_days");
          if (days == 0 || hours == "0:00:00") {
            return _bilingual(
              urdu: '⏱️ اس مہینے کوئی کام کے گھنٹے نہیں ہیں۔',
              english: '⏱️ No working hours this month.',
            );
          }
          final formattedHours = _formatTime(hours);
          final formattedHoursUrdu = _formatTimeUrdu(hours);
          final avg = _calculateAverage(hours, days);
          final avgUrdu = _calculateAverageUrdu(hours, days);
          return _bilingual(
            urdu: '⏱️ اس مہینے آپ کے کل کام کے گھنٹے: **$formattedHoursUrdu**۔\nاوسط روزانہ: **$avgUrdu**۔',
            english: '⏱️ Total working hours this month: **$formattedHours**.\nAverage daily: **$avg**.',
          );

      // ============================================================
        case ChatIntent.dailyWorkingHours:
          return _bilingual(
            urdu: '📊 روزانہ کام کے گھنٹے دیکھنے کے لیے "روزانہ کتنے گھنٹے؟" پوچھیں۔',
            english: '📊 Ask "Daily working hours?" to see breakdown.',
          );

      // ============================================================
        case ChatIntent.halfDays:
          final days = getInt("half_days");
          if (days == 0) {
            return _bilingual(
              urdu: '❌ اس مہینے کوئی ادھا دن نہیں ہے۔',
              english: '❌ No half days this month.',
            );
          }
          return _bilingual(
            urdu: '🌗 اس مہینے آپ کے **$days** ادھے دن ہیں۔',
            english: '🌗 You have **$days** half days this month.',
          );

      // ============================================================
        case ChatIntent.halfDayDates:
          return _bilingual(
            urdu: '📅 ادھے دن کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو ادھا دن تھا؟" پوچھیں۔',
            english: '📅 Ask "Which dates were half days?" to see the dates.',
          );

      // ============================================================
        case ChatIntent.geoViolations:
          final violations = getInt("total_geo_violations");
          if (violations == 0) {
            return _bilingual(
              urdu: '✅ اس مہینے کوئی جگہ کی خلاف ورزی نہیں ہے۔',
              english: '✅ No geo violations this month.',
            );
          }
          return _bilingual(
            urdu: '📍 آپ نے **$violations** بار جگہ کا اصول توڑا۔',
            english: '📍 You violated geo rules **$violations** times.',
          );

      // ============================================================
        case ChatIntent.geoViolationDates:
          return _bilingual(
            urdu: '📅 خلاف ورزی کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو خلاف ورزی ہوئی؟" پوچھیں۔',
            english: '📅 Ask "Which dates had violations?" to see the dates.',
          );

      // ============================================================
        case ChatIntent.offlineEvents:
          final events = getInt("total_offline_events");
          if (events == 0) {
            return _bilingual(
              urdu: '✅ اس مہینے کوئی آف لائن واقعہ نہیں ہے۔',
              english: '✅ No offline events this month.',
            );
          }
          return _bilingual(
            urdu: '📱 آپ **$events** بار آف لائن موڈ میں ریکارڈ ہوئے۔',
            english: '📱 You were recorded in offline mode **$events** times.',
          );

      // ============================================================
        case ChatIntent.offlineEventDates:
          return _bilingual(
            urdu: '📅 آف لائن واقعات کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو آف لائن تھا؟" پوچھیں۔',
            english: '📅 Ask "Which dates were offline events?" to see the dates.',
          );

      // ============================================================
        case ChatIntent.holidays:
          final holidays = getInt("total_holidays");
          return _bilingual(
            urdu: '🏖️ اس مہینے کل **$holidays** چھٹیاں ہیں۔',
            english: '🏖️ There are **$holidays** holidays this month.',
          );

      // ============================================================
        case ChatIntent.leaveInfo:
          final days = getInt("total_leave_days");
          if (days == 0) {
            return _bilingual(
              urdu: '❌ آپ نے اس مہینے کوئی چھٹی نہیں لی۔',
              english: '❌ You did not take any leave this month.',
            );
          }
          return _bilingual(
            urdu: '🏖️ آپ نے اس مہینے **$days** دن کی چھٹی لی۔',
            english: '🏖️ You took **$days** days of leave this month.',
          );

      // ============================================================
        case ChatIntent.leaveDates:
          return _bilingual(
            urdu: '📅 چھٹی کی تاریخیں دیکھنے کے لیے "کون سی تاریخ کو چھٹی تھی؟" پوچھیں۔',
            english: '📅 Ask "Which dates was I on leave?" to see the dates.',
          );

      // ============================================================
        case ChatIntent.attendanceSummary:
          final present = getInt("present_days");
          final late = getInt("late_arrival_days");
          final onTime = getInt("on_time_arrival_days");
          final earlyExit = getInt("early_exit_days");
          final halfDays = getInt("half_days");
          final hours = getString("total_working_hours", def: "0:00:00");
          final violations = getInt("total_geo_violations");
          final leaveDays = getInt("total_leave_days");
          final formattedHours = _formatTime(hours);
          final formattedHoursUrdu = _formatTimeUrdu(hours);

          return _bilingual(
            urdu: '📊 **اس مہینے کی حاضری کا خلاصہ**\n\n'
                '✅ حاضر: **$present** دن\n'
                '⏰ دیر سے: **$late** دن\n'
                '🕐 وقت پر: **$onTime** دن\n'
                '🚪 جلدی گئے: **$earlyExit** دن\n'
                '🌗 ادھے دن: **$halfDays**\n'
                '⏱️ کل کام کے گھنٹے: **$formattedHoursUrdu**\n'
                '📍 جگہ کی خلاف ورزیاں: **$violations**\n'
                '🏖️ چھٹی: **$leaveDays** دن',
            english: '📊 **Attendance Summary for this month**\n\n'
                '✅ Present: **$present** days\n'
                '⏰ Late: **$late** days\n'
                '🕐 On Time: **$onTime** days\n'
                '🚪 Early Exit: **$earlyExit** days\n'
                '🌗 Half Days: **$halfDays**\n'
                '⏱️ Total Working Hours: **$formattedHours**\n'
                '📍 Geo Violations: **$violations**\n'
                '🏖️ Leave: **$leaveDays** days',
          );

      // ============================================================
        default:
          return _bilingual(
            urdu: '⚠️ معذرت، یہ ڈیٹا ابھی دستیاب نہیں ہے۔ بعد میں دوبارہ پوچھیں۔',
            english: '⚠️ Sorry, this data is not available yet. Please ask again later.',
          );
      }
    } catch (e, st) {
      print('❌ ERROR in buildMonthly: $e\n$st');
      return _bilingual(
        urdu: '⚠️ ڈیٹا حاصل کرنے میں مسئلہ ہوا۔ بعد میں دوبارہ کوشش کریں۔\nError: $e',
        english: '⚠️ Error fetching data. Please try again later.\nError: $e',
      );
    }
  }

  /// Helper to combine Urdu and English responses with a separator
  static String _bilingual({required String urdu, required String english}) {
    return '$urdu\n\n---\n\n$english';
  }

  /// Format time from HH:MM:SS to readable format
  static String _formatTime(String timeStr) {
    try {
      if (timeStr == '0:00:00' || timeStr == '00:00:00' || timeStr == 'N/A') {
        return '0 hours';
      }

      final parts = timeStr.split(':');
      if (parts.length < 2) return timeStr;

      int hours = 0;
      int minutes = 0;
      int seconds = 0;

      if (parts.length == 3) {
        hours = int.tryParse(parts[0]) ?? 0;
        minutes = int.tryParse(parts[1]) ?? 0;
        seconds = int.tryParse(parts[2]) ?? 0;
      } else if (parts.length == 2) {
        hours = int.tryParse(parts[0]) ?? 0;
        minutes = int.tryParse(parts[1]) ?? 0;
      }

      List<String> result = [];

      if (hours > 0) {
        result.add('$hours hours');
      }
      if (minutes > 0) {
        result.add('$minutes minutes');
      }
      if (seconds > 0) {
        result.add('$seconds seconds');
      }

      if (result.isEmpty) return '0 hours';

      if (result.length == 1) {
        return result.first;
      } else if (result.length == 2) {
        return '${result[0]}, ${result[1]}';
      } else {
        return '${result[0]}, ${result[1]}, ${result[2]}';
      }
    } catch (e) {
      print('Error formatting time: $e');
      return timeStr;
    }
  }

  static String _calculateAverage(String totalHours, int days) {
    if (days == 0) return '0 hours';
    try {
      final parts = totalHours.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final s = parts.length == 3 ? (int.tryParse(parts[2]) ?? 0) : 0;

        final totalSeconds = (h * 3600) + (m * 60) + s;
        final avgSeconds = totalSeconds ~/ days;

        final avgHours = avgSeconds ~/ 3600;
        final avgMinutes = (avgSeconds % 3600) ~/ 60;
        final avgSecondsRem = avgSeconds % 60;

        List<String> result = [];
        if (avgHours > 0) result.add('$avgHours hours');
        if (avgMinutes > 0) result.add('$avgMinutes minutes');
        if (avgSecondsRem > 0) result.add('$avgSecondsRem seconds');

        if (result.isEmpty) return '0 hours';
        if (result.length == 1) return result.first;
        if (result.length == 2) return '${result[0]}, ${result[1]}';
        return '${result[0]}, ${result[1]}, ${result[2]}';
      }
    } catch (e) {
      return totalHours;
    }
    return totalHours;
  }

  // FIX: Urdu-language counterparts of _formatTime / _calculateAverage.
  // The old code reused the English-worded _formatTime("hours"/"minutes")
  // result inside Urdu sentences too. Mixing Latin "hours, minutes" text
  // inside an RTL Urdu sentence makes Flutter's bidi algorithm reorder the
  // characters, which is exactly the garbled "13 hours, 8 minutes. کل
  // دیری کا وقت:" look reported. These return the same numbers with Urdu
  // unit words instead, so the whole Urdu string stays RTL-consistent.
  static String _formatTimeUrdu(String timeStr) {
    try {
      if (timeStr == '0:00:00' || timeStr == '00:00:00' || timeStr == 'N/A') {
        return '0 گھنٹے';
      }

      final parts = timeStr.split(':');
      if (parts.length < 2) return timeStr;

      int hours = 0;
      int minutes = 0;
      int seconds = 0;

      if (parts.length == 3) {
        hours = int.tryParse(parts[0]) ?? 0;
        minutes = int.tryParse(parts[1]) ?? 0;
        seconds = int.tryParse(parts[2]) ?? 0;
      } else if (parts.length == 2) {
        hours = int.tryParse(parts[0]) ?? 0;
        minutes = int.tryParse(parts[1]) ?? 0;
      }

      List<String> result = [];
      if (hours > 0) result.add('$hours گھنٹے');
      if (minutes > 0) result.add('$minutes منٹ');
      if (seconds > 0) result.add('$seconds سیکنڈ');

      if (result.isEmpty) return '0 گھنٹے';
      if (result.length == 1) return result.first;
      if (result.length == 2) return '${result[0]}, ${result[1]}';
      return '${result[0]}, ${result[1]}, ${result[2]}';
    } catch (e) {
      print('Error formatting Urdu time: $e');
      return timeStr;
    }
  }

  static String _calculateAverageUrdu(String totalHours, int days) {
    if (days == 0) return '0 گھنٹے';
    try {
      final parts = totalHours.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final s = parts.length == 3 ? (int.tryParse(parts[2]) ?? 0) : 0;

        final totalSeconds = (h * 3600) + (m * 60) + s;
        final avgSeconds = totalSeconds ~/ days;

        final avgHours = avgSeconds ~/ 3600;
        final avgMinutes = (avgSeconds % 3600) ~/ 60;
        final avgSecondsRem = avgSeconds % 60;

        List<String> result = [];
        if (avgHours > 0) result.add('$avgHours گھنٹے');
        if (avgMinutes > 0) result.add('$avgMinutes منٹ');
        if (avgSecondsRem > 0) result.add('$avgSecondsRem سیکنڈ');

        if (result.isEmpty) return '0 گھنٹے';
        if (result.length == 1) return result.first;
        if (result.length == 2) return '${result[0]}, ${result[1]}';
        return '${result[0]}, ${result[1]}, ${result[2]}';
      }
    } catch (e) {
      return totalHours;
    }
    return totalHours;
  }

  // FIX: Urdu status label, used so the daily-working-hours follow-up list
  // doesn't show raw English status words like "on time"/"half day" inside
  // an otherwise Urdu line.
  static String _statusToUrdu(String status) {
    switch (status) {
      case 'on time':
        return 'وقت پر';
      case 'late':
        return 'دیر سے';
      case 'half day':
        return 'ادھا دن';
      case 'absent':
        return 'غیر حاضر';
      case 'leave':
        return 'چھٹی';
      case 'holiday':
        return 'تعطیل';
      default:
        return status;
    }
  }

  // ---------------------------------------------------------------------------
  // Daily attendance response
  // ---------------------------------------------------------------------------

  static String buildDaily(Map<String, dynamic> response) {
    print('=== ResponseBuilder.buildDaily called ===');
    try {
      final items = response['items'];

      if (items == null || items.isEmpty) {
        return _bilingual(
          urdu: '📅 آج کی حاضری کا ریکارڈ نہیں ملا۔',
          english: '📅 No attendance record found for today.',
        );
      }

      final today = items.last;

      // ✅ Use correct keys from API
      final status = today['STATUS_TEXT']?.toString() ?? 'N/A';
      final firstIn = today['FIRST_IN']?.toString() ?? 'N/A';
      final lastOut = today['LAST_OUT']?.toString() ?? 'N/A';
      final totalStay = today['total_stay']?.toString() ?? 'N/A';
      final lateTime = today['late_time']?.toString() ?? 'N/A';
      final earlyExit = today['early_exit']?.toString() ?? 'N/A';
      final dayType = today['day_type']?.toString() ?? 'N/A';
      final violations = today['geo_violations'] ?? 0;
      final offline = today['offline_events'] ?? 0;

      return _bilingual(
        urdu: '📅 **آج کی حاضری کی تفصیل**\n\n'
            '📌 حالت: **$status**\n'
            '🚪 پہلی آمد: **$firstIn**\n'
            '🚪 آخری روانگی: **$lastOut**\n'
            '⏱️ کل وقت: **$totalStay**\n'
            '⏰ دیری: **$lateTime**\n'
            '🚪 جلدی رخصتی: **$earlyExit**\n'
            '📅 دن کی قسم: **$dayType**\n'
            '📍 جگہ کی خلاف ورزیاں: **$violations**\n'
            '📱 آف لائن واقعات: **$offline**',
        english: '📅 **Today\'s Attendance Detail**\n\n'
            '📌 Status: **$status**\n'
            '🚪 First In: **$firstIn**\n'
            '🚪 Last Out: **$lastOut**\n'
            '⏱️ Total Time: **$totalStay**\n'
            '⏰ Late: **$lateTime**\n'
            '🚪 Early Exit: **$earlyExit**\n'
            '📅 Day Type: **$dayType**\n'
            '📍 Geo Violations: **$violations**\n'
            '📱 Offline Events: **$offline**',
      );
    } catch (e) {
      print('ERROR in buildDaily: $e');
      return _bilingual(
        urdu: '⚠️ آج کا ڈیٹا حاصل کرنے میں مسئلہ ہوا۔ بعد میں دوبارہ کوشش کریں۔',
        english: '⚠️ Error fetching today\'s data. Please try again later.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Follow-up date queries - FIXED with correct data keys
  // ---------------------------------------------------------------------------

  static String buildDailyFollowUp(ChatIntent intent, Map<String, dynamic> response) {
    print('=== ResponseBuilder.buildDailyFollowUp called ===');
    print('Intent: $intent');

    try {
      final items = response['items'];

      if (items == null || items.isEmpty) {
        return _bilingual(
          urdu: '⚠️ کوئی ڈیٹا نہیں ملا۔ بعد میں دوبارہ پوچھیں۔',
          english: '⚠️ No data found. Please ask again later.',
        );
      }

      // ✅ Take last 30 days
      final data = items.length > 30 ? items.sublist(items.length - 30) : items;
      print('Total days to process: ${data.length}');

      // FIX: build separate Urdu and English lists instead of one shared
      // list with hardcoded English labels ("Late:", "Early Exit:",
      // "violations"). Re-using that single mixed list for both the urdu
      // and english fields of _bilingual() is why the Urdu bubble showed
      // English words embedded mid-sentence.
      List<String> matchedUrdu = [];
      List<String> matchedEn = [];

      for (var day in data) {
        try {
          final date = day['work_date']?.toString() ?? '';
          if (date.isEmpty) continue;

          // ✅ Extract values safely
          final status = day['status_text']?.toString().toLowerCase() ?? '';
          final onLeave = day['on_leave']?.toString().toLowerCase() == 'yes';
          final holiday = day['day_type']?.toString().toLowerCase() == 'holiday';
          final lateTime = day['late_time']?.toString() ?? '';
          final earlyExitTime = day['early_exit']?.toString() ?? '';
          final totalStay = day['total_stay']?.toString() ?? '';
          final geoViolations = (day['geo_violations'] ?? 0) as int;
          final offlineEvents = (day['offline_events'] ?? 0) as int;

          switch (intent) {
          // ==========================================================
            case ChatIntent.presentDates:
            // ✅ Present if: on time, late, or half day (AND not on leave, not holiday)
              if ((status.contains('on time') ||
                  status.contains('late') ||
                  status == 'half day') &&
                  !onLeave &&
                  !holiday) {
                matchedUrdu.add(date);
                matchedEn.add(date);
              }
              break;

          // ==========================================================
            case ChatIntent.lateDates:
            // ✅ Late if late_time is not 00:00:00
              if (lateTime != '00:00:00' && lateTime != 'N/A' && lateTime.isNotEmpty) {
                matchedUrdu.add('$date (دیر سے: ${_formatTimeUrdu(lateTime)})');
                matchedEn.add('$date (Late: ${_formatTime(lateTime)})');
              }
              break;

          // ==========================================================
            case ChatIntent.onTimeDates:
            // ✅ On time if status_text is exactly "on time"
              if (status == 'on time') {
                matchedUrdu.add(date);
                matchedEn.add(date);
              }
              break;

          // ==========================================================
            case ChatIntent.earlyExitDates:
            // ✅ Early exit if early_exit is not 00:00:00
              if (earlyExitTime != '00:00:00' && earlyExitTime != 'N/A' && earlyExitTime.isNotEmpty) {
                matchedUrdu.add('$date (جلدی روانگی: ${_formatTimeUrdu(earlyExitTime)})');
                matchedEn.add('$date (Early Exit: ${_formatTime(earlyExitTime)})');
              }
              break;

          // ==========================================================
            case ChatIntent.dailyWorkingHours:
            // ✅ Show daily hours
              final stayUrdu = totalStay != 'N/A' ? _formatTimeUrdu(totalStay) : totalStay;
              final stayEn = totalStay != 'N/A' ? _formatTime(totalStay) : totalStay;
              matchedUrdu.add('$date: $stayUrdu (${_statusToUrdu(status)})');
              matchedEn.add('$date: $stayEn ($status)');
              break;

          // ==========================================================
            case ChatIntent.halfDayDates:
            // ✅ Half day if status_text is "half day"
              if (status == 'half day') {
                final stayUrdu = totalStay != 'N/A' ? _formatTimeUrdu(totalStay) : totalStay;
                final stayEn = totalStay != 'N/A' ? _formatTime(totalStay) : totalStay;
                matchedUrdu.add('$date ($stayUrdu)');
                matchedEn.add('$date ($stayEn)');
              }
              break;

          // ==========================================================
            case ChatIntent.geoViolationDates:
            // ✅ Geo violations if > 0
              if (geoViolations > 0) {
                matchedUrdu.add('$date ($geoViolations خلاف ورزیاں)');
                matchedEn.add('$date ($geoViolations violations)');
              }
              break;

          // ==========================================================
            case ChatIntent.offlineEventDates:
            // ✅ Offline events if > 0
              if (offlineEvents > 0) {
                matchedUrdu.add('$date ($offlineEvents واقعات)');
                matchedEn.add('$date ($offlineEvents events)');
              }
              break;

          // ==========================================================
            case ChatIntent.leaveDates:
            // ✅ Leave if on_leave is "yes"
              if (onLeave) {
                matchedUrdu.add(date);
                matchedEn.add(date);
              }
              break;

            default:
            // Do nothing for other intents
              break;
          }
        } catch (e) {
          print('Error processing day: $e');
        }
      }

      // ✅ If no matches found
      if (matchedUrdu.isEmpty) {
        return _buildEmptyResponse(intent);
      }

      // ✅ Format response — Urdu
      final displayUrdu = matchedUrdu.length > 15 ? matchedUrdu.sublist(0, 15) : matchedUrdu;
      final suffixUrdu = matchedUrdu.length > 15
          ? '\n... اور ${matchedUrdu.length - 15} مزید تاریخیں ہیں۔'
          : '';

      // ✅ Format response — English
      final displayEn = matchedEn.length > 15 ? matchedEn.sublist(0, 15) : matchedEn;
      final suffixEn = matchedEn.length > 15
          ? '\n... and ${matchedEn.length - 15} more dates.'
          : '';

      final titleUrdu = _getTitleForIntent(intent);
      final titleEn = _getTitleForIntentEnglish(intent);

      // ✅ Return bilingual response, fully separate per language
      return _bilingual(
        urdu: '$titleUrdu\n${displayUrdu.map((d) => '• $d').join('\n')}$suffixUrdu',
        english: '$titleEn\n${displayEn.map((d) => '• $d').join('\n')}$suffixEn',
      );

    } catch (e, st) {
      print('❌ ERROR in buildDailyFollowUp: $e\n$st');
      return _bilingual(
        urdu: '⚠️ ڈیٹا حاصل کرنے میں مسئلہ ہوا۔ بعد میں دوبارہ کوشش کریں۔',
        english: '⚠️ Error fetching data. Please try again later.',
      );
    }
  }

  // ✅ Helper to build empty response
  static String _buildEmptyResponse(ChatIntent intent) {
    switch (intent) {
      case ChatIntent.presentDates:
        return _bilingual(
          urdu: '❌ آپ اس مہینے کسی دن حاضر نہیں رہے۔',
          english: '❌ You were not present on any day this month.',
        );
      case ChatIntent.lateDates:
        return _bilingual(
          urdu: '✅ آپ اس مہینے کسی دن دیر سے نہیں آئے۔',
          english: '✅ You were not late on any day this month.',
        );
      case ChatIntent.onTimeDates:
        return _bilingual(
          urdu: '❌ آپ اس مہینے کسی دن وقت پر نہیں آئے۔',
          english: '❌ You did not arrive on time any day this month.',
        );
      case ChatIntent.earlyExitDates:
        return _bilingual(
          urdu: '✅ آپ اس مہینے کسی دن جلدی نہیں گئے۔',
          english: '✅ You did not leave early any day this month.',
        );
      case ChatIntent.dailyWorkingHours:
        return _bilingual(
          urdu: '⚠️ کام کے گھنٹوں کا کوئی ڈیٹا نہیں ملا۔',
          english: '⚠️ No working hours data found.',
        );
      case ChatIntent.halfDayDates:
        return _bilingual(
          urdu: '❌ اس مہینے کوئی ادھا دن نہیں ہے۔',
          english: '❌ No half days this month.',
        );
      case ChatIntent.geoViolationDates:
        return _bilingual(
          urdu: '✅ اس مہینے کوئی جگہ کی خلاف ورزی نہیں ہے۔',
          english: '✅ No geo violations this month.',
        );
      case ChatIntent.offlineEventDates:
        return _bilingual(
          urdu: '✅ اس مہینے کوئی آف لائن واقعہ نہیں ہے۔',
          english: '✅ No offline events this month.',
        );
      case ChatIntent.leaveDates:
        return _bilingual(
          urdu: '❌ آپ نے اس مہینے کوئی چھٹی نہیں لی۔',
          english: '❌ You did not take any leave this month.',
        );
      default:
        return _bilingual(
          urdu: '⚠️ کوئی مطابق ریکارڈ نہیں ملا۔',
          english: '⚠️ No matching records found.',
        );
    }
  }

  // ✅ Helper to get title for intent
  static String _getTitleForIntent(ChatIntent intent) {
    switch (intent) {
      case ChatIntent.presentDates:
        return '📅 **آپ ان تاریخوں کو حاضر رہے:**';
      case ChatIntent.lateDates:
        return '⏰ **آپ ان تاریخوں کو دیر سے آئے:**';
      case ChatIntent.onTimeDates:
        return '🕐 **آپ ان تاریخوں کو وقت پر آئے:**';
      case ChatIntent.earlyExitDates:
        return '🚪 **آپ ان تاریخوں کو جلدی گئے:**';
      case ChatIntent.dailyWorkingHours:
        return '⏱️ **روزانہ کام کے گھنٹے:**';
      case ChatIntent.halfDayDates:
        return '🌗 **ان تاریخوں پر ادھے دن:**';
      case ChatIntent.geoViolationDates:
        return '📍 **ان تاریخوں کو جگہ کی خلاف ورزیاں:**';
      case ChatIntent.offlineEventDates:
        return '📱 **ان تاریخوں کو آف لائن واقعات:**';
      case ChatIntent.leaveDates:
        return '🏖️ **آپ نے ان تاریخوں پر چھٹی لی:**';
      default:
        return '📅 **تاریخیں:**';
    }
  }

  // FIX: English counterpart of _getTitleForIntent, used so the English
  // side of buildDailyFollowUp's bilingual response no longer reuses the
  // Urdu-only title.
  static String _getTitleForIntentEnglish(ChatIntent intent) {
    switch (intent) {
      case ChatIntent.presentDates:
        return '📅 **You were present on these dates:**';
      case ChatIntent.lateDates:
        return '⏰ **You were late on these dates:**';
      case ChatIntent.onTimeDates:
        return '🕐 **You were on time on these dates:**';
      case ChatIntent.earlyExitDates:
        return '🚪 **You left early on these dates:**';
      case ChatIntent.dailyWorkingHours:
        return '⏱️ **Daily working hours:**';
      case ChatIntent.halfDayDates:
        return '🌗 **Half days on these dates:**';
      case ChatIntent.geoViolationDates:
        return '📍 **Geo violations on these dates:**';
      case ChatIntent.offlineEventDates:
        return '📱 **Offline events on these dates:**';
      case ChatIntent.leaveDates:
        return '🏖️ **You were on leave on these dates:**';
      default:
        return '📅 **Dates:**';
    }
  }

  // ---------------------------------------------------------------------------
  // Monthly + month header
  // ---------------------------------------------------------------------------

  static String buildMonthlyWithMonth(ChatIntent intent, Map<String, dynamic> response, String month) {
    try {
      final formattedMonth = _formatMonthDisplay(month);
      final base = buildMonthly(intent, response);
      return '📅 **$formattedMonth**\n\n$base';
    } catch (e) {
      print('ERROR in buildMonthlyWithMonth: $e');
      return _bilingual(
        urdu: '⚠️ ڈیٹا حاصل کرنے میں مسئلہ ہوا۔ بعد میں دوبارہ کوشش کریں۔',
        english: '⚠️ Error fetching data. Please try again later.',
      );
    }
  }

  static String _formatMonthDisplay(String month) {
    try {
      final parts = month.split('-');
      if (parts.length == 2) {
        final year = parts[0];
        final monthNum = int.tryParse(parts[1]) ?? 1;
        if (monthNum < 1 || monthNum > 12) return month;

        const monthNames = [
          'جنوری', 'فروری', 'مارچ', 'اپریل',
          'مئی', 'جون', 'جولائی', 'اگست',
          'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر',
        ];
        return '${monthNames[monthNum - 1]} $year';
      }
      return month;
    } catch (e) {
      return month;
    }
  }

  // ---------------------------------------------------------------------------
  // Utility methods
  // ---------------------------------------------------------------------------

  static String cleanText(String text) {
    text = text.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'\*(.+?)\*'), r'$1');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  static String prepareForSpeech(String text) {
    if (text.contains('---')) {
      text = text.split('---')[0].trim();
    }
    text = text.replaceAll('•', '');
    text = text.replaceAll('\n', '۔ ');
    text = cleanText(text);
    return text.trim();
  }

  static String formatError(String error) =>
      '⚠️ معذرت، کچھ مسئلہ پیش آیا: $error۔ بعد میں دوبارہ کوشش کریں۔';

  static String formatSuccess(String message) => '✅ ٹھیک ہے، $message';

  static bool hasMarkdown(String text) => text.contains('**') || text.contains('*');
}