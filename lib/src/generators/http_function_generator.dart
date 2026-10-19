/// Pure logic for the HTTP API Function Generator: name suggestion,
/// path/query parameter handling, HTTP-client detection and Dart code
/// generation. No file I/O here on purpose — the CLI orchestration layer
/// (`ninjadev_cli.dart`) reads/writes files and calls into this class.
library;

/// Which HTTP client the generated code should call.
enum HttpClientKind { dio, http }

/// A single header's value: either a literal string baked into the
/// generated code, or a reference to an `.env` variable read at
/// runtime (e.g. an API key that shouldn't be hardcoded).
class HeaderValue {
  const HeaderValue.literal(String value)
      : literalValue = value,
        envKey = null;
  const HeaderValue.env(this.envKey) : literalValue = null;

  final String? literalValue;
  final String? envKey;

  bool get fromEnv => envKey != null;

  /// The exact Dart expression to embed as this header's value.
  String toDartExpression() =>
      fromEnv ? "dotenv.env['$envKey'] ?? ''" : "'${literalValue ?? ''}'";
}

/// Everything the user chose in the wizard.
class HttpApiRequest {
  const HttpApiRequest({
    required this.method,
    required this.url,
    required this.functionName,
    this.bodyType,
    this.queryParams = const [],
    this.headers = const {},
    this.envKey,
  });

  /// GET, POST, PUT, PATCH, DELETE, HEAD or OPTIONS.
  final String method;

  /// Raw URL/path as typed, e.g. `/users/{id}`. When [envKey] is set,
  /// this is just the path portion — the host comes from .env.
  final String url;

  final String functionName;

  /// `json`, `form`, or null when this request has no body.
  final String? bodyType;

  /// Query parameter names (GET only).
  final List<String> queryParams;

  /// Custom header name -> value pairs. Each value is either a literal
  /// or an `.env` reference — see [HeaderValue].
  final Map<String, HeaderValue> headers;

  /// `.env` variable name to read the base URL from (e.g.
  /// `API_BASE_URL`), or null to use [url] as a plain literal.
  final String? envKey;

  bool get usesEnv => envKey != null && envKey!.isNotEmpty;

  /// True when the generated code needs `flutter_dotenv` at all — the
  /// base URL, or any header value, coming from `.env`.
  bool get needsDotenv => usesEnv || headers.values.any((h) => h.fromEnv);

  /// Path parameter names found as `{name}` in [url], in order.
  List<String> get pathParams =>
      RegExp(r'\{(\w+)\}').allMatches(url).map((m) => m.group(1)!).toList();

  bool get supportsBody => const ['POST', 'PUT', 'PATCH'].contains(method);
  bool get supportsQuery => method == 'GET';
}

/// Which client + variable name to call in the generated code.
class HttpClientDetection {
  const HttpClientDetection(
    this.kind,
    this.clientVar, {
    this.needsDioField = false,
  });

  final HttpClientKind kind;

  /// The field/identifier already used in the project, e.g. `dio` or
  /// `_dio` — reused as-is so the generated code matches house style.
  final String clientVar;

  /// True when no existing `Dio ...` field was found, so the generator
  /// needs to add one alongside the new method.
  final bool needsDioField;
}

/// Position of a located method declaration inside a file's source
/// text — see [HttpFunctionGenerator._findDeclaration].
class _Declaration {
  const _Declaration(this.signatureStart, this.closeBrace);

  /// Index of the newline right before the declaration's leading
  /// indentation (i.e. before any return type / modifiers).
  final int signatureStart;

  /// Index of the `}` that closes the method body.
  final int closeBrace;
}

class HttpFunctionGenerator {
  HttpFunctionGenerator._();

  static const Set<String> _numericParamHints = {
    'page',
    'limit',
    'offset',
    'size',
    'count',
    'perpage',
    'per_page',
    'pagesize',
    'page_size',
    'year',
    'month',
    'day',
  };

  static const Map<String, String> _placeholderFallback = {
    'GET': 'getData',
    'POST': 'postData',
    'PUT': 'updateData',
    'PATCH': 'patchData',
    'DELETE': 'deleteData',
    'HEAD': 'headData',
    'OPTIONS': 'optionsData',
  };

