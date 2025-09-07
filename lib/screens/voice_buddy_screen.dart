// lib/screens/voice_buddy_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

/// ===== Your Color Theme =====
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

const String kGeminiApiKey = ('GEMINI_KEY');

class VoiceBuddyScreen extends StatefulWidget {
  const VoiceBuddyScreen({super.key});
  @override
  State<VoiceBuddyScreen> createState() => _VoiceBuddyScreenState();
}

class _VoiceBuddyScreenState extends State<VoiceBuddyScreen>
    with SingleTickerProviderStateMixin {
  // UI constants so spacing is consistent
  static const double _kMicSize = 92;
  static const double _kComposerHeight = 64;
  static const double _kBottomGap =
      _kMicSize + _kComposerHeight + 36; // reserved bottom space

  final List<_ChatMessage> _messages = <_ChatMessage>[
    _ChatMessage.ai(
      "I’m your Voice Buddy. Press the mic and talk to me—I'll reply briefly and calmly.",
    ),
  ];

  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  // Voice
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _listening = false;
  String _partialTranscript = '';

  // Gemini
  late final GenerativeModel _model;

  // TTS
  final FlutterTts _tts = FlutterTts();
  bool _ttsEnabled = true;
  bool _ttsSpeaking = false;

  // Mic glow
  late final AnimationController _glowCtrl;
  late final Animation<double> _glow;

  bool _sending = false;

  @override
  void initState() {
    super.initState();

    if (kGeminiApiKey.isEmpty) {
      _messages.add(_ChatMessage.system(
          "⚠️ Add your Gemini key: --dart-define=GEMINI_API_KEY=YOUR_KEY"));
    }

    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: kGeminiApiKey.isEmpty ? 'NO_KEY' : kGeminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.4,
        maxOutputTokens: 150, // short
      ),
    );

    _glowCtrl =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);

    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45); // calm
    try {
      await _tts.setLanguage("en-US");
    } catch (_) {}
    _tts.setStartHandler(() => setState(() => _ttsSpeaking = true));
    _tts.setCompletionHandler(() => setState(() => _ttsSpeaking = false));
    _tts.setErrorHandler((_) => setState(() => _ttsSpeaking = false));
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _stt.stop();
    _tts.stop();
    super.dispose();
  }

  // ================== STT ==================
  Future<void> _startListening() async {
    if (_listening) return;
    if (_ttsSpeaking) await _tts.stop();

    final ok = await _stt.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          setState(() => _listening = false);
          if (_partialTranscript.trim().isNotEmpty) {
            _handleUserText(_partialTranscript.trim());
            _partialTranscript = '';
          }
        }
      },
      onError: (e) {
        setState(() {
          _listening = false;
          _messages.add(_ChatMessage.system("🎤 Speech error: ${e.errorMsg}"));
        });
      },
    );
    if (!ok) {
      setState(() => _messages.add(_ChatMessage.system(
          "🎤 Mic unavailable. Please grant microphone permission.")));
      return;
    }

    setState(() {
      _listening = true;
      _partialTranscript = '';
    });

    await _stt.listen(
      listenMode: stt.ListenMode.confirmation,
      partialResults: true,
      pauseFor: const Duration(seconds: 3),
      onResult: (r) => setState(() => _partialTranscript = r.recognizedWords),
      localeId: await _defaultLocaleId(),
    );
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    await _stt.stop();
    setState(() => _listening = false);
  }

  Future<String?> _defaultLocaleId() async {
    try {
      final sys = await _stt.systemLocale();
      if (sys != null) return sys.localeId;
      final locales = await _stt.locales();
      return locales.isNotEmpty ? locales.first.localeId : null;
    } catch (_) {
      return null;
    }
  }

  // ================== Chat ==================
  void _handleSendPressed() {
    final t = _textCtrl.text.trim();
    if (t.isEmpty) return;
    _textCtrl.clear();
    _handleUserText(t);
  }

  Future<void> _handleUserText(String text) async {
    setState(() => _messages.add(_ChatMessage.user(text)));
    _scrollToBottom();
    await _replyWithGemini(text);
  }

  Future<void> _replyWithGemini(String userText) async {
    if (kGeminiApiKey.isEmpty) {
      final msg =
          "I can’t reach Gemini without an API key. Add it and try again.";
      setState(() => _messages.add(_ChatMessage.ai(msg)));
      if (_ttsEnabled) _speak(msg);
      _scrollToBottom();
      return;
    }

    setState(() => _sending = true);

    const persona = """
You are Voice Buddy: a calm, supportive peer counselor.
RULES FOR OUTPUT:
- Keep it SHORT and EASY to scan.
- Prefer 1–4 bullet points or 2–4 short sentences.
- Max ~60 words. Avoid long paragraphs.
- Be kind, validating, and practical.
- For crisis/self-harm, gently advise contacting local helplines/trusted people.
""";

    final prompt =
        "$persona\nUser: \"$userText\"\nReply briefly following the RULES.";

    try {
      final resp = await _model.generateContent([Content.text(prompt)]);
      var text = (resp.text ?? "").trim();
      text = _shorten(text); // enforce brevity even if model goes long
      if (text.isEmpty) {
        text = "I hear you. Could you share a bit more?";
      }
      setState(() => _messages.add(_ChatMessage.ai(text)));
      if (_ttsEnabled) _speak(text);
    } catch (e) {
      final err = "⚠️ Gemini error: $e";
      setState(() => _messages.add(_ChatMessage.system(err)));
      if (_ttsEnabled) _speak("Sorry, I hit an error. Please try again.");
    } finally {
      setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  // Hard limit ~60 words, trim to 4 bullets / 4 lines
  String _shorten(String s) {
    final cleaned = s.replaceAll('`', '').trim();
    final lines = cleaned.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // If bullets exist, keep at most 4
    final hasBullets = lines.any((l) => l.trim().startsWith(RegExp(r'[-•*] ')));
    List<String> kept;
    if (hasBullets) {
      kept = lines.where((l) => l.trim().startsWith(RegExp(r'[-•*] '))).toList();
      if (kept.isEmpty) kept = lines;
      if (kept.length > 4) kept = kept.take(4).toList();
      kept = kept.map((l) => l.replaceAll(RegExp(r'^\s*[-•*]\s*'), '• ')).toList();
    } else {
      // 2–4 short sentences
      final sentences = cleaned.split(RegExp(r'(?<=[.!?])\s+'));
      kept = sentences.take(4).toList();
    }

    // Word cap ~60
    final words = kept.join(' ').split(RegExp(r'\s+'));
    if (words.length <= 60) return kept.join('\n');

    return words.take(60).join(' ') + '…';
  }

  // ================== TTS ==================
  Future<void> _speak(String text) async {
    if (_ttsSpeaking) await _tts.stop();
    final sanitized = text
        .replaceAll(RegExp(r'\*\s*'), '')
        .replaceAll(RegExp(r'^\s*•\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    await _tts.speak(sanitized);
  }

  // ================== Helpers ==================
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 280,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
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
              // ===== Black Rounded Capsule AppBar =====
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _CapsuleAppBar(
                  title: "Voice Buddy",
                  subtitle: "Auto • Calm • Assistant",
                  ttsEnabled: _ttsEnabled,
                  onToggleTts: () => setState(() => _ttsEnabled = !_ttsEnabled),
                  onRefresh: () {
                    setState(() {
                      _messages
                        ..clear()
                        ..add(_ChatMessage.ai(
                            "Tell me what’s on your mind. I’ll answer briefly."));
                    });
                  },
                ),
              ),
              const SizedBox(height: 8),

              // ===== Main area =====
              Expanded(
                child: Stack(
                  children: [
                    // Chat list with enough bottom padding so nothing overlaps
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _ChatList(
                          messages: _messages,
                          controller: _scrollCtrl,
                          onSpeak: _speak,
                          bottomExtraPadding: _kBottomGap + bottomPad,
                        ),
                      ),
                    ),

                    // Composer (fixed height) – placed above the mic
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: bottomPad + (_kMicSize + 24),
                      child: _Composer(
                        controller: _textCtrl,
                        onSend: _sending ? null : _handleSendPressed,
                        height: _kComposerHeight,
                      ),
                    ),

                    // BIG mic button at the very bottom
                    Positioned(
                      bottom: bottomPad + 24,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _glow,
                          builder: (_, __) {
                            final blur = (_listening ? 22.0 : 8.0) * _glow.value;
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _accent.withOpacity(0.45),
                                    blurRadius: blur,
                                    spreadRadius: blur * 0.2,
                                  ),
                                ],
                              ),
                              child: GestureDetector(
                                onLongPress: _startListening,
                                onLongPressUp: _stopListening,
                                onTap: () => _listening
                                    ? _stopListening()
                                    : _startListening(),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  height: _kMicSize,
                                  width: _kMicSize,
                                  decoration: BoxDecoration(
                                    color: _accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.10),
                                    ),
                                    gradient: _listening
                                        ? const LinearGradient(
                                      colors: [_accent2, _chipDot],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                        : null,
                                  ),
                                  child: Icon(
                                    _listening ? Icons.hearing : Icons.mic,
                                    size: 36,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // “Thinking” chip
                    if (_sending)
                      Positioned(
                        bottom: bottomPad + _kMicSize + 80,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: _cardOutline),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text("Voice Buddy is thinking…",
                                    style: TextStyle(color: _mutedText)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// ===== Capsule AppBar (Black & Rounded) =====
class _CapsuleAppBar extends StatelessWidget {
  const _CapsuleAppBar({
    required this.title,
    required this.subtitle,
    required this.ttsEnabled,
    this.onToggleTts,
    this.onRefresh,
  });

  final String title;
  final String subtitle;
  final bool ttsEnabled;
  final VoidCallback? onToggleTts;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: _cardOutline),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: _chipDot,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _text, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: _mutedText, fontSize: 12.5)),
              ],
            ),
          ),
          // TTS toggle
          InkWell(
            onTap: onToggleTts,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: ttsEnabled ? _accent : _card,
                shape: BoxShape.circle,
                border: Border.all(color: _cardOutline),
              ),
              child: Icon(ttsEnabled ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white, size: 16),
            ),
          ),
          // Refresh
          InkWell(
            onTap: onRefresh,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: _accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===== Data models =====
class _ChatMessage {
  final String text;
  final _Sender sender;
  _ChatMessage(this.text, this.sender);
  factory _ChatMessage.user(String t) => _ChatMessage(t, _Sender.user);
  factory _ChatMessage.ai(String t) => _ChatMessage(t, _Sender.ai);
  factory _ChatMessage.system(String t) => _ChatMessage(t, _Sender.system);
}
enum _Sender { user, ai, system }

/// ===== Chat List (clean paddings, max width, per-message speaker) =====
class _ChatList extends StatelessWidget {
  const _ChatList({
    required this.messages,
    required this.controller,
    required this.onSpeak,
    required this.bottomExtraPadding,
  });

  final List<_ChatMessage> messages;
  final ScrollController controller;
  final Future<void> Function(String) onSpeak;
  final double bottomExtraPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final maxBubble = (c.maxWidth * 0.88).clamp(260.0, 520.0);
      return ListView.separated(
        controller: controller,
        padding: EdgeInsets.only(top: 6, bottom: bottomExtraPadding),
        itemCount: messages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final m = messages[i];
          switch (m.sender) {
            case _Sender.user:
              return Align(
                alignment: Alignment.centerRight,
                child: Container(
                  constraints: BoxConstraints(maxWidth: maxBubble),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    ),
                    border: Border.all(color: _cardOutline),
                  ),
                  child: Text(m.text,
                      style:
                      const TextStyle(color: _text, fontSize: 15.5, height: 1.25)),
                ),
              );

            case _Sender.ai:
              return _AIBubble(
                text: m.text,
                maxWidth: maxBubble,
                onSpeak: onSpeak,
              );

            case _Sender.system:
              return Center(
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _muted.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cardOutline),
                  ),
                  child: Text(
                    m.text,
                    style: const TextStyle(color: _mutedText, fontSize: 12.5),
                  ),
                ),
              );
          }
        },
      );
    });
  }
}

class _AIBubble extends StatelessWidget {
  const _AIBubble({
    required this.text,
    required this.maxWidth,
    required this.onSpeak,
  });
  final String text;
  final double maxWidth;
  final Future<void> Function(String) onSpeak;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: _chipDot,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
        ),
        const SizedBox(width: 8),

        // Bubble + speaker button
        Flexible(
          child: Stack(
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: const EdgeInsets.fromLTRB(14, 12, 46, 18),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(color: _cardOutline),
                ),
                child: Text(
                  text,
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 15.5,
                    height: 1.25,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: InkWell(
                  onTap: () => onSpeak(text),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withOpacity(0.28),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child:
                    const Icon(Icons.volume_up, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ===== Composer (fixed height) =====
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.height,
  });
  final TextEditingController controller;
  final VoidCallback? onSend;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints:
      BoxConstraints(minHeight: height, maxHeight: height + 48), // stable
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardOutline),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: _mutedText, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: _text),
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend?.call(),
                decoration: const InputDecoration(
                  hintText: "Type to chat, or hold the mic to speak…",
                  hintStyle: TextStyle(color: _mutedText),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                children: [
                  Text("Send"),
                  SizedBox(width: 6),
                  Icon(Icons.send, size: 16),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
