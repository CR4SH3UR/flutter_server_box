import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/src/rust/frb_generated.dart';

void main() {
  test('FRB external-library stem is sbm_ffi, not the codegen UNKNOWN fallback', () {
    // Android loads `lib$stem.so` via dlopen. Codegen writes UNKNOWN when
    // `cargo metadata` cannot resolve crates/sbm_ffi (wrong rustc, broken
    // workspace). That ships as libUNKNOWN.so and RustLib.init dies at launch.
    expect(
      RustLib.kDefaultExternalLibraryLoaderConfig.stem,
      'sbm_ffi',
    );
  });
}
