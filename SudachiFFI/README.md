# SudachiFFI - iOS Bindings for Sudachi.rs

This directory contains the C-compatible FFI wrapper that bridges [sudachi.rs](https://github.com/WorksApplications/sudachi.rs) to Swift/iOS.

## Overview

SudachiFFI provides a statically-linked XCFramework that exposes Sudachi's morphological analysis capabilities through a C API, allowing Swift code to perform professional Japanese tokenization.

## Architecture

```
Swift App (Manglex)
    ↓
SudachiTokenizer.swift (High-level API)
    ↓
SudachiBridge.swift (Low-level wrapper)
    ↓
@import SudachiFFI (Module)
    ↓
libsudachi_ios.a (Static library)
    ↓
sudachi.rs (Rust core)
```

## Files

- **`src/lib.rs`** - Rust FFI implementation
- **`Cargo.toml`** - Rust dependencies
- **`build.sh`** - XCFramework build script
- **`cbindgen.toml`** - C header generation config
- **`SudachiFFI.xcframework/`** - Built framework (output)

## Building

### Automated (Recommended)

```bash
# From project root
make build-framework
```

### Manual

```bash
cd SudachiFFI
./build.sh
```

### Requirements

- Rust 1.70+ with iOS targets
- cbindgen
- Xcode command-line tools

## API Reference

### Initialization

```c
SudachiTokenizer* sudachi_init(const char* dict_path);
```

Initializes Sudachi with the specified dictionary file.

**Parameters:**
- `dict_path`: Path to `system.dic` dictionary file

**Returns:**
- Pointer to tokenizer instance, or NULL on failure

---

### Tokenization

```c
SudachiToken** sudachi_tokenize(
    SudachiTokenizer* tokenizer,
    const char* text,
    SudachiTokenMode mode,
    size_t* out_count
);
```

Tokenizes Japanese text into morphemes.

**Parameters:**
- `tokenizer`: Tokenizer instance from `sudachi_init`
- `text`: UTF-8 Japanese text to analyze
- `mode`: Granularity mode (A=short, B=medium, C=long)
- `out_count`: Output parameter for token count

**Returns:**
- Array of token pointers, or NULL on failure
- Caller must free with `sudachi_free_tokens`

---

### Token Structure

```c
typedef struct SudachiToken {
    char* surface;           // Surface form (e.g., "食べた")
    char* reading;           // Reading in katakana
    char* dictionary_form;   // Base form (e.g., "食べる")
    char* normalized_form;   // Normalized form
    char* pos;               // POS tags (JSON array)
    int32_t begin;           // Start offset in original text
    int32_t end;             // End offset in original text
} SudachiToken;
```

---

### Memory Management

```c
void sudachi_free_token(SudachiToken* token);
void sudachi_free_tokens(SudachiToken** tokens, size_t count);
void sudachi_release_tokenizer(SudachiTokenizer* tokenizer);
```

Always free allocated memory:
1. Free individual tokens with `sudachi_free_token`
2. Free token array with `sudachi_free_tokens`
3. Release tokenizer with `sudachi_release_tokenizer`

---

### Version

```c
const char* sudachi_version(void);
```

Returns the FFI wrapper version string.

## Example Usage (C)

```c
#include "sudachi_ios.h"

// Initialize
SudachiTokenizer* tokenizer = sudachi_init("/path/to/system.dic");
if (!tokenizer) {
    fprintf(stderr, "Failed to initialize\n");
    return;
}

// Tokenize
size_t count = 0;
SudachiToken** tokens = sudachi_tokenize(
    tokenizer,
    "今日は良い天気です",
    C,  // Long mode
    &count
);

// Process tokens
for (size_t i = 0; i < count; i++) {
    printf("Surface: %s\n", tokens[i]->surface);
    printf("Reading: %s\n", tokens[i]->reading);
    printf("Dict Form: %s\n", tokens[i]->dictionary_form);
}

// Cleanup
sudachi_free_tokens(tokens, count);
sudachi_release_tokenizer(tokenizer);
```

## Swift Integration

### Module Import

```swift
import SudachiFFI  // Imports via module.modulemap
```

### High-Level API

```swift
let tokenizer = SudachiTokenizer()
try await tokenizer.initializeWithBundledDictionary()

let tokens = try await tokenizer.tokenize("日本語の文章", mode: .long)
for token in tokens {
    print("\(token.surface) → \(token.dictionaryForm)")
}
```

### Low-Level Bridge

```swift
class SudachiBridge {
    private var tokenizerPtr: OpaquePointer?
    
    func initialize(dictionaryPath: String) throws {
        let cPath = dictionaryPath.withCString { $0 }
        tokenizerPtr = sudachi_init(cPath)
        guard tokenizerPtr != nil else {
            throw SudachiError.initializationFailed
        }
    }
    
    func tokenize(text: String, mode: SudachiMode) throws -> [SudachiToken] {
        // FFI call and conversion...
    }
}
```

## Build Process

### Cross-Compilation Targets

1. **Device (arm64)**: `aarch64-apple-ios`
2. **Simulator (arm64)**: `aarch64-apple-ios-sim`
3. **Simulator (x86_64)**: `x86_64-apple-ios`

### Build Steps

```bash
# 1. Compile for each target
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target x86_64-apple-ios

# 2. Create universal simulator library
lipo -create \
    target/aarch64-apple-ios-sim/release/libsudachi_ios.a \
    target/x86_64-apple-ios/release/libsudachi_ios.a \
    -output libsudachi_ios_sim.a

# 3. Generate C header
cbindgen --config cbindgen.toml --output sudachi_ios.h

# 4. Create module map
# module.modulemap defines the module for Swift import

# 5. Build XCFramework
xcodebuild -create-xcframework \
    -library target/aarch64-apple-ios/release/libsudachi_ios.a \
    -headers Headers/ \
    -library libsudachi_ios_sim.a \
    -headers Headers/ \
    -output SudachiFFI.xcframework
```

## XCFramework Structure

```
SudachiFFI.xcframework/
├── Info.plist
├── ios-arm64/                      # Device slice
│   ├── Headers/
│   │   ├── sudachi_ios.h
│   │   └── module.modulemap
│   └── libsudachi_ios.a
└── ios-arm64_x86_64-simulator/     # Simulator slice
    ├── Headers/
    │   ├── sudachi_ios.h
    │   └── module.modulemap
    └── libsudachi_ios_sim.a
```

## Troubleshooting

### Initialization Fails

**Symptom:** `sudachi_init` returns NULL

**Solutions:**
1. Verify dictionary path is correct
2. Check file permissions
3. Ensure dictionary is not corrupted
4. Review console logs for detailed error

### Missing Symbols

**Symptom:** Linker errors about undefined symbols

**Solutions:**
1. Ensure framework is added to Xcode target
2. Check framework is in "Frameworks, Libraries, and Embedded Content"
3. Verify bridging header imports module: `@import SudachiFFI;`

### Module Not Found

**Symptom:** `Module 'SudachiFFI' not found`

**Solutions:**
1. Rebuild framework: `make rebuild`
2. Check `module.modulemap` exists in Headers/
3. Clean Xcode build: ⌘⇧K

## Performance

### Initialization
- **Cold start**: ~500ms (loads dictionary)
- **Warm start**: Instant (cached)

### Tokenization
- **Short text** (10 words): ~10ms
- **Medium text** (50 words): ~30ms
- **Long text** (200 words): ~100ms

### Memory
- **Dictionary**: ~200MB (mmap'd, shared)
- **Tokenizer**: ~1MB
- **Per-token**: ~200 bytes

## Technical Notes

### Memory Safety

All FFI functions handle memory safely:
- NULL checks on all pointers
- Proper CString allocation/deallocation
- No buffer overflows
- Clean error propagation

### Threading

- Tokenizer is **thread-safe** (uses `StatelessTokenizer`)
- Dictionary is **immutable** after initialization
- Safe for concurrent tokenization

### Error Handling

C API returns NULL on errors. Swift wrapper translates to Swift errors:

```swift
enum SudachiError: Error {
    case initializationFailed(String)
    case tokenizationFailed(String)
    case invalidInput(String)
}
```

## Development

### Modifying FFI Code

1. Edit `src/lib.rs`
2. Update `cbindgen.toml` if adding new types
3. Rebuild: `make rebuild`
4. Update Swift wrapper if API changed

### Testing

```bash
# Rust tests
cargo test

# Integration test via Swift
# (Run app in Xcode with test data)
```

### Debugging

```bash
# Enable debug symbols
cargo build --target aarch64-apple-ios

# View symbols
nm -gU target/aarch64-apple-ios/debug/libsudachi_ios.a

# Check architecture
lipo -info SudachiFFI.xcframework/ios-arm64/libsudachi_ios.a
```

## License

This FFI wrapper follows the same license as sudachi.rs: Apache License 2.0

## References

- **sudachi.rs**: https://github.com/WorksApplications/sudachi.rs
- **cbindgen**: https://github.com/eqrion/cbindgen
- **XCFramework**: https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle

---

**Last Updated:** September 30, 2025