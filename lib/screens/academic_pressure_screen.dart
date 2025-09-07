// lib/screens/academic_pressure_screen.dart
import 'dart:convert';
import 'dart:math';

import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

/// =============================================================
///  Smart Academic Pressure Assistant (voice-first)
///  - Solid purple page background (no gradient)
///  - Black capsule AppBar (like mood screen)
///  - STT mic, TTS fixed to 0.50
///  - Short Advisor (auto-speak) + Stress score
/// =============================================================

/// ── THEME (shared with mood screen) ───────────────────────────
const _bgTop = Color(0xFF2A1B4A);
const _bgBottom = Color(0xFF190F33);
const _card = Color(0xFF1E163A);
const _cardOutline = Color(0x22FFFFFF);
const _chipDot = Color(0xFF7C5CFF);
const _accent = Color(0xFF5B3DFF);
const _accent2 = Color(0xFF5B3DFF);
const _text = Colors.white;
const _mutedText = Color(0xFFE5E7EB);
const _muted = Color(0xFF0F0B23);

class PillColors {
  static const bgTop = _bgTop;
  static const bgBottom = _bgBottom; // we use this for the whole page (solid)

  static const card = _card;
  static const cardOutline = _cardOutline;

  static const text = _text;
  static const textMuted = _mutedText;

  static const chipDot = _chipDot;
  static const primary = _accent;
  static const primaryDeep = _accent2;

  static const track = _muted;

  static const success = Color(0xFF10B981);
  static const warn = Color(0xFFFF8B3D);
  static const danger = Color(0xFFEF4444);

  static const surface = card;
  static const surfaceAlt = card;
  static const onSurface = text;
  static const onSurfaceMuted = textMuted;
  static const borderSoft = cardOutline;
  static const trackLight = track;

  static const softShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 24,
      spreadRadius: -2,
      offset: Offset(0, 14),
    ),
  ];
}

/// ── DATA ──────────────────────────────────────────────────────
class VoiceTask {
  VoiceTask({required this.id, required this.title, this.due, this.done = false});
  final String id;
  final String title;
  DateTime? due;
  bool done;
}

/// ── STRESS ANALYZER (same math) ───────────────────────────────
class StressAnalyzer {
  static double scoreFrom(List<VoiceTask> tasks) {
    if (tasks.isEmpty) return 0;
    final now = DateTime.now();
    final pending = tasks.where((t) => !t.done).toList();
    if (pending.isEmpty) return 0;

    double sum = 0;
    for (final t in pending) {
      final d = t.due;
      final days = d == null ? 21.0 : max(0.0, d.difference(now).inHours / 24.0);
      final urgency = (days <= 1)
          ? 1.0
          : (days <= 3)
          ? 0.7
          : (days <= 7)
          ? 0.45
          : (days <= 14)
          ? 0.25
          : 0.12;
      sum += urgency * 100;
    }

    final byDay = <DateTime, int>{};
    for (final t in pending) {
      if (t.due == null) continue;
      final day = DateTime(t.due!.year, t.due!.month, t.due!.day);
      byDay.update(day, (v) => v + 1, ifAbsent: () => 1);
    }
    final clusterPenalty = byDay.values.fold<double>(0, (p, c) => p + max(0, c - 1) * 6.0);
    final raw = (sum / pending.length) + clusterPenalty;
    return raw.clamp(0, 100);
  }

  static ({String label, Color color}) band(double score) {
    if (score >= 70) return (label: 'High', color: PillColors.danger);
    if (score >= 40) return (label: 'Moderate', color: PillColors.warn);
    return (label: 'Low', color: PillColors.success);
  }
}

/// ── SCREEN ────────────────────────────────────────────────────
class AcademicPressureScreen extends StatefulWidget {
  const AcademicPressureScreen({super.key});
  @override
  State<AcademicPressureScreen> createState() => _AcademicPressureScreenState();
}

