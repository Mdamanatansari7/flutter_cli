import 'dart:io';
import 'package:path/path.dart' as p;

class FileUtils {
  static Future<void> createDirectories(String basePath, List<String> dirs) async {
    for (final dir in dirs) {
      await Directory(p.join(basePath, dir)).create(recursive: true);
    }
  }

  static Future<void> writeFile(String path, String content) async {
    await File(path).create(recursive: true);
    await File(path).writeAsString(content);
  }

  static Future<String> readFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      return await file.readAsString();
    }
    return '';
  }

  static Future<bool> fileExists(String path) async {
    return File(path).exists();
  }

  static Future<void> deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> copyDirectory(String source, String destination) async {
    final srcDir = Directory(source);
    final destDir = Directory(destination);

    if (!await srcDir.exists()) {
      throw Exception('Source directory does not exist: $source');
    }

    await destDir.create(recursive: true);

    await for (final entity in srcDir.list()) {
      if (entity is File) {
        final destPath = p.join(destination, p.basename(entity.path));
        await entity.copy(destPath);
      } else if (entity is Directory) {
        final destSubDir = p.join(destination, p.basename(entity.path));
        await copyDirectory(entity.path, destSubDir);
      }
    }
  }

  static Future<List<String>> listFiles(String directory, {String? extension}) async {
    final dir = Directory(directory);
    if (!await dir.exists()) return [];

    final files = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        if (extension == null || entity.path.endsWith(extension)) {
          files.add(entity.path);
        }
      }
    }
    return files;
  }

  static Future<void> replaceInFile(String path, String oldStr, String newStr) async {
    final content = await readFile(path);
    final updated = content.replaceAll(oldStr, newStr);
    if (content != updated) {
      await writeFile(path, updated);
    }
  }

  static String getRelativePath(String from, String to) {
    return p.relative(to, from: from);
  }
}