import 'dart:async';

import 'package:flutter/services.dart';
import 'package:xterm/core.dart';

/// Puts a terminal selection on the system clipboard once it has settled.
///
/// On a phone there is no right-click, and the selection toolbar's Copy sits
/// under the finger that just made the range. Selecting *is* copying, as it
/// is in every other mobile SSH client. Waiting a beat is what keeps a handle
/// drag from writing every intermediate range.
class TerminalSelectionClipboard {
  TerminalSelectionClipboard({
    required this.readSelection,
    this.settle = const Duration(milliseconds: 180),
  });

  /// The text currently selected, or null when nothing is.
  final String? Function() readSelection;

  /// How long the selection must sit still before it is written.
  final Duration settle;

  Timer? _timer;
  String? _lastCopied;

  /// Call whenever the controller's selection changes.
  void selectionChanged({required bool selected}) {
    _timer?.cancel();
    if (!selected) {
      // A fresh range must be written even if it happens to match what was
      // copied last: clearing is what says the previous copy is done with.
      _lastCopied = null;
      return;
    }
    _timer = Timer(settle, () => unawaited(copyNow()));
  }

  /// Writes [readSelection] now. No-op when it is empty or already there.
  Future<void> copyNow() async {
    final text = readSelection();
    if (text == null || text.isEmpty || text == _lastCopied) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      _lastCopied = text;
    } on PlatformException {
      // Same as the toolbar's copy: the clipboard can refuse, and nothing is
      // waiting to hear about it.
    }
  }

  void dispose() => _timer?.cancel();
}

/// The selected text of [terminal], or null when [controller] has none.
///
/// Read off the buffer rather than the render object, so a copy can happen
/// before the view has a size — and so a test does not need one.
String? selectedTerminalText(Terminal terminal, TerminalController controller) {
  final selection = controller.selection;
  if (selection == null) return null;
  return terminal.buffer.getText(selection);
}
