enum Mood { good, okay, bad }

class MoodEntry {
  final DateTime at;
  final Mood mood;

  MoodEntry({required this.at, required this.mood});

  Map<String, dynamic> toJson() =>
      {'at': at.toIso8601String(), 'mood': mood.name};

  static MoodEntry fromJson(Map<String, dynamic> j) =>
      MoodEntry(at: DateTime.parse(j['at']), mood: Mood.values.byName(j['mood']));
}
