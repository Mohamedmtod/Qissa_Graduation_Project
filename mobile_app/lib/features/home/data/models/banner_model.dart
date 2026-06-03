import 'package:cloud_firestore/cloud_firestore.dart';

class BannerModel {
  final String id;
  final String imageUrl;
  final String? targetCategory;
  final String? targetProductId;
  final String? targetRoute;
  final String? title;
  final Timestamp? createdAt;
  final int? queuePosition;
  final bool isActive;

  BannerModel({
    required this.id,
    required this.imageUrl,
    this.targetCategory,
    this.targetProductId,
    this.targetRoute,
    this.title,
    this.createdAt,
    this.queuePosition,
    this.isActive = true,
  });

  factory BannerModel.fromMap({
    required Map<String, dynamic> map,
    required String documentId,
  }) {
    return BannerModel(
      id: documentId,
      imageUrl: map['imageUrl'] as String,
      targetCategory: map['targetCategory'] as String?,
      targetProductId: map['targetProductId'] as String?,
      targetRoute: map['targetRoute'] as String?,
      title: map['title'] as String?,
      createdAt: map['createdAt'] is Timestamp
          ? map['createdAt']
          : Timestamp.now(),
      queuePosition: map['queuePosition'] as int?,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'targetCategory': targetCategory,
      'targetProductId': targetProductId,
      'targetRoute': targetRoute,
      'title': title,
      'createdAt': createdAt,
      'queuePosition': queuePosition,
      'isActive': isActive,
    };
  }
}
