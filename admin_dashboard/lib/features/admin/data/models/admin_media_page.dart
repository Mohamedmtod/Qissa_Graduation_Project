import 'package:equatable/equatable.dart';

import 'package:perfume_app_admin_dashboard/features/admin/data/models/admin_media_item.dart';

class AdminMediaPage extends Equatable {
  const AdminMediaPage({
    required this.items,
    required this.cursor,
    required this.truncated,
  });

  factory AdminMediaPage.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'];
    if (itemsRaw is! List) {
      throw const FormatException(
        'AdminMediaPage.fromJson: "items" must be a list.',
      );
    }

    final items = itemsRaw.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException(
          'AdminMediaPage.fromJson: each item must be an object.',
        );
      }
      return AdminMediaItem.fromJson(entry);
    }).toList();

    final truncatedRaw = json['truncated'];
    if (truncatedRaw is! bool) {
      throw const FormatException(
        'AdminMediaPage.fromJson: "truncated" must be a boolean.',
      );
    }

    final cursorRaw = json['cursor'];
    String? cursor;
    if (cursorRaw == null) {
      cursor = null;
    } else if (cursorRaw is String) {
      cursor = cursorRaw.trim().isEmpty ? null : cursorRaw.trim();
    } else {
      throw const FormatException(
        'AdminMediaPage.fromJson: "cursor" must be a string or null.',
      );
    }

    return AdminMediaPage(
      items: items,
      cursor: cursor,
      truncated: truncatedRaw,
    );
  }

  final List<AdminMediaItem> items;
  final String? cursor;
  final bool truncated;

  @override
  List<Object?> get props => [items, cursor, truncated];
}
