// // // // import 'package:flutter/foundation.dart';
// // // // import 'package:dio/dio.dart';
// // // //
// // // // import '../core/api_router.dart';
// // // // import '../models/chat_message.dart';
// // // //
// // // // class ChatController extends ChangeNotifier {
// // // //   final ApiRouter router;
// // // //
// // // //   ChatController(this.router) {
// // // //     print('=== ChatController initialized ===');
// // // //     messages.add(
// // // //       ChatMessage(
// // // //         text: "Assalam-o-Alaikum! Main aap ki attendance ke baare mein "
// // // //             "sawalon ka jawab de sakta hoon.",
// // // //         isUser: false,
// // // //       ),
// // // //     );
// // // //   }
// // // //
// // // //   final List<ChatMessage> messages = [];
// // // //   bool isTyping = false;
// // // //
// // // //   Future<void> sendMessage(String text) async {
// // // //     print('=== sendMessage called ===');
// // // //     print('Text: $text');
// // // //
// // // //     final trimmed = text.trim();
// // // //     if (trimmed.isEmpty) return;
// // // //
// // // //     messages.add(ChatMessage(text: trimmed, isUser: true));
// // // //     isTyping = true;
// // // //     notifyListeners();
// // // //
// // // //     try {
// // // //       print('Calling router.ask...');
// // // //       final reply = await router.ask(trimmed);
// // // //       print('Reply received: $reply');
// // // //       messages.add(ChatMessage(text: reply, isUser: false));
// // // //     } on DioException catch (e) {
// // // //       print('DioException caught: $e');
// // // //       print('DioException type: ${e.type}');
// // // //       print('DioException response: ${e.response}');
// // // //       print('DioException message: ${e.message}');
// // // //
// // // //       String errorMsg = _dioErrorMessage(e);
// // // //       print('Error message: $errorMsg');
// // // //       messages.add(
// // // //         ChatMessage(text: errorMsg, isUser: false, isError: true),
// // // //       );
// // // //     } catch (e, stackTrace) {
// // // //       print('GENERAL EXCEPTION caught: $e');
// // // //       print('Stack trace: $stackTrace');
// // // //       messages.add(
// // // //         ChatMessage(
// // // //           text: "Maazrat, kuch ghalat ho gaya. Error: ${e.toString()}",
// // // //           isUser: false,
// // // //           isError: true,
// // // //         ),
// // // //       );
// // // //     }
// // // //
// // // //     isTyping = false;
// // // //     notifyListeners();
// // // //     print('=== sendMessage completed ===');
// // // //   }
// // // //
// // // //   String _dioErrorMessage(DioException e) {
// // // //     switch (e.type) {
// // // //       case DioExceptionType.connectionTimeout:
// // // //       case DioExceptionType.receiveTimeout:
// // // //       case DioExceptionType.sendTimeout:
// // // //         return "Server se jawab dene mein dair ho rahi hai. Internet check karein.";
// // // //       case DioExceptionType.connectionError:
// // // //         return "Internet connection check karein.";
// // // //       default:
// // // //         if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
// // // //           return "Authorization issue hai. Dobara login karein.";
// // // //         }
// // // //         if (e.response?.data != null) {
// // // //           try {
// // // //             final data = e.response?.data;
// // // //             if (data is Map && data.containsKey('message')) {
// // // //               return "Server error: ${data['message']}";
// // // //             }
// // // //           } catch (_) {}
// // // //         }
// // // //         return "Server se data lene mein masla hua "
// // // //             "(status: ${e.response?.statusCode ?? 'no connection'}). "
// // // //             "Error: ${e.message}";
// // // //     }
// // // //   }
// // // // }
// // //
// // // import 'package:flutter/foundation.dart';
// // // import 'package:dio/dio.dart';
// // //
// // // import '../core/api_router.dart';
// // // import '../models/chat_message.dart';
// // // import '../session_helper.dart';
// // //
// // // class ChatController extends ChangeNotifier {
// // //   final ApiRouter router;
// // //
// // //   // Store the last response data for context
// // //   Map<String, dynamic> _lastResponseData = {};
// // //   String _lastIntent = '';
// // //   String _lastQuestion = '';
// // //
// // //   ChatController(this.router) {
// // //     messages.add(
// // //       ChatMessage(
// // //         text: "Assalam-o-Alaikum! Main aap ki attendance ke baare mein "
// // //             "sawalon ka jawab de sakta hoon. Aap pooch sakte hain:\n"
// // //             "• Kitne din present rahe?\n"
// // //             "• Kis kis date ko present the?\n"
// // //             "• Kitni late hui?\n"
// // //             "• Kis date ko late aaye?\n"
// // //             "• Kitni working hours hain?\n"
// // //             "• Koi violation hai?",
// // //         isUser: false,
// // //       ),
// // //     );
// // //   }
// // //
// // //   final List<ChatMessage> messages = [];
// // //   bool isTyping = false;
// // //
// // //   Future<void> sendMessage(String text) async {
// // //     final trimmed = text.trim();
// // //     if (trimmed.isEmpty) return;
// // //
// // //     messages.add(ChatMessage(text: trimmed, isUser: true));
// // //     isTyping = true;
// // //     notifyListeners();
// // //
// // //     try {
// // //       // Check if it's a follow-up question about dates
// // //       final reply = await _handleFollowUp(trimmed);
// // //
// // //       messages.add(ChatMessage(text: reply, isUser: false));
// // //     } on DioException catch (e) {
// // //       String errorMsg = _dioErrorMessage(e);
// // //       messages.add(
// // //         ChatMessage(text: errorMsg, isUser: false, isError: true),
// // //       );
// // //     } catch (e) {
// // //       messages.add(
// // //         ChatMessage(
// // //           text: "Maazrat, kuch ghalat ho gaya. Error: ${e.toString()}",
// // //           isUser: false,
// // //           isError: true,
// // //         ),
// // //       );
// // //     }
// // //
// // //     isTyping = false;
// // //     notifyListeners();
// // //   }
// // //
// // //   Future<String> _handleFollowUp(String text) async {
// // //     final lowerText = text.toLowerCase().trim();
// // //
// // //     // Check if asking about specific dates
// // //     if (_lastResponseData.isNotEmpty &&
// // //         (_lastIntent == 'presentDays' || _lastIntent == 'attendanceSummary')) {
// // //
// // //       // Asking about dates
// // //       if (lowerText.contains('date') ||
// // //           lowerText.contains('kis') ||
// // //           lowerText.contains('kab') ||
// // //           lowerText.contains('kin kin') ||
// // //           lowerText.contains('which')) {
// // //
// // //         // If we have daily data, get dates
// // //         if (_lastResponseData.containsKey('dailyData')) {
// // //           final dailyData = _lastResponseData['dailyData'] as List?;
// // //           if (dailyData != null && dailyData.isNotEmpty) {
// // //             return _buildDateResponse(lowerText, dailyData);
// // //           }
// // //         }
// // //
// // //         // If we don't have daily data, fetch it
// // //         return await _fetchAndGetDates(text);
// // //       }
// // //     }
// // //
// // //     // If asking about specific date details
// // //     if (lowerText.contains('date') || lowerText.contains('kis')) {
// // //       // Try to fetch data for that specific question
// // //       return await router.ask(text);
// // //     }
// // //
// // //     // Regular question
// // //     final reply = await router.ask(text);
// // //
// // //     // Store context for follow-up
// // //     if (reply.contains('din present') ||
// // //         reply.contains('din late') ||
// // //         reply.contains('working hours')) {
// // //       _lastQuestion = text;
// // //       // Try to get daily data for follow-up
// // //       await _storeDailyContext();
// // //     }
// // //
// // //     return reply;
// // //   }
// // //
// // //   Future<void> _storeDailyContext() async {
// // //     try {
// // //       final empId = await SessionHelper.getEmpId();
// // //       final month = await SessionHelper.getMonth();
// // //       final company = await SessionHelper.getCompanyCode();
// // //
// // //       // Get daily data for context
// // //       final response = await router.daily.getDaily(
// // //         empId: empId,
// // //         companyCode: company,
// // //         month: month,
// // //       );
// // //
// // //       if (response.containsKey('items')) {
// // //         _lastResponseData['dailyData'] = response['items'];
// // //       }
// // //     } catch (e) {
// // //       print('Error storing daily context: $e');
// // //     }
// // //   }
// // //
// // //   String _buildDateResponse(String question, List<dynamic> dailyData) {
// // //     final isPresent = question.contains('present') || question.contains('hazir');
// // //     final isLate = question.contains('late') || question.contains('der');
// // //     final isViolation = question.contains('violation') || question.contains('geo');
// // //     final isLeave = question.contains('leave') || question.contains('chutti');
// // //     final isHalfDay = question.contains('half') || question.contains('aadha');
// // //
// // //     // Get last 30 days or all
// // //     final data = dailyData.length > 30 ? dailyData.sublist(dailyData.length - 30) : dailyData;
// // //
// // //     List<String> matchedDates = [];
// // //
// // //     for (var day in data) {
// // //       final status = day['status_text']?.toString().toLowerCase() ?? '';
// // //       final isOnLeave = day['on_leave']?.toString().toLowerCase() == 'yes';
// // //       final isHoliday = day['day_type']?.toString().toLowerCase() == 'holiday';
// // //       final geoViolations = day['geo_violations'] ?? 0;
// // //       final date = day['work_date'] ?? '';
// // //
// // //       if (isPresent && (status.contains('on time') || status.contains('late') || status == 'half day')) {
// // //         if (!isOnLeave && !isHoliday) {
// // //           matchedDates.add(date);
// // //         }
// // //       } else if (isLate && status.contains('late')) {
// // //         matchedDates.add('$date (Late: ${day['late_time'] ?? 'N/A'})');
// // //       } else if (isViolation && geoViolations > 0) {
// // //         matchedDates.add('$date (${geoViolations} violation${geoViolations > 1 ? 's' : ''})');
// // //       } else if (isLeave && isOnLeave) {
// // //         matchedDates.add(date);
// // //       } else if (isHalfDay && status == 'half day') {
// // //         matchedDates.add('$date (${day['total_stay'] ?? 'N/A'})');
// // //       }
// // //     }
// // //
// // //     if (matchedDates.isEmpty) {
// // //       if (isPresent) return "Aap kisi din present nahi rahe is mahine.";
// // //       if (isLate) return "Aap kisi din late nahi aaye is mahine.";
// // //       if (isViolation) return "Koi violation nahi hai is mahine.";
// // //       if (isLeave) return "Aap ne koi chutti nahi li is mahine.";
// // //       if (isHalfDay) return "Koi half day nahi hai is mahine.";
// // //       return "Koi matching record nahi mila.";
// // //     }
// // //
// // //     // Limit to 10 dates to avoid long messages
// // //     final displayDates = matchedDates.length > 10 ? matchedDates.sublist(0, 10) : matchedDates;
// // //     final suffix = matchedDates.length > 10 ? "\n... aur ${matchedDates.length - 10} aur dates hain." : "";
// // //
// // //     if (isPresent) {
// // //       return "Aap in dates ko present rahe:\n${displayDates.join('\n• ')}${suffix}";
// // //     } else if (isLate) {
// // //       return "Aap in dates ko late aaye:\n${displayDates.join('\n• ')}${suffix}";
// // //     } else if (isViolation) {
// // //       return "Geo violations in dates par hain:\n${displayDates.join('\n• ')}${suffix}";
// // //     } else if (isLeave) {
// // //       return "Aap ne in dates par chutti li:\n${displayDates.join('\n• ')}${suffix}";
// // //     } else if (isHalfDay) {
// // //       return "Half days in dates par hain:\n${displayDates.join('\n• ')}${suffix}";
// // //     }
// // //
// // //     return "Ye dates mili hain:\n${displayDates.join('\n• ')}${suffix}";
// // //   }
// // //
// // //   Future<String> _fetchAndGetDates(String text) async {
// // //     final reply = await router.ask(text);
// // //
// // //     // Parse the reply to understand what was asked
// // //     if (reply.contains('din present')) {
// // //       // Fetch daily data and filter
// // //       try {
// // //         final empId = await SessionHelper.getEmpId();
// // //         final month = await SessionHelper.getMonth();
// // //         final company = await SessionHelper.getCompanyCode();
// // //
// // //         final response = await router.daily.getDaily(
// // //           empId: empId,
// // //           companyCode: company,
// // //           month: month,
// // //         );
// // //
// // //         final items = response['items'] as List?;
// // //         if (items != null && items.isNotEmpty) {
// // //           return _buildDateResponse('present dates', items);
// // //         }
// // //       } catch (e) {
// // //         print('Error fetching dates: $e');
// // //       }
// // //     }
// // //
// // //     return reply;
// // //   }
// // //
// // //   String _dioErrorMessage(DioException e) {
// // //     switch (e.type) {
// // //       case DioExceptionType.connectionTimeout:
// // //       case DioExceptionType.receiveTimeout:
// // //       case DioExceptionType.sendTimeout:
// // //         return "Server se jawab dene mein dair ho rahi hai. Internet check karein.";
// // //       case DioExceptionType.connectionError:
// // //         return "Internet connection check karein.";
// // //       default:
// // //         if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
// // //           return "Authorization issue hai. Dobara login karein.";
// // //         }
// // //         if (e.response?.data != null) {
// // //           try {
// // //             final data = e.response?.data;
// // //             if (data is Map && data.containsKey('message')) {
// // //               return "Server error: ${data['message']}";
// // //             }
// // //           } catch (_) {}
// // //         }
// // //         return "Server se data lene mein masla hua "
// // //             "(status: ${e.response?.statusCode ?? 'no connection'}). "
// // //             "Error: ${e.message}";
// // //     }
// // //   }
// // // }
// //
// // import 'package:GPS_Workforce_Monitor/chatbot/core/response_builder.dart';
// // import 'package:flutter/foundation.dart';
// // import 'package:dio/dio.dart';
// // import 'dart:async';
// //
// // import '../core/api_router.dart';
// // import '../models/chat_message.dart';
// // import '../services/voice_service.dart';
// // import '../session_helper.dart';
// //
// // class ChatController extends ChangeNotifier {
// //   final ApiRouter router;
// //   final VoiceService voiceService = VoiceService();
// //
// //   final List<ChatMessage> messages = [];
// //
// //   bool isTyping          = false;
// //   bool _isListening      = false;
// //   bool _isSpeaking       = false;
// //   String _voiceTranscript  = '';
// //   double _voiceConfidence  = 0.0;
// //   bool _isVoiceAvailable   = false;
// //
// //   Timer? _silenceTimer;
// //
// //   Map<String, dynamic> _lastResponseData = {};
// //   String _lastIntent  = '';
// //   String _lastQuestion = '';
// //
// //   // ---------------------------------------------------------------------------
// //   // Constructor
// //   // ---------------------------------------------------------------------------
// //
// //   ChatController(this.router) {
// //     _initializeVoice();
// //     messages.add(
// //       ChatMessage(
// //         text: 'السلام علیکم! میں آپ کی حاضری کے بارے میں سوالوں کا '
// //             'جواب دے سکتا ہوں۔ آپ پوچھ سکتے ہیں:\n'
// //             '• کتنے دن حاضر رہے؟\n'
// //             '• کس کس تاریخ کو حاضر تھے؟\n'
// //             '• کتنی دیر ہوئی؟\n'
// //             '• کس تاریخ کو دیر سے آئے؟\n'
// //             '• کتنے گھنٹے کام کیا؟\n'
// //             '• کوئی خلاف ورزی ہے؟\n\n'
// //             'آواز سے پوچھنے کے لیے مائیک بٹن دبائیں۔',
// //         isUser: false,
// //       ),
// //     );
// //   }
// //
// //   // ---------------------------------------------------------------------------
// //   // Voice initialization
// //   // ---------------------------------------------------------------------------
// //
// //   Future<void> _initializeVoice() async {
// //     try {
// //       _isVoiceAvailable = await voiceService.isSpeechAvailable();
// //       print('🎤 Voice available: $_isVoiceAvailable');
// //       notifyListeners();
// //     } catch (e) {
// //       print('❌ Voice init error: $e');
// //       _isVoiceAvailable = false;
// //     }
// //   }
// //
// //   // ---------------------------------------------------------------------------
// //   // Send message
// //   // ---------------------------------------------------------------------------
// //
// //   Future<void> sendMessage(String text) async {
// //     final trimmed = text.trim();
// //     if (trimmed.isEmpty) return;
// //
// //     // Stop voice input if listening
// //     if (_isListening) await stopVoiceInput();
// //
// //     // Add user message
// //     messages.add(ChatMessage(text: trimmed, isUser: true));
// //     isTyping = true;
// //     notifyListeners();
// //
// //     try {
// //       final reply = await _handleFollowUp(trimmed);
// //       messages.add(ChatMessage(text: reply, isUser: false));
// //
// //       // Auto-speak in Urdu (if not already speaking)
// //       if (!_isSpeaking) {
// //         await speakResponse(reply);
// //       }
// //     } on DioException catch (e) {
// //       messages.add(ChatMessage(
// //           text: _dioErrorMessage(e), isUser: false, isError: true));
// //     } catch (e) {
// //       messages.add(ChatMessage(
// //           text: 'معذرت، کچھ غلط ہو گیا۔ خرابی: ${e.toString()}',
// //           isUser: false,
// //           isError: true));
// //     }
// //
// //     isTyping = false;
// //     notifyListeners();
// //   }
// //
// //   // ---------------------------------------------------------------------------
// //   // Follow-up intent handling with enhanced voice support
// //   // ---------------------------------------------------------------------------
// //
// //   Future<String> _handleFollowUp(String text) async {
// //     // Normalize Urdu script → Roman so keyword matching works regardless
// //     // of whether the input came from voice (Urdu script) or typed (Roman Urdu).
// //     final normalized = voiceService.normalizeForIntent(text);
// //     final lower = normalized.toLowerCase();
// //
// //     print('🔍 Normalized for intent: "$normalized"');
// //
// //     // If context suggests we can answer from cached daily data
// //     if (_lastResponseData.isNotEmpty &&
// //         (_lastIntent == 'presentDays' || _lastIntent == 'attendanceSummary')) {
// //       if (_isDateQuery(lower)) {
// //         if (_lastResponseData.containsKey('dailyData')) {
// //           final dailyData = _lastResponseData['dailyData'] as List?;
// //           if (dailyData != null && dailyData.isNotEmpty) {
// //             return _buildDateResponse(lower, dailyData);
// //           }
// //         }
// //         return await _fetchAndGetDates(text);
// //       }
// //     }
// //
// //     // Generic date / "kis" query
// //     if (_isDateQuery(lower)) {
// //       return await router.ask(text);
// //     }
// //
// //     // Regular API query
// //     final reply = await router.ask(text);
// //
// //     // Cache daily context for potential follow-up
// //     final replyLower = reply.toLowerCase();
// //     if (replyLower.contains('دن') ||
// //         replyLower.contains('din') ||
// //         replyLower.contains('گھنٹے') ||
// //         replyLower.contains('hours')) {
// //       _lastQuestion = text;
// //       await _storeDailyContext();
// //     }
// //
// //     return reply;
// //   }
// //
// //   /// Returns true when the query is asking about specific dates.
// //   bool _isDateQuery(String lower) {
// //     return lower.contains('date')   ||
// //         lower.contains('تاریخ') ||
// //         lower.contains('kis')    ||
// //         lower.contains('کس')    ||
// //         lower.contains('kab')    ||
// //         lower.contains('کب')    ||
// //         lower.contains('kin kin')||
// //         lower.contains('which')  ||
// //         lower.contains('kon si') ||
// //         lower.contains('کن کن') ||
// //         lower.contains('کون سی');
// //   }
// //
// //   Future<void> _storeDailyContext() async {
// //     try {
// //       final empId   = await SessionHelper.getEmpId();
// //       final month   = await SessionHelper.getMonth();
// //       final company = await SessionHelper.getCompanyCode();
// //
// //       final response = await router.daily.getDaily(
// //         empId: empId,
// //         companyCode: company,
// //         month: month,
// //       );
// //
// //       if (response.containsKey('items')) {
// //         _lastResponseData['dailyData'] = response['items'];
// //       }
// //     } catch (e) {
// //       print('Error storing daily context: $e');
// //     }
// //   }
// //
// //   String _buildDateResponse(String question, List<dynamic> dailyData) {
// //     // Support both Roman Urdu and Urdu script keywords
// //     final isPresent = question.contains('present')   ||
// //         question.contains('hazir')      ||
// //         question.contains('حاضر')        ||
// //         question.contains('hazri')      ||
// //         question.contains('حاضری');
// //
// //     final isLate    = question.contains('late')       ||
// //         question.contains('der')        ||
// //         question.contains('دیر')        ||
// //         question.contains('دیری')       ||
// //         question.contains('layt')       ||
// //         question.contains('let');
// //
// //     final isViolation = question.contains('violation')||
// //         question.contains('geo')        ||
// //         question.contains('خلاف')       ||
// //         question.contains('وائلشن')     ||
// //         question.contains('violate');
// //
// //     final isLeave   = question.contains('leave')      ||
// //         question.contains('chutti')     ||
// //         question.contains('چھٹی')       ||
// //         question.contains('chuti');
// //
// //     final isHalfDay = question.contains('half')       ||
// //         question.contains('aadha')      ||
// //         question.contains('ادھا')       ||
// //         question.contains('ادھے')       ||
// //         question.contains('halfday');
// //
// //     final data = dailyData.length > 30
// //         ? dailyData.sublist(dailyData.length - 30)
// //         : dailyData;
// //
// //     List<String> matched = [];
// //
// //     for (var day in data) {
// //       try {
// //         final status   = day['status_text']?.toString().toLowerCase() ?? '';
// //         final onLeave  = day['on_leave']?.toString().toLowerCase() == 'yes';
// //         final holiday  = day['day_type']?.toString().toLowerCase() == 'holiday';
// //         final geoV     = day['geo_violations'] ?? 0;
// //         final date     = day['work_date'] ?? '';
// //
// //         if (date.isEmpty) continue;
// //
// //         if (isPresent &&
// //             (status.contains('on time') ||
// //                 status.contains('late') ||
// //                 status == 'half day') &&
// //             !onLeave &&
// //             !holiday) {
// //           matched.add(date);
// //         } else if (isLate && status.contains('late')) {
// //           final lateTime = day['late_time']?.toString() ?? 'N/A';
// //           matched.add('$date (دیری: $lateTime)');
// //         } else if (isViolation && geoV > 0) {
// //           matched.add('$date ($geoV خلاف ورزی)');
// //         } else if (isLeave && onLeave) {
// //           matched.add(date);
// //         } else if (isHalfDay && status == 'half day') {
// //           final stay = day['total_stay']?.toString() ?? 'N/A';
// //           matched.add('$date ($stay)');
// //         }
// //       } catch (e) {
// //         print('Error processing day: $e');
// //       }
// //     }
// //
// //     if (matched.isEmpty) {
// //       if (isPresent)    return 'آپ اس مہینے کسی دن حاضر نہیں رہے۔';
// //       if (isLate)       return 'آپ اس مہینے کسی دن دیر سے نہیں آئے۔';
// //       if (isViolation)  return 'اس مہینے کوئی جگہ کی خلاف ورزی نہیں ہے۔';
// //       if (isLeave)      return 'آپ نے اس مہینے کوئی چھٹی نہیں لی۔';
// //       if (isHalfDay)    return 'اس مہینے کوئی ادھا دن نہیں ہے۔';
// //       return 'کوئی مطابق ریکارڈ نہیں ملا۔';
// //     }
// //
// //     final display = matched.length > 15 ? matched.sublist(0, 15) : matched;
// //     final suffix  = matched.length > 15
// //         ? '\n... اور ${matched.length - 15} مزید تاریخیں ہیں۔'
// //         : '';
// //
// //     String title;
// //     if (isPresent) {
// //       title = 'آپ ان تاریخوں کو حاضر رہے:';
// //     } else if (isLate) {
// //       title = 'آپ ان تاریخوں کو دیر سے آئے:';
// //     } else if (isViolation) {
// //       title = 'ان تاریخوں کو جگہ کی خلاف ورزیاں:';
// //     } else if (isLeave) {
// //       title = 'آپ نے ان تاریخوں پر چھٹی لی:';
// //     } else if (isHalfDay) {
// //       title = 'ان تاریخوں پر ادھے دن:';
// //     } else {
// //       title = 'یہ تاریخیں ملی ہیں:';
// //     }
// //
// //     return '$title\n${display.map((d) => '• $d').join('\n')}$suffix';
// //   }
// //
// //   Future<String> _fetchAndGetDates(String text) async {
// //     final reply = await router.ask(text);
// //     if (reply.contains('دن') || reply.contains('din')) {
// //       try {
// //         final empId   = await SessionHelper.getEmpId();
// //         final month   = await SessionHelper.getMonth();
// //         final company = await SessionHelper.getCompanyCode();
// //
// //         final response = await router.daily.getDaily(
// //           empId: empId,
// //           companyCode: company,
// //           month: month,
// //         );
// //
// //         final items = response['items'] as List?;
// //         if (items != null && items.isNotEmpty) {
// //           return _buildDateResponse('present dates', items);
// //         }
// //       } catch (e) {
// //         print('Error fetching dates: $e');
// //       }
// //     }
// //     return reply;
// //   }
// //
// //   // ---------------------------------------------------------------------------
// //   // Error messages (Urdu)
// //   // ---------------------------------------------------------------------------
// //
// //   String _dioErrorMessage(DioException e) {
// //     switch (e.type) {
// //       case DioExceptionType.connectionTimeout:
// //       case DioExceptionType.receiveTimeout:
// //       case DioExceptionType.sendTimeout:
// //         return 'سرور سے جواب آنے میں دیر ہو رہی ہے۔ انٹرنیٹ چیک کریں۔';
// //       case DioExceptionType.connectionError:
// //         return 'انٹرنیٹ کنیکشن چیک کریں۔';
// //       default:
// //         if (e.response?.statusCode == 401 ||
// //             e.response?.statusCode == 403) {
// //           return 'اجازت کا مسئلہ ہے۔ دوبارہ لاگ ان کریں۔';
// //         }
// //         if (e.response?.data != null) {
// //           try {
// //             final data = e.response?.data;
// //             if (data is Map && data.containsKey('message')) {
// //               return 'سرور کی خرابی: ${data['message']}';
// //             }
// //           } catch (_) {}
// //         }
// //         return 'سرور سے ڈیٹا لینے میں مسئلہ ہوا '
// //             '(حالت: ${e.response?.statusCode ?? 'کوئی کنیکشن نہیں'})۔';
// //     }
// //   }
// //
// //   // ---------------------------------------------------------------------------
// //   // Voice input - Enhanced
// //   // ---------------------------------------------------------------------------
// //
// //   Future<void> startVoiceInput() async {
// //     if (_isListening) return;
// //
// //     try {
// //       final available = await voiceService.isSpeechAvailable();
// //       if (!available) {
// //         _handleVoiceError('آواز کی پہچان اس ڈیوائس پر دستیاب نہیں ہے۔');
// //         return;
// //       }
// //
// //       _isListening     = true;
// //       _voiceTranscript = '';
// //       _voiceConfidence = 0.0;
// //       _silenceTimer?.cancel();
// //       notifyListeners();
// //
// //       print('🎤 Starting voice input…');
// //
// //       await voiceService.startListening(
// //         onResult: (text) {
// //           // Update transcript even if text is short
// //           _voiceTranscript = text;
// //           notifyListeners();
// //
// //           // Auto-send after 2.5 seconds of silence (increased for Urdu)
// //           _silenceTimer?.cancel();
// //           _silenceTimer = Timer(const Duration(milliseconds: 2500), () {
// //             if (_voiceTranscript.isNotEmpty && _isListening) {
// //               print('🔄 Auto-sending: $_voiceTranscript');
// //               final query = _voiceTranscript;
// //               _voiceTranscript = '';
// //               _isListening     = false;
// //               _silenceTimer?.cancel();
// //               _silenceTimer    = null;
// //               notifyListeners();
// //               sendMessage(query);
// //             }
// //           });
// //         },
// //         onConfidence: (score) {
// //           _voiceConfidence = score;
// //           print('📊 Confidence: ${(score * 100).toStringAsFixed(1)}%');
// //           notifyListeners();
// //         },
// //         onListening: () {
// //           print('🎤 Actively listening…');
// //         },
// //         onComplete: () {
// //           _isListening = false;
// //           _silenceTimer?.cancel();
// //           _silenceTimer = null;
// //           print('✅ Listening complete');
// //           notifyListeners();
// //         },
// //         onError: (error) => _handleVoiceError(error),
// //       );
// //     } catch (e) {
// //       print('❌ startVoiceInput error: $e');
// //       _handleVoiceError('آواز سے ان پٹ شروع نہیں ہو سکی: $e');
// //     }
// //   }
// //
// //   Future<void> stopVoiceInput() async {
// //     try {
// //       await voiceService.stopListening();
// //       _isListening = false;
// //       _silenceTimer?.cancel();
// //       _silenceTimer = null;
// //
// //       if (_voiceTranscript.isNotEmpty) {
// //         final query = _voiceTranscript;
// //         _voiceTranscript = '';
// //         notifyListeners();
// //         await sendMessage(query);
// //       }
// //
// //       notifyListeners();
// //     } catch (e) {
// //       print('❌ stopVoiceInput error: $e');
// //       _isListening = false;
// //       notifyListeners();
// //     }
// //   }
// //
// //   void _handleVoiceError(String error) {
// //     _isListening = false;
// //     _silenceTimer?.cancel();
// //     _silenceTimer = null;
// //
// //     messages.add(ChatMessage(
// //         text: _friendlyVoiceError(error), isUser: false, isError: true));
// //     notifyListeners();
// //   }
// //
// //   String _friendlyVoiceError(String error) {
// //     print('🔴 Voice error: $error');
// //     if (error.contains('permission') || error.contains('Permission')) {
// //       return 'مائیکروفون کی اجازت دیں اور دوبارہ کوشش کریں۔';
// //     } else if (error.contains('not available') ||
// //         error.contains('unavailable')) {
// //       return 'یہ ڈیوائس آواز سے ان پٹ کی سہولت نہیں دیتا۔';
// //     } else if (error.contains('network') || error.contains('Network')) {
// //       return 'انٹرنیٹ کنیکشن چیک کریں۔';
// //     } else if (error.contains('timeout') || error.contains('Timeout')) {
// //       return 'آواز سے ان پٹ کا وقت ختم ہو گیا۔ دوبارہ کوشش کریں۔';
// //     }
// //     return 'آواز سے ان پٹ میں خرابی: $error۔ دوبارہ کوشش کریں۔';
// //   }
// //
// //   // ---------------------------------------------------------------------------
// //   // TTS - Text to Speech
// //   // ---------------------------------------------------------------------------
// //
// //   Future<void> speakResponse(String text) async {
// //     try {
// //       if (_isSpeaking) {
// //         await stopSpeaking();
// //       }
// //
// //       _isSpeaking = true;
// //       notifyListeners();
// //
// //       // Clean text for TTS (remove bullets, collapse newlines)
// //       final speechText = ResponseBuilder.prepareForSpeech(text);
// //
// //       await voiceService.speak(
// //         speechText,
// //         onComplete: () {
// //           _isSpeaking = false;
// //           notifyListeners();
// //           print('✅ Speech done');
// //         },
// //         onError: (e) {
// //           _isSpeaking = false;
// //           print('❌ Speech error: $e');
// //           notifyListeners();
// //         },
// //       );
// //     } catch (e) {
// //       _isSpeaking = false;
// //       print('❌ speakResponse error: $e');
// //       notifyListeners();
// //     }
// //   }
// //
// //   Future<void> stopSpeaking() async {
// //     try {
// //       await voiceService.stopSpeaking();
// //       _isSpeaking = false;
// //       notifyListeners();
// //     } catch (e) {
// //       print('❌ stopSpeaking error: $e');
// //     }
// //   }
// //
// //   // ---------------------------------------------------------------------------
// //   // Clear chat
// //   // ---------------------------------------------------------------------------
// //
// //   void clearChat() {
// //     messages.clear();
// //     _lastResponseData = {};
// //     _lastIntent = '';
// //     _lastQuestion = '';
// //
// //     // Add welcome message again
// //     messages.add(
// //       ChatMessage(
// //         text: 'السلام علیکم! میں آپ کی حاضری کے بارے میں سوالوں کا '
// //             'جواب دے سکتا ہوں۔ آپ پوچھ سکتے ہیں:\n'
// //             '• کتنے دن حاضر رہے؟\n'
// //             '• کس کس تاریخ کو حاضر تھے؟\n'
// //             '• کتنی دیر ہوئی؟\n'
// //             '• کس تاریخ کو دیر سے آئے؟\n'
// //             '• کتنے گھنٹے کام کیا؟\n'
// //             '• کوئی خلاف ورزی ہے؟\n\n'
// //             'آواز سے پوچھنے کے لیے مائیک بٹن دبائیں۔',
// //         isUser: false,
// //       ),
// //     );
// //     notifyListeners();
// //   }
// //
// //   // ---------------------------------------------------------------------------
// //   // Getters
// //   // ---------------------------------------------------------------------------
// //
// //   bool   get isListening      => _isListening;
// //   bool   get isSpeaking       => _isSpeaking;
// //   String get voiceTranscript  => _voiceTranscript;
// //   double get voiceConfidence  => _voiceConfidence;
// //   bool   get isVoiceAvailable => _isVoiceAvailable;
// //
// //   @override
// //   void dispose() {
// //     _silenceTimer?.cancel();
// //     voiceService.dispose();
// //     super.dispose();
// //   }
// // }
//
// ///both language
// import 'package:GPS_Workforce_Monitor/chatbot/core/response_builder.dart';
// import 'package:flutter/foundation.dart';
// import 'package:dio/dio.dart';
// import 'dart:async';
//
// import '../core/api_router.dart';
// import '../models/chat_message.dart';
// import '../services/voice_service.dart';
// import '../session_helper.dart';
//
// class ChatController extends ChangeNotifier {
//   final ApiRouter router;
//   final VoiceService voiceService = VoiceService();
//
//   final List<ChatMessage> messages = [];
//
//   bool isTyping = false;
//   bool _isListening = false;
//   bool _isSpeaking = false;
//   String _voiceTranscript = '';
//   double _voiceConfidence = 0.0;
//   bool _isVoiceAvailable = false;
//
//   Timer? _silenceTimer;
//
//   Map<String, dynamic> _lastResponseData = {};
//   String _lastIntent = '';
//   String _lastQuestion = '';
//
//   // Track which message is speaking
//   int? _speakingMessageIndex;
//   // Track which language is speaking (0 = Urdu, 1 = English)
//   int? _speakingLanguageIndex;
//
//   // Store selected language for each message
//   Map<int, String> _messageLanguage = {};
//
//   // Pending query waiting for language selection
//   String? _pendingQuery;
//   bool _waitingForLanguage = false;
//
//   // Response cache for bilingual support
//   Map<int, Map<String, String>> _responseCache = {};
//
//   // ---------------------------------------------------------------------------
//   // Constructor
//   // ---------------------------------------------------------------------------
//
//   ChatController(this.router) {
//     _initializeVoice();
//     messages.add(
//       ChatMessage(
//         text: 'السلام علیکم! میں آپ کی حاضری کے بارے میں سوالوں کا '
//             'جواب دے سکتا ہوں۔ آپ پوچھ سکتے ہیں:\n'
//             '• کتنے دن حاضر رہے؟\n'
//             '• کس کس تاریخ کو حاضر تھے؟\n'
//             '• کتنی دیر ہوئی؟\n'
//             '• کس تاریخ کو دیر سے آئے؟\n'
//             '• کتنے گھنٹے کام کیا؟\n'
//             '• کوئی خلاف ورزی ہے؟\n\n'
//             'آواز سے پوچھنے کے لیے مائیک بٹن دبائیں۔',
//         isUser: false,
//       ),
//     );
//   }
//
//   // ---------------------------------------------------------------------------
//   // Voice initialization
//   // ---------------------------------------------------------------------------
//
//   Future<void> _initializeVoice() async {
//     try {
//       _isVoiceAvailable = await voiceService.isSpeechAvailable();
//       print('🎤 Voice available: $_isVoiceAvailable');
//       notifyListeners();
//     } catch (e) {
//       print('❌ Voice init error: $e');
//       _isVoiceAvailable = false;
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // Send message with language selection
//   // ---------------------------------------------------------------------------
//
//   Future<void> sendMessage(String text) async {
//     final trimmed = text.trim();
//     if (trimmed.isEmpty) return;
//
//     // Stop voice input if listening
//     if (_isListening) await stopVoiceInput();
//
//     // Add user message
//     messages.add(ChatMessage(text: trimmed, isUser: true));
//     isTyping = true;
//     notifyListeners();
//
//     // Show language selector
//     _pendingQuery = trimmed;
//     _waitingForLanguage = true;
//     isTyping = false;
//
//     messages.add(
//       ChatMessage(
//         text: 'Select Language / زبان منتخب کریں:',
//         isUser: false,
//         isLanguageSelector: true,
//         query: trimmed,
//       ),
//     );
//
//     notifyListeners();
//   }
//
//   // ---------------------------------------------------------------------------
//   // Handle language selection
//   // ---------------------------------------------------------------------------
//
//   // Update the selectLanguage method to store both Urdu and English separately
//   Future<void> selectLanguage(String language, String query) async {
//     _waitingForLanguage = false;
//     _pendingQuery = null;
//
//     if (messages.isNotEmpty && messages.last.isLanguageSelector) {
//       messages.removeLast();
//     }
//     notifyListeners();
//
//     final langLabel = language == 'urdu' ? '🇵🇰 اردو' : '🇬🇧 English';
//     messages.add(
//       ChatMessage(
//         text: '→ $langLabel',
//         isUser: false,
//       ),
//     );
//
//     isTyping = true;
//     notifyListeners();
//
//     try {
//       final reply = await _getResponse(query, language);
//
//       final messageIndex = messages.length;
//       _messageLanguage[messageIndex] = language;
//
//       // Parse bilingual response
//       String urduText = reply;
//       String englishText = reply;
//
//       if (reply.contains('---')) {
//         final parts = reply.split('---');
//         if (parts.length >= 2) {
//           urduText = parts[0].trim();
//           englishText = parts[1].trim();
//         }
//       }
//
//       _responseCache[messageIndex] = {
//         'urdu': urduText,
//         'english': englishText,
//       };
//
//       final displayText = language == 'urdu' ? urduText : englishText;
//
//       messages.add(ChatMessage(
//         text: displayText,
//         isUser: false,
//         messageIndex: messageIndex,
//       ));
//
//       notifyListeners();
//     } on DioException catch (e) {
//       messages.add(ChatMessage(
//         text: _dioErrorMessage(e),
//         isUser: false,
//         isError: true,
//       ));
//       notifyListeners();
//     } catch (e) {
//       messages.add(ChatMessage(
//         text: 'معذرت، کچھ غلط ہو گیا۔ خرابی: ${e.toString()}',
//         isUser: false,
//         isError: true,
//       ));
//       notifyListeners();
//     }
//
//     isTyping = false;
//     notifyListeners();
//   }
//
//   // ---------------------------------------------------------------------------
//   // Get response with language context
//   // ---------------------------------------------------------------------------
//
//   Future<String> _getResponse(String query, String language) async {
//     final reply = await router.ask(query);
//
//     // Cache daily context for follow-up
//     final replyLower = reply.toLowerCase();
//     if (replyLower.contains('دن') || replyLower.contains('din') ||
//         replyLower.contains('گھنٹے') || replyLower.contains('hours')) {
//       _lastQuestion = query;
//       await _storeDailyContext();
//     }
//
//     return reply;
//   }
//
//   // ---------------------------------------------------------------------------
//   // Speak response in specific language
//   // ---------------------------------------------------------------------------
//
//   Future<void> speakResponse(String text, [String? language]) async {
//     try {
//       if (_isSpeaking) {
//         await stopSpeaking();
//       }
//
//       // Set language for TTS
//       if (language == 'urdu') {
//         await voiceService.setLanguage('ur-PK');
//       } else {
//         await voiceService.setLanguage('en-US');
//       }
//
//       _isSpeaking = true;
//       notifyListeners();
//
//       // Clean text for TTS
//       final speechText = ResponseBuilder.prepareForSpeech(text);
//
//       await voiceService.speak(
//         speechText,
//         onComplete: () {
//           _isSpeaking = false;
//           _speakingMessageIndex = null;
//           _speakingLanguageIndex = null;
//           notifyListeners();
//           print('✅ Speech done');
//         },
//         onError: (e) {
//           _isSpeaking = false;
//           _speakingMessageIndex = null;
//           _speakingLanguageIndex = null;
//           print('❌ Speech error: $e');
//           notifyListeners();
//         },
//       );
//     } catch (e) {
//       _isSpeaking = false;
//       _speakingMessageIndex = null;
//       _speakingLanguageIndex = null;
//       print('❌ speakResponse error: $e');
//       notifyListeners();
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // Toggle speak for a specific message
//   // ---------------------------------------------------------------------------
//
//   Future<void> toggleSpeak(int messageIndex, String text, String language) async {
//     if (_speakingMessageIndex == messageIndex && _isSpeaking) {
//       // Stop if currently speaking this message
//       await stopSpeaking();
//       _speakingMessageIndex = null;
//       _speakingLanguageIndex = null;
//       notifyListeners();
//       return;
//     }
//
//     // Stop any ongoing speech
//     if (_isSpeaking) {
//       await stopSpeaking();
//     }
//
//     // Start speaking this message
//     _speakingMessageIndex = messageIndex;
//     _speakingLanguageIndex = language == 'urdu' ? 0 : 1;
//     notifyListeners();
//
//     // Set language for TTS
//     if (language == 'urdu') {
//       await voiceService.setLanguage('ur-PK');
//     } else {
//       await voiceService.setLanguage('en-US');
//     }
//
//     final speechText = ResponseBuilder.prepareForSpeech(text);
//
//     await voiceService.speak(
//       speechText,
//       onComplete: () {
//         _speakingMessageIndex = null;
//         _speakingLanguageIndex = null;
//         notifyListeners();
//       },
//       onError: (e) {
//         _speakingMessageIndex = null;
//         _speakingLanguageIndex = null;
//         notifyListeners();
//       },
//     );
//   }
//
//   // ---------------------------------------------------------------------------
//   // Stop speaking
//   // ---------------------------------------------------------------------------
//
//   Future<void> stopSpeaking() async {
//     try {
//       await voiceService.stopSpeaking();
//       _isSpeaking = false;
//       _speakingMessageIndex = null;
//       _speakingLanguageIndex = null;
//       notifyListeners();
//     } catch (e) {
//       print('❌ stopSpeaking error: $e');
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // Voice input
//   // ---------------------------------------------------------------------------
//
//   Future<void> startVoiceInput() async {
//     if (_isListening) return;
//
//     try {
//       final available = await voiceService.isSpeechAvailable();
//       if (!available) {
//         _handleVoiceError('آواز کی پہچان اس ڈیوائس پر دستیاب نہیں ہے۔');
//         return;
//       }
//
//       _isListening = true;
//       _voiceTranscript = '';
//       _voiceConfidence = 0.0;
//       _silenceTimer?.cancel();
//       notifyListeners();
//
//       print('🎤 Starting voice input…');
//
//       await voiceService.startListening(
//         onResult: (text) {
//           _voiceTranscript = text;
//           notifyListeners();
//
//           _silenceTimer?.cancel();
//           _silenceTimer = Timer(const Duration(milliseconds: 2500), () {
//             if (_voiceTranscript.isNotEmpty && _isListening) {
//               print('🔄 Auto-sending: $_voiceTranscript');
//               final query = _voiceTranscript;
//               _voiceTranscript = '';
//               _isListening = false;
//               _silenceTimer?.cancel();
//               _silenceTimer = null;
//               notifyListeners();
//               sendMessage(query);
//             }
//           });
//         },
//         onConfidence: (score) {
//           _voiceConfidence = score;
//           notifyListeners();
//         },
//         onListening: () {
//           print('🎤 Actively listening…');
//         },
//         onComplete: () {
//           _isListening = false;
//           _silenceTimer?.cancel();
//           _silenceTimer = null;
//           print('✅ Listening complete');
//           notifyListeners();
//         },
//         onError: (error) => _handleVoiceError(error),
//       );
//     } catch (e) {
//       print('❌ startVoiceInput error: $e');
//       _handleVoiceError('آواز سے ان پٹ شروع نہیں ہو سکی: $e');
//     }
//   }
//
//   Future<void> stopVoiceInput() async {
//     try {
//       await voiceService.stopListening();
//       _isListening = false;
//       _silenceTimer?.cancel();
//       _silenceTimer = null;
//
//       if (_voiceTranscript.isNotEmpty) {
//         final query = _voiceTranscript;
//         _voiceTranscript = '';
//         notifyListeners();
//         await sendMessage(query);
//       }
//
//       notifyListeners();
//     } catch (e) {
//       print('❌ stopVoiceInput error: $e');
//       _isListening = false;
//       notifyListeners();
//     }
//   }
//
//   void _handleVoiceError(String error) {
//     _isListening = false;
//     _silenceTimer?.cancel();
//     _silenceTimer = null;
//
//     messages.add(ChatMessage(
//       text: _friendlyVoiceError(error),
//       isUser: false,
//       isError: true,
//     ));
//     notifyListeners();
//   }
//
//   String _friendlyVoiceError(String error) {
//     print('🔴 Voice error: $error');
//     if (error.contains('permission') || error.contains('Permission')) {
//       return 'مائیکروفون کی اجازت دیں اور دوبارہ کوشش کریں۔';
//     } else if (error.contains('not available') || error.contains('unavailable')) {
//       return 'یہ ڈیوائس آواز سے ان پٹ کی سہولت نہیں دیتا۔';
//     } else if (error.contains('network') || error.contains('Network')) {
//       return 'انٹرنیٹ کنیکشن چیک کریں۔';
//     } else if (error.contains('timeout') || error.contains('Timeout')) {
//       return 'آواز سے ان پٹ کا وقت ختم ہو گیا۔ دوبارہ کوشش کریں۔';
//     }
//     return 'آواز سے ان پٹ میں خرابی: $error۔ دوبارہ کوشش کریں۔';
//   }
//
//   // ---------------------------------------------------------------------------
//   // Store daily context
//   // ---------------------------------------------------------------------------
//
//   Future<void> _storeDailyContext() async {
//     try {
//       final empId = await SessionHelper.getEmpId();
//       final month = await SessionHelper.getMonth();
//       final company = await SessionHelper.getCompanyCode();
//
//       final response = await router.daily.getDaily(
//         empId: empId,
//         companyCode: company,
//         month: month,
//       );
//
//       if (response.containsKey('items')) {
//         _lastResponseData['dailyData'] = response['items'];
//       }
//     } catch (e) {
//       print('Error storing daily context: $e');
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // Error messages
//   // ---------------------------------------------------------------------------
//
//   String _dioErrorMessage(DioException e) {
//     switch (e.type) {
//       case DioExceptionType.connectionTimeout:
//       case DioExceptionType.receiveTimeout:
//       case DioExceptionType.sendTimeout:
//         return 'سرور سے جواب آنے میں دیر ہو رہی ہے۔ انٹرنیٹ چیک کریں۔';
//       case DioExceptionType.connectionError:
//         return 'انٹرنیٹ کنیکشن چیک کریں۔';
//       default:
//         if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
//           return 'اجازت کا مسئلہ ہے۔ دوبارہ لاگ ان کریں۔';
//         }
//         if (e.response?.data != null) {
//           try {
//             final data = e.response?.data;
//             if (data is Map && data.containsKey('message')) {
//               return 'سرور کی خرابی: ${data['message']}';
//             }
//           } catch (_) {}
//         }
//         return 'سرور سے ڈیٹا لینے میں مسئلہ ہوا '
//             '(حالت: ${e.response?.statusCode ?? 'کوئی کنیکشن نہیں'})۔';
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // Clear chat
//   // ---------------------------------------------------------------------------
//
//   void clearChat() {
//     messages.clear();
//     _lastResponseData = {};
//     _lastIntent = '';
//     _lastQuestion = '';
//     _responseCache = {};
//     _messageLanguage = {};
//     _speakingMessageIndex = null;
//     _speakingLanguageIndex = null;
//     _pendingQuery = null;
//     _waitingForLanguage = false;
//
//     messages.add(
//       ChatMessage(
//         text: 'السلام علیکم! میں آپ کی حاضری کے بارے میں سوالوں کا '
//             'جواب دے سکتا ہوں۔ آپ پوچھ سکتے ہیں:\n'
//             '• کتنے دن حاضر رہے؟\n'
//             '• کس کس تاریخ کو حاضر تھے؟\n'
//             '• کتنی دیر ہوئی؟\n'
//             '• کس تاریخ کو دیر سے آئے؟\n'
//             '• کتنے گھنٹے کام کیا؟\n'
//             '• کوئی خلاف ورزی ہے؟\n\n'
//             'آواز سے پوچھنے کے لیے مائیک بٹن دبائیں۔',
//         isUser: false,
//       ),
//     );
//     notifyListeners();
//   }
//
//   // ---------------------------------------------------------------------------
//   // Getters
//   // ---------------------------------------------------------------------------
//
//   bool get isListening => _isListening;
//   bool get isSpeaking => _isSpeaking;
//   String get voiceTranscript => _voiceTranscript;
//   double get voiceConfidence => _voiceConfidence;
//   bool get isVoiceAvailable => _isVoiceAvailable;
//   bool get waitingForLanguage => _waitingForLanguage;
//   String? get pendingQuery => _pendingQuery;
//
//   String? getLanguageForMessage(int index) {
//     return _messageLanguage[index];
//   }
//
//   Map<String, String>? getResponseForMessage(int index) {
//     return _responseCache[index];
//   }
//
//   bool isMessageSpeaking(int index) {
//     return _speakingMessageIndex == index && _isSpeaking;
//   }
//
//   @override
//   void dispose() {
//     _silenceTimer?.cancel();
//     voiceService.dispose();
//     super.dispose();
//   }
// }

