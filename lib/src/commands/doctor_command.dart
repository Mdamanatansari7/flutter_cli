import 'dart:io';
import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/commands/command.dart';
import 'package:ninjadev/src/services/config_service.dart';

class DoctorCommand extends BaseCommand {
  DoctorCommand()
      : super(
          name: 'doctor',
          description: 'Check your development environment for issues',
          usage: '[options]',
        ) {
    parser.addFlag('fix',
        negatable: false, help: 'Attempt to fix issues automatically');
  }
  @override
  Future<void> run(
      List<String> args, ConfigService config, Logger logger) async {
    final parsedArgs = parser.parse(args);

    if (parsedArgs['help'] as bool) {
      printUsage(logger);
      return;
    }
    final fix = parsedArgs['fix'] as bool;
    logger.info('Running NinjaDev Doctor...');
    logger.info('');
    final issues = <DoctorIssue>[];
    final warnings = <DoctorIssue>[];
    // Check Flutter
    await _checkFlutter(logger, issues, warnings, fix);
    // Check Dart
    await _checkDart(logger, issues, warnings, fix);
    // Check Git
    await _checkGit(logger, issues, warnings, fix);
    // Check Android Studio / Xcode
    await _checkIDEs(logger, issues, warnings, fix);
    // Check connected devices
    await _checkDevices(logger, issues, warnings, fix);
    // Check NinjaDev config
    _checkConfig(config, logger, issues, warnings);
    // Summary
    if (issues.isEmpty && warnings.isEmpty) {
      logger
          .success('No issues found — your environment is ready for NinjaDev.');
    } else {
      if (issues.isNotEmpty) {
        logger.err('Issues found (${issues.length}):');
        for (final issue in issues) {
          logger.err('  • ${issue.message}');
          if (issue.fixHint != null) {
            logger.detail('    Fix: ${issue.fixHint}');
          }
        }
      }
      if (warnings.isNotEmpty) {
        logger.warn('Warnings (${warnings.length}):');
        for (final warning in warnings) {
          logger.warn('  • ${warning.message}');
          if (warning.fixHint != null) {
            logger.detail('    Fix: ${warning.fixHint}');
          }
        }
      }
    }
  }

  Future<void> _checkFlutter(Logger logger, List<DoctorIssue> issues,
      List<DoctorIssue> warnings, bool fix) async {
    logger.progress('Checking Flutter installation...').complete();
    try {
      final result =
          await Process.run('flutter', ['--version'], runInShell: true);
      if (result.exitCode == 0) {
        final version = result.stdout.toString().split('\n').first;
        logger.success('Flutter: $version');

        // Check Flutter version
        final versionMatch =
            RegExp(r'Flutter (\d+\.\d+\.\d+)').firstMatch(version);
        if (versionMatch != null) {
          final versionStr = versionMatch.group(1)!;
          final parts = versionStr.split('.').map(int.parse).toList();
          if (parts[0] < 3 || (parts[0] == 3 && parts[1] < 16)) {
            warnings.add(DoctorIssue(
              'Flutter version $versionStr is older than recommended 3.16+',
              fixHint: 'Run: flutter upgrade',
            ));
          }
        }
      } else {
        issues.add(DoctorIssue(
          'Flutter not found or not in PATH',
          fixHint:
              'Install Flutter: https://flutter.dev/docs/get-started/install',
        ));
      }
    } catch (e) {
      issues.add(DoctorIssue(
        'Flutter command failed: $e',
        fixHint: 'Ensure Flutter is installed and in PATH',
      ));
    }
  }

  Future<void> _checkDart(Logger logger, List<DoctorIssue> issues,
      List<DoctorIssue> warnings, bool fix) async {
    logger.progress('Checking Dart SDK...').complete();
    try {
      final result = await Process.run('dart', ['--version'], runInShell: true);
      if (result.exitCode == 0) {
        final version = result.stderr.toString().trim();
        logger.success('Dart: $version');
      } else {
        warnings.add(DoctorIssue(
            'Dart SDK not found separately (bundled with Flutter)'));
      }
    } catch (e) {
      warnings.add(DoctorIssue('Could not check Dart version: $e'));
    }
  }

