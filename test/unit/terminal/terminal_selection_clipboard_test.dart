import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/ssh/terminal_selection_clipboard.dart';
import 'package:xterm/core.dart';
import 'package:xterm/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final clipboard = <String>[];

  setUp(() {
    clipboard.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  (Terminal, TerminalController) filled() {
    final terminal = Terminal();
    terminal.resize(20, 6);
    terminal.write('hello world');
    final controller = TerminalController();
    controller.setSelection(
      terminal.buffer.createAnchor(0, 0),
      terminal.buffer.createAnchor(5, 0),
    );
    return (terminal, controller);
  }

  test('copies the selection after it has settled', () async {
    final (terminal, controller) = filled();
    final helper = TerminalSelectionClipboard(
      readSelection: () => selectedTerminalText(terminal, controller),
      settle: Duration.zero,
    );
    addTearDown(helper.dispose);

    helper.selectionChanged(selected: true);
    await Future<void>.delayed(Duration.zero);

    expect(clipboard, hasLength(1));
    expect(clipboard.single, contains('hello'));
  });

  test('does not copy until the selection has sat still', () async {
    final (terminal, controller) = filled();
    final helper = TerminalSelectionClipboard(
      readSelection: () => selectedTerminalText(terminal, controller),
      settle: const Duration(milliseconds: 40),
    );
    addTearDown(helper.dispose);

    helper.selectionChanged(selected: true);
    expect(clipboard, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(clipboard, isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(clipboard, hasLength(1));
  });

  test('a later change replaces the pending copy', () async {
    final (terminal, controller) = filled();
    final helper = TerminalSelectionClipboard(
      readSelection: () => selectedTerminalText(terminal, controller),
      settle: const Duration(milliseconds: 30),
    );
    addTearDown(helper.dispose);

    helper.selectionChanged(selected: true);
    controller.setSelection(
      terminal.buffer.createAnchor(6, 0),
      terminal.buffer.createAnchor(11, 0),
    );
    helper.selectionChanged(selected: true);

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(clipboard, hasLength(1));
    expect(clipboard.single, contains('world'));
  });

  test('clearing the selection copies nothing', () async {
    final (terminal, controller) = filled();
    final helper = TerminalSelectionClipboard(
      readSelection: () => selectedTerminalText(terminal, controller),
      settle: Duration.zero,
    );
    addTearDown(helper.dispose);

    helper.selectionChanged(selected: true);
    helper.selectionChanged(selected: false);
    await Future<void>.delayed(Duration.zero);

    expect(clipboard, isEmpty);
  });

  test('the same text is not written twice', () async {
    final (terminal, controller) = filled();
    final helper = TerminalSelectionClipboard(
      readSelection: () => selectedTerminalText(terminal, controller),
      settle: Duration.zero,
    );
    addTearDown(helper.dispose);

    helper.selectionChanged(selected: true);
    await Future<void>.delayed(Duration.zero);
    helper.selectionChanged(selected: true);
    await Future<void>.delayed(Duration.zero);

    expect(clipboard, hasLength(1));
  });

  test('clearing then selecting the same text copies it again', () async {
    final (terminal, controller) = filled();
    final helper = TerminalSelectionClipboard(
      readSelection: () => selectedTerminalText(terminal, controller),
      settle: Duration.zero,
    );
    addTearDown(helper.dispose);

    helper.selectionChanged(selected: true);
    await Future<void>.delayed(Duration.zero);
    helper.selectionChanged(selected: false);
    helper.selectionChanged(selected: true);
    await Future<void>.delayed(Duration.zero);

    expect(clipboard, hasLength(2));
    expect(clipboard, everyElement(contains('hello')));
  });

  test('a clipboard that refuses is not an error', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'Clipboard error');
          }
          return null;
        });
    final (terminal, controller) = filled();
    final helper = TerminalSelectionClipboard(
      readSelection: () => selectedTerminalText(terminal, controller),
      settle: Duration.zero,
    );
    addTearDown(helper.dispose);

    helper.selectionChanged(selected: true);
    await Future<void>.delayed(Duration.zero);

    expect(clipboard, isEmpty);
  });

  test('selectedTerminalText is null when nothing is selected', () {
    final terminal = Terminal();
    final controller = TerminalController();
    expect(selectedTerminalText(terminal, controller), isNull);
  });
}
