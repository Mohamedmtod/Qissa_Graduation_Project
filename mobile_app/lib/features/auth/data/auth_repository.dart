import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:perfume_app/core/constants/constants.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final Dio _dio;
  final String _authWorkerBaseUrl;

  static const String _defaultAuthWorkerBaseUrl = String.fromEnvironment(
    'AUTH_WORKER_URL',
    defaultValue: 'https://perfume-auth-worker.qessa-prefume.workers.dev',
  );

  AuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    Dio? dio,
    String? authWorkerBaseUrl,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _dio = dio ?? Dio(),
       _authWorkerBaseUrl = (authWorkerBaseUrl ?? _defaultAuthWorkerBaseUrl)
           .trim()
           .replaceAll(RegExp(r'/$'), '');

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<String?> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      try {
        await ensureCurrentUserProfile();
      } catch (_) {
        // Keep login behavior stable; profile repair can be retried later.
      }
      return null; // success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return AuthErrorMessages.userNotFound;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return AuthErrorMessages.invalidCredentials;
      }
      if (e.code == 'invalid-email') {
        return AuthErrorMessages.invalidEmail;
      }
      if (e.code == 'too-many-requests') {
        return AuthErrorMessages.tooManyRequests;
      }
      if (e.code == 'network-request-failed') {
        return AuthErrorMessages.networkFailed;
      }
      return AuthErrorMessages.genericLoginFailed;
    } catch (_) {
      return GeneralErrorMessages.generic;
    }
  }

  Future<String?> createEmailAndPassword(
    String firstName,
    String lastName,
    String email,
    String password,
  ) async {
    final fName = firstName.trim();
    final lName = lastName.trim();
    final mail = email.trim();

    try {
      final cred = await _firebaseAuth.createUserWithEmailAndPassword(
        email: mail,
        password: password,
      );

      final user = cred.user;
      if (user == null) return GeneralErrorMessages.generic;

      final uid = user.uid;

      await user.updateDisplayName('$fName $lName');

      try {
        await _writeUserProfile(
          uid: uid,
          firstName: fName,
          lastName: lName,
          email: mail,
          includeCreatedAt: true,
        );
      } on FirebaseException {
        try {
          await _writeUserProfile(
            uid: uid,
            firstName: fName,
            lastName: lName,
            email: mail,
            includeCreatedAt: true,
          );
        } catch (_) {
          await _signOutAfterPartialRegistration();
          return RegistrationErrorMessages.profileSetupFailed;
        }
      } catch (_) {
        await _signOutAfterPartialRegistration();
        return RegistrationErrorMessages.profileSetupFailed;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return RegistrationErrorMessages.emailAlreadyInUse;
      }
      if (e.code == 'weak-password') {
        return RegistrationErrorMessages.weakPassword;
      }
      if (e.code == 'invalid-email') {
        return RegistrationErrorMessages.invalidEmail;
      }
      if (e.code == 'too-many-requests') {
        return AuthErrorMessages.tooManyRequests;
      }
      if (e.code == 'network-request-failed') {
        return AuthErrorMessages.networkFailed;
      }

      return RegistrationErrorMessages.genericRegistrationFailed;
    } catch (_) {
      return GeneralErrorMessages.generic;
    }
  }

  Future<void> ensureCurrentUserProfile() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();
    if (snapshot.exists) return;

    final displayName = user.displayName?.trim() ?? '';
    final nameParts = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';

    await _writeUserProfile(
      uid: user.uid,
      firstName: firstName,
      lastName: lastName,
      email: user.email?.trim() ?? '',
      includeCreatedAt: true,
    );
  }

  Future<void> _writeUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    required bool includeCreatedAt,
  }) {
    return _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'role': 'user',
      if (includeCreatedAt) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _signOutAfterPartialRegistration() async {
    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      // Registration already failed; avoid masking the profile setup error.
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      final acs = ActionCodeSettings(
        url: 'https://reset-password-qessa.pages.dev/reset.html',
        handleCodeInApp: true,
      );

      await _firebaseAuth.sendPasswordResetEmail(
        email: email.trim(),
        actionCodeSettings: acs,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return AuthErrorMessages.userNotFound;
      if (e.code == 'invalid-email') return AuthErrorMessages.invalidEmail;
      return GeneralErrorMessages.generic;
    } catch (_) {
      return GeneralErrorMessages.generic;
    }
  }

  Future<String?> requestPasswordResetOtp(String email) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        _buildAuthWorkerUrl('/password-reset/request'),
        data: {'email': email.trim()},
        options: _authWorkerOptions(),
      );
      return null;
    } on DioException catch (e) {
      return _extractWorkerError(e);
    } catch (_) {
      return GeneralErrorMessages.generic;
    }
  }

  Future<String?> confirmPasswordResetOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        _buildAuthWorkerUrl('/password-reset/confirm'),
        data: {
          'email': email.trim(),
          'otp': otp.trim(),
          'newPassword': newPassword,
        },
        options: _authWorkerOptions(),
      );
      return null;
    } on DioException catch (e) {
      return _extractWorkerError(e);
    } catch (_) {
      return GeneralErrorMessages.generic;
    }
  }

  Future<String?> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        _buildAuthWorkerUrl('/password-reset/verify'),
        data: {'email': email.trim(), 'otp': otp.trim()},
        options: _authWorkerOptions(),
      );
      return null;
    } on DioException catch (e) {
      return _extractWorkerError(e);
    } catch (_) {
      return GeneralErrorMessages.generic;
    }
  }

  String _buildAuthWorkerUrl(String path) {
    if (_authWorkerBaseUrl.isEmpty) {
      throw StateError('AUTH_WORKER_URL is not configured.');
    }
    return '$_authWorkerBaseUrl$path';
  }

  Options _authWorkerOptions() {
    return Options(
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 25),
    );
  }

  String _extractWorkerError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return AuthErrorMessages.networkFailed;
    }

    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['error'] ?? data['message'] ?? data['details'];
      if (message is String && message.trim().isNotEmpty) {
        final normalized = message.trim();
        if (_isSafePasswordResetWorkerMessage(normalized)) {
          return normalized;
        }
        if (e.response?.statusCode == 429) {
          return AuthErrorMessages.tooManyRequests;
        }
      }
    }
    return GeneralErrorMessages.generic;
  }

  bool _isSafePasswordResetWorkerMessage(String message) {
    return const <String>{
      'Invalid or expired code.',
      'Password is required.',
      PasswordErrorMessages.short,
      PasswordErrorMessages.lowerCase,
      PasswordErrorMessages.upperCase,
      PasswordErrorMessages.digit,
      PasswordErrorMessages.specialChar,
      PasswordErrorMessages.englishOnly,
    }.contains(message);
  }

  Future<String?> updatePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return GeneralErrorMessages.generic;

      // Re-authenticate user first using current credentials
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);

      // Update password
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Incorrect current password.';
      }
      if (e.code == 'weak-password') {
        return RegistrationErrorMessages.weakPassword;
      }
      return 'Failed to update password. Please try again.';
    } catch (_) {
      return GeneralErrorMessages.generic;
    }
  }

  Future<String?> requestAccountDeletion({String? reason}) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return GeneralErrorMessages.generic;

      final now = FieldValue.serverTimestamp();
      final requestRef = _firestore
          .collection('account_deletion_requests')
          .doc(user.uid);
      final existing = await requestRef.get();
      if (existing.exists) {
        return null;
      }

      await requestRef.set({
        'userId': user.uid,
        'email': user.email?.trim() ?? '',
        'reason': reason?.trim() ?? '',
        'status': 'pending',
        'createdAt': now,
        'updatedAt': now,
      });

      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return 'Unable to submit account deletion request.';
      }
      return GeneralErrorMessages.generic;
    } catch (_) {
      return GeneralErrorMessages.generic;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