  /// Suggests a function name from the method + url.
  ///
  ///   GET    /users       -> getUsers
  ///   GET    /users/{id}  -> getUserById
  ///   POST   /users       -> createUser
  ///   PUT    /users/{id}  -> updateUser
  ///   PATCH  /users/{id}  -> patchUser
  ///   DELETE /users/{id}  -> deleteUser
  ///
  /// Falls back to a method-based generic name when [url] is empty or
  /// still the `/api/endpoint` placeholder.
  static String suggestFunctionName(String method, String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed == '/api/endpoint') {
      return _placeholderFallback[method] ?? 'callApi';
    }

    final segments =
        trimmed.split('/').where((s) => s.trim().isNotEmpty).toList();
    if (segments.isEmpty) return _placeholderFallback[method] ?? 'callApi';

    final lastIsParam = _isPathParam(segments.last);
    final lastParamName = lastIsParam ? _paramName(segments.last) : null;
    final staticSegments = segments.where((s) => !_isPathParam(s)).toList();
    final resource = staticSegments.isEmpty ? 'data' : staticSegments.last;
    final singular = _pascal(_singularize(resource));
    final plural = _pascal(resource);

    switch (method) {
      case 'GET':
        return lastParamName != null
            ? 'get${singular}By${_pascal(lastParamName)}'
            : 'get$plural';
      case 'POST':
        return 'create$singular';
      case 'PUT':
        return 'update$singular';
      case 'PATCH':
        return 'patch$singular';
      case 'DELETE':
        return 'delete$singular';
      case 'HEAD':
        return 'head$plural';
      case 'OPTIONS':
        return 'options$plural';
      default:
        return 'callApi';
    }
  }

  /// Converts a raw name (possibly "Create User" or "create-user") into
  /// a valid lowerCamelCase Dart identifier. Returns null when there's
  /// nothing usable left (e.g. the input was purely symbols).
  static String? toDartIdentifier(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return null;
    final words = cleaned
        .split(RegExp(r'[^a-zA-Z0-9]+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return null;
    final buffer = StringBuffer(words.first.toLowerCase());
    for (final word in words.skip(1)) {
      buffer.write(_pascal(word.toLowerCase()));
    }
    var result = buffer.toString();
    if (RegExp(r'^[0-9]').hasMatch(result)) result = '_$result';
    return result;
  }

  static bool isValidDartIdentifier(String name) =>
      RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(name);

  static bool isNumericQueryParam(String name) =>
      _numericParamHints.contains(name.toLowerCase());

  /// Converts a URL template to a Dart string-interpolated path, e.g.
  /// `/users/{id}` -> `/users/$id`. Uses string concatenation (not
  /// nested `${}` interpolation) to build the `$name` piece, since
  /// that's far less error-prone to get right than counting `$` signs
  /// inside a Dart string literal.
  static String dartPath(String url) {
    final path = url.trim().isEmpty ? '/api/endpoint' : url.trim();
    return path.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (m) => r'$' + m.group(1)!,
    );
  }

  /// The full URL expression to embed in the generated call: just the
  /// path, or the `.env` lookup + path when [HttpApiRequest.envKey] is
  /// set (e.g. base URL from `API_BASE_URL`, path `/users/$id`).
  static String dartUrlExpression(HttpApiRequest request) {
    final path = dartPath(request.url);
    if (!request.usesEnv) return path;
    final envLookup = r'${dotenv.env[' + "'" + request.envKey! + "'" + r']}';
    return envLookup + path;
  }

  /// Renders [headers] as a Dart map literal's inner lines (no
  /// surrounding braces, no indentation of its own — callers use
  /// [_indent] to place these at the right depth).
  static String _headerEntries(Map<String, HeaderValue> headers) =>
      headers.entries
          .map((e) => "'${e.key}': ${e.value.toDartExpression()},")
          .join('\n');

  /// Looks at pubspec.yaml + (optionally) the target service file to
  /// decide which HTTP client to generate calls for, and which
  /// variable name to call it through.
  static HttpClientDetection detectClient({
    required String pubspecContent,
    String? existingFileContent,
  }) {
    final hasDio =
        RegExp(r'^\s*dio\s*:', multiLine: true).hasMatch(pubspecContent);
    final hasHttp =
        RegExp(r'^\s*http\s*:', multiLine: true).hasMatch(pubspecContent);

    String? dioVar;
    if (existingFileContent != null) {
      final match = RegExp(r'\bDio\s+(_?\w+)\s*=')
              .firstMatch(existingFileContent) ??
          RegExp(r'\bfinal\s+Dio\s+(_?\w+)').firstMatch(existingFileContent);
      dioVar = match?.group(1);
    }

    if (hasDio || dioVar != null) {
      return HttpClientDetection(
        HttpClientKind.dio,
        dioVar ?? 'dio',
        needsDioField: dioVar == null,
      );
    }
    if (hasHttp) {
      return const HttpClientDetection(HttpClientKind.http, 'http');
    }
    // Nothing detected: default to package:http since it needs no client
    // instance/field, the lowest-friction choice when nothing is set up.
    return const HttpClientDetection(HttpClientKind.http, 'http');
  }

  /// Generates the Dart method (including its own 2-space class
  /// indentation) for [request] — a mandatory `// METHOD Request`
  /// comment line followed by the complete, self-contained method.
  static String generate(HttpApiRequest request, HttpClientDetection client) {
    final params = <String>[
      for (final p in request.pathParams) 'required String $p',
      if (request.supportsBody && request.bodyType != null)
        'required Map<String, dynamic> body',
      if (request.supportsQuery)
        for (final q in request.queryParams)
          '${isNumericQueryParam(q) ? 'int?' : 'String?'} $q',
    ];

    final signature =
        StringBuffer('  Future<dynamic> ${request.functionName}(');
    if (params.isEmpty) {
      signature.write(') async {');
    } else {
      signature.writeln('{');
      for (final p in params) {
        signature.writeln('    $p,');
      }
      signature.write('  }) async {');
    }

    final body = client.kind == HttpClientKind.dio
        ? _generateDio(request, client.clientVar)
        : _generateHttp(request);

    return '  // ${request.method} Request\n$signature\n$body  }\n';
  }

  static String _generateDio(HttpApiRequest request, String clientVar) {
    final path = dartUrlExpression(request);
    final method = request.method.toLowerCase();
    final hasHeaders = request.headers.isNotEmpty;
    final b = StringBuffer();

    b.writeln('    try {');
    if (request.method == 'OPTIONS') {
      b.writeln('      final response = await $clientVar.request(');
      b.writeln("        '$path',");
      if (hasHeaders) {
        b.writeln('        options: Options(');
        b.writeln("          method: 'OPTIONS',");
        b.writeln('          headers: {');
        b.writeln(_indent(_headerEntries(request.headers), 12));
        b.writeln('          },');
        b.writeln('        ),');
      } else {
        b.writeln("        options: Options(method: 'OPTIONS'),");
      }
      b.writeln('      ).timeout(const Duration(seconds: 30));');
    } else {
      b.writeln('      final response = await $clientVar.$method(');
      b.writeln("        '$path',");
      if (request.supportsBody && request.bodyType == 'json') {
        b.writeln('        data: body,');
      } else if (request.supportsBody && request.bodyType == 'form') {
        b.writeln('        data: FormData.fromMap(body),');
      }
      if (request.supportsQuery && request.queryParams.isNotEmpty) {
        b.writeln('        queryParameters: {');
        for (final q in request.queryParams) {
          b.writeln("          if ($q != null) '$q': $q,");
        }
        b.writeln('        },');
      }
      if (hasHeaders) {
        b.writeln('        options: Options(');
        b.writeln('          headers: {');
        b.writeln(_indent(_headerEntries(request.headers), 12));
        b.writeln('          },');
        b.writeln('        ),');
      }
      b.writeln('      ).timeout(const Duration(seconds: 30));');
    }
    b.writeln();
    b.writeln('      return _handleDioResponse(response);');
    b.writeln('    } on DioException catch (e) {');
    b.writeln('      _handleDioError(e);');
    b.writeln('    } catch (e) {');
    b.writeln("      throw Exception('Something went wrong: \$e');");
    b.writeln('    }');
    return b.toString();
  }

  /// The shared Dio response/error handlers used by every generated
  /// method in a file. `_handleDioResponse` decodes successful
  /// responses, `_handleDioError` translates a [DioException] into a
  /// user-friendly [Exception] (network errors when no status code is
  /// present, HTTP errors otherwise). Inserted once per file by
  /// [insertIntoFile].
  static String _dioResponseHandlers() => '''
  /// Returns decoded data for 2xx statuses, or throws a
  /// user-friendly [Exception] for HTTP error statuses.
  dynamic _handleDioResponse(Response response) {
    debugPrint('Status: \${response.statusCode}');
    debugPrint('Response: \${response.data}');

    final statusCode = response.statusCode ?? -1;
    if (statusCode >= 200 && statusCode < 300) return response.data;

    switch (statusCode) {
      case 400:
        throw Exception('Bad Request: \${response.data}');
      case 401:
        throw Exception('Unauthorized: \${response.data}');
      case 403:
        throw Exception('Forbidden: \${response.data}');
      case 404:
        throw Exception('Not Found: \${response.data}');
      case 409:
        throw Exception('Conflict: \${response.data}');
      case 422:
        throw Exception('Validation Error: \${response.data}');
      case 429:
        throw Exception('Too many requests. Please try again later.');
      case 500:
        throw Exception('Internal Server Error: \${response.data}');
      case 502:
      case 503:
      case 504:
        throw Exception(
          'Server temporarily unavailable. Please try again later.',
        );
      default:
        throw Exception(
          'Request failed (\$statusCode): \${response.data}',
        );
    }
  }

  /// Translates a [DioException] into a user-friendly [Exception].
  /// Never returns — always throws.
  Never _handleDioError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;
    debugPrint('Status: \$statusCode');
    debugPrint('Response: \$data');

    switch (statusCode) {
      case 400:
        throw Exception('Bad Request: \$data');
      case 401:
        throw Exception('Unauthorized: \$data');
      case 403:
        throw Exception('Forbidden: \$data');
      case 404:
        throw Exception('Not Found: \$data');
      case 409:
        throw Exception('Conflict: \$data');
      case 422:
        throw Exception('Validation Error: \$data');
      case 429:
        throw Exception('Too many requests. Please try again later.');
      case 500:
        throw Exception('Internal Server Error: \$data');
      case 502:
      case 503:
      case 504:
        throw Exception(
          'Server temporarily unavailable. Please try again later.',
        );
      case null:
        throw Exception(
          'Network error. Please check your internet connection.\\n\$e',
        );
      default:
        throw Exception('Request failed (\$statusCode): \$data');
    }
  }
''';

  static String _generateHttp(HttpApiRequest request) {
    final path = dartUrlExpression(request);
    final hasHeaders = request.headers.isNotEmpty;
    final isJson = request.supportsBody && request.bodyType == 'json';
    final b = StringBuffer();

    b.writeln('    try {');

    if (request.supportsQuery && request.queryParams.isNotEmpty) {
      b.writeln(
          "      final uri = Uri.parse('$path').replace(queryParameters: {");
      for (final q in request.queryParams) {
        b.writeln("        if ($q != null) '$q': $q.toString(),");
      }
      b.writeln('      });');
    } else {
      b.writeln("      final uri = Uri.parse('$path');");
    }

    // Build the headers map once; JSON requests always need
    // Content-Type, custom headers (if any) are merged in alongside it.
    String? headersBlock;
    if (isJson || hasHeaders) {
      final b2 = StringBuffer('{\n');
      if (isJson) b2.writeln("          'Content-Type': 'application/json',");
      if (hasHeaders) b2.writeln(_indent(_headerEntries(request.headers), 10));
      b2.write('        }');
      headersBlock = b2.toString();
    }

    if (request.method == 'OPTIONS') {
      b.writeln("      final request = http.Request('OPTIONS', uri);");
      if (hasHeaders) {
        for (final entry in request.headers.entries) {
          b.writeln(
              "      request.headers['${entry.key}'] = ${entry.value.toDartExpression()};");
        }
      }
      b.writeln('      final response = await http.Response.fromStream(');
      b.writeln('        await http.Client().send(request)');
      b.writeln('            .timeout(const Duration(seconds: 30)),');
      b.writeln('      );');
    } else {
      final method = request.method.toLowerCase();
      if (isJson) {
        b.writeln('      final response = await http.$method(');
        b.writeln('        uri,');
        b.writeln('        headers: $headersBlock,');
        b.writeln('        body: jsonEncode(body),');
        b.writeln('      ).timeout(const Duration(seconds: 30));');
      } else if (request.supportsBody && request.bodyType == 'form') {
        b.writeln('      final response = await http.$method(');
        b.writeln('        uri,');
        b.writeln('        body: body,');
        if (headersBlock != null) b.writeln('        headers: $headersBlock,');
        b.writeln('      ).timeout(const Duration(seconds: 30));');
      } else if (headersBlock != null) {
        b.writeln('      final response = await http.$method(');
        b.writeln('        uri,');
        b.writeln('        headers: $headersBlock,');
        b.writeln('      ).timeout(const Duration(seconds: 30));');
      } else {
        b.writeln('      final response = await http.$method(uri)');
        b.writeln('          .timeout(const Duration(seconds: 30));');
      }
    }
    b.writeln();
    b.writeln('      return _handleResponse(response);');
    b.writeln('    } on http.ClientException catch (e) {');
    b.writeln("      throw Exception('Network error. Please check your "
        "internet connection.\\n\$e');");
    b.writeln('    } on TimeoutException catch (e) {');
    b.writeln(
        "      throw Exception('Request timed out. Please try again later.\\n\$e');");
    b.writeln('    } on FormatException catch (e) {');
    b.writeln("      throw Exception('Invalid response from server.\\n\$e');");
    b.writeln('    } on Exception {');
    b.writeln('      rethrow;');
    b.writeln('    } catch (e) {');
    b.writeln("      throw Exception('Something went wrong: \$e');");
    b.writeln('    }');
    return b.toString();
  }

  /// The shared `_handleResponse` helper (package:http) that every
  /// generated method in a file routes its [http.Response] through:
  /// decodes 2xx bodies (JSON or plain text) and throws a
  /// user-friendly [Exception] for every HTTP error status. Inserted
  /// once per file by [insertIntoFile].
  static String _httpResponseHandler() => '''
  /// Parses an [http.Response]: returns decoded data for 2xx statuses,
  /// or throws a user-friendly [Exception] for HTTP error statuses.
  dynamic _handleResponse(http.Response response) {
    debugPrint('Status: \${response.statusCode}');
    debugPrint('Response: \${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } on FormatException {
        return response.body;
      }
    }

    switch (response.statusCode) {
      case 400:
        throw Exception('Bad Request: \${response.body}');
      case 401:
        throw Exception('Unauthorized: \${response.body}');
      case 403:
        throw Exception('Forbidden: \${response.body}');
      case 404:
        throw Exception('Not Found: \${response.body}');
      case 409:
        throw Exception('Conflict: \${response.body}');
      case 422:
        throw Exception('Validation Error: \${response.body}');
      case 429:
        throw Exception('Too many requests. Please try again later.');
      case 500:
        throw Exception('Internal Server Error: \${response.body}');
      case 502:
      case 503:
      case 504:
        throw Exception(
          'Server temporarily unavailable. Please try again later.',
        );
      default:
        throw Exception(
          'Request failed (\${response.statusCode}): \${response.body}',
        );
    }
  }
''';

  static String _indent(String text, int spaces) {
    final pad = ' ' * spaces;
    return text.split('\n').map((line) => '$pad$line'.trimRight()).join('\n');
  }

  /// Canonical import order this generator ever needs: `dart:` first,
  /// then `package:` imports alphabetically — matches what `dart
  /// format`/effective_dart expect, so a freshly-seeded file comes out
  /// correctly ordered without a second formatting pass.
  static const List<String> _importPriority = [
    "import 'dart:async';",
    "import 'dart:convert';",
    "import 'package:dio/dio.dart';",
    "import 'package:flutter/foundation.dart';",
    "import 'package:flutter_dotenv/flutter_dotenv.dart';",
    "import 'package:http/http.dart' as http;",
  ];

  /// Inserts [methodCode] into [fileContent]'s first class/mixin/
  /// extension body, right before its closing `}`, adding any imports
  /// the client needs that aren't already present. The new method is
  /// always appended as a new member — existing methods are never
  /// touched, and the new method can never end up spliced inside one
  /// of them.
  ///
  /// Falls back to appending at the very end of the file when no
  /// class/mixin/extension is found at all (e.g. a hand-written file
  /// of plain top-level functions) — still strictly after the last
  /// existing declaration, never inside it.
  ///
  /// Validates brace balance before writing anything: throws
  /// [StateError] rather than ever producing a file that doesn't
  /// parse.
  static String insertIntoFile(
    String fileContent,
    String methodCode,
    HttpClientDetection client, {
    bool needsDotenvImport = false,
  }) {
    if (!_hasBalancedBraces(methodCode)) {
      throw StateError(
          'Generated method has unbalanced braces — refusing to write a broken file.');
    }
    if (fileContent.isNotEmpty && !_hasBalancedBraces(fileContent)) {
      throw StateError(
          'Target file already has unbalanced braces — fix it manually, then generate again.');
    }

    // The shared response/error handler is what every generated method
    // routes its response through, so it must exist alongside them —
    // added once per file, skipped when the file already declares it.
    // Its debugPrint calls need flutter/foundation, pulled in alongside.
    final handlers = client.kind == HttpClientKind.dio
        ? _dioResponseHandlers()
        : _httpResponseHandler();
    final handlerSignatures = client.kind == HttpClientKind.dio
        ? [
            RegExp(r'dynamic\s+_handleDioResponse\s*\('),
            RegExp(r'Never\s+_handleDioError\s*\('),
          ]
        : [RegExp(r'dynamic\s+_handleResponse\s*\(http\.Response')];
    final handlersMissing =
        !handlerSignatures.every((re) => re.hasMatch(fileContent));

    final needed = <String>[
      if (client.kind == HttpClientKind.http) "import 'dart:async';",
      if (client.kind == HttpClientKind.http) "import 'dart:convert';",
      if (client.kind == HttpClientKind.dio) "import 'package:dio/dio.dart';",
      if (needsDotenvImport)
        "import 'package:flutter_dotenv/flutter_dotenv.dart';",
      if (handlersMissing)
        "import 'package:flutter/foundation.dart';",
      if (client.kind == HttpClientKind.http)
        "import 'package:http/http.dart' as http;",
    ];
    final missing = [
      for (final imp in _importPriority)
        if (needed.contains(imp) && !fileContent.contains(imp)) imp,
    ];
    final content =
        missing.isEmpty ? fileContent : _insertImports(fileContent, missing);

    var insertion = methodCode;
    if (client.kind == HttpClientKind.dio &&
        client.needsDioField &&
        !RegExp(r'\bDio\s+_?\w+\s*=').hasMatch(fileContent)) {
      insertion = '  final Dio ${client.clientVar} = Dio();\n\n$insertion';
    }

    if (handlersMissing) {
      insertion = '$insertion\n$handlers';
    }

    final insertAt = _classBodyInsertionPoint(content);
    if (insertAt == null) {
      final trimmed = content.trimRight();
      return trimmed.isEmpty ? insertion : '$trimmed\n\n$insertion';
    }
    return '${content.substring(0, insertAt)}\n$insertion${content.substring(insertAt)}';
  }

  /// Splices [missing] import lines into [content] at their canonical
  /// positions (see [_importPriority]), preserving the order of imports
  /// that are already there. Never reorders or duplicates anything that
  /// already exists — only adds the missing ones.
  static String _insertImports(String content, List<String> missing) {
    final matches =
        RegExp(r'^import .+;$', multiLine: true).allMatches(content).toList();
    if (matches.isEmpty) {
      return '${missing.join('\n')}\n\n${content.trimLeft()}';
    }

    final merged = <String>[
      for (final m in matches) content.substring(m.start, m.end),
    ];
    for (final imp in missing) {
      if (merged.contains(imp)) continue;
      final index = _importIndex(imp);
      var pos = 0;
      while (pos < merged.length && _importIndex(merged[pos]) <= index) {
        pos++;
      }
      merged.insert(pos, imp);
    }

    final first = matches.first.start;
    final last = matches.last.end;
    return '${content.substring(0, first)}${merged.join('\n')}'
        '${content.substring(last)}';
  }

  /// Position of [imp] in the canonical import order; anything not in
  /// the list sorts after everything that is.
  static int _importIndex(String imp) {
    final index = _importPriority.indexOf(imp);
    return index == -1 ? _importPriority.length : index;
  }

  /// Finds where a new class member should go: right before the
  /// closing `}` of the file's first top-level `class`/`mixin`/
  /// `extension`, located by brace-matching forward from that
  /// declaration's own `{` — so anything after the class in the file
  /// (if anything) can never shift where new methods land. Returns
  /// null when there's no such declaration at all.
  static int? _classBodyInsertionPoint(String content) {
    final declMatch =
        RegExp(r'\b(class|mixin|extension)\b[^{]*\{').firstMatch(content);
    if (declMatch == null) return null;
    var depth = 1;
    for (var i = declMatch.end; i < content.length; i++) {
      if (content[i] == '{') depth++;
      if (content[i] == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return null;
  }

  static bool _hasBalancedBraces(String code) {
    var depth = 0;
    for (final unit in code.codeUnits) {
      if (unit == 0x7B) depth++;
      if (unit == 0x7D) {
        depth--;
        if (depth < 0) return false;
      }
    }
    return depth == 0;
  }

  /// Locates a declaration of [functionName] in [fileContent] — as
  /// opposed to a mere call site like `await getUsers();`. Each
  /// candidate `name(` match is confirmed by walking past its
  /// (possibly named-parameter-block-containing) parameter list and
  /// checking what follows: a declaration continues into
  /// `async`/`sync*`/`{`, a call site ends in `;`.
  static _Declaration? _findDeclaration(
      String fileContent, String functionName) {
    final candidates = RegExp('\\n[ \\t]*[\\w<>?,\\s]*\\b$functionName\\s*\\(')
        .allMatches(fileContent);
    for (final candidate in candidates) {
      var parenDepth = 1;
      var i = candidate.end;
      while (i < fileContent.length && parenDepth > 0) {
        if (fileContent[i] == '(') parenDepth++;
        if (fileContent[i] == ')') parenDepth--;
        i++;
      }
      if (parenDepth != 0) continue;

      final afterParens = fileContent.substring(i).trimLeft();
      final looksLikeBody = afterParens.startsWith('{') ||
          afterParens.startsWith('async') ||
          afterParens.startsWith('sync*');
      if (!looksLikeBody) continue;

      final openBrace = fileContent.indexOf('{', i);
      if (openBrace == -1) continue;
      var depth = 0;
      var closeBrace = -1;
      for (var j = openBrace; j < fileContent.length; j++) {
        if (fileContent[j] == '{') depth++;
        if (fileContent[j] == '}') {
          depth--;
          if (depth == 0) {
            closeBrace = j;
            break;
          }
        }
      }
      if (closeBrace == -1) continue;
      return _Declaration(candidate.start, closeBrace);
    }
    return null;
  }

  /// Checks whether [fileContent] already declares a method called
  /// [functionName] — a real declaration, not just a call site.
  static bool hasFunction(String fileContent, String functionName) =>
      _findDeclaration(fileContent, functionName) != null;

  /// Removes an existing `functionName(...) { ... }` method from
  /// [fileContent] — used for the "Overwrite" choice. Also consumes a
  /// single-line comment sitting directly above it (our own generated
  /// `// X Request` marker) so overwriting never leaves an orphaned
  /// comment behind. Returns the content unchanged if the method can't
  /// be located.
  static String removeFunction(String fileContent, String functionName) {
    final decl = _findDeclaration(fileContent, functionName);
    if (decl == null) return fileContent;

    var removalStart = decl.signatureStart;
    final beforeSignature = fileContent.substring(0, removalStart);
    final priorNewline = beforeSignature.lastIndexOf('\n');
    final priorLine = beforeSignature.substring(priorNewline + 1);
    if (priorLine.trim().startsWith('//')) {
      removalStart = priorNewline == -1 ? 0 : priorNewline;
    }

    return fileContent.substring(0, removalStart) +
        fileContent.substring(decl.closeBrace + 1);
  }

  static bool _isPathParam(String segment) =>
      segment.startsWith('{') && segment.endsWith('}');

  static String _paramName(String segment) =>
      segment.substring(1, segment.length - 1);

  static String _singularize(String word) {
    if (word.endsWith('ies') && word.length > 3) {
      return '${word.substring(0, word.length - 3)}y';
    }
    if (word.endsWith('ses') && word.length > 3) {
      return word.substring(0, word.length - 2);
    }
    if (word.endsWith('s') && !word.endsWith('ss') && word.length > 1) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }

  static String _pascal(String word) =>
      word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);
}
