import 'dart:async';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';
import '../services/tts_service.dart';

class BreathingGuide {
  final TtsService tts;
  AudioPlayer? _inPlayer;
  AudioPlayer? _outPlayer;
  bool _audioReady = false;
  bool _audioTried = false;

  BreathingGuide(this.tts);

  Future<void> init() async {
    // Lazy init during first use
  }

  Future<void> _ensurePlayers() async {
    if (_audioTried) return;
    _audioTried = true;
    try {
      if (kIsWeb) {
        // If you didn’t add just_audio_web, we’ll fall back to TTS
        _audioReady = false;
        return;
      }
      _inPlayer = AudioPlayer();
      _outPlayer = AudioPlayer();
      await _inPlayer!.setAsset('assets/audio/breathe_in.mp3');
      await _outPlayer!.setAsset('assets/audio/breathe_out.mp3');
      _audioReady = true;
    } catch (_) {
      _audioReady = false; // fallback to TTS
    }
  }

  /// 1-minute box breathing: 4 in, 4 hold, 4 out, 4 hold
  Future<void> startOneMinute() async {
    await _ensurePlayers();

    final start = DateTime.now();
    while (DateTime.now().difference(start).inSeconds < 60) {
      await _cueIn(4);
      await _hold(4);
      await _cueOut(4);
      await _hold(4);
    }
    await tts.speak("Nice job. How do you feel now?");
  }

  Future<void> _cueIn(int seconds) async {
    await _playOrSpeak(_inPlayer, "Breathe in");
    await _hapticStrong();
    await Future.delayed(Duration(seconds: seconds));
  }

  Future<void> _cueOut(int seconds) async {
    await _playOrSpeak(_outPlayer, "Breathe out");
    await _hapticMedium();
    await Future.delayed(Duration(seconds: seconds));
  }

  Future<void> _hold(int seconds) async {
    await _hapticLight();
    await Future.delayed(Duration(seconds: seconds));
  }

  Future<void> _playOrSpeak(AudioPlayer? p, String fallbackText) async {
    if (_audioReady && p != null) {
      try {
        await p.seek(Duration.zero);
        await p.play();
        return;
      } catch (_) {/* fall through */}
    }
    await tts.speak(fallbackText);
  }

  // --- Haptics (no plugin needed) ---
  Future<void> _hapticLight() async {
    try { await HapticFeedback.selectionClick(); } catch (_) {}
  }

  Future<void> _hapticMedium() async {
    try { await HapticFeedback.lightImpact(); } catch (_) {}
  }

  Future<void> _hapticStrong() async {
    try { await HapticFeedback.mediumImpact(); } catch (_) {}
    // If you want a "longer" effect, chain a couple pulses:
    await Future.delayed(const Duration(milliseconds: 60));
    try { await HapticFeedback.mediumImpact(); } catch (_) {}
  }

  Future<void> dispose() async {
    try { await _inPlayer?.dispose(); } catch (_) {}
    try { await _outPlayer?.dispose(); } catch (_) {}
  }
}
