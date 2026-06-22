// import 'package:flutter/foundation.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:flutter_tts/flutter_tts.dart';
//
// class VoiceService {
//   final stt.SpeechToText _speech = stt.SpeechToText();
//   final FlutterTts _tts = FlutterTts();
//
//   bool _isListening = false;
//   bool _isSpeaking = false;
//   String _lastRecognizedText = '';
//   double _lastConfidence = 0.0;
//
//   List<String> _recognitionHistory = [];
//   final int _maxHistoryLength = 5;
//   int _silenceCounter = 0;
//   final int _maxSilenceCount = 8;
//
//   static const List<String> _urduLocales = ['ur-PK', 'ur-IN', 'ur', 'hi-IN'];
//   String _activeLocale = 'ur-PK';
//
//   // ---------------------------------------------------------------------------
//   // Urdu to Roman mapping
//   // ---------------------------------------------------------------------------
//   static final Map<String, String> _urduToRomanMap = {
//     'حاضر': 'present hazir',
//     'حاضری': 'attendance haziri',
//     'حاضرین': 'present',
//     'حاضر رہے': 'present',
//     'دیر سے': 'late der',
//     'دیری': 'late der',
//     'دیر': 'der late',
//     'دیر آئے': 'late',
//     'دیر سے آئے': 'late',
//     'لیٹ': 'late',
//     'وقت پر': 'on time waqt',
//     'ٹائم پر': 'on time',
//     'وقت سے': 'on time',
//     'جلدی گیا': 'early exit jaldi',
//     'جلدی گئے': 'early exit jaldi',
//     'جلدی': 'jaldi early',
//     'جلدی نکلے': 'early exit',
//     'جلدی چلے': 'early exit',
//     'چھٹی': 'leave chutti',
//     'چھٹی لی': 'leave',
//     'لیو': 'leave',
//     'ادھا دن': 'half day aadha',
//     'ادھے دن': 'half day aadhe',
//     'ادھا': 'half aadha',
//     'ہاف ڈے': 'half day',
//     'گھنٹے': 'hours ghante',
//     'کام کے گھنٹے': 'working hours',
//     'ورکنگ آورز': 'working hours',
//     'گھنٹا': 'hours',
//     'خلاف ورزی': 'violation geo',
//     'خلاف': 'violation',
//     'وائلشن': 'violation',
//     'جیو': 'geo violation',
//     'جیو فینس': 'geo violation',
//     'آف لائن': 'offline',
//     'آف لائن موڈ': 'offline',
//     'آف لائن واقعات': 'offline events',
//     'تاریخ': 'date',
//     'تاریخیں': 'dates',
//     'کس تاریخ': 'kis date',
//     'کس کس تاریخ': 'which dates',
//     'کتنے': 'kitne how many',
//     'کتنا': 'kitna how much',
//     'کتنی': 'kitni how many',
//     'کس': 'kis which',
//     'کب': 'kab when',
//     'کیا': 'kya what',
//     'کیسی': 'kese how',
//     'مہینہ': 'mahine month',
//     'مہینے': 'mahine',
//     'اس مہینے': 'is mahine this month',
//     'آج': 'aaj today',
//     'کل': 'kal yesterday',
//     'پرسوں': 'parson day before yesterday',
//     'خلاصہ': 'summary',
//     'سمری': 'summary',
//     'تفصیل': 'detail summary',
//     'رپورٹ': 'report',
//     'آئے': 'aaye came',
//     'گئے': 'gaye went',
//     'گیا': 'gaya went',
//     'پوچھنا': 'ask',
//     'بتانا': 'tell',
//     'دکھانا': 'show',
//     'دیر سے آئے': 'late aaye',
//     'کتنی دیر': 'kitni late',
//     'کتنی چھٹی': 'kitni chutti',
//     'کتنی working': 'kitni working',
//   };
//
//   // ---------------------------------------------------------------------------
//   // Sound-alike corrections
//   // ---------------------------------------------------------------------------
//   static final Map<String, String> _soundCorrections = {
//     'my': 'meri',
//     'me': 'meri',
//     'may': 'meri',
//     'ma': 'meri',
//     'mari': 'meri',
//     'marry': 'meri',
//     'im': 'meri',
//     'am': 'meri',
//     'attnednc': 'attendance',
//     'atndnc': 'attendance',
//     'atendence': 'attendance',
//     'atndance': 'attendance',
//     'presentt': 'present',
//     'presnt': 'present',
//     'prsent': 'present',
//     'prezent': 'present',
//     'layt': 'late',
//     'laet': 'late',
//     'let': 'late',
//     'chutty': 'chutti',
//     'chooty': 'chutti',
//     'chuti': 'chutti',
//     'jaldi': 'early',
//     'jald': 'early',
//     'jldi': 'early',
//     'waqt': 'time',
//     'wqt': 'time',
//     'geofence': 'geo violation',
//     'geofens': 'geo violation',
//     'half': 'half day',
//     'halfday': 'half day',
//     'adha': 'half day',
//     'adhe': 'half day',
//     'hours': 'working hours',
//     'hour': 'working hours',
//     'ghante': 'working hours',
//     'summary': 'summary',
//     'summery': 'summary',
//     'samery': 'summary',
//   };
//
//   VoiceService() {
//     _initTts();
//   }
//
//   // ---------------------------------------------------------------------------
//   // TTS
//   // ---------------------------------------------------------------------------
//
//   Future<void> _initTts() async {
//     try {
//       await _tts.setLanguage('ur-PK');
//       await _tts.setSpeechRate(0.42);
//       await _tts.setPitch(1.0);
//       await _tts.setVolume(1.0);
//       await _tts.awaitSpeakCompletion(true);
//       print('✅ TTS initialized (ur-PK)');
//     } catch (e) {
//       print('❌ TTS init error: $e');
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // STT availability
//   // ---------------------------------------------------------------------------
//
//   Future<bool> isSpeechAvailable() async {
//     try {
//       final available = await _speech.initialize(
//         onStatus: (status) => print('🎤 Status: $status'),
//         onError: (error) => print('❌ STT error: $error'),
//       );
//       if (!available) print('⚠️ STT not available on this device');
//       return available;
//     } catch (e) {
//       print('❌ STT init error: $e');
//       return false;
//     }
//   }
//
//   Future<String> _pickBestLocale() async {
//     try {
//       final locales = await _speech.locales();
//       for (final preferred in _urduLocales) {
//         if (locales.any((l) => l.localeId == preferred)) {
//           print('✅ Using locale: $preferred');
//           return preferred;
//         }
//       }
//       final urduLocale = locales.firstWhere(
//             (l) => l.localeId.startsWith('ur'),
//         orElse: () => locales.first,
//       );
//       print('⚠️ Falling back to locale: ${urduLocale.localeId}');
//       return urduLocale.localeId;
//     } catch (e) {
//       print('❌ Could not enumerate locales: $e — using ur-PK');
//       return 'ur-PK';
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // Start listening
//   // ---------------------------------------------------------------------------
//
//   Future<void> startListening({
//     required Function(String) onResult,
//     required Function(double) onConfidence,
//     required Function() onListening,
//     required Function() onComplete,
//     required Function(String) onError,
//   }) async {
//     if (_isListening) {
//       print('⚠️ Already listening');
//       return;
//     }
//
//     try {
//       final available = await isSpeechAvailable();
//       if (!available) {
//         onError('Speech recognition not available');
//         onComplete();
//         return;
//       }
//
//       _activeLocale = await _pickBestLocale();
//
//       _isListening = true;
//       _lastRecognizedText = '';
//       _lastConfidence = 0.0;
//       _silenceCounter = 0;
//       _recognitionHistory.clear();
//
//       onListening();
//       print('🎤 Listening on locale: $_activeLocale');
//
//       await _speech.listen(
//         onResult: (result) {
//           try {
//             final raw = result.recognizedWords.trim();
//             if (raw.isEmpty) {
//               _silenceCounter++;
//               if (_silenceCounter > _maxSilenceCount) {
//                 print('🔇 Auto-complete after silence');
//                 _isListening = false;
//                 _speech.stop();
//                 onComplete();
//               }
//               return;
//             }
//
//             _silenceCounter = 0;
//
//             // Normalize: Urdu script → Roman equivalents
//             final normalized = _normalizeUrduText(raw);
//
//             // Apply sound-alike correction
//             final corrected = _applySoundAlikeCorrection(normalized);
//
//             _lastRecognizedText = corrected;
//             _lastConfidence = result.confidence > 0 ? result.confidence : 0.7;
//
//             print('📝 Raw: "$raw"');
//             print('📝 Normalized: "$normalized"');
//             print('📝 Corrected: "$corrected"');
//             print('📊 Conf: ${(_lastConfidence * 100).toStringAsFixed(1)}%');
//
//             _addToHistory(corrected);
//
//             if (_lastConfidence >= 0.2 || result.finalResult) {
//               onResult(corrected);
//               onConfidence(_lastConfidence);
//             }
//
//             if (result.finalResult) {
//               _isListening = false;
//               print('✅ Final: "$corrected"');
//               onComplete();
//             }
//           } catch (e) {
//             print('❌ onResult error: $e');
//           }
//         },
//         listenFor: const Duration(seconds: 60),
//         pauseFor: const Duration(seconds: 5),
//         cancelOnError: true,
//         partialResults: true,
//         onSoundLevelChange: (level) {
//           if (level > 0) print('🔊 Level: ${level.toStringAsFixed(1)}');
//         },
//         localeId: _activeLocale,
//       );
//     } catch (e) {
//       print('❌ startListening error: $e');
//       onError('آواز کی پہچان شروع نہیں ہو سکی: $e');
//       _isListening = false;
//       onComplete();
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // Stop listening
//   // ---------------------------------------------------------------------------
//
//   Future<void> stopListening() async {
//     try {
//       if (_isListening) {
//         await _speech.stop();
//         print('⏹️ Listening stopped');
//       }
//       _isListening = false;
//     } catch (e) {
//       print('❌ stopListening error: $e');
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // Urdu text normalization with fuzzy matching
//   // ---------------------------------------------------------------------------
//
//   String _normalizeUrduText(String text) {
//     String result = text;
//
//     // Replace longer phrases first (order matters)
//     final sortedKeys = _urduToRomanMap.keys.toList()
//       ..sort((a, b) => b.length.compareTo(a.length));
//
//     for (final urdu in sortedKeys) {
//       if (result.contains(urdu)) {
//         result = result.replaceAll(urdu, ' ${_urduToRomanMap[urdu]!} ');
//       }
//     }
//
//     // Remove extra spaces
//     result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
//     return result;
//   }
//
//   /// Apply sound-alike correction for commonly mis-recognized words
//   String _applySoundAlikeCorrection(String text) {
//     String result = text.toLowerCase();
//
//     // Common misrecognitions
//     for (final entry in _soundCorrections.entries) {
//       if (result.contains(entry.key)) {
//         result = result.replaceAll(entry.key, entry.value);
//       }
//     }
//
//     // Fix spacing issues
//     result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
//     return result;
//   }
//
//   /// Public method for intent normalization - FIXED
//   String normalizeForIntent(String text) {
//     try {
//       if (text.isEmpty) return '';
//
//       String result = text;
//
//       // First normalize Urdu script
//       result = _normalizeUrduText(result);
//
//       // Then apply sound-alike correction
//       result = _applySoundAlikeCorrection(result);
//
//       return result;
//     } catch (e) {
//       print('❌ normalizeForIntent error: $e');
//       // Return original text if normalization fails
//       return text;
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // History helpers
//   // ---------------------------------------------------------------------------
//
//   String getFinalText({bool requireConfidence = false}) {
//     if (requireConfidence && _lastConfidence < 0.3) {
//       return _getBestFromHistory();
//     }
//     return _lastRecognizedText;
//   }
//
//   double getLastConfidence() => _lastConfidence;
//
//   void _addToHistory(String text) {
//     if (text.isNotEmpty && !_recognitionHistory.contains(text)) {
//       _recognitionHistory.add(text);
//       if (_recognitionHistory.length > _maxHistoryLength) {
//         _recognitionHistory.removeAt(0);
//       }
//     }
//   }
//
//   String _getBestFromHistory() =>
//       _recognitionHistory.isEmpty ? '' : _recognitionHistory.last;
//
//   // ---------------------------------------------------------------------------
//   // Speak
//   // ---------------------------------------------------------------------------
//
//   Future<void> speak(
//       String text, {
//         Function()? onComplete,
//         Function(String)? onError,
//       }) async {
//     try {
//       if (_isSpeaking) await stopSpeaking();
//
//       if (text.isEmpty) {
//         print('⚠️ Empty text — nothing to speak');
//         return;
//       }
//
//       _isSpeaking = true;
//       print('🔊 Speaking Urdu text…');
//
//       _tts.setCompletionHandler(() {
//         _isSpeaking = false;
//         print('✅ Speech done');
//         onComplete?.call();
//       });
//       _tts.setErrorHandler((msg) {
//         _isSpeaking = false;
//         print('❌ TTS error: $msg');
//         onError?.call(msg);
//       });
//       _tts.setCancelHandler(() {
//         _isSpeaking = false;
//         print('⏹️ Speech cancelled');
//       });
//
//       bool ok = await _tts.speak(text);
//       if (!ok) {
//         print('⚠️ ur-PK failed — trying en-US');
//         await _tts.setLanguage('en-US');
//         ok = await _tts.speak(text);
//         await _tts.setLanguage('ur-PK');
//       }
//       if (!ok) throw Exception('TTS could not start');
//     } catch (e) {
//       _isSpeaking = false;
//       print('❌ speak() error: $e');
//       onError?.call(e.toString());
//     }
//   }
//
//   Future<void> stopSpeaking() async {
//     try {
//       if (_isSpeaking) {
//         await _tts.stop();
//         _isSpeaking = false;
//         print('⏹️ Speaking stopped');
//       }
//     } catch (e) {
//       print('❌ stopSpeaking error: $e');
//     }
//   }
//
//   Future<void> pauseSpeaking() async {
//     try {
//       await _tts.pause();
//     } catch (e) {
//       print('❌ pauseSpeaking error: $e');
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // Getters
//   // ---------------------------------------------------------------------------
//
//   bool get isListening => _isListening;
//   bool get isSpeaking => _isSpeaking;
//   String get activeLocale => _activeLocale;
//   List<String> get recognitionHistory => List.unmodifiable(_recognitionHistory);
//
//   void clearHistory() {
//     _recognitionHistory.clear();
//     _lastRecognizedText = '';
//     _lastConfidence = 0.0;
//     print('🗑️ History cleared');
//   }
//
//   void dispose() {
//     try {
//       _speech.stop();
//       _tts.stop();
//       _recognitionHistory.clear();
//       print('🛑 VoiceService disposed');
//     } catch (e) {
//       print('❌ dispose error: $e');
//     }
//   }
//
//   Future<Map<String, dynamic>> getServiceStatus() async {
//     return {
//       'isListening': _isListening,
//       'isSpeaking': _isSpeaking,
//       'activeLocale': _activeLocale,
//       'lastRecognizedText': _lastRecognizedText,
//       'lastConfidence': _lastConfidence,
//       'historyLength': _recognitionHistory.length,
//       'isAvailable': await isSpeechAvailable(),
//     };
//   }
//   // Add this method to VoiceService class
//   Future<void> setLanguage(String languageCode) async {
//     try {
//       await _tts.setLanguage(languageCode);
//       print('🔊 Language set to: $languageCode');
//     } catch (e) {
//       print('❌ Error setting language: $e');
//     }
//   }
// }


