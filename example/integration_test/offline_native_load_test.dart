import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rgb_sdk_flutter/rgb_sdk_flutter_advanced.dart';

// Public test-vector seed only. Never use this seed for a real wallet.
const _publicTestSeed =
    '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('offline native signer loads and reopens its isolated directory', (
    WidgetTester tester,
  ) async {
    expect(Platform.isAndroid || Platform.isIOS, isTrue);
    final artifact = await const RgbSdkFlutter().nativeArtifactInfo();
    expect(artifact.rlnVersion, RgbSdkFlutter.rlnVersion);

    final client = RlnClient();
    final scratch = await Directory.systemTemp.createTemp(
      'rgb-sdk-offline-native-load-',
    );
    final signerDirectory = Directory('${scratch.path}/signer');
    int? activeSigner;
    var nativeMayOwnStorage = false;

    Future<int> createSigner() async {
      // A failed/lost response does not establish that native creation had no
      // effect. Retain this test's directory if ownership becomes uncertain.
      nativeMayOwnStorage = true;
      final handle = await client.createNativeExternalSigner(
        seedHex: _publicTestSeed,
        network: 'regtest',
        permissivePolicy: false,
        storageDirPath: signerDirectory.path,
      );
      activeSigner = handle;
      expect(handle, greaterThan(0));
      final stat = await signerDirectory.stat();
      expect(stat.type, FileSystemEntityType.directory);
      if (stat.mode != 0) {
        expect(
          stat.mode & 0x1ff,
          0x1c0,
          reason: 'Signer directory must be 0700.',
        );
      }
      return handle;
    }

    Future<void> destroySigner() async {
      final handle = activeSigner;
      if (handle != null) {
        await client.destroyNativeExternalSigner(handle);
        activeSigner = null;
        nativeMayOwnStorage = false;
      }
    }

    try {
      final first = await createSigner();
      await destroySigner();
      // Reusing this exact directory forces the real native VLS store to reopen
      // after the preceding UniFFI handle release, through Pigeon and JNA/Swift.
      final reopened = await createSigner();
      expect(reopened, greaterThan(first));
      await destroySigner();
    } finally {
      await destroySigner();
      if (!nativeMayOwnStorage && await scratch.exists()) {
        await scratch.delete(recursive: true);
      }
    }
    expect(await scratch.exists(), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
