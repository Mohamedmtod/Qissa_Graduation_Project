import 'package:perfume_app/features/ai_chat/presentation/manager/ai_chat_text_normalizer.dart';
import 'package:perfume_app/features/ai_chat/data/models/perfume_knowledge_profile.dart';

class AvailabilityReferenceProfile {
  final String key;
  final String displayName;
  final String brand;
  final Set<String> aliases;
  final Set<String> accords;
  final Set<String> topNotes;
  final Set<String> middleNotes;
  final Set<String> baseNotes;
  final Set<String> preferredNotes;
  final Set<String> tags;
  final String fragranceFamily;
  final String? genderHint;
  final String? intensityHint;
  final String? seasonHint;
  final String? occasionHint;
  final String? timeHint;
  final String? sourceName;
  final String? sourceUrl;
  final double lookupConfidence;

  const AvailabilityReferenceProfile({
    required this.key,
    this.displayName = '',
    this.brand = '',
    required this.aliases,
    this.accords = const {},
    this.topNotes = const {},
    this.middleNotes = const {},
    this.baseNotes = const {},
    this.preferredNotes = const {},
    this.tags = const {},
    this.fragranceFamily = '',
    this.genderHint,
    this.intensityHint,
    this.seasonHint,
    this.occasionHint,
    this.timeHint,
    this.sourceName,
    this.sourceUrl,
    this.lookupConfidence = 1,
  });

  factory AvailabilityReferenceProfile.fromKnowledge(
    PerfumeKnowledgeProfile profile,
  ) {
    return AvailabilityReferenceProfile(
      key: profile.id,
      displayName: profile.displayName,
      brand: profile.brand,
      aliases: {
        profile.displayName,
        if (profile.brand.trim().isNotEmpty)
          '${profile.brand} ${profile.displayName}',
        ...profile.aliases,
      },
      accords: profile.accords.toSet(),
      topNotes: profile.topNotes.toSet(),
      middleNotes: profile.middleNotes.toSet(),
      baseNotes: profile.baseNotes.toSet(),
      preferredNotes: profile.preferredNotes.toSet(),
      tags: profile.accords.toSet(),
      fragranceFamily: profile.fragranceFamily,
      genderHint: profile.genderHint,
      intensityHint: profile.intensityHint,
      seasonHint: profile.seasonHint,
      occasionHint: profile.occasionHint,
      timeHint: profile.timeHint,
      sourceName: profile.sourceName,
      sourceUrl: profile.sourceUrl,
      lookupConfidence: profile.lookupConfidence,
    );
  }
}

