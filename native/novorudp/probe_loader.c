/* Synthetic C ABI loader check. No files, keys or network are read. */
#include <dlfcn.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
int main(int argc, char **argv) {
    assert(argc == 2);
    void *lib = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!lib) { puts("NOVORUDP_LIBRARY_LOAD_FAILED"); return 1; }
    uint64_t (*identity)(const uint8_t *, size_t) = dlsym(lib, "kingclub_novorudp_identity");
    char *(*request)(const uint8_t *, size_t) = dlsym(lib, "kingclub_novorudp_request");
    void (*release)(char *) = dlsym(lib, "kingclub_novorudp_free");
    assert(identity && request && release);
    uint8_t seed[32]; memset(seed, 31, sizeof(seed));
    uint64_t handle = identity(seed, sizeof(seed)); memset(seed, 0, sizeof(seed));
    assert(handle != 0);
    char input[128];
    int count = snprintf(input, sizeof(input), "{\"op\":\"public\",\"handle\":%llu}", (unsigned long long)handle);
    char *output = request((const uint8_t *)input, count);
    assert(output && strstr(output, "novovm-ed25519:")); release(output);
    count = snprintf(input, sizeof(input), "{\"op\":\"close\",\"handle\":%llu}", (unsigned long long)handle);
    output = request((const uint8_t *)input, count); assert(output && strstr(output, "\"ok\":true")); release(output);
    count = snprintf(input, sizeof(input), "{\"op\":\"public\",\"handle\":%llu}", (unsigned long long)handle);
    output = request((const uint8_t *)input, count); assert(output && strstr(output, "\"ok\":false")); release(output);
    dlclose(lib);
    puts("NOVORUDP_ANDROID_SHARED_ABI_LOAD_RELEASE_PASSED");
    return 0;
}
