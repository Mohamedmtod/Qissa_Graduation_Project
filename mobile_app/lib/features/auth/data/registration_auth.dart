import 'package:firebase_auth/firebase_auth.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: mail,
      password: password,
    );

    final user = cred.user;
    if (user == null) return GeneralErrorMessages.generic;

    final uid = user.uid;

    await user.updateDisplayName('$fName $lName');

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'uid': uid,
      'firstName': fName,
      'lastName': lName,
      'email': mail,
      'role': 'user',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

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
    if (e.code == 'too-many-requests') return AuthErrorMessages.tooManyRequests;
    if (e.code == 'network-request-failed') {
      return AuthErrorMessages.networkFailed;
    }

    return RegistrationErrorMessages.genericRegistrationFailed;
  } catch (_) {
    return GeneralErrorMessages.generic;
  }
}
