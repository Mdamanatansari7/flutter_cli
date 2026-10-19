import 'dart:io';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class ConfigService {
  late Map<String, dynamic> _config;
  String? _configPath;
  bool _loaded = false;
  final Logger _logger;
  ConfigService({Logger? logger}) : _logger = logger ?? Logger();
  String? get configPath => _configPath;
  Map<String, dynamic> get all => Map.unmodifiable(_config);
  bool get isLoaded => _loaded;
  String get defaultTemplate => _config['template'] as String? ?? 'clean-architecture';
  Future<void> load({String? path}) async {
    if (path != null) {
      _configPath = path;
    } else {
      _configPath = _findConfigFile();
    }
    if (_configPath != null && await File(_configPath!).exists()) {
      try {
        final content = await File(_configPath!).readAsString();
        final yaml = loadYaml(content);
        _config = _yamlToMap(yaml);
        _loaded = true;
      } catch (e) {
        _logger.warn('Failed to parse config file: $e');
        _config = _defaultConfig();
      }
    } else {
      _config = _defaultConfig();
    }
  }
  String? _findConfigFile() {
    final possiblePaths = [
      p.join(Directory.current.path, 'ninjadev.yaml'),
      p.join(Directory.current.path, '.ninjadev.yaml'),
      p.join(_getHomeDir(), '.ninjadev.yaml'),
      p.join(_getHomeDir(), '.config', 'ninjadev', 'config.yaml'),
      p.join(_getXdgConfigHome(), 'ninjadev', 'config.yaml'),
    ];
    for (final path in possiblePaths) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }
  String _getHomeDir() {
    return Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/tmp';
  }
  String _getXdgConfigHome() {
    return Platform.environment['XDG_CONFIG_HOME'] ?? p.join(_getHomeDir(), '.config');
  }
  Future<String> getDefaultConfigPath() async {
    final configDir = p.join(_getXdgConfigHome(), 'ninjadev');
    await Directory(configDir).create(recursive: true);
    return p.join(configDir, 'config.yaml');
  }
  Map<String, dynamic> _defaultConfig() {
    return {
      'project': {
        'name': null,
        'organization': 'com.example',
        'description': null,
        'version': '1.0.0',
      },
      'template': 'clean-architecture',
      'state_management': 'bloc',
      'routing': 'go_router',
      'dependency_injection': 'get_it',
      'localization': 'flutter_localizations',
      'linting': 'very_good_analysis',
      'testing': ['flutter_test', 'mocktail', 'bloc_test'],
      'platforms': ['ios', 'android', 'web'],
      'features': [],
      'templates': {
        'custom': [],
        'remote_enabled': true,
        'server_url': 'https://templates.ninjadev.dev',
      },
      'generators': {
        'auto_import': true,
        'export_barrel': true,
        'use_templates': true,
      },
      'analytics': {
        'enabled': false,
        'provider': null,
      },
      'crash_reporting': {
        'enabled': false,
        'provider': null,
      },
      'ci': {
        'platforms': [],
      },
    };
  }
  Map<String, dynamic> _yamlToMap(dynamic yaml) {
    if (yaml is YamlMap) {
      final map = <String, dynamic>{};
      for (final entry in yaml.entries) {
        if (entry.value is YamlMap) {
          map[entry.key.toString()] = _yamlToMap(entry.value);
        } else if (entry.value is YamlList) {
          map[entry.key.toString()] = (entry.value as YamlList).toList();
        } else {
          map[entry.key.toString()] = entry.value;
        }
      }
      return map;
    }
    return _defaultConfig();
  }
  dynamic get(String key) {
    final parts = key.split('.');
    var current = _config;
    for (final part in parts) {
      if (current[part] is Map) {
        current = current[part] as Map<String, dynamic>;
      } else {
        return current[part];
      }
    }
    return current;
  }
  Future<void> set(String key, dynamic value, {bool global = false}) async {
    final parts = key.split('.');
    var current = _config;
    for (int i = 0; i < parts.length - 1; i++) {
      current[parts[i]] ??= <String, dynamic>{};
      current = current[parts[i]] as Map<String, dynamic>;
    }
    current[parts.last] = value;
    await _save(global ? await getDefaultConfigPath() : _configPath);
  }
  Future<bool> exists() async {
    return _configPath != null && await File(_configPath!).exists();
  }
  Future<void> initDefaults() async {
    _config = _defaultConfig();
    final path = await getDefaultConfigPath();
    await _save(path);
    _configPath = path;
    _loaded = true;
  }
  Future<void> create(Map<String, dynamic> options, {bool force = false}) async {
    final path = _configPath ?? await getDefaultConfigPath();
    if (await File(path).exists() && !force) {
      throw Exception('Config already exists at $path');
    }
    _config = Map<String, dynamic>.from(options);
    await _save(path);
    _configPath = path;
    _loaded = true;
  }
  Future<void> reset() async {
    _config = _defaultConfig();
    if (_configPath != null) {
      await _save(_configPath!);
    }
  }
  Future<void> reload() async {
    if (_configPath != null) {
      await load(path: _configPath);
    }
  }
  Future<void> _save(String? path) async {
    final savePath = path ?? await getDefaultConfigPath();
    final file = File(savePath);
    await file.create(recursive: true);
    await file.writeAsString(_toYamlString(_config));
  }
  String _toYamlString(Map<String, dynamic> config) {
    final buffer = StringBuffer();
    _writeYaml(config, buffer, 0);
    return buffer.toString();
  }
  void _writeYaml(Map<String, dynamic> map, StringBuffer buffer, int indent) {
    for (final entry in map.entries) {
      if (entry.value is Map) {
        buffer.writeln('${'  ' * indent}${entry.key}:');
        _writeYaml(entry.value as Map<String, dynamic>, buffer, indent + 1);
      } else if (entry.value is List) {
        buffer.writeln('${'  ' * indent}${entry.key}:');
        for (final item in entry.value as List) {
          buffer.writeln('${'  ' * (indent + 1)}- $item');
        }
      } else if (entry.value == null) {
        buffer.writeln('${'  ' * indent}${entry.key}:');
      } else {
        buffer.writeln('${'  ' * indent}${entry.key}: ${entry.value}');
      }
    }
  }
}
