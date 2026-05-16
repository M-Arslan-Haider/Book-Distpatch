// lib/Repositories/short_break_repository.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../Models/short_break_model.dart';

class ShortBreakRepository {
  static const String _baseUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/shortbreak/get/';
  static const String _startUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/shortbreak/start/';
  static const String _endUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/shortbreakpost/post/';

  // ── Fetch break policy ─────────────────────────────────────────────────────
  Future<List<ShortBreakModel>> fetchBreakPolicy({
    required String depId,
    required String companyCode,
  }) async {
    debugPrint('');
    debugPrint('════════════════════════════════════════════════════════');
    debugPrint('🟡 [SHORT BREAK] fetchBreakPolicy() called');
    debugPrint('🟡 [SHORT BREAK] depId       = "$depId"');
    debugPrint('🟡 [SHORT BREAK] companyCode = "$companyCode"');

    if (depId.isEmpty) {
      debugPrint('❌ [SHORT BREAK] depId is EMPTY — cannot call API');
      debugPrint('════════════════════════════════════════════════════════');
      return [];
    }
    if (companyCode.isEmpty) {
      debugPrint('❌ [SHORT BREAK] companyCode is EMPTY — cannot call API');
      debugPrint('════════════════════════════════════════════════════════');
      return [];
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl?dep_id=$depId&company_code=$companyCode',
      );
      debugPrint('📡 [SHORT BREAK] Full URL     = $uri');

      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      debugPrint('📡 [SHORT BREAK] HTTP Status  = ${response.statusCode}');
      debugPrint('📡 [SHORT BREAK] Raw Body     = ${response.body}');
      debugPrint('📡 [SHORT BREAK] Body Length  = ${response.body.length} chars');

      if (response.statusCode != 200) {
        debugPrint('❌ [SHORT BREAK] Non-200 — returning empty list');
        debugPrint('════════════════════════════════════════════════════════');
        return [];
      }

      // ── Parse JSON ──────────────────────────────────────────────────
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('❌ [SHORT BREAK] JSON decode failed: $e');
        debugPrint('════════════════════════════════════════════════════════');
        return [];
      }

      debugPrint('📡 [SHORT BREAK] Top-level JSON keys = ${data.keys.toList()}');

      final rawItems = data['items'];
      debugPrint('📡 [SHORT BREAK] data["items"] runtimeType = ${rawItems.runtimeType}');
      debugPrint('📡 [SHORT BREAK] data["items"] value       = $rawItems');

      final items = (rawItems ?? []) as List<dynamic>;
      debugPrint('📡 [SHORT BREAK] items count = ${items.length}');

      if (items.isEmpty) {
        debugPrint('⚠️  [SHORT BREAK] items array is EMPTY');
        debugPrint('    Possible reasons:');
        debugPrint('    1. No row in BREAK_TIME for dep_id=$depId');
        debugPrint('    2. company_code=$companyCode mismatch');
        debugPrint('    3. Oracle WHERE Break_Type="Short Break" filtered all rows');
        debugPrint('════════════════════════════════════════════════════════');
        return [];
      }

