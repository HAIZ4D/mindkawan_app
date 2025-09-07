import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mood_entry.dart';

final moodListProvider =
StateNotifierProvider<MoodListNotifier, List<MoodEntry>>((ref) {
  final n = MoodListNotifier();
  n.load();
  return n;
});

class MoodListNotifier extends StateNotifier<List<MoodEntry>> {
  MoodListNotifier() : super(const []);

  static const _k = 'moods_v1';

  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_k);
    if (raw != null) {
      final list = (jsonDecode(raw) as List)
          .map((e) => MoodEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      state = list..sort((a, b) => a.at.compareTo(b.at));
    }
  }

  Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_k, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  Future<void> log(Mood mood, {DateTime? at}) async {
    final entry = MoodEntry(at: at ?? DateTime.now(), mood: mood);
    state = [...state, entry]..sort((a, b) => a.at.compareTo(b.at));
    await _save();
  }

  List<MoodEntry> last7Days() {
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 6));
    return state.where((e) => e.at.isAfter(DateTime(from.year, from.month, from.day))).toList();
  }

  ({int good, int okay, int bad}) counts(Iterable<MoodEntry> list) {
    var g = 0, o = 0, b = 0;
    for (final e in list) {
      switch (e.mood) {
        case Mood.good: g++; break;
        case Mood.okay: o++; break;
        case Mood.bad:  b++; break;
      }
    }
    return (good: g, okay: o, bad: b);
  }
}
