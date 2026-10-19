import 'dart:io';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:ninjadev/src/services/config_service.dart';
import 'package:ninjadev/src/utils/file_utils.dart';
import 'package:ninjadev/src/utils/ui.dart';

class FeatureGenerator {
  final ConfigService _config;
  final Logger _logger;
  FeatureGenerator(this._config, this._logger);
  Future<void> generate(String name,
      {String? feature, String? path, bool dryRun = false}) async {
    final basePath = path ??
        p.join(Directory.current.path, 'lib', 'features', _toSnakeCase(name));
    final arch = _config.get('architecture') as String? ?? 'feature-first';
    final progress = _logger.progress('Generating feature: $name...');
    switch (arch) {
      case 'clean-architecture':
        await _generateCleanArchFeature(basePath, name, dryRun);
        break;
      case 'mvc':
        await _generateMVCFeature(basePath, name, dryRun);
        break;
      case 'mvvm':
        await _generateMVVMFeature(basePath, name, dryRun);
        break;
      default:
        await _generateFeatureFirstFeature(basePath, name, dryRun);
    }
    // Each branch above prints its own specific success message, so
    // the header spinner just needs to stop, not show its own checkmark.
    progress.cancel();
  }

  Future<void> _generateFeatureFirstFeature(
      String basePath, String name, bool dryRun) async {
    final dirs = [
      'controllers',
      'views',
      'widgets',
      'models',
      'repositories',
      'services',
    ];
    for (final dir in dirs) {
      if (!dryRun) {
        await Directory(p.join(basePath, dir)).create(recursive: true);
      }
    }
    // Controller
    final controllerPath = p.join(
        basePath, 'controllers', '${_toSnakeCase(name)}_controller.dart');
    // View
    final viewPath =
        p.join(basePath, 'views', '${_toSnakeCase(name)}_screen.dart');
    // Model
    final modelPath =
        p.join(basePath, 'models', '${_toSnakeCase(name)}_model.dart');
    // Repository
    final repoPath = p.join(
        basePath, 'repositories', '${_toSnakeCase(name)}_repository.dart');
    // Service
    final svcPath =
        p.join(basePath, 'services', '${_toSnakeCase(name)}_service.dart');
    if (!dryRun) {
      await FileUtils.writeFile(controllerPath, _controllerContent(name));
      await FileUtils.writeFile(viewPath, _screenContent(name));
      await FileUtils.writeFile(modelPath, _modelContent(name));
      await FileUtils.writeFile(repoPath, _repositoryContent(name));
      await FileUtils.writeFile(svcPath, _serviceContent(name));
      _logger.success('Feature $name created at $basePath');
      NinjaUI.printTree('Generated feature: $name', [
        '$basePath/',
        '  controllers/${_toSnakeCase(name)}_controller.dart',
        '  views/${_toSnakeCase(name)}_screen.dart',
        '  models/${_toSnakeCase(name)}_model.dart',
        '  repositories/${_toSnakeCase(name)}_repository.dart',
        '  services/${_toSnakeCase(name)}_service.dart',
      ]);
    } else {
      _logger.info('Would create feature: $name');
    }
  }

  Future<void> _generateCleanArchFeature(
      String basePath, String name, bool dryRun) async {
    final dirs = [
      'data/models',
      'data/repositories',
      'data/datasources',
      'domain/entities',
      'domain/repositories',
      'domain/usecases',
      'presentation/controllers',
      'presentation/views',
      'presentation/widgets'
    ];
    for (final dir in dirs) {
      if (!dryRun)
        await Directory(p.join(basePath, dir)).create(recursive: true);
    }
    if (!dryRun) {
      await FileUtils.writeFile(
          p.join(basePath, 'presentation', 'views',
              '${_toSnakeCase(name)}_screen.dart'),
          _screenContent(name));
      await FileUtils.writeFile(
          p.join(basePath, 'presentation', 'controllers',
              '${_toSnakeCase(name)}_controller.dart'),
          _controllerContent(name));
      await FileUtils.writeFile(
          p.join(
              basePath, 'data', 'models', '${_toSnakeCase(name)}_model.dart'),
          _modelContent(name));
      _logger.success('Clean Architecture feature $name created');
      NinjaUI.printTree('Generated feature: $name', [
        '$basePath/',
        '  presentation/views/${_toSnakeCase(name)}_screen.dart',
        '  presentation/controllers/${_toSnakeCase(name)}_controller.dart',
        '  data/models/${_toSnakeCase(name)}_model.dart',
      ]);
    }
  }

