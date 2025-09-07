import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/mood_entry.dart';
import '../services/gemini_nlp.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import 'mood_provider.dart';

// ---------- Providers (top-level) ----------
final ttsProvider = Provider<TtsService>((_) => TtsService());
final sttProvider = Provider<SttService>((_) => SttService());
final geminiProvider = Provider<GeminiNLP>((_) => GeminiNLP());

// Mic level stream (used by the UI meter)
final micLevelStreamProvider = StreamProvider<double>((ref) {
  return ref.read(sttProvider).levelStream;
});

final voiceControllerProvider = Provider<VoiceController>((ref) {
  return VoiceController(
    tts: ref.read(ttsProvider),
    stt: ref.read(sttProvider),
    classify: ref.read(geminiProvider).classifyMood,
    logMood: (m) => ref.read(moodListProvider.notifier).log(m),
  );
});

// ---------- Controller ----------
class VoiceController {
  VoiceController({
    required this.tts,
    required this.stt,
    required this.classify,
    required this.logMood,
  });

  final TtsService tts;
  final SttService stt;
  final Future<Mood?> Function(String) classify;
  final Future<void> Function(Mood) logMood;

  Future<void> captureAndLog() async {
    // 1) Speak prompt & wait until done
    await tts.speakThenDelay(
      'Listening. Please say: log mood good, okay, or bad.',
      delay: const Duration(milliseconds: 450),
    );

    // 2) Start listening (auto-stops 2s after silence, up to 10s)
    final heard = await stt.listenOnce(
      localeId: 'en_US', // or 'ms_MY'
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
    );

    if (heard == null) {
      await tts.speak('Sorry, I did not hear you. Please try again.');
      return;
    }

    final mood = await classify(heard);
    if (mood == null) {
      await tts.speak('Sorry, I could not understand. Please say: good, okay, or bad.');
      return;
    }

    await logMood(mood);
    await tts.speak('Mood logged successfully: ${_label(mood)}.');
  }

  String _label(Mood m) => switch (m) {
    Mood.good => 'good',
    Mood.okay => 'okay',
    Mood.bad => 'bad'
  };
}
