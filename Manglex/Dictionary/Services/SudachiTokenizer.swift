//
//  SudachiTokenizer.swift
//  Manglex
//
//  Created by Sudachi Integration
//
//  High-level Swift API for Sudachi tokenization
//

import Foundation
import os.log

/// High-level Swift API for Japanese morphological analysis using Sudachi
@MainActor
final class SudachiTokenizer: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var isReady = false
    @Published private(set) var isInitializing = false
    
    // MARK: - Private Properties
    
    private var bridge: SudachiBridge?
    private let logger = Logger(subsystem: "com.manglex.sudachi", category: "Tokenizer")
    
    // Token cache for performance
    private var tokenCache: [String: [SudachiToken]] = [:]
    private let maxCacheSize = 100
    
    // MARK: - Initialization
    
    /// Initialize with dictionary path
    /// Call this during app startup
    func initialize(dictionaryPath: String) async throws {
        guard !isInitializing && !isReady else {
            logger.warning("Already initialized or initializing")
            return
        }
        
        isInitializing = true
        logger.info("Initializing Sudachi tokenizer...")
        
        do {
            // Initialize on background thread to avoid blocking UI
            let bridge = try await Task.detached(priority: .userInitiated) {
                try SudachiBridge(dictionaryPath: dictionaryPath)
            }.value
            
            await MainActor.run {
                self.bridge = bridge
                self.isReady = true
                self.isInitializing = false
                self.logger.info("✅ Sudachi tokenizer ready")
            }
        } catch {
            await MainActor.run {
                self.isInitializing = false
                self.logger.error("❌ Failed to initialize: \(error.localizedDescription)")
            }
            throw error
        }
    }
    
    /// Convenience initializer that finds dictionary in app bundle
    func initializeWithBundledDictionary() async throws {
        guard let dictPath = Bundle.main.path(forResource: "system", ofType: "dic") else {
            logger.error("system.dic not found in app bundle")
            throw SudachiError.dictionaryNotFound(path: "Bundle/system.dic")
        }
        
        try await initialize(dictionaryPath: dictPath)
    }
    
    // MARK: - Tokenization
    
    /// Tokenize Japanese text
    /// - Parameters:
    ///   - text: Japanese text to analyze
    ///   - mode: Tokenization granularity (default: .medium)
    ///   - useCache: Whether to use token cache (default: true)
    /// - Returns: Array of morphological tokens
    /// - Throws: SudachiError if tokenization fails
    func tokenize(
        _ text: String,
        mode: SudachiMode = .medium,
        useCache: Bool = true
    ) async throws -> [SudachiToken] {
        guard isReady, let bridge = bridge else {
            throw SudachiError.initializationFailed
        }
        
        // Check cache
        let cacheKey = "\(text):\(mode.rawValue)"
        if useCache, let cached = tokenCache[cacheKey] {
            logger.debug("Cache hit for: \(text.prefix(20))...")
            return cached
        }
        
        // Tokenize on background thread
        let tokens = try await Task.detached(priority: .userInitiated) {
            try bridge.tokenize(text, mode: mode)
        }.value
        
        // Update cache on main actor
        await MainActor.run {
            if useCache {
                updateCache(key: cacheKey, tokens: tokens)
            }
        }
        
        return tokens
    }
    
    /// Tokenize text synchronously (for use in non-async contexts)
    /// - Warning: This blocks the calling thread. Prefer async version when possible.
    func tokenizeSync(_ text: String, mode: SudachiMode = .medium) throws -> [SudachiToken] {
        guard isReady, let bridge = bridge else {
            throw SudachiError.initializationFailed
        }
        
        return try bridge.tokenize(text, mode: mode)
    }
    
    // MARK: - Cache Management
    
    private func updateCache(key: String, tokens: [SudachiToken]) {
        // Simple LRU: remove oldest if cache is full
        if tokenCache.count >= maxCacheSize {
            if let firstKey = tokenCache.keys.first {
                tokenCache.removeValue(forKey: firstKey)
            }
        }
        
        tokenCache[key] = tokens
    }
    
    /// Clear token cache
    func clearCache() {
        tokenCache.removeAll()
        logger.debug("Token cache cleared")
    }
    
    // MARK: - Utility Methods
    
    /// Extract all surface forms from tokens
    func surfaces(from tokens: [SudachiToken]) -> [String] {
        return tokens.map { $0.surface }
    }
    
    /// Extract all readings from tokens
    func readings(from tokens: [SudachiToken]) -> [String] {
        return tokens.map { $0.readingOrSurface }
    }
    
    /// Extract all base forms from tokens
    func baseForms(from tokens: [SudachiToken]) -> [String] {
        return tokens.map { $0.baseForm }
    }
    
    /// Filter tokens by part of speech
    func filterByPOS(_ tokens: [SudachiToken], primaryPOS: String) -> [SudachiToken] {
        return tokens.filter { $0.primaryPOS == primaryPOS }
    }
    
    /// Get nouns from tokens
    func nouns(from tokens: [SudachiToken]) -> [SudachiToken] {
        return tokens.filter { $0.primaryPOS == "名詞" }
    }
    
    /// Get verbs from tokens
    func verbs(from tokens: [SudachiToken]) -> [SudachiToken] {
        return tokens.filter { $0.primaryPOS == "動詞" }
    }
    
    // MARK: - Version Info
    
    /// Get Sudachi library version
    static func version() -> String {
        return SudachiBridge.version()
    }
}

// MARK: - Convenience Extensions

extension SudachiTokenizer {
    /// Tokenize and return surface forms only
    func tokenizeSurfaces(_ text: String, mode: SudachiMode = .medium) async throws -> [String] {
        let tokens = try await tokenize(text, mode: mode)
        return surfaces(from: tokens)
    }
    
    /// Tokenize and return readings only
    func tokenizeReadings(_ text: String, mode: SudachiMode = .medium) async throws -> [String] {
        let tokens = try await tokenize(text, mode: mode)
        return readings(from: tokens)
    }
    
    /// Tokenize and return base forms only
    func tokenizeBaseForms(_ text: String, mode: SudachiMode = .medium) async throws -> [String] {
        let tokens = try await tokenize(text, mode: mode)
        return baseForms(from: tokens)
    }
}
