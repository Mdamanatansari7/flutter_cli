import 'dart:io';
import 'package:path/path.dart' as p;

import 'package:mason_logger/mason_logger.dart';

class PackageInfo {
  final String name;
  final String? version;
  final String? description;
  final String category;
  PackageInfo({
    required this.name,
    this.version,
    this.description,
    this.category = 'general',
  });
}

class PackageService {
  final Logger _logger;
  PackageService(this._logger);
  static final Map<String, List<PackageInfo>> _packagesByCategory = {
    'Network': [
      PackageInfo(
          name: 'dio',
          version: '^5.4.0',
          description: 'HTTP client',
          category: 'network'),
      PackageInfo(
          name: 'retrofit',
          version: '^4.1.0',
          description: 'Type-safe HTTP client',
          category: 'network'),
      PackageInfo(
          name: 'graphql_flutter',
          version: '^5.1.0',
          description: 'GraphQL client',
          category: 'network'),
      PackageInfo(
          name: 'http',
          version: '^1.2.0',
          description: 'HTTP client',
          category: 'network'),
      PackageInfo(
          name: 'chopper',
          version: '^7.1.0',
          description: 'HTTP client generator',
          category: 'network'),
    ],
    'State Management': [
      PackageInfo(
          name: 'flutter_bloc',
          version: '^8.1.0',
          description: 'Bloc state management',
          category: 'state'),
      PackageInfo(
          name: 'bloc',
          version: '^8.1.0',
          description: 'Bloc core',
          category: 'state'),
      PackageInfo(
          name: 'provider',
          version: '^6.1.0',
          description: 'Provider state management',
          category: 'state'),
      PackageInfo(
          name: 'riverpod',
          version: '^2.5.0',
          description: 'Riverpod state management',
          category: 'state'),
      PackageInfo(
          name: 'flutter_riverpod',
          version: '^2.5.0',
          description: 'Riverpod for Flutter',
          category: 'state'),
      PackageInfo(
          name: 'get',
          version: '^4.6.0',
          description: 'GetX state management',
          category: 'state'),
    ],
    'Routing': [
      PackageInfo(
          name: 'go_router',
          version: '^14.0.0',
          description: 'Declarative routing',
          category: 'routing'),
      PackageInfo(
          name: 'auto_route',
          version: '^8.0.0',
          description: 'Generated routing',
          category: 'routing'),
      PackageInfo(
          name: 'fluro',
          version: '^2.0.0',
          description: 'Router',
          category: 'routing'),
      PackageInfo(
          name: 'beamer',
          version: '^1.6.0',
          description: 'Navigation',
          category: 'routing'),
    ],
    'Storage': [
      PackageInfo(
          name: 'hive',
          version: '^2.2.0',
          description: 'Local storage',
          category: 'storage'),
      PackageInfo(
          name: 'hive_flutter',
          version: '^1.1.0',
          description: 'Hive Flutter',
          category: 'storage'),
      PackageInfo(
          name: 'isar',
          version: '^3.1.0',
          description: 'Database',
          category: 'storage'),
      PackageInfo(
          name: 'sqflite',
          version: '^2.3.0',
          description: 'SQLite',
          category: 'storage'),
      PackageInfo(
          name: 'drift',
          version: '^2.15.0',
          description: 'SQLite ORM',
          category: 'storage'),
      PackageInfo(
          name: 'shared_preferences',
          version: '^2.2.0',
          description: 'Key-value storage',
          category: 'storage'),
    ],
    'Firebase': [
      PackageInfo(
          name: 'firebase_core',
          version: '^2.27.0',
          description: 'Firebase core',
          category: 'firebase'),
      PackageInfo(
          name: 'firebase_auth',
          version: '^4.18.0',
          description: 'Firebase auth',
          category: 'firebase'),
      PackageInfo(
          name: 'cloud_firestore',
          version: '^4.15.0',
          description: 'Firestore DB',
          category: 'firebase'),
      PackageInfo(
          name: 'firebase_storage',
          version: '^11.6.0',
          description: 'Firebase storage',
          category: 'firebase'),
      PackageInfo(
          name: 'firebase_messaging',
          version: '^14.7.0',
          description: 'Push notifications',
          category: 'firebase'),
      PackageInfo(
          name: 'firebase_crashlytics',
          version: '^3.4.0',
          description: 'Crash reporting',
          category: 'firebase'),
      PackageInfo(
          name: 'firebase_analytics',
          version: '^10.8.0',
          description: 'Analytics',
          category: 'firebase'),
    ],
    'UI': [
      PackageInfo(
          name: 'flutter_svg',
          version: '^2.0.0',
          description: 'SVG rendering',
          category: 'ui'),
      PackageInfo(
          name: 'cached_network_image',
          version: '^3.3.0',
          description: 'Image caching',
          category: 'ui'),
      PackageInfo(
          name: 'shimmer',
          version: '^3.0.0',
          description: 'Loading shimmer',
          category: 'ui'),
      PackageInfo(
          name: 'lottie',
          version: '^3.0.0',
          description: 'Animations',
          category: 'ui'),
      PackageInfo(
          name: 'google_fonts',
          version: '^6.2.0',
          description: 'Google fonts',
          category: 'ui'),
      PackageInfo(
          name: 'flutter_animate',
          version: '^4.5.0',
          description: 'Animations',
          category: 'ui'),
    ],
    'Utilities': [
      PackageInfo(
          name: 'permission_handler',
          version: '^11.3.0',
          description: 'Permissions',
          category: 'utils'),
      PackageInfo(
          name: 'url_launcher',
          version: '^6.2.0',
          description: 'URL launcher',
          category: 'utils'),
      PackageInfo(
          name: 'connectivity_plus',
          version: '^6.0.0',
          description: 'Connectivity',
          category: 'utils'),
      PackageInfo(
          name: 'device_info_plus',
          version: '^10.0.0',
          description: 'Device info',
          category: 'utils'),
      PackageInfo(
          name: 'package_info_plus',
          version: '^8.0.0',
          description: 'Package info',
          category: 'utils'),
      PackageInfo(
          name: 'path_provider',
          version: '^2.1.0',
          description: 'File paths',
          category: 'utils'),
      PackageInfo(
          name: 'image_picker',
          version: '^1.0.0',
          description: 'Image picker',
          category: 'utils'),
    ],
    'Testing': [
      PackageInfo(
          name: 'mocktail',
          version: '^1.0.0',
          description: 'Mocking',
          category: 'testing'),
      PackageInfo(
          name: 'bloc_test',
          version: '^9.1.0',
          description: 'Bloc testing',
          category: 'testing'),
      PackageInfo(
          name: 'golden_toolkit',
          version: '^0.15.0',
          description: 'Golden tests',
          category: 'testing'),
      PackageInfo(
          name: 'integration_test',
          description: 'Integration tests',
          category: 'testing'),
    ],
  };
  Future<void> interactiveAdd({bool dev = false}) async {
    _logger.info('\nInteractive Package Installer\n');
    final categories = _packagesByCategory.keys.toList();
    _logger.info('Select a category:');
    for (int i = 0; i < categories.length; i++) {
      _logger.info('  ${i + 1}. ${categories[i]}');
    }
    _logger.info('  ${categories.length + 1}. Done');
    _logger.info('');
    while (true) {
      _logger.info('Enter category number (or Done):');
      final input = stdin.readLineSync()?.trim() ?? '';
      if (input == (categories.length + 1).toString() ||
          input.toLowerCase() == 'done') {
        break;
      }
      final index = int.tryParse(input);
      if (index == null || index < 1 || index > categories.length) {
        _logger.err('Invalid selection');
        continue;
      }
      final category = categories[index - 1];
      final packages = _packagesByCategory[category]!;
      _logger.info('\n$category packages:');
      for (int i = 0; i < packages.length; i++) {
        _logger.info(
            '  ${i + 1}. ${packages[i].name} ${packages[i].version ?? ''} - ${packages[i].description}');
      }
      _logger.info('  ${packages.length + 1}. Back');
      _logger.info('');
      _logger.info('Select package to install (or Back):');
      final pkgInput = stdin.readLineSync()?.trim() ?? '';
      if (pkgInput == (packages.length + 1).toString() ||
          pkgInput.toLowerCase() == 'back') {
        continue;
      }
      final pkgIndex = int.tryParse(pkgInput);
      if (pkgIndex == null || pkgIndex < 1 || pkgIndex > packages.length) {
        _logger.err('Invalid selection');
        continue;
      }
      final pkg = packages[pkgIndex - 1];
      await addPackage(pkg.name, version: pkg.version, dev: dev);
    }
  }

