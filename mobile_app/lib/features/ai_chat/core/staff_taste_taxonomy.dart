enum StaffTasteTagGroup {
  useCase,
  vibe,
  comfort,
  performance,
  risk,
  famousDna,
  warning,
}

enum StaffTasteStatus { draft, reviewed, trusted }

class StaffTasteTagDefinition {
  final String id;
  final StaffTasteTagGroup group;
  final String labelEn;
  final String labelAr;
  final List<String> aliases;

  const StaffTasteTagDefinition({
    required this.id,
    required this.group,
    required this.labelEn,
    required this.labelAr,
    this.aliases = const <String>[],
  });
}

class StaffTasteTaxonomy {
  static const int version = 1;

  static const List<StaffTasteTagDefinition> tags = [
    StaffTasteTagDefinition(
      id: 'office',
      group: StaffTasteTagGroup.useCase,
      labelEn: 'Office',
      labelAr: 'شغل',
      aliases: ['work', 'شغل', 'مكتب'],
    ),
    StaffTasteTagDefinition(
      id: 'university',
      group: StaffTasteTagGroup.useCase,
      labelEn: 'University',
      labelAr: 'جامعة',
      aliases: ['campus', 'college', 'جامعة'],
    ),
    StaffTasteTagDefinition(
      id: 'wedding',
      group: StaffTasteTagGroup.useCase,
      labelEn: 'Wedding',
      labelAr: 'فرح',
      aliases: ['formal event', 'فرح', 'مناسبة'],
    ),
    StaffTasteTagDefinition(
      id: 'daily',
      group: StaffTasteTagGroup.useCase,
      labelEn: 'Daily',
      labelAr: 'يومي',
      aliases: ['everyday', 'يومي'],
    ),
    StaffTasteTagDefinition(
      id: 'gift',
      group: StaffTasteTagGroup.useCase,
      labelEn: 'Gift',
      labelAr: 'هدية',
      aliases: ['present', 'هدية'],
    ),
    StaffTasteTagDefinition(
      id: 'date',
      group: StaffTasteTagGroup.useCase,
      labelEn: 'Date',
      labelAr: 'موعد',
      aliases: ['date night', 'خروجة'],
    ),
    StaffTasteTagDefinition(
      id: 'clean',
      group: StaffTasteTagGroup.vibe,
      labelEn: 'Clean',
      labelAr: 'نضيف',
      aliases: ['نضيف', 'clean'],
    ),
    StaffTasteTagDefinition(
      id: 'fresh',
      group: StaffTasteTagGroup.vibe,
      labelEn: 'Fresh',
      labelAr: 'فريش',
      aliases: ['فريش', 'fresh'],
    ),
    StaffTasteTagDefinition(
      id: 'elegant',
      group: StaffTasteTagGroup.vibe,
      labelEn: 'Elegant',
      labelAr: 'شيك',
      aliases: ['chic', 'classy', 'شيك', 'راقي'],
    ),
    StaffTasteTagDefinition(
      id: 'luxury',
      group: StaffTasteTagGroup.vibe,
      labelEn: 'Luxury',
      labelAr: 'فخم',
      aliases: ['premium', 'فخم'],
    ),
    StaffTasteTagDefinition(
      id: 'youthful',
      group: StaffTasteTagGroup.vibe,
      labelEn: 'Youthful',
      labelAr: 'شبابي',
      aliases: ['young', 'شبابي'],
    ),
    StaffTasteTagDefinition(
      id: 'classic',
      group: StaffTasteTagGroup.vibe,
      labelEn: 'Classic',
      labelAr: 'كلاسيك',
      aliases: ['كلاسيك'],
    ),
    StaffTasteTagDefinition(
      id: 'masculine',
      group: StaffTasteTagGroup.vibe,
      labelEn: 'Masculine',
      labelAr: 'رجولي',
      aliases: ['رجولي'],
    ),
    StaffTasteTagDefinition(
      id: 'feminine',
      group: StaffTasteTagGroup.vibe,
      labelEn: 'Feminine',
      labelAr: 'أنثوي',
      aliases: ['نسائي', 'انثوي'],
    ),
    StaffTasteTagDefinition(
      id: 'soft_on_nose',
      group: StaffTasteTagGroup.comfort,
      labelEn: 'Soft on nose',
      labelAr: 'هادي على الأنف',
      aliases: ['هادي على الانف', 'هادي على الأنف', 'soft'],
    ),
    StaffTasteTagDefinition(
      id: 'non_offensive',
      group: StaffTasteTagGroup.comfort,
      labelEn: 'Non offensive',
      labelAr: 'مش مزعج',
      aliases: ['مش مزعج', 'safe scent'],
    ),
    StaffTasteTagDefinition(
      id: 'not_headachey',
      group: StaffTasteTagGroup.comfort,
      labelEn: 'Not headachey',
      labelAr: 'مش بيوجع الدماغ',
      aliases: ['مش بيوجع الدماغ', 'مش يصدع'],
    ),
    StaffTasteTagDefinition(
      id: 'not_cloying',
      group: StaffTasteTagGroup.comfort,
      labelEn: 'Not cloying',
      labelAr: 'مش خانق',
      aliases: ['مش خانق', 'not choking'],
    ),
    StaffTasteTagDefinition(
      id: 'long_lasting',
      group: StaffTasteTagGroup.performance,
      labelEn: 'Long lasting',
      labelAr: 'ثابت',
      aliases: ['ثابت', 'long lasting'],
    ),
    StaffTasteTagDefinition(
      id: 'moderate_projection',
      group: StaffTasteTagGroup.performance,
      labelEn: 'Moderate projection',
      labelAr: 'فوحانه متوسط',
      aliases: ['فوحان متوسط', 'moderate projection'],
    ),
    StaffTasteTagDefinition(
      id: 'loud_projection',
      group: StaffTasteTagGroup.performance,
      labelEn: 'Loud projection',
      labelAr: 'فواح',
      aliases: ['فواح', 'loud'],
    ),
    StaffTasteTagDefinition(
      id: 'soft_projection',
      group: StaffTasteTagGroup.performance,
      labelEn: 'Soft projection',
      labelAr: 'هادي',
      aliases: ['هادي', 'soft projection'],
    ),
    StaffTasteTagDefinition(
      id: 'safe_blind_buy',
      group: StaffTasteTagGroup.risk,
      labelEn: 'Safe blind buy',
      labelAr: 'آمن للشراء بدون شم',
      aliases: ['safe blind buy', 'امان', 'آمن'],
    ),
    StaffTasteTagDefinition(
      id: 'medium_risk',
      group: StaffTasteTagGroup.risk,
      labelEn: 'Medium risk',
      labelAr: 'مخاطرة متوسطة',
    ),
    StaffTasteTagDefinition(
      id: 'polarizing',
      group: StaffTasteTagGroup.risk,
      labelEn: 'Polarizing',
      labelAr: 'مش لكل الناس',
      aliases: ['not for everyone', 'مش لكل الناس'],
    ),
    StaffTasteTagDefinition(
      id: 'crowd_pleaser',
      group: StaffTasteTagGroup.risk,
      labelEn: 'Crowd pleaser',
      labelAr: 'بيعجب أغلب الناس',
      aliases: ['mass appealing', 'بيعجب اغلب الناس'],
    ),
    StaffTasteTagDefinition(
      id: 'sauvage_like',
      group: StaffTasteTagGroup.famousDna,
      labelEn: 'Sauvage-like',
      labelAr: 'شبه سوفاج',
      aliases: ['sauvage', 'سوفاج'],
    ),
    StaffTasteTagDefinition(
      id: 'acqua_di_gio_like',
      group: StaffTasteTagGroup.famousDna,
      labelEn: 'Acqua di Gio-like',
      labelAr: 'شبه أكوا دي جيو',
      aliases: ['acqua di gio', 'اكوا'],
    ),
    StaffTasteTagDefinition(
      id: 'aventus_like',
      group: StaffTasteTagGroup.famousDna,
      labelEn: 'Aventus-like',
      labelAr: 'شبه أفينتوس',
      aliases: ['aventus', 'افينتوس'],
    ),
    StaffTasteTagDefinition(
      id: 'good_girl_like',
      group: StaffTasteTagGroup.famousDna,
      labelEn: 'Good Girl-like',
      labelAr: 'شبه جود جيرل',
      aliases: ['good girl', 'جود جيرل'],
    ),
    StaffTasteTagDefinition(
      id: 'baccarat_like',
      group: StaffTasteTagGroup.famousDna,
      labelEn: 'Baccarat-like',
      labelAr: 'شبه باكارات',
      aliases: ['baccarat', 'باكارات'],
    ),
    StaffTasteTagDefinition(
      id: 'too_sweet_for_some',
      group: StaffTasteTagGroup.warning,
      labelEn: 'Too sweet for some',
      labelAr: 'حلو زيادة لبعض الناس',
    ),
    StaffTasteTagDefinition(
      id: 'not_for_hot_weather',
      group: StaffTasteTagGroup.warning,
      labelEn: 'Not for hot weather',
      labelAr: 'مش مناسب للحر',
    ),
    StaffTasteTagDefinition(
      id: 'too_loud_for_sensitive_nose',
      group: StaffTasteTagGroup.warning,
      labelEn: 'Too loud for sensitive nose',
      labelAr: 'قوي على الأنف الحساسة',
    ),
  ];

