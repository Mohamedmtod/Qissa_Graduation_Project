import 'package:perfume_app/features/ai_chat/data/models/session_preferences.dart';

enum PreferenceScalar {
  gender,
  maxBudget,
  season,
  occasion,
  time,
  intensity,
  rankingStrategy,
}

enum PreferenceListField {
  preferredNotes,
  preferredTopNotes,
  preferredMiddleNotes,
  preferredBaseNotes,
  excludedNotes,
  medicalExcludedNotes,
  tags,
}

class PreferencePatch {
  final Map<PreferenceScalar, Object?> _setScalars = {};
  final Set<PreferenceScalar> _clearScalars = {};
  final Map<PreferenceListField, List<String>> _replaceLists = {};
  final Map<PreferenceListField, List<String>> _appendLists = {};
  final Map<PreferenceListField, List<String>> _removeLists = {};

  factory PreferencePatch.fromJson(Map<String, dynamic>? json) {
    final patch = PreferencePatch();
    if (json == null) return patch;

    final clearScalars = json['clearScalars'];
    if (clearScalars is Iterable) {
      for (final raw in clearScalars) {
        final field = _scalarFromWire(raw);
        if (field != null) patch.clearScalar(field);
      }
    }

    final clear = json['clear'];
    if (clear is Map) {
      for (final entry in clear.entries) {
        if (entry.value != true) continue;
        final field = _scalarFromWire(entry.key);
        if (field != null) patch.clearScalar(field);
      }
    }

    final setScalars = json['setScalars'] ?? json['replaceScalars'];
    if (setScalars is Map) {
      for (final entry in setScalars.entries) {
        final field = _scalarFromWire(entry.key);
        if (field != null) patch.setScalar(field, entry.value);
      }
    }

    _readListOps(json['replaceLists'], (field, values) {
      patch.replaceList(field, values);
    });
    _readListOps(json['appendLists'], (field, values) {
      patch.appendList(field, values);
    });
    _readListOps(json['removeLists'] ?? json['removeFromLists'], (
      field,
      values,
    ) {
      patch.removeFromList(field, values);
    });

    return patch;
  }

  PreferencePatch();

  bool get isEmpty =>
      _setScalars.isEmpty &&
      _clearScalars.isEmpty &&
      _replaceLists.isEmpty &&
      _appendLists.isEmpty &&
      _removeLists.isEmpty;

  PreferencePatch setScalar(PreferenceScalar field, Object? value) {
    _setScalars[field] = value;
    _clearScalars.remove(field);
    return this;
  }

  PreferencePatch clearScalar(PreferenceScalar field) {
    _clearScalars.add(field);
    _setScalars.remove(field);
    return this;
  }

  PreferencePatch replaceList(
    PreferenceListField field,
    Iterable<String> values,
  ) {
    _replaceLists[field] = _clean(values);
    _appendLists.remove(field);
    _removeLists.remove(field);
    return this;
  }

  PreferencePatch appendList(
    PreferenceListField field,
    Iterable<String> values,
  ) {
    _appendLists[field] = [...?_appendLists[field], ..._clean(values)];
    return this;
  }

  PreferencePatch removeFromList(
    PreferenceListField field,
    Iterable<String> values,
  ) {
    _removeLists[field] = [...?_removeLists[field], ..._clean(values)];
    return this;
  }

  Map<String, dynamic> toJson() {
    final setScalars = <String, dynamic>{};
    for (final entry in _setScalars.entries) {
      final wireKey = _scalarToWire(entry.key);
      if (wireKey == null) continue;
      final value = entry.value;
      setScalars[wireKey] = value is RankingStrategy ? value.name : value;
    }

    final clearScalars = _clearScalars
        .map(_scalarToWire)
        .whereType<String>()
        .toList(growable: false);

    final replaceLists = <String, List<String>>{
      for (final entry in _replaceLists.entries)
        _listFieldToWire(entry.key): entry.value,
    };
    final appendLists = <String, List<String>>{
      for (final entry in _appendLists.entries)
        _listFieldToWire(entry.key): entry.value,
    };
    final removeLists = <String, List<String>>{
      for (final entry in _removeLists.entries)
        _listFieldToWire(entry.key): entry.value,
    };

    return {
      if (setScalars.isNotEmpty) 'setScalars': setScalars,
      if (clearScalars.isNotEmpty) 'clearScalars': clearScalars,
      if (replaceLists.isNotEmpty) 'replaceLists': replaceLists,
      if (appendLists.isNotEmpty) 'appendLists': appendLists,
      if (removeLists.isNotEmpty) 'removeLists': removeLists,
    };
  }