class AvailabilityReferenceProfileRegistry {
  static const List<AvailabilityReferenceProfile> profiles = [
    AvailabilityReferenceProfile(
      key: 'sauvage_ar',
      displayName: 'Dior Sauvage',
      brand: 'Dior',
      aliases: {'سوفاج', 'ديور سوفاج'},
      accords: {'citrus', 'woody', 'aromatic', 'spicy'},
      topNotes: {'citrus'},
      baseNotes: {'woody', 'amber'},
      preferredNotes: {'citrus', 'spicy', 'woody', 'amber', 'pepper', 'ambroxan'},
      tags: {'fresh', 'bold', 'classic', 'aromatic'},
      fragranceFamily: 'aromatic fougere',
      genderHint: 'men',
      intensityHint: 'strong',
    ),
    AvailabilityReferenceProfile(
      key: 'sauvage',
      displayName: 'Dior Sauvage',
      brand: 'Dior',
      aliases: {'sauvage', 'dior sauvage', 'سوفاج', 'ديور سوفاج'},
      accords: {'citrus', 'woody', 'aromatic', 'spicy'},
      topNotes: {'citrus'},
      baseNotes: {'woody', 'amber'},
      preferredNotes: {'citrus', 'spicy', 'woody', 'amber', 'pepper', 'ambroxan'},
      tags: {'fresh', 'bold', 'classic', 'aromatic'},
      fragranceFamily: 'aromatic fougere',
      genderHint: 'men',
      intensityHint: 'strong',
    ),
    AvailabilityReferenceProfile(
      key: 'bleu_de_chanel',
      displayName: 'Bleu de Chanel',
      brand: 'Chanel',
      aliases: {'bleu de chanel', 'blue de chanel', 'بلو دي شانيل'},
      accords: {'citrus', 'woody', 'aromatic', 'fresh', 'amber'},
      topNotes: {'citrus'},
      middleNotes: {'aromatic'},
      baseNotes: {'woody', 'amber'},
      preferredNotes: {'citrus', 'woody', 'aromatic', 'amber'},
      tags: {'fresh', 'elegant', 'classic', 'aromatic'},
      fragranceFamily: 'woody aromatic',
      genderHint: 'men',
      intensityHint: 'medium',
    ),
    AvailabilityReferenceProfile(
      key: 'tom_ford_oud_wood',
      displayName: 'Tom Ford Oud Wood',
      brand: 'Tom Ford',
      aliases: {
        'tom ford oud wood',
        'oud wood',
        'tomford oud wood',
        'tom ford wood oud',
      },
      accords: {'woody', 'oud', 'warm', 'spicy', 'amber'},
      topNotes: {'spicy'},
      middleNotes: {'oud', 'woody'},
      baseNotes: {'amber', 'musk', 'vanilla'},
      preferredNotes: {'oud', 'woody', 'amber', 'spicy', 'musk'},
      tags: {'woody', 'warm', 'elegant', 'classic'},
      fragranceFamily: 'woody oriental',
      genderHint: 'unisex',
      intensityHint: 'medium',
      seasonHint: 'winter',
      occasionHint: 'formal',
      timeHint: 'night',
    ),
    AvailabilityReferenceProfile(
      key: 'gym_fresh',
      aliases: {'gym', 'workout', 'sports', 'جيم', 'رياضة'},
      tags: {'fresh', 'clean'},
      intensityHint: 'light',
      timeHint: 'day',
    ),
    AvailabilityReferenceProfile(
      key: 'heavy_workout',
      aliases: {'heavy workout', 'lifting', 'weights'},
      tags: {'fresh', 'clean'},
      occasionHint: 'daily',
      intensityHint: 'light',
      timeHint: 'day',
    ),
    AvailabilityReferenceProfile(
      key: 'office_clean',
      aliases: {'office', 'work', 'every day at work', 'مكتب', 'شغل', 'دوام'},
      tags: {'clean', 'elegant'},
      occasionHint: 'office',
      intensityHint: 'light',
      timeHint: 'all_day',
    ),
    AvailabilityReferenceProfile(
      key: 'university_fresh',
      aliases: {'university', 'college', 'campus', 'جامعة', 'كلية'},
      tags: {'fresh', 'clean'},
      occasionHint: 'university',
      intensityHint: 'light',
      timeHint: 'all_day',
    ),
    AvailabilityReferenceProfile(
      key: 'interview_formal',
      aliases: {'interview', 'job interview', 'company interview'},
      tags: {'clean', 'elegant', 'classic'},
      occasionHint: 'office',
      intensityHint: 'light',
      timeHint: 'all_day',
    ),
    AvailabilityReferenceProfile(
      key: 'romantic_date',
      aliases: {
        'romantic',
        'valentine',
        'valentine day',
        'valentines day',
        "valentine's day",
        'موعد',
        'رومانسي',
        'غرامي',
      },
      tags: {'sweet', 'warm', 'romantic'},
      occasionHint: 'date',
    ),
    AvailabilityReferenceProfile(
      key: 'date_night',
      aliases: {'date night', 'date', 'romantic', 'مواعدة', 'رومانسي', 'غرامي'},
      preferredNotes: {'woody', 'spicy'},
      tags: {'sweet', 'warm'},
      occasionHint: 'date',
      intensityHint: 'strong',
      timeHint: 'night',
    ),
    AvailabilityReferenceProfile(
      key: 'manager_gift',
      aliases: {
        'manager',
        'boss',
        'older professional',
        'gift for manager',
        'gift for boss',
        'مديري',
        'مدير',
      },
      tags: {'classic', 'elegant'},
      occasionHint: 'formal',
      intensityHint: 'medium',
    ),
    AvailabilityReferenceProfile(
      key: 'campus_hot_day',
      aliases: {'campus day', 'hot campus day'},
      tags: {'fresh', 'clean'},
      seasonHint: 'summer',
      occasionHint: 'university',
      intensityHint: 'light',
      timeHint: 'all_day',
    ),
    AvailabilityReferenceProfile(
      key: 'luxury_royal',
      aliases: {
        'luxury',
        'premium',
        'royal',
        'masterpiece',
        'vip',
        'money is no object',
      },
      tags: {'elegant', 'classic', 'bold'},
      intensityHint: 'strong',
      timeHint: 'night',
    ),
    AvailabilityReferenceProfile(
      key: 'bedtime_soft',
      aliases: {'bedtime', 'before sleep', 'sleep'},
      preferredNotes: {'musk', 'floral'},
      tags: {'clean'},
      intensityHint: 'light',
      timeHint: 'night',
    ),
  ];

  static AvailabilityReferenceProfile? resolveByMessage(String message) {
    final normalized = AIChatTextNormalizer.normalizeForParsing(message);
    for (final profile in profiles) {
      for (final alias in profile.aliases) {
        final normalizedAlias = AIChatTextNormalizer.normalizeForParsing(alias);
        if (normalizedAlias.isEmpty) continue;
        if (normalized.contains(normalizedAlias)) {
          return profile;
        }
      }
    }
    return null;
  }
}
