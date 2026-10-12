import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/api_export_graph.dart';

void main() {
  Map<String, DartExportVisibility> graph(Map<String, String> sources) =>
      collectDartExportGraph(
        entrypoints: ['lib/root.dart'],
        readSource: (path) => sources[path]!,
      );

  test(
    'real entrypoints snapshot new burn, signer and WebRGB error contracts',
    () {
      final files = collectDartExportGraph(
        entrypoints: [
          'lib/rgb_sdk_flutter.dart',
          'lib/rgb_sdk_flutter_advanced.dart',
          'lib/rgb_sdk_flutter_webrgb.dart',
        ],
        readSource: (path) => File(path).readAsStringSync(),
      );
      expect(
        files['lib/src/models/burn_models.dart']!.allows('BurnParams'),
        true,
      );
      expect(
        files['lib/src/models/burn_models.dart']!.allows('burnHex32'),
        false,
      );
      expect(
        files['lib/src/wallet/rln_signers.dart']!.allows('RlnSigner'),
        true,
      );
      expect(files['lib/src/crypto/message.dart']!.allows('signMessage'), true);
      expect(
        files['lib/src/integrations/webrgb/errors.dart']!.allows('WebRgbError'),
        true,
      );
      expect(
        files['lib/src/integrations/webrgb/errors.dart']!.allows(
          'webRgbWalletCall',
        ),
        false,
      );
      expect(
        files['lib/src/integrations/webrgb/types.dart']!.allows('payoutJson'),
        false,
      );
    },
  );

  test('multiline exports include burn models and preserve combinators', () {
    final files = graph({
      'lib/root.dart':
          "export 'src/burn.dart'\n show BurnParams, BurnResult\n hide BurnResult;",
      'lib/src/burn.dart':
          'class BurnParams {} class BurnResult {} class Internal {}',
    });
    final burn = files['lib/src/burn.dart']!;
    expect(burn.allows('BurnParams'), true);
    expect(burn.allows('BurnResult'), false);
    expect(burn.allows('Internal'), false);
    expect(burn.allows('_Private'), false);
  });

  test('transitive barrels union visibility without widening hidden names', () {
    final sources = {
      'lib/root.dart': "export 'a.dart' show A; export 'b.dart' show B;",
      'lib/a.dart': "export 'model.dart';",
      'lib/b.dart': "export 'model.dart';",
      'lib/model.dart': 'class A {} class B {} class C {}',
    };
    final names = graph(sources)['lib/model.dart']!;
    expect(names.allows('A'), true);
    expect(names.allows('B'), true);
    expect(names.allows('C'), false);
    final reversed = graph({
      ...sources,
      'lib/root.dart': "export 'b.dart' show B; export 'a.dart' show A;",
    });
    expect(names.fingerprint, reversed['lib/model.dart']!.fingerprint);
  });

  test('parts and export cycles converge with repeated hide/show paths', () {
    final files = graph({
      'lib/root.dart': "export 'a.dart' hide B; export 'a.dart' show B;",
      'lib/a.dart': "export 'b.dart'; part 'part.dart';",
      'lib/b.dart': "export 'a.dart';",
      'lib/part.dart': "part of 'a.dart'; class A {} class B {}",
    });
    expect(files.keys.toSet(), {
      'lib/root.dart',
      'lib/a.dart',
      'lib/b.dart',
      'lib/part.dart',
    });
    expect(files['lib/part.dart']!.allows('A'), true);
    expect(files['lib/part.dart']!.allows('B'), true);
  });

  test(
    'conditional and external exports fail closed instead of disappearing',
    () {
      for (final source in [
        "export 'a.dart' if (dart.library.io) 'b.dart';",
        "export 'package:external/api.dart';",
      ]) {
        expect(() => graph({'lib/root.dart': source}), throwsStateError);
      }
    },
  );
}