  SessionPreferences applyTo(SessionPreferences base) {
    var result = base.copyWith(
      gender: _stringValue(PreferenceScalar.gender),
      maxBudget: _doubleValue(PreferenceScalar.maxBudget),
      season: _stringValue(PreferenceScalar.season),
      occasion: _stringValue(PreferenceScalar.occasion),
      time: _stringValue(PreferenceScalar.time),
      intensity: _stringValue(PreferenceScalar.intensity),
      rankingStrategy: _rankingStrategyValue(PreferenceScalar.rankingStrategy),
      clearGender: _clearScalars.contains(PreferenceScalar.gender),
      clearBudget: _clearScalars.contains(PreferenceScalar.maxBudget),
      clearSeason: _clearScalars.contains(PreferenceScalar.season),
      clearOccasion: _clearScalars.contains(PreferenceScalar.occasion),
      clearTime: _clearScalars.contains(PreferenceScalar.time),
      clearIntensity: _clearScalars.contains(PreferenceScalar.intensity),
      clearRankingStrategy: _clearScalars.contains(
        PreferenceScalar.rankingStrategy,
      ),
    );

    for (final entry in _replaceLists.entries) {
      result = _copyList(result, entry.key, entry.value);
    }

    for (final entry in _appendLists.entries) {
      final current = _listValue(result, entry.key);
      result = _copyList(
        result,
        entry.key,
        _dedupe([...current, ...entry.value]),
      );
    }

    for (final entry in _removeLists.entries) {
      final removals = entry.value.map((item) => item.toLowerCase()).toSet();
      final current = _listValue(result, entry.key)
          .where((item) => !removals.contains(item.toLowerCase()))
          .toList(growable: false);
      result = _copyList(result, entry.key, current);
    }

    return result.sanitize();
  }

  String? _stringValue(PreferenceScalar field) {
    final value = _setScalars[field];
    return value is String ? value : null;
  }

  double? _doubleValue(PreferenceScalar field) {
    final value = _setScalars[field];
    return value is num ? value.toDouble() : null;
  }

