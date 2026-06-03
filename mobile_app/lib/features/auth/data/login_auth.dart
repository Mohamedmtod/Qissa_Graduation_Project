import 'package:firebase_auth/firebase_auth.dart';
import 'package:perfume_app/core/constants/constants.dart';

Future<String?> loginWithEmailAndPassword(String email, String password) async {
  try {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
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
