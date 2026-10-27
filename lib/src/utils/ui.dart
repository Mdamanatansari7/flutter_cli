import 'dart:async';
import 'dart:io';

import 'package:interact/interact.dart'
    show Input, Theme, ValidationError, reset;
import 'package:mason_logger/mason_logger.dart'
    show darkGray, green, lightBlue, lightGreen, red, styleBold, white;
import 'package:ninjadev/src/generators/http_function_generator.dart'
    show HeaderValue;
import 'package:ninjadev/src/services/github_accounts.dart' show GithubAccounts;
import 'package:ninjadev/src/utils/terminal_menu.dart';
import 'package:ninjadev/src/validators/project_validator.dart';

/// Terminal UI for NinjaDev: the NINJADEV logo banner, styled help
/// output and the green interactive menus.
class NinjaUI {
  NinjaUI._();

  /// Single source of truth for the CLI version string.
  static const String version = '1.2.0';

  static const List<String> _logo = [
    '███╗   ██╗██╗███╗   ██╗     ██╗ █████╗ ██████╗ ███████╗██╗   ██╗',
    '████╗  ██║██║████╗  ██║     ██║██╔══██╗██╔══██╗██╔════╝██║   ██║',
    '██╔██╗ ██║██║██╔██╗ ██║     ██║███████║██║  ██║█████╗  ██║   ██║',
    '██║╚██╗██║██║██║╚██╗██║██   ██║██╔══██║██║  ██║██╔══╝  ╚██╗ ██╔╝',
    '██║ ╚████║██║██║ ╚████║╚█████╔╝██║  ██║██████╔╝███████╗ ╚████╔╝ ',
    '╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚════╝ ╚═╝  ╚═╝╚═════╝ ╚══════╝  ╚═══╝  ',
  ];

  // Bright-lime to deep-green gradient (xterm 256-color codes), one per row.
  static const List<int> _gradient = [118, 84, 48, 41, 35, 29];

  static bool get _ansi => stdout.supportsAnsiEscapes;

  static String _shade(String text, int color) =>
      _ansi ? '\x1B[38;5;${color}m$text\x1B[0m' : text;

  static String _g(String text) => lightGreen.wrap(text)!;
  static String _gb(String text) => styleBold.wrap(lightGreen.wrap(text))!;
  static String _dim(String text) => darkGray.wrap(text)!;
  static String _bold(String text) => styleBold.wrap(white.wrap(text))!;

  // Sky blue — used for whatever is currently selected/highlighted, so
  // it stands out from the rest of the green UI. Uses mason_logger's
  // standard 16-color `lightBlue` (the exact same wrap mechanism as the
  // proven-working `_g`/lightGreen).
  static String _sky(String text) => lightBlue.wrap(text)!;

  static String _pink(String text) => _shade(text, 213);

  static void printTree(String title, List<String> entries) {
    stdout.writeln();
    stdout.writeln('  ${_gb(title)}');
    stdout.writeln('  ${_pink('│')}');
    for (var i = 0; i < entries.length; i++) {
      final isLast = i == entries.length - 1;
      final connector = isLast ? '└── ' : '├── ';
      stdout.writeln('  ${_pink(connector + entries[i])}');
    }
    stdout.writeln();
  }

  /// Theme used by text prompts (`Input`) — the menu selectors below
  /// use [TerminalMenu] instead, see its doc comment for why.
  static Theme get greenTheme => Theme.colorfulTheme.copyWith(
        inputPrefix: _g('?'),
        inputSuffix: _dim('›'),
        successPrefix: _g('✔'),
        messageStyle: _bold,
        valueStyle: _sky,
        hintStyle: _dim,
      );

  static StreamSubscription<ProcessSignal>? _sigintSubscription;

  /// Restores the terminal if the user hits Ctrl-C inside a prompt.
  static void guardTerminal() {
    _sigintSubscription ??= ProcessSignal.sigint.watch().listen((_) {
      reset();
      stdout.writeln();
      exit(130);
    });
  }

  /// Prints the NINJADEV logo with a green gradient.
  static void printBanner() {
    stdout.writeln();
    for (var i = 0; i < _logo.length; i++) {
      stdout.writeln('  ${_shade(_logo[i], _gradient[i])}');
    }
    stdout.writeln();
    stdout.writeln(
        '  ${_bold('Flutter Developer Productivity CLI')}  ${_dim('•')}  ${_g('v$version')}');
    stdout.writeln('  ${_dim('─' * 64)}');
  }

  /// Prints the full styled help screen (banner + usage).
  static void printUsage() {
    printBanner();
    stdout.writeln();
    _section('USAGE');
    stdout.writeln(
        '    ${_dim(r'$')} ${_g('ninjadev')} ${green.wrap('<command>')} ${_dim('[arguments]')}');
    stdout.writeln();
    _section('COMMANDS');
    _item('create', 'Create a new Flutter project');
    _item('generate', 'Generate code (features, widgets, models, APIs, theme)',
        alias: 'gen');
    _item('init', 'Initialize NinjaDev in an existing project');
    _item('add', 'Add packages to pubspec.yaml');
    _item('remove', 'Remove packages from pubspec.yaml', alias: 'rm');
    _item('list', 'List templates, packages, generators', alias: 'ls');
    _item('config', 'Manage NinjaDev configuration');
    _item('template', 'Manage project templates');
    _item('doctor', 'Check environment and diagnose issues');
    _item('upgrade', 'Upgrade NinjaDev to latest version');
    _item('completion', 'Generate shell completions');
    stdout.writeln();
    _section('GLOBAL OPTIONS');
    _item('-h, --help', 'Show help');
    _item('-v, --verbose', 'Verbose output');
    _item('--version', 'Print version');
    stdout.writeln();
    _section('EXAMPLES');
    _example('ninjadev create my_app');
    _example('ninjadev gen feature auth');
    _example('ninjadev gen widget button');
    _example('ninjadev gen theme');
    _example('ninjadev add dio');
    _example('ninjadev doctor');
    stdout.writeln();
    stdout.writeln(
        '  ${_dim('Tip: run')} ${_g('ninjadev')} ${_dim('with no arguments to open the interactive menu.')}');
    stdout.writeln();
  }

