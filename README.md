# Manglex

Manglex is an iOS app that provides professional-grade Japanese morphological analysis for manga text using [Sudachi.rs](https://github.com/WorksApplications/sudachi.rs) and [JMDict](https://www.edrdg.org/jmdict/j_jmdict.html). Select text from manga images and get instant word breakdowns with conjugations, readings, and comprehensive definitions.

## Development

### Prerequisites Setup

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Add iOS targets
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

# Install cbindgen
cargo install cbindgen

# Verify installation
make check
```

### Building from Source

```bash
# Clone and setup
git clone https://github.com/at-wr/Manglex.git
cd Manglex
make all

open Manglex.xcodeproj
```

## Testing

### Run Tests

```bash
# Swift tests (in Xcode)
⌘U (Command+U)

# Or via command line
xcodebuild test -scheme Manglex -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Commands

| Command | Description |
|---------|-------------|
| `make all` | Complete setup and build |
| `make setup` | Clone dependencies and download dictionary |
| `make build-framework` | Build SudachiFFI.xcframework |
| `make install-framework` | Copy framework to Frameworks/ |
| `make dictionary` | Download Sudachi dictionary |
| `make rebuild` | Clean and rebuild framework |
| `make clean` | Remove build artifacts |
| `make clean-all` | Remove everything (deps + builds) |
| `make check` | Verify prerequisites |
| `make help` | Show available commands |


## Architecture

```
┌─────────────────────────────────────────┐
│         SwiftUI User Interface          │
│  MorphologyBreakdownView, WordDetailView│
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│        JMDictAnalyzer (Swift)           │
│   Dual-mode: Sudachi or Legacy         │
└──────┬────────────────────┬─────────────┘
       │                    │
┌──────▼─────────┐  ┌──────▼──────────┐
│ SudachiTokenizer│  │ JMDict Database │
│  (Swift API)    │  │   (SQLite)      │
└──────┬──────────┘  └─────────────────┘
       │
┌──────▼──────────┐
│ SudachiBridge   │  ← FFI Layer
│  (C wrapper)    │
└──────┬──────────┘
       │
┌──────▼──────────────────────────────────┐
│ SudachiFFI.xcframework (Rust → C API)  │
└──────┬──────────────────────────────────┘
       │
┌──────▼──────────┐
│  sudachi.rs     │  ← Core Engine
└─────────────────┘
```

### Key Components

- **SwiftUI** - The responsive UI
- **JMDictAnalyzer** - Main analysis coordinator
- **SudachiTokenizer** - High-level Swift API for Sudachi
- **SudachiBridge** - Low-level FFI wrapper
- **SudachiFFI** - Rust-to-C bridge (XCFramework)
- **sudachi.rs** - Core morphological engine


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Third-Party Licenses

- **Sudachi.rs**: Apache License 2.0
- **JMDict**: Creative Commons Attribution-ShareAlike 3.0
- **SudachiDict**: Apache License 2.0