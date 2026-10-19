import 'dart:io';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:ninjadev/src/commands/generate_command.dart';
import 'package:ninjadev/src/generators/api_generator.dart';
import 'package:ninjadev/src/generators/feature_generator.dart';
import 'package:ninjadev/src/generators/local_setup_generator.dart';
import 'package:ninjadev/src/generators/main_dart_wiring.dart';
import 'package:ninjadev/src/generators/model_generator.dart';
import 'package:ninjadev/src/generators/theme_generator.dart';
import 'package:ninjadev/src/generators/widget_generator.dart';
import 'package:ninjadev/src/services/config_service.dart';
import 'package:ninjadev/src/services/package_service.dart';
import 'package:ninjadev/src/utils/ui.dart';

class GenerateService {
  final ConfigService _config;
  final Logger _logger;
  GenerateService(this._config, this._logger);
  Future<void> generate(GenerateOptions options) async {
    if (options.dryRun) {
      _logger.info('Dry run mode — no files will be created\n');
    }
    switch (options.type) {
      case 'feature':
        await _generateFeature(options);
        break;
      case 'widget':
        await _generateWidget(options);
        break;
      case 'model':
        await _generateModel(options);
        break;
      case 'api':
      case 'service':
        await _generateApi(options);
        break;
      case 'theme':
        await _generateTheme(options);
        break;
      case 'screen':
        await _generateScreen(options);
        break;
      case 'settings':
        await _generateSettings(options);
        break;
      case 'repository':
        await _generateRepository(options);
        break;
      case 'bloc':
        await _generateBloc(options);
        break;
      case 'cubit':
        await _generateCubit(options);
        break;
      case 'provider':
        await _generateProvider(options);
        break;
      case 'controller':
        await _generateController(options);
        break;
      default:
        _logger.err('Unknown generate type: ${options.type}');
        _logger.info(
            'Available types: feature, widget, model, api, theme, screen, settings, repository, bloc, cubit, provider, controller');
    }
  }

  Future<void> _generateFeature(GenerateOptions options) async {
    if (options.name == null) {
      _logger.err('Feature name is required');
      _logger.info('Usage: ninjadev generate feature <name>');
      return;
    }
    final generator = FeatureGenerator(_config, _logger);
    await generator.generate(
      options.name!,
      feature: options.feature,
      path: options.path,
      dryRun: options.dryRun,
    );
  }

  Future<void> _generateWidget(GenerateOptions options) async {
    if (options.name == null) {
      _logger.err('Widget name is required');
      _logger.info('Usage: ninjadev generate widget <name>');
      return;
    }
    final generator = WidgetGenerator(_logger);
    await generator.generate(
      options.name!,
      feature: options.feature,
      path: options.path,
      dryRun: options.dryRun,
    );
  }

  Future<void> _generateModel(GenerateOptions options) async {
    if (options.name == null) {
      _logger.err('Model name is required');
      _logger.info('Usage: ninjadev generate model <name>');
      return;
    }
    final generator = ModelGenerator(_logger);
    await generator.generate(
      options.name!,
      feature: options.feature,
      path: options.path,
      dryRun: options.dryRun,
    );
  }

  Future<void> _generateApi(GenerateOptions options) async {
    if (options.name == null) {
      _logger.err('API service name is required');
      _logger.info('Usage: ninjadev generate api <name>');
      return;
    }
    final generator = ApiGenerator(_logger);
    await generator.generate(
      options.name!,
      feature: options.feature,
      path: options.path,
      dryRun: options.dryRun,
    );
  }

  Future<void> _generateTheme(GenerateOptions options) async {
    final generator = ThemeGenerator(_logger);
    await generator.generate(
      options.path ?? p.join(Directory.current.path, 'lib', 'core', 'theme'),
      dryRun: options.dryRun,
    );
  }

