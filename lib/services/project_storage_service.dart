import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/generated_pattern.dart';
import '../models/saved_project.dart';

class ProjectStorageService {
  Future<SavedProject> saveGeneratedPattern(
    GeneratedPattern pattern, {
    String? title,
  }) async {
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final root = await getApplicationDocumentsDirectory();
    final projectDir = Directory('${root.path}/projects/$id');
    await projectDir.create(recursive: true);

    final patternPath = '${projectDir.path}/pattern.rgba';
    await File(patternPath).writeAsBytes(pattern.pixels, flush: true);

    final saved = SavedProject(
      id: id,
      title: title ?? _defaultTitle(now),
      createdAt: now,
      updatedAt: now,
      patternPath: patternPath,
      draft: pattern.draft,
      generatedPattern: pattern,
    );

    final manifest = File('${projectDir.path}/project.json');
    final temp = File('${projectDir.path}/project.tmp.json');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(saved.toJson()),
      flush: true,
    );
    if (await manifest.exists()) {
      await manifest.delete();
    }
    await temp.rename(manifest.path);

    return saved;
  }

  Future<Uint8List> readPatternBytes(String path) async {
    return File(path).readAsBytes();
  }

  String _defaultTitle(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
