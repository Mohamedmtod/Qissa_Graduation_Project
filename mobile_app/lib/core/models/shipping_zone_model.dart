/// Shared contract for a delivery governorate zone.
///
/// Source of truth is Firestore: /config/shipping_zones -> field "zones".
/// The client reads this to populate address dropdowns and compute fees.
/// The Orders Worker reads it server-side to validate and compute the final fee.
class ShippingZoneModel {
  /// Stable lowercase ASCII key, e.g. "cairo", "giza", "alexandria".
  final String code;

  /// Arabic display name shown in the app UI.
  final String governorate;

  /// English name used for map auto-matching and admin display.
  final String governorateEn;

  /// Delivery fee in EGP. Must be >= 0.
  final double fee;

  /// Whether this zone is currently accepting orders.
  final bool enabled;
  final String? parentCode;
  final List<String> aliasesAr;
  final List<String> aliasesEn;

  const ShippingZoneModel({
    required this.code,
    required this.governorate,
    required this.governorateEn,
    required this.fee,
    required this.enabled,
    this.parentCode,
    this.aliasesAr = const [],
    this.aliasesEn = const [],
  });

  factory ShippingZoneModel.fromMap(Map<String, dynamic> map) {
    final rawCode = map['code'] as String?;
    final govEn = (map['governorateEn'] as String? ?? '').trim();
    final derivedCode = rawCode?.trim().isNotEmpty == true
        ? rawCode!.trim().toLowerCase()
        : _deriveCode(govEn);

    return ShippingZoneModel(
      code: derivedCode,
      governorate: (map['governorate'] as String? ?? '').trim(),
      governorateEn: govEn,
      fee: (map['fee'] as num? ?? 0).toDouble(),
      enabled: map['enabled'] as bool? ?? false,
      parentCode: map['parentCode'] as String?,
      aliasesAr: _stringList(map['aliasesAr']),
      aliasesEn: _stringList(map['aliasesEn']),
    );
  }

  Map<String, dynamic> toMap() => {
    'code': code,
    'governorate': governorate,
    'governorateEn': governorateEn,
    'fee': fee,
    'enabled': enabled,
    'parentCode': parentCode,
    if (aliasesAr.isNotEmpty) 'aliasesAr': aliasesAr,
    if (aliasesEn.isNotEmpty) 'aliasesEn': aliasesEn,
  };

  ShippingZoneModel copyWith({
    String? code,
    String? governorate,
    String? governorateEn,
    double? fee,
    bool? enabled,
    String? parentCode,
    List<String>? aliasesAr,
    List<String>? aliasesEn,
  }) {
    return ShippingZoneModel(
      code: code ?? this.code,
      governorate: governorate ?? this.governorate,
      governorateEn: governorateEn ?? this.governorateEn,
      fee: fee ?? this.fee,
      enabled: enabled ?? this.enabled,
      parentCode: parentCode ?? this.parentCode,
      aliasesAr: aliasesAr ?? this.aliasesAr,
      aliasesEn: aliasesEn ?? this.aliasesEn,
    );
  }

  bool get isGovernorate => parentCode == null || parentCode!.trim().isEmpty;

  bool get isCityZone => !isGovernorate;

  Iterable<String> get searchableNames sync* {
    yield governorate;
    yield governorateEn;
    yield code.replaceAll('_', ' ');
    yield* _defaultAliasesEn(code);
    yield* aliasesAr;
    yield* aliasesEn;
  }

  static String _deriveCode(String govEn) {
    return govEn
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
  }

  static List<String> _defaultAliasesEn(String code) {
    return switch (code) {
      'cairo' => const ['Cairo Governorate', 'Al Qahirah'],
      'cairo_nasr_city' => const [
        'Nasr',
        'Nasr City',
        'Nasr City District',
        'Qesm Awal Nasr City',
        'Qesm Than Nasr City',
      ],
      'cairo_heliopolis' => const ['Heliopolis', 'Masr El Gedida'],
      'cairo_new_cairo' => const [
        'New Cairo',
        'El Tagamoa',
        'Fifth Settlement',
        'First Settlement',
        'Third Settlement',
      ],
      'cairo_maadi' => const ['Maadi', 'El Maadi'],
      'cairo_helwan' => const ['Helwan'],
      'giza' => const ['Giza Governorate', 'Al Jizah'],
      'giza_october' => const [
        '6 October',
        '6th October',
        '6th of October City',
        'Sixth of October',
      ],
      'giza_zayed' => const ['Sheikh Zayed', 'El Sheikh Zayed'],
      'alexandria' => const ['Alexandria Governorate', 'Alex'],
      _ => const [],
    };
  }

