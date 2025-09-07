class EmotionFlag {
  final bool likelyStressed;
  final double confidence; // 0..1
  EmotionFlag({required this.likelyStressed, required this.confidence});
}

class EmotionAnalyzer {
  // Simple negative keywords & exclamations as text cues:
  static const _stressWords = [
    'anxious', 'anxiety', 'panic', 'panic attack', 'overwhelmed',
    'stressed', 'stress', 'worried', 'scared', 'nervous', 'tight',
    'can\'t breathe', 'can’t breathe', 'heartbeat', 'cry', 'crying',
  ];

  EmotionFlag analyze({
    required double avgSoundLevel,
    required String textSnapshot,
  }) {
    final t = textSnapshot.toLowerCase();
    final hits = _stressWords.where((w) => t.contains(w)).length;

    // Sound level ~40-60 is normal; >60 can imply heightened arousal (device-dependent)
    final soundScore = (avgSoundLevel > 60) ? 0.6 : (avgSoundLevel > 50 ? 0.3 : 0.1);
    final textScore = (hits >= 2) ? 0.7 : (hits == 1 ? 0.4 : 0.0);

    final combined = (soundScore * 0.45) + (textScore * 0.55);
    return EmotionFlag(likelyStressed: combined >= 0.45, confidence: combined.clamp(0, 1));
  }
}
