import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../tool/android_elf.dart';
import '../tool/native_artifact_paths.dart';
import '../tool/verify_android_elf.dart';

void main() {
  test(
    'Maven resolution follows the exact coordinate rather than archive URL',
    () {
      final coordinate = MavenArtifactCoordinate.parse(
        'com.utexo.flutter:rgb-lightning-node-android:0.17.0-beta.3-16k.1',
      );
      expect(
        coordinate.cacheDirectory('/test'),
        '/test/.gradle/caches/modules-2/files-2.1/com.utexo.flutter/'
        'rgb-lightning-node-android/0.17.0-beta.3-16k.1',
      );
      expect(
        coordinate.fileName,
        'rgb-lightning-node-android-0.17.0-beta.3-16k.1.aar',
      );
      for (final invalid in <String>[
        '',
        'group:module',
        'group:module:version:extra',
        '../group:module:version',
        'group:../module:version',
        'group:module:../version',
        'group:..:version',
        'group:module:..',
        'group:module:version\n',
      ]) {
        expect(
          () => MavenArtifactCoordinate.parse(invalid),
          throwsFormatException,
          reason: invalid,
        );
      }
    },
  );
  test('64-bit native mapping and RELRO remain safe at 16 KiB', () {
    for (final abi in <String>['arm64-v8a', 'x86_64']) {
      final report = inspectAndroidElf(_fixture(abi: abi), abi);
      expect(report.compatible, true, reason: report.failures.join('\n'));
      expect(report.pageSize, 16384);
      expect(report.dynamicRelocations, true);
    }
  });

  test('32-bit Android keeps its 4 KiB policy', () {
    for (final abi in <String>['armeabi-v7a', 'x86']) {
      final report = inspectAndroidElf(
        _fixture(abi: abi, alignment: 4096),
        abi,
      );
      expect(report.compatible, true, reason: report.failures.join('\n'));
      expect(report.pageSize, 4096);
    }
  });

  test('every LOAD is checked, including a later 4 KiB LOAD', () {
    final bytes = _fixture();
    _word(bytes, 1, 48, 4096);
    final report = inspectAndroidElf(bytes, 'arm64-v8a');
    expect(report.compatible, false);
    expect(report.failures, contains(contains('LOAD[1] alignment')));
  });

  test('changing p_align alone cannot repair mismatched segment offsets', () {
    final bytes = _fixture();
    _word(bytes, 1, 16, 0x5000);
    expect(
      inspectAndroidElf(bytes, 'arm64-v8a').failures,
      contains(contains('incongruent')),
    );
  });

  test('invalid alignment and overlapping page permissions fail', () {
    final invalid = _fixture();
    _word(invalid, 0, 48, 0x5000);
    expect(inspectAndroidElf(invalid, 'arm64-v8a').compatible, false);
    final overlap = _fixture();
    _word(overlap, 0, 32, 0x4100);
    _word(overlap, 0, 40, 0x4100);
    expect(
      inspectAndroidElf(overlap, 'arm64-v8a').failures,
      contains(contains('different permissions')),
    );
    final writableCode = _fixture();
    ByteData.sublistView(writableCode).setUint32(64 + 4, 7, Endian.little);
    expect(
      inspectAndroidElf(writableCode, 'arm64-v8a').failures,
      contains(contains('writable and executable')),
    );
  });

  test('RELRO rounding cannot make ordinary writable data read-only', () {
    final suffix = _fixture();
    _word(suffix, 3, 32, 0x3000);
    _word(suffix, 3, 40, 0x3000);
    expect(
      inspectAndroidElf(suffix, 'arm64-v8a').failures,
      contains(contains('page rounding')),
    );
    final prefix = _fixture();
    _word(prefix, 3, 8, 0x4100);
    _word(prefix, 3, 16, 0x4100);
    _word(prefix, 3, 32, 0x3f00);
    _word(prefix, 3, 40, 0x3f00);
    expect(
      inspectAndroidElf(prefix, 'arm64-v8a').failures,
      contains(contains('page rounding')),
    );
  });

  test('RELRO alignment uses memory extent, allowing a larger file extent', () {
    final valid = _fixture();
    _word(valid, 3, 32, 0x5000);
    expect(inspectAndroidElf(valid, 'arm64-v8a').compatible, true);
    final badEnd = _fixture();
    _word(badEnd, 1, 32, 0x3000);
    _word(badEnd, 1, 40, 0x3000);
    _word(badEnd, 3, 32, 0x3000);
    _word(badEnd, 3, 40, 0x3000);
    expect(
      inspectAndroidElf(badEnd, 'arm64-v8a').compatible,
      true,
      reason: 'An entire LOAD can be RELRO without an aligned suffix.',
    );
    final padded = _fixture();
    _word(padded, 1, 32, 0x268);
    _word(padded, 1, 40, 0x268);
    _word(padded, 3, 32, 0x268);
    _word(padded, 3, 40, 0x1000);
    expect(
      inspectAndroidElf(padded, 'arm64-v8a').compatible,
      true,
      reason: 'Whole-LOAD RELRO may extend into zero-filled page padding.',
    );
  });

  test('RELRO outside writable LOAD and DYNAMIC mismatches fail', () {
    final relro = _fixture();
    _word(relro, 3, 16, 0x8000);
    _word(relro, 3, 40, 0x8000);
    expect(
      inspectAndroidElf(relro, 'arm64-v8a').failures,
      contains(contains('outside a writable LOAD')),
    );
    final dynamic = _fixture();
    _word(dynamic, 2, 8, 0x4200);
    expect(
      inspectAndroidElf(dynamic, 'arm64-v8a').failures,
      contains(contains('DYNAMIC has invalid size or LOAD geometry')),
    );
    final outside = _fixture();
    _word(outside, 2, 8, 0x8100);
    _word(outside, 2, 16, 0x8100);
    ByteData.sublistView(outside).setUint64(0x8100, 7, Endian.little);
    ByteData.sublistView(outside).setUint64(0x8108, 1, Endian.little);
    expect(
      inspectAndroidElf(outside, 'arm64-v8a').failures,
      contains(contains('outside GNU_RELRO')),
    );
  });

  test('dynamic relocations need RELRO and a terminated dynamic table', () {
    final noRelro = _fixture();
    ByteData.sublistView(noRelro).setUint32(64 + 3 * 56, 0, Endian.little);
    expect(
      inspectAndroidElf(noRelro, 'arm64-v8a').failures,
      contains(contains('without GNU_RELRO')),
    );
    final unterminated = _fixture();
    _word(unterminated, 2, 32, 16);
    _word(unterminated, 2, 40, 16);
    expect(
      inspectAndroidElf(unterminated, 'arm64-v8a').failures,
      contains(contains('no DT_NULL')),
    );
    final textRelocations = _fixture();
    ByteData.sublistView(textRelocations).setUint64(0x4100, 22, Endian.little);
    expect(
      inspectAndroidElf(textRelocations, 'arm64-v8a').failures,
      contains(contains('text relocations')),
    );
  });

  test(
    'malformed bounds, unsupported headers and integer overflow fail closed',
    () {
      final corruptions = <void Function(Uint8List)>[
        (b) => b[0] = 0,
        (b) => b[4] = 1,
        (b) => b[5] = 2,
        (b) => b[6] = 0,
        (b) => ByteData.sublistView(b).setUint16(16, 2, Endian.little),
        (b) => ByteData.sublistView(b).setUint16(18, 62, Endian.little),
        (b) => ByteData.sublistView(b).setUint16(52, 0, Endian.little),
        (b) => ByteData.sublistView(b).setUint16(54, 8, Endian.little),
        (b) => ByteData.sublistView(b).setUint16(56, 0, Endian.little),
        (b) => ByteData.sublistView(b).setUint16(56, 0xffff, Endian.little),
        (b) => ByteData.sublistView(b).setUint64(32, 0xffff, Endian.little),
        (b) => ByteData.sublistView(b).setUint32(36, 0x80000000, Endian.little),
        (b) => _word(b, 1, 8, 0xc000),
        (b) => _word(b, 1, 40, 1),
        (b) => _word(b, 1, 16, 0x7fffffffffffffff),
        // The sum itself fits, but rounding the end up to a 16 KiB page would
        // overflow a native Dart int. Reject before any geometry arithmetic.
        (b) {
          _word(b, 1, 16, 0x7fffffffffffe000);
          _word(b, 1, 32, 1);
          _word(b, 1, 40, 1);
        },
      ];
      for (var i = 0; i < corruptions.length; i++) {
        final bytes = _fixture();
        corruptions[i](bytes);
        expect(
          () => inspectAndroidElf(bytes, 'arm64-v8a'),
          throwsFormatException,
          reason: 'corruption $i',
        );
      }
      expect(
        () => inspectAndroidElf(Uint8List(15), 'arm64-v8a'),
        throwsFormatException,
      );
      expect(
        () => inspectAndroidElf(_fixture(), 'unknown'),
        throwsFormatException,
      );
    },
  );

  test('missing LOAD and duplicate DYNAMIC cannot pass', () {
    final noLoad = _fixture();
    final data = ByteData.sublistView(noLoad);
    data.setUint32(64, 0, Endian.little);
    data.setUint32(64 + 56, 0, Endian.little);
    expect(inspectAndroidElf(noLoad, 'arm64-v8a').compatible, false);
    final multiple = _fixture();
    ByteData.sublistView(multiple).setUint32(64 + 3 * 56, 2, Endian.little);
    expect(
      inspectAndroidElf(multiple, 'arm64-v8a').failures,
      contains(contains('exactly one PT_DYNAMIC')),
    );
  });

  test(
    'archive validation inspects auxiliary libraries and exact ABI inventory',
    () async {
      final bad = _fixture(alignment: 4096);
      await _withArchive(
        <(String, Uint8List)>[
          ('jni/arm64-v8a/librgb_lightning_node.so', _fixture()),
          ('jni/arm64-v8a/libauxiliary.so', bad),
        ],
        (archive) async {
          final report = await inspectAndroidArchive(archive, 'aar', <String>{
            'arm64-v8a',
          });
          expect(report['compatible'], false);
          expect(report['libraries'], hasLength(2));
          expect(
            (report['failures']! as List<String>).join(),
            contains('libauxiliary.so'),
          );
        },
      );
      await _withArchive(
        <(String, Uint8List)>[('lib/arm64-v8a/libvalid.so', _fixture())],
        (archive) async {
          final report = await inspectAndroidArchive(archive, 'apk', <String>{
            'arm64-v8a',
            'x86_64',
          });
          expect(report['compatible'], false);
          expect(report['apkZipAlignment'], 'not-checked');
        },
      );
    },
  );

  test(
    'duplicate, traversing, unknown or absent library entries fail closed',
    () async {
      for (final names in <List<String>>[
        <String>['jni/arm64-v8a/lib.so', 'jni/arm64-v8a/lib.so'],
        <String>['jni/arm64-v8a/../lib.so'],
        <String>['jni/unknown/lib.so'],
        <String>['assets/lib.so'],
        <String>['empty.txt'],
      ]) {
        await _withArchive(names.map((name) => (name, _fixture())).toList(), (
          archive,
        ) async {
          await expectLater(
            inspectAndroidArchive(archive, 'aar', <String>{'arm64-v8a'}),
            throwsFormatException,
          );
        });
      }
    },
  );

  test(
    'a correct AAB validates every declared ABI but claims no APK ZIP proof',
    () async {
      await _withArchive(
        <(String, Uint8List)>[
          ('base/lib/arm64-v8a/libfirst.so', _fixture()),
          ('base/lib/x86_64/libsecond.so', _fixture(abi: 'x86_64')),
          (
            'base/lib/armeabi-v7a/libthird.so',
            _fixture(abi: 'armeabi-v7a', alignment: 4096),
          ),
        ],
        (archive) async {
          final report = await inspectAndroidArchive(archive, 'aab', <String>{
            'arm64-v8a',
            'x86_64',
            'armeabi-v7a',
          });
          expect(
            report['compatible'],
            true,
            reason: report['failures'].toString(),
          );
          expect(report['libraries'], hasLength(3));
          expect(report['apkZipAlignment'], 'not-checked');
        },
      );
    },
  );
}

