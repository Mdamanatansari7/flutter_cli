import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/commands/command.dart';
import 'package:ninjadev/src/services/config_service.dart';

class DeployCommand extends BaseCommand {
  DeployCommand()
      : super(
          name: 'deploy',
          description: 'Build a Flutter release for deployment',
          usage: '[options]',
        ) {
    parser
      ..addOption(
        'platform',
        abbr: 'p',
        defaultsTo: 'web',
        allowed: ['web', 'apk', 'appbundle', 'ios', 'macos'],
        help: 'Release platform to build',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help: 'Show the Flutter build command without running it',
      );
  }

  @override
  Future<void> run(
      List<String> args, ConfigService config, Logger logger) async {
    final parsedArgs = parser.parse(args);
    if (parsedArgs['help'] as bool) {
      printUsage(logger);
      return;
    }

    final platform = parsedArgs['platform'] as String;
    final command = ['build', platform, '--release'];
    logger.info('Deployment target: $platform');
    logger.info('Command: flutter ${command.join(' ')}');
    if (parsedArgs['dry-run'] as bool) return;

    final progress = logger.progress('Building $platform release...');
    try {
      final result = await Process.run('flutter', command, runInShell: true);
      if (result.exitCode == 0) {
        progress.complete('Release build ready for $platform');
      } else {
        progress.fail('Build failed: ${result.stderr}');
      }
    } catch (error) {
      progress.fail('Could not run Flutter: $error');
    }
  }
}
