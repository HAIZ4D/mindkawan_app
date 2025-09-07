class BuddyMemory {
  String? lastPrompt;           // user's last full text
  String? lastQuestion;         // what buddy asked: "play music, log, or breathing?"
  List<String> lastOptions = []; // e.g. ["music", "log", "breathing"]
  DateTime? lastUpdated;

  void rememberOptions(String question, List<String> options) {
    lastQuestion = question;
    lastOptions = options;
    lastUpdated = DateTime.now();
  }

  void rememberUser(String utterance) {
    lastPrompt = utterance;
    lastUpdated = DateTime.now();
  }

  bool get isFresh => lastUpdated != null && DateTime.now().difference(lastUpdated!).inMinutes < 10;

  /// Try to resolve a single-word or short reply like "music" based on lastOptions
  String? resolveShortReply(String utterance) {
    if (!isFresh || lastOptions.isEmpty) return null;
    final l = utterance.toLowerCase();
    for (final o in lastOptions) {
      if (l.contains(o.toLowerCase())) return o;
    }
    return null;
  }

  void clear() {
    lastPrompt = null;
    lastQuestion = null;
    lastOptions = [];
    lastUpdated = null;
  }
}
