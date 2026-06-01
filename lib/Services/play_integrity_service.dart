import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class PlayIntegrityService {
  static final PlayIntegrityService _instance =
  PlayIntegrityService._internal();

  PlayIntegrityService._internal();
  factory PlayIntegrityService() => _instance;

  static const MethodChannel _channel = MethodChannel('play_integrity');

  Timer? _debugTimer;

  // ✅ Call this once to start printing every 1 second
  void startDebugPrinting() {
    _debugTimer?.cancel();
    _debugTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await requestIntegrityToken();
    });
    debugPrint('🟢 Play Integrity debug printing started (every 1 sec)');
  }

  // ✅ Call this to stop
  void stopDebugPrinting() {
    _debugTimer?.cancel();
    _debugTimer = null;
    debugPrint('🔴 Play Integrity debug printing stopped');
  }

  Future<String?> requestIntegrityToken() async {
    try {
      final String? token = await _channel.invokeMethod('getIntegrityToken', {
        'cloudProjectNumber': '651989973255',
      });
      debugPrint('✅ Play Integrity Token Obtained: $token');
      return token;
    } catch (e) {
      debugPrint('❌ Play Integrity Error: $e');
      return null;
    }
  }
}