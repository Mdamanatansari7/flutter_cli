/// Pure main.dart surgery for the settings bundle: points the app at the
/// setup the user picked — the bundle's imports from the folder it went
/// into, the saved mode (and for Local the saved server) restored before
/// runApp(), ModeBanner around every route and ModePage as home. Picking
/// Online takes the Local-only server restore out again. No file I/O
/// here on purpose — GenerateService reads and writes main.dart.
library;

/// main.dart after [MainDartWiring.wire], plus whatever couldn't be wired
/// automatically and has to be added by hand.
class MainDartWiringResult {
  const MainDartWiringResult(this.content, this.hints);

  final String content;
  final List<String> hints;
}

class MainDartWiring {
  static const String _modeCall = 'await loadSavedMode();';
  static const String _modeComment =
      '// Restore the TESTING / LIVE choice saved on the device';
  static const String _apiCall = 'await loadSavedApi();';
  static const String _apiComment =
      '// Restore the backend IP / port saved on the device';
  static const String _bannerComment =
      '// Shows the red "TESTING" strip on top of every page in testing mode';
  static const String _bannerArg =
      'builder: (context, child) => ModeBanner(child: child),';

  /// `home: <widget>(...)`, with up to one level of nested parentheses.
  static final RegExp _homeArg = RegExp(
    r'home:\s*(?:const\s+)?[\w.]+\((?:[^()]|\([^()]*\))*\)\s*,?',
  );

  /// Rewires [content] for the bundle in lib/[folder] of [packageName].
  /// [folder] is '' for lib itself, otherwise it ends in '/'.
  static MainDartWiringResult wire(
    String content, {
    required String packageName,
    required String folder,
    required bool isLocal,
  }) {
    final hints = <String>[];
    var out = _wireImports(content, packageName, folder, isLocal);
    out = _wireStartup(out, isLocal, hints);
    out = _wireMaterialApp(out, hints);
    out = _dropUnusedImport(
        out, packageName, 'Homepage.dart', RegExp(r'\bHomepage\b'));
    if (!isLocal) {
      out = _dropUnusedImport(
        out,
        packageName,
        'api_config.dart',
        RegExp(r'\b(loadSavedApi|saveApi|apiUrl|apiIp|apiPort|defaultApiPort)\b'),
      );
    }
    return MainDartWiringResult(out, hints);
  }

  /// The whole line importing [file] from [packageName] — as a package or
  /// relative import, from any folder.
  static RegExp _importLine(String packageName, String file) => RegExp(
        "^import\\s+'(?:package:${RegExp.escape(packageName)}/)?(?:\\w+/)*"
        "${RegExp.escape(file)}';[ \\t]*\\n?",
        multiLine: true,
      );

  /// Points the imports of the bundle files at [folder] (dropping a second
  /// copy from another folder), and adds the ones main.dart doesn't have
  /// yet after its last import.
  static String _wireImports(
    String content,
    String packageName,
    String folder,
    bool isLocal,
  ) {
    var out = content;
    final missing = StringBuffer();
    final files = [
      'ModeBanner.dart',
      'app_mode.dart',
      'mode.dart',
      if (isLocal) 'api_config.dart',
    ];
    for (final file in files) {
      final line = "import 'package:$packageName/$folder$file';\n";
      final matches = _importLine(packageName, file).allMatches(out).toList();
      if (matches.isEmpty) {
        missing.write(line);
        continue;
      }
      for (final match in matches.reversed) {
        out = out.replaceRange(
            match.start, match.end, match == matches.first ? line : '');
      }
    }
    if (missing.isEmpty) return out;

    final imports =
        RegExp(r'^import\s.*;[ \t]*\n', multiLine: true).allMatches(out);
    final at = imports.isEmpty ? 0 : imports.last.end;
    return out.substring(0, at) + missing.toString() + out.substring(at);
  }

