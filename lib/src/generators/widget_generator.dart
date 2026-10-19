import 'dart:io';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

class WidgetGenerator {
  final Logger _logger;
  WidgetGenerator(this._logger);
  Future<void> generate(String name,
      {String? feature, String? path, bool dryRun = false}) async {
    final cn = _pascalCase(name);
    var outputDir = path;
    if (outputDir == null) {
      if (feature != null) {
        outputDir = p.join(Directory.current.path, 'lib', 'features',
            _toSnakeCase(feature), 'widgets');
      } else {
        outputDir = p.join(Directory.current.path, 'lib', 'core', 'widgets');
      }
    }
    final outputPath = p.join(outputDir, '${_toSnakeCase(name)}_widget.dart');
    String content;
    switch (name.toLowerCase()) {
      case 'button':
        content = _buttonWidget(cn);
        break;
      case 'textfield':
      case 'text_field':
        content = _textFieldWidget(cn);
        break;
      case 'card':
        content = _cardWidget(cn);
        break;
      case 'loading':
        content = _loadingWidget(cn);
        break;
      case 'error':
        content = _errorWidget(cn);
        break;
      case 'empty':
        content = _emptyWidget(cn);
        break;
      default:
        content = _defaultWidget(cn);
    }
    if (dryRun) {
      _logger.info('Would create widget: $outputPath');
      _logger.detail(content);
    } else {
      await File(outputPath).create(recursive: true);
      await File(outputPath).writeAsString(content);
      _logger.success('Widget created: $outputPath');
    }
  }

  String _defaultWidget(String cn) => '''import 'package:flutter/material.dart';
class ${cn}Widget extends StatelessWidget {
  const ${cn}Widget({super.key});
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
''';
  String _buttonWidget(String cn) => '''import 'package:flutter/material.dart';
class ${cn}Widget extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  const ${cn}Widget({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon), const SizedBox(width: 8)],
                Text(label),
              ]),
      ),
    );
  }
}
''';
  String _textFieldWidget(String cn) =>
      '''import 'package:flutter/material.dart';
class ${cn}Widget extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  const ${cn}Widget({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
  });
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}
''';
  String _cardWidget(String cn) => '''import 'package:flutter/material.dart';
class ${cn}Widget extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  const ${cn}Widget({super.key, required this.child, this.padding, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
      ),
    );
  }
}
''';
  String _loadingWidget(String cn) => '''import 'package:flutter/material.dart';
class ${cn}Widget extends StatelessWidget {
  final String? message;
  const ${cn}Widget({super.key, this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[const SizedBox(height: 16), Text(message!)],
        ],
      ),
    );
  }
}
''';
  String _errorWidget(String cn) => '''import 'package:flutter/material.dart';
class ${cn}Widget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ${cn}Widget({super.key, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message),
            if (onRetry != null) ...[const SizedBox(height: 16), ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))],
          ],
        ),
      ),
    );
  }
}
''';
  String _emptyWidget(String cn) => '''import 'package:flutter/material.dart';
class ${cn}Widget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const ${cn}Widget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle!)],
            if (actionLabel != null && onAction != null) ...[const SizedBox(height: 24), ElevatedButton(onPressed: onAction, child: Text(actionLabel!))],
          ],
        ),
      ),
    );
  }
}
''';
  String _pascalCase(String input) {
    return input
        .split(RegExp(r'[_\s-]'))
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join();
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
            RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')
        .replaceAll(RegExp(r'^_'), '')
        .toLowerCase();
  }
}