class _AcademicPressureScreenState extends State<AcademicPressureScreen> {
  // Highlight words for transcript (visual)
  final Map<String, HighlightedWord> _highlights = {
    'task': HighlightedWord(
      onTap: () {},
      textStyle: const TextStyle(color: PillColors.primary, fontWeight: FontWeight.w800),
    ),
    'tomorrow': HighlightedWord(
      onTap: () {},
      textStyle: const TextStyle(color: PillColors.success, fontWeight: FontWeight.w800),
    ),
  };

  // Core services
  late final stt.SpeechToText _speech = stt.SpeechToText();
  late final FlutterTts _tts = FlutterTts();
  late final GenerativeModel _gemini = GenerativeModel(
    model: 'gemini-2.0-flash',
    apiKey: ('GEMINI_KEY'),
  );

  bool _isListening = false;
  bool _aiBusy = false;
  String _text = 'Tap the mic and speak.';
  String _reply = '';
  String _advice = '';
  double _confidence = 1.0;

  static const double _kTtsRate = 0.50;

  final List<VoiceTask> _tasks = [];

  @override
  void initState() {
    super.initState();
    _applyTtsSettings();
  }

  Future<void> _applyTtsSettings() async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(_kTtsRate);
    await _tts.awaitSpeakCompletion(true);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        content: Text(msg, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  // ── STT ──
  Future<void> _toggleListen() async {
    await HapticFeedback.selectionClick();
    if (!_isListening) {
      final ok = await _speech.initialize(
        onStatus: (s) => debugPrint('STT: $s'),
        onError: (e) => _snack('Speech error: $e'),
      );
      if (!mounted) return;
      if (!ok) {
        _snack('Microphone permission denied or speech not available.');
        return;
      }
      setState(() => _isListening = true);

      await _speech.listen(
        listenFor: const Duration(minutes: 2),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
        onResult: (val) async {
          setState(() {
            if (val.recognizedWords.isNotEmpty) _text = val.recognizedWords;
            if (val.hasConfidenceRating && val.confidence > 0) _confidence = val.confidence;
          });
          if (val.finalResult) {
            await _speech.stop();
            if (mounted) setState(() => _isListening = false);
            final utterance = _text.trim();
            if (utterance.isNotEmpty) await _routeVoiceCommand(utterance);
          }
        },
      );
    } else {
      setState(() => _isListening = false);
      await _speech.stop();
    }
  }

  // ── Router ──
  Future<void> _routeVoiceCommand(String userText) async {
    final parsed = await _nlu(userText);
    switch (parsed.intent) {
      case 'add':
        final t = _addTask(parsed.title, parsed.due);
        setState(() => _reply = 'Added "${t.title}"${t.due != null ? ' (due ${_fmt(t.due!)})' : ''}.');
        await _speak('Added ${t.title}${t.due != null ? " due ${_fmt(t.due!)}" : ""}');
        break;
      case 'complete':
        final ok = _completeTask(parsed.title);
        setState(() => _reply = ok ? 'Marked "${parsed.title}" done.' : 'Could not find "${parsed.title}".');
        await _speak(ok ? 'Marked ${parsed.title} done' : 'Sorry, I could not find ${parsed.title}');
        break;
      case 'delete':
        final ok2 = _deleteTask(parsed.title);
        setState(() => _reply = ok2 ? 'Deleted "${parsed.title}".' : 'Could not find "${parsed.title}".');
        await _speak(ok2 ? 'Deleted ${parsed.title}' : 'Sorry, I could not find ${parsed.title}');
        break;
      case 'list':
        await _listTasks();
        break;
      default:
        await _askGeminiAndSpeak(userText);
    }
    setState(() {});
    await _refreshAdvice(); // auto-speak short advice
  }

  // ── NLU ──
  Future<_Intent> _nlu(String userText) async {
    final nowIso = DateTime.now().toIso8601String();
    final prompt = '''
You are an intent parser for a voice to-do app.
Return JSON ONLY with keys: intent, title, due_iso.
- intent ∈ ["add","complete","delete","list","other"]
- title: short text or "" if none
- due_iso: ISO 8601 or "" (resolve relative terms using now=$nowIso)

User: "$userText"
JSON:
''';
    try {
      final res = await _gemini.generateContent([Content.text(prompt)]);
      final raw = (res.text ?? '').trim();
      final i = raw.indexOf('{'), j = raw.lastIndexOf('}');
      if (i == -1 || j == -1) return _Intent.other();
      final m = jsonDecode(raw.substring(i, j + 1)) as Map<String, dynamic>;
      final intent = (m['intent'] ?? 'other').toString();
      final title = (m['title'] ?? '').toString().trim();
      final dueRaw = (m['due_iso'] ?? '').toString().trim();
      DateTime? due;
      if (dueRaw.isNotEmpty) {
        try {
          due = DateTime.parse(dueRaw);
        } catch (_) {}
      }
      return _Intent(intent: intent, title: title, due: due);
    } catch (_) {
      return _Intent.other();
    }
  }

  // ── Advisor (short, plain, no symbols) ──
  Future<void> _refreshAdvice() async {
    if (_aiBusy) return;

    final stress = StressAnalyzer.scoreFrom(_tasks).round();
    final band = StressAnalyzer.band(stress.toDouble()).label;
    final taskLine = _tasks.isEmpty
        ? 'no tasks'
        : _tasks
        .map((t) {
      final due = t.due != null ? t.due!.toIso8601String() : 'no date';
      return '${t.title} (${t.done ? "done" : "pending"}, $due)';
    })
        .join('; ');

    final prompt = '''
You are an academic assistant for disabled students.
Based on stress and tasks, give a very short, plain suggestion in 1 or 2 simple sentences.
Do not use symbols or lists. Be direct and supportive.

Stress band: $band
Stress score: $stress
Tasks: $taskLine
''';

    try {
      setState(() => _aiBusy = true);
      final resp = await _gemini.generateContent([Content.text(prompt)]);
      var txt = (resp.text ?? '').trim();

      txt = txt.replaceAll(RegExp(r'[*`•\-_]'), '').trim();
      if (txt.length > 180) txt = txt.substring(0, 180);

      if (mounted) {
        setState(() => _advice = txt);
        if (txt.isNotEmpty) await _safeSpeak(txt);
      }
    } catch (e) {
      _snack('Advisor error: $e');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  // ── Tasks ──
  VoiceTask _addTask(String title, DateTime? due) {
    final t = VoiceTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'Untitled task' : title,
      due: due,
    );
    _tasks.add(t);
    return t;
  }

  bool _completeTask(String title) {
    final i = _tasks.indexWhere((t) => t.title.toLowerCase() == title.toLowerCase());
    if (i == -1) return false;
    _tasks[i].done = true;
    return true;
  }

  bool _deleteTask(String title) {
    final i = _tasks.indexWhere((t) => t.title.toLowerCase() == title.toLowerCase());
    if (i == -1) return false;
    _tasks.removeAt(i);
    return true;
  }

  Future<void> _listTasks() async {
    if (_tasks.isEmpty) {
      setState(() => _reply = 'Your to-do list is empty.');
      await _speak('Your to-do list is empty');
      return;
    }
    final parts = _tasks
        .map((t) {
      final status = t.done ? 'done' : 'pending';
      final when = t.due != null ? ' due ${_fmt(t.due!)}' : '';
      return '${t.title}$when ($status)';
    })
        .toList();
    final msg = 'You have ${_tasks.length} tasks: ${parts.join(', ')}.';
    setState(() => _reply = msg);
    await _speak(msg);
  }

  // ── Chat fallback ──
  Future<void> _askGeminiAndSpeak(String userText) async {
    if (_aiBusy) return;
    setState(() => _aiBusy = true);
    try {
      final resp = await _gemini.generateContent([
        Content.text('Reply helpfully in no more than two short sentences. User said: "$userText"')
      ]);
      final ai = (resp.text ?? 'Sorry, I’m not sure what to say.').trim();
      setState(() => _reply = ai);
      await _safeSpeak(ai);
    } catch (e) {
      _snack('Gemini API error: $e');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  // ── TTS ──
  Future<void> _safeSpeak(String text) async {
    try {
      await _tts.stop();
    } catch (_) {}
    try {
      await _tts.setSpeechRate(_kTtsRate);
      await _tts.speak(text);
    } catch (e) {
      _snack('TTS speak error: $e');
    }
  }

  Future<void> _speak(String text) => _safeSpeak(text);

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    final stress = StressAnalyzer.scoreFrom(_tasks);
    final band = StressAnalyzer.band(stress);
    final confPct = (_confidence * 100).clamp(0, 100).toStringAsFixed(1);

    return Scaffold(
      backgroundColor: PillColors.bgBottom, // solid purple background
      appBar: CapsuleAppBar(
        title: 'Academic Assistant',
        statusLeft: 'Auto',
        statusMiddle: _isListening ? 'Listening' : 'Status',
        statusRight: 'Assistant',
        onAction: _refreshAdvice,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AvatarGlow(
        animate: _isListening,
        glowColor: PillColors.primary,
        duration: const Duration(milliseconds: 2000),
        repeat: true,
        glowShape: BoxShape.circle,
        glowRadiusFactor: 0.85,
        child: Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [PillColors.primaryDeep, PillColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 24,
                spreadRadius: -4,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: FloatingActionButton(
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            onPressed: _toggleListen,
            child: Icon(_isListening ? Icons.stop : Icons.mic, size: 32),
          ),
        ),
      ),
      body: SingleChildScrollView(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        child: Column(
          children: [
            CapsuleSection(
              child: _StressCard(score: stress, bandLabel: band.label, bandColor: band.color),
            ),
            const SizedBox(height: 12),
            CapsuleSection(
              child: _TranscriptPanel(
                text: _text,
                isListening: _isListening,
                highlights: _highlights,
                confidence: _confidence,
                confLabel: 'Conf $confPct%',
              ),
            ),
            const SizedBox(height: 12),
            if (_advice.isNotEmpty)
              CapsuleSection(
                child: _AdvisorCard(text: _advice, onSpeak: () => _safeSpeak(_advice)),
              ),
            if (_reply.isNotEmpty) ...[
              const SizedBox(height: 12),
              CapsuleSection(child: _AssistantCard(text: _reply, onSpeak: () => _safeSpeak(_reply))),
            ],
            if (_tasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              CapsuleSection(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('Your Tasks'),
                    const SizedBox(height: 6),
                    ..._tasks.map(
                          (t) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: PillColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: PillColors.borderSoft, width: 1),
                          boxShadow: PillColors.softShadow,
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Checkbox(
                            value: t.done,
                            onChanged: (v) async {
                              setState(() => t.done = v ?? false);
                              await _refreshAdvice();
                            },
                            side: const BorderSide(color: PillColors.primary, width: 2),
                            activeColor: PillColors.primary,
                            checkColor: Colors.white,
                          ),
                          title: Text(
                            t.title,
                            style: TextStyle(
                              color: PillColors.onSurface,
                              fontWeight: FontWeight.w700,
                              decoration: t.done ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: t.due != null
                              ? Text('Due ${_fmt(t.due!)}',
                              style: const TextStyle(color: PillColors.onSurfaceMuted))
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: PillColors.danger),
                            onPressed: () async {
                              setState(() => _tasks.remove(t));
                              await _refreshAdvice();
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final mm = d.minute.toString().padLeft(2, '0');
    final am = d.hour < 12 ? 'AM' : 'PM';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} $h:$mm $am';
  }
}

/// ── AppBar & shared widgets ───────────────────────────────────
class CapsuleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CapsuleAppBar({
    super.key,
    required this.title,
    required this.statusLeft,
    required this.statusMiddle,
    required this.statusRight,
    required this.onAction,
  });

  final String title;
  final String statusLeft;
  final String statusMiddle;
  final String statusRight;
  final VoidCallback onAction;

  @override
  Size get preferredSize => const Size.fromHeight(92);

  @override
  Widget build(BuildContext context) {
    final padTop = MediaQuery.of(context).padding.top;
    return PreferredSize(
      preferredSize: preferredSize,
      child: Container(
        color: PillColors.bgBottom, // same as page background (no divider line)
        padding: EdgeInsets.fromLTRB(16, padTop + 10, 16, 12),
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D), // black capsule
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: PillColors.cardOutline),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [PillColors.primaryDeep, PillColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Academic Assistant',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const _Dot(color: PillColors.chipDot),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$statusLeft  •  $statusMiddle  •  $statusRight',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: PillColors.textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: PillColors.primary,
                    ),
                    child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CapsuleSection extends StatelessWidget {
  const CapsuleSection({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PillColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: PillColors.cardOutline, width: 1),
        boxShadow: PillColors.softShadow,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: child,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: PillColors.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _StressCard extends StatelessWidget {
  const _StressCard({required this.score, required this.bandLabel, required this.bandColor});
  final double score;
  final String bandLabel;
  final Color bandColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const _SectionTitle('Stress Level'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: PillColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: bandColor, width: 1.4),
            ),
            child: Text(bandLabel, style: TextStyle(color: bandColor, fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: (score / 100).clamp(0, 1),
            minHeight: 16,
            backgroundColor: PillColors.trackLight,
            valueColor: AlwaysStoppedAnimation(bandColor),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${score.toStringAsFixed(0)} / 100',
            style: const TextStyle(color: PillColors.onSurfaceMuted, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _TranscriptPanel extends StatelessWidget {
  const _TranscriptPanel({
    required this.text,
    required this.isListening,
    required this.highlights,
    required this.confidence,
    this.confLabel,
  });

  final String text;
  final bool isListening;
  final Map<String, HighlightedWord> highlights;
  final double confidence;
  final String? confLabel;

  @override
  Widget build(BuildContext context) {
    final conf = (confidence <= 0 ? 0.01 : confidence).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: isListening ? PillColors.primary : PillColors.onSurfaceMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const _SectionTitle('Transcript'),
          const Spacer(),
          Text(
            confLabel ?? '${(conf * 100).toStringAsFixed(1)}%',
            style: const TextStyle(color: PillColors.onSurfaceMuted, fontWeight: FontWeight.w800),
          ),
        ]),
        const SizedBox(height: 10),
        TextHighlight(
          text: text,
          words: highlights,
          textAlign: TextAlign.left,
          textStyle: const TextStyle(
            fontSize: 24,
            height: 1.28,
            color: PillColors.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: conf,
            minHeight: 8,
            backgroundColor: PillColors.track,
            valueColor: const AlwaysStoppedAnimation(PillColors.primary),
          ),
        ),
      ],
    );
  }
}

class _AdvisorCard extends StatelessWidget {
  const _AdvisorCard({required this.text, required this.onSpeak});
  final String text;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lightbulb, color: Colors.white, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionTitle('Advisor'),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(color: PillColors.onSurface)),
          ]),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.volume_up, color: Colors.white),
          onPressed: onSpeak,
          tooltip: 'Speak advice',
        ),
      ],
    );
  }
}

class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.text, required this.onSpeak});
  final String text;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.smart_toy, color: Colors.white, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionTitle('Assistant'),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(color: PillColors.onSurface)),
          ]),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.volume_up, color: Colors.white),
          onPressed: onSpeak,
          tooltip: 'Speak reply',
        ),
      ],
    );
  }
}

class _Intent {
  final String intent; // add, complete, delete, list, other
  final String title;
  final DateTime? due;
  _Intent({required this.intent, required this.title, required this.due});
  factory _Intent.other() => _Intent(intent: 'other', title: '', due: null);
}
