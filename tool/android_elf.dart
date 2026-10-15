import 'dart:typed_data';

// Static ELF checks, independent of readelf output or the host architecture.
// Android's native loader also checks RELRO page boundaries; p_align alone is
// insufficient. This does not prove runtime behavior or APK ZIP alignment.
// https://developer.android.com/guide/practices/page-sizes
// https://android.googlesource.com/platform/bionic/+/android16-qpr2-release/linker/linker_phdr_16kib_compat.cpp
const androidElfAbis = <String, (int, int, int)>{
  'arm64-v8a': (2, 183, 16384),
  'x86_64': (2, 62, 16384),
  // Android's 16 KiB device requirement applies to 64-bit ABIs.
  'armeabi-v7a': (1, 40, 4096),
  'x86': (1, 3, 4096),
};

class AndroidElfReport {
  AndroidElfReport({
    required this.abi,
    required this.pageSize,
    required this.segments,
    required this.failures,
    required this.dynamicRelocations,
  });

  final String abi;
  final int pageSize;
  final List<ElfSegment> segments;
  final List<String> failures;
  final bool dynamicRelocations;

  bool get compatible => failures.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'abi': abi,
    'requiredPageSize': pageSize,
    'compatible': compatible,
    'dynamicRelocations': dynamicRelocations,
    'segments': segments.map((segment) => segment.toJson()).toList(),
    'failures': failures,
  };
}

class ElfSegment {
  ElfSegment(
    this.type,
    this.flags,
    this.offset,
    this.address,
    this.fileSize,
    this.memorySize,
    this.alignment,
  );

  final int type;
  final int flags;
  final int offset;
  final int address;
  final int fileSize;
  final int memorySize;
  final int alignment;

  int get end => address + memorySize;
  bool get writable => flags & 2 != 0;

  Map<String, Object?> toJson() => <String, Object?>{
    'type': switch (type) {
      1 => 'LOAD',
      2 => 'DYNAMIC',
      0x6474e552 => 'GNU_RELRO',
      _ => '0x${type.toRadixString(16)}',
    },
    'flags': flags,
    'offset': offset,
    'virtualAddress': address,
    'fileSize': fileSize,
    'memorySize': memorySize,
    'alignment': alignment,
  };
}

