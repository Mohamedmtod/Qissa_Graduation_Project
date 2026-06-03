import 'package:equatable/equatable.dart';

class ExternalPerfumeCandidate extends Equatable {
  final String id;
  final String displayName;
  final String brand;
  final String sourceUrl;
  final double score;

  const ExternalPerfumeCandidate({
    required this.id,
    required this.displayName,
    required this.brand,
    required this.sourceUrl,
    this.score = 0,
  });

  String get label {
    final cleanBrand = brand.trim();
    if (cleanBrand.isEmpty) return displayName;
    return '$displayName - $cleanBrand';
  }

  factory ExternalPerfumeCandidate.fromMap(Map<String, dynamic> map) {
    return ExternalPerfumeCandidate(
      id: (map['id'] ?? '').toString().trim(),
      displayName: (map['displayName'] ?? '').toString().trim(),
      brand: (map['brand'] ?? '').toString().trim(),
      sourceUrl: (map['sourceUrl'] ?? '').toString().trim(),
      score: _asDouble(map['score']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'brand': brand,
      'sourceUrl': sourceUrl,
      'score': score,
    };
  }

  bool get isUsable => displayName.isNotEmpty && sourceUrl.isNotEmpty;

  @override
  List<Object?> get props => [id, displayName, brand, sourceUrl, score];
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? 0;
  return 0;
}
