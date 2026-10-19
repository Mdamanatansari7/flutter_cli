import 'dart:io';

import 'package:dart_console/dart_console.dart';

/// Minimal arrow-key list selectors that render with raw, unpadded
/// writes instead of going through `interact`'s `Select`/`MultiSelect`.
///
/// Those components render every line via dart_console's
/// `Console.writeLine()`, which pads each line with spaces out to the
/// full terminal width for alignment. On terminals where a line that
/// reaches exactly the last column is ambiguous about whether the
/// cursor wrapped to the next row, that padding corrupts the
/// erase-and-redraw cycle on every keypress — the menu fills up with
/// duplicated lines. `Console.write()` is a raw passthrough with no
/// padding, so lines this short never approach the terminal width and
/// the ambiguity never comes up.
class TerminalMenu {
  TerminalMenu._();

  static final Console _console = Console();

  static bool get _ansi => stdout.supportsAnsiEscapes;

  /// Same pink used by NinjaUI's file trees (256-color 213) — kept
  /// local since this file has no access to NinjaUI's private helpers.
  static String _pink(String text) =>
      _ansi ? '\x1B[38;5;213m$text\x1B[0m' : text;

  /// Leaves a small pink tree branch behind after a selection, so the
  /// choice stays visible in scrollback instead of vanishing along
  /// with the rest of the erased menu.
  static void _confirmSelection(String chosenLine) {
    _console.write('  ${_pink('└──')} $chosenLine\n');
  }

  /// Arrow-key single choice. [render] returns the exact line to print
  /// for option [index], given whether it's the currently active one.
  /// Returns the chosen index.
  static int select({
    required String prompt,
    required int optionCount,
    required String Function(int index, bool active) render,
    int initialIndex = 0,
  }) {
    var index = initialIndex;
    _console.write('$prompt\n');
    _console.hideCursor();
    _draw(optionCount, (i) => render(i, i == index));

    while (true) {
      final key = _readKey();
      if (key.controlChar == ControlCharacter.arrowUp) {
        index = (index - 1) % optionCount;
      } else if (key.controlChar == ControlCharacter.arrowDown) {
        index = (index + 1) % optionCount;
      } else if (key.controlChar == ControlCharacter.enter) {
        _erase(optionCount);
        _console.showCursor();
        _confirmSelection(render(index, false));
        return index;
      } else {
        continue;
      }
      _erase(optionCount);
      _draw(optionCount, (i) => render(i, i == index));
    }
  }

  /// Arrow-key + space multi-choice. [render] returns the exact line
  /// to print for option [index], given active/checked state. Returns
  /// the sorted list of checked indices.
  static List<int> multiSelect({
    required String prompt,
    required int optionCount,
    required String Function(int index, bool active, bool checked) render,
    List<bool>? defaults,
  }) {
    var index = 0;
    final checked = <int>{
      if (defaults != null)
        for (var i = 0; i < defaults.length; i++)
          if (defaults[i]) i,
    };
    _console.write('$prompt\n');
    _console.hideCursor();
    _draw(optionCount, (i) => render(i, i == index, checked.contains(i)));

    while (true) {
      final key = _readKey();
      if (key.controlChar == ControlCharacter.arrowUp) {
        index = (index - 1) % optionCount;
      } else if (key.controlChar == ControlCharacter.arrowDown) {
        index = (index + 1) % optionCount;
      } else if (!key.isControl && key.char == ' ') {
        if (!checked.add(index)) checked.remove(index);
      } else if (key.controlChar == ControlCharacter.enter) {
        _erase(optionCount);
        _console.showCursor();
        final result = checked.toList()..sort();
        return result;
      } else {
        continue;
      }
      _erase(optionCount);
      _draw(optionCount, (i) => render(i, i == index, checked.contains(i)));
    }
  }

  static Key _readKey() {
    final key = _console.readKey();
    if (key.controlChar == ControlCharacter.ctrlC) {
      _console.showCursor();
      exit(130);
    }
    return key;
  }

  static void _draw(int count, String Function(int) render) {
    for (var i = 0; i < count; i++) {
      _console.write('${render(i)}\n');
    }
  }

  static void _erase(int n) {
    for (var i = 0; i < n; i++) {
      _console.cursorUp();
      _console.eraseLine();
    }
  }
}
