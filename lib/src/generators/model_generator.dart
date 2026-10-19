import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:mason_logger/mason_logger.dart';

class ModelGenerator {
  final Logger _logger;
  ModelGenerator(this._logger);
  Future<void> generate(String name,
      {String? feature, String? path, bool dryRun = false}) async {
    final cn = _pascalCase(name);
    final fn = _toFileName(name);
    var outputDir = path;
    if (outputDir == null) {
      if (feature != null) {
        outputDir = p.join(Directory.current.path, 'lib', 'features',
            _toSnakeCase(feature), 'models');
      } else {
        outputDir = p.join(Directory.current.path, 'lib', 'models');
      }
    }
    final outputPath = p.join(outputDir, '${fn}_model.dart');
    if (dryRun) {
      _logger.info('Would create model: $outputPath');
      _logger.detail(_modelContent(cn));
      return;
    }
    _logger.info('');
    _logger.info('Define fields (enter empty line to finish):');
    _logger.info('Format: fieldName:Type (e.g., name:String, age:int)');
    final fields = <String, String>{};
    while (true) {
      _logger.info('Field:');
      final input = stdin.readLineSync()?.trim() ?? '';
      if (input.isEmpty) break;
      final parts = input.split(':');
      if (parts.length == 2) {
        fields[parts[0].trim()] = parts[1].trim();
      } else {
        _logger.err('Invalid format. Use fieldName:Type');
      }
    }
    if (fields.isEmpty) {
      fields['id'] = 'String';
    }
    final progress = _logger.progress('Generating model $name...');
    await File(outputPath).create(recursive: true);
    await File(outputPath).writeAsString(_modelContent(cn, fields));
    progress.complete('Model created: $outputPath');
  }

  String _modelContent(String cn, [Map<String, String>? fields]) {
    fields ??= {'id': 'String'};
    final constructorParams =
        fields.entries.map((e) => 'required this.${e.key}').join(',\n    ');
    final jsonFields =
        fields.entries.map((e) => "'${e.key}': ${e.key}").join(',\n      ');
    final fromJsonFields = fields.entries.map((e) {
      if (e.value == 'int') return "${e.key}: json['${e.key}'] as int";
      if (e.value == 'double')
        return "${e.key}: (json['${e.key}'] as num).toDouble()";
      if (e.value == 'bool') return "${e.key}: json['${e.key}'] as bool";
      if (e.value == 'List<String>')
        return "${e.key}: (json['${e.key}'] as List?)?.cast<String>() ?? []";
      if (e.value.startsWith('List<'))
        return "${e.key}: (json['${e.key}'] as List?)?.map((e) => ${e.value.substring(5, e.value.length - 1)}.fromJson(e)).toList() ?? []";
      return "${e.key}: json['${e.key}'] as ${e.value}";
    }).join(',\n      ');
    final copyWithFields = fields.entries
        .map((e) =>
            '${e.value.endsWith('?') ? e.value : '${e.value}?'} ${e.key}')
        .join(',\n    ');
    // Each field reads `name: <value>` in the generated toString().
    final dollar = String.fromCharCode(36);
    final toStringFields = fields.keys.map((k) => '$k: $dollar$k').join(', ');
    final copyWithAssign = fields.entries
        .map((e) => '${e.key}: ${e.key} ?? this.${e.key}')
        .join(',\n      ');
    return '''class ${cn}Model {
  final ${fields.entries.map((e) => '${e.value} ${e.key}').join(';\n  final ')};
  const ${cn}Model({
    $constructorParams,
  });
  factory ${cn}Model.fromJson(Map<String, dynamic> json) {
    return ${cn}Model(
      $fromJsonFields,
    );
  }
  Map<String, dynamic> toJson() => {
      $jsonFields,
    };
  ${cn}Model copyWith({
    $copyWithFields,
  }) {
    return ${cn}Model(
      $copyWithAssign,
    );
  }
  @override
  String toString() => '${cn}Model($toStringFields)';
}
''';
  }

  String _pascalCase(String input) {
    return input
        .split(RegExp(r'[_\s-]'))
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join();
  }

  String _toFileName(String input) {
    return _toSnakeCase(input);
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
            RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')
        .replaceAll(RegExp(r'^_'), '')
        .toLowerCase();
  }
}
