import 'dart:io';
import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';
import 'package:ninjadev/src/commands/create_command.dart';
import 'package:ninjadev/src/commands/generate_command.dart';
import 'package:ninjadev/src/commands/config_command.dart';
import 'package:ninjadev/src/commands/template_command.dart';
import 'package:ninjadev/src/commands/doctor_command.dart';
import 'package:ninjadev/src/commands/completion_command.dart';
import 'package:ninjadev/src/commands/upgrade_command.dart';
import 'package:ninjadev/src/commands/init_command.dart';
import 'package:ninjadev/src/commands/add_command.dart';
import 'package:ninjadev/src/commands/remove_command.dart';
import 'package:ninjadev/src/commands/list_command.dart';
import 'package:ninjadev/src/commands/deploy_command.dart';
import 'package:ninjadev/src/generators/http_function_generator.dart';
import 'package:ninjadev/src/generators/websocket_generator.dart';
import 'package:ninjadev/src/services/config_service.dart';
import 'package:ninjadev/src/services/generate_service.dart';
import 'package:ninjadev/src/services/git_service.dart';
import 'package:ninjadev/src/services/project_service.dart';
import 'package:ninjadev/src/utils/ui.dart';

/// Native permissions a pub package needs, so a dropped-in snippet can
/// wire them up automatically instead of the app crashing at runtime
/// (iOS) or a silent permission denial (Android).
class _PackagePermissions {
  const _PackagePermissions({this.ios = const {}, this.android = const []});
  final Map<String, String> ios;
  final List<String> android;
}

const Map<String, _PackagePermissions> _packagePermissions = {
  'mobile_scanner': _PackagePermissions(
    ios: {
      'NSCameraUsageDescription':
          'This app uses the camera to scan QR codes and barcodes.',
    },
    android: ['android.permission.CAMERA'],
  ),
  'camera': _PackagePermissions(
    ios: {'NSCameraUsageDescription': 'This app uses the camera.'},
    android: ['android.permission.CAMERA'],
  ),
  'image_picker': _PackagePermissions(
    ios: {
      'NSCameraUsageDescription': 'This app uses the camera to take photos.',
      'NSPhotoLibraryUsageDescription':
          'This app accesses your photos so you can pick images.',
    },
    android: ['android.permission.CAMERA'],
  ),
  'geolocator': _PackagePermissions(
    ios: {
      'NSLocationWhenInUseUsageDescription': 'This app uses your location.',
    },
    android: [
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
    ],
  ),
  'location': _PackagePermissions(
    ios: {
      'NSLocationWhenInUseUsageDescription': 'This app uses your location.',
    },
    android: [
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.ACCESS_COARSE_LOCATION',
    ],
  ),
  'record': _PackagePermissions(
    ios: {
      'NSMicrophoneUsageDescription':
          'This app uses the microphone to record audio.',
    },
    android: ['android.permission.RECORD_AUDIO'],
  ),
  'speech_to_text': _PackagePermissions(
    ios: {
      'NSMicrophoneUsageDescription':
          'This app uses the microphone for speech recognition.',
      'NSSpeechRecognitionUsageDescription':
          'This app uses speech recognition.',
    },
    android: ['android.permission.RECORD_AUDIO'],
  ),
  'local_auth': _PackagePermissions(
    ios: {
      'NSFaceIDUsageDescription': 'This app uses Face ID to authenticate you.',
    },
  ),
  'flutter_contacts': _PackagePermissions(
    ios: {'NSContactsUsageDescription': 'This app accesses your contacts.'},
    android: ['android.permission.READ_CONTACTS'],
  ),
};

class NinjaDevCLI {
  late final ArgParser _parser;
  late final Logger _logger;

  NinjaDevCLI() {
    _logger = Logger();
    _parser = _createParser();
  }

  ArgParser _createParser() {
    final parser = ArgParser(allowTrailingOptions: true);

    parser.addCommand('create', CreateCommand().parser);
    parser.addCommand('generate', GenerateCommand().parser);
    parser.addCommand('gen', GenerateCommand().parser);
    parser.addCommand('config', ConfigCommand().parser);
    parser.addCommand('template', TemplateCommand().parser);
    parser.addCommand('doctor', DoctorCommand().parser);
    parser.addCommand('completion', CompletionCommand().parser);
    parser.addCommand('upgrade', UpgradeCommand().parser);
    parser.addCommand('init', InitCommand().parser);
    parser.addCommand('add', AddCommand().parser);
    parser.addCommand('remove', RemoveCommand().parser);
    parser.addCommand('rm', RemoveCommand().parser);
    parser.addCommand('list', ListCommand().parser);
    parser.addCommand('ls', ListCommand().parser);
    parser.addCommand('deploy', DeployCommand().parser);

    parser.addFlag('version', negatable: false, help: 'Print the version');
    parser.addFlag('verbose',
        negatable: false, abbr: 'v', help: 'Verbose output');
    parser.addFlag('help', negatable: false, abbr: 'h', help: 'Show help');

    return parser;
  }

  void run(List<String> arguments) {
    _runAsync(arguments);
  }

  Future<void> _runAsync(List<String> arguments) async {
    try {
      if (arguments.isEmpty) {
        if (stdin.hasTerminal && stdout.hasTerminal) {
          await _runInteractiveMenu();
        } else {
          _printUsage();
        }
        return;
      }

      if (arguments.contains('--help') || arguments.contains('-h')) {
        _printUsage();
        return;
      }

      if (arguments.contains('--version')) {
        _printVersion();
        return;
      }

      final results = _parser.parse(arguments);
      if (results.command == null) {
        _printUsage();
        return;
      }

      final commandName = results.command!.name;
      final commandArgs = results.command!.arguments;

      await _dispatch(commandName, commandArgs);
    } on FormatException catch (e) {
      _logger.err(e.message);
      _printUsage();
    } catch (e, stackTrace) {
      _logger.err('Error: $e');
      _logger.detail(stackTrace.toString());
    }
  }

