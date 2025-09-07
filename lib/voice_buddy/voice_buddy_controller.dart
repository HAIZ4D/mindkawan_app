import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/emotion_analyzer.dart';
import '../logic/intent_router.dart';
import '../logic/buddy_memory.dart';
import '../flows/breathing_guide.dart';
import '../flows/story_bank.dart';

class VoiceBuddyController {
  final TtsService tts;
  final SttService stt;
  final EmotionAnalyzer emotion;
  final IntentRouter router;
  final BuddyMemory memory;
  final BreathingGuide breathing;

  double _avgSound = 0;
  int _soundSamples = 0;

  VoiceBuddyController({
    required this.tts,
    required this.stt,
    required this.emotion,
    required this.router,
    required this.memory,
    required this.breathing,
  });

  Future<void> init() async {
    await breathing.init();
  }


  Future<void> startListening({
    required void Function(String partial) onPartial,
    required void Function(String finalText) onFinal,
    required void Function(bool listening) onState,
  }) async {
    onState(true);
    _avgSound = 0; _soundSamples = 0;

    await stt.listenContinuous(
      onPartial: (p) => onPartial(p),
      onFinal: (f) async {
        try {
          memory.rememberUser(f);
          onFinal(f);

          final flag = emotion.analyze(
            avgSoundLevel: _soundSamples == 0 ? 0 : _avgSound / _soundSamples,
            textSnapshot: f,
          );

          if (flag.likelyStressed) {
            await tts.speak("I sense some stress in your voice. Would you like a calming one minute breathing exercise?");
            memory.rememberOptions("calming exercise or skip", ["calming", "exercise", "skip", "breathing"]);
            await stt.stop();
            onState(false);
            return;
          }

          await _route(f);
        } catch (e) {
          await tts.speak("Sorry, I ran into a small error. Please try again.");
        } finally {
          await stt.stop();
          onState(false);
        }
      },

      onSoundLevel: (level) {
        _avgSound += level;
        _soundSamples++;
      },
    );
  }

  Future<void> stopListening({
    required void Function(bool listening) onState,
  }) async {
    await stt.stop();
    onState(false);
  }

  Future<void> _route(String userText) async {
    final quick = memory.resolveShortReply(userText);
    if (quick != null) {
      switch (quick) {
        case "music":
          await _handlePlayMusic(); return;
        case "log":
        case "feeling":
          await _handleLogFeeling(); return;
        case "breathing":
        case "calming":
        case "exercise":
          await _handleBreathing(); return;
        case "skip":
          await tts.speak("Okay, we can skip for now. I’m here when you need me.");
          memory.clear(); return;
      }
    }

    final intent = router.detect(userText);
    switch (intent) {
      case BuddyIntent.feelingAnxious:
        await tts.speak("I understand. Would you like me to play calming music, log this feeling, or start a one minute breathing exercise?");
        memory.rememberOptions("play music, log feeling, or start breathing", ["music", "log", "breathing"]);
        break;
      case BuddyIntent.logFeeling:
        await _handleLogFeeling(); break;
      case BuddyIntent.playMusic:
        await _handlePlayMusic(); break;
      case BuddyIntent.startBreathing:
        await _handleBreathing(); break;
      case BuddyIntent.stressTomorrow:
        await tts.speak("Tomorrow you have an exam and a project check-in, so your stress may be high. Would you like me to prepare a two minute wind down tonight?");
        memory.rememberOptions("prepare wind down tonight?", ["yes", "no"]);
        break;
      case BuddyIntent.tellStory:
        final s = (List<String>.from(StoryBank.minuteStories)..shuffle()).first;
        await tts.speak(s); break;
      case BuddyIntent.safeWord:
        await _handleGrounding(); break;
      case BuddyIntent.unknown:
        await tts.speak("Got it. You can say things like, I feel anxious, start breathing, tell me a story, or play music.");
        break;
    }
  }

  Future<void> _handleLogFeeling() async {
    await tts.speak("I’ve logged your feeling. Thank you for sharing. Would you like a short story or breathing to feel calmer?");
    memory.rememberOptions("story or breathing", ["story", "breathing"]);
  }

  Future<void> _handlePlayMusic() async {
    await tts.speak("Playing calming soundscapes. Imagine a quiet beach. If you prefer, I can guide your breathing too.");
    memory.rememberOptions("continue music or breathing?", ["continue", "breathing", "stop"]);
  }

  Future<void> _handleBreathing() async {
    await tts.speak("Let’s do one minute of box breathing together. Follow the cues.");
    await breathing.startOneMinute();
    memory.clear();
  }

  Future<void> _handleGrounding() async {
    await tts.speak("I’m here. Let’s ground together. Name five things you can feel touching you.");
    memory.clear();
  }
}
