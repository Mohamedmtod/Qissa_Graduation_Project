// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:perfume_app_admin_dashboard/features/admin/presentation/widgets/media_file_picker/media_file_picker_types.dart';

Future<PickedMediaFile?> pickMediaImageFile() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false
    ..style.display = 'none';
  html.document.body?.append(input);

  try {
    input.click();
    try {
      await input.onChange.first.timeout(const Duration(minutes: 2));
    } on TimeoutException {
      return null;
    }

    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) {
      return null;
    }

    final reader = html.FileReader();
    final completer = Completer<PickedMediaFile?>();

    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is! String) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        return;
      }

      final separatorIndex = result.indexOf(',');
      if (separatorIndex <= -1 || separatorIndex + 1 >= result.length) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        return;
      }

      try {
        final raw = result.substring(separatorIndex + 1);
        final bytes = base64Decode(raw);
        if (!completer.isCompleted) {
          completer.complete(
            PickedMediaFile(
              name: file.name,
              bytes: bytes,
              contentType: file.type.isEmpty ? null : file.type,
              extension: _readExtension(file.name),
            ),
          );
        }
      } catch (_) {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      }
    });

    reader.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    reader.readAsDataUrl(file);
    return completer.future;
  } finally {
    input.remove();
  }
}

String? _readExtension(String fileName) {
  final parts = fileName.split('.');
  if (parts.length < 2) {
    return null;
  }
  final last = parts.last.trim();
  return last.isEmpty ? null : last;
}