  Future<void> _checkGit(Logger logger, List<DoctorIssue> issues,
      List<DoctorIssue> warnings, bool fix) async {
    logger.progress('Checking Git...').complete();
    try {
      final result = await Process.run('git', ['--version'], runInShell: true);
      if (result.exitCode == 0) {
        logger.success('Git: ${result.stdout.toString().trim()}');
        // Check git config
        final nameResult =
            await Process.run('git', ['config', 'user.name'], runInShell: true);
        final emailResult = await Process.run('git', ['config', 'user.email'],
            runInShell: true);
        if (nameResult.exitCode != 0 ||
            (nameResult.stdout.toString().trim().isEmpty)) {
          warnings.add(DoctorIssue(
            'Git user.name not configured',
            fixHint: 'Run: git config --global user.name "Your Name"',
          ));
        }
        if (emailResult.exitCode != 0 ||
            (emailResult.stdout.toString().trim().isEmpty)) {
          warnings.add(DoctorIssue(
            'Git user.email not configured',
            fixHint: 'Run: git config --global user.email "you@example.com"',
          ));
        }
      } else {
        issues.add(DoctorIssue(
          'Git not found',
          fixHint: 'Install Git: https://git-scm.com/',
        ));
      }
    } catch (e) {
      issues.add(DoctorIssue('Git check failed: $e'));
    }
  }

  Future<void> _checkIDEs(Logger logger, List<DoctorIssue> issues,
      List<DoctorIssue> warnings, bool fix) async {
    logger.progress('Checking IDEs...').complete();
    // Check Android Studio
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      final androidStudioPaths = <String>[
        if (Platform.isMacOS) '/Applications/Android Studio.app',
        if (Platform.isLinux) '/opt/android-studio',
        if (Platform.isWindows) 'C:\\Program Files\\Android\\Android Studio',
      ];

      var found = false;
      for (final p in androidStudioPaths) {
        if (await Directory(p).exists()) {
          found = true;
          break;
        }
      }
      if (found) {
        logger.success('Android Studio: Found');
      } else {
        warnings.add(DoctorIssue(
          'Android Studio not found in default location',
          fixHint:
              'Install Android Studio: https://developer.android.com/studio',
        ));
      }
    }
    // Check Xcode (macOS only)
    if (Platform.isMacOS) {
      try {
        final result =
            await Process.run('xcodebuild', ['-version'], runInShell: true);
        if (result.exitCode == 0) {
          final version = result.stdout.toString().split('\n').first;
          logger.success('Xcode: $version');
        } else {
          warnings.add(DoctorIssue(
            'Xcode not found or command line tools not installed',
            fixHint:
                'Install Xcode from App Store or run: xcode-select --install',
          ));
        }
      } catch (e) {
        warnings.add(DoctorIssue('Could not check Xcode: $e'));
      }
    }
    // Check VS Code
    try {
      final result = await Process.run('code', ['--version'], runInShell: true);
      if (result.exitCode == 0) {
        final version = result.stdout.toString().split('\n').first;
        logger.success('VS Code: $version');
        // Check Flutter extension
        final extResult =
            await Process.run('code', ['--list-extensions'], runInShell: true);
        if (extResult.exitCode == 0 &&
            extResult.stdout.toString().contains('dart-code.flutter')) {
          logger.success('Flutter Extension: Installed');
        } else {
          warnings.add(DoctorIssue(
            'Flutter extension not installed in VS Code',
            fixHint: 'Install from Extensions marketplace: Dart-Code.flutter',
          ));
        }
      } else {
        logger.detail('VS Code: Not installed (optional)');
      }
    } catch (_) {
      logger.detail('VS Code: Not installed (optional)');
    }
  }

  Future<void> _checkDevices(Logger logger, List<DoctorIssue> issues,
      List<DoctorIssue> warnings, bool fix) async {
    logger.progress('Checking connected devices...').complete();
    try {
      final result =
          await Process.run('flutter', ['devices'], runInShell: true);
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        if (output.contains('No devices found')) {
          warnings.add(DoctorIssue(
            'No devices connected',
            fixHint:
                'Connect a device/emulator or run: flutter emulators --launch <id>',
          ));
        } else {
          final deviceLines =
              output.split('\n').where((l) => l.contains('•')).toList();
          for (final line in deviceLines) {
            logger.success('Device: ${line.trim()}');
          }
        }
      } else {
        warnings.add(DoctorIssue('Could not list Flutter devices'));
      }
    } catch (e) {
      warnings.add(DoctorIssue('Device check failed: $e'));
    }
  }

  void _checkConfig(ConfigService config, Logger logger,
      List<DoctorIssue> issues, List<DoctorIssue> warnings) {
    logger.progress('Checking NinjaDev configuration...').complete();
    if (config.configPath != null) {
      logger.success('Config file: ${config.configPath}');
    } else {
      warnings.add(DoctorIssue(
        'No NinjaDev config found',
        fixHint: 'Run: ninjadev config init',
      ));
    }
    if (config.defaultTemplate.isEmpty) {
      warnings.add(DoctorIssue(
        'No default template configured',
        fixHint: 'Run: ninjadev config set template <template-name>',
      ));
    }
  }
}

class DoctorIssue {
  final String message;
  final String? fixHint;
  DoctorIssue(this.message, {this.fixHint});
}
