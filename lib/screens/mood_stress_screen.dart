// lib/screens/mood_stress_screen.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mood_entry.dart';
import '../providers/mood_provider.dart';
import '../providers/voice_controller.dart'
    show voiceControllerProvider, ttsProvider, micLevelStreamProvider, geminiProvider;

//
// ── Purple theme like your screenshot
//
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

const _good = Color(0xFF10B981);
const _okay = Color(0xFF8B5CF6);
const _bad  = Color(0xFFEF4444);

class MoodStressScreen extends ConsumerWidget {
  const MoodStressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(moodListProvider);
    final last7 = ref.read(moodListProvider.notifier).last7Days();
    final counts = ref.read(moodListProvider.notifier).counts(last7);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgBottom],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: const _PurpleHeader(),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _LargeButtonsRow(
                onTap: (mood) async {
                  await ref.read(moodListProvider.notifier).log(mood);
                  await ref.read(ttsProvider).speak('Mood logged successfully.');
                  HapticFeedback.selectionClick();
                },
              ),
              const SizedBox(height: 16),
              _VoiceCard(
                onListen: () => ref.read(voiceControllerProvider).captureAndLog(),
              ),
              const SizedBox(height: 20),
              _WeeklySummary(counts: counts),
              const SizedBox(height: 12),
              _WeeklyChart(entries: last7),
              const SizedBox(height: 24),
              _SpeakSummaryButton(counts: counts),
            ],
          ),
        ),
      ),
    );
  }
}

//
// ── Header styled like your photo
//
class _PurpleHeader extends StatelessWidget implements PreferredSizeWidget {
  const _PurpleHeader();

  @override
  Size get preferredSize => const Size.fromHeight(92);

  @override
  Widget build(BuildContext context) {
    return PreferredSize(
      preferredSize: preferredSize,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgTop],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D), // solid black capsule
              borderRadius: BorderRadius.circular(40), // <- capsule shape
              border: Border.all(color: _cardOutline),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Leading round icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_accent2, _accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.book_rounded, color: _text),
                ),
                const SizedBox(width: 12),

                // ↓↓↓ FIX: Flexible (loose) + mainAxisSize.min and slightly smaller fonts/gap
                Flexible(
                  fit: FlexFit.loose,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Mood Tracker', // or 'Mood & Stress Tracker'
                        style: TextStyle(
                          color: _text,
                          fontSize: 16,          // was 18
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),       // was 4–6
                      _SubtitleChips(           // chips row is compact
                        // (No change needed in the widget, but we’ll reduce its font below)
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Trailing circular action
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent,
                  ),
                  child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                ),
              ],
            )

          ),
        ),
      ),
    );
  }
}


class _SubtitleChips extends StatelessWidget {
  const _SubtitleChips();

  @override
  Widget build(BuildContext context) {
    Widget dot() => Container(
      width: 6, height: 6,
      decoration: const BoxDecoration(color: _chipDot, shape: BoxShape.circle),
    );
    Widget chip(String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: _mutedText,
            fontSize: 11.5,   // was 12–12.5
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return Row(
      children: [
        chip('Good'),
        const SizedBox(width: 12),
        chip('Okay'),
        const SizedBox(width: 12),
        chip('Bad'),
      ],
    );
  }
}

//
// ── Big mood buttons
//
class _LargeButtonsRow extends StatelessWidget {
  const _LargeButtonsRow({required this.onTap});
  final void Function(Mood mood) onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _BigMoodButton(label: '😊 Good', color: _good, onPressed: () => onTap(Mood.good))),
        const SizedBox(width: 12),
        Expanded(child: _BigMoodButton(label: '😐 Okay', color: _okay, onPressed: () => onTap(Mood.okay))),
        const SizedBox(width: 12),
        Expanded(child: _BigMoodButton(label: '🥲 Bad',  color: _bad,  onPressed: () => onTap(Mood.bad))),
      ],
    );
  }
}

class _BigMoodButton extends StatelessWidget {
  const _BigMoodButton({required this.label, required this.color, required this.onPressed});
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(64),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: Text(label),
      ),
    );
  }
}

//
// ── Voice card with mic meter
//
class _VoiceCard extends ConsumerWidget {
  const _VoiceCard({required this.onListen});
  final Future<void> Function() onListen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelAsync = ref.watch(micLevelStreamProvider);
    final raw = levelAsync.value ?? 0.0;
    final normalized = (raw / 30).clamp(0.0, 1.0);