      // ── Log every raw item ──────────────────────────────────────────
      for (int i = 0; i < items.length; i++) {
        final item = items[i] as Map<String, dynamic>;
        debugPrint('');
        debugPrint('📋 [SHORT BREAK] ── Item[$i] RAW ──────────────────────');
        debugPrint('📋 [SHORT BREAK] Item[$i] keys     = ${item.keys.toList()}');
        debugPrint('📋 [SHORT BREAK] Item[$i] full map = $item');
        debugPrint('');

        // ── Per-field key detection ─────────────────────────────────
        debugPrint('🔍 [SHORT BREAK] Item[$i] FIELD TRACE:');

        // break_type
        final rawBreakTypeUpper = item['BREAK_TYPE'];
        final rawBreakTypeLower = item['break_type'];
        final resolvedBreakType = rawBreakTypeUpper ?? rawBreakTypeLower;
        debugPrint('   break_type  → UPPERCASE key present: ${rawBreakTypeUpper != null} '
            '(value: $rawBreakTypeUpper, type: ${rawBreakTypeUpper.runtimeType})');
        debugPrint('   break_type  → lowercase  key present: ${rawBreakTypeLower != null} '
            '(value: $rawBreakTypeLower, type: ${rawBreakTypeLower.runtimeType})');
        debugPrint('   break_type  → RESOLVED VALUE: "$resolvedBreakType"  '
            'after trim: "${resolvedBreakType?.toString().trim()}"');

        // count_limit
        final rawCountUpper = item['COUNT_LIMIT'];
        final rawCountLower = item['count_limit'];
        final resolvedCount  = rawCountUpper ?? rawCountLower ?? '0';
        final parsedCount    = int.tryParse(resolvedCount.toString());
        debugPrint('   count_limit → UPPERCASE key present: ${rawCountUpper != null} '
            '(value: $rawCountUpper, type: ${rawCountUpper.runtimeType})');
        debugPrint('   count_limit → lowercase  key present: ${rawCountLower != null} '
            '(value: $rawCountLower, type: ${rawCountLower.runtimeType})');
        debugPrint('   count_limit → RESOLVED RAW: "$resolvedCount"  '
            'after int.tryParse: $parsedCount  '
            'final: ${parsedCount ?? 0}');

        // short_break_time
        final rawTimeUpper = item['SHORT_BREAK_TIME'];
        final rawTimeLower = item['short_break_time'];
        final resolvedTime = rawTimeUpper ?? rawTimeLower ?? '15:00';
        debugPrint('   short_break_time → UPPERCASE key present: ${rawTimeUpper != null} '
            '(value: $rawTimeUpper, type: ${rawTimeUpper.runtimeType})');
        debugPrint('   short_break_time → lowercase  key present: ${rawTimeLower != null} '
            '(value: $rawTimeLower, type: ${rawTimeLower.runtimeType})');
        debugPrint('   short_break_time → RESOLVED VALUE: "$resolvedTime"  '
            'after trim: "${resolvedTime.toString().trim()}"');

        debugPrint('');
        debugPrint('   ✅ WILL PARSE TO: '
            'breakType="${resolvedBreakType?.toString().trim()}"  '
            'countLimit=${parsedCount ?? 0}  '
            'shortBreakTime="${resolvedTime.toString().trim()}"');
        debugPrint('   🚦 FILTER CHECK: '
            'breakType.isNotEmpty=${resolvedBreakType?.toString().trim().isNotEmpty}  '
            'countLimit>0=${( parsedCount ?? 0) > 0}  '
            '→ will ${((resolvedBreakType?.toString().trim().isNotEmpty ?? false) && ((parsedCount ?? 0) > 0)) ? "KEEP ✅" : "DROP ❌"}');
      }

      // ── Parse to models ─────────────────────────────────────────────
      debugPrint('');
      debugPrint('📡 [SHORT BREAK] Running ShortBreakModel.fromJson() on all items...');
      final allParsed = items
          .map((e) => ShortBreakModel.fromJson(e as Map<String, dynamic>))
          .toList();

      debugPrint('📡 [SHORT BREAK] Parsed ${allParsed.length} model(s) BEFORE filter:');
      for (final b in allParsed) {
        debugPrint('   • breakType="${b.breakType}"  '
            'countLimit=${b.countLimit}  '
            'shortBreakTime="${b.shortBreakTime}"  '
            'maxDuration=${b.maxDuration.inMinutes}m${b.maxDuration.inSeconds % 60}s  '
            'canTakeBreak=${b.canTakeBreak}  '
            'durationLabel="${b.durationLabel}"');
      }

      // ── Apply filter ─────────────────────────────────────────────────
      final filtered = allParsed
          .where((b) => b.breakType.isNotEmpty && b.countLimit > 0)
          .toList();

      debugPrint('✅ [SHORT BREAK] After filter: ${filtered.length} break type(s) kept');
      if (filtered.length < allParsed.length) {
        debugPrint('⚠️  [SHORT BREAK] Dropped ${allParsed.length - filtered.length} '
            'item(s): empty breakType OR countLimit <= 0');
      }

      if (filtered.isNotEmpty) {
        debugPrint('🎉 [SHORT BREAK] FINAL RESULT:');
        for (final b in filtered) {
          debugPrint('   ✅ "${b.breakType}" — ${b.durationLabel} — limit: ${b.countLimit}');
        }
      } else {
        debugPrint('❌ [SHORT BREAK] FINAL RESULT: empty list returned to ViewModel');
        debugPrint('   → Check FIELD TRACE above to see which field caused the drop');
      }

