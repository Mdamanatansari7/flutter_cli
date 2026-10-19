import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/commands/command.dart';
import 'package:ninjadev/src/services/config_service.dart';
import 'package:ninjadev/src/services/package_service.dart';

class AddCommand extends BaseCommand {
  AddCommand()
      : super(
          name: 'add',
          description: 'Add packages to pubspec.yaml',
          usage: '<package> [options]',
        ) {
    parser
      ..addFlag('dev',
          abbr: 'd', negatable: false, help: 'Add as dev dependency')
      ..addOption('version', help: 'Package version constraint')
      ..addFlag('yes',
          abbr: 'y', negatable: false, help: 'Skip prompts and use defaults')
      ..addFlag('interactive',
          abbr: 'i', negatable: false, help: 'Interactive package selection');
  }
  @override
  Future<void> run(
      List<String> args, ConfigService config, Logger logger) async {
    final parsedArgs = parser.parse(args);

    if (parsedArgs['help'] as bool) {
      printUsage(logger);
      return;
    }
    final dev = parsedArgs['dev'] as bool;
    final version = parsedArgs['version'] as String?;
    final skipPrompts = parsedArgs['yes'] as bool;
    final interactive = parsedArgs['interactive'] as bool;
    final packageService = PackageService(logger);
    if (interactive) {
      await packageService.interactiveAdd(dev: dev);
    } else if (parsedArgs.rest.isEmpty) {
      if (skipPrompts) {
        logger.info('No package specified — nothing to add.');
      } else {
        await packageService.interactiveAdd(dev: dev);
      }
    } else {
      for (final pkg in parsedArgs.rest) {
        await packageService.addPackage(pkg, version: version, dev: dev);
      }
    }
  }
}
