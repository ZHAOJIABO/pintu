import 'draft_project.dart';
import 'generated_pattern.dart';

class SavedProject {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? thumbnailPath;
  final String? patternPath;
  final DraftProject draft;
  final GeneratedPattern? generatedPattern;

  const SavedProject({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.thumbnailPath,
    this.patternPath,
    required this.draft,
    this.generatedPattern,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'thumbnailPath': thumbnailPath,
    'patternPath': patternPath,
    'draft': draft.toJson(),
    if (generatedPattern != null)
      'generatedPattern': generatedPattern!.toJson(),
  };
}
