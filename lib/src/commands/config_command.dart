import 'dart:io';
import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/commands/command.dart';
import 'package:ninjadev/src/services/config_service.dart';

class ConfigCommand extends BaseCommand {
  ConfigCommand() : super(
    name: 'config',
    description: 'Manage NinjaDev configuration',
    usage: '<subcommand> [options]',
  ) {
    parser
      ..addCommand('get', _getParser())
      ..addCommand('set', _setParser())
      ..addCommand('list', _listParser())
      ..addCommand('init', _initParser())
      ..addCommand('reset', _resetParser())
      ..addCommand('edit', _editParser());
  }
  ArgParser _getParser() => ArgParser()
    ..addFlag('help', negatable: false, abbr: 'h', help: 'Show help for config get');
  ArgParser _setParser() => ArgParser()
    ..addFlag('help', negatable: false, abbr: 'h', help: 'Show help for config set')
    ..addFlag('global', negatable: false, abbr: 'g', help: 'Set global config');
  ArgParser _listParser() => ArgParser()
    ..addFlag('help', negatable: false, abbr: 'h', help: 'Show help for config list');
  ArgParser _initParser() => ArgParser()
    ..addFlag('help', negatable: false, abbr: 'h', help: 'Show help for config init')
    ..addFlag('force', negatable: false, abbr: 'f', help: 'Overwrite existing config');
  ArgParser _resetParser() => ArgParser()
    ..addFlag('help', negatable: false, abbr: 'h', help: 'Show help for config reset')
    ..addFlag('force', negatable: false, abbr: 'f', help: 'Force reset without confirmation');
  ArgParser _editParser() => ArgParser()
    ..addFlag('help', negatable: false, abbr: 'h', help: 'Show help for config edit');
  @override
  Future<void> run(List<String> args, ConfigService config, Logger logger) async {
    final parsedArgs = parser.parse(args);
    
    if (parsedArgs['help'] as bool) {
      printUsage(logger);
      return;
    }
    final subcommand = parsedArgs.command?.name ?? 'list';
    switch (subcommand) {
      case 'get':
        await _handleGet(parsedArgs.command!, config, logger);
        break;
      case 'set':
        await _handleSet(parsedArgs.command!, config, logger);
        break;
      case 'list':
        await _handleList(config, logger);
        break;
      case 'init':
        await _handleInit(parsedArgs.command!, config, logger);
        break;
      case 'reset':
        await _handleReset(parsedArgs.command!, config, logger);
        break;
      case 'edit':
        await _handleEdit(config, logger);
        break;
      default:
        logger.err('Unknown config subcommand: $subcommand');
        printUsage(logger);
    }
  }

  Future<void> _handleGet(ArgResults results, ConfigService config, Logger logger) async {
    if (results.rest.isEmpty) {
      logger.err('Config key is required');
      return;
    }
    final key = results.rest.first;
    final value = config.get(key);
    if (value != null) {
      logger.info('$key = $value');
    } else {
      logger.warn('Config key not found: $key');
    }
  }

  Future<void> _handleSet(ArgResults results, ConfigService config, Logger logger) async {
    if (results.rest.length < 2) {
      logger.err('Usage: ninjadev config set <key> <value>');
      return;
    }
    final key = results.rest[0];
    final value = results.rest[1];
    final global = results['global'] as bool;
    await config.set(key, value, global: global);
    logger.success('Set $key = $value');
  }

  Future<void> _handleList(ConfigService config, Logger logger) async {
    final allConfig = config.all;
    if (allConfig.isEmpty) {
      logger.info('No configuration set. Run "ninjadev config init" to create one.');
      return;
    }
    logger.info('NinjaDev Configuration:');
    logger.info('');
    final sections = <String, Map<String, dynamic>>{
      'Project': {},
      'Templates': {},
      'Generators': {},
      'Features': {},
      'Other': {},
    };
    for (final entry in allConfig.entries) {
      final key = entry.key;
      if (key.startsWith('project.')) {
        sections['Project']![key] = entry.value;
      } else if (key.startsWith('template.')) {
        sections['Templates']![key] = entry.value;
      } else if (key.startsWith('generator.')) {
        sections['Generators']![key] = entry.value;
      } else if (key.startsWith('feature.')) {
        sections['Features']![key] = entry.value;
      } else {
        sections['Other']![key] = entry.value;
      }
    }
    for (final section in sections.entries) {
      if (section.value.isNotEmpty) {
        logger.detail('${section.key}:');
        for (final entry in section.value.entries) {
          logger.detail('  ${entry.key} = ${entry.value}');
        }
        logger.info('');
      }
    }
  }

  Future<void> _handleInit(ArgResults results, ConfigService config, Logger logger) async {
    final force = results['force'] as bool;
    if (await config.exists() && !force) {
      logger.warn('Config file already exists. Use --force to overwrite.');
      return;
    }
    await config.initDefaults();
    logger.success('Created default NinjaDev configuration');
    logger.info('Config file: ${config.configPath}');
  }

  Future<void> _handleReset(ArgResults results, ConfigService config, Logger logger) async {
    final force = results['force'] as bool;
    if (!force) {
      logger.info('This will reset all config to defaults. Continue? (y/N)');
      final input = stdin.readLineSync()?.trim().toLowerCase() ?? '';
      if (input != 'y' && input != 'yes') {
        logger.info('Cancelled');
        return;
      }
    }
    await config.reset();
    logger.success('Configuration reset to defaults');
  }

  Future<void> _handleEdit(ConfigService config, Logger logger) async {
    final editor = Platform.environment['EDITOR'] ?? 'code';
    final configPath = config.configPath ?? await config.getDefaultConfigPath();
    try {
      await Process.run(editor, [configPath], runInShell: true);
      logger.success('Opened config in editor');
      await config.reload();
    } catch (e) {
      logger.err('Failed to open editor: $e');
      logger.info('Config file: $configPath');
    }
  }
}
