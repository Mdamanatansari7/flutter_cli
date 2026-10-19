import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:mason_logger/mason_logger.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';
import 'package:ninjadev/src/validators/project_validator.dart';
import 'package:ninjadev/src/generators/git_generator.dart';

class ProjectService {
  final Logger _logger;
  final bool _isVerbose;
  ProjectService(this._logger, [this._isVerbose = false]);
  void log(String msg) {
    if (_isVerbose) _logger.detail(msg);
  }

  /// Runs a plain `flutter create` so the project starts with the
  /// normal default Flutter page — nothing extra is generated.
  Future<void> createProject(CreateOptions opts) async {
    _logger.info('Creating Flutter project...\n');
    String projectName;
    if (opts.skipPrompts) {
      projectName = opts.projectName ?? 'my_app';
    } else {
      projectName = _promptProjectName(opts.projectName);
    }
    projectName =
        projectName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    final bundleId = opts.organization ?? 'com.example.$projectName';
    final platforms = opts.platforms ?? ['android', 'ios'];
    final projectPath = p.join(Directory.current.path, projectName);
    _logger.info(
        'Running flutter create for "$projectName" (${platforms.join(', ')})...');
    final result = await Process.run(
        'flutter',
        [
          'create',
          projectName,
          '--org',
          bundleId.split('.').take(2).join('.'),
          '--platforms',
          platforms.join(','),
          if (opts.description != null &&
              opts.description!.trim().isNotEmpty) ...[
            '--description',
            opts.description!.trim()
          ],
        ],
        workingDirectory: Directory.current.path);
    if (result.exitCode != 0 || !await Directory(projectPath).exists()) {
      _logger.err('Failed to create Flutter project');
      final errorOutput = result.stderr.toString().trim();
      if (errorOutput.isNotEmpty) {
        _logger.err(errorOutput.split('\n').take(5).join('\n'));
      }
      return;
    }
    _logger.success('Flutter project created with the default starter page');
    await _applyStartupDefaults(
      projectPath,
      opts.orientation ?? 'portrait',
      projectName,
      runPubGet: opts.runPubGet,
    );
    if (opts.initGit) {
      await GitGenerator(_logger).generate(projectPath);
    }
    _logger.info('Project "$projectName" created successfully!');
    _logger.info('  cd $projectName');
    _logger.info('  flutter run');
  }

  /// Wires up the startup defaults every NinjaDev project should have:
  /// a Homepage placeholder as the first screen, the chosen orientation
  /// lock wrapped in ScreenUtilInit, dotenv loading before runApp, and
  /// no debug banner — then fetches every package that was just wired
  /// in. No mode/settings page here on purpose: that's generated (and
  /// wired into main.dart) only once the user picks Local or Online
  /// under "Custom settings page".
  Future<void> _applyStartupDefaults(
    String projectPath,
    String orientation,
    String projectName, {
    bool runPubGet = true,
  }) async {
    await _writeStarterMainDart(projectPath, orientation, projectName);
    await _ensureHomepageStub(projectPath);
    await _addDotenvSupport(projectPath);
    await _addScreenUtilSupport(projectPath);
    if (runPubGet) {
      await _runFlutterPubGet(projectPath);
    }
  }

  /// Device orientations to lock to, per wizard/flag choice.
  /// 'both' lists all four explicitly rather than omitting the call,
  /// so main.dart always shows exactly what's allowed.
  List<String> _orientationValues(String orientation) {
    switch (orientation) {
      case 'landscape':
        return [
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
        ];
      case 'both':
        return [
          'DeviceOrientation.portraitUp',
          'DeviceOrientation.portraitDown',
          'DeviceOrientation.landscapeLeft',
          'DeviceOrientation.landscapeRight',
        ];
      case 'portrait':
      default:
        return [
          'DeviceOrientation.portraitUp',
          'DeviceOrientation.portraitDown',
        ];
    }
  }

  /// ScreenUtil reference size (width, height) for the orientation lock,
  /// so a landscape app isn't scaled against a portrait Figma frame.
  /// 'both' keeps the portrait default.
  String _designSize(String orientation) =>
      orientation == 'landscape' ? '1194, 835' : '835, 1194';

  /// Flips an existing `designSize: const Size(w, h)` so its shape matches
  /// [orientation] — a custom size keeps its numbers, only their order
  /// changes. 'both' and an already-matching size are left alone.
  String _syncDesignSize(String content, String orientation) {
    if (orientation == 'both') return content;
    return content.replaceFirstMapped(
      RegExp(r'designSize:\s*const\s+Size\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)'),
      (m) {
        final isWide = double.parse(m.group(1)!) > double.parse(m.group(2)!);
        if (isWide == (orientation == 'landscape')) return m.group(0)!;
        return 'designSize: const Size(${m.group(2)}, ${m.group(1)})';
      },
    );
  }

