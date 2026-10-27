import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One GitHub login: the GitHub it's on (github.com, or an office's own
/// GitHub server) and the username.
class GithubLogin {
  const GithubLogin(this.host, this.user);

  final String host;
  final String user;

  /// The username, plus the host when it isn't github.com.
  String get label => host == 'github.com' ? user : '$user on $host';

  Map<String, String> toJson() => {'host': host, 'user': user};
}

/// Remembers which GitHub login is the user's own ('original') and which
/// is their office one ('office'), in ~/.ninjadev/github_accounts.json.
/// Usernames only — the GitHub CLI keeps the actual logins; this is just
/// what lets "GitHub account" and the first push pick the right one.
class GithubAccounts {
  GithubAccounts._();

  static File get _file => File(p.join(
        Platform.environment['HOME'] ??
            Platform.environment['USERPROFILE'] ??
            '',
        '.ninjadev',
        'github_accounts.json',
      ));

  /// The saved logins by slot ('original' / 'office'); empty when none.
  static Map<String, GithubLogin> load() {
    try {
      final data = jsonDecode(_file.readAsStringSync());
      if (data is! Map) return {};
      return {
        for (final entry in data.entries)
          if (entry.value is Map &&
              entry.value['host'] is String &&
              entry.value['user'] is String)
            entry.key.toString(): GithubLogin(
                entry.value['host'] as String, entry.value['user'] as String),
      };
    } catch (_) {
      return {};
    }
  }

  static void save(String slot, GithubLogin login) =>
      _write({...load(), slot: login});

  static void remove(String slot) => _write(load()..remove(slot));

  static void _write(Map<String, GithubLogin> accounts) {
    _file.parent.createSync(recursive: true);
    _file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      for (final entry in accounts.entries) entry.key: entry.value.toJson(),
    }));
  }

  /// The host a GitHub link points at — https://host/… or git@host:… — or
  /// null when [link] isn't one.
  static String? hostOf(String link) {
    final match = RegExp(r'^(?:https://([\w.-]+)(?:/\S*)?|git@([\w.-]+):\S+)')
        .matchAsPrefix(link);
    if (match == null || match.end != link.length) return null;
    return match.group(1) ?? match.group(2);
  }
}