  RankingStrategy? _rankingStrategyValue(PreferenceScalar field) {
    final value = _setScalars[field];
    if (value is RankingStrategy) return value;
    if (value is! String) return null;

    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]+'),
      '',
    );
    switch (normalized) {
      case 'expensivefirst':
      case 'mostexpensive':
      case 'highestprice':
      case 'premium':
      case 'luxury':
        return RankingStrategy.expensiveFirst;
      case 'cheapestfirst':
      case 'cheapest':
      case 'cheap':
      case 'lowerprice':
      case 'lowestprice':
      case 'moreaffordable':
      case 'mostaffordable':
      case 'economy':
      case 'economic':
      case 'economical':
        return RankingStrategy.cheapestFirst;
      case 'relevancefirst':
      case 'relevance':
      case 'default':
        return null;
    }
    return null;
  }

  static List<String> _clean(Iterable<String> values) {
    return _dedupe(
      values.map((item) => item.trim()).where((item) => item.isNotEmpty),
    );
  }

  static List<String> _dedupe(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final key = value.toLowerCase();
      if (seen.add(key)) result.add(value);
    }
    return result;
  }

  static List<String> _listValue(
    SessionPreferences preferences,
    PreferenceListField field,
  ) {
    switch (field) {
      case PreferenceListField.preferredNotes:
        return preferences.preferredNotes;
      case PreferenceListField.preferredTopNotes:
        return preferences.preferredTopNotes;
      case PreferenceListField.preferredMiddleNotes:
        return preferences.preferredMiddleNotes;
      case PreferenceListField.preferredBaseNotes:
        return preferences.preferredBaseNotes;
      case PreferenceListField.excludedNotes:
        return preferences.excludedNotes;
      case PreferenceListField.medicalExcludedNotes:
        return preferences.medicalExcludedNotes;
      case PreferenceListField.tags:
        return preferences.tags;
    }
  }

  static SessionPreferences _copyList(
    SessionPreferences preferences,
    PreferenceListField field,
    List<String> values,
  ) {
    switch (field) {
      case PreferenceListField.preferredNotes:
        return preferences.copyWith(preferredNotes: values);
      case PreferenceListField.preferredTopNotes:
        return preferences.copyWith(preferredTopNotes: values);
      case PreferenceListField.preferredMiddleNotes:
        return preferences.copyWith(preferredMiddleNotes: values);
      case PreferenceListField.preferredBaseNotes:
        return preferences.copyWith(preferredBaseNotes: values);
      case PreferenceListField.excludedNotes:
        return preferences.copyWith(excludedNotes: values);
      case PreferenceListField.medicalExcludedNotes:
        return preferences.copyWith(medicalExcludedNotes: values);
      case PreferenceListField.tags:
        return preferences.copyWith(tags: values);
    }
  }

  static void _readListOps(
    Object? raw,
    void Function(PreferenceListField field, Iterable<String> values) apply,
  ) {
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      final field = _listFieldFromWire(entry.key);
      final values = entry.value;
      if (field != null && values is Iterable) {
        apply(field, values.map((item) => item.toString()));
      }
    }
  }

  static PreferenceScalar? _scalarFromWire(Object? raw) {
    final value = raw.toString().trim();
    switch (value) {
      case 'gender':
        return PreferenceScalar.gender;
      case 'maxBudget':
      case 'budget':
        return PreferenceScalar.maxBudget;
      case 'season':
        return PreferenceScalar.season;
      case 'occasion':
        return PreferenceScalar.occasion;
      case 'time':
        return PreferenceScalar.time;
      case 'intensity':
        return PreferenceScalar.intensity;
      case 'rankingStrategy':
        return PreferenceScalar.rankingStrategy;
    }
    return null;
  }

  static String? _scalarToWire(PreferenceScalar field) {
    switch (field) {
      case PreferenceScalar.gender:
        return 'gender';
      case PreferenceScalar.maxBudget:
        return 'maxBudget';
      case PreferenceScalar.season:
        return 'season';
      case PreferenceScalar.occasion:
        return 'occasion';
      case PreferenceScalar.time:
        return 'time';
      case PreferenceScalar.intensity:
        return 'intensity';
      case PreferenceScalar.rankingStrategy:
        return 'rankingStrategy';
    }
  }

  static PreferenceListField? _listFieldFromWire(Object? raw) {
    final value = raw.toString().trim();
    switch (value) {
      case 'preferredNotes':
      case 'notes':
        return PreferenceListField.preferredNotes;
      case 'preferredTopNotes':
      case 'topNotes':
        return PreferenceListField.preferredTopNotes;
      case 'preferredMiddleNotes':
      case 'middleNotes':
        return PreferenceListField.preferredMiddleNotes;
      case 'preferredBaseNotes':
      case 'baseNotes':
        return PreferenceListField.preferredBaseNotes;
      case 'excludedNotes':
        return PreferenceListField.excludedNotes;
      case 'medicalExcludedNotes':
        return PreferenceListField.medicalExcludedNotes;
      case 'tags':
        return PreferenceListField.tags;
    }
    return null;
  }

  static String _listFieldToWire(PreferenceListField field) {
    switch (field) {
      case PreferenceListField.preferredNotes:
        return 'preferredNotes';
      case PreferenceListField.preferredTopNotes:
        return 'preferredTopNotes';
      case PreferenceListField.preferredMiddleNotes:
        return 'preferredMiddleNotes';
      case PreferenceListField.preferredBaseNotes:
        return 'preferredBaseNotes';
      case PreferenceListField.excludedNotes:
        return 'excludedNotes';
      case PreferenceListField.medicalExcludedNotes:
        return 'medicalExcludedNotes';
      case PreferenceListField.tags:
        return 'tags';
    }
  }
}