  Future<void> _generateScreen(GenerateOptions options) async {
    if (options.name == null) {
      _logger.err('Screen name is required');
      _logger.info('Usage: ninjadev generate screen <name>');
      return;
    }
    final type = options.template ?? 'default';
    final screenContent = _getScreenTemplate(options.name!, type);
    final outputPath = options.path ??
        p.join(
          Directory.current.path,
          'lib',
          options.feature ?? 'screens',
          '${_toFileName(options.name!)}_screen.dart',
        );
    if (options.dryRun) {
      _logger.info('Would create: $outputPath');
      _logger.detail(screenContent);
    } else {
      await File(outputPath).create(recursive: true);
      await File(outputPath).writeAsString(screenContent);
      _logger.success('Created screen: $outputPath');
    }
  }

  /// Generates the "Custom settings page (local/deploy)" bundle: app-wide
  /// mode state, the TESTING banner, an internet-connectivity guard and
  /// the mode-picker page — all wired to the same [outputPath] so their
  /// relative imports resolve. Both setups come in portrait (default)
  /// and landscape, and main.dart is rewired to exactly the setup picked,
  /// in the folder it went into. The Local setup's mode page also saves
  /// the backend address (api_config.dart) and finds servers on the
  /// network with Bonsoir, so its platform permissions get wired up too.
  Future<void> _generateSettings(GenerateOptions options) async {
    final isLandscape = options.orientation == 'landscape';
    final isLocal = options.setup == 'local';

    final outputPath = options.path ??
        p.join(Directory.current.path, 'lib', 'screens', 'settings');

    final files = <String, String>{
      'app_mode.dart': _appModeContent(),
      'ModeBanner.dart': _modeBannerContent(),
      'internetcheck.dart': _internetCheckContent(),
      if (isLocal) 'api_config.dart': LocalSetupGenerator.apiConfig,
      'mode.dart': isLocal
          ? LocalSetupGenerator.modePage(landscape: isLandscape)
          : _modePageContent(landscape: isLandscape),
    };

    // The Local mode page imports ../widgets/press_scale.dart. A copy the
    // project already has is left alone.
    final pressScalePath =
        p.normalize(p.join(outputPath, '..', 'widgets', 'press_scale.dart'));
    final writePressScale = isLocal && !await File(pressScalePath).exists();

    if (options.dryRun) {
      for (final entry in files.entries) {
        _logger.info('Would create: ${p.join(outputPath, entry.key)}');
        _logger.detail(entry.value);
      }
      if (writePressScale) {
        _logger.info('Would create: $pressScalePath');
        _logger.detail(LocalSetupGenerator.pressScale);
      }
      return;
    }

    for (final entry in files.entries) {
      final filePath = p.join(outputPath, entry.key);
      await File(filePath).create(recursive: true);
      await File(filePath).writeAsString(entry.value);
    }
    if (writePressScale) {
      await File(pressScalePath).create(recursive: true);
      await File(pressScalePath).writeAsString(LocalSetupGenerator.pressScale);
    }

    final packages = PackageService(_logger);
    await packages.ensurePackage('shared_preferences', version: '^2.2.0');
    if (isLocal) {
      await packages.ensurePackage('flutter_screenutil');
      await packages.ensurePackage('bonsoir', version: '^7.1.5');
    } else {
      await packages.ensurePackage('flutter_dotenv');
    }

    await _wireMainDart(outputPath, isLocal: isLocal);
    if (isLocal) {
      await _addLocalNetworkAccess();
    }

    _logger.success('Created settings pages in: $outputPath');
    NinjaUI.printTree('Generated settings', [
      '$outputPath/',
      for (final name in files.keys) '  $name',
      if (writePressScale) pressScalePath,
    ]);
  }

