class UserTasteProfile {
  final Map<String, double> noteScores;

  const UserTasteProfile({required this.noteScores});

  static const UserTasteProfile empty = UserTasteProfile(noteScores: <String, double>{});

  Map<String, dynamic> toMap() {
    return {
      'noteScores': noteScores,
    };
  }

  factory UserTasteProfile.fromMap(Map<String, dynamic> map) {
    final dynamic rawScores = map['noteScores'];
    if (rawScores is! Map) return empty;

    final scores = <String, double>{};
    for (final entry in rawScores.entries) {
      final key = entry.key?.toString().trim() ?? '';
      if (key.isEmpty) continue;
      final value = entry.value;
      if (value is num) {
        scores[key] = value.toDouble();
      } else if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          scores[key] = parsed;
        }
      }
    }

    return UserTasteProfile(noteScores: scores);
  }
}
