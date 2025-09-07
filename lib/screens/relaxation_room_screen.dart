import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// ─────────────────────────────────────────────────────────────
/// THEME (your colors)
/// ─────────────────────────────────────────────────────────────
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

/// ─────────────────────────────────────────────────────────────
/// DATA MODELS
/// ─────────────────────────────────────────────────────────────
enum BreathPhase { inhale, hold1, exhale, hold2 }

class BreathingTechnique {
  final String name;
  final List<_PhaseStep> steps;
  final String subtitle;

  const BreathingTechnique({
    required this.name,
    required this.steps,
    required this.subtitle,
  });

  static const boxBreathing = BreathingTechnique(
    name: "Box Breathing",
    subtitle: "Inhale 4 • Hold 4 • Exhale 4 • Hold 4",
    steps: [
      _PhaseStep(BreathPhase.inhale, 4),
      _PhaseStep(BreathPhase.hold1, 4),
      _PhaseStep(BreathPhase.exhale, 4),
      _PhaseStep(BreathPhase.hold2, 4),
    ],
  );

  static const fourSevenEight = BreathingTechnique(
    name: "4–7–8",
    subtitle: "Inhale 4 • Hold 7 • Exhale 8",
    steps: [
      _PhaseStep(BreathPhase.inhale, 4),
      _PhaseStep(BreathPhase.hold1, 7),
      _PhaseStep(BreathPhase.exhale, 8),
      _PhaseStep(BreathPhase.hold2, 0),
    ],
  );

  static const coherent = BreathingTechnique(
    name: "Coherent (5s)",
    subtitle: "Inhale 5 • Exhale 5",
    steps: [
      _PhaseStep(BreathPhase.inhale, 5),
      _PhaseStep(BreathPhase.exhale, 5),
    ],
  );

  static const all = [boxBreathing, fourSevenEight, coherent];
}

class _PhaseStep {
  final BreathPhase phase;
  final int seconds;
  const _PhaseStep(this.phase, this.seconds);
}

/// ─────────────────────────────────────────────────────────────
/// MAIN SCREEN
/// ─────────────────────────────────────────────────────────────
class RelaxationRoomScreen extends StatefulWidget {
  const RelaxationRoomScreen({super.key});

  @override
  State<RelaxationRoomScreen> createState() => _RelaxationRoomScreenState();
}