AndroidElfReport inspectAndroidElf(Uint8List bytes, String abi) {
  final specification = androidElfAbis[abi];
  if (specification == null) throw FormatException('Unsupported ABI: $abi');
  final (expectedClass, expectedMachine, pageSize) = specification;
  final reader = _Reader(bytes);
  reader.range(0, 16);
  if (bytes[0] != 0x7f ||
      bytes[1] != 0x45 ||
      bytes[2] != 0x4c ||
      bytes[3] != 0x46) {
    throw const FormatException('Not an ELF file.');
  }
  final elfClass = bytes[4];
  if (elfClass != expectedClass || bytes[5] != 1 || bytes[6] != 1) {
    throw FormatException('Unsupported ELF class, byte order or version: $abi');
  }
  final is64 = elfClass == 2;
  final headerSize = is64 ? 64 : 52;
  final programHeaderSize = is64 ? 56 : 32;
  reader.range(0, headerSize);
  if (reader.u16(16) != 3 ||
      reader.u16(18) != expectedMachine ||
      reader.u32(20) != 1) {
    throw FormatException('Expected an Android $abi ET_DYN shared library.');
  }
  if (reader.u16(is64 ? 52 : 40) != headerSize ||
      reader.u16(is64 ? 54 : 42) != programHeaderSize) {
    throw const FormatException('Invalid ELF or program header size.');
  }
  final phOffset = is64 ? reader.u64(32) : reader.u32(28);
  final phCount = reader.u16(is64 ? 56 : 44);
  if (phCount == 0 || phCount == 0xffff || phOffset < headerSize) {
    throw const FormatException('Missing or unsupported program header table.');
  }
  reader.range(phOffset, phCount * programHeaderSize);
  final segments = <ElfSegment>[];
  for (var i = 0; i < phCount; i++) {
    final start = phOffset + i * programHeaderSize;
    int word(int displacement) => is64
        ? reader.u64(start + displacement)
        : reader.u32(start + displacement);
    final segment = ElfSegment(
      reader.u32(start),
      reader.u32(start + (is64 ? 4 : 24)),
      word(is64 ? 8 : 4),
      word(is64 ? 16 : 8),
      word(is64 ? 32 : 16),
      word(is64 ? 40 : 20),
      word(is64 ? 48 : 28),
    );
    reader.range(segment.offset, segment.fileSize);
    if ((segment.type == 1 && segment.fileSize > segment.memorySize) ||
        segment.memorySize > 0x7fffffffffffffff - pageSize - segment.address) {
      throw const FormatException('Invalid segment file or memory extent.');
    }
    segments.add(segment);
  }
  final loads = segments.where((segment) => segment.type == 1).toList();
  final relros = segments
      .where((segment) => segment.type == 0x6474e552)
      .toList();
  final dynamics = segments.where((segment) => segment.type == 2).toList();
  final failures = <String>[];
  if (loads.isEmpty) failures.add('No PT_LOAD segments.');
  for (var i = 0; i < loads.length; i++) {
    final load = loads[i];
    if (load.alignment < pageSize ||
        load.alignment & (load.alignment - 1) != 0) {
      failures.add(
        'LOAD[$i] alignment ${load.alignment} is below $pageSize or invalid.',
      );
    }
    if ((load.alignment > 0 &&
            load.offset % load.alignment != load.address % load.alignment) ||
        load.offset % pageSize != load.address % pageSize) {
      failures.add('LOAD[$i] file offset and virtual address are incongruent.');
    }
    if (load.flags & 3 == 3) {
      failures.add('LOAD[$i] is writable and executable.');
    }
    if (i > 0 && loads[i - 1].end > load.address) {
      failures.add(
        'LOAD segments overlap or are out of virtual-address order.',
      );
    }
    for (final previous in loads.take(i)) {
      if (previous.memorySize == 0 || load.memorySize == 0) continue;
      if (_overlaps(
            _down(previous.address, pageSize),
            _up(previous.end, pageSize),
            _down(load.address, pageSize),
            _up(load.end, pageSize),
          ) &&
          previous.flags != load.flags) {
        failures.add(
          'LOAD[$i] shares a $pageSize-byte page with different permissions.',
        );
      }
    }
  }
  for (var i = 0; i < relros.length; i++) {
    final relro = relros[i];
    final parents = loads
        .where(
          (load) =>
              load.writable &&
              relro.address >= load.address &&
              relro.end <= _up(load.end, pageSize) &&
              relro.offset >= load.offset &&
              relro.offset + relro.fileSize <= load.offset + load.fileSize &&
              relro.address - load.address == relro.offset - load.offset,
        )
        .toList();
    if (relro.memorySize == 0 || parents.isEmpty) {
      failures.add('RELRO[$i] is empty or outside a writable LOAD segment.');
      continue;
    }
    // GNU_RELRO may include zero-filled page padding beyond the LOAD's actual
    // memory extent. Bionic does not require a separate aligned boundary when
    // the whole writable LOAD is RELRO. Only a remaining writable suffix needs
    // an exact page boundary; rounding must never protect another LOAD's data.
    final entireLoad = parents.any(
      (load) => relro.address == load.address && relro.end >= load.end,
    );
    if (!entireLoad && relro.end % pageSize != 0) {
      failures.add('RELRO[$i] end is not aligned to $pageSize bytes.');
    }
    for (final load in loads.where((load) => load.writable)) {
      if (_overlaps(
            _down(relro.address, pageSize),
            relro.address,
            load.address,
            load.end,
          ) ||
          _overlaps(
            relro.end,
            _up(relro.end, pageSize),
            load.address,
            load.end,
          )) {
        failures.add(
          'RELRO[$i] page rounding protects writable data outside RELRO.',
        );
      }
    }
  }
  var relocations = false;
  if (dynamics.length != 1) {
    failures.add('Expected exactly one PT_DYNAMIC segment.');
  } else {
    final dynamic = dynamics.single;
    final entrySize = is64 ? 16 : 8;
    if (dynamic.fileSize == 0 ||
        dynamic.fileSize > dynamic.memorySize ||
        dynamic.fileSize % entrySize != 0 ||
        !_contained(dynamic, loads, writable: true)) {
      failures.add('DYNAMIC has invalid size or LOAD geometry.');
    } else {
      var terminated = false;
      for (
        var cursor = dynamic.offset;
        cursor < dynamic.offset + dynamic.fileSize;
        cursor += entrySize
      ) {
        final tag = is64 ? reader.u64(cursor) : reader.u32(cursor);
        final value = is64 ? reader.u64(cursor + 8) : reader.u32(cursor + 4);
        if (tag == 0) {
          terminated = true;
          break;
        }
        if (<int>{
              7,
              8,
              17,
              18,
              23,
              2,
              35,
              36,
              0x6000000f,
              0x60000010,
              0x60000011,
              0x60000012,
            }.contains(tag) &&
            value != 0) {
          relocations = true;
        }
        if (tag == 22 || (tag == 30 && value & 4 != 0)) {
          failures.add('DYNAMIC requests text relocations.');
        }
      }
      if (!terminated) failures.add('DYNAMIC has no DT_NULL terminator.');
      if (relocations && !_contained(dynamic, relros, fileMapping: false)) {
        failures.add('DYNAMIC with relocations is outside GNU_RELRO.');
      }
    }
  }
  if (relocations && relros.isEmpty) {
    failures.add('Dynamic relocations are present without GNU_RELRO.');
  }
  return AndroidElfReport(
    abi: abi,
    pageSize: pageSize,
    segments: segments
        .where(
          (segment) =>
              segment.type == 1 ||
              segment.type == 2 ||
              segment.type == 0x6474e552,
        )
        .toList(),
    failures: failures.toSet().toList(),
    dynamicRelocations: relocations,
  );
}

