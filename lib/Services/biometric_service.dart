import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

// ── Shared-preference keys (add these to your constants.dart as well) ────────
const String prefBiometricEnabled  = 'biometric_enabled';
const String prefBiometricUserId   = 'biometric_user_id';
const String prefBiometricPassword = 'biometric_password';

/// Describes which biometric modality the device primarily uses.
enum BiometricModality { face, fingerprint, none }

/// Thin wrapper around [LocalAuthentication].
/// All methods are static so no instance management is needed.
class BiometricService {
  BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  // ── Device capability check ───────────────────────────────────────────────

  /// Returns `true` when the device both supports and has enrolled biometrics.
  static Future<bool> isAvailable() async {
    try {
      final canCheck    = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException catch (e) {
      _log('isAvailable error: $e');
      return false;
    }
  }

  /// Returns the list of enrolled biometric types (fingerprint, face, etc.).
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (e) {
      _log('getAvailableBiometrics error: $e');
      return [];
    }
  }

  // ── NEW: Modality detection ───────────────────────────────────────────────

  /// Resolves the *primary* biometric modality enrolled on this device.
  ///
  /// Priority order: face → fingerprint → none.
  /// Used by the UI to pick the correct icon and label automatically.
  static Future<BiometricModality> getPrimaryModality() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face) ||
          types.contains(BiometricType.iris)) {
        return BiometricModality.face;
      }
      if (types.contains(BiometricType.fingerprint) ||
          types.contains(BiometricType.strong) ||
          types.contains(BiometricType.weak)) {
        return BiometricModality.fingerprint;
      }
      return BiometricModality.none;
    } on PlatformException catch (e) {
      _log('getPrimaryModality error: $e');
      return BiometricModality.none;
    }
  }

  // ── Authentication ────────────────────────────────────────────────────────

  /// Prompts the system biometric sheet and returns `true` on success.
  ///
  /// [reason] is the string shown to the user in the OS dialog.
  /// local_auth handles both Face ID and fingerprint automatically via the
  /// platform — no extra configuration is required here.
  static Future<bool> authenticate({
    String reason = 'Authenticate to continue',
  }) async {
    try {
      // local_auth 3.x: localizedReason is the only required parameter.
      // PIN fallback and sticky-auth are handled by the platform.
      return await _auth.authenticate(
        localizedReason: reason,
      );
    } on PlatformException catch (e) {
      _log('authenticate error: $e');
      return false;
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────
  static void _log(String msg) {
    // ignore: avoid_print
    print('[BiometricService] $msg');
  }
}