import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:ninjadev/src/services/config_service.dart';
import 'package:ninjadev/src/utils/file_utils.dart';

class TemplateInfo {
  final String name;
  final String description;
  final String? version;
  final String? author;
  final String? license;
  final bool installed;
  final String source;
  final List<String> tags;
  final List<TemplateVariable> variables;
  TemplateInfo({
    required this.name,
    required this.description,
    this.version,
    this.author,
    this.license,
    this.installed = false,
    this.source = 'local',
    this.tags = const [],
    this.variables = const [],
  });
}

class TemplateVariable {
  final String name;
  final String type;
  final String description;
  final String? defaultValue;
  TemplateVariable({
    required this.name,
    required this.type,
    this.description = '',
    this.defaultValue,
  });
}

class TemplateServerService {
  final ConfigService _config;
  final Logger _logger;
  TemplateServerService(this._config, this._logger);
  String get _serverUrl {
    return _config.get('templates.server_url') as String? ?? 'https://templates.ninjadev.dev';
  }
  String get _cacheDir {
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/tmp';
    return p.join(home, '.ninjadev', 'templates');
  }
  Future<List<TemplateInfo>> listTemplates({bool includeRemote = false}) async {
    final templates = <TemplateInfo>[];
    // Local templates
    templates.addAll(await _listLocalTemplates());
    // Installed custom templates
    templates.addAll(await _listInstalledTemplates());
    // Remote templates
    if (includeRemote) {
      try {
        templates.addAll(await _fetchRemoteTemplateList());
      } catch (e) {
        _logger.warn('Could not fetch remote templates: $e');
      }
    }
    return templates;
  }
  Future<List<TemplateInfo>> _listLocalTemplates() async {
    final templates = <TemplateInfo>[];
    final templateDir = Directory(p.join(_getPackageRoot(), 'templates'));
    if (!await templateDir.exists()) return templates;
    await for (final entity in templateDir.list()) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        templates.add(TemplateInfo(
          name: name,
          description: '${_capitalize(name)} template',
          installed: true,
          source: 'built-in',
        ));
      }
    }
    return templates;
  }
  Future<List<TemplateInfo>> _listInstalledTemplates() async {
    final templates = <TemplateInfo>[];
    final cacheDir = Directory(_cacheDir);
    if (!await cacheDir.exists()) return templates;
    await for (final entity in cacheDir.list()) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        final metadataPath = p.join(entity.path, 'metadata.json');
        if (await File(metadataPath).exists()) {
          try {
            final data = json.decode(await File(metadataPath).readAsString()) as Map<String, dynamic>;
            templates.add(TemplateInfo(
              name: name,
              description: data['description'] as String? ?? 'Custom template',
              version: data['version'] as String?,
              author: data['author'] as String?,
              license: data['license'] as String?,
              installed: true,
              source: 'cached',
              tags: (data['tags'] as List?)?.cast<String>() ?? [],
            ));
          } catch (_) {
            templates.add(TemplateInfo(
              name: name,
              description: 'Custom template (no metadata)',
              installed: true,
              source: 'cached',
            ));
          }
        }
      }
    }
    return templates;
  }
  Future<List<TemplateInfo>> _fetchRemoteTemplateList() async {
    final uri = Uri.parse('$_serverUrl/api/templates');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];
    final data = json.decode(response.body) as List;
    return data.map((t) => TemplateInfo(
      name: t['name'] as String,
      description: t['description'] as String? ?? '',
      version: t['version'] as String?,
      author: t['author'] as String?,
      license: t['license'] as String?,
      installed: false,
      source: 'remote',
      tags: (t['tags'] as List?)?.cast<String>() ?? [],
      variables: (t['variables'] as List?)?.map((v) => TemplateVariable(
        name: v['name'] as String,
        type: v['type'] as String? ?? 'string',
        description: v['description'] as String? ?? '',
        defaultValue: v['default'] as String?,
      )).toList() ?? [],
    )).toList();
  }
  Future<TemplateInfo?> getTemplateInfo(String name) async {
    // Check local
    final localPath = p.join(_getPackageRoot(), 'templates', name);
    if (await Directory(localPath).exists()) {
      return TemplateInfo(
        name: name,
        description: '${_capitalize(name)} template',
        installed: true,
        source: 'built-in',
      );
    }
    // Check cached
    final cachedPath = p.join(_cacheDir, name);
    if (await Directory(cachedPath).exists()) {
      final metadataPath = p.join(cachedPath, 'metadata.json');
      if (await File(metadataPath).exists()) {
        try {
          final data = json.decode(await File(metadataPath).readAsString()) as Map<String, dynamic>;
          return TemplateInfo(
            name: name,
            description: data['description'] as String? ?? '',
            version: data['version'] as String?,
            author: data['author'] as String?,
            license: data['license'] as String?,
            installed: true,
            source: 'cached',
            tags: (data['tags'] as List?)?.cast<String>() ?? [],
          );
        } catch (_) {}
      }
    }
    // Try remote
    try {
      final uri = Uri.parse('$_serverUrl/api/templates/$name');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final t = json.decode(response.body) as Map<String, dynamic>;
        return TemplateInfo(
          name: t['name'] as String,
          description: t['description'] as String? ?? '',
          version: t['version'] as String?,
          author: t['author'] as String?,
          license: t['license'] as String?,
          installed: false,
          source: 'remote',
          tags: (t['tags'] as List?)?.cast<String>() ?? [],
        );
      }
    } catch (_) {}
    return null;
  }
  Future<void> addTemplate(String name, {String? gitUrl, String? localPath}) async {
    if (gitUrl != null) {
      await _downloadTemplateFromGit(name, gitUrl);
    } else if (localPath != null) {
      await _copyTemplateFromLocal(name, localPath);
    } else {
      throw Exception('Either gitUrl or localPath is required');
    }
  }
  Future<void> _downloadTemplateFromGit(String name, String gitUrl) async {
    final targetDir = p.join(_cacheDir, name);
    if (await Directory(targetDir).exists()) {
      await Directory(targetDir).delete(recursive: true);
    }
    final result = await Process.run('git', ['clone', gitUrl, targetDir], runInShell: true);
    if (result.exitCode != 0) {
      throw Exception('Failed to clone template: ${result.stderr}');
    }
  }
  Future<void> _copyTemplateFromLocal(String name, String sourcePath) async {
    final targetDir = p.join(_cacheDir, name);
    if (await Directory(targetDir).exists()) {
      await Directory(targetDir).delete(recursive: true);
    }
    await Directory(targetDir).create(recursive: true);
    await FileUtils.copyDirectory(sourcePath, targetDir);
  }
  Future<void> removeTemplate(String name) async {
    final targetDir = Directory(p.join(_cacheDir, name));
    if (!await targetDir.exists()) {
      throw Exception('Template $name is not installed');
    }
    await targetDir.delete(recursive: true);
  }
  Future<void> updateTemplate(String name) async {
    final targetDir = p.join(_cacheDir, name);
    if (!await Directory(targetDir).exists()) {
      throw Exception('Template $name is not installed');
    }
    final metadataPath = p.join(targetDir, 'metadata.json');
    if (!await File(metadataPath).exists()) {
      throw Exception('Template $name has no metadata. Cannot update.');
    }
    final metadata = json.decode(await File(metadataPath).readAsString()) as Map<String, dynamic>;
    final sourceUrl = metadata['source_url'] as String?;
    if (sourceUrl == null) {
      throw Exception('Template $name has no source URL. Cannot update.');
    }
    await _downloadTemplateFromGit(name, sourceUrl);
  }
  Future<void> updateAllTemplates() async {
    final cacheDir = Directory(_cacheDir);
    if (!await cacheDir.exists()) return;
    await for (final entity in cacheDir.list()) {
      if (entity is Directory) {
        try {
          await updateTemplate(p.basename(entity.path));
        } catch (e) {
          _logger.warn('Failed to update ${p.basename(entity.path)}: $e');
        }
      }
    }
  }
  Future<void> createTemplateScaffold(String name, {String? description, String? outputDir}) async {
    final output = outputDir ?? p.join(Directory.current.path, name, 'template');
    await FileUtils.createDirectories(output, [
      'files',
      'hooks',
      'tests',
    ]);
    final metadata = {
      'name': name,
      'description': description ?? '$name template for NinjaDev',
      'version': '1.0.0',
      'author': '',
      'license': 'MIT',
      'tags': [name],
      'source_url': '',
      'variables': [
        {
          'name': 'project_name',
          'type': 'string',
          'description': 'The project name',
          'default': 'my_project',
        },
        {
          'name': 'org_name',
          'type': 'string',
          'description': 'Organization name',
          'default': 'com.example',
        },
      ],
    };
    await FileUtils.writeFile(
      p.join(output, 'metadata.json'),
      const JsonEncoder.withIndent('  ').convert(metadata),
    );
    // Create sample hook
    await FileUtils.writeFile(p.join(output, 'hooks', 'pre_generate.dart'), '''// Pre-generation hook
void main(List<String> args) {
  print('Running pre-generation hook for $name...');
}
''');
    _logger.success('Template scaffold created at $output');
  }
  String _getPackageRoot() {
    // This would be the package root at runtime
    return p.dirname(p.dirname(p.dirname(Platform.script.toFilePath())));
  }
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).replaceAll('_', ' ');
  }
}