import 'package:GPS_Workforce_Monitor/chatbot/core/response_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'dart:async';

import '../core/api_router.dart';
import '../models/chat_message.dart';
import '../services/voice_service.dart';
import '../session_helper.dart';

class ChatController extends ChangeNotifier {
  final ApiRouter router;
  final VoiceService voiceService = VoiceService();

  final List<ChatMessage> messages = [];

  bool isTyping = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _voiceTranscript = '';
  double _voiceConfidence = 0.0;
  bool _isVoiceAvailable = false;

  Timer? _silenceTimer;

  Map<String, dynamic> _lastResponseData = {};
  String _lastIntent = '';
  String _lastQuestion = '';

  int? _speakingMessageIndex;
  int? _speakingLanguageIndex;

  Map<int, String> _messageLanguage = {};

  String? _pendingQuery;
  bool _waitingForLanguage = false;

  Map<int, Map<String, String>> _responseCache = {};

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  ChatController(this.router) {
    _initializeVoice();
    messages.add(
      ChatMessage(
        text: 'السلام علیکم! میں آپ کی حاضری کے بارے میں سوالوں کا '
            'جواب دے سکتا ہوں۔ آپ پوچھ سکتے ہیں:\n'
            '• کتنے دن حاضر رہے؟\n'
            '• کس کس تاریخ کو حاضر تھے؟\n'
            '• کتنی دیر ہوئی؟\n'
            '• کس تاریخ کو دیر سے آئے؟\n'
            '• کتنے گھنٹے کام کیا؟\n'
            '• کوئی خلاف ورزی ہے؟\n\n'
            'آواز سے پوچھنے کے لیے مائیک بٹن دبائیں۔',
        isUser: false,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Voice initialization
  // ---------------------------------------------------------------------------

  Future<void> _initializeVoice() async {
    try {
      _isVoiceAvailable = await voiceService.isSpeechAvailable();
      print('🎤 Voice available: $_isVoiceAvailable');
      notifyListeners();
    } catch (e) {
      print('❌ Voice init error: $e');
      _isVoiceAvailable = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Send message — shows language selector
  // ---------------------------------------------------------------------------

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (_isListening) await stopVoiceInput();

    messages.add(ChatMessage(text: trimmed, isUser: true));
    isTyping = true;
    notifyListeners();

    _pendingQuery = trimmed;
    _waitingForLanguage = true;
    isTyping = false;

    messages.add(
      ChatMessage(
        text: 'Select Language / زبان منتخب کریں:',
        isUser: false,
        isLanguageSelector: true,
        query: trimmed,
      ),
    );

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Handle language selection
  //
  // FIX 1: The "→ 🇵🇰 اردو" confirmation bubble is now marked with
  //         isLanguageConfirmation = true so the screen hides it silently.
  //         Users see: [their message] → [language buttons] → [answer]
  //
  // FIX 2: After the answer we attach contextual follow-up suggestions
  //         based on what the user asked, so they can drill deeper in one tap.
  // ---------------------------------------------------------------------------

  Future<void> selectLanguage(String language, String query) async {
    _waitingForLanguage = false;
    _pendingQuery = null;

    // Remove language selector bubble
    if (messages.isNotEmpty && messages.last.isLanguageSelector) {
      messages.removeLast();
    }
    notifyListeners();

    // FIX 1: Add confirmation bubble but marked as hidden
    messages.add(
      ChatMessage(
        text: language == 'urdu' ? '🇵🇰 اردو' : '🇬🇧 English',
        isUser: false,
        isLanguageConfirmation: true, // screen will render SizedBox.shrink()
      ),
    );

    isTyping = true;
    notifyListeners();

    try {
      final reply = await _getResponse(query, language);

      final messageIndex = messages.length;
      _messageLanguage[messageIndex] = language;

      String urduText = reply;
      String englishText = reply;

      if (reply.contains('---')) {
        final parts = reply.split('---');
        if (parts.length >= 2) {
          urduText = parts[0].trim();
          englishText = parts[1].trim();
        }
      }

      _responseCache[messageIndex] = {
        'urdu': urduText,
        'english': englishText,
      };

      final displayText = language == 'urdu' ? urduText : englishText;

      // FIX 2: Build follow-up suggestions based on the user's question
      final suggestions = _buildSuggestions(query, language);

      messages.add(ChatMessage(
        text: displayText,
        isUser: false,
        messageIndex: messageIndex,
        suggestions: suggestions.isNotEmpty ? suggestions : null,
      ));

      notifyListeners();
    } on DioException catch (e) {
      messages.add(ChatMessage(
        text: _dioErrorMessage(e),
        isUser: false,
        isError: true,
      ));
      notifyListeners();
    } catch (e) {
      messages.add(ChatMessage(
        text: 'معذرت، کچھ غلط ہو گیا۔ خرابی: ${e.toString()}',
        isUser: false,
        isError: true,
      ));
      notifyListeners();
    }

    isTyping = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Build contextual follow-up suggestions
  //
  // Returns 2-3 short queries the user is likely to ask next, based on what
  // they just asked.  Keeps them concise so they fit on chips.
  // ---------------------------------------------------------------------------

  List<String> _buildSuggestions(String query, String language) {
    final q = query.toLowerCase();

    final isUrdu = language == 'urdu';

    // Helper to pick language variant
    String s(String urdu, String english) => isUrdu ? urdu : english;

    // Attendance summary → suggest present / late / hours
    if (q.contains('summary') ||
        q.contains('attendance') ||
        q.contains('haziri') ||
        q.contains('حاضری') ||
        q.contains('report')) {
      return [
        s('کتنے دن حاضر رہے؟', 'How many days present?'),
        s('کتنی دیر ہوئی؟', 'How many late arrivals?'),
        s('کتنے گھنٹے کام کیا؟', 'Total working hours?'),
      ];
    }

    // Present days → suggest present dates / late info
    if (q.contains('present') ||
        q.contains('hazir') ||
        q.contains('حاضر')) {
      return [
        s('کس کس تاریخ کو حاضر تھے؟', 'Which dates was I present?'),
        s('کتنی دیر ہوئی؟', 'How many times was I late?'),
        s('کتنی چھٹیاں لیں؟', 'How many leaves did I take?'),
      ];
    }

    // Late → suggest late dates / on time info
    if (q.contains('late') ||
        q.contains('دیر') ||
        q.contains('der')) {
      return [
        s('کس تاریخ کو دیر ہوئی؟', 'Which dates was I late?'),
        s('کتنے دن وقت پر آیا؟', 'How many days on time?'),
        s('کتنے گھنٹے کام کیا؟', 'Total working hours?'),
      ];
    }

    // Working hours → suggest daily breakdown / early exit
    if (q.contains('hour') ||
        q.contains('ghante') ||
        q.contains('گھنٹے') ||
        q.contains('working')) {
      return [
        s('روزانہ کتنے گھنٹے؟', 'Daily working hours breakdown?'),
        s('کتنے دن جلدی گئے؟', 'How many early exits?'),
        s('کتنی دیر ہوئی؟', 'How many late arrivals?'),
      ];
    }

    // Geo violations → suggest violation dates
    if (q.contains('geo') ||
        q.contains('violation') ||
        q.contains('location')) {
      return [
        s('کس تاریخ کو خلاف ورزی ہوئی؟', 'Which dates had violations?'),
        s('کتنے آف لائن واقعات ہیں؟', 'How many offline events?'),
        s('حاضری کا خلاصہ دکھاؤ', 'Show attendance summary'),
      ];
    }

    // Leave → suggest leave dates
    if (q.contains('leave') ||
        q.contains('chutti') ||
        q.contains('چھٹی')) {
      return [
        s('کس تاریخ کو چھٹی تھی؟', 'Which dates was I on leave?'),
        s('کتنے دن حاضر رہے؟', 'How many days was I present?'),
        s('کتنی دیر ہوئی؟', 'How many late arrivals?'),
      ];
    }

    // Half days
    if (q.contains('half') || q.contains('adha') || q.contains('آدھا')) {
      return [
        s('کس تاریخ کو آدھا دن تھا؟', 'Which dates were half days?'),
        s('کتنے دن حاضر رہے؟', 'How many full days present?'),
        s('کتنے گھنٹے کام کیا؟', 'Total working hours?'),
      ];
    }

    // Early exit
    if (q.contains('early') || q.contains('jaldi') || q.contains('جلدی')) {
      return [
        s('کس تاریخ کو جلدی گئے؟', 'Which dates did I leave early?'),
        s('کتنے گھنٹے کام کیا؟', 'Total working hours?'),
        s('حاضری کا خلاصہ دکھاؤ', 'Show attendance summary'),
      ];
    }

    // Default — show generic suggestions
    return [
      s('حاضری کا خلاصہ دکھاؤ', 'Show attendance summary'),
      s('کتنی دیر ہوئی؟', 'How many late arrivals?'),
      s('کتنے گھنٹے کام کیا؟', 'Total working hours?'),
    ];
  }

  // ---------------------------------------------------------------------------
  // Get response with language context
  // ---------------------------------------------------------------------------

  Future<String> _getResponse(String query, String language) async {
    final reply = await router.ask(query);

    final replyLower = reply.toLowerCase();
    if (replyLower.contains('دن') ||
        replyLower.contains('din') ||
        replyLower.contains('گھنٹے') ||
        replyLower.contains('hours')) {
      _lastQuestion = query;
      await _storeDailyContext();
    }

    return reply;
  }

  // ---------------------------------------------------------------------------
  // Speak response in specific language
  // ---------------------------------------------------------------------------

  Future<void> speakResponse(String text, [String? language]) async {
    try {
      if (_isSpeaking) await stopSpeaking();

      if (language == 'urdu') {
        await voiceService.setLanguage('ur-PK');
      } else {
        await voiceService.setLanguage('en-US');
      }

      _isSpeaking = true;
      notifyListeners();

      final speechText = ResponseBuilder.prepareForSpeech(text);

      await voiceService.speak(
        speechText,
        onComplete: () {
          _isSpeaking = false;
          _speakingMessageIndex = null;
          _speakingLanguageIndex = null;
          notifyListeners();
          print('✅ Speech done');
        },
        onError: (e) {
          _isSpeaking = false;
          _speakingMessageIndex = null;
          _speakingLanguageIndex = null;
          print('❌ Speech error: $e');
          notifyListeners();
        },
      );
    } catch (e) {
      _isSpeaking = false;
      _speakingMessageIndex = null;
      _speakingLanguageIndex = null;
      print('❌ speakResponse error: $e');
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Toggle speak for a specific message
  // ---------------------------------------------------------------------------

  Future<void> toggleSpeak(
      int messageIndex, String text, String language) async {
    if (_speakingMessageIndex == messageIndex && _isSpeaking) {
      await stopSpeaking();
      _speakingMessageIndex = null;
      _speakingLanguageIndex = null;
      notifyListeners();
      return;
    }

    if (_isSpeaking) await stopSpeaking();

    _speakingMessageIndex = messageIndex;
    _speakingLanguageIndex = language == 'urdu' ? 0 : 1;
    notifyListeners();

    if (language == 'urdu') {
      await voiceService.setLanguage('ur-PK');
    } else {
      await voiceService.setLanguage('en-US');
    }

    final speechText = ResponseBuilder.prepareForSpeech(text);

    await voiceService.speak(
      speechText,
      onComplete: () {
        _speakingMessageIndex = null;
        _speakingLanguageIndex = null;
        notifyListeners();
      },
      onError: (e) {
        _speakingMessageIndex = null;
        _speakingLanguageIndex = null;
        notifyListeners();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Stop speaking
  // ---------------------------------------------------------------------------

  Future<void> stopSpeaking() async {
    try {
      await voiceService.stopSpeaking();
      _isSpeaking = false;
      _speakingMessageIndex = null;
      _speakingLanguageIndex = null;
      notifyListeners();
    } catch (e) {
      print('❌ stopSpeaking error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Voice input
  // ---------------------------------------------------------------------------

  Future<void> startVoiceInput() async {
    if (_isListening) return;

    try {
      final available = await voiceService.isSpeechAvailable();
      if (!available) {
        _handleVoiceError('آواز کی پہچان اس ڈیوائس پر دستیاب نہیں ہے۔');
        return;
      }

      _isListening = true;
      _voiceTranscript = '';
      _voiceConfidence = 0.0;
      _silenceTimer?.cancel();
      notifyListeners();

      print('🎤 Starting voice input…');

      await voiceService.startListening(
        onResult: (text) {
          _voiceTranscript = text;
          notifyListeners();

          _silenceTimer?.cancel();
          _silenceTimer = Timer(const Duration(milliseconds: 2500), () {
            if (_voiceTranscript.isNotEmpty && _isListening) {
              print('🔄 Auto-sending: $_voiceTranscript');
              final query = _voiceTranscript;
              _voiceTranscript = '';
              _isListening = false;
              _silenceTimer?.cancel();
              _silenceTimer = null;
              notifyListeners();
              sendMessage(query);
            }
          });
        },
        onConfidence: (score) {
          _voiceConfidence = score;
          notifyListeners();
        },
        onListening: () {
          print('🎤 Actively listening…');
        },
        onComplete: () {
          _isListening = false;
          _silenceTimer?.cancel();
          _silenceTimer = null;
          print('✅ Listening complete');
          notifyListeners();
        },
        onError: (error) => _handleVoiceError(error),
      );
    } catch (e) {
      print('❌ startVoiceInput error: $e');
      _handleVoiceError('آواز سے ان پٹ شروع نہیں ہو سکی: $e');
    }
  }

  Future<void> stopVoiceInput() async {
    try {
      await voiceService.stopListening();
      _isListening = false;
      _silenceTimer?.cancel();
      _silenceTimer = null;

      if (_voiceTranscript.isNotEmpty) {
        final query = _voiceTranscript;
        _voiceTranscript = '';
        notifyListeners();
        await sendMessage(query);
      }

      notifyListeners();
    } catch (e) {
      print('❌ stopVoiceInput error: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  void _handleVoiceError(String error) {
    _isListening = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;

    messages.add(ChatMessage(
      text: _friendlyVoiceError(error),
      isUser: false,
      isError: true,
    ));
    notifyListeners();
  }

  String _friendlyVoiceError(String error) {
    print('🔴 Voice error: $error');
    if (error.contains('permission') || error.contains('Permission')) {
      return 'مائیکروفون کی اجازت دیں اور دوبارہ کوشش کریں۔';
    } else if (error.contains('not available') ||
        error.contains('unavailable')) {
      return 'یہ ڈیوائس آواز سے ان پٹ کی سہولت نہیں دیتا۔';
    } else if (error.contains('network') || error.contains('Network')) {
      return 'انٹرنیٹ کنیکشن چیک کریں۔';
    } else if (error.contains('timeout') || error.contains('Timeout')) {
      return 'آواز سے ان پٹ کا وقت ختم ہو گیا۔ دوبارہ کوشش کریں۔';
    }
    return 'آواز سے ان پٹ میں خرابی: $error۔ دوبارہ کوشش کریں۔';
  }

  // ---------------------------------------------------------------------------
  // Store daily context for follow-up questions
  // ---------------------------------------------------------------------------

  Future<void> _storeDailyContext() async {
    try {
      final empId = await SessionHelper.getEmpId();
      final month = await SessionHelper.getMonth();
      final company = await SessionHelper.getCompanyCode();

      final response = await router.daily.getDaily(
        empId: empId,
        companyCode: company,
        month: month,
      );

      if (response.containsKey('items')) {
        _lastResponseData['dailyData'] = response['items'];
      }
    } catch (e) {
      print('Error storing daily context: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Dio error messages
  // ---------------------------------------------------------------------------

  String _dioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'سرور سے جواب آنے میں دیر ہو رہی ہے۔ انٹرنیٹ چیک کریں۔';
      case DioExceptionType.connectionError:
        return 'انٹرنیٹ کنیکشن چیک کریں۔';
      default:
        if (e.response?.statusCode == 401 ||
            e.response?.statusCode == 403) {
          return 'اجازت کا مسئلہ ہے۔ دوبارہ لاگ ان کریں۔';
        }
        if (e.response?.data != null) {
          try {
            final data = e.response?.data;
            if (data is Map && data.containsKey('message')) {
              return 'سرور کی خرابی: ${data['message']}';
            }
          } catch (_) {}
        }
        return 'سرور سے ڈیٹا لینے میں مسئلہ ہوا '
            '(حالت: ${e.response?.statusCode ?? 'کوئی کنیکشن نہیں'})۔';
    }
  }

  // ---------------------------------------------------------------------------
  // Clear chat
  // ---------------------------------------------------------------------------

  void clearChat() {
    messages.clear();
    _lastResponseData = {};
    _lastIntent = '';
    _lastQuestion = '';
    _responseCache = {};
    _messageLanguage = {};
    _speakingMessageIndex = null;
    _speakingLanguageIndex = null;
    _pendingQuery = null;
    _waitingForLanguage = false;

    messages.add(
      ChatMessage(
        text: 'السلام علیکم! میں آپ کی حاضری کے بارے میں سوالوں کا '
            'جواب دے سکتا ہوں۔ آپ پوچھ سکتے ہیں:\n'
            '• کتنے دن حاضر رہے؟\n'
            '• کس کس تاریخ کو حاضر تھے؟\n'
            '• کتنی دیر ہوئی؟\n'
            '• کس تاریخ کو دیر سے آئے؟\n'
            '• کتنے گھنٹے کام کیا؟\n'
            '• کوئی خلاف ورزی ہے؟\n\n'
            'آواز سے پوچھنے کے لیے مائیک بٹن دبائیں۔',
        isUser: false,
      ),
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  String get voiceTranscript => _voiceTranscript;
  double get voiceConfidence => _voiceConfidence;
  bool get isVoiceAvailable => _isVoiceAvailable;
  bool get waitingForLanguage => _waitingForLanguage;
  String? get pendingQuery => _pendingQuery;

  String? getLanguageForMessage(int index) => _messageLanguage[index];

  Map<String, String>? getResponseForMessage(int index) =>
      _responseCache[index];

  bool isMessageSpeaking(int index) =>
      _speakingMessageIndex == index && _isSpeaking;

  @override
  void dispose() {
    _silenceTimer?.cancel();
    voiceService.dispose();
    super.dispose();
  }
}