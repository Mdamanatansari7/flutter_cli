import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/commands/command.dart';
import 'package:ninjadev/src/services/config_service.dart';
import 'package:ninjadev/src/utils/ui.dart';

/// Where NinjaDev is published. `upgrade` installs the latest `main` from
/// here — the same way NinjaDev is installed in the first place.
const String ninjadevRepository =
    'https://github.com/Mdamanatansari7/flutter_cli';

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

    final progress = logger.progress('Checking for updates...');
    final latest = await _latestVersion();
    progress.complete();
    const current = NinjaUI.version;
    if (latest == null) {
      logger.warn('Could not reach $ninjadevRepository to check for updates.');
    } else if (latest == current) {
      logger.success('NinjaDev is up to date (v$current)');
    } else {
      logger.info('Update available: v$current → v$latest');
    }
    if (parsedArgs['check'] as bool) return;
    if (latest == current && !force) return;

    if (!force && await _isLocalInstall()) {
      logger.warn(
          'NinjaDev is installed from a local folder (a development install) — '
          'pull the latest code there, or run "ninjadev upgrade --force" to '
          'switch to the GitHub version.');
      return;
    }

    logger.info('Installing the latest NinjaDev from GitHub...');
    final process = await Process.start(
      'dart',
      ['pub', 'global', 'activate', '--source', 'git', '$ninjadevRepository.git'],
      runInShell: true,
      mode: ProcessStartMode.inheritStdio,
    );
    if (await process.exitCode == 0) {
      logger.success(
          'NinjaDev upgraded${latest == null ? '' : ' to v$latest'}');
    } else {
      logger.err('Upgrade failed. Try: dart pub global activate --source git '
          '$ninjadevRepository.git');
    }
  }

  /// The `version:` in pubspec.yaml on GitHub's main branch, or null when
  /// it can't be fetched.
  Future<String?> _latestVersion() async {
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

  /// Whether `dart pub global` has NinjaDev activated from a local folder.
  Future<bool> _isLocalInstall() async {
    final result =
        await Process.run('dart', ['pub', 'global', 'list'], runInShell: true);
    return RegExp(r'^ninjadev \S+ at path', multiLine: true)
        .hasMatch(result.stdout.toString());
  }
}
