import 'package:args/args.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/commands/command.dart';
import 'package:ninjadev/src/services/config_service.dart';
import 'package:ninjadev/src/services/template_server_service.dart';

class TemplateCommand extends BaseCommand {
  TemplateCommand()
      : super(
          name: 'template',
          description: 'Manage project templates',
          usage: '<subcommand> [options]',
        ) {
    parser
      ..addCommand('list', _listParser())
      ..addCommand('add', _addParser())
      ..addCommand('remove', _removeParser())
      ..addCommand('update', _updateParser())
      ..addCommand('info', _infoParser())
      ..addCommand('create', _createParser());
  }
  ArgParser _listParser() => ArgParser()
    ..addFlag('help',
        negatable: false, abbr: 'h', help: 'Show help for template list')
    ..addFlag('all',
        abbr: 'a',
        negatable: false,
        help: 'Show all templates including remote')
    ..addFlag('installed',
        abbr: 'i', negatable: false, help: 'Show only installed templates');
  ArgParser _addParser() => ArgParser()
    ..addFlag('help',
        negatable: false, abbr: 'h', help: 'Show help for template add')
    ..addOption('name', abbr: 'n', help: 'Template name')
    ..addOption('git', abbr: 'g', help: 'Git repository URL')
    ..addOption('path', abbr: 'p', help: 'Local path to template');
  ArgParser _removeParser() => ArgParser()
    ..addFlag('help',
        negatable: false, abbr: 'h', help: 'Show help for template remove');
  ArgParser _updateParser() => ArgParser()
    ..addFlag('help',
        negatable: false, abbr: 'h', help: 'Show help for template update')
    ..addFlag('all', negatable: false, abbr: 'a', help: 'Update all templates');
  ArgParser _infoParser() => ArgParser()
    ..addFlag('help',
        negatable: false, abbr: 'h', help: 'Show help for template info');
  ArgParser _createParser() => ArgParser()
    ..addFlag('help',
        negatable: false, abbr: 'h', help: 'Show help for template create')
    ..addOption('name', abbr: 'n', help: 'Template name')
    ..addOption('description', abbr: 'd', help: 'Template description')
    ..addOption('output', abbr: 'o', help: 'Output directory');
  @override
  Future<void> run(
      List<String> args, ConfigService config, Logger logger) async {
    final parsedArgs = parser.parse(args);

    if (parsedArgs['help'] as bool) {
      printUsage(logger);
      return;
    }
    final subcommand = parsedArgs.command?.name ?? 'list';
    final templateService = TemplateServerService(config, logger);
    switch (subcommand) {
      case 'list':
        await _handleList(parsedArgs.command!, templateService, logger);
        break;
      case 'add':
        await _handleAdd(parsedArgs.command!, templateService, logger);
        break;
      case 'remove':
        await _handleRemove(parsedArgs.command!, templateService, logger);
        break;
      case 'update':
        await _handleUpdate(parsedArgs.command!, templateService, logger);
        break;
      case 'info':
        await _handleInfo(parsedArgs.command!, templateService, logger);
        break;
      case 'create':
        await _handleCreate(parsedArgs.command!, templateService, logger);
        break;
      default:
        logger.err('Unknown template subcommand: $subcommand');
        printUsage(logger);
    }
  }

  Future<void> _handleList(
      ArgResults results, TemplateServerService service, Logger logger) async {
    final showAll = results['all'] as bool;
    final showInstalled = results['installed'] as bool;
    final fetching = logger.progress('Fetching templates...');
    final allTemplates = await service.listTemplates(includeRemote: showAll);
    fetching.complete();
    final templates = showInstalled
        ? allTemplates.where((t) => t.installed).toList()
        : allTemplates;
    logger.info('');
    logger.info('Available Templates:');
    for (final template in templates) {
      final status = template.installed ? '[installed]' : '[remote]';
      logger.info(
          '  ${status.padRight(11)} ${template.name} - ${template.description}');
      if (template.version != null) {
        logger.detail('      Version: ${template.version}');
      }
      if (template.tags.isNotEmpty) {
        logger.detail('      Tags: ${template.tags.join(', ')}');
      }
    }
    if (templates.isEmpty) {
      logger.info(
          '  No templates found. Run "ninjadev template add" to add one.');
    }
  }

  Future<void> _handleAdd(
      ArgResults results, TemplateServerService service, Logger logger) async {
    final name = results['name'] as String?;
    final gitUrl = results['git'] as String?;
    final localPath = results['path'] as String?;
    if (name == null || (gitUrl == null && localPath == null)) {
      logger.err('Template name and source (git or path) are required');
      logger.info(
          'Usage: ninjadev template add --name <name> --git <url> [--path <path>]');
      return;
    }
    final progress = logger.progress('Adding template $name...');
    await service.addTemplate(name, gitUrl: gitUrl, localPath: localPath);
    progress.complete('Template $name added successfully');
  }

  Future<void> _handleRemove(
      ArgResults results, TemplateServerService service, Logger logger) async {
    if (results.rest.isEmpty) {
      logger.err('Template name is required');
      return;
    }
    final name = results.rest.first;
    final progress = logger.progress('Removing template $name...');
    await service.removeTemplate(name);
    progress.complete('Template $name removed');
  }

  Future<void> _handleUpdate(
      ArgResults results, TemplateServerService service, Logger logger) async {
    final updateAll = results['all'] as bool;
    if (updateAll) {
      final progress = logger.progress('Updating all templates...');
      await service.updateAllTemplates();
      progress.complete('All templates updated');
    } else if (results.rest.isNotEmpty) {
      final name = results.rest.first;
      final progress = logger.progress('Updating template $name...');
      await service.updateTemplate(name);
      progress.complete('Template $name updated');
    } else {
      logger.err('Template name or --all flag is required');
    }
  }

  Future<void> _handleInfo(
      ArgResults results, TemplateServerService service, Logger logger) async {
    if (results.rest.isEmpty) {
      logger.err('Template name is required');
      return;
    }
    final name = results.rest.first;
    final template = await service.getTemplateInfo(name);
    if (template == null) {
      logger.err('Template not found: $name');
      return;
    }
    logger.info('Template: ${template.name}');
    logger.info('Description: ${template.description}');
    logger.info('Version: ${template.version ?? 'N/A'}');
    logger.info('Author: ${template.author ?? 'N/A'}');
    logger.info('License: ${template.license ?? 'N/A'}');
    logger.info('Installed: ${template.installed ? 'Yes' : 'No'}');
    logger.info('Source: ${template.source}');
    if (template.tags.isNotEmpty) {
      logger.info('Tags: ${template.tags.join(', ')}');
    }
    if (template.variables.isNotEmpty) {
      logger.info('Variables:');
      for (final variable in template.variables) {
        logger.detail(
            '  ${variable.name} (${variable.type}): ${variable.description}');
        if (variable.defaultValue != null) {
          logger.detail('    Default: ${variable.defaultValue}');
        }
      }
    }
  }

  Future<void> _handleCreate(
      ArgResults results, TemplateServerService service, Logger logger) async {
    final name = results['name'] as String?;
    final description = results['description'] as String?;
    final output = results['output'] as String?;
    if (name == null) {
      logger.err('Template name is required (--name)');
      return;
    }
    final progress = logger.progress('Creating template scaffold...');
    await service.createTemplateScaffold(name,
        description: description, outputDir: output);
    progress.complete('Template scaffold created');
    logger.info('Edit the template files in the output directory, then run:');
    logger.info('  ninjadev template add --name $name --path <output-dir>');
  }
}
