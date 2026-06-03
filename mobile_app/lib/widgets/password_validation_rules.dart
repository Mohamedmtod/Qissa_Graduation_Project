import 'package:flutter/material.dart';
import 'package:perfume_app/core/constants/constants.dart';
import 'package:perfume_app/core/theme/theme.dart';
import 'package:perfume_app/core/utils/validator.dart';

class PasswordValidationRules extends StatelessWidget {
  final String password;

  const PasswordValidationRules({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    // 1. High Priority Blocker: English Only
    if (!PasswordRules.isEnglishOnly(password)) {
      return _buildErrorRule(PasswordErrorMessages.englishOnly);
    }

    // 2. Sequential rules
    final rules = [
      _RuleData(
        text: PasswordErrorMessages.lowerCase,
        isMet: PasswordRules.hasLowerCase(password),
      ),
      _RuleData(
        text: PasswordErrorMessages.upperCase,
        isMet: PasswordRules.hasUpperCase(password),
      ),
      _RuleData(
        text: PasswordErrorMessages.digit,
        isMet: PasswordRules.hasDigit(password),
      ),
      _RuleData(
        text: PasswordErrorMessages.specialChar,
        isMet: PasswordRules.hasSpecialChar(password),
      ),
      _RuleData(
        text: PasswordErrorMessages.short,
        isMet: PasswordRules.hasMinLength(password),
      ),
    ];

    // Find the first rule that is NOT met
    final firstUnmetRule = rules.where((rule) => !rule.isMet).firstOrNull;

    if (firstUnmetRule == null) {
      // All rules are met, show nothing as requested
      return const SizedBox.shrink();
    }

    return _buildErrorRule(firstUnmetRule.text);
  }

  Widget _buildErrorRule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: red,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: red,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleData {
  final String text;
  final bool isMet;

  _RuleData({required this.text, required this.isMet});
}