  Future<void> _generateMVCFeature(
      String basePath, String name, bool dryRun) async {
    final dirs = ['controllers', 'models', 'views', 'services'];
    for (final dir in dirs) {
      if (!dryRun)
        await Directory(p.join(basePath, dir)).create(recursive: true);
    }
    if (!dryRun) {
      await FileUtils.writeFile(
          p.join(
              basePath, 'controllers', '${_toSnakeCase(name)}_controller.dart'),
          _mvcControllerContent(name));
      await FileUtils.writeFile(
          p.join(basePath, 'views', '${_toSnakeCase(name)}_screen.dart'),
          _screenContent(name));
      await FileUtils.writeFile(
          p.join(basePath, 'models', '${_toSnakeCase(name)}_model.dart'),
          _modelContent(name));
      _logger.success('MVC feature $name created');
      NinjaUI.printTree('Generated feature: $name', [
        '$basePath/',
        '  controllers/${_toSnakeCase(name)}_controller.dart',
        '  views/${_toSnakeCase(name)}_screen.dart',
        '  models/${_toSnakeCase(name)}_model.dart',
      ]);
    }
  }

  Future<void> _generateMVVMFeature(
      String basePath, String name, bool dryRun) async {
    final dirs = ['models', 'views', 'viewmodels', 'services'];
    for (final dir in dirs) {
      if (!dryRun)
        await Directory(p.join(basePath, dir)).create(recursive: true);
    }
    if (!dryRun) {
      await FileUtils.writeFile(
          p.join(
              basePath, 'viewmodels', '${_toSnakeCase(name)}_viewmodel.dart'),
          _viewModelContent(name));
      await FileUtils.writeFile(
          p.join(basePath, 'views', '${_toSnakeCase(name)}_screen.dart'),
          _screenContent(name));
      await FileUtils.writeFile(
          p.join(basePath, 'models', '${_toSnakeCase(name)}_model.dart'),
          _modelContent(name));
      _logger.success('MVVM feature $name created');
      NinjaUI.printTree('Generated feature: $name', [
        '$basePath/',
        '  viewmodels/${_toSnakeCase(name)}_viewmodel.dart',
        '  views/${_toSnakeCase(name)}_screen.dart',
        '  models/${_toSnakeCase(name)}_model.dart',
      ]);
    }
  }

  String _screenContent(String name) {
    final cn = _pascalCase(name);
    return '''import 'package:flutter/material.dart';
class ${cn}Screen extends StatefulWidget {
  const ${cn}Screen({super.key});
  @override
  State<${cn}Screen> createState() => _${cn}ScreenState();
}
class _${cn}ScreenState extends State<${cn}Screen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('$cn')),
      body: const Center(child: Text('$cn Screen')),
    );
  }
}
''';
  }

  String _controllerContent(String name) {
    final cn = _pascalCase(name);
    return '''import 'package:flutter/foundation.dart';
class ${cn}Controller extends ChangeNotifier {
  ${cn}Controller();
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;
  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      // TODO: implement load
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
''';
  }

  String _modelContent(String name) {
    final cn = _pascalCase(name);
    return '''class ${cn}Model {
  final String id;
  const ${cn}Model({required this.id});
  factory ${cn}Model.fromJson(Map<String, dynamic> json) {
    return ${cn}Model(id: json['id'] as String);
  }
  Map<String, dynamic> toJson() => {'id': id};
  ${cn}Model copyWith({String? id}) {
    return ${cn}Model(id: id ?? this.id);
  }
}
''';
  }

  String _repositoryContent(String name) {
    final cn = _pascalCase(name);
    return '''import '../models/${_toSnakeCase(name)}_model.dart';
abstract class ${cn}Repository {
  Future<List<${cn}Model>> getAll();
  Future<${cn}Model?> getById(String id);
  Future<${cn}Model> create(${cn}Model item);
  Future<${cn}Model> update(${cn}Model item);
  Future<void> delete(String id);
}
class ${cn}RepositoryImpl implements ${cn}Repository {
  @override
  Future<List<${cn}Model>> getAll() async => [];
  @override
  Future<${cn}Model?> getById(String id) async => null;
  @override
  Future<${cn}Model> create(${cn}Model item) async => item;
  @override
  Future<${cn}Model> update(${cn}Model item) async => item;
  @override
  Future<void> delete(String id) async {}
}
''';
  }

  String _serviceContent(String name) {
    final cn = _pascalCase(name);
    return '''class ${cn}Service {
  // TODO: Add service methods
}
''';
  }

  String _mvcControllerContent(String name) {
    final cn = _pascalCase(name);
    return '''class ${cn}Controller {
  // TODO: Add controller logic
}
''';
  }

  String _viewModelContent(String name) {
    final cn = _pascalCase(name);
    return '''import 'package:flutter/foundation.dart';
class ${cn}ViewModel extends ChangeNotifier {
  ${cn}ViewModel();
  Future<void> initialize() async {
    // TODO: implement
  }
}
''';
  }

  String _pascalCase(String input) {
    return input
        .split(RegExp(r'[_\s-]'))
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join();
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
            RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')
        .replaceAll(RegExp(r'^_'), '')
        .toLowerCase();
  }
}
