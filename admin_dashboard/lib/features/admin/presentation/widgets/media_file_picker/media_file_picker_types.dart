import 'dart:typed_data';

class PickedMediaFile {
  const PickedMediaFile({
    required this.name,
    required this.bytes,
    this.contentType,
    this.extension,
  });

  final String name;
  final Uint8List bytes;
  final String? contentType;
  final String? extension;
}