  Future<void> addPackage(String packageName,
      {String? version, bool dev = false}) async {
    final pubspecPath = p.join(Directory.current.path, 'pubspec.yaml');
    if (!await File(pubspecPath).exists()) {
      _logger.err('pubspec.yaml not found in current directory');
      return;
    }
    final progress = _logger.progress('Adding $packageName...');
    try {
      final args = [
        'pub',
        'add',
        version != null ? '$packageName:$version' : packageName,
      ];
      if (dev) {
        args.add('--dev');
      }
      // Uses the Flutter-bundled Dart SDK, not whatever standalone `dart`
      // is on PATH — those can be different versions, and a mismatch
      // makes `dart pub add` fail version-solving on Flutter projects.
      final result = await Process.run('flutter', args, runInShell: true);
      if (result.exitCode == 0) {
        progress.complete('Added $packageName');
      } else {
        progress.fail('Failed to add $packageName: ${result.stderr}');
      }
    } catch (e) {
      progress.fail('Failed to add package: $e');
    }
  }

  Future<void> ensurePackage(String packageName,
      {String? version, bool dev = false}) async {
    final pubspecPath = p.join(Directory.current.path, 'pubspec.yaml');
    final pubspecFile = File(pubspecPath);
    if (!await pubspecFile.exists()) {
      _logger.err('pubspec.yaml not found in current directory');
      return;
    }

    final content = await pubspecFile.readAsString();
    final dependencySection = dev ? 'dev_dependencies:' : 'dependencies:';
    final sectionStart = content.indexOf(dependencySection);
    final sectionBodyStart =
        sectionStart == -1 ? -1 : sectionStart + dependencySection.length;
    final nextSectionMatch = sectionBodyStart == -1
        ? null
        : RegExp(r'\n(?=\S)').firstMatch(content.substring(sectionBodyStart));
    final nextSection = nextSectionMatch == null
        ? -1
        : sectionBodyStart + nextSectionMatch.start;
    final section = sectionStart == -1
        ? ''
        : content.substring(
            sectionStart, nextSection == -1 ? content.length : nextSection);
    if (RegExp(r'^\s{2}' + RegExp.escape(packageName) + r':', multiLine: true)
        .hasMatch(section)) {
      return;
    }

    await addPackage(packageName, version: version, dev: dev);
  }

  Future<void> removePackage(String packageName, {bool dev = false}) async {
    final progress = _logger.progress('Removing $packageName...');
    try {
      final args = ['pub', 'remove', packageName];
      final result = await Process.run('flutter', args, runInShell: true);
      if (result.exitCode == 0) {
        progress.complete('Removed $packageName');
      } else {
        progress.fail('Failed to remove $packageName: ${result.stderr}');
      }
    } catch (e) {
      progress.fail('Failed to remove package: $e');
    }
  }

  Future<void> installMultiple(List<String> packages,
      {bool dev = false}) async {
    for (final pkg in packages) {
      await addPackage(pkg, dev: dev);
    }
  }

  static List<PackageInfo> getPackagesByCategory(String category) {
    return _packagesByCategory[category] ?? [];
  }

  static List<PackageInfo> getAllPackages() {
    return _packagesByCategory.values.expand((p) => p).toList();
  }
}