  static final Map<String, StaffTasteTagDefinition> byId = {
    for (final tag in tags) tag.id: tag,
  };

  static Set<String> get validTagIds => byId.keys.toSet();

  static Set<String> get warningTagIds => tags
      .where((tag) => tag.group == StaffTasteTagGroup.warning)
      .map((tag) => tag.id)
      .toSet();

  static Set<String> get scoringTagIds => tags
      .where((tag) => tag.group != StaffTasteTagGroup.warning)
      .map((tag) => tag.id)
      .toSet();

  static Set<String> get famousDnaTagIds => tags
      .where((tag) => tag.group == StaffTasteTagGroup.famousDna)
      .map((tag) => tag.id)
      .toSet();

  static StaffTasteTagGroup? groupFor(String tagId) => byId[tagId]?.group;

  static String normalizeStatus(String raw) {
    final value = raw.trim().toLowerCase();
    return switch (value) {
      'reviewed' => 'reviewed',
      'trusted' => 'trusted',
      _ => 'draft',
    };
  }

  static Map<String, int> sanitizeScores(Map<String, dynamic> raw) {
    final result = <String, int>{};
    for (final entry in raw.entries) {
      final tagId = entry.key.trim();
      if (!scoringTagIds.contains(tagId)) continue;
      final score = _scoreFrom(entry.value);
      if (score == null) continue;
      result[tagId] = score;
    }
    return result;
  }

