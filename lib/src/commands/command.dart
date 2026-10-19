
import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/services/config_service.dart';

abstract class BaseCommand {
  late final ArgParser parser;
  final String name;
  final String description;
  final String? usage;
  BaseCommand({
    required this.name,
    required this.description,
    this.usage,
  }) {
    parser = ArgParser(allowTrailingOptions: true)
      ..addFlag('help', negatable: false, abbr: 'h', help: 'Show help for $name command')
      ..addFlag('verbose', negatable: false, abbr: 'v', help: 'Verbose output');
    addCustomArgs();
  }
  void addCustomArgs() {}
  Future<void> run(List<String> args, ConfigService config, Logger logger);
  void printUsage(Logger logger) {
    logger.info('Usage: ninjadev $name ${usage ?? '[arguments]'}');
    logger.info('');
    logger.info(description);
    logger.info('Options:');
    logger.info(parser.usage);
  }
}
