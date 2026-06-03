import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserRecord {
  const AdminUserRecord({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final String email;
  final String role;
  final DateTime createdAt;

  String get createdLabel {
    if (createdAt.millisecondsSinceEpoch <= 0) {
      return 'N/A';
    }
    return createdAt.toLocal().toString().split('.').first;
  }

  factory AdminUserRecord.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final firstName = data['firstName']?.toString().trim() ?? '';
    final lastName = data['lastName']?.toString().trim() ?? '';
    final displayName = [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ').trim();
    final createdAt = data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);

    return AdminUserRecord(
      id: doc.id,
      displayName: displayName.isEmpty ? doc.id : displayName,
      email: data['email']?.toString().trim() ?? '',
      role: data['role']?.toString().trim().toLowerCase() ?? 'user',
      createdAt: createdAt,
    );
  }
}

class AdminUserRoleUpdateResult {
  const AdminUserRoleUpdateResult({
    required this.ok,
    required this.uid,
    required this.role,
    required this.traceId,
  });

  final bool ok;
  final String uid;
  final String role;
  final String traceId;

  factory AdminUserRoleUpdateResult.fromJson(Map<String, dynamic> json) {
    return AdminUserRoleUpdateResult(
      ok: json['ok'] == true,
      uid: json['uid']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      traceId: json['traceId']?.toString() ?? '',
    );
  }
}