  static List<String> sanitizeWarnings(Iterable<dynamic> raw) {
    final result = <String>[];
    for (final item in raw) {
      final tagId = item.toString().trim();
      if (!warningTagIds.contains(tagId) || result.contains(tagId)) continue;
      result.add(tagId);
    }
    return result;
  }

  static double calculateCoverage(Map<String, int> scores) {
    if (scores.isEmpty) return 0;
    final groups = scores.keys.map(groupFor).whereType<StaffTasteTagGroup>();
    final hasUseCase = groups.contains(StaffTasteTagGroup.useCase);
    final hasVibeOrComfort =
        groups.contains(StaffTasteTagGroup.vibe) ||
        groups.contains(StaffTasteTagGroup.comfort);
    var coverage = 0.0;
    if (scores.length >= 3) coverage += 0.4;
    if (hasUseCase) coverage += 0.3;
    if (hasVibeOrComfort) coverage += 0.3;
    return coverage.clamp(0.0, 1.0);
  }

  static String coverageLabel(double coverage) {
    if (coverage <= 0) return 'none';
    if (coverage >= 1) return 'complete';
    return 'partial';
  }

  static int normalizeConfidence(Object? value) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString().trim() ?? '');
    if (parsed == null) return 1;
    return parsed.clamp(1, 3);
  }

  static int? _scoreFrom(Object? raw) {
    final parsed = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString().trim() ?? '');
    if (parsed == null || parsed < 1 || parsed > 3) return null;
    return parsed;
  }
}
