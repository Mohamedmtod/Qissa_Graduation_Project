import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

String buildCsv(List<List<Object?>> rows) {
  final buffer = StringBuffer();
  for (final row in rows) {
    final encoded = row
        .map((value) {
          final text = (value ?? '').toString().replaceAll('"', '""');
          return '"$text"';
        })
        .join(',');
    buffer.writeln(encoded);
  }
  return buffer.toString();
}

Future<bool> saveTextFile({
  required String dialogTitle,
  required String fileName,
  required String extension,
  required String content,
}) async {
  try {
    final saveResult = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
    return saveResult != null;
  } catch (_) {
    return false;
  }
}
