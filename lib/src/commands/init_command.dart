import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/commands/command.dart';
import 'package:ninjadev/src/services/config_service.dart';

class InitCommand extends BaseCommand {
  InitCommand()
      : super(
          name: 'init',
          description: 'Initialize NinjaDev configuration in current project',
          usage: '[options]',
        ) {
    parser
      ..addFlag('force',
          abbr: 'f', negatable: false, help: 'Overwrite existing configuration')
      ..addOption('template', abbr: 't', help: 'Template to initialize with')
      ..addFlag('yes',
          abbr: 'y', negatable: false, help: 'Skip prompts and use defaults');
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
    final skipPrompts = parsedArgs['yes'] as bool;
    if (await config.exists() && !force) {
      logger.warn('NinjaDev config already exists. Use --force to overwrite.');
      return;
    }
    final options = <String, dynamic>{
      'projectName': Directory.current.path.split(Platform.pathSeparator).last,
      'organization': 'com.example',
      'description': 'A NinjaDev Flutter project',
      'template': parsedArgs['template'] as String? ?? 'clean-architecture',
      'flutterVersion': '3.16.0',
      'platforms': ['ios', 'android', 'web'],
      'stateManagement': 'bloc',
      'architecture': 'clean-architecture',
      'dependencyInjection': 'get_it',
      'routing': 'go_router',
      'localization': 'flutter_localizations',
      'testing': ['flutter_test', 'mocktail', 'bloc_test'],
      'linting': 'very_good_analysis',
      'ci': 'github_actions',
      'analytics': 'firebase_analytics',
      'crashReporting': 'firebase_crashlytics',
    };
    if (!skipPrompts) {
      await _promptForOptions(options, logger);
    }
    final progress = logger.progress('Initializing NinjaDev configuration...');
    await config.create(options, force: force);
    progress.complete('NinjaDev initialized successfully!');
    logger.info('Config saved to: ${config.configPath}');
    logger.info('');
    logger.info('Next steps:');
    logger.info('  ninjadev create my_app    # Create a new project');
    logger.info('  ninjadev generate feature user  # Generate a feature');
    logger.info('  ninjadev doctor              # Check environment');
  }

  Future<void> _promptForOptions(
      Map<String, dynamic> options, Logger logger) async {
    // Interactive prompts would go here
    // For now, we'll use defaults
  }
}
