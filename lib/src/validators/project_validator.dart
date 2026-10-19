class ProjectValidator {
  static String? validateName(String name) {
    if (name.isEmpty) return 'Project name cannot be empty';
    if (name.length < 2) return 'Project name must be at least 2 characters';
    if (name.length > 50) return 'Project name must be at most 50 characters';
    if (!RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(name)) {
      return 'Project name must start with a lowercase letter and contain only lowercase letters, numbers, and underscores';
    }
    if (name == 'flutter' || name == 'dart' || name == 'test' || name == 'lib') {
      return 'Project name "$name" is reserved';
    }
    return null;
  }

  static String? validateBundleId(String bundleId) {
    if (bundleId.isEmpty) return 'Bundle ID cannot be empty';
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z][a-zA-Z0-9]*)+$').hasMatch(bundleId)) {
      return 'Invalid bundle ID format. Expected: com.example.app';
    }
    return null;
  }

  static String? validateDescription(String? description) {
    if (description != null && description.length > 200) {
      return 'Description must be at most 200 characters';
    }
    return null;
  }

  static String? validatePlatform(String platform) {
    final valid = ['ios', 'android', 'web', 'macos', 'windows', 'linux'];
    if (!valid.contains(platform.toLowerCase())) {
      return 'Invalid platform. Valid: ${valid.join(', ')}';
    }
    return null;
  }

  static bool isValidName(String name) {
    return !name.isEmpty && RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(name);
  }
}