  /// Wires lib/main.dart to the bundle just generated in [outputPath], so
  /// the app starts on exactly the setup that was picked (see
  /// [MainDartWiring]) — then formats it, and prints a hint for anything
  /// main.dart doesn't have the expected shape for.
  Future<void> _wireMainDart(String outputPath, {required bool isLocal}) async {
    final setupName = isLocal ? 'Local' : 'Online';
    final mainFile = File(p.join('lib', 'main.dart'));
    final packageName = await _packageName();
    final folder = _libFolder(outputPath);
    if (!await mainFile.exists() || packageName == null || folder == null) {
      _logger.info('Wire the $setupName setup into lib/main.dart by hand: '
          'import ModeBanner.dart, app_mode.dart, mode.dart'
          '${isLocal ? ' and api_config.dart' : ''}, call loadSavedMode()'
          '${isLocal ? ' and loadSavedApi()' : ''} before runApp(), and make '
          'ModePage() the home screen.');
      return;
    }

    final original = await mainFile.readAsString();
    final result = MainDartWiring.wire(
      original,
      packageName: packageName,
      folder: folder,
      isLocal: isLocal,
    );
    if (result.content != original) {
      await mainFile.writeAsString(result.content);
      try {
        await Process.run('dart', ['format', mainFile.path], runInShell: true);
      } catch (_) {}
    }
    _logger
        .success('lib/main.dart starts on the $setupName setup in lib/$folder');
    for (final hint in result.hints) {
      _logger.info('Still to do in lib/main.dart: $hint.');
    }
  }

  /// The project's package name from pubspec.yaml, or null.
  Future<String?> _packageName() async {
    final pubspecFile = File('pubspec.yaml');
    if (!await pubspecFile.exists()) return null;
    try {
      final pubspec = loadYaml(await pubspecFile.readAsString());
      return pubspec is Map ? pubspec['name']?.toString() : null;
    } catch (_) {
      return null;
    }
  }

  /// [outputPath] as the folder part of a package import — '' for lib/
  /// itself, 'services/' for lib/services — or null when it's outside lib/.
  String? _libFolder(String outputPath) {
    final fromLib = p.relative(p.absolute(outputPath), from: p.absolute('lib'));
    if (fromLib.startsWith('..')) return null;
    return fromLib == '.' ? '' : '${p.split(fromLib).join('/')}/';
  }

  /// Bonsoir has to be allowed to browse the local network, and the saved
  /// backend is plain http on a LAN IP — adds whatever of that is missing
  /// to Info.plist and AndroidManifest.xml, when the project has them.
  Future<void> _addLocalNetworkAccess() async {
    final plist = File(p.join('ios', 'Runner', 'Info.plist'));
    if (await plist.exists()) {
      final content = await plist.readAsString();
      final missing = LocalSetupGenerator.iosPlistEntries.entries
          .where((e) => !content.contains('<key>${e.key}</key>'))
          .toList();
      final closingDictIndex = content.lastIndexOf('</dict>');
      if (missing.isNotEmpty && closingDictIndex != -1) {
        final insertion =
            missing.map((e) => '\t<key>${e.key}</key>\n${e.value}').join();
        await plist.writeAsString(content.substring(0, closingDictIndex) +
            insertion +
            content.substring(closingDictIndex));
        _logger.success(
            'Added to Info.plist: ${missing.map((e) => e.key).join(', ')}');
      }
    }

    final manifest =
        File(p.join('android', 'app', 'src', 'main', 'AndroidManifest.xml'));
    if (await manifest.exists()) {
      var content = await manifest.readAsString();
      final added = <String>[];
      final missing = LocalSetupGenerator.androidPermissions
          .where((permission) => !content.contains('"$permission"'))
          .toList();
      final manifestStart = content.indexOf('<manifest');
      final tagEnd =
          manifestStart == -1 ? -1 : content.indexOf('>', manifestStart);
      if (missing.isNotEmpty && tagEnd != -1) {
        final insertion = missing
            .map((permission) =>
                '\n    <uses-permission android:name="$permission"/>')
            .join();
        content = content.substring(0, tagEnd + 1) +
            insertion +
            content.substring(tagEnd + 1);
        added.addAll(missing);
      }
      final applicationStart = content.indexOf('<application');
      if (!content.contains('android:usesCleartextTraffic') &&
          applicationStart != -1) {
        final insertAt = applicationStart + '<application'.length;
        content = '${content.substring(0, insertAt)}'
            '\n        android:usesCleartextTraffic="true"'
            '${content.substring(insertAt)}';
        added.add('usesCleartextTraffic');
      }
      if (added.isNotEmpty) {
        await manifest.writeAsString(content);
        _logger.success('Added to AndroidManifest.xml: ${added.join(', ')}');
      }
    }
  }

