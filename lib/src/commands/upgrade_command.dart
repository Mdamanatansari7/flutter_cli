import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/commands/command.dart';
import 'package:ninjadev/src/services/config_service.dart';
import 'package:ninjadev/src/utils/ui.dart';

/// Where NinjaDev's source lives. Git installs upgrade from `main` here.
const String ninjadevRepository =
    'https://github.com/Mdamanatansari7/flutter_cli';

/// How NinjaDev is installed, which decides where `upgrade` gets it from.
enum _InstallSource { pubDev, git, localPath }

class UpgradeCommand extends BaseCommand {
  UpgradeCommand()
      : super(
          name: 'upgrade',
          description: 'Upgrade NinjaDev to the latest version',
          usage: '[options]',
        ) {
    parser
      ..addFlag('check',
          negatable: false,
          abbr: 'c',
          help: 'Check for updates without installing')
      ..addFlag('force',
          negatable: false,
          abbr: 'f',
          help:
              'Reinstall even if up to date, or replace a local development install');
  }

  @override
  Future<void> run(
      List<String> args, ConfigService config, Logger logger) async {
    final parsedArgs = parser.parse(args);

    if (parsedArgs['help'] as bool) {
      printUsage(logger);
      return;
    }
    final force = parsedArgs['force'] as bool;

    final source = await _installSource();
    final progress = logger.progress('Checking for updates...');
    final latest = source == _InstallSource.pubDev
        ? await _latestPubDevVersion()
        : await _latestGitVersion();
    progress.complete();
    const current = NinjaUI.version;
    if (latest == null) {
      logger.warn('Could not check for updates right now.');
    } else if (latest == current) {
      logger.success('NinjaDev is up to date (v$current)');
    } else {
      logger.info('Update available: v$current → v$latest');
    }
    if (parsedArgs['check'] as bool) return;
    if (latest == current && !force) return;

    if (source == _InstallSource.localPath && !force) {
      logger.warn(
          'NinjaDev is installed from a local folder (a development install) — '
          'pull the latest code there, or run "ninjadev upgrade --force" to '
          'switch to the GitHub version.');
      return;
    }

    final activate = source == _InstallSource.pubDev
        ? ['pub', 'global', 'activate', 'ninjadev']
        : [
            'pub',
            'global',
            'activate',
            '--source',
            'git',
            '$ninjadevRepository.git'
          ];
    logger.info('Installing the latest NinjaDev...');
    final process = await Process.start('dart', activate,
        runInShell: true, mode: ProcessStartMode.inheritStdio);
    if (await process.exitCode == 0) {
      logger
          .success('NinjaDev upgraded${latest == null ? '' : ' to v$latest'}');
    } else {
      logger.err('Upgrade failed. Try: dart ${activate.join(' ')}');
    }
  }

  /// Reads `dart pub global list`: a local checkout shows "at path", a
  /// GitHub install "from Git repository", a pub.dev install just the
  /// version. Anything unrecognised is treated as a GitHub install.
  Future<_InstallSource> _installSource() async {
    try {
      final result = await Process.run('dart', ['pub', 'global', 'list'],
          runInShell: true);
      final line = RegExp(r'^ninjadev \S+.*$', multiLine: true)
              .stringMatch(result.stdout.toString()) ??
          '';
      if (line.contains(' at path ')) return _InstallSource.localPath;
      if (line.isEmpty || line.contains(' from Git repository ')) {
        return _InstallSource.git;
      }
      return _InstallSource.pubDev;
    } catch (_) {
      return _InstallSource.git;
    }
  }

  /// The latest version published on pub.dev, or null.
  Future<String?> _latestPubDevVersion() async {
    try {
      final response = await http
          .get(Uri.parse('https://pub.dev/api/packages/ninjadev'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['latest'] as Map<String, dynamic>?)?['version'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// The `version:` in pubspec.yaml on GitHub's main branch, or null.
  Future<String?> _latestGitVersion() async {
    try {
      final repoPath = Uri.parse(ninjadevRepository).path;
      final response = await http
          .get(Uri.parse(
              'https://raw.githubusercontent.com$repoPath/main/pubspec.yaml'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      return RegExp(r'^version:\s*(\S+)', multiLine: true)
          .firstMatch(response.body)
          ?.group(1);
    } catch (_) {
      return null;
    }
  }
}