bool _contained(
  ElfSegment segment,
  List<ElfSegment> containers, {
  bool writable = false,
  bool fileMapping = true,
}) => containers.any(
  (parent) =>
      (!writable || parent.writable) &&
      segment.address >= parent.address &&
      segment.end <= parent.end &&
      (!fileMapping ||
          (segment.offset >= parent.offset &&
              segment.offset + segment.fileSize <=
                  parent.offset + parent.fileSize &&
              segment.address - parent.address ==
                  segment.offset - parent.offset)),
);

int _down(int value, int pageSize) => value - value % pageSize;
int _up(int value, int pageSize) => _down(value + pageSize - 1, pageSize);
bool _overlaps(int a, int b, int c, int d) => a < b && c < d && a < d && c < b;

class _Reader {
  _Reader(Uint8List bytes) : data = ByteData.sublistView(bytes);
  final ByteData data;
  void range(int offset, int length) {
    if (offset < 0 ||
        length < 0 ||
        offset > data.lengthInBytes ||
        length > data.lengthInBytes - offset) {
      throw const FormatException('ELF extent exceeds file bounds.');
    }
  }

  int u16(int offset) {
    range(offset, 2);
    return data.getUint16(offset, Endian.little);
  }

  int u32(int offset) {
    range(offset, 4);
    return data.getUint32(offset, Endian.little);
  }

  int u64(int offset) {
    range(offset, 8);
    // Native Dart ints cannot represent upper-half unsigned offsets exactly.
    if (data.getUint32(offset + 4, Endian.little) > 0x7fffffff) {
      throw const FormatException(
        'ELF address or extent exceeds signed 64-bit range.',
      );
    }
    return data.getUint64(offset, Endian.little);
  }
}
