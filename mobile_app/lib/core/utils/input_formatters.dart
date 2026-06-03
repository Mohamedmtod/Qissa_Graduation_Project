import 'package:flutter/services.dart';

class CustomInputFormatters {
  static final name = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z\u0621-\u064A\s]'),
  );

  static final email = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z0-9@._+ \-]'),
  );

  static final digitsOnly = FilteringTextInputFormatter.digitsOnly;

  static final address = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z0-9\u0621-\u064A\s\-\/\,]'),
  );
}