  /// Restores the saved mode before runApp() and, for Local, the saved
  /// server right after it. Online takes the server restore out again.
  static String _wireStartup(String content, bool isLocal, List<String> hints) {
    var out = content;
    if (!out.contains(_modeCall)) {
      final runApp =
          RegExp(r'^([ \t]*)runApp\(', multiLine: true).firstMatch(out);
      final canAwait = RegExp(r'main\(\)\s*async\s*\{').hasMatch(out) &&
          out.contains('WidgetsFlutterBinding.ensureInitialized()');
      if (runApp != null && canAwait) {
        final indent = runApp.group(1)!;
        out = out.replaceRange(runApp.start, runApp.start + indent.length,
            '$indent$_modeComment\n$indent$_modeCall\n\n$indent');
      } else {
        hints.add('call `$_modeCall` in main() before runApp()');
      }
    }

    if (!isLocal) {
      return out
          .replaceAll(
              RegExp('\\n\\n[ \\t]*${RegExp.escape(_apiComment)}\\n'
                  '[ \\t]*${RegExp.escape(_apiCall)}'),
              '')
          .replaceAll(
              RegExp('^[ \\t]*${RegExp.escape(_apiCall)}[ \\t]*\\n',
                  multiLine: true),
              '');
    }
    if (out.contains(_apiCall)) return out;

    final modeCall = RegExp('^([ \\t]*)${RegExp.escape(_modeCall)}',
            multiLine: true)
        .firstMatch(out);
    if (modeCall == null) {
      hints.add('call `$_apiCall` in main() before runApp()');
      return out;
    }
    final indent = modeCall.group(1)!;
    return out.replaceRange(modeCall.end, modeCall.end,
        '\n\n$indent$_apiComment\n$indent$_apiCall');
  }

  /// Makes ModePage MaterialApp's home and ModeBanner its builder.
  static String _wireMaterialApp(String content, List<String> hints) {
    final start = content.indexOf('MaterialApp(');
    final open = start == -1 ? -1 : start + 'MaterialApp'.length;
    final close = open == -1 ? -1 : _closingParen(content, open);
    if (close == -1) {
      hints.add(
          "use ModeBanner(child: child) as MaterialApp's builder and ModePage() as its home");
      return content;
    }
    final lineStart = content.lastIndexOf('\n', start) + 1;
    final indent =
        '${RegExp(r'^[ \t]*').stringMatch(content.substring(lineStart, start))}  ';
    var args = content.substring(open + 1, close);

    final home = _homeArg.firstMatch(args);
    if (home != null) {
      args = args.replaceRange(home.start, home.end, 'home: ModePage(),');
    } else if (RegExp(r'\b(routes|initialRoute|onGenerateRoute)\s*:')
        .hasMatch(args)) {
      hints.add('make ModePage() the first screen');
    } else {
      args = '\n${indent}home: ModePage(),$args';
    }

    if (!args.contains('ModeBanner(')) {
      if (RegExp(r'\bbuilder\s*:').hasMatch(args)) {
        hints.add(
            "wrap what MaterialApp's builder returns in ModeBanner(child: ...)");
      } else {
        final at = args.indexOf('home:');
        args = at == -1
            ? '\n$indent$_bannerComment\n$indent$_bannerArg$args'
            : args.replaceRange(
                at, at, '$_bannerComment\n$indent$_bannerArg\n$indent');
      }
    }
    return content.replaceRange(open + 1, close, args);
  }

  /// Removes the import of [file] once nothing else in main.dart matches
  /// [usage].
  static String _dropUnusedImport(
    String content,
    String packageName,
    String file,
    RegExp usage,
  ) {
    final importLine = _importLine(packageName, file);
    if (!importLine.hasMatch(content)) return content;
    final without = content.replaceAll(importLine, '');
    return usage.hasMatch(without) ? content : without;
  }

  /// Index of the `)` closing the `(` at [open], or -1.
  static int _closingParen(String text, int open) {
    var depth = 0;
    for (var i = open; i < text.length; i++) {
      if (text[i] == '(') depth++;
      if (text[i] == ')') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }
}
