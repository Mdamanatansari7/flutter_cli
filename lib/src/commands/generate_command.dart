import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/commands/command.dart';
import 'package:ninjadev/src/services/config_service.dart';
import 'package:ninjadev/src/services/generate_service.dart';

class GenerateCommand extends BaseCommand {
  GenerateCommand()
      : super(
          name: 'generate',
          description:
              'Generate code files (features, screens, widgets, blocs, models, etc.)',
          usage: '<type> [name] [options]',
        ) {
    parser
      ..addOption('feature', abbr: 'f', help: 'Feature name to generate into')
      ..addOption('path', abbr: 'p', help: 'Custom output path')
      ..addFlag('yes',
          abbr: 'y', negatable: false, help: 'Skip prompts and use defaults')
      ..addFlag('dry-run',
          negatable: false, help: 'Preview files without creating them')
      ..addOption('template', abbr: 't', help: 'Custom template to use')
      ..addOption(
        'orientation',
        allowed: ['portrait', 'landscape'],
        help: 'Which settings-page variant to generate',
      )
      ..addOption(
        'setup',
        allowed: ['local', 'online'],
        help: 'Which settings-page variant to generate',
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
    if (parsedArgs.rest.isEmpty) {
      logger.err(
          'Generate type is required. Use: ninjadev generate <type> [name]');
      return;
    }
    final type = parsedArgs.rest[0];
    final name = parsedArgs.rest.length > 1 ? parsedArgs.rest[1] : null;
    final options = GenerateOptions(
      type: type,
      name: name,
      feature: parsedArgs['feature'] as String?,
      path: parsedArgs['path'] as String?,
      skipPrompts: parsedArgs['yes'] as bool,
      dryRun: parsedArgs['dry-run'] as bool,
      template: parsedArgs['template'] as String?,
      orientation: parsedArgs['orientation'] as String?,
      setup: parsedArgs['setup'] as String?,
    );
    final generateService = GenerateService(config, logger);
    await generateService.generate(options);
  }
}

class GenerateOptions {
  final String type;
  final String? name;
  final String? feature;
  final String? path;
  final bool skipPrompts;
  final bool dryRun;
  final String? template;
  final String? orientation;
  final String? setup;
  GenerateOptions({
    required this.type,
    this.name,
    this.feature,
    this.path,
    this.skipPrompts = false,
    this.dryRun = false,
    this.template,
    this.orientation,
    this.setup,
  });
}