  /// Updates the orientation lock in an already-created project's
  /// main.dart. If the lock block is already there (project created by
  /// NinjaDev, or set once before), only its values are replaced. If
  /// main.dart still has the stock `flutter create` shape, the full
  /// startup patch is applied instead. Returns false when neither
  /// shape is found, so the caller can point the user at a manual fix.
  Future<bool> applyOrientation(String projectPath, String orientation) async {
    final file = File(p.join(projectPath, 'lib', 'main.dart'));
    if (!await file.exists()) return false;
    final content = await file.readAsString();

    final existingLock = RegExp(
      r'SystemChrome\.setPreferredOrientations\(\s*\[[^\]]*\]\s*\)',
    );
    if (existingLock.hasMatch(content)) {
      final orientationList =
          _orientationValues(orientation).map((v) => '    $v,').join('\n');
      final updated = content.replaceFirst(
        existingLock,
        'SystemChrome.setPreferredOrientations([\n$orientationList\n  ])',
      );
      await file.writeAsString(_syncDesignSize(updated, orientation));
      return true;
    }

    if (RegExp(r'void main\(\)\s*\{\s*runApp\(const MyApp\(\)\);\s*\}')
        .hasMatch(content)) {
      await _patchMainDart(projectPath, orientation);
      return true;
    }

    return false;
  }

  /// Minimal orientation-only retrofit for an existing, still-vanilla
  /// `flutter create` main.dart — used only by [applyOrientation]'s
  /// fallback. Unlike [_writeStarterMainDart] (create-time only), this
  /// preserves whatever MaterialApp/home the project already has.
  Future<void> _patchMainDart(String projectPath, String orientation) async {
    final file = File(p.join(projectPath, 'lib', 'main.dart'));
    if (!await file.exists()) return;
    var content = await file.readAsString();

    content = content.replaceFirst(
      "import 'package:flutter/material.dart';",
      "import 'package:flutter/material.dart';\n"
          "import 'package:flutter/services.dart';\n"
          "import 'package:flutter_dotenv/flutter_dotenv.dart';",
    );

    final orientationList =
        _orientationValues(orientation).map((v) => '    $v,').join('\n');
    content = content.replaceFirst(
      RegExp(r'void main\(\)\s*\{\s*runApp\(const MyApp\(\)\);\s*\}'),
      '''void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
$orientationList
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}''',
    );

    content = content.replaceFirst(
      'MaterialApp(',
      'MaterialApp(\n      debugShowCheckedModeBanner: false,',
    );

    content = _wrapWithScreenUtilInit(content, orientation);

    await file.writeAsString(content);
  }

