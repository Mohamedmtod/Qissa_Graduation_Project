import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:perfume_app/core/theme/theme.dart';

class CustomTextField extends StatelessWidget {
  final String hintText;
  final bool hidden;
  final double paddingLeft;
  final double paddingRight;
  final double paddingTop;
  final double paddingBottom;
  final String? autofill;
  final int maxLength;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final bool textInputAction;
  final Widget? suffixIcon;
  final bool enabled;
  final void Function(String)? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final double radius;

  const CustomTextField({
    super.key,
    required this.hintText,
    required this.autofill,
    this.paddingLeft = 0,
    this.paddingRight = 0,
    this.paddingTop = 0,
    this.paddingBottom = 0,
    required this.maxLength,
    required this.hidden,
    this.controller,
    this.validator,
    this.onFieldSubmitted,
    this.textInputAction = false,
    this.enabled = true,
    this.suffixIcon,
    this.onChanged,
    this.inputFormatters,
    this.radius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: paddingLeft,
        right: paddingRight,
        top: paddingTop,
        bottom: paddingBottom,
      ),
      child: TextFormField(
        enabled: enabled,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        autofillHints: autofill != null ? [autofill!] : null,
        controller: controller,
        validator: validator,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        inputFormatters: [
          LengthLimitingTextInputFormatter(maxLength),
          ...?(inputFormatters),
        ],
        keyboardType: autofill == AutofillHints.email
            ? TextInputType.emailAddress
            : TextInputType.text,
        textInputAction: textInputAction
            ? TextInputAction.done
            : TextInputAction.next,
        obscureText: hidden,
        decoration: InputDecoration(
          hintText: hintText,
          suffixIcon: suffixIcon,
          hintStyle: TextStyle(color: lightGray),
          filled: true,
          fillColor: enabled
              ? Theme.of(context).colorScheme.surfaceContainerLowest
              : lightGray,
          border: OutlineInputBorder(),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              width: 2,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          errorMaxLines: 2,
          errorStyle: TextStyle(
            color: red,
            fontSize: 12,
            height: 1.3,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide(color: red, width: 2),
          ),

          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
            borderSide: BorderSide(color: red, width: 2),
          ),
        ),
      ),
    );
  }
}
