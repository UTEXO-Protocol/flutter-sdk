#!/usr/bin/env bash
# Rebuild the pinned RLN release with Android 16 KiB segment alignment.
# This recipe changes build tools/link flags; it applies no RLN/WDK source overlay.
# Independently repeated builds are required before claiming bit reproducibility.
set -euo pipefail

usage() {
  echo 'Usage: build_rln_android_16k.sh SOURCE OUTPUT TARGET_DIR NDK BASE_AAR SOURCES_JAR' >&2
  echo 'SOURCE must contain the exact release and initialized pinned rust-lightning submodule.' >&2
  echo 'TARGET_DIR must be outside paths containing spaces or angle brackets (CMake constraint).' >&2
  exit 2
}
[[ $# == 6 ]] || usage
if [[ "${CARGO_HOME+x}" == x && "$CARGO_HOME" != /* ]]; then
  echo 'CARGO_HOME must be absolute for this recipe.' >&2
  exit 1
fi
export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH"
RECIPE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
for dependency in python3 git cargo rustup dart cmake ninja bindgen unzip; do
  command -v "$dependency" >/dev/null || { echo "Missing dependency: $dependency" >&2; exit 1; }
done
python3 - "$1" <<'PY'
import os, pathlib, sys
source = pathlib.Path(sys.argv[1]).resolve()
overrides = []
for name in os.environ:
    if ((name.startswith('CARGO_') and name != 'CARGO_HOME') or
        name.startswith(('RUSTFLAGS', 'RUSTC', 'RUSTDOC', 'RUST_TARGET_',
                         'CC_', 'CXX_', 'AR_', 'RANLIB_', 'LD_', 'STRIP_', 'HOST_', 'TARGET_',
                         'CFLAGS', 'CXXFLAGS', 'CPPFLAGS', 'LDFLAGS', 'CMAKE',
                         'BINDGEN', 'OPENSSL', 'PKG_CONFIG', 'AWS_LC_SYS_')) or
        name.startswith('LIBCLANG_') or
        name in {'CC','CXX','AR','RANLIB','LD','STRIP','CLANG_PATH',
                 'CRATE_CC_NO_DEFAULTS','ARFLAGS','ASFLAGS','ASMFLAGS'}):
        overrides.append(name)
if overrides:
    raise SystemExit('Remove inherited build overrides before this recipe: ' + ', '.join(sorted(overrides)))
# Cargo searches ancestor configuration from its invocation directory, then
# CARGO_HOME. Undeclared source/registry/flag overrides would invalidate this recipe.
configs = [directory/relative for directory in [source, *source.parents]
           for relative in ['.cargo/config','.cargo/config.toml']]
cargo_home = pathlib.Path(os.environ.get('CARGO_HOME', pathlib.Path.home()/'.cargo'))
configs.extend(cargo_home/relative for relative in ['config','config.toml'])
for config in configs:
    if config.exists():
        raise SystemExit('Ambient Cargo configuration is unsupported by this recipe: ' + str(config))
PY
SOURCE="$(cd "$1" && pwd -P)"
mkdir -p "$2" "$3"
OUTPUT="$(cd "$2" && pwd -P)"
export CARGO_TARGET_DIR="$(cd "$3" && pwd -P)"
export ANDROID_NDK_HOME="$(cd "$4" && pwd -P)"
BASE_AAR="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$5")"
SOURCES_JAR="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$6")"
SDK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
case "$CARGO_TARGET_DIR" in *' '*|*'<'*|*'>'*) echo 'Use a sanitized TARGET_DIR for CMake.' >&2; exit 1;; esac
verify_pins() {
test "$(git -C "$SOURCE" rev-parse HEAD)" = ecc69f20308231400561f6f060fea88acfa40cc4
test "$(git -C "$SOURCE/rust-lightning" rev-parse HEAD)" = 79b9eb5166546c62692d3a672986f385c7fe047d
test -z "$(git -C "$SOURCE" status --porcelain --untracked-files=all)"
test -z "$(git -C "$SOURCE/rust-lightning" status --porcelain --untracked-files=all)"
python3 - "$SOURCE/Cargo.lock" "$BASE_AAR" "$SOURCES_JAR" "$ANDROID_NDK_HOME/source.properties" <<'PY'
import hashlib, pathlib, sys
for filename, digest in zip(sys.argv[1:4], [
    'f61d03fa8f45dada6654c89fd3a87b794601ff79ec30ffc06acc536bc0f64139',
    '148e8e50c1014237c737b26120469ceefc8a79bb6c77cd74ddda89ea316c6dac',
    '1cac3055200f1049c2bbee8a9bc08eac49a642281669999e440793d7ef186c7d',
]):
    digestor = hashlib.sha256()
    with open(filename, 'rb') as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b''): digestor.update(chunk)
    actual = digestor.hexdigest()
    if actual != digest: raise SystemExit(f'Unrecognized input: {filename}: {actual}')
if 'Pkg.Revision = 28.2.13676358' not in pathlib.Path(sys.argv[4]).read_text():
    raise SystemExit('This recipe requires Android NDK 28.2.13676358.')
PY
}
verify_pins
test "$(cargo +1.94.0 ndk --version)" = 'cargo-ndk 4.1.2'
test "$(bindgen --version)" = 'bindgen 0.72.1'
export ANDROID_NDK_ROOT="$ANDROID_NDK_HOME" ANDROID_NDK="$ANDROID_NDK_HOME"
export AWS_LC_SYS_ANDROID_NDK_ROOT="$ANDROID_NDK_HOME" AWS_LC_SYS_ANDROID_NDK="$ANDROID_NDK_HOME"
export AWS_LC_SYS_EXTERNAL_BINDGEN=1
export LIBCLANG_PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$(ls "$ANDROID_NDK_HOME/toolchains/llvm/prebuilt")/lib"
export CMAKE="$(command -v cmake)"
export CARGO_BUILD_JOBS=2
export CARGO_PROFILE_RELEASE_BUILD_OVERRIDE_STRIP=none
PAGE_FLAGS='-C link-arg=-Wl,-z,max-page-size=16384 -C link-arg=-Wl,-z,common-page-size=16384'
export CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS="$PAGE_FLAGS"
export CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_RUSTFLAGS="$PAGE_FLAGS"
export CARGO_TARGET_X86_64_LINUX_ANDROID_RUSTFLAGS="$PAGE_FLAGS"
cd "$SOURCE"
cargo +1.94.0 metadata --locked --features uniffi,vls,vss --format-version 1 > "$OUTPUT/cargo-metadata.json"
for abi in arm64-v8a armeabi-v7a x86_64; do
  cargo +1.94.0 ndk -t "$abi" --platform 24 -o "$OUTPUT/jniLibs" build --locked --release --features uniffi,vls,vss --lib 2>&1 | tee "$OUTPUT/build-$abi.log"
  dart run "$SDK_ROOT/tool/verify_android_elf.dart" --elf "$OUTPUT/jniLibs/$abi/librgb_lightning_node.so" --abi "$abi" --report "$OUTPUT/elf-$abi.json"
done
# UniFFI extracts metadata statically from each Android ELF: no host RLN build,
# wallet initialization, daemon, backend, or network connection is needed.
COPIED_UDL=0
test ! -e "$SOURCE/src/rgb_lightning_node.udl"
cp "$SOURCE/bindings/rgb_lightning_node.udl" "$SOURCE/src/rgb_lightning_node.udl"
COPIED_UDL=1
cleanup() { if [[ "$COPIED_UDL" == 1 ]]; then rm -f "$SOURCE/src/rgb_lightning_node.udl"; fi; }
trap cleanup EXIT
for abi in arm64-v8a armeabi-v7a x86_64; do
  cargo +1.94.0 run --locked --release --manifest-path "$SOURCE/bindings/uniffi-bindgen/Cargo.toml" --target-dir "$CARGO_TARGET_DIR" -- generate "$OUTPUT/jniLibs/$abi/librgb_lightning_node.so" --library --no-format --crate rgb_lightning_node --language kotlin --config "$SOURCE/uniffi-android.toml" -o "$OUTPUT/kotlin-$abi" 2>&1 | tee "$OUTPUT/bindings-$abi.log"
done
python3 - "$SOURCE" "$OUTPUT" "$BASE_AAR" "$SOURCES_JAR" "$RECIPE_PATH" "$ANDROID_NDK_HOME" "$CARGO_TARGET_DIR" <<'PY'
import hashlib, json, os, pathlib, re, shutil, subprocess, sys, tempfile, zipfile, zlib
source, output, base, sources, recipe, ndk, target = map(pathlib.Path, sys.argv[1:])
def sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024*1024), b''): digest.update(chunk)
    return digest.hexdigest()
def run(*args): return subprocess.check_output(args, text=True).strip()
def public_text(value):
    substitutions = [(str(ndk),'<ndk>'), (str(source),'<source>'),
                     (str(target),'<target>'), (str(output),'<output>')]
    if os.environ.get('SDKROOT'): substitutions.append((os.environ['SDKROOT'],'<host-sdk>'))
    substitutions.append((str(pathlib.Path.home()),'<home>'))
    for original, label in substitutions: value = value.replace(original, label)
    return value
abis = ['arm64-v8a', 'armeabi-v7a', 'x86_64']
tools = next((ndk/'toolchains/llvm/prebuilt').iterdir())/'bin'
def api_symbols(path):
    rows = run(str(tools/'llvm-nm'), '-D', '--defined-only', '--format=posix', str(path)).splitlines()
    return sorted(row.split()[0] for row in rows if row.startswith(('ffi_', 'uniffi_', 'UNIFFI_META_')))
def needed(path):
    return sorted(re.findall(r'\(NEEDED\).*?\[(.*?)\]', run(str(tools/'llvm-readelf'), '-d', str(path))))
binding_path = 'org/utexo/rgblightningnode/rgb_lightning_node.kt'
with zipfile.ZipFile(sources) as z: canonical = z.read(binding_path)
libraries = {}
for abi in abis:
    if (output/f'kotlin-{abi}'/binding_path).read_bytes() != canonical:
        raise SystemExit(f'Generated Kotlin differs from the verified official source: {abi}')
    path = output/'jniLibs'/abi/'librgb_lightning_node.so'
    raw = output/'rawJniLibs'/abi/path.name
    raw.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, raw)
    exports = api_symbols(path)
    if not exports: raise SystemExit(f'Missing UniFFI exports: {abi}')
    with tempfile.TemporaryDirectory(prefix='rln-stock-') as directory:
        stock = pathlib.Path(directory)/path.name
        with zipfile.ZipFile(base) as z: stock.write_bytes(z.read(f'jni/{abi}/{path.name}'))
        if api_symbols(stock) != exports: raise SystemExit(f'UniFFI exports differ from stock: {abi}')
        if needed(stock) != needed(path): raise SystemExit(f'DT_NEEDED differs from stock: {abi}')
    subprocess.run([str(tools/'llvm-strip'), '--strip-unneeded', '--wildcard', '--keep-symbol=UNIFFI_META*', str(path)], check=True)
    if api_symbols(path) != exports or needed(path) != needed(raw):
        raise SystemExit(f'Stripping changed runtime exports/dependencies: {abi}')
    # Re-reading metadata after stripping proves that the packaged library still
    # generates exactly the canonical Kotlin/UniFFI contract, including checksums.
    subprocess.run([str(target/'release/uniffi-bindgen'), 'generate', str(path), '--library', '--no-format', '--crate', 'rgb_lightning_node', '--language', 'kotlin', '--config', str(source/'uniffi-android.toml'), '-o', str(output/f'kotlin-stripped-{abi}')], check=True)
    if (output/f'kotlin-stripped-{abi}'/binding_path).read_bytes() != canonical:
        raise SystemExit(f'Stripping changed UniFFI metadata: {abi}')
    libraries[abi] = {
        'unstrippedSha256': sha(raw), 'unstrippedSizeBytes': raw.stat().st_size,
        'sha256': sha(path), 'sizeBytes': path.stat().st_size,
        'dtNeeded': needed(path), 'ffiExportCount': len(exports),
        'ffiExportNamesSha256': hashlib.sha256(('\n'.join(exports)+'\n').encode()).hexdigest(),
    }
entries = {f'jni/{abi}/librgb_lightning_node.so': output/'jniLibs'/abi/'librgb_lightning_node.so' for abi in abis}
destination = output/'rgb-lightning-node-android-0.17.0-beta.3-16k.1.aar'
with zipfile.ZipFile(base) as original, zipfile.ZipFile(destination, 'w') as result:
    names = original.namelist()
    if len(set(names)) != len(names) or not set(entries) <= set(names):
        raise SystemExit('The original AAR has duplicate/missing JNI entries.')
    for item in original.infolist():
        data = entries[item.filename].read_bytes() if item.filename in entries else original.read(item.filename)
        result.writestr(item, data)
with zipfile.ZipFile(base) as original, zipfile.ZipFile(destination) as result:
    assert original.namelist() == result.namelist()
    assert all(original.read(n) == result.read(n) for n in original.namelist() if n not in entries)
manifest = {
    'schemaVersion': 1,
    'scope': 'derived-android-native-build',
    'upstreamRelease': '0.17.0-beta.3',
    'derivedArtifactVersion': '0.17.0-beta.3-16k.1',
    'sourceRepository': 'https://github.com/UTEXO-Protocol/rgb-lightning-node.git',
    'sourceTag': 'v0.17.0-beta.3',
    'sourceCommit': run('git','-C',str(source),'rev-parse','HEAD'),
    'ldkCommit': run('git','-C',str(source/'rust-lightning'),'rev-parse','HEAD'),
    'cargoLockSha256': sha(source/'Cargo.lock'),
    'uniffiBindgenCargoLockSha256': sha(source/'bindings/uniffi-bindgen/Cargo.lock'),
    'udlSha256': sha(source/'bindings/rgb_lightning_node.udl'),
    'cargoMetadataSha256': sha(output/'cargo-metadata.json'),
    'buildRecipeSha256': sha(recipe.resolve()),
    'sourceOverlay': None,
    'rust': public_text(run('rustc','+1.94.0','-vV')),
    'cargoNdk': run('cargo','+1.94.0','ndk','--version'),
    'bindgenCli': run('bindgen','--version'),
    'cmake': public_text(run('cmake','--version')),
    'ninja': run('ninja','--version'),
    'buildHost': run('uname','-srm'),
    'packagingPython': sys.version,
    'packagingZlib': zlib.ZLIB_RUNTIME_VERSION,
    'ndkRevision': '28.2.13676358',
    'clang': public_text(run(str(next((ndk/'toolchains/llvm/prebuilt').iterdir())/'bin/clang'),'--version')),
    'hostSdkPath': '<host-sdk>' if os.environ.get('SDKROOT') else None,
    'features': ['uniffi','vls','vss'],
    'cargoLocked': True,
    'apiLevel': 24,
    'pageLinkerFlags': ['-Wl,-z,max-page-size=16384','-Wl,-z,common-page-size=16384'],
    'buildDependencyStrip': 'none',
    'targetStripCommand': 'NDK 28.2.13676358 llvm-strip --strip-unneeded --wildcard --keep-symbol=UNIFFI_META*',
    'officialBaseAarSha256': sha(base),
    'officialSourcesJarSha256': sha(sources),
    'kotlinBindingSha256': hashlib.sha256(canonical).hexdigest(),
    'bindingFormatting': 'disabled',
    'generatedKotlinByteParity': True,
    'generatedKotlinByteParityAfterStrip': True,
    'stockFfiExportParity': True,
    'stockDtNeededParity': True,
    'unchangedNonJniAarEntries': True,
    'independentReproducibility': 'not-verified',
    'officialSignatureAppliesToDerivedArtifact': False,
    'libraries': libraries,
    'aar': {'file': destination.name, 'sha256': sha(destination), 'sizeBytes': destination.stat().st_size},
}
(output/'sourcebuild-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
PY
cleanup
COPIED_UDL=0
dart run "$SDK_ROOT/tool/verify_android_elf.dart" --archive "$OUTPUT/rgb-lightning-node-android-0.17.0-beta.3-16k.1.aar" --kind aar --expected-abis arm64-v8a,armeabi-v7a,x86_64 --report "$OUTPUT/aar-elf.json"
verify_pins
