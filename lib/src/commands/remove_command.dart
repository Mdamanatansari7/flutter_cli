import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/commands/command.dart';
import 'package:ninjadev/src/services/config_service.dart';
import 'package:ninjadev/src/services/package_service.dart';

class RemoveCommand extends BaseCommand {
  RemoveCommand()
      : super(
          name: 'remove',
          description: 'Remove packages from pubspec.yaml',
          usage: '<package> [options]',
        ) {
    parser.addFlag('dev',
        abbr: 'd', negatable: false, help: 'Remove from dev dependencies');
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
    if (parsedArgs.rest.isEmpty) {
      logger.err('Package name is required');
      return;
    }
    final packageService = PackageService(logger);
    for (final pkg in parsedArgs.rest) {
      await packageService.removePackage(pkg, dev: dev);
    }
  }
}
