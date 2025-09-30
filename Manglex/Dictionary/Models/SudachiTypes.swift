//
//  SudachiTypes.swift
//  Manglex
//
//  Created by Sudachi Integration
//

import Foundation

// MARK: - Tokenization Mode

/// Sudachi tokenization granularity modes
enum SudachiMode: UInt8 {
    /// Short units (A mode) - finest granularity
    /// Example: "選挙管理委員会" → ["選挙", "管理", "委員", "会"]
    case short = 0
    
    /// Medium units (B mode) - balanced granularity (default)
    /// Example: "選挙管理委員会" → ["選挙", "管理委員会"]
    case medium = 1
    
    /// Long units (C mode) - coarsest granularity
    /// Example: "選挙管理委員会" → ["選挙管理委員会"]
    case long = 2
    
    /// Convert to C FFI enum
    var cValue: SudachiSudachiTokenMode {
        switch self {
        case .short: return A
        case .medium: return B
        case .long: return C
        }
    }
}

// MARK: - Token Data

/// A morphological token produced by Sudachi
struct SudachiToken: Equatable {
    /// Surface form (original text as it appears)
    let surface: String
    
    /// Reading in katakana (if available)
    let reading: String?
    
    /// Dictionary/base form (e.g., "食べた" → "食べる")
    let dictionaryForm: String?
    
    /// Normalized form (e.g., "打込む" → "打ち込む")
    let normalizedForm: String?
    
    /// Part-of-speech tags (hierarchical)
    /// Example: ["名詞", "普通名詞", "サ変可能"]
    let partOfSpeech: [String]
    
    /// Character offset where token begins
    let beginOffset: Int
    
    /// Character offset where token ends
    let endOffset: Int
    
    /// Whether this token is out-of-vocabulary (not in dictionary)
    var isOOV: Bool {
        return partOfSpeech.isEmpty || surface.isEmpty
    }
    
    /// Primary part of speech (first element)
    var primaryPOS: String {
        return partOfSpeech.first ?? "unknown"
    }
    
    /// Secondary part of speech (second element)
    var secondaryPOS: String? {
        return partOfSpeech.count > 1 ? partOfSpeech[1] : nil
    }
}

// MARK: - Error Types

/// Errors that can occur during Sudachi operations
enum SudachiError: Error, LocalizedError {
    case initializationFailed
    case dictionaryNotFound(path: String)
    case tokenizationFailed
    case invalidInput
    case memoryAllocationFailed
    
    var errorDescription: String? {
        switch self {
        case .initializationFailed:
            return "Failed to initialize Sudachi tokenizer"
        case .dictionaryNotFound(let path):
            return "Dictionary file not found at: \(path)"
        case .tokenizationFailed:
            return "Tokenization failed"
        case .invalidInput:
            return "Invalid input text"
        case .memoryAllocationFailed:
            return "Memory allocation failed"
        }
    }
}

// MARK: - Helper Extensions

extension SudachiToken {
    /// Returns the most appropriate form for display
    var displayForm: String {
        return normalizedForm ?? dictionaryForm ?? surface
    }
    
    /// Returns reading or surface if reading not available
    var readingOrSurface: String {
        return reading ?? surface
    }
    
    /// Returns dictionary form or surface if not available
    var baseForm: String {
        return dictionaryForm ?? surface
    }
}

// MARK: - CustomStringConvertible

extension SudachiToken: CustomStringConvertible {
    var description: String {
        var parts: [String] = []
        parts.append("surface: \(surface)")
        
        if let reading = reading, !reading.isEmpty {
            parts.append("reading: \(reading)")
        }
        
        if let dictForm = dictionaryForm, !dictForm.isEmpty, dictForm != surface {
            parts.append("base: \(dictForm)")
        }
        
        if !partOfSpeech.isEmpty {
            parts.append("pos: [\(partOfSpeech.joined(separator: ", "))]")
        }
        
        return "Token(\(parts.joined(separator: ", ")))"
    }
}

// MARK: - Codable Support

extension SudachiToken: Codable {
    enum CodingKeys: String, CodingKey {
        case surface
        case reading
        case dictionaryForm
        case normalizedForm
        case partOfSpeech
        case beginOffset
        case endOffset
    }
}
