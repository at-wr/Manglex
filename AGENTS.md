# Repository Guidelines

## Project Structure & Module Organization

### Directory Layout
```
Manglex/
├── Manglex/              # iOS app source code
│   ├── Main.swift        # App entry point
│   ├── Views/            # SwiftUI views
│   │   ├── Components/   # Reusable UI components
│   │   ├── Library/      # Library feature views
│   │   └── LiveText/     # Live Text feature views
│   ├── Dictionary/       # Analysis engine
│   │   ├── Services/     # Core services (Sudachi, JMDict)
│   │   └── Models/       # Data models
│   └── Resources/        # Bundled assets (DB, dictionary)
│
├── SudachiFFI/          # Rust FFI wrapper (version controlled)
│   ├── src/lib.rs       # C-compatible Sudachi interface
│   ├── build.sh         # XCFramework build script
│   └── Cargo.toml       # Rust dependencies
│
├── Frameworks/          # Built frameworks (version controlled)
│   └── SudachiFFI.xcframework
│
└── Ext/                 # External dependencies (gitignored)
    └── sudachi.rs/      # Cloned by Makefile
```

### Module Conventions
- **UI Components**: `Views/Components/` - Reusable SwiftUI views
- **Feature Screens**: `Views/Library/`, `Views/LiveText/` - Feature-specific containers
- **Dictionary Services**: `Dictionary/Services/` - Analysis, tokenization, conversion services
- **Data Models**: `Dictionary/Models/` - Swift structs representing data
- **Resources**: `Manglex/Resources/` - SQLite DB, Sudachi dictionary, assets

**Rule**: Maintain this separation - UI, services, and resources are isolated and testable.

---

## Build & Development Commands

### Prerequisites
```bash
# Install Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Add iOS targets
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

# Install cbindgen
cargo install cbindgen

# Verify setup
make check
```

### Main Workflow
```bash
# Initial setup (clone deps, download dictionary, build framework)
make all

# Open Xcode project
open Manglex.xcodeproj

# Build and run
# Select target device/simulator in Xcode, press ⌘R

# Rebuild framework after FFI changes
make rebuild

# Clean build artifacts
make clean

# Clean everything (including downloaded deps)
make clean-all
```

### Makefile Targets
- `make all` - Complete setup and build
- `make setup` - Clone sudachi.rs and download dictionary
- `make build-framework` - Build SudachiFFI.xcframework
- `make install-framework` - Copy framework to Frameworks/
- `make dictionary` - Download Sudachi dictionary
- `make rebuild` - Clean and rebuild framework
- `make clean` - Remove build artifacts
- `make clean-all` - Remove everything
- `make check` - Verify prerequisites
- `make help` - Show all targets

### Development Notes
- **External dependencies** (`Ext/`) are managed by Makefile and gitignored
- **FFI source code** (`SudachiFFI/`) is version controlled
- **Built frameworks** (`Frameworks/SudachiFFI.xcframework/`) are version controlled for convenience
- **Dictionary files** (`*.dic`) are downloaded by Makefile and gitignored (large files)

### Context7 Documentation
Always consult Context7 before drafting changes:
- `/websites/developer_apple` for Apple/SwiftUI/UIKit documentation
- Resolve library IDs and cite sources in code comments

### Build Optimization
- Use `xcbeautify -qq` when running `xcodebuild` locally for concise logs
- CI builds: `xcodebuild -scheme Manglex -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

---

## Coding Style & Naming Conventions

### Swift Guidelines
- **Indentation**: 4 spaces (no tabs)
- **Types**: `UpperCamelCase` (e.g., `WordAnalysis`, `SudachiTokenizer`)
- **Properties/Functions**: `lowerCamelCase` (e.g., `analyzeText`, `isReady`)
- **File Length**: Keep SwiftUI files under ~150 lines; split into extensions or separate components
- **Modern APIs**: Prefer modern SwiftUI/UIKit APIs (e.g., `PhotosPicker`) with graceful fallbacks

### Rust Guidelines
- **Follow rustfmt**: Standard Rust formatting conventions
- **FFI Safety**: All FFI functions must be `#[no_mangle]` and `extern "C"`
- **Memory Management**: Properly free allocated CStrings and arrays
- **Error Handling**: Return NULL pointers on errors (C convention)

