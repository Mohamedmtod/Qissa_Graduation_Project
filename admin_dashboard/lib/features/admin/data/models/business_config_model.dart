class BusinessConfigModel {
  final double serverCosts;
  final double manufacturingCosts;
  final double otherFixedCosts;
  final DateTime updatedAt;

  BusinessConfigModel({
    required this.serverCosts,
    required this.manufacturingCosts,
    required this.otherFixedCosts,
    required this.updatedAt,
  });

  double get totalFixedCosts =>
      serverCosts + manufacturingCosts + otherFixedCosts;

  factory BusinessConfigModel.fromMap(Map<String, dynamic> map) {
    return BusinessConfigModel(
      serverCosts: (map['serverCosts'] ?? 0).toDouble(),
      manufacturingCosts: (map['manufacturingCosts'] ?? 0).toDouble(),
      otherFixedCosts: (map['otherFixedCosts'] ?? 0).toDouble(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serverCosts': serverCosts,
      'manufacturingCosts': manufacturingCosts,
      'otherFixedCosts': otherFixedCosts,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  BusinessConfigModel copyWith({
    double? serverCosts,
    double? manufacturingCosts,
    double? otherFixedCosts,
    DateTime? updatedAt,
  }) {
    return BusinessConfigModel(
      serverCosts: serverCosts ?? this.serverCosts,
      manufacturingCosts: manufacturingCosts ?? this.manufacturingCosts,
      otherFixedCosts: otherFixedCosts ?? this.otherFixedCosts,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