  String _appModeContent() {
    return '''
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
const String _modeKey = "app_is_testing";
const String _cameraKey = "app_use_front_camera";

/// true = TESTING, false = LIVE.
final ValueNotifier<bool> isTestingMode = ValueNotifier<bool>(false);

/// true = FRONT, false = BACK.
final ValueNotifier<bool> useFrontCamera = ValueNotifier<bool>(true);

/// What gets sent to the backend with every request.
String get modeName => isTestingMode.value ? "testing" : "live";

/// Reads the choice saved on the device. Call once before the first frame.
Future<void> loadSavedMode() async {
  final prefs = await SharedPreferences.getInstance();
  isTestingMode.value = prefs.getBool(_modeKey) ?? false;
  useFrontCamera.value = prefs.getBool(_cameraKey) ?? true;
  debugPrint("App Mode: loaded '\$modeName' and camera '\${useFrontCamera.value ? "front" : "back"}' from device");
}

/// Saves the choice on the device so it survives restarts.
Future<void> saveMode(bool testing) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_modeKey, testing);
  isTestingMode.value = testing;
  debugPrint("App Mode: saved '\$modeName' on device");
}

/// Saves the camera choice on the device.
Future<void> saveCameraPreference(bool front) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_cameraKey, front);
  useFrontCamera.value = front;
  debugPrint("App Mode: saved camera preference '\${front ? "front" : "back"}' on device");
}
''';
  }

  String _modeBannerContent() {
    return '''
import 'package:flutter/material.dart';

import 'app_mode.dart';

/// Puts a "TESTING" strip at the top of whatever is on screen.
///
/// Used from MaterialApp's `builder`, so it sits above every route — no page
/// has to add the header itself. In LIVE mode it renders nothing.
class ModeBanner extends StatelessWidget {
  const ModeBanner({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final content = child ?? const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: isTestingMode,
      builder: (context, isTesting, _) {
        if (!isTesting) return content;

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              content,
              // IgnorePointer so the strip never eats a tap meant for the page.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      width: double.infinity,
                      color: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: const Text(
                        "TESTING",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
''';
  }

  String _internetCheckContent() {
    return '''
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

/// Real connectivity check — a DNS lookup, so "wifi connected but no data"
/// is also reported as offline.
Future<bool> hasInternet() async {
  try {
    final result = await InternetAddress.lookup(
      'google.com',
    ).timeout(const Duration(seconds: 5));
    return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
  } on SocketException catch (e) {
    debugPrint("Internet Check: offline (SocketException: \${e.message})");
    return false;
  } on TimeoutException {
    debugPrint("Internet Check: offline (lookup timed out)");
    return false;
  }
}

/// Blocks with a non-dismissible "No Internet" popup until the device is
/// actually online. Returns as soon as the connection is back.
Future<void> ensureInternet(BuildContext context) async {
  while (!await hasInternet()) {
    if (!context.mounted) return;
    debugPrint("Internet Check: showing No Internet dialog.");
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Colors.white24),
            ),
            title: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.yellow),
                SizedBox(width: 10),
                Text(
                  "No Internet",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: const Text(
              "Please connect to the internet to continue.",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  "RETRY",
                  style: TextStyle(
                    color: Colors.yellow,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  debugPrint("Internet Check: online.");
}
''';
  }