Uint8List _fixture({String abi = 'arm64-v8a', int alignment = 16384}) {
  final (elfClass, machine, _) = androidElfAbis[abi]!;
  final is64 = elfClass == 2;
  final bytes = Uint8List(0xc000);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 7, <int>[0x7f, 0x45, 0x4c, 0x46, elfClass, 1, 1]);
  data.setUint16(16, 3, Endian.little);
  data.setUint16(18, machine, Endian.little);
  data.setUint32(20, 1, Endian.little);
  if (is64) {
    data.setUint64(32, 64, Endian.little);
  } else {
    data.setUint32(28, 52, Endian.little);
  }
  data.setUint16(is64 ? 52 : 40, is64 ? 64 : 52, Endian.little);
  data.setUint16(is64 ? 54 : 42, is64 ? 56 : 32, Endian.little);
  data.setUint16(is64 ? 56 : 44, 4, Endian.little);
  final segments = <List<int>>[
    <int>[1, 5, 0, 0, 0x4000, 0x4000, alignment],
    <int>[1, 6, 0x4000, 0x4000, 0x8000, 0x8000, alignment],
    <int>[2, 6, 0x4100, 0x4100, is64 ? 32 : 16, is64 ? 32 : 16, is64 ? 8 : 4],
    <int>[0x6474e552, 4, 0x4000, 0x4000, 0x4000, 0x4000, 1],
  ];
  for (var i = 0; i < segments.length; i++) {
    final row = segments[i];
    final start = (is64 ? 64 : 52) + i * (is64 ? 56 : 32);
    data.setUint32(start, row[0], Endian.little);
    data.setUint32(start + (is64 ? 4 : 24), row[1], Endian.little);
    final offsets = is64 ? <int>[8, 16, 32, 40, 48] : <int>[4, 8, 16, 20, 28];
    for (var j = 0; j < offsets.length; j++) {
      if (is64) {
        data.setUint64(start + offsets[j], row[j + 2], Endian.little);
      } else {
        data.setUint32(start + offsets[j], row[j + 2], Endian.little);
      }
    }
  }
  if (is64) {
    data.setUint64(0x4100, 7, Endian.little);
    data.setUint64(0x4108, 0x1000, Endian.little);
  } else {
    data.setUint32(0x4100, 17, Endian.little);
    data.setUint32(0x4104, 0x1000, Endian.little);
  }
  return bytes;
}

