//
//  JMDictFormatter.swift
//  RecManga
//
//  Created by Alan Ye on 7/30/25.
//

import Foundation

struct JMDictFormatter {
    static func formatAnalysis(_ analyses: [WordAnalysis], originalText: String) -> String {
        var result = ""
        
        // Add the original text with romanization
        let romanized = analyses.map { $0.romanized }.joined(separator: " ")
        result += "\"\(originalText)\"\n"
        result += "\(romanized)\n\n"
        
        // Add word-by-word analysis
        for (index, analysis) in analyses.enumerated() {
            result += formatWordAnalysis(analysis, index: index)
            if index < analyses.count - 1 {
                result += "\n"
            }
        }
        
        return result
    }
    
    private static func formatWordAnalysis(_ analysis: WordAnalysis, index: Int) -> String {
        var result = ""
        
        // Format the word header
        let header = "* \(analysis.romanized)  \(analysis.surface)"
        if analysis.surface != analysis.reading && !analysis.reading.isEmpty {
            result += "\(header) 【\(analysis.reading)】\n"
        } else {
            result += "\(header)\n"
        }
        
        // Add definitions
        if analysis.definitions.isEmpty {
            result += "1. [unknown] (no definition found)"
        } else {
            let uniqueDefinitions = Array(Set(analysis.definitions.map { $0.text }))
            for (defIndex, definition) in uniqueDefinitions.prefix(5).enumerated() {
                let defNumber = defIndex + 1
                let pos = analysis.partOfSpeech.isEmpty ? "" : "[\(formatPartOfSpeech(analysis.partOfSpeech))] "
                result += "\(defNumber). \(pos)\(definition)\n"
            }
            // Remove the last newline
            if result.hasSuffix("\n") {
                result.removeLast()
            }
        }
        
        return result
    }
    
    private static func formatPartOfSpeech(_ pos: [String]) -> String {
        let abbreviations: [String: String] = [
            "noun": "n",
            "verb": "v",
            "i-adjective": "adj-i",
            "na-adjective": "adj-na",
            "no-adjective": "adj-no",
            "adverb": "adv",
            "particle": "prt",
            "auxiliary verb": "aux-v",
            "copula": "cop",
            "interjection": "int",
            "pronoun": "pn",
            "expression": "exp",
            "transitive verb": "vt",
            "intransitive verb": "vi",
            "suru verb": "vs"
        ]
        
        let abbreviated = pos.compactMap { part in
            let lowercased = part.lowercased()
            return abbreviations[lowercased] ?? (lowercased.count <= 4 ? lowercased : nil)
        }
        
        return abbreviated.isEmpty ? pos.joined(separator: ", ") : abbreviated.joined(separator: ", ")
    }
    
    static func formatSimpleAnalysis(_ analyses: [WordAnalysis]) -> String {
        return analyses.map { analysis in
            let pos = analysis.partOfSpeech.isEmpty ? "" : " (\(formatPartOfSpeech(analysis.partOfSpeech)))"
            let firstDefinition = analysis.definitions.first?.text ?? "unknown"
            return "\(analysis.surface) [\(analysis.reading)] \(analysis.romanized)\(pos): \(firstDefinition)"
        }.joined(separator: "\n")
    }
}