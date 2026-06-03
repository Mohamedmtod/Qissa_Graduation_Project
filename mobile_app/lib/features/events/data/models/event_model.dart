import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String userId;
  final String eventType;
  final Map<String, dynamic> data;
  final Timestamp timestamp;

  EventModel({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'eventType': eventType,
      'data': data,
      'timestamp': timestamp,
    };
  }
}
