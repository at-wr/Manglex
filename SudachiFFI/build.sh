#!/bin/bash
set -e

echo "🦀 Building Sudachi for iOS..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Build for all iOS architectures
echo -e "${BLUE}Building for iOS device (arm64)...${NC}"
cargo build --release --target aarch64-apple-ios

echo -e "${BLUE}Building for iOS simulator (arm64)...${NC}"
cargo build --release --target aarch64-apple-ios-sim

echo -e "${BLUE}Building for iOS simulator (x86_64)...${NC}"
cargo build --release --target x86_64-apple-ios

# Create directories
mkdir -p target/universal/release

# Use workspace-level target directory
TARGET_DIR="../target"

# Create universal library for simulator
echo -e "${BLUE}Creating universal simulator library...${NC}"
lipo -create \
    ${TARGET_DIR}/aarch64-apple-ios-sim/release/libsudachi_ios.a \
    ${TARGET_DIR}/x86_64-apple-ios/release/libsudachi_ios.a \
    -output target/universal/release/libsudachi_ios_sim.a

# Generate C header
echo -e "${BLUE}Generating C header...${NC}"
cbindgen --config cbindgen.toml --crate sudachi-ios --output target/universal/release/sudachi_ios.h

# Create module maps for both architectures
echo -e "${BLUE}Creating module maps...${NC}"
cat > target/universal/release/module.modulemap << 'EOF'
module SudachiFFI {
    header "sudachi_ios.h"
    export *
}
EOF

# Create XCFramework
echo -e "${BLUE}Creating XCFramework...${NC}"
rm -rf SudachiFFI.xcframework

xcodebuild -create-xcframework \
    -library ${TARGET_DIR}/aarch64-apple-ios/release/libsudachi_ios.a \
    -headers target/universal/release \
    -library target/universal/release/libsudachi_ios_sim.a \
    -headers target/universal/release \
    -output SudachiFFI.xcframework

# Add module maps to each slice
echo -e "${BLUE}Adding module maps to XCFramework...${NC}"
cp target/universal/release/module.modulemap SudachiFFI.xcframework/ios-arm64/Headers/
cp target/universal/release/module.modulemap SudachiFFI.xcframework/ios-arm64_x86_64-simulator/Headers/

echo -e "${GREEN}✅ Build complete!${NC}"
echo "📦 Output: SudachiFFI.xcframework"
echo ""
echo "Next steps:"
echo "1. Copy SudachiFFI.xcframework to your Xcode project's Frameworks folder"
echo "2. Add it to your app target in Xcode"
echo "3. Import the Swift bridge files"
