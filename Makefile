# Manglex Build System
# Automates Sudachi FFI framework building and dependency management

.PHONY: all setup build-framework install-framework clean clean-all help

# Configuration
SUDACHI_REPO := https://github.com/WorksApplications/sudachi.rs.git
SUDACHI_VERSION := develop
EXT_DIR := Ext
SUDACHI_DIR := $(EXT_DIR)/sudachi.rs
FFI_DIR := SudachiFFI
FRAMEWORKS_DIR := Frameworks
XCFRAMEWORK := SudachiFFI.xcframework
DICTIONARY_URL := https://github.com/WorksApplications/SudachiDict/releases/download/v20250728/sudachi-dictionary-20250728-core.zip
DICTIONARY_FILE := Manglex/Resources/system.dic

# Colors for output
GREEN := \033[0;32m
BLUE := \033[0;34m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

all: setup build-framework install-framework
	@echo "$(GREEN)✅ Build complete!$(NC)"
	@echo "$(BLUE)📦 Framework installed to $(FRAMEWORKS_DIR)/$(XCFRAMEWORK)$(NC)"

help:
	@echo "$(BLUE)Manglex Build System$(NC)"
	@echo ""
	@echo "Available targets:"
	@echo "  $(GREEN)make all$(NC)              - Complete setup and build"
	@echo "  $(GREEN)make setup$(NC)            - Clone dependencies and download dictionary"
	@echo "  $(GREEN)make build-framework$(NC)  - Build SudachiFFI.xcframework"
	@echo "  $(GREEN)make install-framework$(NC) - Copy framework to Frameworks/"
	@echo "  $(GREEN)make dictionary$(NC)       - Download Sudachi dictionary"
	@echo "  $(GREEN)make clean$(NC)            - Clean build artifacts"
	@echo "  $(GREEN)make clean-all$(NC)        - Clean everything including dependencies"
	@echo "  $(GREEN)make help$(NC)             - Show this help"

setup: $(SUDACHI_DIR) $(DICTIONARY_FILE)
	@echo "$(GREEN)✅ Setup complete!$(NC)"

# Clone sudachi.rs repository
$(SUDACHI_DIR):
	@echo "$(BLUE)📥 Cloning sudachi.rs repository...$(NC)"
	@mkdir -p $(EXT_DIR)
	@git clone --depth 1 --branch $(SUDACHI_VERSION) $(SUDACHI_REPO) $(SUDACHI_DIR)
	@echo "$(GREEN)✅ Repository cloned$(NC)"

# Download and extract dictionary
$(DICTIONARY_FILE):
	@echo "$(BLUE)📥 Downloading Sudachi dictionary...$(NC)"
	@mkdir -p Manglex/Resources
	@mkdir -p tmp
	@curl -L $(DICTIONARY_URL) -o tmp/dictionary.zip
	@echo "$(BLUE)📦 Extracting dictionary...$(NC)"
	@unzip -q tmp/dictionary.zip -d tmp/
	@mv tmp/system_core.dic $(DICTIONARY_FILE)
	@rm -rf tmp
	@echo "$(GREEN)✅ Dictionary installed ($(shell du -h $(DICTIONARY_FILE) | cut -f1))$(NC)"

dictionary: $(DICTIONARY_FILE)

# Build the FFI framework
build-framework: $(SUDACHI_DIR)
	@echo "$(BLUE)🔨 Building SudachiFFI.xcframework...$(NC)"
	@# Copy FFI code to sudachi.rs workspace
	@mkdir -p $(SUDACHI_DIR)/sudachi-ios
	@cp -r $(FFI_DIR)/* $(SUDACHI_DIR)/sudachi-ios/
	@# Add to workspace if not already added
	@if ! grep -q 'sudachi-ios' $(SUDACHI_DIR)/Cargo.toml; then \
		echo "$(YELLOW)Adding sudachi-ios to workspace...$(NC)"; \
		sed -i.bak '/"python",/a\'$$'\n''    "sudachi-ios",' $(SUDACHI_DIR)/Cargo.toml; \
	fi
	@# Update plugin loader for iOS if needed
	@if ! grep -q 'target_os = "ios"' $(SUDACHI_DIR)/sudachi/src/plugin/loader.rs; then \
		echo "$(YELLOW)Patching sudachi for iOS...$(NC)"; \
		sed -i.bak 's/target_os = "macos"/target_os = "macos", target_os = "ios"/' $(SUDACHI_DIR)/sudachi/src/plugin/loader.rs; \
	fi
	@# Build the framework
	@cd $(SUDACHI_DIR)/sudachi-ios && ./build.sh
	@# Copy back to our directory
	@cp -r $(SUDACHI_DIR)/sudachi-ios/$(XCFRAMEWORK) $(FFI_DIR)/
	@echo "$(GREEN)✅ Framework built successfully$(NC)"

# Install framework to Xcode project
install-framework: $(FFI_DIR)/$(XCFRAMEWORK)
	@echo "$(BLUE)📦 Installing framework...$(NC)"
	@mkdir -p $(FRAMEWORKS_DIR)
	@rm -rf $(FRAMEWORKS_DIR)/$(XCFRAMEWORK)
	@cp -r $(FFI_DIR)/$(XCFRAMEWORK) $(FRAMEWORKS_DIR)/
	@echo "$(GREEN)✅ Framework installed$(NC)"

# Check if framework exists
$(FFI_DIR)/$(XCFRAMEWORK):
	@echo "$(RED)❌ Framework not found. Run 'make build-framework' first.$(NC)"
	@exit 1

# Clean build artifacts
clean:
	@echo "$(YELLOW)🧹 Cleaning build artifacts...$(NC)"
	@rm -rf $(FFI_DIR)/target
	@rm -rf $(FFI_DIR)/$(XCFRAMEWORK)
	@if [ -d "$(SUDACHI_DIR)/sudachi-ios" ]; then \
		cd $(SUDACHI_DIR)/sudachi-ios && cargo clean 2>/dev/null || true; \
	fi
	@echo "$(GREEN)✅ Build artifacts cleaned$(NC)"

# Clean everything including dependencies
clean-all: clean
	@echo "$(YELLOW)🧹 Cleaning all dependencies...$(NC)"
	@rm -rf $(EXT_DIR)
	@rm -rf $(FRAMEWORKS_DIR)/$(XCFRAMEWORK)
	@rm -f $(DICTIONARY_FILE)
	@echo "$(GREEN)✅ All dependencies cleaned$(NC)"
	@echo "$(BLUE)ℹ️  Run 'make all' to rebuild everything$(NC)"

# Rebuild framework only (faster)
rebuild: clean build-framework install-framework
	@echo "$(GREEN)✅ Framework rebuilt!$(NC)"

# Update dictionary only
update-dictionary:
	@echo "$(YELLOW)🔄 Updating dictionary...$(NC)"
	@rm -f $(DICTIONARY_FILE)
	@$(MAKE) dictionary

# Check prerequisites
check:
	@echo "$(BLUE)🔍 Checking prerequisites...$(NC)"
	@command -v cargo >/dev/null 2>&1 || (echo "$(RED)❌ Rust/Cargo not found. Install from https://rustup.rs/$(NC)" && exit 1)
	@command -v cbindgen >/dev/null 2>&1 || (echo "$(RED)❌ cbindgen not found. Install with: cargo install cbindgen$(NC)" && exit 1)
	@command -v xcodebuild >/dev/null 2>&1 || (echo "$(RED)❌ Xcode not found. Install from App Store$(NC)" && exit 1)
	@rustup target list --installed | grep -q aarch64-apple-ios || (echo "$(YELLOW)⚠️  Adding iOS targets...$(NC)" && rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios)
	@echo "$(GREEN)✅ All prerequisites satisfied$(NC)"
