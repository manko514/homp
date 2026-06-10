import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

/// Handles NFC tag writes for the digital room key feature.
///
/// The hotel issues a blank NDEF-compatible NFC card at front desk.
/// After digital check-in the guest taps "Write NFC Key" → this service
/// encodes the reservation token as a plain-text NDEF record on the card.
/// Door lock readers scan the card and validate the token server-side.
class NfcService {
  NfcService._();
  static final NfcService instance = NfcService._();

  /// Returns true when the device has an NFC adapter and it is enabled.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Writes [keyToken] to an NFC tag in NDEF format.
  ///
  /// [onWaiting] is called immediately after NFC listening starts so the
  /// caller can show an "Hold your phone near the hotel key card" overlay.
  ///
  /// Completes when the write succeeds, or throws if it fails / the user
  /// cancels via [cancelWrite].
  Future<void> writeRoomKey({
    required String keyToken,
    required VoidCallback onWaiting,
  }) async {
    final available = await isAvailable();
    if (!available) {
      throw UnsupportedError(
        'NFC is not available on this device. '
        'Use the QR code to unlock your room.',
      );
    }

    final completer = Completer<void>();

    await NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null) {
            completer.completeError(
              Exception(
                'Tag is not NDEF-compatible. '
                'Please use the hotel key card provided at reception.',
              ),
            );
            return;
          }
          if (!ndef.isWritable) {
            completer.completeError(
              Exception(
                'This NFC card is read-only. '
                'Please collect a blank key card from reception.',
              ),
            );
            return;
          }

          final message = NdefMessage([NdefRecord.createText(keyToken)]);
          await ndef.write(message);

          if (!completer.isCompleted) completer.complete();
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        } finally {
          await NfcManager.instance.stopSession();
        }
      },
    );

    // Let the caller show the "scan" UI immediately.
    onWaiting();

    return completer.future;
  }

  Future<void> cancelWrite() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }
}
