import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum AdminAccessStatus {
  unauthenticated,
  authorized,
  unauthorized,
  recoverableFailure,
}

class AdminAccessSnapshot {
  const AdminAccessSnapshot({
    required this.status,
    this.user,
    this.role,
    this.profileName,
    this.errorCode,
    this.errorMessage,
  });

  final AdminAccessStatus status;
  final User? user;
  final String? role;
  final String? profileName;
  final String? errorCode;
  final String? errorMessage;
}

class AdminAuthRepository extends ChangeNotifier {
  AdminAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance {
    _authSubscription = _firebaseAuth.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  late final StreamSubscription<User?> _authSubscription;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> signIn({required String email, required String password}) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    notifyListeners();
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    notifyListeners();
  }

  Future<AdminAccessSnapshot> resolveAccess({bool forceRefresh = false}) async {
    final user = currentUser;
    if (user == null) {
      return const AdminAccessSnapshot(
        status: AdminAccessStatus.unauthenticated,
      );
    }

    try {
      final tokenResult = await user.getIdTokenResult(forceRefresh);
      final claims = tokenResult.claims ?? const <String, dynamic>{};
      final claimRole = _roleFromClaims(claims);
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(forceRefresh ? const GetOptions(source: Source.server) : null);
      final data = userDoc.data();
      final firestoreRole = data?['role']?.toString();
      final role = claimRole ?? firestoreRole;
      final profileName = _resolveProfileName(user: user, data: data);
      final isAdmin = role == 'admin';

      return AdminAccessSnapshot(
        status: isAdmin
            ? AdminAccessStatus.authorized
            : AdminAccessStatus.unauthorized,
        user: user,
        role: role,
        profileName: profileName,
      );
    } on FirebaseException catch (error) {
      if (_isRecoverableAccessError(error.code)) {
        return AdminAccessSnapshot(
          status: AdminAccessStatus.recoverableFailure,
          user: user,
          errorCode: error.code,
          errorMessage: error.message,
        );
      }

      return AdminAccessSnapshot(
        status: AdminAccessStatus.unauthorized,
        user: user,
        errorCode: error.code,
        errorMessage: error.message,
      );
    }
  }

  bool _isRecoverableAccessError(String code) {
    switch (code.toLowerCase().trim()) {
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
      case 'resource-exhausted':
      case 'aborted':
      case 'internal':
        return true;
      case 'permission-denied':
        return false;
      default:
        return false;
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  String? _resolveProfileName({
    required User user,
    required Map<String, dynamic>? data,
  }) {
    final effectiveData = _extractProfilePayload(data);

    final firstName = _readFirstNonEmpty(effectiveData, const [
      'firstName',
      'first_name',
      'fName',
      'f_name',
      'givenName',
      'given_name',
      'firstname',
    ]);
    final lastName = _readFirstNonEmpty(effectiveData, const [
      'lastName',
      'last_name',
      'lName',
      'l_name',
      'familyName',
      'family_name',
      'lastname',
      'surname',
    ]);

    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    if (firstName != null) {
      return firstName;
    }

    final candidates = <String?>[
      _readFirstNonEmpty(effectiveData, const ['fullName', 'full_name']),
      effectiveData?['displayName']?.toString(),
      effectiveData?['name']?.toString(),
      effectiveData?['username']?.toString(),
      user.displayName,
      _emailLocalPart(user.email),
      lastName,
    ];

    for (final candidate in candidates) {
      final normalized = candidate?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
  }

  String? _roleFromClaims(Map<String, dynamic> claims) {
    final role = claims['role']?.toString().trim().toLowerCase();
    if (role == 'admin' || role == 'employee') {
      return role;
    }

    final admin = claims['admin'];
    if (admin == true || admin?.toString().toLowerCase() == 'true') {
      return 'admin';
    }

    return null;
  }

  Map<String, dynamic>? _extractProfilePayload(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }

    final profile = data['profile'];
    if (profile is Map<String, dynamic>) {
      return <String, dynamic>{...data, ...profile};
    }

    return data;
  }

  String? _readFirstNonEmpty(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) {
      return null;
    }

    final normalizedEntries = <String, dynamic>{};
    for (final entry in data.entries) {
      normalizedEntries[_normalizeKey(entry.key)] = entry.value;
    }

    for (final key in keys) {
      final directValue = data[key]?.toString().trim();
      if (directValue != null && directValue.isNotEmpty) {
        return directValue;
      }

      final normalizedValue = normalizedEntries[_normalizeKey(key)]
          ?.toString()
          .trim();
      final value = normalizedValue;
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  String _normalizeKey(String value) {
    final lower = value.toLowerCase().trim();
    return lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String? _emailLocalPart(String? email) {
    if (email == null || email.trim().isEmpty || !email.contains('@')) {
      return null;
    }

    final localPart = email.split('@').first.trim();
    return localPart.isEmpty ? null : localPart;
  }
}
