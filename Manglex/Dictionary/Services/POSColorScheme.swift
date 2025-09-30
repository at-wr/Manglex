//
//  POSColorScheme.swift
//  Manglex
//
//  Unified part-of-speech color scheme supporting both Sudachi and JMDict tags
//

import SwiftUI

struct POSColorScheme {
    
    /// Get color for a word based on its POS tags
    static func color(for word: WordAnalysis) -> Color {
        // Prioritize Sudachi POS if available
        if let sudachiPOS = word.sudachiPOS?.first {
            return colorForSudachiPOS(sudachiPOS)
        }
        
        // Fall back to JMDict POS
        if let jmdictPOS = word.partOfSpeech.first {
            return colorForJMDictPOS(jmdictPOS)
        }
        
        // Unknown
        return .gray
    }
    
    /// Get fill color (background)
    static func fillColor(for word: WordAnalysis) -> Color {
        return color(for: word).opacity(0.12)
    }
    
    /// Get border color
    static func borderColor(for word: WordAnalysis) -> Color {
        return color(for: word).opacity(0.35)
    }
    
    /// Get color for Sudachi POS tags (Japanese)
    private static func colorForSudachiPOS(_ pos: String) -> Color {
        switch pos {
        // Nouns (名詞)
        case let x where x.contains("名詞"):
            return .blue
            
        // Verbs (動詞)
        case let x where x.contains("動詞"):
            return .green
            
        // Adjectives (形容詞)
        case let x where x.contains("形容詞"):
            return .orange
            
        // Adverbs (副詞)
        case let x where x.contains("副詞"):
            return .purple
            
        // Particles (助詞)
        case let x where x.contains("助詞"):
            return .red
            
        // Auxiliary verbs (助動詞)
        case let x where x.contains("助動詞"):
            return .pink
            
        // Adnominal (連体詞)
        case let x where x.contains("連体詞"):
            return .indigo
            
        // Conjunctions (接続詞)
        case let x where x.contains("接続詞"):
            return .brown
            
        // Prefix (接頭辞)
        case let x where x.contains("接頭"):
            return .cyan
            
        // Suffix (接尾辞)
        case let x where x.contains("接尾"):
            return .teal
            
        // Interjections (感動詞)
        case let x where x.contains("感動詞"):
            return .yellow
            
        // Symbols (補助記号, 空白)
        case let x where x.contains("記号"), let x where x.contains("空白"):
            return .gray.opacity(0.5)
            
        default:
            return .gray
        }
    }
    
    /// Get color for JMDict POS tags (English)
    private static func colorForJMDictPOS(_ pos: String) -> Color {
        let lowercased = pos.lowercased()
        
        switch lowercased {
        case let x where x.contains("noun"):
            return .blue
        case let x where x.contains("verb") && !x.contains("aux"):
            return .green
        case let x where x.contains("adj"):
            return .orange
        case let x where x.contains("adv"):
            return .purple
        case let x where x.contains("prt"), let x where x.contains("particle"):
            return .red
        case let x where x.contains("aux"), let x where x.contains("cop"):
            return .pink
        case let x where x.contains("pref"):
            return .cyan
        case let x where x.contains("suf"):
            return .teal
        case let x where x.contains("int"):
            return .yellow
        case let x where x.contains("conj"):
            return .brown
        case let x where x.contains("exp"):
            return .indigo
        default:
            return .gray
        }
    }
    
    /// Get human-readable POS label
    static func label(for word: WordAnalysis) -> String {
        if let sudachiPOS = word.sudachiPOS, !sudachiPOS.isEmpty {
            // Show first 2-3 levels of Sudachi POS
            return sudachiPOS.prefix(3).filter { $0 != "*" }.joined(separator: " · ")
        }
        
        if let jmdictPOS = word.partOfSpeech.first {
            return jmdictPOS
        }
        
        return "unknown"
    }
    
    /// Get abbreviated POS label for compact display
    static func abbreviatedLabel(for word: WordAnalysis) -> String {
        let abbreviations: [String: String] = [
            "名詞": "N", "動詞": "V", "形容詞": "Adj", "副詞": "Adv",
            "助詞": "Prt", "助動詞": "Aux", "連体詞": "Adn", "接続詞": "Conj",
            "感動詞": "Int", "接頭辞": "Pref", "接尾辞": "Suff",
            "noun": "N", "verb": "V", "adjective": "Adj", "adverb": "Adv",
            "particle": "Prt", "auxiliary": "Aux", "conjunction": "Conj",
            "interjection": "Int", "prefix": "Pref", "suffix": "Suff"
        ]
        
        if let sudachiPOS = word.sudachiPOS?.first {
            return abbreviations[sudachiPOS] ?? sudachiPOS.prefix(4).uppercased()
        }
        
        if let jmdictPOS = word.partOfSpeech.first {
            let lowercased = jmdictPOS.lowercased()
            for (key, abbrev) in abbreviations {
                if lowercased.contains(key) {
                    return abbrev
                }
            }
            return jmdictPOS.prefix(4).uppercased()
        }
        
        return "?"
    }
}