### File Naming
- **Swift Files**: `PascalCase.swift` (e.g., `WordDetailView.swift`)
- **Rust Files**: `snake_case.rs` (e.g., `lib.rs`)
- **Resources**: `kebab-case` (e.g., `jmdict-eng-3.6.1.db`)

### Code Organization
```swift
// MARK: - Section Name
// Clear section markers for readability

// Classes/Structs: Properties → Initializers → Public Methods → Private Methods
struct WordAnalysis {
    // MARK: - Properties
    let surface: String
    let reading: String
    
    // MARK: - Initialization
    init(surface: String, reading: String) {
        self.surface = surface
        self.reading = reading
    }
    
    // MARK: - Public Methods
    func analyze() { ... }
    
    // MARK: - Private Methods
    private func helper() { ... }
}
```

---

## Manual QA Checklist

Run these smoke tests before committing major changes:

### Basic Functionality
- [ ] Launch app on iPhone 15 simulator
- [ ] Import sample manga image via photo picker
- [ ] Select Japanese text using Live Text
- [ ] Verify highlighted text appears correctly
- [ ] Long-press selected text to open morphology sheet
- [ ] Confirm word tokens display with correct colors
- [ ] Tap individual words to open detail view
- [ ] Verify all dictionary entries load properly
- [ ] Check conjugation information displays correctly
- [ ] Test romaji conversion accuracy

### UI/UX
- [ ] Check loading overlay clears after analysis
- [ ] Verify no empty morphology sections shown
- [ ] Confirm punctuation is filtered from breakdown
- [ ] Test card width uniformity
- [ ] Verify "+X more" is subtle and gray
- [ ] Check sheet dismissal works correctly
- [ ] Test fast-tap handling (no empty sheets)

### Edge Cases
- [ ] Test with text containing only hiragana
- [ ] Test with text containing only katakana
- [ ] Test with mixed kanji/kana text
- [ ] Test with long sentences (10+ words)
- [ ] Test with unknown/rare words
- [ ] Verify empty text input handling

### Console Checks
- [ ] No raw OCR text logged
- [ ] No unexpected warnings
- [ ] Dictionary initialization succeeds
- [ ] Sudachi initializes successfully

---

## Dictionary Data & Security Notes

### Database Files
- **JMDict Database**: `jmdict-eng-3.6.1-20250728123310.db` (~60MB)
  - Bundled in `Manglex/Resources/`
  - Version controlled (relatively stable)
  - Contains 200,000+ entries
  
- **Sudachi Dictionary**: `system.dic` (~200MB)
  - Downloaded by Makefile from SudachiDict releases
  - Gitignored due to size
  - Required for morphological analysis

### Security & Privacy
- **DO NOT** log extracted text or user images
- **Rely on** in-memory analysis only
- **Scrub** debug statements before committing
- **Clear** cached OCR results after use
- **Never commit** user data or test images

### Updating Dictionaries
```bash
# Update Sudachi dictionary
make update-dictionary

# Update JMDict (manual process)
# 1. Download new version from https://www.edrdg.org/jmdict/edict_doc.html
# 2. Convert to SQLite (use conversion script)
# 3. Replace Manglex/Resources/jmdict-eng-*.db
# 4. Update filename references in JMDictAnalyzer.swift
```

---

## Ingestion & Library Roadmap

### Current Implementation
- **Photo Picker**: Import manga pages from photo library
- **Live Text**: iOS native text recognition
- **Single Image**: Analysis on selected text from one image

### Future Roadmap
- **PDF Support**: Import manga volumes in PDF format
- **EPUB Support**: Handle digital manga ebooks
- **CBZ/ZIP Archives**: Support compressed manga collections
- **Batch Processing**: Analyze multiple pages
- **Library Management**: Organize and track reading progress
- **Bookmarks**: Save interesting words/phrases

### Architecture Goals
New ingest points should plug into a shared pipeline:
```
Media Source (PDF/EPUB/CBZ/Image)
    ↓
Media Decoder (format-specific)
    ↓
Text Extractor (OCR/native text)
    ↓
Analysis Pipeline (Sudachi + JMDict)
    ↓
UI Presentation
```

This abstraction allows future sources to reuse downstream services.

---

## FFI Development

### Sudachi FFI Layer
Located in `SudachiFFI/`, this provides C-compatible bindings for sudachi.rs:

