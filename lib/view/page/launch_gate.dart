import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/app.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/schema_too_new.dart';

/// What [LaunchGate] is showing while [main] finishes (or fails) startup.
///
/// The Android / iOS splash theme stays up until Flutter draws a first frame.
/// `_initApp` used to run to completion *before* `runApp`, so any throw other
/// than [SchemaTooNewException] — and any hang — left that splash on screen
/// forever with no window and no message. This gate is the window: loading
/// first, then the real app, the schema-too-new rescue, or a failure page.
sealed class LaunchState {
  const LaunchState();
}

final class LaunchLoading extends LaunchState {
  const LaunchLoading();
}

final class LaunchReady extends LaunchState {
  const LaunchReady();
}

final class LaunchSchemaTooNew extends LaunchState {
  const LaunchSchemaTooNew(this.err);
  final SchemaTooNewException err;
}

final class LaunchFailed extends LaunchState {
  const LaunchFailed(this.error, this.stack);
  final Object error;
  final StackTrace stack;
}

/// Root widget put up at once so the platform splash can go away.
class LaunchGate extends StatelessWidget {
  const LaunchGate({
    super.key,
    required this.container,
    required this.state,
  });

  final ProviderContainer container;
  final ValueNotifier<LaunchState> state;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LaunchState>(
      valueListenable: state,
      builder: (context, phase, _) => switch (phase) {
        LaunchReady() => UncontrolledProviderScope(
          container: container,
          child: const MyApp(),
        ),
        LaunchSchemaTooNew(:final err) => SchemaTooNewApp(err: err),
        LaunchFailed(:final error) => StartupFailedApp(error: error),
        LaunchLoading() => const _LaunchLoadingApp(),
      },
    );
  }
}

class _LaunchLoadingApp extends StatelessWidget {
  const _LaunchLoadingApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              SizedBox(height: 24),
              Text(BuildData.name),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when startup throws something other than [SchemaTooNewException].
///
/// Same thin `MaterialApp` shape as [SchemaTooNewApp]: no stores, no providers.
class StartupFailedApp extends StatelessWidget {
  const StartupFailedApp({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: LocaleUtil.resolve,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ).fixWindowsFont,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ).fixWindowsFont,
      home: Builder(
        builder: (context) {
          context.setLibL10n();
          return _StartupFailedPage(error: error);
        },
      ),
    );
  }
}

class _StartupFailedPage extends StatelessWidget {
  const _StartupFailedPage({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 37),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.error_outline, size: 57, color: scheme.error),
                  UIs.height13,
                  Text(
                    l10n.startupFailedTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  UIs.height13,
                  Text(
                    l10n.startupFailedBody,
                    style: UIs.textGrey,
                    textAlign: TextAlign.center,
                  ),
                  UIs.height13,
                  SelectableText(
                    '$error',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  UIs.height13,
                  FilledButton(
                    onPressed: () => SystemNavigator.pop(),
                    child: Text(libL10n.ok),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