  Future<void> _dispatch(String? commandName, List<String> commandArgs) async {
    final configService = ConfigService();
    await configService.load();

    switch (commandName) {
      case 'create':
        await CreateCommand().run(commandArgs, configService, _logger);
        break;
      case 'generate':
      case 'gen':
        await GenerateCommand().run(commandArgs, configService, _logger);
        break;
      case 'config':
        await ConfigCommand().run(commandArgs, configService, _logger);
        break;
      case 'template':
        await TemplateCommand().run(commandArgs, configService, _logger);
        break;
      case 'doctor':
        await DoctorCommand().run(commandArgs, configService, _logger);
        break;
      case 'completion':
        await CompletionCommand().run(commandArgs, configService, _logger);
        break;
      case 'upgrade':
        await UpgradeCommand().run(commandArgs, configService, _logger);
        break;
      case 'init':
        await InitCommand().run(commandArgs, configService, _logger);
        break;
      case 'add':
        await AddCommand().run(commandArgs, configService, _logger);
        break;
      case 'remove':
      case 'rm':
        await RemoveCommand().run(commandArgs, configService, _logger);
        break;
      case 'list':
      case 'ls':
        await ListCommand().run(commandArgs, configService, _logger);
        break;
      case 'deploy':
        await DeployCommand().run(commandArgs, configService, _logger);
        break;
      default:
        _logger.err('Unknown command: $commandName');
        _printUsage();
    }
  }

  Future<void> _runInteractiveMenu() async {
    NinjaUI.guardTerminal();
    NinjaUI.printBanner();
    while (true) {
      stdout.writeln();
      final choice = NinjaUI.mainMenu();
      if (choice == 'exit') {
        NinjaUI.goodbye();
        return;
      }
      if (choice == 'help') {
        _printUsage();
        continue;
      }
      if (choice == 'create') {
        await _runCreateWizard();
        continue;
      }
      if (choice == 'existing') {
        await _runExistingProjectMenu();
        continue;
      }
      await _dispatch(choice, const <String>[]);
    }
  }

  Future<void> _runCreateWizard() async {
    NinjaUI.stepHeader(1, 6, 'Checking your environment');
    final flutterOk = await _checkTool('Flutter', 'flutter');
    final dartOk = await _checkTool('Dart', 'dart');
    final gitOk = await _checkTool('Git', 'git');
    if (!flutterOk || !dartOk) {
      NinjaUI.wizardAbort(
          'Install the missing tools first, then try again. Run Doctor for details.');
      return;
    }

    NinjaUI.stepHeader(2, 6, 'Project details');
    final name = NinjaUI.askProjectName();
    final org = NinjaUI.askOrganization();

    NinjaUI.stepHeader(3, 6, 'Project description');
    final description = NinjaUI.askDescription();

    NinjaUI.stepHeader(4, 6, 'Target platforms');
    final platforms = NinjaUI.askPlatforms();

    NinjaUI.stepHeader(5, 6, 'Device orientation');
    final orientation = NinjaUI.askOrientation();

    NinjaUI.stepHeader(6, 6, 'Generating project');
    NinjaUI.createSummary(name, org, description, platforms, orientation);
    await _dispatch('create', [
      name,
      '--org',
      org,
      '--platform',
      platforms.join(','),
      if (description.isNotEmpty) ...['--description', description],
      '--orientation',
      orientation,
      '--yes',
      if (!gitOk) '--no-git',
    ]);
  }

  Future<bool> _checkTool(String label, String executable) async {
    try {
      final result =
          await Process.run(executable, ['--version'], runInShell: true);
      if (result.exitCode == 0) {
        var detail = result.stdout.toString().trim();
        if (detail.isEmpty) detail = result.stderr.toString().trim();
        NinjaUI.checkOk(label, detail.split('\n').first.trim());
        return true;
      }
    } catch (_) {}
    NinjaUI.checkFail(label, '$executable not found in PATH');
    return false;
  }

  Future<void> _runExistingProjectMenu() async {
    final originalDir = Directory.current;
    try {
      if (!_ensureProjectDirectory()) return;
      await _existingProjectLoop();
    } finally {
      Directory.current = originalDir;
    }
  }

  /// Makes sure we are inside a Flutter project. If the current folder
  /// is not one, it looks for projects in the subfolders: a single match
  /// is selected automatically, multiple matches show a picker.
  bool _ensureProjectDirectory() {
    if (File('pubspec.yaml').existsSync()) return true;
    final projects = _findFlutterProjects();
    if (projects.isEmpty) {
      NinjaUI.notInProject(Directory.current.path);
      return false;
    }
    String chosen;
    if (projects.length == 1) {
      chosen = projects.first;
      NinjaUI.autoSelectedProject(chosen);
    } else {
      final picked =
          NinjaUI.pickFolder('Which project do you want to work in?', projects);
      if (picked == null) return false;
      chosen = picked;
    }
    Directory.current = chosen;
    return true;
  }