  /// Normalise an Arabic or English city string for fuzzy matching.
  static String normalise(String input) {
    const diacritics = 'ًٌٍَُِّْ';
    var s = input.trim().toLowerCase();
    for (final d in diacritics.split('')) {
      s = s.replaceAll(d, '');
    }
    s = s.replaceAll(RegExp('[أإآا]'), 'ا');
    s = s.replaceAll('ة', 'ه');
    return s;
  }

  /// Try to match [cityName] (from geocoding) against this zone.
  bool matchesCityName(String cityName) {
    final q = normalise(cityName);
    if (q.isEmpty) return false;
    if (normalise(governorate).contains(q) ||
        q.contains(normalise(governorate))) {
      return true;
    }
    if (normalise(governorateEn).contains(q) ||
        q.contains(normalise(governorateEn))) {
      return true;
    }
    for (final alias in [...aliasesAr, ...aliasesEn]) {
      final normalisedAlias = normalise(alias);
      if (normalisedAlias.contains(q) || q.contains(normalisedAlias)) {
        return true;
      }
    }
    return false;
  }

  @override
  String toString() =>
      'ShippingZoneModel(code: $code, governorate: $governorate, fee: $fee, enabled: $enabled)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShippingZoneModel && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Canonical list of Egyptian governorates used as the seed when the
/// Firestore document does not yet exist.
const kEgyptianGovernorates = <ShippingZoneModel>[
  ShippingZoneModel(
    code: 'cairo',
    governorate: 'القاهرة',
    governorateEn: 'Cairo',
    fee: 50,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'cairo_nasr_city',
    governorate: 'مدينة نصر',
    governorateEn: 'Nasr City',
    fee: 50,
    enabled: true,
    parentCode: 'cairo',
  ),
  ShippingZoneModel(
    code: 'cairo_heliopolis',
    governorate: 'مصر الجديدة',
    governorateEn: 'Heliopolis',
    fee: 50,
    enabled: true,
    parentCode: 'cairo',
  ),
  ShippingZoneModel(
    code: 'cairo_new_cairo',
    governorate: 'التجمع / القاهرة الجديدة',
    governorateEn: 'New Cairo',
    fee: 50,
    enabled: true,
    parentCode: 'cairo',
  ),
  ShippingZoneModel(
    code: 'cairo_maadi',
    governorate: 'المعادي',
    governorateEn: 'Maadi',
    fee: 50,
    enabled: true,
    parentCode: 'cairo',
  ),
  ShippingZoneModel(
    code: 'cairo_helwan',
    governorate: 'حلوان',
    governorateEn: 'Helwan',
    fee: 60,
    enabled: true,
    parentCode: 'cairo',
  ),
  ShippingZoneModel(
    code: 'cairo_shorouk',
    governorate: 'الشروق',
    governorateEn: 'Shorouk',
    fee: 60,
    enabled: true,
    parentCode: 'cairo',
  ),
  ShippingZoneModel(
    code: 'cairo_obour',
    governorate: 'العبور',
    governorateEn: 'Obour',
    fee: 60,
    enabled: true,
    parentCode: 'cairo',
  ),
  ShippingZoneModel(
    code: 'cairo_madinaty',
    governorate: 'مدينتي',
    governorateEn: 'Madinaty',
    fee: 60,
    enabled: true,
    parentCode: 'cairo',
  ),
  ShippingZoneModel(
    code: 'giza',
    governorate: 'الجيزة',
    governorateEn: 'Giza',
    fee: 50,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'giza_october',
    governorate: '6 أكتوبر',
    governorateEn: '6th of October',
    fee: 60,
    enabled: true,
    parentCode: 'giza',
  ),
  ShippingZoneModel(
    code: 'giza_zayed',
    governorate: 'الشيخ زايد',
    governorateEn: 'Sheikh Zayed',
    fee: 60,
    enabled: true,
    parentCode: 'giza',
  ),
  ShippingZoneModel(
    code: 'giza_haram',
    governorate: 'الهرم',
    governorateEn: 'Haram',
    fee: 50,
    enabled: true,
    parentCode: 'giza',
  ),
  ShippingZoneModel(
    code: 'giza_dokki',
    governorate: 'الدقي',
    governorateEn: 'Dokki',
    fee: 50,
    enabled: true,
    parentCode: 'giza',
  ),
  ShippingZoneModel(
    code: 'giza_mohandessin',
    governorate: 'المهندسين',
    governorateEn: 'Mohandessin',
    fee: 50,
    enabled: true,
    parentCode: 'giza',
  ),
  ShippingZoneModel(
    code: 'alexandria',
    governorate: 'الإسكندرية',
    governorateEn: 'Alexandria',
    fee: 65,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'alex_smouha',
    governorate: 'سموحة',
    governorateEn: 'Smouha',
    fee: 65,
    enabled: true,
    parentCode: 'alexandria',
  ),
  ShippingZoneModel(
    code: 'alex_miami',
    governorate: 'ميامي',
    governorateEn: 'Miami',
    fee: 65,
    enabled: true,
    parentCode: 'alexandria',
  ),
  ShippingZoneModel(
    code: 'alex_montazah',
    governorate: 'المنتزة',
    governorateEn: 'Montazah',
    fee: 65,
    enabled: true,
    parentCode: 'alexandria',
  ),
  ShippingZoneModel(
    code: 'alex_agami',
    governorate: 'العجمي',
    governorateEn: 'Agami',
    fee: 70,
    enabled: true,
    parentCode: 'alexandria',
  ),
  ShippingZoneModel(
    code: 'alex_borg_arab',
    governorate: 'برج العرب',
    governorateEn: 'Borg El Arab',
    fee: 80,
    enabled: true,
    parentCode: 'alexandria',
  ),
  ShippingZoneModel(
    code: 'qalyubia',
    governorate: 'القليوبية',
    governorateEn: 'Qalyubia',
    fee: 55,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'qaly_banha',
    governorate: 'بنها',
    governorateEn: 'Banha',
    fee: 55,
    enabled: true,
    parentCode: 'qalyubia',
  ),
  ShippingZoneModel(
    code: 'qaly_shubra',
    governorate: 'شبرا الخيمة',
    governorateEn: 'Shubra El Kheima',
    fee: 55,
    enabled: true,
    parentCode: 'qalyubia',
  ),
  ShippingZoneModel(
    code: 'sharqia',
    governorate: 'الشرقية',
    governorateEn: 'Sharqia',
    fee: 60,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'sharq_zagazig',
    governorate: 'الزقازيق',
    governorateEn: 'Zagazig',
    fee: 60,
    enabled: true,
    parentCode: 'sharqia',
  ),
  ShippingZoneModel(
    code: 'sharq_10th',
    governorate: 'العاشر من رمضان',
    governorateEn: '10th of Ramadan',
    fee: 60,
    enabled: true,
    parentCode: 'sharqia',
  ),
  ShippingZoneModel(
    code: 'dakahlia',
    governorate: 'الدقهلية',
    governorateEn: 'Dakahlia',
    fee: 60,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'dak_mansoura',
    governorate: 'المنصورة',
    governorateEn: 'Mansoura',
    fee: 60,
    enabled: true,
    parentCode: 'dakahlia',
  ),
  ShippingZoneModel(
    code: 'gharbiya',
    governorate: 'الغربية',
    governorateEn: 'Gharbiya',
    fee: 60,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'ghar_tanta',
    governorate: 'طنطا',
    governorateEn: 'Tanta',
    fee: 60,
    enabled: true,
    parentCode: 'gharbiya',
  ),
  ShippingZoneModel(
    code: 'ghar_mahalla',
    governorate: 'المحلة الكبرى',
    governorateEn: 'El Mahalla',
    fee: 60,
    enabled: true,
    parentCode: 'gharbiya',
  ),
  ShippingZoneModel(
    code: 'menufia',
    governorate: 'المنوفية',
    governorateEn: 'Menufia',
    fee: 60,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'men_shibin',
    governorate: 'شبين الكوم',
    governorateEn: 'Shibin El Kom',
    fee: 60,
    enabled: true,
    parentCode: 'menufia',
  ),
  ShippingZoneModel(
    code: 'men_sadat',
    governorate: 'مدينة السادات',
    governorateEn: 'Sadat City',
    fee: 65,
    enabled: true,
    parentCode: 'menufia',
  ),
  ShippingZoneModel(
    code: 'kafr_elsheikh',
    governorate: 'كفر الشيخ',
    governorateEn: 'Kafr El Sheikh',
    fee: 65,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'beheira',
    governorate: 'البحيرة',
    governorateEn: 'Beheira',
    fee: 65,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'beh_damanhour',
    governorate: 'دمنهور',
    governorateEn: 'Damanhour',
    fee: 65,
    enabled: true,
    parentCode: 'beheira',
  ),
  ShippingZoneModel(
    code: 'ismailia',
    governorate: 'الإسماعيلية',
    governorateEn: 'Ismailia',
    fee: 65,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'port_said',
    governorate: 'بور سعيد',
    governorateEn: 'Port Said',
    fee: 70,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'suez',
    governorate: 'السويس',
    governorateEn: 'Suez',
    fee: 70,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'suez_sokhna',
    governorate: 'العين السخنة',
    governorateEn: 'Ain Sokhna',
    fee: 80,
    enabled: true,
    parentCode: 'suez',
  ),
  ShippingZoneModel(
    code: 'damietta',
    governorate: 'دمياط',
    governorateEn: 'Damietta',
    fee: 65,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'dam_ras_bar',
    governorate: 'رأس البر',
    governorateEn: 'Ras El Bar',
    fee: 70,
    enabled: true,
    parentCode: 'damietta',
  ),
  ShippingZoneModel(
    code: 'fayoum',
    governorate: 'الفيوم',
    governorateEn: 'Fayoum',
    fee: 65,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'beni_suef',
    governorate: 'بني سويف',
    governorateEn: 'Beni Suef',
    fee: 70,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'minya',
    governorate: 'المنيا',
    governorateEn: 'Minya',
    fee: 75,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'assiut',
    governorate: 'أسيوط',
    governorateEn: 'Assiut',
    fee: 80,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'sohag',
    governorate: 'سوهاج',
    governorateEn: 'Sohag',
    fee: 80,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'qena',
    governorate: 'قنا',
    governorateEn: 'Qena',
    fee: 85,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'luxor',
    governorate: 'الأقصر',
    governorateEn: 'Luxor',
    fee: 90,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'aswan',
    governorate: 'أسوان',
    governorateEn: 'Aswan',
    fee: 90,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'red_sea',
    governorate: 'البحر الأحمر',
    governorateEn: 'Red Sea',
    fee: 100,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'rs_hurghada',
    governorate: 'الغردقة',
    governorateEn: 'Hurghada',
    fee: 100,
    enabled: true,
    parentCode: 'red_sea',
  ),
  ShippingZoneModel(
    code: 'rs_gouna',
    governorate: 'الجونة',
    governorateEn: 'Gouna',
    fee: 110,
    enabled: true,
    parentCode: 'red_sea',
  ),
  ShippingZoneModel(
    code: 'rs_safaga',
    governorate: 'سفاجا',
    governorateEn: 'Safaga',
    fee: 100,
    enabled: true,
    parentCode: 'red_sea',
  ),
  ShippingZoneModel(
    code: 'north_sinai',
    governorate: 'شمال سيناء',
    governorateEn: 'North Sinai',
    fee: 110,
    enabled: false,
  ),
  ShippingZoneModel(
    code: 'south_sinai',
    governorate: 'جنوب سيناء',
    governorateEn: 'South Sinai',
    fee: 110,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'ss_sharm',
    governorate: 'شرم الشيخ',
    governorateEn: 'Sharm El Sheikh',
    fee: 110,
    enabled: true,
    parentCode: 'south_sinai',
  ),
  ShippingZoneModel(
    code: 'ss_dahab',
    governorate: 'دهب',
    governorateEn: 'Dahab',
    fee: 120,
    enabled: true,
    parentCode: 'south_sinai',
  ),
  ShippingZoneModel(
    code: 'matrouh',
    governorate: 'مطروح',
    governorateEn: 'Matrouh',
    fee: 100,
    enabled: true,
  ),
  ShippingZoneModel(
    code: 'mat_north_coast',
    governorate: 'الساحل الشمالي',
    governorateEn: 'North Coast',
    fee: 100,
    enabled: true,
    parentCode: 'matrouh',
  ),
  ShippingZoneModel(
    code: 'new_valley',
    governorate: 'الوادي الجديد',
    governorateEn: 'New Valley',
    fee: 120,
    enabled: false,
  ),
];