  String _modePageContent({required bool landscape}) {
    return '''
import '../pages/Homepage.dart';
import 'package:flutter/material.dart';
import 'app_mode.dart';

/// First screen on every app start: pick TESTING or LIVE.
///
/// The choice is saved on the device, so the previously used mode comes back
/// already selected and keeps being sent to the backend until it is changed.
class ModePage extends StatefulWidget {
  const ModePage({super.key});

  @override
  State<ModePage> createState() => _ModePageState();
}

class _ModePageState extends State<ModePage> {
  bool? _isTesting;

  @override
  void initState() {
    super.initState();
    _isTesting = isTestingMode.value;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _select(bool testing) async {
    await saveMode(testing);
    if (!mounted) return;
    setState(() => _isTesting = testing);
  }

  @override
  Widget build(BuildContext context) {
    final double sw = MediaQuery.of(context).size.width;
    final double sh = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Dark gradient background ──────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0E1A),
                  Color(0xFF111827),
                  Color(0xFF0D1526),
                ],
              ),
            ),
          ),

          // ── Subtle decorative circles ─────────────────────────
          Positioned(
            top: -sh * 0.15,
            left: -sw * 0.1,
            child: Container(
              width: sh * 0.55,
              height: sh * 0.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF293E7D).withOpacity(0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -sh * 0.1,
            right: -sw * 0.08,
            child: Container(
              width: sh * 0.45,
              height: sh * 0.45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E3A5F).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

${landscape ? _onlineLandscapeContent : _onlinePortraitContent}
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader(double sw, double sh) {
    return Column(
      children: [
        // Icon badge
        Container(
          width: sh * 0.1,
          height: sh * 0.1,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.45),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.tune_rounded,
            color: Colors.white,
            size: sh * 0.042,
          ),
        ),

        SizedBox(height: sh * 0.022),

        const Text(
          'SELECT MODE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 5,
          ),
        ),

        SizedBox(height: sh * 0.008),

        Text(
          'Choose how the app operates',
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 13,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ── Mode card ─────────────────────────────────────────────────
  Widget _buildModeCard({
    required String label,
    required String description,
    required IconData icon,
    required Color selectedColor,
    required Color glowColor,
    required bool value,
    required double sw,
    required double sh,
  }) {
    final bool isSelected = _isTesting == value;

    return GestureDetector(
      onTap: () => _select(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: sw * 0.03,
          vertical: sh * 0.028,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected
              ? selectedColor.withOpacity(0.12)
              : Colors.white.withOpacity(0.04),
          border: Border.all(
            color: isSelected
                ? selectedColor.withOpacity(0.7)
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: glowColor.withOpacity(0.25),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Icon circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: sh * 0.072,
              height: sh * 0.072,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? selectedColor.withOpacity(0.2)
                    : Colors.white.withOpacity(0.06),
                border: Border.all(
                  color: isSelected
                      ? selectedColor.withOpacity(0.6)
                      : Colors.white.withOpacity(0.12),
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                color: isSelected ? selectedColor : Colors.white38,
                size: sh * 0.032,
              ),
            ),

            SizedBox(width: sw * 0.025),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? selectedColor : Colors.white70,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.38),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? selectedColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? selectedColor
                      : Colors.white.withOpacity(0.25),
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: selectedColor.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── Next button ───────────────────────────────────────────────
  Widget _buildNextButton(double sw, double sh) {
    final bool canProceed = _isTesting != null;

    return GestureDetector(
      onTap: canProceed
          ? () {
              debugPrint('Mode Page: continuing with \$modeName.');
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const Homepage(),
                  transitionsBuilder: (_, anim, __, child) {
                    return FadeTransition(opacity: anim, child: child);
                  },
                  transitionDuration: const Duration(milliseconds: 350),
                ),
              );
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        height: sh * 0.068,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: canProceed
              ? const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                )
              : null,
          color: canProceed ? null : Colors.white.withOpacity(0.07),
          boxShadow: canProceed
              ? [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.4),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'CONTINUE',
              style: TextStyle(
                color: canProceed ? Colors.white : Colors.white24,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            SizedBox(width: sw * 0.015),
            Icon(
              Icons.arrow_forward_rounded,
              color: canProceed ? Colors.white : Colors.white24,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
''';
  }

