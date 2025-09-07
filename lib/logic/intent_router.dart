enum BuddyIntent {
  feelingAnxious,
  logFeeling,
  playMusic,
  startBreathing,
  stressTomorrow,
  tellStory,
  safeWord,
  unknown,
}

class IntentRouter {
  final String safeWord;

  IntentRouter({this.safeWord = 'i\'m overwhelmed'});

  BuddyIntent detect(String input) {
    final t = input.toLowerCase();

    if (t.contains(safeWord)) return BuddyIntent.safeWord;

    if (t.contains('feel') && (t.contains('anxious') || t.contains('anxiety') || t.contains('panic'))) {
      return BuddyIntent.feelingAnxious;
    }
    if ((t.contains('log') && t.contains('feeling')) || t.contains('mood log')) {
      return BuddyIntent.logFeeling;
    }
    if (t.contains('music') || t.contains('play music') || t.contains('calming songs')) {
      return BuddyIntent.playMusic;
    }
    if (t.contains('breathing') || t.contains('breathe') || t.contains('breath')) {
      return BuddyIntent.startBreathing;
    }
    if (t.contains('stress') && (t.contains('tomorrow') || t.contains('next day'))) {
      return BuddyIntent.stressTomorrow;
    }
    if (t.contains('story') || t.contains('tell me a story')) {
      return BuddyIntent.tellStory;
    }
    return BuddyIntent.unknown;
  }
}