  List<String> _findFlutterProjects() {
    final projects = <String>[];
    try {
      for (final entity in Directory.current.listSync()) {
        if (entity is! Directory) continue;
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith('.')) continue;
        final pubspec =
            File('${entity.path}${Platform.pathSeparator}pubspec.yaml');
        if (pubspec.existsSync()) projects.add(name);
      }
    } catch (_) {}
    projects.sort();
    return projects;
  }

  Future<void> _existingProjectLoop() async {
    while (true) {
      if (!File('pubspec.yaml').existsSync()) {
        NinjaUI.notInProject(Directory.current.path);
        return;
      }
      final folderName =
          Directory.current.path.split(Platform.pathSeparator).last;
      final choice = NinjaUI.existingProjectMenu(folderName);
      if (choice == 'home') return;
      if (choice == 'assets') {
        final picked = NinjaUI.assetFoldersMenu();
        if (picked == null) continue;
        if (picked.isEmpty) {
          _logger.warn('Nothing selected');
          continue;
        }
        for (final folder in picked) {
          _createFolder('assets/$folder');
        }
        final assetPaths = [
          for (final f in picked)
            if (f != 'fonts') 'assets/$f/',
        ];
        if (assetPaths.isNotEmpty) _registerAssetsInPubspec(assetPaths);
        if (picked.contains('fonts')) _setupProjectFonts();
        continue;
      }
      if (choice == 'libfolders') {
        final picked = NinjaUI.libFoldersMenu();
        if (picked == null) continue;
        if (picked.isEmpty) {
          _logger.warn('Nothing selected');
          continue;
        }
        for (final folder in picked) {
          _createFolder('lib/$folder');
        }
        continue;
      }
      if (choice == 'api') {
        final serviceType = NinjaUI.serviceTypeMenu();
        if (serviceType == null) continue;
        if (serviceType == 'http') {
          _runHttpApiFunctionWizard();
          continue;
        }
        if (serviceType == 'ws') {
          _runWebSocketWizard();
          continue;
        }
        // serviceType == 'stub' — the original stub-file generator,
        // unchanged.
        final folders = _libSubfolders();
        if (folders.isEmpty) {
          _logger
              .warn('No folders inside lib/ yet — create lib folders first.');
          continue;
        }
        final target =
            NinjaUI.pickFolder('Where should the service files go?', folders);
        if (target == null) continue;
        final names = NinjaUI.serviceFilesMenu(target);
        if (names == null) continue;
        if (names.isEmpty) {
          _logger.warn('Nothing selected');
          continue;
        }
        for (final name in names) {
          _createServiceFile(target, name);
        }
        continue;
      }
      if (choice == 'snippets') {
        final folders = _libSubfolders();
        if (folders.isEmpty) {
          _logger
              .warn('No folders inside lib/ yet — create lib folders first.');
          continue;
        }
        final target =
            NinjaUI.pickFolder('Where should these pages go?', folders);
        if (target == null) continue;
        final available = _availableSnippets();
        if (available.isEmpty) {
          _logger.warn('No snippets found in ${_snippetsDir().path}');
          _logger.info(
              'Paste your ready-made .dart files there once — they will show up here automatically, no restart needed.');
          continue;
        }
        final names = NinjaUI.snippetFilesMenu(target, available);
        if (names == null) continue;
        if (names.isEmpty) {
          _logger.warn('Nothing selected');
          continue;
        }
        for (final name in names) {
          _copySnippet(target, name);
        }
        _wireSnippetDependencies(target, names);
        continue;
      }
      if (choice == 'settings') {
        final settingsOrientation = NinjaUI.askSettingsOrientation();
        final settingsSetup = NinjaUI.askSettingsSetup();
        final folders = _libSubfolders();
        if (folders.isEmpty) {
          _logger
              .warn('No folders inside lib/ yet — create lib folders first.');
          continue;
        }
        final target =
            NinjaUI.pickFolder('Where should the settings pages go?', folders);
        if (target == null) continue;
        final configService = ConfigService();
        await configService.load();
        _logger.info('Generating custom settings pages...');
        await GenerateService(configService, _logger).generate(
          GenerateOptions(
            type: 'settings',
            path: target,
            orientation: settingsOrientation,
            setup: settingsSetup,
          ),
        );
        continue;
      }
      if (choice == 'orientation') {
        final orientation = NinjaUI.askOrientation();
        final applied = await ProjectService(_logger)
            .applyOrientation(Directory.current.path, orientation);
        if (applied) {
          _logger.success('Orientation set to $orientation in lib/main.dart');
        } else {
          _logger.warn(
              'Could not find a recognizable main() in lib/main.dart — add the orientation lock manually.');
        }
        continue;
      }
      if (choice == 'gitpush') {
        await _runGitPushWizard();
        continue;
      }
      if (choice == 'githubaccount') {
        await _runGithubAccountMenu();
        continue;
      }
      if (choice == 'env') {
        _createEnvFile();
        continue;
      }
    }
  }

  void _createFolder(String relativePath) {
    final dir = Directory(relativePath);
    if (dir.existsSync()) {
      _logger.warn('Already exists: $relativePath/');
      return;
    }
    dir.createSync(recursive: true);
    _logger.success('Created $relativePath/');
  }

  /// Registers the given asset paths under `flutter: assets:` in
  /// pubspec.yaml so the app can load them.
  ///
  /// Rebuilds the whole list in memory and writes it with a single
  /// `editor.update()` call — `appendToList` corrupts the YAML here
  /// once `assets:` isn't the last key in the `flutter:` map (e.g. when
  /// `uses-material-design` or `fonts:` comes after it, which is the
  /// normal case for every `flutter create`d pubspec).
  void _registerAssetsInPubspec(List<String> assetPaths) {
    final file = File('pubspec.yaml');
    if (!file.existsSync()) {
      _logger.warn('pubspec.yaml not found — assets not registered');
      return;
    }
    try {
      final content = file.readAsStringSync();
      final editor = YamlEditor(content);
      final root = loadYaml(content);
      final flutterSection = root is Map ? root['flutter'] : null;
      final existing = <String>[
        if (flutterSection is Map && flutterSection['assets'] is List)
          for (final entry in flutterSection['assets'] as List)
            entry.toString(),
      ];
      final newPaths = [
        for (final path in assetPaths)
          if (!existing.contains(path)) path,
      ];
      if (newPaths.isEmpty) {
        _logger.info('Assets already registered in pubspec.yaml');
        return;
      }
      final mergedPaths = [...existing, ...newPaths];
      if (flutterSection is! Map) {
        editor.update(['flutter'], {'assets': mergedPaths});
      } else {
        editor.update(['flutter', 'assets'], mergedPaths);
      }
      file.writeAsStringSync(editor.toString());
      for (final path in newPaths) {
        _logger.success('Registered $path in pubspec.yaml');
      }
    } catch (e) {
      _logger.err('Could not update pubspec.yaml: $e');
    }
  }

  /// Registers the Poppins font family (with weights) under
  /// `flutter: fonts:` in pubspec.yaml — the proper way to use fonts.
  /// Copies every .ttf from ~/.ninjadev/fonts/ into the project's
  /// assets/fonts/ and registers the families in pubspec.yaml.
  /// Naya font chahiye? Bas .ttf file us folder me paste karo —
  /// koi rebuild nahi chahiye, agli baar se copy hoga.
  void _setupProjectFonts() {
    final home = Platform.environment['HOME'] ?? '';
    final sourceDir = Directory('$home/.ninjadev/fonts');
    final sources = <File>[];
    if (sourceDir.existsSync()) {
      sources.addAll(sourceDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.ttf')));
      sources.sort((a, b) => a.path.compareTo(b.path));
    }
    if (sources.isEmpty) {
      _logger.warn('No fonts found in ${sourceDir.path}');
      _logger.info(
          'Paste your .ttf files there once — they will be copied into every project automatically.');
      return;
    }
    Directory('assets/fonts').createSync(recursive: true);
    final copiedNames = <String>[];
    for (final source in sources) {
      final name = source.path.split(Platform.pathSeparator).last;
      copiedNames.add(name);
      final target = File('assets/fonts/$name');
      if (target.existsSync()) {
        _logger.info('Already there: assets/fonts/$name');
        continue;
      }
      source.copySync(target.path);
      _logger.success('Copied $name into assets/fonts/');
    }
    _registerFontsInPubspec(copiedNames);
  }

  static const Map<String, int> _fontWeights = {
    'thin': 100,
    'extralight': 200,
    'light': 300,
    'regular': 400,
    'medium': 500,
    'semibold': 600,
    'bold': 700,
    'extrabold': 800,
    'black': 900,
  };

  /// Registers font families in pubspec.yaml based on file names,
  /// e.g. Poppins-SemiBold.ttf -> family Poppins, weight 600.
  /// Syncs pubspec.yaml with [fontFileNames]: brand-new families are
  /// added, and new weights for a family that's already registered are
  /// merged into its existing `fonts:` list instead of being skipped.
  ///
  /// The whole `fonts:` list is rebuilt in memory and written with a
  /// single `editor.update()` call — `appendToList` corrupts the YAML
  /// here whenever the touched list isn't the last node in the file.
  void _registerFontsInPubspec(List<String> fontFileNames) {
    final file = File('pubspec.yaml');
    if (!file.existsSync()) {
      _logger.warn('pubspec.yaml not found — fonts not registered');
      return;
    }
    try {
      final content = file.readAsStringSync();
      final editor = YamlEditor(content);
      final root = loadYaml(content);
      final flutterSection = root is Map ? root['flutter'] : null;

      final byFamily = <String, List<Map<String, Object>>>{};
      for (final name in fontFileNames) {
        final base = name.substring(0, name.length - 4);
        final dash = base.indexOf('-');
        final family = dash == -1 ? base : base.substring(0, dash);
        final variant =
            dash == -1 ? 'regular' : base.substring(dash + 1).toLowerCase();
        final weight = _fontWeights[variant.replaceAll('italic', '')] ?? 400;
        final font = <String, Object>{
          'asset': 'assets/fonts/$name',
          'weight': weight,
          if (variant.contains('italic')) 'style': 'italic',
        };
        byFamily.putIfAbsent(family, () => []).add(font);
      }

      var changed = false;
      final newTopList = <Object>[];
      final remaining = Map<String, List<Map<String, Object>>>.from(byFamily);

      if (flutterSection is Map && flutterSection['fonts'] is List) {
        for (final entry in flutterSection['fonts'] as List) {
          if (entry is! Map || entry['family'] == null) {
            newTopList.add(entry);
            continue;
          }
          final family = entry['family'].toString();
          final incoming = remaining.remove(family);
          if (incoming == null) {
            newTopList.add(entry);
            continue;
          }
          final existingAssets = <String>{
            if (entry['fonts'] is List)
              for (final f in entry['fonts'] as List)
                if (f is Map && f['asset'] != null) f['asset'].toString(),
          };
          final toAdd = incoming
              .where((f) => !existingAssets.contains(f['asset']))
              .toList();
          if (toAdd.isEmpty) {
            newTopList.add(entry);
            continue;
          }
          newTopList.add({
            'family': family,
            'fonts': [
              if (entry['fonts'] is List) ...(entry['fonts'] as List),
              ...toAdd,
            ],
          });
          changed = true;
          _logger.success(
              'Updated $family in pubspec.yaml (+${toAdd.length} weight${toAdd.length == 1 ? '' : 's'})');
        }
      }

      for (final entry in remaining.entries) {
        newTopList.add({'family': entry.key, 'fonts': entry.value});
        changed = true;
        _logger.success('Registered ${entry.key} font family in pubspec.yaml');
        _logger.info("Use in code: TextStyle(fontFamily: '${entry.key}')");
      }

      if (!changed) {
        _logger.info('Fonts already up to date in pubspec.yaml');
        return;
      }
      if (flutterSection is! Map) {
        editor.update(['flutter'], {'fonts': newTopList});
      } else {
        editor.update(['flutter', 'fonts'], newTopList);
      }
      file.writeAsStringSync(editor.toString());
    } catch (e) {
      _logger.err('Could not update pubspec.yaml: $e');
    }
  }

  /// Folders you can generate files into: `lib` itself (always offered,
  /// so a brand-new project doesn't need a subfolder first) plus every
  /// subfolder underneath it.
  List<String> _libSubfolders() {
    final lib = Directory('lib');
    if (!lib.existsSync()) return [];
    final subfolders = <String>[
      for (final entity in lib.listSync(recursive: true))
        if (entity is Directory) entity.path,
    ]..sort();
    return ['lib', ...subfolders];
  }

  void _createServiceFile(String targetFolder, String rawName) {
    var name = rawName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    if (!name.endsWith('_service')) name = '${name}_service';
    final file = File('$targetFolder${Platform.pathSeparator}$name.dart');
    if (file.existsSync()) {
      _logger.warn('Already exists: ${file.path}');
      return;
    }
    final className = _pascalCase(name);
    file.createSync(recursive: true);
    file.writeAsStringSync(
        'class $className {\n  // TODO: add your code here\n}\n');
    _logger.success('Created ${file.path}');
  }

  String _pascalCase(String input) => input
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join();

  // ---------------------------------------------------------------------
  // HTTP API Function Generator
  // ---------------------------------------------------------------------

  /// Guided HTTP API function generator: pick or create a service file,
  /// choose the HTTP method + URL, name the function (with a smart
  /// suggestion), collect body/query params, confirm, then generate and
  /// insert the Dart function — reusing whatever HTTP client the
  /// project already has (Dio or package:http) instead of introducing
  /// a new one.
  void _runHttpApiFunctionWizard() {
    final serviceFiles = _findServiceFiles();
    final picked = NinjaUI.selectServiceFile(serviceFiles);
    if (picked == null) return;

    final String targetPath;
    if (picked == '__new__') {
      final created = _createNewServiceFile();
      if (created == null) return;
      targetPath = created;
    } else {
      targetPath = picked;
    }

    final method = NinjaUI.httpMethodMenu();
    if (method == null) return;

    String? envKey;
    if (NinjaUI.askUseEnv()) {
      envKey = NinjaUI.askEnvKey();
    }
    final url = NinjaUI.askApiUrl();

    String functionName;
    var overwrite = false;
    while (true) {
      final suggested = HttpFunctionGenerator.suggestFunctionName(method, url);
      var name = NinjaUI.askFunctionNameSuggested(suggested);

      if (!HttpFunctionGenerator.isValidDartIdentifier(name)) {
        final converted = HttpFunctionGenerator.toDartIdentifier(name);
        if (converted == null ||
            !HttpFunctionGenerator.isValidDartIdentifier(converted)) {
          NinjaUI.invalidFunctionName();
          continue;
        }
        NinjaUI.nameAutoConverted(name, converted);
        name = converted;
      }

      final existing = File(targetPath).existsSync()
          ? File(targetPath).readAsStringSync()
          : '';
      if (HttpFunctionGenerator.hasFunction(existing, name)) {
        final action = NinjaUI.duplicateFunctionMenu(name);
        if (action == 'cancel') return;
        if (action == 'rename') continue;
        overwrite = true;
      }
      functionName = name;
      break;
    }

    String? bodyType;
    if (const ['POST', 'PUT', 'PATCH'].contains(method)) {
      if (NinjaUI.yesNoMenu('Does this request need a body?')) {
        bodyType = NinjaUI.bodyTypeMenu();
      }
    }

    var headers = const <String, HeaderValue>{};
    if (NinjaUI.askUseHeaders()) {
      headers = NinjaUI.askHeaders();
    }

    var queryParams = const <String>[];
    if (method == 'GET') {
      if (NinjaUI.yesNoMenu('Does this request need query parameters?',
          defaultYes: false)) {
        queryParams = NinjaUI.askQueryParams();
      }
    }

    final proceed = NinjaUI.confirmApiFunction(
      method: method,
      url: url,
      functionName: functionName,
      bodyType: bodyType,
      file: targetPath,
      envKey: envKey,
      headers: headers,
    );
    if (!proceed) {
      _logger.warn('Cancelled');
      return;
    }

    final pubspecContent = File('pubspec.yaml').existsSync()
        ? File('pubspec.yaml').readAsStringSync()
        : '';
    var fileContent = File(targetPath).existsSync()
        ? File(targetPath).readAsStringSync()
        : '';
    final client = HttpFunctionGenerator.detectClient(
      pubspecContent: pubspecContent,
      existingFileContent: fileContent,
    );

    if (overwrite) {
      fileContent =
          HttpFunctionGenerator.removeFunction(fileContent, functionName);
    }

    final request = HttpApiRequest(
      method: method,
      url: url,
      functionName: functionName,
      bodyType: bodyType,
      queryParams: queryParams,
      headers: headers,
      envKey: envKey,
    );
    final methodCode = HttpFunctionGenerator.generate(request, client);
    try {
      fileContent = HttpFunctionGenerator.insertIntoFile(
        fileContent,
        methodCode,
        client,
        needsDotenvImport: request.needsDotenv,
      );
    } catch (e) {
      _logger.err('Could not generate function safely: $e');
      return;
    }
    File(targetPath).writeAsStringSync(fileContent);
    _formatFile(targetPath);

    NinjaUI.apiFunctionCreated(
      file: targetPath,
      functionName: functionName,
      method: method,
      url: url,
    );

    // Whichever client/packages this call needed but pubspec.yaml
    // doesn't have yet get added automatically — same as the snippets
    // flow, the user's only remaining step is `flutter pub get`.
    final neededPackages = <String>{
      if (client.kind == HttpClientKind.dio) 'dio',
      if (client.kind == HttpClientKind.http) 'http',
      if (request.needsDotenv) 'flutter_dotenv',
    };
    _ensurePubspecDependencies(neededPackages);
  }

  /// Guided WebSocket service generator: picks the client
  /// (`web_socket_channel` or `dart:io`), a service name, the URL
  /// source (`.env` or literal), heartbeat and reconnect settings,
  /// then writes a complete reusable singleton service and wires up
  /// pubspec.yaml — the user's only remaining step is
  /// `flutter pub get`.
  void _runWebSocketWizard() {
    final clientKind = NinjaUI.socketClientMenu();
    if (clientKind == null) return;

    final baseName = NinjaUI.askSocketServiceName();

    String? envKey;
    var url = '';
    if (NinjaUI.askUseEnv(prompt: 'Use .env for the socket URL?')) {
      envKey = NinjaUI.askEnvKey();
    } else {
      url = NinjaUI.askSocketUrl();
    }

    final heartbeatSeconds = NinjaUI.askHeartbeatInterval();
    final maxReconnectAttempts = NinjaUI.askReconnectAttempts();

    final serviceName = '${_pascalCase(baseName)}Service';
    final folders = _libSubfolders();
    final servicesFolder = 'lib${Platform.pathSeparator}services';
    final target = folders.contains(servicesFolder)
        ? servicesFolder
        : (folders.isNotEmpty ? folders.first : 'lib');
    final path = '$target${Platform.pathSeparator}${baseName}_service.dart';

    final clientLabel =
        clientKind == 'channel' ? 'web_socket_channel' : 'dart:io WebSocket';
    if (!NinjaUI.confirmSocketService(
      clientLabel: clientLabel,
      serviceName: serviceName,
      urlOrEnv: envKey != null ? "dotenv.env['$envKey']" : url,
      heartbeat: heartbeatSeconds <= 0 ? 'Off' : 'Every ${heartbeatSeconds}s',
      reconnect:
          maxReconnectAttempts <= 0 ? 'Off' : '$maxReconnectAttempts attempts',
      file: path,
    )) {
      _logger.warn('Cancelled');
      return;
    }

    final config = SocketServiceConfig(
      clientKind: clientKind == 'channel'
          ? SocketClientKind.webSocketChannel
          : SocketClientKind.dartIo,
      baseName: baseName,
      url: url,
      envKey: envKey,
      heartbeatSeconds: heartbeatSeconds,
      maxReconnectAttempts: maxReconnectAttempts,
    );
    File(path).createSync(recursive: true);
    File(path).writeAsStringSync(WebSocketGenerator.generate(config));
    _formatFile(path);

    if (config.needsWebSocketChannel) {
      _ensurePubspecDependencies({'web_socket_channel'});
      _logger.info('Run "flutter pub get" to install web_socket_channel.');
    }

    NinjaUI.socketServiceCreated(
      file: path,
      serviceName: serviceName,
      clientLabel: clientLabel,
    );
  }

  /// Runs `dart format` on the generated file so line-wrapping, blank
  /// lines and indentation match the SDK's own formatting rules.
  /// Best-effort: a missing/failing formatter still leaves valid,
  /// correctly-structured Dart behind, just less prettily wrapped.
  void _formatFile(String path) {
    try {
      Process.runSync('dart', ['format', path]);
    } catch (_) {}
  }

  /// Finds every `*_service.dart` file under lib/, for the "select
  /// service file" picker.
  List<String> _findServiceFiles() {
    final lib = Directory('lib');
    if (!lib.existsSync()) return [];
    final files = <String>[
      for (final entity in lib.listSync(recursive: true))
        if (entity is File && entity.path.endsWith('_service.dart'))
          entity.path,
    ]..sort();
    return files;
  }

  /// Creates a new, empty service file for the "+ Create new service"
  /// choice and returns its path, or null if the name was invalid.
  String? _createNewServiceFile() {
    final rawName = NinjaUI.askNewServiceName();
    var name = rawName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    if (name.isEmpty) {
      _logger.err('Invalid service name');
      return null;
    }
    if (!name.endsWith('_service')) name = '${name}_service';

    final folders = _libSubfolders();
    final servicesFolder = 'lib${Platform.pathSeparator}services';
    final preferred = folders.firstWhere(
      (f) =>
          f == servicesFolder ||
          f.endsWith('${Platform.pathSeparator}services'),
      orElse: () => folders.isNotEmpty ? folders.first : 'lib',
    );
    final path = '$preferred${Platform.pathSeparator}$name.dart';
    final file = File(path);
    if (!file.existsSync()) {
      final className = _pascalCase(name);
      file.createSync(recursive: true);
      file.writeAsStringSync('class $className {\n}\n');
      _logger.success('Created $path');
    }
    return path;
  }

  Directory _snippetsDir() {
    final home = Platform.environment['HOME'] ?? '';
    return Directory('$home/.ninjadev/snippets');
  }

  List<String> _availableSnippets() {
    final dir = _snippetsDir();
    if (!dir.existsSync()) return [];
    final names = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.toLowerCase().endsWith('.dart'))
        .map((file) => file.path.split(Platform.pathSeparator).last)
        .toList();
    names.sort();
    return names;
  }

  void _copySnippet(String targetFolder, String fileName) {
    final source =
        File('${_snippetsDir().path}${Platform.pathSeparator}$fileName');
    final target = File('$targetFolder${Platform.pathSeparator}$fileName');
    if (target.existsSync()) {
      _logger.warn('Already exists: ${target.path}');
      return;
    }
    target.parent.createSync(recursive: true);
    source.copySync(target.path);
    _logger.success('Created ${target.path}');
  }

  /// Scans the copied snippet files for `package:` imports and wires up
  /// whatever they need: the package in pubspec.yaml (so `flutter pub
  /// get` picks it up) and any iOS/Android permissions known to be
  /// required by that package.
  void _wireSnippetDependencies(String targetFolder, List<String> fileNames) {
    final packages = <String>{};
    for (final name in fileNames) {
      final file = File('$targetFolder${Platform.pathSeparator}$name');
      if (!file.existsSync()) continue;
      packages.addAll(_extractImportedPackages(file.readAsStringSync()));
    }
    if (packages.isEmpty) return;

    _ensurePubspecDependencies(packages);

    final iosEntries = <String, String>{};
    final androidPerms = <String>{};
    for (final pkg in packages) {
      final spec = _packagePermissions[pkg];
      if (spec == null) continue;
      iosEntries.addAll(spec.ios);
      androidPerms.addAll(spec.android);
    }
    if (iosEntries.isNotEmpty) _addIosPermissions(iosEntries);
    if (androidPerms.isNotEmpty) _addAndroidPermissions(androidPerms.toList());
    _logger.info('Run "flutter pub get" to install the new packages.');
  }

  static const Set<String> _packagesToSkip = {
    'flutter',
    'flutter_test',
    'flutter_driver',
    'flutter_localizations',
  };

  Set<String> _extractImportedPackages(String content) {
    final matches = RegExp(r'''import\s+['"]package:([a-zA-Z0-9_]+)/''')
        .allMatches(content);
    return {for (final m in matches) m.group(1)!}
      ..removeWhere(_packagesToSkip.contains);
  }

  /// Adds any package in [packages] that's missing from pubspec.yaml's
  /// `dependencies:` map, using `any` so the next `flutter pub get`
  /// resolves whatever version is compatible.
  void _ensurePubspecDependencies(Set<String> packages) {
    final file = File('pubspec.yaml');
    if (!file.existsSync()) return;
    try {
      final content = file.readAsStringSync();
      final editor = YamlEditor(content);
      final root = loadYaml(content);
      final deps = root is Map ? root['dependencies'] : null;

      if (deps is! Map) {
        editor.update(['dependencies'], {for (final p in packages) p: 'any'});
        file.writeAsStringSync(editor.toString());
        _logger.success('Added to pubspec.yaml: ${packages.join(', ')}');
        return;
      }

      final added = <String>[];
      for (final pkg in packages) {
        if (deps.containsKey(pkg)) continue;
        editor.update(['dependencies', pkg], 'any');
        added.add(pkg);
      }
      if (added.isEmpty) return;
      file.writeAsStringSync(editor.toString());
      _logger.success('Added to pubspec.yaml: ${added.join(', ')}');
    } catch (e) {
      _logger.err('Could not update pubspec.yaml dependencies: $e');
    }
  }

  /// Adds missing keys from [entries] to ios/Runner/Info.plist, right
  /// before the outermost `</dict>` — plain text insertion since a
  /// stock Info.plist has no other `</dict>` after it in the file.
  void _addIosPermissions(Map<String, String> entries) {
    final file = File('ios/Runner/Info.plist');
    if (!file.existsSync()) return;
    try {
      final content = file.readAsStringSync();
      final toAdd = entries.entries
          .where((e) => !content.contains('<key>${e.key}</key>'))
          .toList();
      if (toAdd.isEmpty) return;
      final closingDictIndex = content.lastIndexOf('</dict>');
      if (closingDictIndex == -1) {
        _logger.warn(
            'Could not find </dict> in Info.plist — add permissions manually.');
        return;
      }
      final insertion = toAdd
          .map((e) => '\t<key>${e.key}</key>\n\t<string>${e.value}</string>\n')
          .join();
      final updated = content.substring(0, closingDictIndex) +
          insertion +
          content.substring(closingDictIndex);
      file.writeAsStringSync(updated);
      _logger.success(
          'Added to Info.plist: ${toAdd.map((e) => e.key).join(', ')}');
    } catch (e) {
      _logger.err('Could not update Info.plist: $e');
    }
  }

  /// Adds missing permissions to android/app/src/main/AndroidManifest.xml,
  /// right after the opening `<manifest ...>` tag.
  void _addAndroidPermissions(List<String> permissions) {
    final file = File('android/app/src/main/AndroidManifest.xml');
    if (!file.existsSync()) return;
    try {
      final content = file.readAsStringSync();
      final toAdd =
          permissions.where((p) => !content.contains('"$p"')).toList();
      if (toAdd.isEmpty) return;
      final manifestStart = content.indexOf('<manifest');
      final tagEnd =
          manifestStart == -1 ? -1 : content.indexOf('>', manifestStart);
      if (tagEnd == -1) {
        _logger.warn(
            'Could not find <manifest> in AndroidManifest.xml — add permissions manually.');
        return;
      }
      final insertion =
          toAdd.map((p) => '\n    <uses-permission android:name="$p"/>').join();
      final updated = content.substring(0, tagEnd + 1) +
          insertion +
          content.substring(tagEnd + 1);
      file.writeAsStringSync(updated);
      _logger.success('Added to AndroidManifest.xml: ${toAdd.join(', ')}');
    } catch (e) {
      _logger.err('Could not update AndroidManifest.xml: $e');
    }
  }

  /// Pushes the project to GitHub. The first time — no `origin` remote
  /// yet — its GitHub repo is created under whichever account is logged
  /// in (installing the GitHub CLI / logging in right here if needed) and
  /// everything goes up as the initial commit. Every push after that
  /// bumps the version: pubspec.yaml's major number and build number are
  /// each incremented by 1 (e.g. 1.0.0+1 -> 2.0.0+2), then everything is
  /// staged, committed and pushed to the current branch's remote.
  Future<void> _runGitPushWizard() async {
    final gitService = GitService(_logger);
    if (!await gitService.isGitInstalled()) {
      _logger.err('Git is not installed.');
      return;
    }
    if (!await gitService.isRepo(Directory.current.path) ||
        await _originUrl() == null) {
      await _createRepoAndPush(gitService);
      return;
    }
    final pubspecFile = File('pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      _logger.err('pubspec.yaml not found in current directory');
      return;
    }
    final content = pubspecFile.readAsStringSync();
    final versionMatch =
        RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(content);
    if (versionMatch == null) {
      _logger.err('Could not find a "version:" line in pubspec.yaml');
      return;
    }
    final oldVersion = versionMatch.group(1)!;
    final newVersion = _bumpVersion(oldVersion);
    if (newVersion == null) {
      _logger.err(
          'Could not parse version "$oldVersion" (expected X.Y.Z+B, e.g. 1.0.0+1)');
      return;
    }

    final statusResult =
        await Process.run('git', ['status', '--short'], runInShell: true);
    final changedFiles = statusResult.stdout
        .toString()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (!NinjaUI.confirmGitPush(
      oldVersion: oldVersion,
      newVersion: newVersion,
      changedFiles: changedFiles,
    )) {
      _logger.warn('Cancelled');
      return;
    }

    final editor = YamlEditor(content);
    editor.update(['version'], newVersion);
    pubspecFile.writeAsStringSync(editor.toString());
    _logger.success('Version bumped: $oldVersion -> $newVersion');

    await gitService.stageAndCommit(
      Directory.current.path,
      message: 'chore: bump version to $newVersion',
    );
    await gitService.push(Directory.current.path);
  }

  /// The `origin` remote's URL, or null when the project has none yet.
  Future<String?> _originUrl() async {
    final result = await Process.run('git', ['remote', 'get-url', 'origin'],
        runInShell: true, workingDirectory: Directory.current.path);
    final url = result.stdout.toString().trim();
    return result.exitCode == 0 && url.isNotEmpty ? url : null;
  }

  /// First push of a project that isn't on GitHub yet: creates its repo
  /// under the logged-in account (named after the project folder unless
  /// changed), commits everything and pushes it. A missing GitHub CLI
  /// gets installed and a missing login done right here, so the push
  /// carries on in one go.
  Future<void> _createRepoAndPush(GitService gitService) async {
    _logger.info(
        'This project isn\'t on GitHub yet — its repository gets created first.');
    if (!await _ensureGhInstalled()) return;
    final account = await _ensureGhLogin();
    if (account == null) return;

    final folderName =
        Directory.current.path.split(Platform.pathSeparator).last;
    final repoName = NinjaUI.askGithubRepoName(folderName);
    final isPrivate = NinjaUI.askRepoIsPrivate();

    if (!NinjaUI.confirmGithubUpload(
      account: account,
      repoName: repoName,
      isPrivate: isPrivate,
    )) {
      _logger.warn('Cancelled');
      return;
    }

    if (!await gitService.isRepo(Directory.current.path)) {
      await gitService.init(Directory.current.path);
    }
    await gitService.stageAndCommit(Directory.current.path,
        message: 'Initial commit');

    final progress = _logger.progress('Creating GitHub repository...');
    final createResult = await Process.run(
      'gh',
      ['repo', 'create', repoName, isPrivate ? '--private' : '--public'],
      runInShell: true,
      workingDirectory: Directory.current.path,
    );
    if (createResult.exitCode != 0) {
      progress.fail(
          'Failed to create GitHub repo: ${createResult.stderr.toString().trim()}');
      return;
    }
    final repoUrl = createResult.stdout.toString().trim();
    progress.complete('GitHub repository created: $repoUrl');

    await gitService.setupRemote(Directory.current.path, '$repoUrl.git');
    await gitService.push(Directory.current.path);
  }

  /// Makes sure the GitHub CLI is there — when it's missing, offers to
  /// install it with Homebrew (macOS/Linux) or winget (Windows) instead
  /// of sending the user off to do it by hand.
  Future<bool> _ensureGhInstalled() async {
    if (await _checkTool('GitHub CLI', 'gh')) return true;

    const manualHint =
        'Install it from https://cli.github.com/, then try again.';
    final installCommand = await _ghInstallCommand();
    if (installCommand == null ||
        !NinjaUI.yesNoMenu(
            'Install GitHub CLI now? (${installCommand.join(' ')})')) {
      _logger.info(manualHint);
      return false;
    }

    final exitCode =
        await _runAttached(installCommand.first, installCommand.sublist(1));
    if (exitCode == 0 && await _checkTool('GitHub CLI', 'gh')) return true;
    _logger.err(exitCode == 0
        ? 'GitHub CLI was installed but isn\'t on PATH yet — open a new terminal and try again.'
        : 'Installing GitHub CLI failed. $manualHint');
    return false;
  }

  /// `brew install gh` where Homebrew is available, the winget package on
  /// Windows, or null when there's no package manager to install with.
  Future<List<String>?> _ghInstallCommand() async {
    final command = Platform.isWindows
        ? ['winget', 'install', '--id', 'GitHub.cli', '-e']
        : ['brew', 'install', 'gh'];
    try {
      final result =
          await Process.run(command.first, ['--version'], runInShell: true);
      return result.exitCode == 0 ? command : null;
    } catch (_) {
      return null;
    }
  }

  /// The GitHub account the CLI is logged in as. When nobody is logged in
  /// on this machine yet, the user logs in with their own account right
  /// here first.
  Future<String?> _ensureGhLogin() async {
    final account = await _ghAccount();
    if (account != null) return account;

    if (!NinjaUI.yesNoMenu('Not logged in to GitHub yet. Log in now?')) {
      _logger
          .info('Log in from "GitHub account" in this menu, then try again.');
      return null;
    }
    return _ghLogin();
  }

  /// Runs the interactive `gh auth login` (browser + one-time code, HTTPS)
  /// and points git at that login, so `git push` doesn't ask for its own
  /// password. Returns the account now logged in, or null.
  Future<String?> _ghLogin() async {
    await _runAttached('gh', [
      'auth',
      'login',
      '--hostname',
      'github.com',
      '--git-protocol',
      'https',
      '--web',
    ]);
    final account = await _ghAccount();
    if (account == null) {
      _logger.err('Not logged in to GitHub — try again from "GitHub account".');
      return null;
    }
    await Process.run('gh', ['auth', 'setup-git'], runInShell: true);
    _logger.success('Logged in to GitHub as $account');
    return account;
  }

  /// "GitHub account": each user logs in with their own GitHub account
  /// here, adds and switches to another one, or logs out. Pushes create
  /// repos under whichever account is active.
  Future<void> _runGithubAccountMenu() async {
    if (!await _ensureGhInstalled()) return;
    final account = await _ghAccount();
    final action = NinjaUI.githubAccountMenu(account);
    if (action == 'login') {
      await _ghLogin();
    } else if (action == 'logout' && account != null) {
      await _runAttached('gh',
          ['auth', 'logout', '--hostname', 'github.com', '--user', account]);
      final nowActive = await _ghAccount();
      if (nowActive == null) {
        _logger.success('Logged out of GitHub');
      } else {
        _logger.info('Now using GitHub account $nowActive');
      }
    }
  }

  /// The logged-in GitHub username, or null when the CLI isn't logged in.
  Future<String?> _ghAccount() async {
    final result = await Process.run('gh', ['api', 'user', '--jq', '.login'],
        runInShell: true);
    final login = result.stdout.toString().trim();
    return result.exitCode == 0 && login.isNotEmpty ? login : null;
  }

  /// Runs [executable] attached to this terminal, so its own prompts and
  /// progress work exactly as if it had been started by hand. Returns its
  /// exit code.
  Future<int> _runAttached(String executable, List<String> args) async {
    final process = await Process.start(executable, args,
        runInShell: true, mode: ProcessStartMode.inheritStdio);
    return process.exitCode;
  }

  /// Bumps "X.Y.Z+B" to "(X+1).Y.Z+(B+1)", e.g. 1.0.0+1 -> 2.0.0+2.
  /// Returns null if [version] isn't in that shape.
  String? _bumpVersion(String version) {
    final pattern = RegExp('^([0-9]+)\\.([0-9]+)\\.([0-9]+)\\+([0-9]+)\$');
    final match = pattern.firstMatch(version.trim());
    if (match == null) return null;
    final major = int.parse(match.group(1)!) + 1;
    final minor = match.group(2)!;
    final patch = match.group(3)!;
    final build = int.parse(match.group(4)!) + 1;
    return '$major.$minor.$patch+$build';
  }

  void _createEnvFile() {
    final file = File('.env');
    if (file.existsSync()) {
      _logger.warn('.env already exists at project root');
      return;
    }
    file.writeAsStringSync(
        '# Environment variables\n# API_BASE_URL=https://api.example.com\n');
    _logger.success('Created .env at project root');
    _logger
        .info('Tip: add .env to .gitignore and load it with flutter_dotenv.');
  }

  void _printUsage() => NinjaUI.printUsage();

  void _printVersion() => _logger.info('NinjaDev ${NinjaUI.version}');
}