void _word(Uint8List bytes, int segment, int displacement, int value) =>
    ByteData.sublistView(
      bytes,
    ).setUint64(64 + segment * 56 + displacement, value, Endian.little);

Future<void> _withArchive(
  List<(String, Uint8List)> entries,
  Future<void> Function(File) body,
) async {
  final directory = await Directory.systemTemp.createTemp('android-elf-test-');
  try {
    final file = File('${directory.path}/fixture.zip');
    await file.writeAsBytes(_zip(entries));
    await body(file);
  } finally {
    await directory.delete(recursive: true);
  }
}

// Minimal stored ZIP writer permits duplicate/traversing central-directory
// fixtures, which normal archive-creation tools may silently normalize away.
Uint8List _zip(List<(String, Uint8List)> entries) {
  final output = BytesBuilder();
  final directory = BytesBuilder();
  Uint8List words(List<(int, int)> fields) {
    final size = fields.fold(0, (sum, field) => sum + field.$1);
    final bytes = Uint8List(size);
    final data = ByteData.sublistView(bytes);
    var offset = 0;
    for (final (width, value) in fields) {
      if (width == 2) {
        data.setUint16(offset, value, Endian.little);
      } else {
        data.setUint32(offset, value, Endian.little);
      }
      offset += width;
    }
    return bytes;
  }

  for (final (name, payload) in entries) {
    final nameBytes = name.codeUnits;
    var crc = 0xffffffff;
    for (final byte in payload) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = crc & 1 != 0 ? (crc >>> 1) ^ 0xedb88320 : crc >>> 1;
      }
    }
    crc ^= 0xffffffff;
    final offset = output.length;
    output.add(
      words(<(int, int)>[
        (4, 0x04034b50),
        (2, 20),
        (2, 0),
        (2, 0),
        (2, 0),
        (2, 0),
        (4, crc),
        (4, payload.length),
        (4, payload.length),
        (2, nameBytes.length),
        (2, 0),
      ]),
    );
    output.add(nameBytes);
    output.add(payload);
    directory.add(
      words(<(int, int)>[
        (4, 0x02014b50),
        (2, 20),
        (2, 20),
        (2, 0),
        (2, 0),
        (2, 0),
        (2, 0),
        (4, crc),
        (4, payload.length),
        (4, payload.length),
        (2, nameBytes.length),
        (2, 0),
        (2, 0),
        (2, 0),
        (2, 0),
        (4, 0),
        (4, offset),
      ]),
    );
    directory.add(nameBytes);
  }
  final directoryOffset = output.length;
  output.add(directory.takeBytes());
  output.add(
    words(<(int, int)>[
      (4, 0x06054b50),
      (2, 0),
      (2, 0),
      (2, entries.length),
      (2, entries.length),
      (4, output.length - directoryOffset),
      (4, directoryOffset),
      (2, 0),
    ]),
  );
  return output.takeBytes();
}
