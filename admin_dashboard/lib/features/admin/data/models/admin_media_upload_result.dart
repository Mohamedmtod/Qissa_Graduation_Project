import 'package:equatable/equatable.dart';

class AdminMediaUploadResult extends Equatable {
  const AdminMediaUploadResult({
    required this.key,
    required this.url,
    required this.size,
  });

  factory AdminMediaUploadResult.fromJson(Map<String, dynamic> json) {
    final key = _readRequiredString(json, 'key');
    final url = _readRequiredString(json, 'url');
    final size = _readRequiredInt(json, 'size');
    return AdminMediaUploadResult(key: key, url: url, size: size);
  }

  final String key;
  final String url;
  final int size;

  @override
  List<Object?> get props => [key, url, size];
}

String _readRequiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw FormatException(
    'AdminMediaUploadResult.fromJson: "$field" is required and must be a non-empty string.',
  );
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
    'AdminMediaUploadResult.fromJson: "$field" is required and must be a number.',
  );
}
