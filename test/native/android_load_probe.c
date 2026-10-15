// Load-only validation of the exact generated UniFFI contract. No node,
// wallet, signer, network client or storage is created.
#include <dlfcn.h>
#include <inttypes.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "RGBLightningNodeFFI.h"

_Static_assert(sizeof(void *) == 8, "This probe targets Android arm64.");
_Static_assert(sizeof(RustBuffer) == 24, "Unexpected UniFFI RustBuffer ABI.");
_Static_assert(offsetof(RustBuffer, len) == 8, "Unexpected buffer length offset.");
_Static_assert(offsetof(RustBuffer, data) == 16, "Unexpected buffer data offset.");
_Static_assert(sizeof(RustCallStatus) == 32, "Unexpected UniFFI status ABI.");
_Static_assert(offsetof(RustCallStatus, errorBuf) == 8, "Unexpected error buffer offset.");

typedef uint32_t (*ContractVersion)(void);
typedef uint16_t (*ApiChecksum)(void);
typedef RustBuffer (*Healthcheck)(RustCallStatus *);
typedef void (*FreeBuffer)(RustBuffer, RustCallStatus *);

static int release_buffer(FreeBuffer release, RustBuffer buffer) {
  RustCallStatus status = {0};
  release(buffer, &status);
  if (status.code != 0 || status.errorBuf.data != NULL ||
      status.errorBuf.len != 0 || status.errorBuf.capacity != 0) {
    // Avoid printing arbitrary native error contents. A failed release is a
    // protocol failure; process exit reclaims any remaining native allocation.
    fprintf(stderr, "UniFFI buffer release failed (status=%d).\n", status.code);
    return 1;
  }
  return 0;
}

#define LOAD_FUNCTION(destination, name) do { \
  dlerror(); \
  void *address = dlsym(library, name); \
  const char *error = dlerror(); \
  if (error != NULL || address == NULL) { \
    fprintf(stderr, "Required native symbol is unavailable: %s\n", name); \
    dlclose(library); \
    return 1; \
  } \
  _Static_assert(sizeof(destination) == sizeof(address), "Unexpected function pointer ABI."); \
  memcpy(&(destination), &address, sizeof(destination)); \
} while (0)

int main(int argc, char **argv) {
  if (argc != 2) {
    fprintf(stderr, "Usage: android_load_probe /absolute/path/library.so\n");
    return 2;
  }
  if (argv[1][0] != '/') {
    fprintf(stderr, "The native library path must be absolute.\n");
    return 2;
  }
  const long page_size = sysconf(_SC_PAGESIZE);
  if (page_size != 16384) {
    fprintf(stderr, "Expected a 16384-byte guest page size; got %ld.\n", page_size);
    return 1;
  }
  void *library = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
  if (library == NULL) {
    fprintf(stderr, "Native dlopen failed: %s\n", dlerror());
    return 1;
  }
  ContractVersion contract = NULL;
  ApiChecksum checksum = NULL;
  Healthcheck healthcheck = NULL;
  FreeBuffer release = NULL;
  LOAD_FUNCTION(contract, "ffi_rgb_lightning_node_uniffi_contract_version");
  LOAD_FUNCTION(checksum, "uniffi_rgb_lightning_node_checksum_func_uniffi_healthcheck");
  LOAD_FUNCTION(healthcheck, "uniffi_rgb_lightning_node_fn_func_uniffi_healthcheck");
  LOAD_FUNCTION(release, "ffi_rgb_lightning_node_rustbuffer_free");
  const uint32_t actual_contract = contract();
  const uint16_t actual_checksum = checksum();
  if (actual_contract != 26 || actual_checksum != 28125) {
    fprintf(stderr, "Native UniFFI contract mismatch: version=%" PRIu32
        ", checksum=%" PRIu16 ".\n", actual_contract, actual_checksum);
    dlclose(library);
    return 1;
  }
  RustCallStatus status = {0};
  RustBuffer result = healthcheck(&status);
  int failed = 0;
  if (status.code != 0 || status.errorBuf.data != NULL ||
      status.errorBuf.len != 0 || status.errorBuf.capacity != 0) {
    fprintf(stderr, "UniFFI healthcheck failed (status=%d).\n", status.code);
    failed = 1;
  }
  static const char expected[] = "rgb_lightning_node_uniffi_ready";
  if (result.data == NULL || result.len != sizeof(expected) - 1 ||
      result.len > result.capacity ||
      memcmp(result.data, expected, sizeof(expected) - 1) != 0) {
    fprintf(stderr, "UniFFI healthcheck returned an unexpected buffer.\n");
    failed = 1;
  }
  if (result.data != NULL && result.len <= result.capacity) {
    failed |= release_buffer(release, result);
  }
  if (status.errorBuf.data != NULL && status.errorBuf.len <= status.errorBuf.capacity) {
    failed |= release_buffer(release, status.errorBuf);
  }
  if (dlclose(library) != 0) {
    fprintf(stderr, "Native dlclose failed.\n");
    failed = 1;
  }
  if (failed) return 1;
  printf("PAGE_SIZE=16384\nUNIFFI_CONTRACT=26\nHEALTHCHECK_CHECKSUM=28125\n"
         "HEALTHCHECK=rgb_lightning_node_uniffi_ready\nRUST_BUFFER_RELEASED=true\n");
  return 0;
}
