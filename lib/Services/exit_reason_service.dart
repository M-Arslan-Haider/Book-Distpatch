import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ExitReasonService — with OFFLINE QUEUE
/// -------------------------------------------------------------------------
/// Detects how the process died last time (force stop vs OEM kill vs crash)
/// and posts it to the server. If offline, the event is saved locally and
/// flushed on a later launch when internet returns — so an OFFLINE force stop
/// is never lost.
///
/// Flow on every launch:
///   1. flushPending()  -> try to send any events saved while offline
///   2. checkOnLaunch() -> read newest exit reason, send OR queue it
class ExitReasonService {
  static const MethodChannel _channel =
  MethodChannel('com.metaxperts.gwm/exit_reason');

  static const String _postUrl =
      'http://oracle.metaxperts.net/ords/gps_workforce/processexitevents/post/';

  static const String _prefLastReportedTs = 'exit_reason_last_reported_ts';
  static const String _prefPendingQueue = 'exit_reason_pending_queue';

  /// Call this ONCE on launch. Flushes the offline queue first, then checks
  /// for a new death. Replaces your old single checkOnLaunch() call.
  static Future<void> runOnLaunch() async {
    await flushPending();
    await checkOnLaunch();
  }

  // -- Detect newest death, then send or queue -----------------------------
  static Future<void> checkOnLaunch() async {
    try {
      final raw = await _channel
          .invokeMethod<List<dynamic>>('getExitReasons', {'max': 5});
      if (raw == null || raw.isEmpty) return;

      final latest = Map<String, dynamic>.from(raw.first as Map);
      final int ts = (latest['timestamp'] as num?)?.toInt() ?? 0;
      if (ts == 0) return;

      final prefs = await SharedPreferences.getInstance();
      final int lastReported = prefs.getInt(_prefLastReportedTs) ?? 0;
      if (ts <= lastReported) return; // already handled this death

      final empId = prefs.getInt('emp_id')?.toString() ??
          prefs.getString('emp_id') ??
          '';
      if (empId.isEmpty) return; // not logged in yet — retry next launch

      final bool isForceStop = latest['isForceStop'] == true;
      final bool isSystemKill = latest['isSystemKill'] == true;
      final bool isAppFault = latest['isAppFault'] == true;
      final String reasonText = (latest['reasonText'] ?? 'UNKNOWN').toString();

      final String classification = isForceStop
          ? 'FORCE_STOP'
          : isAppFault
          ? 'APP_FAULT'
          : isSystemKill
          ? 'SYSTEM_KILL'
          : 'OTHER';

      // String-typed map (matches the ORDS handler that works in Postman).
      final Map<String, dynamic> event = {
        'emp_id': empId,
        'emp_name': prefs.getString('emp_name') ?? '',
        'company_code': prefs.getString('company_code') ?? '',
        'event_type': 'process_exit',
        'classification': classification,
        'reason_text': reasonText,
        'died_at_epoch_ms': ts.toString(),
        'is_force_stop': isForceStop ? '1' : '0',
        'is_system_kill': isSystemKill ? '1' : '0',
        'is_app_fault': isAppFault ? '1' : '0',
        'importance': (latest['importance'] ?? 0).toString(),
        'description': (latest['description'] ?? '').toString(),
        'reported_at': DateTime.now().toUtc().toIso8601String(),
      };

      final bool sent = await _tryPost(event);

      if (sent) {
        await prefs.setInt(_prefLastReportedTs, ts);
        print("[EXIT] posted ($classification)");
      } else {
        // Offline / server down -> SAVE to queue and advance the marker,
        // because the event is now safely stored and will be flushed later.
        await _addToQueue(event);
        await prefs.setInt(_prefLastReportedTs, ts);
        print("[EXIT] offline — event queued ($classification)");
      }
    } catch (e) {
      print("[EXIT] checkOnLaunch error $e");
    }
  }

  // -- Flush any events saved while offline --------------------------------
  static Future<void> flushPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? rawQueue = prefs.getString(_prefPendingQueue);
      if (rawQueue == null || rawQueue.isEmpty) return;

      final List<dynamic> queue = jsonDecode(rawQueue) as List<dynamic>;
      if (queue.isEmpty) return;

      print("[EXIT] flushing ${queue.length} queued event(s)");
      final List<dynamic> stillPending = [];

      for (final item in queue) {
        final event = Map<String, dynamic>.from(item as Map);
        final bool sent = await _tryPost(event);
        if (!sent) {
          stillPending.add(event);
        } else {
          print("[EXIT] flushed one queued event");
        }
      }

      if (stillPending.isEmpty) {
        await prefs.remove(_prefPendingQueue);
        print("[EXIT] queue empty — all flushed");
      } else {
        await prefs.setString(_prefPendingQueue, jsonEncode(stillPending));
        print("[EXIT] ${stillPending.length} still pending (offline)");
      }
    } catch (e) {
      print("[EXIT] flushPending error $e");
    }
  }

  // -- Helpers -------------------------------------------------------------
  static Future<bool> _tryPost(Map<String, dynamic> event) async {
    try {
      final resp = await http
          .post(Uri.parse(_postUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(event))
          .timeout(const Duration(seconds: 15));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false; // no internet / timeout / DNS fail -> not sent
    }
  }

  static Future<void> _addToQueue(Map<String, dynamic> event) async {
    final prefs = await SharedPreferences.getInstance();
    final String? rawQueue = prefs.getString(_prefPendingQueue);
    final List<dynamic> queue =
    (rawQueue == null || rawQueue.isEmpty) ? [] : jsonDecode(rawQueue);

    // Avoid duplicates: skip if same died_at_epoch_ms already queued.
    final String ts = event['died_at_epoch_ms'].toString();
    final bool exists =
    queue.any((e) => (e as Map)['died_at_epoch_ms'].toString() == ts);
    if (!exists) queue.add(event);

    await prefs.setString(_prefPendingQueue, jsonEncode(queue));
  }
}