    return Card(
      elevation: 0,
      color: _card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _cardOutline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_accent2, _accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(Icons.mic_rounded, color: _text, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Say: “Log mood good / okay / bad”.',
                    style: TextStyle(color: _text),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onListen,
                  icon: const Icon(Icons.record_voice_over_rounded),
                  label: const Text('Record'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(140, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MicLevelBar(value: normalized),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Quiet', style: TextStyle(fontSize: 12, color: _mutedText)),
                Text('Loud',  style: TextStyle(fontSize: 12, color: _mutedText)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MicLevelBar extends StatelessWidget {
  const _MicLevelBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      decoration: BoxDecoration(
        color: _muted,
        borderRadius: BorderRadius.circular(10),
        // ✅ FIX: BoxDecoration.border needs a BoxBorder, not BorderSide
        border: Border.all(color: _cardOutline),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth * value;
          return Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: width,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accent2, _accent],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

//
// ── Weekly summary (fixed: no followedBy on Column)
//
class _WeeklySummary extends StatelessWidget {
  const _WeeklySummary({required this.counts});
  final ({int good, int okay, int bad}) counts;

  @override
  Widget build(BuildContext context) {
    final total = counts.good + counts.okay + counts.bad;
    final trend = (counts.good > counts.bad)
        ? 'getting better'
        : (counts.bad > counts.good ? 'getting harder' : 'steady');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('This Week',
            style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Logged $total moods: ${counts.good} good, ${counts.okay} okay, ${counts.bad} bad. Trend: $trend.',
          style: const TextStyle(color: _mutedText),
        ),
      ],
    );
  }
}

//
// ── Weekly chart
//
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.entries});
  final List<MoodEntry> entries;

  static const _moodToY = {Mood.bad: 1.0, Mood.okay: 2.0, Mood.good: 3.0};
  static const _moodColor = {Mood.good: _good, Mood.okay: _okay, Mood.bad: _bad};
  static const _moodLabel = {Mood.good: 'Good', Mood.okay: 'Okay', Mood.bad: 'Bad'};

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(
      7,
          (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)),
    );

    final byDay = <DateTime, Mood?>{for (final d in days) d: null};
    for (final e in entries) {
      final key = DateTime(e.at.year, e.at.month, e.at.day);
      if (byDay.containsKey(key)) byDay[key] = e.mood;
    }

    final groups = <BarChartGroupData>[];
    for (var i = 0; i < days.length; i++) {
      final mood = byDay[days[i]];
      final y = mood == null ? 0.0 : _moodToY[mood]!;
      final color = mood == null ? const Color(0xFF2A3244) : _moodColor[mood]!;

      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: y,
              width: 18,
              borderRadius: BorderRadius.circular(8),
              color: color,
            ),
          ],
        ),
      );
    }

    String weekdayShort(DateTime d) {
      const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      return names[d.weekday % 7];
    }

    return Card(
      elevation: 0,
      color: _card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _cardOutline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mood over last 7 days',
                style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  barGroups: groups,
                  maxY: 3,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    getDrawingHorizontalLine: (v) => const FlLine(
                      color: Color(0x22FFFFFF),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                    getDrawingVerticalLine: (v) => const FlLine(
                      color: Color(0x11FFFFFF),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (v, _) {
                          final t = v.toInt();
                          final text = switch (t) {
                            0 => '',
                            1 => 'Bad',
                            2 => 'Okay',
                            3 => 'Good',
                            _ => '',
                          };
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(text,
                                style: const TextStyle(
                                    color: _mutedText, fontSize: 12, fontWeight: FontWeight.w600)),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt().clamp(0, days.length - 1);
                          final d = days[i];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(weekdayShort(d),
                                style: const TextStyle(color: _mutedText, fontSize: 11)),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      tooltipRoundedRadius: 8,
                      getTooltipItem: (group, _, rod, __) {
                        final d = days[group.x.toInt()];
                        final mood = byDay[d];
                        final label = mood == null ? 'No entry' : _moodLabel[mood]!;
                        return BarTooltipItem(
                          '${weekdayShort(d)} • $label',
                          const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const _MoodLegend(),
          ],
        ),
      ),
    );
  }
}

class _MoodLegend extends StatelessWidget {
  const _MoodLegend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String label) => Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(color: _mutedText, fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
    return Row(children: [
      const SizedBox(width: 4),
      item(_good, 'Good'),
      const SizedBox(width: 16),
      item(_okay, 'Okay'),
      const SizedBox(width: 16),
      item(_bad, 'Bad'),
    ]);
  }
}

//
// ── Speak weekly summary + Gemini advice
//
class _SpeakSummaryButton extends ConsumerStatefulWidget {
  const _SpeakSummaryButton({required this.counts, super.key});
  final ({int good, int okay, int bad}) counts;

  @override
  ConsumerState<_SpeakSummaryButton> createState() => _SpeakSummaryButtonState();
}

class _SpeakSummaryButtonState extends ConsumerState<_SpeakSummaryButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : _onPressed,
      icon: _loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.volume_up_rounded),
      label: Text(_loading ? 'Getting advice…' : 'Speak Weekly Summary',
          style: const TextStyle(color: _text)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _cardOutline),
        backgroundColor: _card,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        foregroundColor: _text,
      ),
    );
  }

  Future<void> _onPressed() async {
    setState(() => _loading = true);
    final counts = widget.counts;

    final total = counts.good + counts.okay + counts.bad;
    final trend = (counts.good > counts.bad)
        ? 'getting better'
        : (counts.bad > counts.good ? 'getting harder' : 'steady');

    final summary =
        'This week you logged $total moods: ${counts.good} good, '
        '${counts.okay} okay, ${counts.bad} bad. Trend: $trend.';

    await ref.read(ttsProvider).speak(summary);

    final last7 = ref.read(moodListProvider.notifier).last7Days();
    final advice = await ref.read(geminiProvider).weeklyAdvice(
      good: counts.good,
      okay: counts.okay,
      bad: counts.bad,
      last7: last7,
      locale: 'en', // 'ms' for Malay
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (advice == null) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: _card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Supportive tip', style: TextStyle(color: _text)),
          content: const Text(
            'Sorry, I can’t get an AI tip right now. Please try again later.',
            style: TextStyle(color: _mutedText, fontSize: 16, height: 1.35),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ],
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supportive tip', style: TextStyle(color: _text)),
        content: SingleChildScrollView(
          child: Text(advice, style: const TextStyle(color: _mutedText, fontSize: 16, height: 1.35)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ElevatedButton.icon(
            onPressed: () async => ref.read(ttsProvider).speak(advice),
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('Speak tip'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