  /// Wraps the `return MaterialApp(...);` statement inside `MyApp.build()`
  /// with `ScreenUtilInit`, so main.dart scales UI against a
  /// Figma-style reference design size. Finds the matching closing
  /// paren by counting depth instead of a fixed-shape regex, so it
  /// still works no matter what's inside the MaterialApp call. Leaves
  /// [content] untouched if the expected shape isn't found.
  String _wrapWithScreenUtilInit(String content, String orientation) {
    const needle = 'return MaterialApp(';
    final start = content.indexOf(needle);
    if (start == -1) return content;
    final parenStart = start + 'return MaterialApp'.length;
    var depth = 0;
    var i = parenStart;
    for (; i < content.length; i++) {
      final char = content[i];
      if (char == '(') depth++;
      if (char == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    if (depth != 0) return content;
    var end = i + 1;
    while (end < content.length && content[end] != ';') {
      end++;
    }
    if (end >= content.length) return content;
    end++; // include the ';'

    final materialAppStatement =
        content.substring(start + 'return '.length, end);
    final replacement = '''return ScreenUtilInit(
      /// Figma and other design size (width, height)
      designSize: const Size(${_designSize(orientation)}),

      /// Text screen size
      minTextAdapt: true,

      /// Split screen / tablet support
      splitScreenMode: true,

      builder: (context, child) {
        return $materialAppStatement
      },
    );''';
    return content.replaceRange(start, end, replacement);
  }

  /// Writes the full NinjaDev starter main.dart for a brand-new
  /// project: SystemChrome + dotenv startup and the app wrapped in
  /// ScreenUtilInit -> MaterialApp, with the [_ensureHomepageStub]
  /// placeholder as home. Picking a setup under "Custom settings page"
  /// later rewires it to that setup's mode page.
  Future<void> _writeStarterMainDart(
    String projectPath,
    String orientation,
    String projectName,
  ) async {
    final file = File(p.join(projectPath, 'lib', 'main.dart'));
    final orientationList =
        _orientationValues(orientation).map((v) => '    $v,').join('\n');
    final content = '''import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:$projectName/pages/Homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
$orientationList
  ]);

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      /// Figma and other design  size (width, height)
      designSize: const Size(${_designSize(orientation)}),

      /// Text screen size
      minTextAdapt: true,

      /// Split screen / tablet support
      splitScreenMode: true,

      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: const Homepage(),
        );
      },
    );
  }
}
''';
    await file.create(recursive: true);
    await file.writeAsString(content);
    await _formatMainDart(projectPath);
  }

  /// A fresh project's first screen, and where the mode page's NEXT /
  /// CONTINUE button goes once a settings page is added — a minimal
  /// placeholder so the project compiles and runs immediately; replace
  /// it with the app's real home screen.
  Future<void> _ensureHomepageStub(String projectPath) async {
    final file = File(p.join(projectPath, 'lib', 'pages', 'Homepage.dart'));
    if (await file.exists()) return;
    const content = '''import 'package:flutter/material.dart';

/// Placeholder home screen — replace with your app's real home page.
class Homepage extends StatelessWidget {
  const Homepage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Home')),
    );
  }
}
''';
    await file.create(recursive: true);
    await file.writeAsString(content);
  }

  /// Runs `dart format` on the generated main.dart so the
  /// ScreenUtilInit/MaterialApp indentation matches SDK formatting.
  /// Best-effort: a missing/failing formatter still leaves valid,
  /// correctly-structured Dart behind, just less prettily wrapped.
  Future<void> _formatMainDart(String projectPath) async {
    try {
      await Process.run(
        'dart',
        ['format', p.join(projectPath, 'lib', 'main.dart')],
        runInShell: true,
      );
    } catch (_) {}
  }

  /// Fetches every package just wired into pubspec.yaml, so the
  /// project builds immediately with no manual step.
  Future<void> _runFlutterPubGet(String projectPath) async {
    final progress = _logger.progress('Running flutter pub get...');
    try {
      final result = await Process.run(
        'flutter',
        ['pub', 'get'],
        runInShell: true,
        workingDirectory: projectPath,
      );
      if (result.exitCode == 0) {
        progress.complete('Dependencies installed');
      } else {
        progress
            .fail('flutter pub get failed: ${result.stderr.toString().trim()}');
      }
    } catch (e) {
      progress.fail('Could not run flutter pub get: $e');
    }
  }

  /// Creates a starter .env file and wires flutter_dotenv into
  /// pubspec.yaml (dependency + asset) so dotenv.load() in main.dart
  /// finds it.
  Future<void> _addDotenvSupport(String projectPath) async {
    final envFile = File(p.join(projectPath, '.env'));
    if (!await envFile.exists()) {
      await envFile.writeAsString(
          '# Environment variables\n# API_BASE_URL=https://api.example.com\n');
    }

    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) return;
    try {
      final content = await pubspecFile.readAsString();
      final editor = YamlEditor(content);
      final root = loadYaml(content);

      final deps = root is Map ? root['dependencies'] : null;
      if (deps is! Map || !deps.containsKey('flutter_dotenv')) {
        editor.update(['dependencies', 'flutter_dotenv'], 'any');
      }

      final flutterSection = root is Map ? root['flutter'] : null;
      final existingAssets = <String>[
        if (flutterSection is Map && flutterSection['assets'] is List)
          for (final a in flutterSection['assets'] as List) a.toString(),
      ];
      if (!existingAssets.contains('.env')) {
        final newAssets = [...existingAssets, '.env'];
        if (flutterSection is! Map) {
          editor.update(['flutter'], {'assets': newAssets});
        } else {
          editor.update(['flutter', 'assets'], newAssets);
        }
      }

      await pubspecFile.writeAsString(editor.toString());
    } catch (e) {
      _logger.err('Could not update pubspec.yaml for dotenv: $e');
    }
  }

  /// Wires flutter_screenutil into pubspec.yaml's dependencies so the
  /// ScreenUtilInit wrapper added to main.dart resolves.
  Future<void> _addScreenUtilSupport(String projectPath) async {
    final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) return;
    try {
      final content = await pubspecFile.readAsString();
      final editor = YamlEditor(content);
      final root = loadYaml(content);
      final deps = root is Map ? root['dependencies'] : null;
      if (deps is! Map || !deps.containsKey('flutter_screenutil')) {
        editor.update(['dependencies', 'flutter_screenutil'], 'any');
        await pubspecFile.writeAsString(editor.toString());
      }
    } catch (e) {
      _logger.err('Could not update pubspec.yaml for flutter_screenutil: $e');
    }
  }

  String _promptProjectName(String? given) {
    if (given != null && ProjectValidator.validateName(given) == null)
      return given;
    while (true) {
      _logger.info('Project name (e.g., my_app):');
      final name = stdin.readLineSync()?.trim() ?? '';
      final err = ProjectValidator.validateName(name);
      if (err == null) return name;
      _logger.err(err);
    }
  }
}

class CreateOptions {
  final String? projectName;
  final String? organization;
  final String? description;
  final bool initGit;
  final bool runPubGet;
  final String template;
  final String? orgName;
  final bool skipPrompts;
  final bool offline;
  final String? flutterVersion;
  final List<String>? platforms;
  final String? orientation;
  CreateOptions({
    this.projectName,
    this.organization,
    this.description,
    this.initGit = true,
    this.runPubGet = true,
    this.template = 'blank',
    this.orgName,
    this.skipPrompts = false,
    this.offline = false,
    this.flutterVersion,
    this.platforms,
    this.orientation,
  });
}