  static void _section(String title) => stdout.writeln('  ${_gb(title)}');

  static void _item(String name, String description, {String? alias}) {
    final label = alias == null ? name : '$name ($alias)';
    stdout.writeln('    ${_g(label.padRight(16))} $description');
  }

  static void _example(String command) {
    final parts = command.split(' ');
    stdout.writeln(
        '    ${_dim(r'$')} ${_g(parts.first)} ${green.wrap(parts.sublist(1).join(' '))}');
  }

  /// Renders a single-select option line: a red dot + sky blue text
  /// when active, a green dot + green text otherwise.
  static String _optionLine(String text, bool active) => active
      ? '${_solidRed('●')} ${_sky(text)}'
      : '${_solidGreen('●')} ${green.wrap(text)}';

  /// Renders a multi-select option line: a checked/unchecked prefix
  /// plus the text in sky blue when it's under the cursor.
  static String _checkboxLine(String text, bool active, bool checked) {
    final prefix = checked ? _sky('◉') : _dim('◯');
    return '$prefix ${active ? _sky(text) : green.wrap(text)}';
  }

  /// Trims a menu line defensively so very long custom-typed names
  /// don't approach the terminal width.
  static String _fit(String text) {
    var width = 80;
    try {
      if (stdout.hasTerminal) width = stdout.terminalColumns;
    } catch (_) {}
    final max = width - 8;
    if (max <= 3 || text.length <= max) return text;
    return '${text.substring(0, max - 1)}…';
  }

