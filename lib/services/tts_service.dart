import 'package:flutter_tts/flutter_tts.dart';

/// Voice styles for user personalization.
enum VoiceProfile { calming, friendly, energetic }

class TtsService {
  final FlutterTts _tts = FlutterTts();
  VoiceProfile _profile = VoiceProfile.calming;

  TtsService() {
    _init();
  }

  Future<void> _init() async {
    await _tts.setLanguage('en-US');      // default language
    await _tts.setSpeechRate(0.45);       // baseline
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
  }

  /// Basic speak (awaits until done).
  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Speak, then wait a bit before next action (e.g., re-opening mic).
  Future<void> speakThenDelay(
      String text, {
        Duration delay = const Duration(milliseconds: 350),
      }) async {
    await speak(text);
    await Future.delayed(delay);
  }

  /// Stop speaking immediately.
  Future<void> stop() => _tts.stop();
}
