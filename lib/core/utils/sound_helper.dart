import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

class SoundHelper {
  /// Plays a clear scan sound and triggers vibration for barcode scanning feedback across the system.
  static Future<void> playScanSound() async {
    // Play ringtone/notification sound
    try {
      FlutterRingtonePlayer().playNotification();
    } catch (_) {}

    // Fallback system click sound
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}

    // Trigger haptic vibration
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate();
      }
    } catch (_) {}
  }
}