  /// Shows the main menu and returns a command token like `create`.
  static String mainMenu() {
    const entries = [
      ['create', 'New Project'],
      ['existing', 'Existing Project'],
      ['doctor', 'Doctor'],
      ['help', 'Help'],
      ['exit', 'Exit'],
    ];
    stdout.writeln('  ${_dim('↑↓ move · enter select')}');
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('What would you like to do?')}',
      optionCount: entries.length,
      render: (i, active) => _optionLine(_fit(entries[i][1]), active),
    );
    return entries[index][0];
  }

  /// Menu shown for the Existing Project workflow; returns a token.
  static String existingProjectMenu(String projectName) {
    stdout.writeln();
    stdout.writeln('  ${_dim('Current project:')} ${_gb(projectName)}');
    const entries = [
      ['assets', 'Asset folders (images, icons, fonts…)'],
      ['libfolders', 'Lib folders (screens, pages…)'],
      ['api', 'Service files (API, settings…)'],
      ['snippets', 'Ready-made pages (camera, buttons, scanner…)'],
      ['settings', 'Custom settings page (local/deploy)'],
      ['orientation', 'Device orientation (portrait/landscape)'],
      ['gitpush', 'Push to GitHub (creates the repo if needed)'],
      ['githubaccount', 'GitHub account (login / switch / logout)'],
      ['env', 'Create .env file'],
      ['home', '←  Back to Home'],
    ];
    final index = TerminalMenu.select(
      prompt:
          '${_g('?')} ${_bold('What do you want to create in this project?')}',
      optionCount: entries.length,
      render: (i, active) => _optionLine(_fit(entries[i][1]), active),
    );
    return entries[index][0];
  }

  /// Shown when Existing Project is opened outside a Flutter project.
  static void notInProject(String path) {
    stdout.writeln();
    stdout.writeln(
        '  ${red.wrap('✘')} No Flutter project found here ${_dim('(pubspec.yaml missing)')}');
    stdout.writeln('    ${_dim('Folder:')} ${_dim(path)}');
    stdout.writeln(
        '    ${_dim('Open a terminal inside your project, then run')} ${_g('ninjadev')} ${_dim('again.')}');
  }

  /// Announces the auto-detected project folder.
  static void autoSelectedProject(String name) {
    stdout.writeln();
    stdout.writeln('  ${_g('✔')} Auto-selected project: ${_gb(name)}');
  }

  /// Wizard step header: a green dot timeline showing progress,
  /// beside `STEP 2/4 · Project details`.
  static void stepHeader(int step, int total, String title) {
    stdout.writeln();
    stdout.writeln(
        '  ${_timeline(step, total)}  ${_gb('STEP $step/$total')} ${_dim('·')} ${_bold(title)}');
    stdout.writeln();
  }

  /// True green (256-color, not the 16-color `lightGreen` used
  /// elsewhere) — some terminal themes remap bright-green to a
  /// blue-tinted teal, which is exactly the look the timeline should
  /// avoid.
  static String _solidGreen(String text) => _shade(text, 46);

  /// True red (256-color) for the active option's dot — same reasoning
  /// as [_solidGreen]: a fixed color, not a themeable 16-color one.
  static String _solidRed(String text) => _shade(text, 196);

  /// Dot-and-line progress timeline: filled green dots for the
  /// current and completed steps, hollow dim dots for what's ahead.
  static String _timeline(int step, int total) {
    final buffer = StringBuffer();
    for (var i = 1; i <= total; i++) {
      buffer.write(i <= step ? _solidGreen('●') : _dim('○'));
      if (i != total) {
        buffer.write(i < step ? _solidGreen('──') : _dim('──'));
      }
    }
    return buffer.toString();
  }

  /// One passed line of the environment check.
  static void checkOk(String label, String detail) => stdout
      .writeln('    ${_g('✔')} ${_bold(label.padRight(8))} ${_dim(detail)}');

  /// One failed line of the environment check.
  static void checkFail(String label, String hint) => stdout.writeln(
      '    ${red.wrap('✘')} ${_bold(label.padRight(8))} ${_dim(hint)}');

  /// Aborts the wizard with a red message.
  static void wizardAbort(String message) {
    stdout.writeln();
    stdout.writeln('  ${red.wrap('✘')} $message');
  }

  /// Asks for a valid snake_case project name.
  static String askProjectName() => Input.withTheme(
        prompt: 'Project name (e.g. my_app)',
        theme: greenTheme,
        validator: (value) {
          final error = ProjectValidator.validateName(value.trim());
          if (error != null) throw ValidationError(error);
          return true;
        },
      ).interact().trim();

  /// Asks for the bundle / organization id, defaulting to com.example.
  static String askOrganization() {
    final value = Input.withTheme(
      prompt: 'Bundle ID / organization',
      defaultValue: 'com.example',
      theme: greenTheme,
      validator: (input) {
        final trimmed = input.trim();
        if (trimmed.isEmpty) return true;
        final error = ProjectValidator.validateBundleId(trimmed);
        if (error != null) throw ValidationError(error);
        return true;
      },
    ).interact().trim();
    return value.isEmpty ? 'com.example' : value;
  }

  /// Asks for the project description; comes pre-filled so the user
  /// can keep it, extend it or rewrite it.
  static String askDescription() => Input.withTheme(
        prompt: 'Project description',
        initialText: 'A new Flutter application built with NinjaDev.',
        theme: greenTheme,
      ).interact().trim();

  /// Prints the summary shown right before generation starts.
  static void createSummary(String name, String org, String description,
      List<String> platforms, String orientation) {
    stdout.writeln('    ${_dim('Project'.padRight(12))} ${_g(name)}');
    stdout.writeln('    ${_dim('Bundle'.padRight(12))} ${_g('$org.$name')}');
    stdout
        .writeln('    ${_dim('Description'.padRight(12))} ${_g(description)}');
    stdout.writeln(
        '    ${_dim('Platforms'.padRight(12))} ${_g(platforms.join(', '))}');
    stdout
        .writeln('    ${_dim('Orientation'.padRight(12))} ${_g(orientation)}');
    stdout.writeln();
  }

  /// Single-select of the device orientation lock applied to main.dart.
  static String askOrientation() {
    const values = ['portrait', 'landscape', 'both'];
    const labels = ['Portrait only', 'Landscape only', 'Both (unlocked)'];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Device orientation')}',
      optionCount: labels.length,
      render: (i, active) => _optionLine(labels[i], active),
    );
    return values[index];
  }

  /// Multi-select of target platforms/devices; iOS and Android are
  /// pre-selected by default.
  static List<String> askPlatforms() {
    const values = ['ios', 'android', 'web', 'macos', 'windows', 'linux'];
    const labels = ['iOS', 'Android', 'Web', 'macOS', 'Windows', 'Linux'];
    stdout.writeln('  ${_dim('space = select · enter = confirm')}');
    final picked = TerminalMenu.multiSelect(
      prompt: '${_g('?')} ${_bold('Select target platforms')}',
      optionCount: labels.length,
      defaults: const [true, true, false, false, false, false],
      render: (i, active, checked) => _checkboxLine(labels[i], active, checked),
    );
    if (picked.isEmpty) return ['ios', 'android'];
    return [for (final i in picked) values[i]];
  }

  /// Multi-select of asset folders to create under `assets/`.
  /// All options come pre-selected.
  static List<String>? assetFoldersMenu() {
    const folders = ['images', 'icons', 'fonts', 'animations'];
    stdout.writeln();
    stdout.writeln('  ${_dim('space = select · enter = create')}');
    final exists = [
      for (final folder in folders) Directory('assets/$folder').existsSync(),
    ];
    final labels = [
      for (var i = 0; i < folders.length; i++)
        exists[i] ? '${folders[i].padRight(12)} ✔ created' : folders[i],
      '←  Back',
    ];
    final picked = TerminalMenu.multiSelect(
      prompt: '${_g('?')} ${_bold('Which asset folders do you want?')}',
      optionCount: labels.length,
      defaults: [for (final alreadyThere in exists) !alreadyThere, false],
      render: (i, active, checked) => _checkboxLine(labels[i], active, checked),
    );
    if (picked.contains(folders.length)) return null;
    return [for (final i in picked) folders[i]];
  }

  /// Multi-select of folders to create under `lib/`, with an option
  /// to type custom names (comma separated).
  static List<String>? libFoldersMenu() {
    const defaults = ['screens', 'pages', 'services', 'widgets', 'utils'];
    stdout.writeln();
    stdout.writeln('  ${_dim('space = select · enter = create')}');
    final labels = [
      for (final folder in defaults)
        Directory('lib/$folder').existsSync()
            ? '${folder.padRight(12)} ✔ created'
            : folder,
      'Custom names…',
      '←  Back',
    ];
    final picked = TerminalMenu.multiSelect(
      prompt: '${_g('?')} ${_bold('Which folders do you want inside lib/?')}',
      optionCount: labels.length,
      render: (i, active, checked) => _checkboxLine(labels[i], active, checked),
    );
    if (picked.contains(defaults.length + 1)) return null;
    final chosen = <String>[
      for (final i in picked)
        if (i < defaults.length) defaults[i],
    ];
    if (picked.contains(defaults.length)) {
      final raw = Input.withTheme(
        prompt: 'Custom folder names (comma separated)',
        theme: greenTheme,
      ).interact();
      chosen.addAll([
        for (final part in raw.split(','))
          if (part.trim().isNotEmpty) part.trim(),
      ]);
    }
    return chosen;
  }

  /// Lets the user pick one folder out of [folders]; null means Back.
  static String? pickFolder(String prompt, List<String> folders) {
    final labels = [...folders.map(_fit), '←  Back'];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold(prompt)}',
      optionCount: labels.length,
      render: (i, active) => _optionLine(labels[i], active),
    );
    if (index == folders.length) return null;
    return folders[index];
  }

  /// Multi-select of service files to create inside [targetFolder];
  /// includes custom names and Back. Returns null on Back.
  static List<String>? serviceFilesMenu(String targetFolder) {
    const services = [
      'api_service',
      'settings_service',
      'auth_service',
      'storage_service',
      'notification_service',
    ];
    stdout.writeln();
    stdout.writeln('  ${_dim('space = select · enter = create')}');
    final exists = [
      for (final service in services)
        File('$targetFolder${Platform.pathSeparator}$service.dart')
            .existsSync(),
    ];
    final labels = [
      for (var i = 0; i < services.length; i++)
        exists[i] ? '${services[i].padRight(22)} ✔ created' : services[i],
      'Custom names…',
      '←  Back',
    ];
    final picked = TerminalMenu.multiSelect(
      prompt: '${_g('?')} ${_bold('Which service files do you want?')}',
      optionCount: labels.length,
      render: (i, active, checked) => _checkboxLine(labels[i], active, checked),
    );
    if (picked.contains(services.length + 1)) return null;
    final chosen = <String>[
      for (final i in picked)
        if (i < services.length) services[i],
    ];
    if (picked.contains(services.length)) {
      final raw = Input.withTheme(
        prompt: 'Custom service names (comma separated, e.g. payment)',
        theme: greenTheme,
      ).interact();
      chosen.addAll([
        for (final part in raw.split(','))
          if (part.trim().isNotEmpty) part.trim(),
      ]);
    }
    return chosen;
  }

  // ---------------------------------------------------------------------
  // HTTP API Function Generator prompts
  // ---------------------------------------------------------------------

  /// First choice under "Service files": the guided HTTP function
  /// generator, the WebSocket service generator, or the existing
  /// stub-file creator. Returns 'http', 'ws', 'stub' or null (Back).
  static String? serviceTypeMenu() {
    const entries = [
      ['http', 'HTTP API Function'],
      ['ws', 'WebSocket Service'],
      ['stub', 'Create service stub…'],
      ['back', '←  Back'],
    ];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('What service do you want to create?')}',
      optionCount: entries.length,
      render: (i, active) => _optionLine(_fit(entries[i][1]), active),
    );
    return entries[index][0] == 'back' ? null : entries[index][0];
  }

  /// `web_socket_channel` vs `dart:io` choice for the WebSocket
  /// wizard. Returns 'channel', 'dartio' or null (Back).
  static String? socketClientMenu() {
    const entries = [
      ['channel', 'web_socket_channel  (mobile + desktop + web)'],
      ['dartio', 'dart:io WebSocket  (built-in, no web)'],
      ['back', '←  Back'],
    ];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Which WebSocket client do you want?')}',
      optionCount: entries.length,
      render: (i, active) => _optionLine(_fit(entries[i][1]), active),
    );
    return entries[index][0] == 'back' ? null : entries[index][0];
  }

  /// Asks for the socket service's base name (e.g. `chat`), defaulting
  /// to `socket`. Used for both the class name and the file name.
  static String askSocketServiceName() => Input.withTheme(
        prompt: 'Socket service name (e.g. chat)',
        defaultValue: 'socket',
        theme: greenTheme,
        validator: (value) {
          if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value.trim())) {
            throw ValidationError(
                'Use lowercase letters, numbers and _ (e.g. chat)');
          }
          return true;
        },
      ).interact().trim();

  /// Asks for a literal `ws://`/`wss://` URL when the user doesn't
  /// want to use `.env`.
  static String askSocketUrl() {
    final value = Input.withTheme(
      prompt: 'Enter socket URL',
      defaultValue: 'wss://example.com/socket',
      theme: greenTheme,
      validator: (input) {
        final v = input.trim();
        if (v.isEmpty) return true;
        if (!v.startsWith('ws://') && !v.startsWith('wss://')) {
          throw ValidationError('Socket URLs start with ws:// or wss://');
        }
        return true;
      },
    ).interact().trim();
    return value.isEmpty ? 'wss://example.com/socket' : value;
  }

  /// Heartbeat ping interval choice; returns seconds (0 = off).
  static int askHeartbeatInterval() {
    const labels = [
      'Off',
      'Every 10 seconds',
      'Every 30 seconds',
      'Every 60 seconds',
    ];
    const values = [0, 10, 30, 60];
    final index = TerminalMenu.select(
      prompt:
          '${_g('?')} ${_bold('Heartbeat ping (keeps the connection alive)?')}',
      optionCount: labels.length,
      initialIndex: 2,
      render: (i, active) => _optionLine(labels[i], active),
    );
    return values[index];
  }

  /// Auto-reconnect attempts choice; returns attempt count (0 = off).
  static int askReconnectAttempts() {
    const labels = ['Off', '3 attempts', '5 attempts', '10 attempts'];
    const values = [0, 3, 5, 10];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Auto-reconnect after a connection drop?')}',
      optionCount: labels.length,
      initialIndex: 2,
      render: (i, active) => _optionLine(labels[i], active),
    );
    return values[index];
  }

  /// Existing `*_service.dart` files, plus "Create new service" and
  /// Back. Returns the chosen path, `'__new__'`, or null (Back).
  static String? selectServiceFile(List<String> existingFiles) {
    final labels = [
      ...existingFiles.map((f) => f.split(Platform.pathSeparator).last),
      'Create new service',
      '←  Back',
    ];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Select service file')}',
      optionCount: labels.length,
      render: (i, active) => _optionLine(_fit(labels[i]), active),
    );
    if (index == labels.length - 1) return null;
    if (index == labels.length - 2) return '__new__';
    return existingFiles[index];
  }

  /// Asks for a new service's base name (without `_service.dart`).
  static String askNewServiceName() => Input.withTheme(
        prompt: 'New service name (e.g. product)',
        theme: greenTheme,
        validator: (value) {
          if (value.trim().isEmpty) {
            throw ValidationError('Name cannot be empty');
          }
          return true;
        },
      ).interact().trim();

  /// HTTP method single-select. Returns the method string, or null on
  /// Back.
  static String? httpMethodMenu() {
    const methods = [
      'GET',
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
      'HEAD',
      'OPTIONS',
    ];
    final labels = [...methods, '←  Back'];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Select HTTP method')}',
      optionCount: labels.length,
      render: (i, active) => _optionLine(labels[i], active),
    );
    return index == methods.length ? null : methods[index];
  }

  /// Asks for the API URL; returns the placeholder when left empty.
  static String askApiUrl() {
    final value = Input.withTheme(
      prompt: 'Enter API URL',
      defaultValue: '/api/endpoint',
      theme: greenTheme,
    ).interact().trim();
    return value.isEmpty ? '/api/endpoint' : value;
  }

  /// Shows the suggested name as a hint line, then asks for the
  /// function name with that suggestion as the *default* (used only
  /// when the field is submitted empty) — not pre-filled text. Typing
  /// anything always replaces the suggestion outright, so there's no
  /// way to end up with the suggestion and your own text mashed
  /// together.
  static String askFunctionNameSuggested(String suggested) {
    stdout.writeln();
    stdout.writeln('  ${_dim('Suggested:')} ${_g(suggested)}');
    final value = Input.withTheme(
      prompt: 'Enter function name (Enter = use suggested)',
      defaultValue: suggested,
      theme: greenTheme,
    ).interact().trim();
    return value.isEmpty ? suggested : value;
  }

  /// Generic Yes/No prompt used for the body/query-parameter questions.
  static bool yesNoMenu(String prompt, {bool defaultYes = true}) {
    const entries = ['Yes', 'No'];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold(prompt)}',
      optionCount: entries.length,
      initialIndex: defaultYes ? 0 : 1,
      render: (i, active) => _optionLine(entries[i], active),
    );
    return index == 0;
  }

  /// JSON vs form-data choice for request bodies.
  static String bodyTypeMenu() {
    const entries = ['JSON', 'Form Data'];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Select body type')}',
      optionCount: entries.length,
      render: (i, active) => _optionLine(entries[i], active),
    );
    return index == 0 ? 'json' : 'form';
  }

  /// Collects query parameter names one at a time until the user
  /// declines "add another?".
  static List<String> askQueryParams() {
    final params = <String>[];
    while (true) {
      final name = Input.withTheme(
        prompt: 'Enter parameter name',
        theme: greenTheme,
        validator: (value) {
          if (value.trim().isEmpty) {
            throw ValidationError('Parameter name cannot be empty');
          }
          return true;
        },
      ).interact().trim();
      params.add(name);
      if (!yesNoMenu('Enter another parameter?', defaultYes: false)) break;
    }
    return params;
  }

  /// Asked right before the URL prompt: should the URL come from a
  /// `.env` variable instead of being typed as a literal?
  static bool askUseEnv({String prompt = 'Use .env for the base URL?'}) =>
      yesNoMenu(prompt, defaultYes: false);

  /// The `.env` variable name that holds the base URL, e.g.
  /// `API_BASE_URL`.
  static String askEnvKey() {
    final value = Input.withTheme(
      prompt: 'Enter .env variable name',
      defaultValue: 'API_BASE_URL',
      theme: greenTheme,
    ).interact().trim();
    return value.isEmpty ? 'API_BASE_URL' : value;
  }

  /// Whether this request needs any custom headers.
  static bool askUseHeaders() =>
      yesNoMenu('Does this request need custom headers?', defaultYes: false);

  /// Collects header name/value pairs one at a time until the user
  /// declines "add another?" — same shape as [askQueryParams]. Each
  /// value can be a literal string or pulled from `.env` (handy for
  /// API keys/tokens that shouldn't be hardcoded).
  static Map<String, HeaderValue> askHeaders() {
    final headers = <String, HeaderValue>{};
    while (true) {
      final name = Input.withTheme(
        prompt: 'Enter header name',
        theme: greenTheme,
        validator: (value) {
          if (value.trim().isEmpty) {
            throw ValidationError('Header name cannot be empty');
          }
          return true;
        },
      ).interact().trim();

      if (yesNoMenu('Use .env for this header\'s value?', defaultYes: false)) {
        final envKey = Input.withTheme(
          prompt: 'Enter .env variable name',
          theme: greenTheme,
          validator: (value) {
            if (value.trim().isEmpty) {
              throw ValidationError('Variable name cannot be empty');
            }
            return true;
          },
        ).interact().trim();
        headers[name] = HeaderValue.env(envKey);
      } else {
        final value = Input.withTheme(
          prompt: 'Enter header value',
          theme: greenTheme,
        ).interact().trim();
        headers[name] = HeaderValue.literal(value);
      }

      if (!yesNoMenu('Add another header?', defaultYes: false)) break;
    }
    return headers;
  }

  /// Shows the invalid-name error with a couple of good examples.
  static void invalidFunctionName() {
    stdout.writeln();
    stdout.writeln('  ${red.wrap('✘')} Invalid function name.');
    stdout
        .writeln('    ${_dim('Use a valid Dart function name, for example:')}');
    stdout.writeln('    ${_g('createUser')}');
    stdout.writeln('    ${_g('getUsers')}');
    stdout.writeln('    ${_g('updateUser')}');
  }

  /// Announces an automatic camelCase conversion of the typed name.
  static void nameAutoConverted(String original, String converted) {
    stdout.writeln(
        '  ${_dim('"$original" isn\'t a valid Dart name — using')} ${_g(converted)}');
  }

  /// Rename / overwrite / cancel choice when the target file already
  /// has a function with this name. Never overwrites without this
  /// explicit confirmation.
  static String duplicateFunctionMenu(String functionName) {
    stdout.writeln();
    stdout.writeln(
        '  ${red.wrap('✘')} Function ${_g(functionName)} already exists.');
    const entries = ['rename', 'overwrite', 'cancel'];
    const labels = [
      'Choose another name',
      'Overwrite existing function',
      'Cancel',
    ];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('What do you want to do?')}',
      optionCount: labels.length,
      render: (i, active) => _optionLine(labels[i], active),
    );
    return entries[index];
  }

  /// Summary shown right before generating the function; returns true
  /// to proceed, false to cancel.
  static bool confirmApiFunction({
    required String method,
    required String url,
    required String functionName,
    required String? bodyType,
    required String file,
    String? envKey,
    Map<String, HeaderValue> headers = const {},
  }) {
    const divider = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    stdout.writeln();
    stdout.writeln('  ${_g(divider)}');
    stdout.writeln('        ${_bold('API FUNCTION')}');
    stdout.writeln('  ${_g(divider)}');
    stdout.writeln();
    stdout.writeln('    ${_dim('Method'.padRight(10))} ${_g(method)}');
    if (envKey != null) {
      stdout.writeln(
          '    ${_dim('Base URL'.padRight(10))} ${_g("\$dotenv['$envKey']")}');
      stdout.writeln('    ${_dim('Path'.padRight(10))} ${_g(url)}');
    } else {
      stdout.writeln('    ${_dim('URL'.padRight(10))} ${_g(url)}');
    }
    stdout.writeln('    ${_dim('Function'.padRight(10))} ${_g(functionName)}');
    if (bodyType != null) {
      stdout.writeln('    ${_dim('Body'.padRight(10))} ${_g(bodyType)}');
    }
    if (headers.isNotEmpty) {
      stdout.writeln(
          '    ${_dim('Headers'.padRight(10))} ${_g(headers.keys.join(', '))}');
    }
    stdout.writeln('    ${_dim('File'.padRight(10))} ${_g(file)}');
    stdout.writeln();
    stdout.writeln('  ${_g(divider)}');
    stdout.writeln();
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Ready to generate?')}',
      optionCount: 2,
      render: (i, active) =>
          _optionLine(i == 0 ? 'Generate' : 'Cancel', active),
    );
    return index == 0;
  }

  /// Final success line after the function is written to disk.
  static void apiFunctionCreated({
    required String file,
    required String functionName,
    required String method,
    required String url,
  }) {
    stdout.writeln();
    stdout.writeln('  ${_g('✔')} API function created');
    printTree('Details', [
      'File      $file',
      'Function  $functionName',
      'Method    $method',
      'URL       $url',
    ]);
  }

  /// Summary shown right before generating the WebSocket service;
  /// returns true to proceed, false to cancel.
  static bool confirmSocketService({
    required String clientLabel,
    required String serviceName,
    required String urlOrEnv,
    required String heartbeat,
    required String reconnect,
    required String file,
  }) {
    const divider = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    stdout.writeln();
    stdout.writeln('  ${_g(divider)}');
    stdout.writeln('        ${_bold('WEBSOCKET SERVICE')}');
    stdout.writeln('  ${_g(divider)}');
    stdout.writeln();
    stdout.writeln('    ${_dim('Client'.padRight(10))} ${_g(clientLabel)}');
    stdout.writeln('    ${_dim('Service'.padRight(10))} ${_g(serviceName)}');
    stdout.writeln('    ${_dim('URL'.padRight(10))} ${_g(urlOrEnv)}');
    stdout.writeln('    ${_dim('Heartbeat'.padRight(10))} ${_g(heartbeat)}');
    stdout.writeln('    ${_dim('Reconnect'.padRight(10))} ${_g(reconnect)}');
    stdout.writeln('    ${_dim('File'.padRight(10))} ${_g(file)}');
    stdout.writeln();
    stdout.writeln('  ${_g(divider)}');
    stdout.writeln();
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Ready to generate?')}',
      optionCount: 2,
      render: (i, active) =>
          _optionLine(i == 0 ? 'Generate' : 'Cancel', active),
    );
    return index == 0;
  }

  /// Summary shown right before bumping the version and pushing to
  /// GitHub; returns true to proceed, false to cancel.
  static bool confirmGitPush({
    required String oldVersion,
    required String newVersion,
    required List<String> changedFiles,
  }) {
    const divider = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    stdout.writeln();
    stdout.writeln('  ${_g(divider)}');
    stdout.writeln('        ${_bold('GIT PUSH')}');
    stdout.writeln('  ${_g(divider)}');
    stdout.writeln();
    stdout.writeln(
        '    ${_dim('Current version'.padRight(16))} ${_g(oldVersion)}');
    stdout.writeln('    ${_dim('New version'.padRight(16))} ${_g(newVersion)}');
    stdout.writeln();
    stdout.writeln('  ${_g(divider)}');
    if (changedFiles.isNotEmpty) {
      printTree('Changes to commit', changedFiles);
    } else {
      stdout.writeln();
      stdout.writeln(
          '  ${_dim('No other pending changes — only the version bump will be committed.')}');
      stdout.writeln();
    }
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Bump version and push to GitHub?')}',
      optionCount: 2,
      render: (i, active) => _optionLine(i == 0 ? 'Push' : 'Cancel', active),
    );
    return index == 0;
  }

  /// Final success line after the WebSocket service is written.
  static void socketServiceCreated({
    required String file,
    required String serviceName,
    required String clientLabel,
  }) {
    stdout.writeln();
    stdout.writeln('  ${_g('✔')} WebSocket service created');
    printTree('Details', [
      'File     $file',
      'Service  $serviceName',
      'Client   $clientLabel',
    ]);
  }

  /// Multi-select of ready-made snippet files (sourced from
  /// ~/.ninjadev/snippets/) to copy into [targetFolder]. Files already
  /// present in the target show `✔ created`. Returns null on Back.
  static List<String>? snippetFilesMenu(
      String targetFolder, List<String> available) {
    stdout.writeln();
    stdout.writeln('  ${_dim('space = select · enter = create')}');
    final labels = [
      for (final name in available)
        File('$targetFolder${Platform.pathSeparator}$name').existsSync()
            ? '${name.padRight(28)} ✔ created'
            : name,
      '←  Back',
    ];
    final picked = TerminalMenu.multiSelect(
      prompt: '${_g('?')} ${_bold('Which pages/widgets do you want to add?')}',
      optionCount: labels.length,
      render: (i, active, checked) => _checkboxLine(labels[i], active, checked),
    );
    if (picked.contains(available.length)) return null;
    return [
      for (final i in picked)
        if (i < available.length) available[i]
    ];
  }

  /// Which orientation variant of the settings-page bundle to generate.
  static String askSettingsOrientation() {
    const values = ['portrait', 'landscape'];
    const labels = ['Portrait', 'Landscape'];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Which orientation?')}',
      optionCount: labels.length,
      render: (i, active) => _optionLine(labels[i], active),
    );
    return values[index];
  }

  /// Which setup variant of the settings-page bundle to generate.
  static String askSettingsSetup() {
    const values = ['local', 'online'];
    const labels = ['Local setup', 'Online setup'];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Local setup or online setup?')}',
      optionCount: labels.length,
      render: (i, active) => _optionLine(labels[i], active),
    );
    return values[index];
  }

  /// Where a project that isn't on GitHub yet goes: 'original' — a new repo
  /// on the logged-in account — or 'office' — an existing repo the office
  /// already made, by its link.
  static String githubDestinationMenu() {
    const entries = [
      ['original', 'Original GitHub (new repo on my account)'],
      ['office', 'Office work (paste the repo link)'],
    ];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Where should this project go on GitHub?')}',
      optionCount: entries.length,
      render: (i, active) => _optionLine(_fit(entries[i][1]), active),
    );
    return entries[index][0];
  }

  /// Asks for the link of an existing repo to push to, e.g. one the office
  /// created in its GitHub organization. Takes the browser link or the
  /// clone link (HTTPS or SSH) and returns it ready for `git remote add`,
  /// or null when the input ends. Read as a plain terminal line on purpose:
  /// the Input widget only takes what fits on the prompt's own line, which
  /// cuts a link off in an 80-column terminal.
  static String? askOfficeRepoLink() {
    final linkPattern = RegExp(
        r'^(https://[\w.-]+/[\w.-]+/[\w.-]+|git@[\w.-]+:[\w.-]+/[\w.-]+)/?');
    stdout.writeln(
        '  ${_dim('Paste the repo link, e.g. https://github.com/company/project')}');
    while (true) {
      stdout.write('${_g('?')} ${_bold('Repository link')} ${_dim('›')} ');
      final line = stdin.readLineSync();
      if (line == null) return null;
      final value = line.trim();
      if (linkPattern.matchAsPrefix(value)?.end == value.length) {
        final link =
            value.endsWith('/') ? value.substring(0, value.length - 1) : value;
        return link.endsWith('.git') ? link : '$link.git';
      }
      stdout.writeln(
          '  ${red.wrap('✘')} ${_dim("That isn't a repo link — it should look like https://github.com/company/project")}');
    }
  }

  /// Asks for the new GitHub repository's name, pre-filled with the
  /// current folder name.
  static String askGithubRepoName(String defaultName) {
    final nameCharPattern = RegExp('[^A-Za-z0-9._-]');
    final value = Input.withTheme(
      prompt: 'Repository name',
      defaultValue: defaultName,
      theme: greenTheme,
      validator: (input) {
        final trimmed = input.trim();
        if (trimmed.isEmpty) return true;
        if (nameCharPattern.hasMatch(trimmed)) {
          throw ValidationError(
              'Use letters, numbers, . _ or - only (no spaces)');
        }
        return true;
      },
    ).interact().trim();
    return value.isEmpty ? defaultName : value;
  }

  /// First question under "GitHub account": which login to manage, each
  /// shown with its account (or "not set up"). Returns 'original',
  /// 'office' or 'back'.
  static String githubSlotMenu({String? original, String? office}) {
    stdout.writeln();
    final entries = [
      ['original', 'Original GitHub — ${original ?? 'not set up'}'],
      ['office', 'Office work — ${office ?? 'not set up'}'],
      ['back', '←  Back'],
    ];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Which GitHub account?')}',
      optionCount: entries.length,
      render: (i, active) => _optionLine(_fit(entries[i][1]), active),
    );
    return entries[index][0];
  }

  /// What to do with a login that's set up: 'use', 'login', 'logout' or
  /// 'back'.
  static String githubSlotActionMenu(String title, String account) {
    stdout.writeln('  ${_dim('$title:')} ${_gb(account)}');
    const entries = [
      ['use', 'Use this account now'],
      ['login', 'Log in with a different account'],
      ['logout', 'Log out'],
      ['back', '←  Back'],
    ];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold(title)}',
      optionCount: entries.length,
      render: (i, active) => _optionLine(entries[i][1], active),
    );
    return entries[index][0];
  }

  /// Asks for any link from the office GitHub — its organization page like
  /// https://github.com/company, a repo, or the office's own GitHub server —
  /// and returns the host to log in to, or null when the input ends.
  static String? askOfficeGithubHost() {
    stdout.writeln(
        '  ${_dim('Paste your office GitHub link, e.g. https://github.com/company')}');
    while (true) {
      stdout.write('${_g('?')} ${_bold('Office GitHub link')} ${_dim('›')} ');
      final line = stdin.readLineSync();
      if (line == null) return null;
      final host = GithubAccounts.hostOf(line.trim());
      if (host != null) return host;
      stdout.writeln(
          '  ${red.wrap('✘')} ${_dim("That isn't a GitHub link — it should look like https://github.com/company")}');
    }
  }

  /// Public vs private choice for a new GitHub repository.
  static bool askRepoIsPrivate() {
    const entries = ['Private', 'Public'];
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Repository visibility')}',
      optionCount: entries.length,
      render: (i, active) => _optionLine(entries[i], active),
    );
    return index == 0;
  }

  /// Summary shown right before creating the GitHub repo and pushing;
  /// returns true to proceed, false to cancel.
  static bool confirmGithubUpload({
    required String account,
    required String repoName,
    required bool isPrivate,
  }) {
    const divider = '━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    stdout.writeln();
    stdout.writeln('  ${_g(divider)}');
    stdout.writeln('        ${_bold('UPLOAD TO GITHUB')}');
    stdout.writeln('  ${_g(divider)}');
    stdout.writeln();
    stdout.writeln('    ${_dim('Account'.padRight(12))} ${_g(account)}');
    stdout.writeln('    ${_dim('Repository'.padRight(12))} ${_g(repoName)}');
    stdout.writeln(
        '    ${_dim('Visibility'.padRight(12))} ${_g(isPrivate ? 'Private' : 'Public')}');
    stdout.writeln();
    stdout.writeln('  ${_g(divider)}');
    stdout.writeln();
    final index = TerminalMenu.select(
      prompt: '${_g('?')} ${_bold('Create this repository and push?')}',
      optionCount: 2,
      render: (i, active) =>
          _optionLine(i == 0 ? 'Create & push' : 'Cancel', active),
    );
    return index == 0;
  }

  /// Asks a lowercase file name, e.g. for a new API service.
  static String askFileName(String prompt) => Input.withTheme(
        prompt: prompt,
        theme: greenTheme,
        validator: (value) {
          if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(value.trim())) {
            throw ValidationError(
                'Use lowercase letters, numbers and _ (e.g. auth)');
          }
          return true;
        },
      ).interact().trim();

  /// Friendly exit message for the interactive menu.
  static void goodbye() {
    stdout.writeln();
    stdout.writeln('  ${_g('Happy coding!')}');
    stdout.writeln();
  }
}
