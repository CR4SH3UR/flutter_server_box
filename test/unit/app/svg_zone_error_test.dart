/// The `StateError` flutter_svg throws from `encodeSvg` in `compute`.
///
/// That is the object the zone handler in `main.dart` sees with the isolate
/// stack `SvgParser._parseTree` → `_RemoteRunner._run`. A document with no
/// `svg` root is how `_parseTree` decides the data is invalid.
///
/// The cache leak itself (`svg.cache.putIfAbsent` attaches `.then` with no
/// `onError`) does not show up here: debug builds use `_testCompute`, which
/// never goes through `_RemoteRunner`.
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
    if (caught == null) fail('encodeSvg did not throw');
    expect(CrashReport.isInvalidSvg(caught), isTrue);
    expect(CrashReport.isAppFault(caught), isFalse);
  });
}
