import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:perfume_app/core/constants/constants.dart';

class UserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String? phone;
  final String email;
  final String role;
  final String? preferredPaymentMethod;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  UserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    this.phone,
    required this.email,
    required this.role,
    String? preferredPaymentMethod,
    required this.createdAt,
    required this.updatedAt,
  }) : preferredPaymentMethod = PaymentMethodCodes.normalizePreference(
         preferredPaymentMethod,
       );

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      phone: map['phone'],
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
      preferredPaymentMethod: map['preferredPaymentMethod'] as String?,
      createdAt: map['createdAt'] is Timestamp
          ? map['createdAt']
          : Timestamp.now(),
      updatedAt: map['updatedAt'] is Timestamp
          ? map['updatedAt']
          : Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      if (phone != null) 'phone': phone,
      'email': email,
      'role': role,
      'preferredPaymentMethod': preferredPaymentMethod,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  UserModel copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    Object? preferredPaymentMethod = _preferredPaymentMethodUnchanged,
    Timestamp? updatedAt,
  }) {
    return UserModel(
      uid: uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role,
      preferredPaymentMethod:
          identical(preferredPaymentMethod, _preferredPaymentMethodUnchanged)
          ? this.preferredPaymentMethod
          : preferredPaymentMethod as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _preferredPaymentMethodUnchanged = Object();
