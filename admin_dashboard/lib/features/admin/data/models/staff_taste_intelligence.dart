class StaffTasteIntelligence {
  static const int taxonomyVersion = 1;
  static const Set<String> scoringTags = {
    'office',
    'university',
    'wedding',
    'daily',
    'gift',
    'date',
    'clean',
    'fresh',
    'elegant',
    'luxury',
    'youthful',
    'classic',
    'masculine',
    'feminine',
    'soft_on_nose',
    'non_offensive',
    'not_headachey',
    'not_cloying',
    'long_lasting',
    'moderate_projection',
    'loud_projection',
    'soft_projection',
    'safe_blind_buy',
    'medium_risk',
    'polarizing',
    'crowd_pleaser',
    'sauvage_like',
    'acqua_di_gio_like',
    'aventus_like',
    'good_girl_like',
    'baccarat_like',
  };

  static const Set<String> useCaseTags = {
    'office',
    'university',
    'wedding',
    'daily',
    'gift',
    'date',
  };

  static const Set<String> vibeTags = {
    'clean',
    'fresh',
    'elegant',
    'luxury',
    'youthful',
    'classic',
    'masculine',
    'feminine',
  };

  static const Set<String> comfortTags = {
    'soft_on_nose',
    'non_offensive',
    'not_headachey',
    'not_cloying',
  };

  static const Set<String> famousDnaTags = {
    'sauvage_like',
    'acqua_di_gio_like',
    'aventus_like',
    'good_girl_like',
    'baccarat_like',
  };

  static const Set<String> warningTags = {
    'too_sweet_for_some',
    'not_for_hot_weather',
    'too_loud_for_sensitive_nose',
  };

  static Map<String, int> sanitizeScores(Map<String, int> scores) {
    return {
      for (final entry in scores.entries)
        if (scoringTags.contains(entry.key) &&
            entry.value >= 1 &&
            entry.value <= 3)
          entry.key: entry.value,
    };
  }

  static List<String> sanitizeWarnings(Iterable<String> warnings) {
    return warnings.where(warningTags.contains).toSet().toList(growable: false);
  }

  static double calculateCoverage(Map<String, int> scores) {
    if (scores.isEmpty) return 0;
    var coverage = 0.0;
    if (scores.length >= 3) coverage += 0.4;
    if (scores.keys.any(useCaseTags.contains)) coverage += 0.3;
    if (scores.keys.any(vibeTags.contains) ||
        scores.keys.any(comfortTags.contains)) {
      coverage += 0.3;
    }
    return coverage.clamp(0.0, 1.0);
  }

  static String coverageLabel(double coverage) {
    if (coverage <= 0) return 'none';
    if (coverage >= 1) return 'complete';
    return 'partial';
  }

  static bool isMainAdminRole(String? role) {
    final normalized = (role ?? '').trim().toLowerCase();
    return normalized == 'owner' ||
        normalized == 'main_admin' ||
        normalized == 'super_admin';
  }
}