      debugPrint('════════════════════════════════════════════════════════');
      debugPrint('');
      return filtered;
    } catch (e, stack) {
      debugPrint('❌ [SHORT BREAK] Exception: $e');
      debugPrint('❌ [SHORT BREAK] Stack: $stack');
      debugPrint('════════════════════════════════════════════════════════');
      return [];
    }
  }

  // ── POST break start ──────────────────────────────────────────────────────
  Future<bool> postBreakStart({
    required String empId,
    required String empName,
    required String companyCode,
    required String breakType,
    required String startTimestamp,
    required double lat,
    required double lng,
  }) async {
    try {
      final body = jsonEncode({
        'emp_id': empId,
        'emp_name': empName,
        'company_code': companyCode,
        'break_type': breakType,
        'start_timestamp': startTimestamp,
        'lat': lat,
        'lng': lng,
      });
      debugPrint('📤 [SHORT BREAK START] POST: $_startUrl');
      debugPrint('📤 [SHORT BREAK START] Body: $body');

      final response = await http
          .post(Uri.parse(_startUrl),
          headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));

      debugPrint('📤 [SHORT BREAK START] Status  : ${response.statusCode}');
      debugPrint('📤 [SHORT BREAK START] Response: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ [SHORT BREAK START] Error: $e');
      return false;
    }
  }

  // ── POST break end ──────────────────────────────────────────────────────────
  // Oracle ORDS uses :body for BLOB (selfie) and query-params for all other fields.
  // So: text fields → URL query parameters, selfie → raw binary POST body.
  Future<bool> postBreakEnd({
    required String empId,
    required String empName,
    required String companyCode,
    required String depId,
    required String breakType,
    required String startTimestamp,
    required String endTimestamp,
    required String totalBreakTime,
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required String selfieBase64,
  }) async {
    try {
      // ── All text fields as URL query parameters → Oracle :bind_variables ──
      final uri = Uri.parse(_endUrl).replace(queryParameters: {
        'emp_id':          empId,
        'emp_name':        empName,
        'company_code':    companyCode,
        'dep_id':          depId,
        'break_type':      breakType,
        'start_timestamp': startTimestamp,
        'end_timestamp':   endTimestamp,
        'total_break_time': totalBreakTime,
        'start_lat':       startLat.toString(),
        'start_lng':       startLng.toString(),
        'end_lat':         endLat.toString(),
        'end_lng':         endLng.toString(),
      });

      // ── Selfie as raw bytes → Oracle :body reads it directly as BLOB ──────
      final imageBytes = selfieBase64.isNotEmpty
          ? base64Decode(selfieBase64)
          : <int>[];

      debugPrint('📤 [SHORT BREAK END] POST: $uri');
      debugPrint('📤 [SHORT BREAK END] empId=$empId  empName="$empName"');
      debugPrint('📤 [SHORT BREAK END] companyCode="$companyCode"  depId="$depId"');
      debugPrint('📤 [SHORT BREAK END] breakType="$breakType"');
      debugPrint('📤 [SHORT BREAK END] startTimestamp="$startTimestamp"');
      debugPrint('📤 [SHORT BREAK END] endTimestamp="$endTimestamp"');
      debugPrint('📤 [SHORT BREAK END] totalBreakTime="$totalBreakTime"');
      debugPrint('📤 [SHORT BREAK END] startLat=$startLat  startLng=$startLng');
      debugPrint('📤 [SHORT BREAK END] endLat=$endLat  endLng=$endLng');
      debugPrint('📤 [SHORT BREAK END] selfie raw bytes=${imageBytes.length}');

      final response = await http
          .post(
        uri,
        headers: {'Content-Type': 'image/jpeg'},
        body: imageBytes,
      )
          .timeout(const Duration(seconds: 30));

      debugPrint('📤 [SHORT BREAK END] Status  : ${response.statusCode}');
      debugPrint('📤 [SHORT BREAK END] Response: ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ [SHORT BREAK END] Error: $e');
      return false;
    }
  }
}