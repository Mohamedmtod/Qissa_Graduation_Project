import 'package:equatable/equatable.dart';

class AdminMediaItem extends Equatable {
  const AdminMediaItem({
    required this.key,
    required this.url,
    required this.size,
    required this.contentType,
    required this.uploadedAt,
  });

  factory AdminMediaItem.fromJson(Map<String, dynamic> json) {
    final key = _readRequiredString(json, 'key');
    final url = _readRequiredString(json, 'url');
    final size = _readRequiredInt(json, 'size');
    final contentType =
        _readOptionalString(json, 'contentType') ?? 'application/octet-stream';
    final uploadedAtRaw = _readOptionalString(json, 'uploadedAt');
    final uploadedAt =
        DateTime.tryParse(uploadedAtRaw ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    return AdminMediaItem(
      key: key,
      url: url,
      size: size,
      contentType: contentType,
      uploadedAt: uploadedAt,
    );
  }

  final String key;
  final String url;
  final int size;
  final String contentType;
  final DateTime uploadedAt;

  @override
  List<Object?> get props => [key, url, size, contentType, uploadedAt];
}

String _readRequiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw FormatException(
    'AdminMediaItem.fromJson: "$field" is required and must be a non-empty string.',
  );
}

String? _readOptionalString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) {
    return null;
  }
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

int _readRequiredInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  throw FormatException(
    'AdminMediaItem.fromJson: "$field" is required and must be a number.',
  );
}
