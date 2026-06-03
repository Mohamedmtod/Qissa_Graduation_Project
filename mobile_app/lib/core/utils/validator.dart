import 'package:flutter/material.dart';
import 'package:perfume_app/core/constants/constants.dart';

class PasswordRules {
  static const int minLength = 8;
  static final RegExp upperCaseRegex = RegExp(r'[A-Z]');
  static final RegExp lowerCaseRegex = RegExp(r'[a-z]');
  static final RegExp digitRegex = RegExp(r'[0-9]');
  static final RegExp specialCharRegex = RegExp(r'[!@#\$%\^&*()_\-+=?.,/|]');
  static final RegExp englishOnlyRegex = RegExp(
    r'^[A-Za-z0-9!@#\$%\^&*()_\-+=?.,/|]*$',
  );

  static bool hasMinLength(String pass) => pass.length >= minLength;
  static bool hasUpperCase(String pass) => upperCaseRegex.hasMatch(pass);
  static bool hasLowerCase(String pass) => lowerCaseRegex.hasMatch(pass);
  static bool hasDigit(String pass) => digitRegex.hasMatch(pass);
  static bool hasSpecialChar(String pass) => specialCharRegex.hasMatch(pass);
  static bool isEnglishOnly(String pass) => englishOnlyRegex.hasMatch(pass);
}

String? validateRegPass(String? pass) {
  pass = pass ?? "";
  if (pass.isEmpty) {
    return PasswordErrorMessages.empty;
  } else if (!PasswordRules.isEnglishOnly(pass)) {
    return PasswordErrorMessages.englishOnly;
  } else if (!PasswordRules.hasMinLength(pass)) {
    return PasswordErrorMessages.short;
  } else if (!PasswordRules.hasLowerCase(pass)) {
    return PasswordErrorMessages.lowerCase;
  } else if (!PasswordRules.hasUpperCase(pass)) {
    return PasswordErrorMessages.upperCase;
  } else if (!PasswordRules.hasDigit(pass)) {
    return PasswordErrorMessages.digit;
  } else if (!PasswordRules.hasSpecialChar(pass)) {
    return PasswordErrorMessages.specialChar;
  }
  return null;
}

String? validateEmail(String? email) {
  email = (email ?? "").trim();
  if (email.isEmpty) {
    return EmailErrorMessages.empty;
  } else if (email.contains(".") && email.contains("@")) {
    return null;
  } else {
    return EmailErrorMessages.invalid;
  }
}

String? validateLoginPass(String? pass) {
  final p = pass ?? '';
  if (p.isEmpty) return PasswordErrorMessages.empty;
  return null;
}

String? nameValidator(String? name) {
  final n = (name ?? '').trim();
  if (n.isEmpty) return NameValidatorMessages.empty;
  if (n.length < 2) return NameValidatorMessages.tooShort;

  // Allows Arabic and English letters and spaces
  final nameRegex = RegExp(r'^[a-zA-Z\u0621-\u064A\s]+$');
  if (!nameRegex.hasMatch(n)) return NameValidatorMessages.noSymbols;

  return null;
}

String? confirmPasswordValidator(
  String? confirmPass,
  TextEditingController passwordController,
) {
  final confirm = confirmPass ?? '';
  if (confirm.isEmpty) return ConfirmPasswordValidatorMessages.empty;
  if (confirm != passwordController.text) {
    return ConfirmPasswordValidatorMessages.notMatch;
  }
  return null;
}

// ── Egyptian phone number: 010, 011, 012, 015 followed by 8 digits ──
final _egyptianPhoneRegex = RegExp(r'^(010|011|012|015)\d{8}$');

String? phoneValidator(String? phone) {
  final p = (phone ?? '').trim();
  if (p.isEmpty) return AddressErrorMessages.phoneEmpty;
  if (!_egyptianPhoneRegex.hasMatch(p)) {
    return AddressErrorMessages.phoneInvalid;
  }
  return null;
}

String? optionalPhoneValidator(String? phone) {
  final p = (phone ?? '').trim();
  if (p.isEmpty) return null;
  return phoneValidator(p);
}

String? requiredFieldValidator(String? value) {
  final v = (value ?? '').trim();
  if (v.isEmpty) return NameValidatorMessages.empty;
  return null;
}

String? validateSearch(String? query) {
  final q = (query ?? '').trim();
  if (q.length < 2) return SearchErrorMessages.tooShort;
  return null;
}
