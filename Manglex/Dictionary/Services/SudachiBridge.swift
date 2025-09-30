//
//  SudachiBridge.swift
//  Manglex
//
//  Created by Sudachi Integration
//
//  Low-level C FFI bridge to Sudachi Rust library
//  This file contains unsafe code and should not be used directly.
//  Use SudachiTokenizer instead.
//

import Foundation
import os.log

/// Low-level bridge to Sudachi C FFI
/// ⚠️ This class contains unsafe code. Do not use directly - use SudachiTokenizer instead.
final class SudachiBridge {
    
    // MARK: - Properties
    
    private var tokenizer: OpaquePointer?
    private let logger = Logger(subsystem: "com.manglex.sudachi", category: "FFIBridge")
    
    // MARK: - Initialization
    
    /// Initialize Sudachi with dictionary path
    /// - Parameter dictionaryPath: Full path to system.dic file
    /// - Throws: SudachiError if initialization fails
    init(dictionaryPath: String) throws {
        logger.info("Initializing Sudachi with dictionary: \(dictionaryPath)")
        
        // Verify dictionary file exists
        guard FileManager.default.fileExists(atPath: dictionaryPath) else {
            logger.error("Dictionary file not found at: \(dictionaryPath)")
            throw SudachiError.dictionaryNotFound(path: dictionaryPath)
        }
        
        // Call C FFI to initialize
        guard let cPath = dictionaryPath.cString(using: .utf8) else {
            logger.error("Failed to convert path to C string")
            throw SudachiError.invalidInput
        }
        
        tokenizer = sudachi_init(cPath)
        
        guard tokenizer != nil else {
            logger.error("sudachi_init returned NULL")
            throw SudachiError.initializationFailed
        }
        
        logger.info("✅ Sudachi initialized successfully")
    }
    
    deinit {
        if let tokenizer = tokenizer {
            logger.debug("Freeing Sudachi tokenizer")
            sudachi_free_tokenizer(tokenizer)
        }
    }
    
    // MARK: - Tokenization
    
    /// Tokenize text using Sudachi
    /// - Parameters:
    ///   - text: Japanese text to tokenize
    ///   - mode: Tokenization granularity mode
    /// - Returns: Array of tokens
    /// - Throws: SudachiError if tokenization fails
    func tokenize(_ text: String, mode: SudachiMode) throws -> [SudachiToken] {
        guard let tokenizer = tokenizer else {
            throw SudachiError.initializationFailed
        }
        
        guard !text.isEmpty else {
            return []
        }
        
        // Convert Swift string to C string
        guard let cText = text.cString(using: .utf8) else {
            logger.error("Failed to convert text to C string")
            throw SudachiError.invalidInput
        }
        
        // Call C FFI
        var count: UInt = 0
        let tokensPtr = sudachi_tokenize(
            tokenizer,
            cText,
            mode.cValue,
            &count
        )
        
        guard tokensPtr != nil else {
            logger.error("sudachi_tokenize returned NULL")
            throw SudachiError.tokenizationFailed
        }
        
        // Convert C tokens to Swift tokens
        var tokens: [SudachiToken] = []
        tokens.reserveCapacity(Int(count))
        
        for i in 0..<Int(count) {
            guard let tokenPtr = tokensPtr?[i] else {
                logger.warning("Token pointer at index \(i) is NULL")
                continue
            }
            
            let token = try convertCTokenToSwift(tokenPtr.pointee)
            tokens.append(token)
        }
        
        // Free C memory
        sudachi_free_tokens(tokensPtr, count)
        
        logger.debug("Tokenized '\(text)' into \(tokens.count) tokens")
        return tokens
    }
    
    // MARK: - Private Helpers
    
    /// Convert C token struct to Swift SudachiToken
    private func convertCTokenToSwift(_ cToken: SudachiSudachiToken) throws -> SudachiToken {
        // Extract surface (required)
        guard let surfacePtr = cToken.surface else {
            throw SudachiError.memoryAllocationFailed
        }
        let surface = String(cString: surfacePtr)
        
        // Extract reading (optional)
        let reading: String? = if let readingPtr = cToken.reading {
            String(cString: readingPtr)
        } else {
            nil
        }
        
        // Extract dictionary form (optional)
        let dictionaryForm: String? = if let dictPtr = cToken.dictionary_form {
            String(cString: dictPtr)
        } else {
            nil
        }
        
        // Extract normalized form (optional)
        let normalizedForm: String? = if let normPtr = cToken.normalized_form {
            String(cString: normPtr)
        } else {
            nil
        }
        
        // Extract POS tags (JSON array)
        var partOfSpeech: [String] = []
        if let posPtr = cToken.pos {
            let posJSON = String(cString: posPtr)
            if let data = posJSON.data(using: .utf8),
               let array = try? JSONDecoder().decode([String].self, from: data) {
                partOfSpeech = array
            } else {
                logger.warning("Failed to parse POS JSON: \(posJSON)")
            }
        }
        
        return SudachiToken(
            surface: surface,
            reading: reading,
            dictionaryForm: dictionaryForm,
            normalizedForm: normalizedForm,
            partOfSpeech: partOfSpeech,
            beginOffset: Int(cToken.begin),
            endOffset: Int(cToken.end)
        )
    }
}

// MARK: - Version Info

extension SudachiBridge {
    /// Get Sudachi library version
    static func version() -> String {
        if let versionPtr = sudachi_version() {
            return String(cString: versionPtr)
        }
        return "unknown"
    }
}
