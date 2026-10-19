import 'package:mason_logger/mason_logger.dart';

import 'package:ninjadev/src/commands/command.dart';
import 'package:ninjadev/src/services/config_service.dart';
import 'package:ninjadev/src/services/project_service.dart'
    show ProjectService, CreateOptions;

class CreateCommand extends BaseCommand {
  CreateCommand()
      : super(
          name: 'create',
          description: 'Create a new Flutter project with NinjaDev',
          usage: '[project-name] [options]',
        ) {
    parser
      ..addOption('org',
          abbr: 'o', help: 'Organization name (e.g., com.example)')
      ..addOption('description', abbr: 'd', help: 'Project description')
      ..addFlag('no-git', negatable: false, help: 'Skip git initialization')
      ..addFlag('no-pub-get', negatable: false, help: 'Skip flutter pub get')
      ..addOption('template',
          abbr: 't', help: 'Project template (default: clean-architecture)')
      ..addOption('org-name', help: 'Organization name for package naming')
      ..addFlag('yes',
          abbr: 'y', negatable: false, help: 'Skip prompts and use defaults')
      ..addFlag('offline', negatable: false, help: 'Use offline mode')
      ..addOption('flutter-version', help: 'Flutter version to use')
      ..addOption('platform', help: 'Target platforms (comma-separated)')
      ..addOption(
        'orientation',
        allowed: ['portrait', 'landscape', 'both'],
        defaultsTo: 'portrait',
        help: 'Device orientation lock for the generated app',
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
    final isVerbose = parsedArgs['verbose'] as bool;
    String? projectName;
    if (parsedArgs.rest.isNotEmpty) projectName = parsedArgs.rest.first;
    final options = CreateOptions(
      projectName: projectName,
      organization: parsedArgs['org'] as String?,
      description: parsedArgs['description'] as String?,
      initGit: !(parsedArgs['no-git'] as bool),
      runPubGet: !(parsedArgs['no-pub-get'] as bool),
      template: parsedArgs['template'] as String? ?? config.defaultTemplate,
      orgName: parsedArgs['org-name'] as String?,
      skipPrompts: parsedArgs['yes'] as bool,
      offline: parsedArgs['offline'] as bool,
      flutterVersion: parsedArgs['flutter-version'] as String?,
      platforms: (parsedArgs['platform'] as String?)
          ?.split(',')
          .map((e) => e.trim())
          .toList(),
      orientation: parsedArgs['orientation'] as String?,
    );
    final projectService = ProjectService(logger, isVerbose);
    await projectService.createProject(options);
  }
}