import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _isListening = false;
  bool _isSpeaking = false;
  String _lastRecognizedText = '';
  double _lastConfidence = 0.0;

  List<String> _recognitionHistory = [];
  final int _maxHistoryLength = 5;
  int _silenceCounter = 0;
  final int _maxSilenceCount = 8;

  static const List<String> _urduLocales = ['ur-PK', 'ur-IN', 'ur', 'hi-IN'];
  String _activeLocale = 'ur-PK';

  // ---------------------------------------------------------------------------
  // Urdu to Roman mapping
  // ---------------------------------------------------------------------------
  static final Map<String, String> _urduToRomanMap = {
    'حاضر': 'present hazir',
    'حاضری': 'attendance haziri',
    'حاضرین': 'present',
    'حاضر رہے': 'present',
    'دیر سے': 'late der',
    'دیری': 'late der',
    'دیر': 'der late',
    'دیر آئے': 'late',
    'دیر سے آئے': 'late',
    'لیٹ': 'late',
    'وقت پر': 'on time waqt',
    'ٹائم پر': 'on time',
    'وقت سے': 'on time',
    'جلدی گیا': 'early exit jaldi',
    'جلدی گئے': 'early exit jaldi',
    'جلدی': 'jaldi early',
    'جلدی نکلے': 'early exit',
    'جلدی چلے': 'early exit',
    'چھٹی': 'leave chutti',
    'چھٹی لی': 'leave',
    'لیو': 'leave',
    'ادھا دن': 'half day aadha',
    'ادھے دن': 'half day aadhe',
    'ادھا': 'half aadha',
    'ہاف ڈے': 'half day',
    'گھنٹے': 'hours ghante',
    'کام کے گھنٹے': 'working hours',
    'ورکنگ آورز': 'working hours',
    'گھنٹا': 'hours',
    'خلاف ورزی': 'violation geo',
    'خلاف': 'violation',
    'وائلشن': 'violation',
    'جیو': 'geo violation',
    'جیو فینس': 'geo violation',
    'آف لائن': 'offline',
    'آف لائن موڈ': 'offline',
    'آف لائن واقعات': 'offline events',
    'تاریخ': 'date',
    'تاریخیں': 'dates',
    'کس تاریخ': 'kis date',
    'کس کس تاریخ': 'which dates',
    'کتنے': 'kitne how many',
    'کتنا': 'kitna how much',
    'کتنی': 'kitni how many',
    'کس': 'kis which',
    'کب': 'kab when',
    'کیا': 'kya what',
    'کیسی': 'kese how',
    'مہینہ': 'mahine month',
    'مہینے': 'mahine',
    'اس مہینے': 'is mahine this month',
    'آج': 'aaj today',
    'کل': 'kal yesterday',
    'پرسوں': 'parson day before yesterday',
    'خلاصہ': 'summary',
    'سمری': 'summary',
    'تفصیل': 'detail summary',
    'رپورٹ': 'report',
    'آئے': 'aaye came',
    'گئے': 'gaye went',
    'گیا': 'gaya went',
    'پوچھنا': 'ask',
    'بتانا': 'tell',
    'دکھانا': 'show',
    'دیر سے آئے': 'late aaye',
    'کتنی دیر': 'kitni late',
    'کتنی چھٹی': 'kitni chutti',
    'کتنی working': 'kitni working',
  };

  // ---------------------------------------------------------------------------
  // Sound-alike corrections
  // ---------------------------------------------------------------------------
  static final Map<String, String> _soundCorrections = {
    'my': 'meri',
    'me': 'meri',
    'may': 'meri',
    'ma': 'meri',
    'mari': 'meri',
    'marry': 'meri',
    'im': 'meri',
    'am': 'meri',
    'attnednc': 'attendance',
    'atndnc': 'attendance',
    'atendence': 'attendance',
    'atndance': 'attendance',
    'presentt': 'present',
    'presnt': 'present',
    'prsent': 'present',
    'prezent': 'present',
    'layt': 'late',
    'laet': 'late',
    'let': 'late',
    'chutty': 'chutti',
    'chooty': 'chutti',
    'chuti': 'chutti',
    'jaldi': 'early',
    'jald': 'early',
    'jldi': 'early',
    'waqt': 'time',
    'wqt': 'time',
    'geofence': 'geo violation',
    'geofens': 'geo violation',
    'half': 'half day',
    'halfday': 'half day',
    'adha': 'half day',
    'adhe': 'half day',
    'hours': 'working hours',
    'hour': 'working hours',
    'ghante': 'working hours',
    'summary': 'summary',
    'summery': 'summary',
    'samery': 'summary',
  };

  VoiceService() {
    _initTts();
  }

  // ---------------------------------------------------------------------------
  // TTS
  // ---------------------------------------------------------------------------

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('ur-PK');
      await _tts.setSpeechRate(0.42);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);
      print('✅ TTS initialized (ur-PK)');
    } catch (e) {
      print('❌ TTS init error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // STT availability
  // ---------------------------------------------------------------------------

  Future<bool> isSpeechAvailable() async {
    try {
      final available = await _speech.initialize(
        onStatus: (status) => print('🎤 Status: $status'),
        onError: (error) => print('❌ STT error: $error'),
      );
      if (!available) print('⚠️ STT not available on this device');
      return available;
    } catch (e) {
      print('❌ STT init error: $e');
      return false;
    }
  }

  Future<String> _pickBestLocale() async {
    try {
      final locales = await _speech.locales();
      for (final preferred in _urduLocales) {
        if (locales.any((l) => l.localeId == preferred)) {
          print('✅ Using locale: $preferred');
          return preferred;
        }
      }
      final urduLocale = locales.firstWhere(
            (l) => l.localeId.startsWith('ur'),
        orElse: () => locales.first,
      );
      print('⚠️ Falling back to locale: ${urduLocale.localeId}');
      return urduLocale.localeId;
    } catch (e) {
      print('❌ Could not enumerate locales: $e — using ur-PK');
      return 'ur-PK';
    }
  }

  // ---------------------------------------------------------------------------
  // Start listening
  // ---------------------------------------------------------------------------

  Future<void> startListening({
    required Function(String) onResult,
    required Function(double) onConfidence,
    required Function() onListening,
    required Function() onComplete,
    required Function(String) onError,
  }) async {
    if (_isListening) {
      print('⚠️ Already listening');
      return;
    }

    try {
      final available = await isSpeechAvailable();
      if (!available) {
        onError('Speech recognition not available');
        onComplete();
        return;
      }

      _activeLocale = await _pickBestLocale();

      _isListening = true;
      _lastRecognizedText = '';
      _lastConfidence = 0.0;
      _silenceCounter = 0;
      _recognitionHistory.clear();

      onListening();
      print('🎤 Listening on locale: $_activeLocale');

      await _speech.listen(
        onResult: (result) {
          try {
            final raw = result.recognizedWords.trim();
            if (raw.isEmpty) {
              _silenceCounter++;
              if (_silenceCounter > _maxSilenceCount) {
                print('🔇 Auto-complete after silence');
                _isListening = false;
                _speech.stop();
                onComplete();
              }
              return;
            }

            _silenceCounter = 0;

            // Normalize: Urdu script → Roman equivalents
            final normalized = _normalizeUrduText(raw);

            // Apply sound-alike correction
            final corrected = _applySoundAlikeCorrection(normalized);

            _lastRecognizedText = corrected;
            _lastConfidence = result.confidence > 0 ? result.confidence : 0.7;

            print('📝 Raw: "$raw"');
            print('📝 Normalized: "$normalized"');
            print('📝 Corrected: "$corrected"');
            print('📊 Conf: ${(_lastConfidence * 100).toStringAsFixed(1)}%');

            _addToHistory(corrected);

            if (_lastConfidence >= 0.2 || result.finalResult) {
              onResult(corrected);
              onConfidence(_lastConfidence);
            }

            if (result.finalResult) {
              _isListening = false;
              print('✅ Final: "$corrected"');
              onComplete();
            }
          } catch (e) {
            print('❌ onResult error: $e');
          }
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 5),
        cancelOnError: true,
        partialResults: true,
        onSoundLevelChange: (level) {
          if (level > 0) print('🔊 Level: ${level.toStringAsFixed(1)}');
        },
        localeId: _activeLocale,
      );
    } catch (e) {
      print('❌ startListening error: $e');
      onError('آواز کی پہچان شروع نہیں ہو سکی: $e');
      _isListening = false;
      onComplete();
    }
  }

  // ---------------------------------------------------------------------------
  // Stop listening
  // ---------------------------------------------------------------------------

  Future<void> stopListening() async {
    try {
      if (_isListening) {
        await _speech.stop();
        print('⏹️ Listening stopped');
      }
      _isListening = false;
    } catch (e) {
      print('❌ stopListening error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Urdu text normalization with fuzzy matching
  // ---------------------------------------------------------------------------

  String _normalizeUrduText(String text) {
    String result = text;

    // Replace longer phrases first (order matters)
    final sortedKeys = _urduToRomanMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final urdu in sortedKeys) {
      if (result.contains(urdu)) {
        result = result.replaceAll(urdu, ' ${_urduToRomanMap[urdu]!} ');
      }
    }

    // Remove extra spaces
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }

  /// Apply sound-alike correction for commonly mis-recognized words
  String _applySoundAlikeCorrection(String text) {
    String result = text.toLowerCase();

    // Common misrecognitions
    for (final entry in _soundCorrections.entries) {
      if (result.contains(entry.key)) {
        result = result.replaceAll(entry.key, entry.value);
      }
    }

    // Fix spacing issues
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }

  /// Public method for intent normalization - FIXED
  String normalizeForIntent(String text) {
    try {
      if (text.isEmpty) return '';

      String result = text;

      // First normalize Urdu script
      result = _normalizeUrduText(result);

      // Then apply sound-alike correction
      result = _applySoundAlikeCorrection(result);

      return result;
    } catch (e) {
      print('❌ normalizeForIntent error: $e');
      // Return original text if normalization fails
      return text;
    }
  }

  // ---------------------------------------------------------------------------
  // History helpers
  // ---------------------------------------------------------------------------

  String getFinalText({bool requireConfidence = false}) {
    if (requireConfidence && _lastConfidence < 0.3) {
      return _getBestFromHistory();
    }
    return _lastRecognizedText;
  }

  double getLastConfidence() => _lastConfidence;

  void _addToHistory(String text) {
    if (text.isNotEmpty && !_recognitionHistory.contains(text)) {
      _recognitionHistory.add(text);
      if (_recognitionHistory.length > _maxHistoryLength) {
        _recognitionHistory.removeAt(0);
      }
    }
  }

  String _getBestFromHistory() =>
      _recognitionHistory.isEmpty ? '' : _recognitionHistory.last;

  // ---------------------------------------------------------------------------
  // Speak
  // ---------------------------------------------------------------------------

  /// FIX: the OS text-to-speech engine was reading raw "**bold**" markdown
  /// markers, bullet points, and the urdu/english "---" separator out loud
  /// literally (reported as "**" sounding like "ek dollar"), because the
  /// raw response text — straight out of ResponseBuilder — was being
  /// passed to _tts.speak() unmodified. This strips all of that before
  /// speaking, while leaving the on-screen text (which renders "**" as
  /// actual bold) untouched.
  String _cleanForSpeech(String text) {
    String result = text;

    // In case an un-split bilingual string ever reaches here, only speak
    // the part before the separator.
    if (result.contains('---')) {
      result = result.split('---')[0];
    }

    // Drop markdown bold markers but keep the wrapped text.
    result = result.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'$1');
    // Remove any leftover/unmatched asterisks.
    result = result.replaceAll('*', '');
    // Remove bullet characters used in lists.
    result = result.replaceAll('•', '');
    // Treat newlines as a natural pause instead of reading them literally.
    result = result.replaceAll('\n', '۔ ');
    // Collapse repeated whitespace left behind by the replacements above.
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }

  Future<void> speak(
      String text, {
        Function()? onComplete,
        Function(String)? onError,
      }) async {
    try {
      if (_isSpeaking) await stopSpeaking();

      final cleaned = _cleanForSpeech(text);

      if (cleaned.isEmpty) {
        print('⚠️ Empty text — nothing to speak');
        return;
      }

      _isSpeaking = true;
      print('🔊 Speaking Urdu text…');

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        print('✅ Speech done');
        onComplete?.call();
      });
      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        print('❌ TTS error: $msg');
        onError?.call(msg);
      });
      _tts.setCancelHandler(() {
        _isSpeaking = false;
        print('⏹️ Speech cancelled');
      });

      bool ok = await _tts.speak(cleaned);
      if (!ok) {
        print('⚠️ ur-PK failed — trying en-US');
        await _tts.setLanguage('en-US');
        ok = await _tts.speak(cleaned);
        await _tts.setLanguage('ur-PK');
      }
      if (!ok) throw Exception('TTS could not start');
    } catch (e) {
      _isSpeaking = false;
      print('❌ speak() error: $e');
      onError?.call(e.toString());
    }
  }

  Future<void> stopSpeaking() async {
    try {
      if (_isSpeaking) {
        await _tts.stop();
        _isSpeaking = false;
        print('⏹️ Speaking stopped');
      }
    } catch (e) {
      print('❌ stopSpeaking error: $e');
    }
  }

  Future<void> pauseSpeaking() async {
    try {
      await _tts.pause();
    } catch (e) {
      print('❌ pauseSpeaking error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  String get activeLocale => _activeLocale;
  List<String> get recognitionHistory => List.unmodifiable(_recognitionHistory);

  void clearHistory() {
    _recognitionHistory.clear();
    _lastRecognizedText = '';
    _lastConfidence = 0.0;
    print('🗑️ History cleared');
  }

  void dispose() {
    try {
      _speech.stop();
      _tts.stop();
      _recognitionHistory.clear();
      print('🛑 VoiceService disposed');
    } catch (e) {
      print('❌ dispose error: $e');
    }
  }

  Future<Map<String, dynamic>> getServiceStatus() async {
    return {
      'isListening': _isListening,
      'isSpeaking': _isSpeaking,
      'activeLocale': _activeLocale,
      'lastRecognizedText': _lastRecognizedText,
      'lastConfidence': _lastConfidence,
      'historyLength': _recognitionHistory.length,
      'isAvailable': await isSpeechAvailable(),
    };
  }
  // Add this method to VoiceService class
  Future<void> setLanguage(String languageCode) async {
    try {
      await _tts.setLanguage(languageCode);
      print('🔊 Language set to: $languageCode');
    } catch (e) {
      print('❌ Error setting language: $e');
    }
  }
}