  /// Online mode page body, portrait: header, TESTING and LIVE stacked,
  /// then NEXT — all in one narrow centred column.
  static const String _onlinePortraitContent = '''
          // ── Main content ──────────────────────────────────────
          SafeArea(
            child: Center(
              child: SizedBox(
                width: sw * 0.65,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo / title
                    _buildHeader(sw, sh),

                    SizedBox(height: sh * 0.055),

                    // TESTING card
                    _buildModeCard(
                      label: 'TESTING',
                      description: 'Use test images · No real prints',
                      icon: Icons.science_rounded,
                      selectedColor: const Color(0xFFFF8C00),
                      glowColor: const Color(0xFFFF8C00),
                      value: true,
                      sw: sw,
                      sh: sh,
                    ),

                    SizedBox(height: sh * 0.03),

                    // LIVE card
                    _buildModeCard(
                      label: 'LIVE',
                      description: 'Real AI generation · Actual prints',
                      icon: Icons.bolt_rounded,
                      selectedColor: const Color(0xFF22C55E),
                      glowColor: const Color(0xFF22C55E),
                      value: false,
                      sw: sw,
                      sh: sh,
                    ),

                    SizedBox(height: sh * 0.06),

                    // NEXT button
                    _buildNextButton(sw, sh),
                  ],
                ),
              ),
            ),
          ),''';

  /// Online mode page body, landscape: same header and NEXT, but TESTING
  /// and LIVE sit side by side (kept the same height) across the wide
  /// screen instead of stacking.
  static const String _onlineLandscapeContent = '''
          // ── Main content ──────────────────────────────────────
          SafeArea(
            child: Center(
              child: SizedBox(
                width: sw * 0.7,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo / title
                    _buildHeader(sw, sh),

                    SizedBox(height: sh * 0.07),

                    // TESTING and LIVE side by side on the wide screen
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _buildModeCard(
                              label: 'TESTING',
                              description: 'Use test images · No real prints',
                              icon: Icons.science_rounded,
                              selectedColor: const Color(0xFFFF8C00),
                              glowColor: const Color(0xFFFF8C00),
                              value: true,
                              sw: sw,
                              sh: sh,
                            ),
                          ),
                          SizedBox(width: sw * 0.02),
                          Expanded(
                            child: _buildModeCard(
                              label: 'LIVE',
                              description: 'Real AI generation · Actual prints',
                              icon: Icons.bolt_rounded,
                              selectedColor: const Color(0xFF22C55E),
                              glowColor: const Color(0xFF22C55E),
                              value: false,
                              sw: sw,
                              sh: sh,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: sh * 0.07),

                    // NEXT button
                    _buildNextButton(sw, sh),
                  ],
                ),
              ),
            ),
          ),''';

  Future<void> _generateRepository(GenerateOptions options) async {
    if (options.name == null) {
      _logger.err('Repository name is required');
      _logger.info('Usage: ninjadev generate repository <name>');
      return;
    }
    final repoContent = '''
import '../models/${_toFileName(options.name!)}_model.dart';
abstract class ${_pascalCase(options.name!)}Repository {
  Future<List<${_pascalCase(options.name!)}Model>> getAll();
  Future<${_pascalCase(options.name!)}Model?> getById(String id);
  Future<${_pascalCase(options.name!)}Model> create(${_pascalCase(options.name!)}Model item);
  Future<${_pascalCase(options.name!)}Model> update(${_pascalCase(options.name!)}Model item);
  Future<void> delete(String id);
}
class ${_pascalCase(options.name!)}RepositoryImpl implements ${_pascalCase(options.name!)}Repository {
  @override
  Future<List<${_pascalCase(options.name!)}Model>> getAll() async {
    // TODO: implement getAll
    return [];
  }
  @override
  Future<${_pascalCase(options.name!)}Model?> getById(String id) async {
    // TODO: implement getById
    return null;
  }
  @override
  Future<${_pascalCase(options.name!)}Model> create(${_pascalCase(options.name!)}Model item) async {
    // TODO: implement create
    return item;
  }
  @override
  Future<${_pascalCase(options.name!)}Model> update(${_pascalCase(options.name!)}Model item) async {
    // TODO: implement update
    return item;
  }
  @override
  Future<void> delete(String id) async {
    // TODO: implement delete
  }
}
''';
    final outputPath = options.path ??
        p.join(
          Directory.current.path,
          'lib',
          options.feature ?? 'repositories',
          '${_toFileName(options.name!)}_repository.dart',
        );
    if (options.dryRun) {
      _logger.info('Would create: $outputPath');
      _logger.detail(repoContent);
    } else {
      await File(outputPath).create(recursive: true);
      await File(outputPath).writeAsString(repoContent);
      _logger.success('Created repository: $outputPath');
    }
  }

