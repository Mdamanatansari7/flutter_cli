import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:mason_logger/mason_logger.dart';
import 'package:ninjadev/src/services/package_service.dart';

class ApiGenerator {
  final Logger _logger;
  ApiGenerator(this._logger);
  Future<void> generate(String name,
      {String? feature, String? path, bool dryRun = false}) async {
    final cn = _pascalCase(name);
    var outputDir = path;
    if (outputDir == null) {
      if (feature != null) {
        outputDir = p.join(Directory.current.path, 'lib', 'features',
            _toSnakeCase(feature), 'services');
      } else {
        outputDir = p.join(Directory.current.path, 'lib', 'services');
      }
    }
    final fn = _toFileName(name).toLowerCase();
    final outputPath = p.join(outputDir, '${fn}_service.dart');
    final clientPath = p.join(
        Directory.current.path, 'lib', 'core', 'network', 'api_client.dart');
    final clientImport = p
        .split(p.relative(p.absolute(clientPath), from: p.absolute(outputDir)))
        .join('/');
    if (dryRun) {
      _logger.info('Would create service: $outputPath');
      _logger.detail(_simpleServiceContent(cn, clientImport));
      return;
    }
    _logger.info('');
    _logger.info('Define API methods:');
    final methods = <ApiMethod>[];
    while (true) {
      _logger.info('');
      _logger.info('Endpoint path (e.g., /api/users) or empty to finish:');
      final endpoint = stdin.readLineSync()?.trim() ?? '';
      if (endpoint.isEmpty) break;
      _logger.info('HTTP method (GET/POST/PUT/DELETE):');
      final httpMethod = stdin.readLineSync()?.trim().toUpperCase() ?? 'GET';
      _logger.info('Function name (e.g., getUsers):');
      final funcName = stdin.readLineSync()?.trim() ?? '';
      final params = <MethodParam>[];
      _logger.info('Enter parameters (field:type, empty to finish):');
      while (true) {
        _logger.info('Parameter:');
        final input = stdin.readLineSync()?.trim() ?? '';
        if (input.isEmpty) break;
        final parts = input.split(':');
        if (parts.length == 2)
          params.add(MethodParam(parts[0].trim(), parts[1].trim()));
      }
      if (funcName.isNotEmpty && endpoint.isNotEmpty) {
        methods.add(ApiMethod(endpoint, httpMethod, funcName, params));
      }
    }
    if (methods.isEmpty) {
      methods.add(ApiMethod('/api/${_toSnakeCase(cn)}', 'GET', 'get$cn', []));
    }
    final progress = _logger.progress('Generating API service $name...');
    await File(outputPath).create(recursive: true);
    await File(outputPath)
        .writeAsString(_customServiceContent(cn, methods, clientImport));
    progress.complete('API service created: $outputPath');
    await _ensureApiClient(clientPath);
  }

  /// The generated services talk through lib/core/network/api_client.dart —
  /// writes a small package:http based one (and adds http) when the
  /// project doesn't have one yet.
  Future<void> _ensureApiClient(String clientPath) async {
    if (await File(clientPath).exists()) return;
    await File(clientPath).create(recursive: true);
    await File(clientPath).writeAsString(_apiClientContent);
    _logger.success('Created ${p.relative(clientPath)}');
    await PackageService(_logger).ensurePackage('http');
  }

  /// [httpMethod] as the ApiClient method to call; anything unknown is a GET.
  String _clientMethod(String httpMethod) =>
      const {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'}.contains(httpMethod)
          ? httpMethod.toLowerCase()
          : 'get';

  String _simpleServiceContent(String cn, String clientImport) =>
      '''import '$clientImport';
class ${cn}Service {
  final ApiClient _client;
  ${cn}Service(this._client);
  Future<Map<String, dynamic>> getAll() async => _client.get('/api/${_toSnakeCase(cn)}');
  Future<Map<String, dynamic>> getById(String id) async => _client.get('/api/${_toSnakeCase(cn)}/\$id');
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async => _client.post('/api/${_toSnakeCase(cn)}', body: data);
  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> data) async => _client.put('/api/${_toSnakeCase(cn)}/\$id', body: data);
  Future<Map<String, dynamic>> delete(String id) async => _client.delete('/api/${_toSnakeCase(cn)}/\$id');
}
''';

  /// One method per endpoint. Parameters become required named arguments:
  /// the JSON body for POST/PUT/PATCH, the query string otherwise.
  String _customServiceContent(
      String cn, List<ApiMethod> methods, String clientImport) {
    final b = StringBuffer();
    b.writeln("import '$clientImport';");
    b.writeln();
    b.writeln('class ${cn}Service {');
    b.writeln('  final ApiClient _client;');
    b.writeln('  ${cn}Service(this._client);');
    for (final m in methods) {
      final params = m.params.isEmpty
          ? ''
          : '{${m.params.map((param) => 'required ${param.type} ${param.name}').join(', ')}}';
      final hasBody = const {'POST', 'PUT', 'PATCH'}.contains(m.httpMethod);
      final query = !hasBody && m.params.isNotEmpty
          ? '?${m.params.map((param) => '${param.name}=\${${param.name}}').join('&')}'
          : '';
      final body = hasBody && m.params.isNotEmpty
          ? ", body: {${m.params.map((param) => "'${param.name}': ${param.name}").join(', ')}}"
          : '';
      b.writeln(
          '  Future<Map<String, dynamic>> ${m.funcName}($params) async {');
      b.writeln(
          "    return _client.${_clientMethod(m.httpMethod)}('${m.endpoint}$query'$body);");
      b.writeln('  }');
      b.writeln();
    }
    b.writeln('}');
    return b.toString();
  }

  static const String _apiClientContent = r'''
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Small JSON client the generated API services talk through. Point
/// [baseUrl] at your backend, e.g. ApiClient(baseUrl: 'https://api.example.com').
class ApiClient {
  ApiClient({this.baseUrl = '', http.Client? client})
      : _http = client ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> get(String path) async =>
      _decode(await _http.get(_uri(path)));

  Future<Map<String, dynamic>> post(String path,
          {Map<String, dynamic>? body}) async =>
      _decode(await _http.post(_uri(path),
          headers: _jsonHeaders, body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> put(String path,
          {Map<String, dynamic>? body}) async =>
      _decode(await _http.put(_uri(path),
          headers: _jsonHeaders, body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> patch(String path,
          {Map<String, dynamic>? body}) async =>
      _decode(await _http.patch(_uri(path),
          headers: _jsonHeaders, body: jsonEncode(body ?? {})));

  Future<Map<String, dynamic>> delete(String path) async =>
      _decode(await _http.delete(_uri(path)));

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  /// The decoded JSON object; a top-level JSON list comes back under 'data'.
  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }
}
''';

  String _pascalCase(String input) => input
      .split(RegExp(r'[_\s-]'))
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join();
  String _toFileName(String input) => input
      .split(RegExp(r'[_\s-]'))
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join();
  String _toSnakeCase(String input) => input
      .replaceAllMapped(
          RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')
      .replaceAll(RegExp(r'^_'), '')
      .toLowerCase();
}

class ApiMethod {
  final String endpoint;
  final String httpMethod;
  final String funcName;
  final List<MethodParam> params;
  ApiMethod(this.endpoint, this.httpMethod, this.funcName, this.params);
}

class MethodParam {
  final String name;
  final String type;
  MethodParam(this.name, this.type);
}
