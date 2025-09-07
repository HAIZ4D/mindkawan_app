import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SttService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _initialized = false;

  final _levelCtrl = StreamController<double>.broadcast();
  Stream<double> get levelStream => _levelCtrl.stream;

  bool get isInitialized => _initialized;
  bool get isListening => _speech.isListening;

  Future<bool> _ensureInit() async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(onStatus: (_) {}, onError: (_) {});
    return _initialized;
  }

  /// One-shot capture (kept for other screens).
  Future<String?> listenOnce({
    String localeId = 'en_US',
    Duration listenFor = const Duration(seconds: 10),
    Duration pauseFor = const Duration(seconds: 2),
  }) async {
    if (!await _ensureInit()) return null;

    if (!await _speech.hasPermission) {
      final ok = await _speech.initialize();
      if (!ok || !await _speech.hasPermission) return null;
    }

    final resultCompleter = Completer<String?>();
    String? finalText;

    await _speech.listen(
      localeId: localeId,
      listenMode: stt.ListenMode.confirmation,
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: true,
      onSoundLevelChange: (level) {
        _levelCtrl.add(level);
      },
      onResult: (r) {
        if (r.recognizedWords.isNotEmpty) finalText = r.recognizedWords;
        if (r.finalResult && !resultCompleter.isCompleted) {
          resultCompleter.complete(finalText);
        }
      },
    );

    final text = await resultCompleter.future.timeout(
      listenFor + const Duration(seconds: 2),
      onTimeout: () async {
        await _speech.stop();
        return finalText;
      },
    );

    await _speech.stop();
    _levelCtrl.add(0.0);
    return (text == null || text.trim().isEmpty) ? null : text.trim();
  }

  /// Continuous capture for Voice Buddy.
  Future<bool> listenContinuous({
    String localeId = 'en_US',
    Duration? listenFor,
    Duration pauseFor = const Duration(seconds: 2),
    required void Function(String partial) onPartial,
    required void Function(String finalText) onFinal,
    required void Function(double level) onSoundLevel,
  }) async {
    if (!await _ensureInit()) return false;

    if (!await _speech.hasPermission) {
      final ok = await _speech.initialize();
      if (!ok || !await _speech.hasPermission) return false;
    }

    await _speech.listen(
      localeId: localeId,
      listenMode: stt.ListenMode.confirmation,
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: true,
      onSoundLevelChange: (level) {
        _levelCtrl.add(level);
        onSoundLevel(level);
      },
      onResult: (r) {
        final text = r.recognizedWords.trim();
        if (text.isEmpty) return;
        if (r.finalResult) {
          onFinal(text);
        } else {
          onPartial(text);
        }
      },
    );
    return true;
  }

  Future<void> stop() async {
    await _speech.stop();
    _levelCtrl.add(0.0);
  }

  Future<void> cancel() async {
    await _speech.cancel();
    _levelCtrl.add(0.0);
  }

  void dispose() {
    _levelCtrl.close();
  }
}
