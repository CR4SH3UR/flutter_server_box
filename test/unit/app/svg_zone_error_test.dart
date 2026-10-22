/// The `StateError` flutter_svg throws from `encodeSvg` in `compute`.
///
/// That is the object the zone handler in `main.dart` sees with the isolate
/// stack `SvgParser._parseTree` → `_RemoteRunner._run`. A document with no
/// `svg` root is how `_parseTree` decides the data is invalid.
///
/// `SvgLoader.loadBytes` always goes through `svg.cache.putIfAbsent`, and
/// that cache attaches a `.then` with no `onError`. The picture's own
/// future is handled (errorBuilder, or the await below); the orphan
/// `.then` future is not, and that is the zone leak.
library;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/crash_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a document with no svg root is the invalid-svg StateError', () async {
    svg.cache.clear();
    Object? caught;
    try {
      await const SvgStringLoader('<html/>').loadBytes(null);
    } catch (e) {
      caught = e;
    }
    expect(caught, isNotNull);
    expect(CrashReport.isInvalidSvg(caught!), isTrue);
    expect(CrashReport.isAppFault(caught!), isFalse);
  });

  test('the cache .then with no onError is the zone leak', () async {
    svg.cache.clear();
    final leaked = <Object>[];
    await runZonedGuarded(() async {
      try {
        await const SvgStringLoader('<html/>').loadBytes(null);
      } catch (_) {
        // The loader's own future is what errorBuilder would catch.
      }
      // The cache's orphan `.then` reports on a later microtask.
      await Future<void>.delayed(Duration.zero);
    }, (e, _) => leaked.add(e));

    expect(leaked, isNotEmpty, reason: 'cache .then has no onError');
    expect(CrashReport.isInvalidSvg(leaked.first), isTrue);
    expect(CrashReport.isAppFault(leaked.first), isFalse);
  });
}
