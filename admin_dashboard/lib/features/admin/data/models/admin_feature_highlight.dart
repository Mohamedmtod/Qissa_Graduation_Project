import 'package:equatable/equatable.dart';

class AdminFeatureHighlight extends Equatable {
  const AdminFeatureHighlight({
    required this.title,
    required this.description,
    required this.imageUrl,
    this.actionLabel,
  });

  final String title;
  final String description;
  final String imageUrl;
  final String? actionLabel;

  @override
  List<Object?> get props => [title, description, imageUrl, actionLabel];
}
