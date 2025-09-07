import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/mood_entry.dart';

const String _apiKey = ('GEMINI_KEY');

class GeminiNLP {
  final GenerativeModel _model =
  GenerativeModel(model: 'gemini-2.0-flash', apiKey: _apiKey);

  Future<Mood?> classifyMood(String text) async {
    final low = text.toLowerCase();
    if (low.contains('good') || low.contains('great') || low.contains('happy')) return Mood.good;
    if (low.contains('ok') || low.contains('okay') || low.contains('fine')) return Mood.okay;
    if (low.contains('bad') || low.contains('sad') || low.contains('stress') || low.contains('tired')) return Mood.bad;

    if (_apiKey.isEmpty) return null;
    final prompt = '''
You are an NLU for a student wellbeing app. Output ONE of: GOOD, OKAY, BAD.
Utterance: "$text"
Output:
''';
    try {
      final r = await _model.generateContent([Content.text(prompt)]);
      final out = (r.text ?? '').toUpperCase().trim();
      if (out.startsWith('GOOD')) return Mood.good;
      if (out.startsWith('OKAY') || out.startsWith('OK')) return Mood.okay;
      if (out.startsWith('BAD')) return Mood.bad;
    } catch (_) {}
    return null;
  }

  /// Gemini-only weekly advice (returns null if API/key/unavailable).
  Future<String?> weeklyAdvice({
    required int good,
    required int okay,
    required int bad,
    required List<MoodEntry> last7, // oldest..newest
    String locale = 'en',           // 'en' or 'ms'
  }) async {
    if (_apiKey.isEmpty) return null;

    final total = good + okay + bad;
    final lastMood = last7.isNotEmpty ? last7.last.mood.name : 'none';
    final loggedDays = last7.length;

    final langHint = (locale == 'ms')
        ? 'Gunakan Bahasa Melayu yang ringkas, profesional, dan mudah difahami.'
        : 'Use simple, supportive English.';

    final prompt = '''
You are a gentle coach for a university wellbeing app used by blind and motor-disabled students.
Based ONLY on the data below, give 2–3 SHORT bullet lines of supportive, actionable advice:
- Be kind, specific, non-judgmental.
- Offer one simple action for TODAY (e.g., "5-min stretch", "box breathing 4-4-4-4", "ask a friend for notes").
- If most days are "bad", gently suggest campus help lines (no alarming language).
- Avoid medical/clinical claims; no diagnosis.
- No emojis. No preamble. Bulleted lines only.

$langHint

Data (last 7 days):
- total_logged: $total (loggedDays=$loggedDays)
- counts: good=$good, okay=$okay, bad=$bad
- last_mood: $lastMood

Respond with max 3 bullet lines.
''';

    try {
      final r = await _model.generateContent([Content.text(prompt)]);
      final text = r.text?.trim();
      if (text == null || text.isEmpty) return null;
      return text.split('\n').where((l) => l.trim().isNotEmpty).take(6).join('\n').trim();
    } catch (_) {
      return null;
    }
  }
}
