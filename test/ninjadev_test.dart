import 'dart:io';
import 'package:test/test.dart';
import 'package:ninjadev/ninjadev.dart';

void main() {
  group('NinjaDev CLI', () {
    test('CLI should be instantiable', () {
      expect(() => NinjaDevCLI(), returnsNormally);
    });

    test('CLI should have a run method', () {
      final cli = NinjaDevCLI();
      expect(cli.run, isA<Function>());
    });
  });

  group('ProjectValidator', () {
    test('validateName returns null for valid name', () {
      expect(ProjectValidator.validateName('my_app'), isNull);
    });

    test('validateName returns error for empty name', () {
      expect(ProjectValidator.validateName(''), isNotNull);
    });

    test('validateName returns error for name starting with uppercase', () {
      expect(ProjectValidator.validateName('MyApp'), isNotNull);
    });

    test('validateName returns error for name with hyphens', () {
      expect(ProjectValidator.validateName('my-app'), isNotNull);
    });

    test('validateBundleId returns null for valid bundle ID', () {
      expect(ProjectValidator.validateBundleId('com.example.app'), isNull);
    });

    test('validateBundleId returns error for invalid bundle ID', () {
      expect(ProjectValidator.validateBundleId('invalid'), isNotNull);
    });
  });

  group('FileUtils', () {
    test('writeFile creates file with content', () async {
      final tempDir = Directory.systemTemp.createTempSync('ninjadev_test_');
      final testFile = '${tempDir.path}/test.txt';
      await FileUtils.writeFile(testFile, 'test content');
      expect(await File(testFile).exists(), isTrue);
      expect(await File(testFile).readAsString(), equals('test content'));
      await tempDir.delete(recursive: true);
    });

    test('readFile returns content for existing file', () async {
      final tempDir = Directory.systemTemp.createTempSync('ninjadev_test_');
      final testFile = '${tempDir.path}/test.txt';
      await File(testFile).writeAsString('hello');
      final content = await FileUtils.readFile(testFile);
      expect(content, equals('hello'));
      await tempDir.delete(recursive: true);
    });
  });

  group('DoctorCommand', () {
    test('should be constructable', () {
      expect(() => DoctorCommand(), returnsNormally);
    });

    test('has parser with expected options', () {
      final cmd = DoctorCommand();
      expect(cmd.parser.options.containsKey('verbose'), isTrue);
      expect(cmd.parser.options.containsKey('fix'), isTrue);
    });
  });

  group('CreateCommand', () {
    test('should be constructable', () {
      expect(() => CreateCommand(), returnsNormally);
    });

    test('has parser with expected options', () {
      final cmd = CreateCommand();
      expect(cmd.parser.options.containsKey('org'), isTrue);
      expect(cmd.parser.options.containsKey('template'), isTrue);
      expect(cmd.parser.options.containsKey('no-git'), isTrue);
      expect(cmd.parser.options.containsKey('yes'), isTrue);
    });
  });

  group('ConfigService', () {
    test('default config has expected structure', () async {
      final service = ConfigService();
      await service.load();
      expect(service.all, isA<Map<String, dynamic>>());
      expect(service.all.containsKey('project'), isTrue);
      expect(service.all.containsKey('template'), isTrue);
    });

    test('get returns null for missing key', () async {
      final service = ConfigService();
      await service.load();
      expect(service.get('nonexistent.key'), isNull);
    });
  });
}
