import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:mason_logger/mason_logger.dart';

class GitService {
  final Logger _logger;
  GitService(this._logger);
  Future<bool> isGitInstalled() async {
    try {
      final result = await Process.run('git', ['--version'], runInShell: true);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isRepo(String path) async {
    final dir = Directory(p.join(path, '.git'));
    return await dir.exists();
  }

  Future<void> init(String path) async {
    if (!await isGitInstalled()) {
      _logger.err('Git is not installed');
      return;
    }
    if (await isRepo(path)) {
      _logger.warn('Git repository already exists');
      return;
    }
    final progress = _logger.progress('Initializing git repository...');
    final result = await Process.run('git', ['init'],
        runInShell: true, workingDirectory: path);
    if (result.exitCode == 0) {
      progress.complete('Git repository initialized');
    } else {
      progress.fail('Failed to initialize git: ${result.stderr}');
    }
  }

  Future<void> createGitignore(String path) async {
    const content = '''
# Flutter
.dart_tool/
.packages
build/
*.iml
.idea/
.vscode/
.metadata
*.lock
*.log
# Android
*.apk
*.aab
android/.gradle/
android/gradle/wrapper/gradle-wrapper.jar
android/local.properties
# iOS
ios/Pods/
ios/.symlinks/
ios/Flutter/Flutter.framework
ios/Flutter/Flutter.podspec
ios/Runner.xcworkspace
ios/Flutter/App.framework
# macOS
macos/Pods/
macos/.symlinks/
macos/Runner.xcworkspace
# Web
web/fonts/
# Windows
windows/runner/flutter_windows.dll
windows/runner/FlutterEmbedder.dll
windows/runner/flutter_windows.exe
# Linux
linux/flutter/ephemeral
# Environment
.env
.env.local
.env.dev
.env.prod
# IDE
*.swp
*.swo
*~
# OS
.DS_Store
Thumbs.db
# Coverage
coverage/
# Testing
test_reports/
# NinjaDev
.ninjadev/
''';
    await File(p.join(path, '.gitignore')).writeAsString(content);
    _logger.success('.gitignore created');
  }

  Future<void> stageAndCommit(String path,
      {String message = 'Initial commit'}) async {
    final staging = _logger.progress('Staging files...');
    final addResult = await Process.run('git', ['add', '.'],
        runInShell: true, workingDirectory: path);
    if (addResult.exitCode != 0) {
      staging.fail('Failed to stage files: ${addResult.stderr}');
      return;
    }
    staging.complete('Files staged');
    final committing = _logger.progress('Creating initial commit...');
    final commitResult = await Process.run(
      'git',
      ['commit', '-m', message, '--allow-empty'],
      runInShell: true,
      workingDirectory: path,
    );
    if (commitResult.exitCode == 0) {
      committing.complete('Initial commit created');
    } else {
      committing.fail('Failed to create commit: ${commitResult.stderr}');
    }
  }

  Future<void> configureUser(String path, {String? name, String? email}) async {
    if (name != null) {
      await Process.run('git', ['config', 'user.name', name],
          runInShell: true, workingDirectory: path);
    }
    if (email != null) {
      await Process.run('git', ['config', 'user.email', email],
          runInShell: true, workingDirectory: path);
    }
  }

  /// Pushes the current branch. If it has no upstream yet (e.g. right
  /// after `git init`), retries once with `-u origin <branch>`.
  Future<bool> push(String path) async {
    final progress = _logger.progress('Pushing to GitHub...');
    var result = await Process.run('git', ['push'],
        runInShell: true, workingDirectory: path);
    if (result.exitCode != 0 &&
        result.stderr.toString().contains('has no upstream branch')) {
      final branchResult = await Process.run(
          'git', ['rev-parse', '--abbrev-ref', 'HEAD'],
          runInShell: true, workingDirectory: path);
      final branch = branchResult.stdout.toString().trim();
      if (branch.isNotEmpty) {
        result = await Process.run('git', ['push', '-u', 'origin', branch],
            runInShell: true, workingDirectory: path);
      }
    }
    if (result.exitCode == 0) {
      progress.complete('Pushed to GitHub');
      return true;
    }
    progress.fail('git push failed: ${result.stderr.toString().trim()}');
    return false;
  }

  Future<void> setupRemote(String path, String remoteUrl) async {
    final progress = _logger.progress('Setting up remote...');
    final result = await Process.run(
      'git',
      ['remote', 'add', 'origin', remoteUrl],
      runInShell: true,
      workingDirectory: path,
    );
    if (result.exitCode == 0) {
      progress.complete('Remote added: $remoteUrl');
    } else {
      progress.fail('Failed to add remote: ${result.stderr}');
    }
  }
}
