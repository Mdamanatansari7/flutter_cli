import 'dart:io';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:ninjadev/src/utils/file_utils.dart';
import 'package:ninjadev/src/utils/ui.dart';

class ThemeGenerator {
  final Logger _logger;
  ThemeGenerator(this._logger);
  Future<void> generate(String? path, {bool dryRun = false}) async {
    final themeDir =
        path ?? p.join(Directory.current.path, 'lib', 'core', 'theme');
    if (dryRun) {
      _logger.info('Would create theme files in: $themeDir');
      return;
    }
    final progress = _logger.progress('Generating theme system...');
    await Directory(themeDir).create(recursive: true);
    await FileUtils.writeFile(p.join(themeDir, 'colors.dart'), _colors);
    await FileUtils.writeFile(
        p.join(themeDir, 'text_styles.dart'), _textStyles);
    await FileUtils.writeFile(p.join(themeDir, 'app_theme.dart'), _appTheme);
    await FileUtils.writeFile(p.join(themeDir, 'spacing.dart'), _spacing);
    await FileUtils.writeFile(p.join(themeDir, 'radius.dart'), _radius);
    progress.complete('Theme system created at $themeDir');
    NinjaUI.printTree('Generated theme', [
      '$themeDir/',
      '  colors.dart',
      '  text_styles.dart',
      '  app_theme.dart',
      '  spacing.dart',
      '  radius.dart',
    ]);
  }

  String get _colors => '''import 'package:flutter/material.dart';
class AppColors {
  AppColors._();
  // Primary
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryLight = Color(0xFF9D97FF);
  static const Color primaryDark = Color(0xFF4A42D4);
  // Secondary
  static const Color secondary = Color(0xFF03DAC6);
  static const Color secondaryLight = Color(0xFF66FFF8);
  static const Color secondaryDark = Color(0xFF00A896);
  // Neutral
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);
  // Semantic
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);
  // Background
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
}
''';
  String get _textStyles => '''import 'package:flutter/material.dart';
class AppTextStyles {
  AppTextStyles._();
  static const String _fontFamily = 'AppFont';
  static TextStyle get displayLarge => const TextStyle(
    fontFamily: _fontFamily, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1.5,
  );
  static TextStyle get displayMedium => const TextStyle(
    fontFamily: _fontFamily, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5,
  );
  static TextStyle get displaySmall => const TextStyle(
    fontFamily: _fontFamily, fontSize: 24, fontWeight: FontWeight.w600,
  );
  static TextStyle get headlineLarge => const TextStyle(
    fontFamily: _fontFamily, fontSize: 22, fontWeight: FontWeight.w600,
  );
  static TextStyle get headlineMedium => const TextStyle(
    fontFamily: _fontFamily, fontSize: 20, fontWeight: FontWeight.w600,
  );
  static TextStyle get headlineSmall => const TextStyle(
    fontFamily: _fontFamily, fontSize: 18, fontWeight: FontWeight.w500,
  );
  static TextStyle get titleLarge => const TextStyle(
    fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.w500,
  );
  static TextStyle get titleMedium => const TextStyle(
    fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w500,
  );
  static TextStyle get titleSmall => const TextStyle(
    fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.w500,
  );
  static TextStyle get bodyLarge => const TextStyle(
    fontFamily: _fontFamily, fontSize: 16, fontWeight: FontWeight.normal,
  );
  static TextStyle get bodyMedium => const TextStyle(
    fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.normal,
  );
  static TextStyle get bodySmall => const TextStyle(
    fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.normal,
  );
  static TextStyle get labelLarge => const TextStyle(
    fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w500,
  );
  static TextStyle get labelSmall => const TextStyle(
    fontFamily: _fontFamily, fontSize: 11, fontWeight: FontWeight.w500,
  );
  static TextStyle get button => const TextStyle(
    fontFamily: _fontFamily, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5,
  );
  static TextStyle get caption => const TextStyle(
    fontFamily: _fontFamily, fontSize: 12, fontWeight: FontWeight.normal,
  );
  static TextStyle get overline => const TextStyle(
    fontFamily: _fontFamily, fontSize: 10, fontWeight: FontWeight.normal, letterSpacing: 1.5,
  );
}
''';
  String get _appTheme => '''import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';
class AppTheme {
  AppTheme._();
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ),
    fontFamily: 'AppFont',
    textTheme: TextTheme(
      displayLarge: AppTextStyles.displayLarge,
      displayMedium: AppTextStyles.displayMedium,
      displaySmall: AppTextStyles.displaySmall,
      headlineLarge: AppTextStyles.headlineLarge,
      headlineMedium: AppTextStyles.headlineMedium,
      headlineSmall: AppTextStyles.headlineSmall,
      titleLarge: AppTextStyles.titleLarge,
      titleMedium: AppTextStyles.titleMedium,
      titleSmall: AppTextStyles.titleSmall,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.labelLarge,
      labelSmall: AppTextStyles.labelSmall,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ),
    fontFamily: 'AppFont',
  );
}
''';
  String get _spacing => '''class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double screenPadding = md;
  static const double cardPadding = md;
  static const double listSpacing = sm;
  static const double sectionSpacing = lg;
}
''';
  String get _radius => '''class AppRadius {
  AppRadius._();
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 9999;
  static const double button = md;
  static const double card = md;
  static const double input = md;
  static const double dialog = lg;
}
''';
}