  Future<void> _generateBloc(GenerateOptions options) async {
    if (options.name == null) {
      _logger.err('Bloc name is required');
      _logger.info('Usage: ninjadev generate bloc <name>');
      return;
    }
    final blocContent = '''
import 'package:flutter_bloc/flutter_bloc.dart';
// Events
abstract class ${_pascalCase(options.name!)}Event {}
class ${_pascalCase(options.name!)}InitialEvent extends ${_pascalCase(options.name!)}Event {}
// States
abstract class ${_pascalCase(options.name!)}State {}
class ${_pascalCase(options.name!)}InitialState extends ${_pascalCase(options.name!)}State {}
class ${_pascalCase(options.name!)}LoadingState extends ${_pascalCase(options.name!)}State {}
class ${_pascalCase(options.name!)}LoadedState extends ${_pascalCase(options.name!)}State {}
class ${_pascalCase(options.name!)}ErrorState extends ${_pascalCase(options.name!)}State {
  final String message;
  ${_pascalCase(options.name!)}ErrorState(this.message);
}
class ${_pascalCase(options.name!)}Bloc extends Bloc<${_pascalCase(options.name!)}Event, ${_pascalCase(options.name!)}State> {
  ${_pascalCase(options.name!)}Bloc() : super(${_pascalCase(options.name!)}InitialState()) {
    on<${_pascalCase(options.name!)}InitialEvent>(_onInitial);
  }
  Future<void> _onInitial(${_pascalCase(options.name!)}InitialEvent event, Emitter<${_pascalCase(options.name!)}State> emit) async {
    emit(${_pascalCase(options.name!)}LoadingState());
    try {
      // TODO: implement logic
      emit(${_pascalCase(options.name!)}LoadedState());
    } catch (e) {
      emit(${_pascalCase(options.name!)}ErrorState(e.toString()));
    }
  }
}
''';
    final outputPath = options.path ??
        p.join(
          Directory.current.path,
          'lib',
          options.feature ?? 'blocs',
          '${_toFileName(options.name!)}_bloc.dart',
        );
    if (options.dryRun) {
      _logger.info('Would create: $outputPath');
      _logger.detail(blocContent);
    } else {
      await File(outputPath).create(recursive: true);
      await File(outputPath).writeAsString(blocContent);
      _logger.success('Created bloc: $outputPath');
    }
  }

