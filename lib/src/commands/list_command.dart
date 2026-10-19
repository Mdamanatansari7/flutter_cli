import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/commands/command.dart';
import 'package:ninjadev/src/services/config_service.dart';

class ListCommand extends BaseCommand {
  ListCommand() : super(
    name: 'list',
    description: 'List available templates, packages, and generators',
    usage: '<type> [options]',
  ) {
    parser.addFlag('installed', abbr: 'i', negatable: false, help: 'Show only installed items');
  }
  @override
  Future<void> run(List<String> args, ConfigService config, Logger logger) async {
    final parsedArgs = parser.parse(args);
    if (parsedArgs['help'] as bool) {
      printUsage(logger);
      return;
    }
    final type = parsedArgs.rest.isNotEmpty ? parsedArgs.rest.first : 'help';
    switch (type) {
      case 'templates':
        await _listTemplates(config, logger);
        break;
      case 'packages':
        await _listPackages(config, logger);
        break;
      case 'generators':
        await _listGenerators(config, logger);
        break;
      case 'features':
        await _listFeatures(config, logger);
        break;
      case 'help':
      default:
        logger.info('Available list types:');
        logger.info('  templates    List available templates');
        logger.info('  packages     List available packages');
        logger.info('  generators   List available generators');
        logger.info('  features     List existing features');
        logger.info('');
        logger.info('Usage: ninjadev list <type>');
        break;
    }
  }

  Future<void> _listTemplates(ConfigService config, Logger logger) async {
    logger.info('Available Templates:');
    logger.info('');
    logger.info('  clean-architecture     Clean Architecture template');
    logger.info('  feature-first         Feature-first architecture template');
    logger.info('  mvc                   MVC architecture template');
    logger.info('  mvvm                  MVVM architecture template');
    final installed = config.get('templates.installed') as List<dynamic>?;
    if (installed != null && installed.isNotEmpty) {
      logger.info('Installed Custom Templates:');
      for (final t in installed) {
        logger.info('  - $t');
      }
    }
  }

  Future<void> _listPackages(ConfigService config, Logger logger) async {
    logger.info('Available Package Categories:');
    logger.info('Network:');
    logger.info('  dio, retrofit, graphql_flutter, http, chopper');
    logger.info('State Management:');
    logger.info('  provider, riverpod, flutter_bloc, get_it, injectable');
    logger.info('Routing:');
    logger.info('  go_router, auto_route, fluro, beamer');
    logger.info('Storage:');
    logger.info('  hive, isar, sqflite, drift, shared_preferences');
    logger.info('Firebase:');
    logger.info('  firebase_core, firebase_auth, cloud_firestore, firebase_storage, firebase_messaging, firebase_crashlytics');
    logger.info('UI:');
    logger.info('  flutter_svg, cached_network_image, shimmer, lottie, google_fonts');
    logger.info('Utilities:');
    logger.info('  permission_handler, url_launcher, connectivity_plus, device_info_plus, package_info_plus');
  }

  Future<void> _listGenerators(ConfigService config, Logger logger) async {
    logger.info('Available Generators:');
    logger.info('  feature     Generate a feature (controller, view, model, etc.)');
    logger.info('  widget      Generate a reusable widget');
    logger.info('  model       Generate a data model from JSON');
    logger.info('  api         Generate an API service');
    logger.info('  theme       Generate theme system');
    logger.info('  screen      Generate a screen/page');
    logger.info('  repository  Generate a repository');
    logger.info('  bloc        Generate a Bloc');
    logger.info('  cubit       Generate a Cubit');
    logger.info('  provider    Generate a Provider');
    logger.info('  controller  Generate a Controller');
    logger.info('  service     Generate a service');
    logger.info('Usage: ninjadev generate <type> <name>');
  }

  Future<void> _listFeatures(ConfigService config, Logger logger) async {
    final libDir = Directory('lib');
    if (!await libDir.exists()) {
      logger.warn('No lib directory found. Run this command from a Flutter project root.');
      return;
    }
    final featuresDir = Directory('lib/features');
    if (!await featuresDir.exists()) {
      logger.info('No features found. Run "ninjadev generate feature <name>" to create one.');
      return;
    }
    logger.info('Features:');
    await for (final entity in featuresDir.list()) {
      if (entity is Directory) {
        final name = entity.path.split('/').last;
        logger.info('  - $name');
      }
    }
  }
}