class _RelaxationRoomScreenState extends State<RelaxationRoomScreen>
    with TickerProviderStateMixin {
  String _tab = "Breathing";
  Set<String> _favs = {};

  // Breathing state
  BreathingTechnique _tech = BreathingTechnique.boxBreathing;
  int _stepIndex = 0;
  int _countdown = 0;
  bool _running = false;
  Timer? _tick;

  // Animation: controller 0..1, tween maps to 0.85..1.25 (safe for curves)
  late AnimationController _ctrl; // 0..1
  late Animation<double> _scale;  // 0.85..1.25

  // Text-to-Speech
  final FlutterTts _tts = FlutterTts();
  bool _voiceOn = true;

  // Audio (assets)
  final AudioPlayer _player = AudioPlayer();
  int? _currentIndex;
  bool _isPlaying = false;

  final List<Map<String, String>> _music = const [
    {"title": "Ocean Waves", "desc": "Calm sea sound", "asset": "assets/audio/ocean_waves.mp3"},
    {"title": "Forest Rain", "desc": "Rain & thunder", "asset": "assets/audio/forest_rain.mp3"},
    {"title": "Soft Piano", "desc": "Gentle melody", "asset": "assets/audio/soft_piano.mp3"},
    {"title": "Wind Chimes", "desc": "Light & airy", "asset": "assets/audio/wind_chimes.mp3"},
  ];

  @override
  void initState() {
    super.initState();

    // Anim controller in 0..1
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scale = Tween<double>(begin: 0.85, end: 1.25)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _applyStep(animated: false);
    _setupTts();

    _player.playerStateStream.listen((state) {
      final playing = state.playing;
      final completed = state.processingState == ProcessingState.completed;
      if (completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
      if (mounted) setState(() => _isPlaying = playing);
    });
  }

  Future<void> _setupTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.4);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ctrl.dispose();
    _player.dispose();
    _tts.stop();
    super.dispose();
  }

  // ── Breathing engine ────────────────────────────────────────
  void _start() {
    if (_running) return;
    setState(() => _running = true);

    // NEW: start animating right away instead of waiting 1s
    _applyStep(animated: true);

    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _pause() {
    _tick?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _tick?.cancel();
    _stepIndex = 0;
    _applyStep(animated: false);
    setState(() => _running = false);
  }

  void _onTick() {
    if (_countdown > 1) {
      setState(() => _countdown--);
      return;
    }
    _stepIndex = (_stepIndex + 1) % _tech.steps.length;
    _applyStep(animated: true);
  }

  Future<void> _speakPhase(String text) async {
    if (!_voiceOn) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  void _applyStep({required bool animated}) {
    final step = _tech.steps[_stepIndex];
    _countdown = step.seconds == 0 ? 1 : step.seconds;

    // Announce phase for accessibility
    switch (step.phase) {
      case BreathPhase.inhale:
        _speakPhase("Inhale for ${step.seconds} seconds");
        break;
      case BreathPhase.hold1:
      case BreathPhase.hold2:
        if (step.seconds > 0) _speakPhase("Hold for ${step.seconds} seconds");
        break;
      case BreathPhase.exhale:
        _speakPhase("Exhale for ${step.seconds} seconds");
        break;
    }

    // Animate between 0.0 (exhale) and 1.0 (inhale)
    if (animated) {
      switch (step.phase) {
        case BreathPhase.inhale:
          _ctrl.animateTo(1.0,
              duration: Duration(milliseconds: step.seconds * 1000),
              curve: Curves.easeInOut);
          break;
        case BreathPhase.exhale:
          _ctrl.animateTo(0.0,
              duration: Duration(milliseconds: step.seconds * 1000),
              curve: Curves.easeInOut);
          break;
        case BreathPhase.hold1:
        case BreathPhase.hold2:
        // keep current value; short idle to still trigger repaint
          _ctrl.animateTo(_ctrl.value,
              duration: Duration(milliseconds: step.seconds * 1000));
          break;
      }
    }
    setState(() {});
  }

  String get _phaseText {
    final p = _tech.steps[_stepIndex].phase;
    switch (p) {
      case BreathPhase.inhale:
        return "Inhale";
      case BreathPhase.hold1:
      case BreathPhase.hold2:
        return "Hold";
      case BreathPhase.exhale:
        return "Exhale";
    }
  }

  // ── Audio controls (assets) ─────────────────────────────────
  Future<void> _togglePlayAsset(int index) async {
    if (_currentIndex == index) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      setState(() {});
      return;
    }
    _currentIndex = index;
    final assetPath = _music[index]["asset"]!;
    try {
      await _player.setAsset(assetPath);
      await _player.setLoopMode(LoopMode.one);
      await _player.play();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to play "${_music[index]["title"]}".'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    setState(() {});
  }

  // ── UI ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBottom,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              _CapsuleAppBar(
                title: "Relaxation Room",
                subtitles: const ["Auto", "Calm", "Assistant"],
                onRefresh: _reset,
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _tabs(),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _tab == "Breathing" ? _breathingPane() : _musicPane(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tabs
  Widget _tabs() {
    Widget chip(String label, bool selected) => GestureDetector(
      onTap: () => setState(() => _tab = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _accent : _muted,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _mutedText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip("Breathing", _tab == "Breathing"),
        const SizedBox(width: 10),
        chip("Music", _tab == "Music"),
      ],
    );
  }

  // Breathing UI
  Widget _breathingPane() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // Technique selector
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: BreathingTechnique.all.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final t = BreathingTechnique.all[i];
              final sel = t.name == _tech.name;
              return GestureDetector(
                onTap: () {
                  _pause();
                  _tech = t;
                  _stepIndex = 0;
                  _applyStep(animated: false);

                  // NEW: if you prefer to keep it running seamlessly:
                  if (_running) {
                    _start(); // or: _applyStep(animated: true);
                  }
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? _accent : _card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cardOutline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.self_improvement,
                          size: 16, color: sel ? Colors.white : _mutedText),
                      const SizedBox(width: 8),
                      Text(
                        t.name,
                        style: TextStyle(
                          color: sel ? Colors.white : _mutedText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Ripple Waves visual + controls
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _cardOutline),
          ),
          child: Column(
            children: [
              Text(_tech.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _mutedText)),
              const SizedBox(height: 18),

              SizedBox(
                height: 260,
                child: Center(
                  child: CustomPaint(
                    painter: RipplePainter(
                      progress: _scale.value,
                      repaint: _ctrl, // listen to animation ticks
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_phaseText,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18)),
                          const SizedBox(height: 4),
                          Text("$_countdown s",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _roundBtn(
                    icon: _running ? Icons.pause : Icons.play_arrow,
                    onTap: _running ? _pause : _start,
                  ),
                  const SizedBox(width: 14),
                  _roundBtn(icon: Icons.refresh, onTap: _reset),
                  const SizedBox(width: 14),
                  _roundBtn(
                    icon: _voiceOn ? Icons.volume_up : Icons.volume_off,
                    onTap: () => setState(() => _voiceOn = !_voiceOn),
                    bg: _voiceOn ? _accent : _muted,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Tiny legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _LegendDot(label: "Inhale"),
            SizedBox(width: 14),
            _LegendDot(label: "Hold"),
            SizedBox(width: 14),
            _LegendDot(label: "Exhale"),
          ],
        ),
      ],
    );
  }

  // Music UI (assets)
  Widget _musicPane() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _music.length,
      itemBuilder: (context, i) {
        final item = _music[i];
        final fav = _favs.contains(item["title"]);
        final isCurrent = _currentIndex == i;
        final isPlayingThis = isCurrent && _isPlaying;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardOutline),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [_accent, _accent2]),
                ),
                child: const Icon(Icons.music_note, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item["title"]!,
                        style: const TextStyle(
                            color: _text,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(item["desc"]!,
                        style: const TextStyle(color: _mutedText)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  fav ? Icons.favorite : Icons.favorite_border,
                  color: fav ? Colors.red : _mutedText,
                ),
                onPressed: () {
                  setState(() {
                    fav ? _favs.remove(item["title"]) : _favs.add(item["title"]!);
                  });
                },
              ),
              Material(
                color: _accent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _togglePlayAsset(i),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      isPlayingThis ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _roundBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color bg = _accent,
  }) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Capsule AppBar (matches your reference look)
/// ─────────────────────────────────────────────────────────────
class _CapsuleAppBar extends StatelessWidget {
  final String title;
  final List<String> subtitles;
  final VoidCallback onRefresh;

  const _CapsuleAppBar({
    required this.title,
    required this.subtitles,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: _muted,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: _cardOutline),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [_accent, _accent2]),
              ),
              child: const Icon(Icons.self_improvement, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      )),
                  const SizedBox(height: 3),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      for (int i = 0; i < subtitles.length; i++) ...[
                        if (i != 0)
                          const Text("•",
                              style:
                              TextStyle(color: _mutedText, fontSize: 12)),
                        Text(
                          subtitles[i],
                          style: const TextStyle(
                            color: _mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: _accent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onRefresh,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.refresh, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  const _LegendDot({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: _chipDot,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: _mutedText)),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────
/// Ripple Waves Painter (repaints with [_ctrl])
/// ─────────────────────────────────────────────────────────────
class RipplePainter extends CustomPainter {
  final double progress;   // 0.85..1.25
  RipplePainter({required this.progress, required Listenable repaint})
      : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Map 0.85..1.25 → 0..1 breathing factor
    final t = ((progress - 0.85) / (1.25 - 0.85)).clamp(0.0, 1.0);

    final base = 40.0;   // inner radius
    final spread = 70.0; // outer ring distance

    // Make the breathing visibly stronger (was 22)
    final breatheDelta = 38.0 * t;

    const waves = 4;
    for (int i = 0; i < waves; i++) {
      final k = i / (waves - 1);               // 0..1
      final radius = base + spread * k + breatheDelta;
      final alpha = (1.0 - k) * (0.28 + 0.25 * t); // fade + brighten on inhale

      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = _accent.withOpacity(alpha);
      canvas.drawCircle(center, radius, ring);

      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6)
        ..color = _accent.withOpacity(alpha * 0.7);
      canvas.drawCircle(center, radius, glow);
    }

    // Soft breathing glow that expands/contracts with t
    final glowRadius = base + spread * 0.75 + 20 * t;
    final bg = Paint()
      ..color = _accent.withOpacity(0.20 + 0.10 * t)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    canvas.drawCircle(center, glowRadius, bg);
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