```rust
// Core FFI functions
#[no_mangle]
pub extern "C" fn sudachi_init(dict_path: *const c_char) -> *mut SudachiTokenizer;

#[no_mangle]
pub extern "C" fn sudachi_tokenize(...) -> *mut *mut SudachiToken;

#[no_mangle]
pub extern "C" fn sudachi_free_tokens(...);
```

### Building the Framework
```bash
# Automated build (recommended)
make build-framework

# Manual build (for debugging)
cd SudachiFFI
./build.sh
```

### Framework Architecture
```
SudachiFFI.xcframework/
├── ios-arm64/                    # Device
│   ├── Headers/
│   │   ├── sudachi_ios.h        # C header
│   │   └── module.modulemap     # Module definition
│   └── libsudachi_ios.a         # Static library
└── ios-arm64_x86_64-simulator/  # Simulator
    ├── Headers/
    │   ├── sudachi_ios.h
    │   └── module.modulemap
    └── libsudachi_ios_sim.a     # Universal simulator lib
```

### Swift Integration
```swift
// Low-level bridge (SudachiBridge.swift)
// Direct FFI calls with unsafe pointers

// High-level API (SudachiTokenizer.swift)
// Swift-friendly async/await interface
@MainActor
class SudachiTokenizer: ObservableObject {
    func tokenize(_ text: String) async throws -> [SudachiToken]
}
```

---

## Testing & CI

### Local Testing
```bash
# Swift tests in Xcode
⌘U

# Command-line tests
xcodebuild test -scheme Manglex -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Rust tests
cd SudachiFFI
cargo test
```

### Test Coverage
- **Unit Tests**: Dictionary lookup, tokenization, romaji conversion
- **Integration Tests**: Full analysis pipeline
- **UI Tests**: View rendering and interaction
- **FFI Tests**: Memory safety, error handling

---

## Version Control

### What to Commit
✅ **DO commit:**
- All Swift source code
- FFI wrapper code (`SudachiFFI/src/`, `Cargo.toml`, `build.sh`)
- Built XCFramework (`Frameworks/SudachiFFI.xcframework/`)
- JMDict database (`Manglex/Resources/jmdict-eng-*.db`)
- Project files (`Manglex.xcodeproj/`)
- Documentation (`.md` files)
- Makefile and build scripts

❌ **DO NOT commit:**
- External dependencies (`Ext/sudachi.rs/`)
- Sudachi dictionary (`Manglex/Resources/system.dic`)
- Build artifacts (`build/`, `DerivedData/`)
- User settings (`xcuserdata/`)
- Temporary files (`*.tmp`, `*.bak`)

### Commit Messages
Follow conventional commit format:
```
feat: Add word bookmark feature
fix: Correct romaji conversion for katakana
docs: Update README with setup instructions
refactor: Extract morphology view components
test: Add conjugation resolution tests
```

---

## Performance Optimization

### Current Optimizations
- **Lazy Loading**: Dictionary entries loaded on-demand
- **Caching**: Word lookups cached in memory
- **Async/Await**: Non-blocking UI during analysis
- **SQLite Indices**: Fast dictionary queries
- **Mmap**: Zero-copy Sudachi dictionary loading

### Performance Targets
- **Initial Launch**: < 2 seconds
- **Dictionary Initialization**: < 1 second
- **Text Analysis**: < 500ms for 10 words
- **UI Responsiveness**: 60 FPS animations

---

## Troubleshooting

### Framework Build Issues
```bash
# Reset everything
make clean-all
make check  # Verify prerequisites
make all    # Rebuild from scratch
```

### Xcode Linking Errors
1. Check framework is in `Frameworks/SudachiFFI.xcframework/`
2. Verify framework is added to target in Xcode
3. Check bridging header imports `@import SudachiFFI;`

### Dictionary Not Found
```bash
# Re-download dictionary
make dictionary
```

### Rust Compilation Errors
```bash
# Update Rust toolchain
rustup update

# Verify iOS targets
rustup target list --installed

# Reinstall if needed
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
```

---

## Resources

- **Sudachi.rs**: https://github.com/WorksApplications/sudachi.rs
- **JMDict**: https://www.edrdg.org/jmdict/j_jmdict.html
- **Swift API Guidelines**: https://www.swift.org/documentation/api-design-guidelines/
- **Apple Developer**: https://developer.apple.com/documentation/

---

**Last Updated**: September 30, 2025  
**Maintainer**: Development Team