  Future<void> _generateCubit(GenerateOptions options) async {
    if (options.name == null) {
      _logger.err('Cubit name is required');
      _logger.info('Usage: ninjadev generate cubit <name>');
      return;
    }
    final cubitContent = '''
import 'package:flutter_bloc/flutter_bloc.dart';
// States
abstract class ${_pascalCase(options.name!)}State {}
class ${_pascalCase(options.name!)}InitialState extends ${_pascalCase(options.name!)}State {}
class ${_pascalCase(options.name!)}LoadingState extends ${_pascalCase(options.name!)}State {}
class ${_pascalCase(options.name!)}LoadedState extends ${_pascalCase(options.name!)}State {}
class ${_pascalCase(options.name!)}ErrorState extends ${_pascalCase(options.name!)}State {
  final String message;
  ${_pascalCase(options.name!)}ErrorState(this.message);
}
class ${_pascalCase(options.name!)}Cubit extends Cubit<${_pascalCase(options.name!)}State> {
  ${_pascalCase(options.name!)}Cubit() : super(${_pascalCase(options.name!)}InitialState());
  Future<void> load() async {
    emit(${_pascalCase(options.name!)}LoadingState());
    try {
      // TODO: implement load
      emit(${_pascalCase(options.name!)}LoadedState());
    } catch (e) {
      emit(${_pascalCase(options.name!)}ErrorState(e.toString()));
    }
  }
}
''';
    final outputPath = options.path ??
        p.join(
          Directory.current.path,
          'lib',
          options.feature ?? 'cubits',
          '${_toFileName(options.name!)}_cubit.dart',
        );
    if (options.dryRun) {
      _logger.info('Would create: $outputPath');
      _logger.detail(cubitContent);
    } else {
      await File(outputPath).create(recursive: true);
      await File(outputPath).writeAsString(cubitContent);
      _logger.success('Created cubit: $outputPath');
    }
  }

  Future<void> _generateProvider(GenerateOptions options) async {
    if (options.name == null) {
      _logger.err('Provider name is required');
      _logger.info('Usage: ninjadev generate provider <name>');
      return;
    }
    final providerContent = '''
import 'package:flutter/foundation.dart';
class ${_pascalCase(options.name!)}Provider extends ChangeNotifier {
  ${_pascalCase(options.name!)}Provider();
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;
  Future<void> load() async {
    _isLoading = true;
    _error = null;
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
    final outputPath = options.path ??
        p.join(
          Directory.current.path,
          'lib',
          options.feature ?? 'providers',
          '${_toFileName(options.name!)}_provider.dart',
        );
    if (options.dryRun) {
      _logger.info('Would create: $outputPath');
      _logger.detail(providerContent);
    } else {
      await File(outputPath).create(recursive: true);
      await File(outputPath).writeAsString(providerContent);
      _logger.success('Created provider: $outputPath');
    }
  }

  Future<void> _generateController(GenerateOptions options) async {
    if (options.name == null) {
      _logger.err('Controller name is required');
      _logger.info('Usage: ninjadev generate controller <name>');
      return;
    }
    final controllerContent = '''
import 'package:get/get.dart';
class ${_pascalCase(options.name!)}Controller extends GetxController {
  final count = 0.obs;
  @override
  void onInit() {
    super.onInit();
  }
  void increment() => count.value++;
  void decrement() => count.value--;
}
''';
    final outputPath = options.path ??
        p.join(
          Directory.current.path,
          'lib',
          options.feature ?? 'controllers',
          '${_toFileName(options.name!)}_controller.dart',
        );
    if (options.dryRun) {
      _logger.info('Would create: $outputPath');
      _logger.detail(controllerContent);
    } else {
      await File(outputPath).create(recursive: true);
      await File(outputPath).writeAsString(controllerContent);
      _logger.success('Created controller: $outputPath');
    }
  }

  String _getScreenTemplate(String name, String type) {
    final className = _pascalCase(name);
    return '''
import 'package:flutter/material.dart';
class ${className}Screen extends StatefulWidget {
  const ${className}Screen({super.key});
  @override
  State<${className}Screen> createState() => _${className}ScreenState();
}
class _${className}ScreenState extends State<${className}Screen> {
  @override
  void initState() {
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('$className'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text('$className Screen'),
      ),
    );
  }
}
''';
  }

  String _pascalCase(String input) {
    return input.split(RegExp(r'[_\s-]')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join();
  }

  String _toFileName(String input) {
    return input
        .replaceAllMapped(
            RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')
        .replaceAll(RegExp(r'[\s-]'), '_')
        .replaceAll(RegExp(r'^_'), '')
        .toLowerCase();
  }
}
