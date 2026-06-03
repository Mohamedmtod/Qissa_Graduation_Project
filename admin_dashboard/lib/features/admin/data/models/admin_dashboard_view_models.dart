import 'package:flutter/material.dart';

class DashboardMetric {
  const DashboardMetric({
    required this.icon,
    required this.highlight,
    required this.title,
    required this.value,
    required this.iconTint,
    required this.iconBackground,
    this.emphasizeValue = false,
  });

  final IconData icon;
  final String highlight;
  final String title;
  final String value;
  final Color iconTint;
  final Color iconBackground;
  final bool emphasizeValue;
}

class TrendPoint {
  const TrendPoint(this.label, this.value);

  final String label;
  final double value;
}

class ActivityItem {
  const ActivityItem({
    required this.title,
    required this.subtitle,
    required this.timeAgo,
    this.highlighted = false,
  });

  final String title;
  final String subtitle;
  final String timeAgo;
  final bool highlighted;
}

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class ProductEntry {
  const ProductEntry({
    this.id = '',
    required this.title,
    required this.collection,
    required this.status,
    required this.updatedAt,
    required this.notes,
    this.isVisible = true,
    this.isArchived = false,
    this.isBestSeller = false,
    this.isNew = false,
    this.imageUrl = '',
    this.imageUrls = const <String>[],
    this.nameAr = '',
    this.brand = '',
    this.brandAr = '',
    this.aliases = const <String>[],
    this.aliasesAr = const <String>[],
    this.price = 0,
    this.stock = 0,
    this.gender = 'unisex',
    this.season = 'all_season',
    this.time = 'any',
    this.occasion = 'casual',
    this.intensity = 'moderate',
    this.fragranceFamily = 'floral',
    this.topNotes = const <String>[],
    this.middleNotes = const <String>[],
    this.baseNotes = const <String>[],
    this.tags = const <String>[],
    this.size,
    this.salePrice,
  });

  final String id;
  final String title;
  final String collection;
  final String status;
  final String updatedAt;
  final String notes;
  final bool isVisible;
  final bool isArchived;
  final bool isBestSeller;
  final bool isNew;
  final String imageUrl;
  final List<String> imageUrls;
  final String nameAr;
  final String brand;
  final String brandAr;
  final List<String> aliases;
  final List<String> aliasesAr;
  final double price;
  final int stock;
  final String gender;
  final String season;
  final String time;
  final String occasion;
  final String intensity;
  final String fragranceFamily;
  final List<String> topNotes;
  final List<String> middleNotes;
  final List<String> baseNotes;
  final List<String> tags;
  final String? size;
  final double? salePrice;

  bool get isOnSale =>
      salePrice != null && salePrice! > 0 && salePrice! < price;

  double get effectivePrice => isOnSale ? salePrice! : price;
}

class BannerEntry {
  const BannerEntry({
    this.id = '',
    required this.title,
    required this.slot,
    required this.mood,
    required this.performance,
    this.queuePosition = 0,
    this.isActive = true,
    this.imageUrl = '',
    this.targetPath,
  });

  final String id;
  final String title;
  final String slot;
  final String mood;
  final String performance;
  final int queuePosition;
  final bool isActive;
  final String imageUrl;
  final String? targetPath;
}

class CategoryEntry {
  const CategoryEntry({
    this.id = '',
    required this.name,
    required this.productCount,
    required this.description,
    this.queuePosition = 0,
    this.isActive = true,
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final int productCount;
  final String description;
  final int queuePosition;
  final bool isActive;
  final String imageUrl;
}

class FinancePoint {
  const FinancePoint({
    required this.label,
    required this.revenue,
    required this.cost,
  });

  final String label;
  final double revenue;
  final double cost;
}

class FinanceRatio {
  const FinanceRatio({
    required this.label,
    required this.value,
    required this.change,
  });

  final String label;
  final String value;
  final String change;
}

class InsightTheme {
  const InsightTheme({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class DialogueTurn {
  const DialogueTurn({
    required this.speaker,
    required this.time,
    required this.message,
    required this.isAi,
  });

  final String speaker;
  final String time;
  final String message;
  final bool isAi;
}

class InsightAnnotation {
  const InsightAnnotation({
    required this.title,
    required this.description,
    required this.tags,
    required this.color,
  });

  final String title;
  final String description;
  final List<String> tags;
  final Color color;
}
