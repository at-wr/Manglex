//
//  JMDictAnalyzer.swift
//  RecManga
//
//  Created by Alan Ye on 7/31/25.
//

import Foundation
import SQLite3
import os.log

// MARK: - Data Models

struct WordAnalysis {
    let surface: String
    let reading: String
    let romanized: String
    let definitions: [Definition]
    let partOfSpeech: [String]
    let isCommon: Bool
    let primaryPOS: String
    let confidence: Double
    let entryId: Int
    
    init(surface: String, reading: String, romanized: String, definitions: [Definition], 
         partOfSpeech: [String], isCommon: Bool, confidence: Double = 1.0, entryId: Int = 0) {
        self.surface = surface
        self.reading = reading
        self.romanized = romanized
        self.definitions = definitions
        self.partOfSpeech = partOfSpeech
        self.isCommon = isCommon
        self.confidence = confidence
        self.entryId = entryId
        
        // Enhanced POS detection with better categorization
        if let firstPOS = partOfSpeech.first {
            let pos = firstPOS.lowercased()
            switch pos {
            case let x where x.contains("noun"):
                self.primaryPOS = "noun"
            case let x where x.contains("verb") && !x.contains("auxiliary"):
                self.primaryPOS = "verb"
            case let x where x.contains("adj"):
                self.primaryPOS = "adjective"
            case let x where x.contains("adv"):
                self.primaryPOS = "adverb"
            case let x where x.contains("prt"):
                self.primaryPOS = "particle"
            case let x where x.contains("aux"), let x where x.contains("cop"):
                self.primaryPOS = "auxiliary"
            case let x where x.contains("pref"):
                self.primaryPOS = "prefix"
            case let x where x.contains("suf"):
                self.primaryPOS = "suffix"
            case let x where x.contains("int"):
                self.primaryPOS = "interjection"
            case let x where x.contains("exp"):
                self.primaryPOS = "expression"
            case let x where x.contains("conj"):
                self.primaryPOS = "conjunction"
            default:
                self.primaryPOS = "other"
            }
        } else {
            self.primaryPOS = "unknown"
        }
    }
}

struct Definition {
    let text: String
    let partOfSpeech: [String]
    let tags: [String]
    let senseOrder: Int
    let glossOrder: Int
    
    init(text: String, partOfSpeech: [String] = [], tags: [String] = [], 
         senseOrder: Int = 0, glossOrder: Int = 0) {
        self.text = text
        self.partOfSpeech = partOfSpeech
        self.tags = tags
        self.senseOrder = senseOrder
        self.glossOrder = glossOrder
    }
}

struct DatabaseEntry {
    let id: Int
    let kanjiText: String?
    let kanaText: String
    let isCommon: Bool
    let definitions: [Definition]
    let partOfSpeech: [String]
}

// MARK: - Enhanced JMDict Analyzer

@MainActor
class JMDictAnalyzer: ObservableObject {
    static let shared = JMDictAnalyzer()
    
    // MARK: - Published Properties
    @Published var isReady = false
    
    // MARK: - Private Properties  
    private var db: OpaquePointer?
    private var isInitializing = false
    private var initializationTask: Task<Void, Never>?
    private var wordCache: Set<String> = []
    private var entryCache: [String: DatabaseEntry] = [:]
    private var cacheLoaded = false
    private var dbPath: String?
    
    // Enhanced logging
    private let logger = Logger(subsystem: "RecManga", category: "JMDictAnalyzer")
    
    private init() {}
    
    // MARK: - Initialization
    
    func initialize() {
        guard db == nil && !isInitializing else { 
            logger.warning("Initialize called but already initialized or initializing")
            return 
        }
        
        isInitializing = true
        logger.info("Starting dictionary initialization...")
        
        initializationTask = Task {
            let success = await withTaskGroup(of: Bool.self) { group in
                group.addTask { await self.initializeDatabase() }
                return await group.first(where: { $0 == true }) ?? false
            }
            
            await MainActor.run {
                if success {
                    self.isReady = true
                    self.logger.info("Dictionary initialization completed successfully")
                    
                    // Load caches on main actor to avoid threading issues
                    Task {
                        await self.loadWordCache()
                        await self.loadEntryCache()
                    }
                } else {
                    self.logger.error("Dictionary initialization failed")
                }
                self.isInitializing = false
            }
        }
    }
    
    private func initializeDatabase() async -> Bool {
        // Enhanced database path resolution with better error handling
        let possiblePaths = [
            Bundle.main.path(forResource: "jmdict-eng-3.6.1-20250728123310", ofType: "db"),
            Bundle.main.path(forResource: "jmdict-eng-3.6.1-20250728123310", ofType: "db", inDirectory: "Resources"),
            Bundle.main.resourcePath.flatMap { "\($0)/Resources/jmdict-eng-3.6.1-20250728123310.db" },
            Bundle.main.resourcePath.flatMap { "\($0)/jmdict-eng-3.6.1-20250728123310.db" }
        ]
        
        guard let dbPath = possiblePaths.compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            logger.error("Database file not found in bundle")
            logBundleContents()
            return false
        }
        
        logger.info("Found database at: \(dbPath)")
        
        var database: OpaquePointer?
        let result = sqlite3_open(dbPath, &database)
        
        guard result == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(database))
            logger.error("Failed to open database: \(errorMessage)")
            sqlite3_close(database)
            return false
        }
        
        // Verify database integrity
        guard await verifyDatabaseIntegrity(database!) else {
            logger.error("Database integrity check failed")
            sqlite3_close(database)
            return false
        }
        
        await MainActor.run {
            self.db = database
            self.dbPath = dbPath
        }
        
        return true
    }
    
    private func verifyDatabaseIntegrity(_ db: OpaquePointer) async -> Bool {
        let queries = [
            ("entries", "SELECT COUNT(*) FROM entries"),
            ("kanji_forms", "SELECT COUNT(*) FROM kanji_forms"),
            ("kana_readings", "SELECT COUNT(*) FROM kana_readings"),
            ("senses", "SELECT COUNT(*) FROM senses"),
            ("glosses", "SELECT COUNT(*) FROM glosses")
        ]
        
        for (tableName, query) in queries {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            
            guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK,
                  sqlite3_step(stmt) == SQLITE_ROW else {
                return false
            }
            
            let count = sqlite3_column_int(stmt, 0)
            logger.info("Table \(tableName): \(count) records")
            
            if count == 0 {
                logger.error("Table \(tableName) is empty")
                return false
            }
        }
        
        return true
    }
    
    private func logBundleContents() {
        guard let resourcePath = Bundle.main.resourcePath else { return }
        
        logger.debug("Bundle resource path: \(resourcePath)")
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
            logger.debug("Bundle contents: \(contents)")
            
            let resourcesPath = "\(resourcePath)/Resources"
            if FileManager.default.fileExists(atPath: resourcesPath) {
                let resourcesContents = try FileManager.default.contentsOfDirectory(atPath: resourcesPath)
                logger.debug("Resources folder contents: \(resourcesContents)")
            }
        } catch {
            logger.error("Failed to list bundle contents: \(error)")
        }
    }

    // MARK: - Text Analysis
    
    func analyzeText(_ text: String) async -> [WordAnalysis] {
        logger.info("Starting analysis of text: '\(text)'")
        
        guard let db = await getDatabase() else { 
            logger.error("Database not available")
            return [] 
        }
        
        let cleanedText = preprocessText(text)
        logger.debug("Cleaned text: '\(cleanedText)' (length: \(cleanedText.count))")
        
        guard !cleanedText.isEmpty else { 
            logger.warning("Cleaned text is empty")
            return [] 
        }
        
        // Use forward maximum matching for segmentation
        let segments = segmentText(cleanedText)
        logger.info("Segmented into \(segments.count) segments")
        
        var results: [WordAnalysis] = []
        
        for segment in segments {
            if let analysis = await lookupWordEnhanced(segment, in: db) {
                results.append(analysis)
            } else {
                // Create unknown word analysis
                results.append(createUnknownWordAnalysis(segment))
            }
        }
        
        logger.info("Analysis complete: \(results.count) words analyzed")
        return results
    }
    
    private func preprocessText(_ text: String) -> String {
        // Enhanced preprocessing with better Unicode handling
        let cleanedText = text
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove invisible Unicode characters
        let invisibleChars = CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{FEFF}\u{00AD}")
        return cleanedText.components(separatedBy: invisibleChars).joined()
    }
    
    private func createUnknownWordAnalysis(_ word: String) -> WordAnalysis {
        return WordAnalysis(
            surface: word,
            reading: word,
            romanized: romanizeHiragana(word),
            definitions: [],
            partOfSpeech: [],
            isCommon: false,
            confidence: 0.1
        )
    }
    
    // MARK: - Segmentation
    
    private func segmentText(_ text: String) -> [String] {
        logger.debug("Starting segmentation of: '\(text)'")
        
        var segments: [String] = []
        var currentIndex = text.startIndex
        
        while currentIndex < text.endIndex {
            let (segment, nextIndex) = findLongestMatch(in: text, from: currentIndex)
            segments.append(segment)
            logger.debug("Found segment: '\(segment)'")
            currentIndex = nextIndex
        }
        
        logger.debug("Segmentation complete. Total segments: \(segments.count)")
        return segments
    }
    
    private func findLongestMatch(in text: String, from startIndex: String.Index) -> (String, String.Index) {
        let remainingText = String(text[startIndex...])
        
        // Handle punctuation first
        if let firstChar = remainingText.first, isPunctuation(firstChar) {
            let endIndex = text.index(after: startIndex)
            return (String(firstChar), endIndex)
        }
        
        // Improved matching algorithm: prioritize common words and longer matches
        let maxCheckLength = min(remainingText.count, 15)
        var bestMatch: (String, String.Index, Bool)?  // (word, endIndex, isCommon)
        
        // Check from longest to shortest, but prioritize common words
        for length in stride(from: maxCheckLength, through: 1, by: -1) {
            let endIndex = text.index(startIndex, offsetBy: length, limitedBy: text.endIndex) ?? text.endIndex
            let candidate = String(text[startIndex..<endIndex])
            
            if hasWordInDictionary(candidate) {
                // Check if this is a common word
                let isCommon = isCommonWord(candidate)
                
                // If we found a match
                if bestMatch == nil {
                    bestMatch = (candidate, endIndex, isCommon)
                } else if let (bestWord, _, bestIsCommon) = bestMatch {
                    // Prefer common words over uncommon words
                    // For words of same commonality, prefer longer ones (already handled by loop order)
                    if isCommon && !bestIsCommon {
                        bestMatch = (candidate, endIndex, isCommon)
                    } else if isCommon == bestIsCommon && candidate.count > bestWord.count {
                        bestMatch = (candidate, endIndex, isCommon)
                    }
                }
                
                // If we found a long common word, we can break early
                if isCommon && length >= 3 {
                    break
                }
            }
        }
        
        // If we found a dictionary match, return it
        if let (word, endIndex, _) = bestMatch {
            return (word, endIndex)
        }
        
        // Fallback to character grouping
        return fallbackSegmentation(in: text, from: startIndex)
    }
    
    private func isCommonWord(_ word: String) -> Bool {
        // Quick check - could be improved by maintaining a common words cache
        guard let db = db else { return false }
        
        let queries = [
            "SELECT is_common FROM kanji_forms WHERE text = ? AND is_common = 1 LIMIT 1",
            "SELECT is_common FROM kana_readings WHERE text = ? AND is_common = 1 LIMIT 1"
        ]
        
        for query in queries {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, word, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                if sqlite3_step(stmt) == SQLITE_ROW {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func fallbackSegmentation(in text: String, from startIndex: String.Index) -> (String, String.Index) {
        var endIndex = text.index(after: startIndex)
        let firstChar = String(text[startIndex])
        let firstScalar = firstChar.unicodeScalars.first!.value
        
        // Group similar character types
        while endIndex < text.endIndex {
            let currentChar = String(text[endIndex])
            let currentScalar = currentChar.unicodeScalars.first!.value
            
            if !isCharacterTypeSimilar(firstScalar, currentScalar) {
                break
            }
            
            let extendedCandidate = String(text[startIndex...endIndex])
            if extendedCandidate.count >= 4 {
                break
            }
            
            endIndex = text.index(after: endIndex)
        }
        
        let result = String(text[startIndex..<endIndex])
        return (result, endIndex)
    }
    
    private func isPunctuation(_ char: Character) -> Bool {
        let scalar = char.unicodeScalars.first!.value
        return (0x3000...0x303F).contains(scalar) || // CJK punctuation
               (0xFF00...0xFFEF).contains(scalar) || // Fullwidth forms
               char.isPunctuation || char.isSymbol
    }

    // MARK: - Database Access
    
    private func getDatabase() async -> OpaquePointer? {
        if let db = db, isReady {
            return db
        }
        
        if !isInitializing && db == nil {
            initialize()
        }
        
        await initializationTask?.value
        return db
    }
    
    // MARK: - Enhanced Word Lookup (Fixed SQL)
    
    private func lookupWordEnhanced(_ word: String, in db: OpaquePointer) async -> WordAnalysis? {
        logger.debug("Enhanced lookup for word: '\(word)'")
        
        // First check cache
        if let entry = entryCache[word] {
            return createWordAnalysis(from: entry, surface: word)
        }
        
        // Try kanji lookup first
        if let result = await lookupByKanji(word, in: db) {
            return result
        }
        
        // Then try kana lookup
        if let result = await lookupByKana(word, in: db) {
            return result
        }
        
        return nil
    }
    
    private func lookupByKanji(_ word: String, in db: OpaquePointer) async -> WordAnalysis? {
        let sql = """
            SELECT DISTINCT 
                e.id,
                k.text as kanji,
                r.text as kana,
                k.is_common,
                s.parts_of_speech,
                g.text as gloss,
                s.sense_order,
                g.gloss_order
            FROM kanji_forms k
            JOIN entries e ON k.entry_id = e.id
            JOIN kana_readings r ON r.entry_id = e.id
            JOIN senses s ON s.entry_id = e.id
            JOIN glosses g ON g.sense_id = s.id
            WHERE k.text = ?
            ORDER BY k.is_common DESC, s.sense_order ASC, g.gloss_order ASC
            LIMIT 30
        """
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            logger.error("Failed to prepare kanji lookup query: \(errorMessage)")
            return nil
        }
        
        // FIXED: Use SQLITE_TRANSIENT for parameter binding
        sqlite3_bind_text(stmt, 1, word, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        logger.debug("Executing kanji lookup for: '\(word)'")
        
        let result = processLookupResults(stmt: stmt!, surface: word)
        if result != nil {
            logger.debug("Kanji lookup successful for: '\(word)'")
        } else {
            logger.debug("Kanji lookup returned no results for: '\(word)'")
        }
        
        return result
    }
    
    private func lookupByKana(_ word: String, in db: OpaquePointer) async -> WordAnalysis? {
        let sql = """
            SELECT DISTINCT 
                e.id,
                COALESCE(k.text, '') as kanji,
                r.text as kana,
                r.is_common,
                s.parts_of_speech,
                g.text as gloss,
                s.sense_order,
                g.gloss_order
            FROM kana_readings r
            JOIN entries e ON r.entry_id = e.id
            LEFT JOIN kanji_forms k ON k.entry_id = e.id
            JOIN senses s ON s.entry_id = e.id
            JOIN glosses g ON g.sense_id = s.id
            WHERE r.text = ?
            ORDER BY r.is_common DESC, s.sense_order ASC, g.gloss_order ASC
            LIMIT 30
        """
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            logger.error("Failed to prepare kana lookup query: \(errorMessage)")
            return nil
        }
        
        // FIXED: Use SQLITE_TRANSIENT for parameter binding
        sqlite3_bind_text(stmt, 1, word, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        logger.debug("Executing kana lookup for: '\(word)'")
        
        let result = processLookupResults(stmt: stmt!, surface: word)
        if result != nil {
            logger.debug("Kana lookup successful for: '\(word)'")
        } else {
            logger.debug("Kana lookup returned no results for: '\(word)'")
        }
        
        return result
    }
    
    private func processLookupResults(stmt: OpaquePointer, surface: String) -> WordAnalysis? {
        var definitions: [Definition] = []
        var entryId: Int = 0
        var kanjiText: String?
        var kanaText = ""
        var isCommon = false
        var allPartOfSpeech: Set<String> = []
        var rowCount = 0
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            rowCount += 1
            logger.debug("Processing row \(rowCount) for word '\(surface)'")
            
            if entryId == 0 {
                entryId = Int(sqlite3_column_int(stmt, 0))
                logger.debug("Entry ID: \(entryId)")
                
                if let kanjiPtr = sqlite3_column_text(stmt, 1) {
                    let kanjiStr = String(cString: kanjiPtr)
                    kanjiText = kanjiStr.isEmpty ? nil : kanjiStr
                    logger.debug("Kanji: '\(kanjiStr)'")
                }
                
                if let kanaPtr = sqlite3_column_text(stmt, 2) {
                    kanaText = String(cString: kanaPtr)
                    logger.debug("Kana: '\(kanaText)'")
                }
                
                isCommon = sqlite3_column_int(stmt, 3) == 1
                logger.debug("Is common: \(isCommon)")
            }
            
            // Get POS for this specific sense
            var sensePartOfSpeech: [String] = []
            if let posPtr = sqlite3_column_text(stmt, 4) {
                let posString = String(cString: posPtr)
                sensePartOfSpeech = parseJSONArray(posString)
                allPartOfSpeech.formUnion(sensePartOfSpeech)
                logger.debug("Sense parts of speech: \(sensePartOfSpeech)")
            }
            
            if let glossPtr = sqlite3_column_text(stmt, 5) {
                let glossText = String(cString: glossPtr)
                let senseOrder = Int(sqlite3_column_int(stmt, 6))
                let glossOrder = Int(sqlite3_column_int(stmt, 7))
                
                logger.debug("Adding definition: '\(glossText)' (sense: \(senseOrder), gloss: \(glossOrder))")
                
                // Use the specific POS for this sense/definition, not all POS
                definitions.append(Definition(
                    text: glossText,
                    partOfSpeech: sensePartOfSpeech,
                    tags: [],
                    senseOrder: senseOrder,
                    glossOrder: glossOrder
                ))
            }
        }
        
        logger.debug("Processed \(rowCount) rows, got \(definitions.count) definitions for '\(surface)'")
        
        guard !definitions.isEmpty else {
            logger.debug("No definitions found for word: '\(surface)'")
            return nil
        }
        
        // Create and cache entry
        let entry = DatabaseEntry(
            id: entryId,
            kanjiText: kanjiText,
            kanaText: kanaText,
            isCommon: isCommon,
            definitions: definitions,
            partOfSpeech: Array(allPartOfSpeech) // Use all POS for the word level
        )
        
        entryCache[surface] = entry
        logger.debug("Successfully created word analysis for '\(surface)' with \(definitions.count) definitions")
        
        return createWordAnalysis(from: entry, surface: surface)
    }
    
    private func createWordAnalysis(from entry: DatabaseEntry, surface: String) -> WordAnalysis {
        // Prefer the original surface that was segmented from the user's text so
        // the breakdown mirrors what was selected. Some dictionary entries use an
        // archaic kanji variant (e.g. 乃 for the particle の); falling back to the
        // canonical form only when the surface is empty prevents that mismatch.
        let trimmedSurface = surface.trimmingCharacters(in: .whitespacesAndNewlines)
        let displaySurface = trimmedSurface.isEmpty ? (entry.kanjiText ?? entry.kanaText)
                                                    : trimmedSurface
        let reading = entry.kanaText
        
        return WordAnalysis(
            surface: displaySurface,
            reading: reading,
            romanized: romanizeHiragana(reading),
            definitions: entry.definitions,
            partOfSpeech: entry.partOfSpeech,
            isCommon: entry.isCommon,
            confidence: 0.9,
            entryId: entry.id
        )
    }
    
    // MARK: - Caching System
    
    private func loadWordCache() async {
        guard let db = db, !cacheLoaded else { return }
        
        // Perform cache loading on main actor to avoid threading issues
        var words: Set<String> = []
        
        // Load kanji forms
        let kanjiSql = "SELECT DISTINCT text FROM kanji_forms WHERE LENGTH(text) <= 8"
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, kanjiSql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let text = sqlite3_column_text(stmt, 0) {
                    words.insert(String(cString: text))
                }
            }
        }
        sqlite3_finalize(stmt)
        
        // Load kana readings
        let kanaSql = "SELECT DISTINCT text FROM kana_readings WHERE LENGTH(text) <= 8"
        if sqlite3_prepare_v2(db, kanaSql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let text = sqlite3_column_text(stmt, 0) {
                    words.insert(String(cString: text))
                }
            }
        }
        sqlite3_finalize(stmt)
        
        self.wordCache = words
        self.cacheLoaded = true
        self.logger.info("Loaded \(words.count) words into cache")
    }
    
    private func loadEntryCache() async {
        // Entry cache will be populated on-demand during lookups for optimal performance
        logger.debug("Entry cache initialized - will populate on-demand")
    }
    
    private func hasWordInDictionary(_ word: String) -> Bool {
        if cacheLoaded {
            return wordCache.contains(word)
        }
        
        // Fallback to database query
        guard let db = db else { return false }
        
        let queries = [
            "SELECT 1 FROM kanji_forms WHERE text = ? LIMIT 1",
            "SELECT 1 FROM kana_readings WHERE text = ? LIMIT 1"
        ]
        
        for query in queries {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                // FIXED: Use SQLITE_TRANSIENT for parameter binding
                sqlite3_bind_text(stmt, 1, word, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                if sqlite3_step(stmt) == SQLITE_ROW {
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Character Analysis and Utilities
    
    private func isCharacterTypeSimilar(_ first: UInt32, _ second: UInt32) -> Bool {
        let isFirstHiragana = (0x3040...0x309F).contains(first)
        let isSecondHiragana = (0x3040...0x309F).contains(second)
        
        let isFirstKatakana = (0x30A0...0x30FF).contains(first)
        let isSecondKatakana = (0x30A0...0x30FF).contains(second)
        
        let isFirstKanji = (0x4E00...0x9FAF).contains(first)
        let isSecondKanji = (0x4E00...0x9FAF).contains(second)
        
        let isFirstASCII = first < 0x80
        let isSecondASCII = second < 0x80
        
        return (isFirstHiragana && isSecondHiragana) ||
               (isFirstKatakana && isSecondKatakana) ||
               (isFirstKanji && isSecondKanji) ||
               (isFirstASCII && isSecondASCII)
    }
    
    private func parseJSONArray(_ jsonString: String) -> [String] {
        guard let data = jsonString.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return []
        }
        return array
    }
    
    private func romanizeHiragana(_ hiragana: String) -> String {
        let hiraganaToRomaji: [String: String] = [
            "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
            "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
            "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
            "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
            "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
            "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
            "だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
            "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
            "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
            "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
            "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
            "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
            "や": "ya", "ゆ": "yu", "よ": "yo",
            "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
            "わ": "wa", "ゐ": "wi", "ゑ": "we", "を": "wo", "ん": "n",
            "ー": "", "っ": "", "ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o",
            "ゃ": "ya", "ゅ": "yu", "ょ": "yo", "ゎ": "wa"
        ]
        
        var romanized = ""
        var i = hiragana.startIndex
        
        while i < hiragana.endIndex {
            let char = String(hiragana[i])
            
            // Handle small tsu (っ) - double next consonant
            if char == "っ" && hiragana.index(after: i) < hiragana.endIndex {
                let nextChar = String(hiragana[hiragana.index(after: i)])
                if let nextRomaji = hiraganaToRomaji[nextChar] {
                    if let firstChar = nextRomaji.first {
                        romanized += String(firstChar)
                    }
                }
                i = hiragana.index(after: i)
                continue
            }
            
            if let romaji = hiraganaToRomaji[char] {
                romanized += romaji
            } else {
                romanized += char
            }
            
            i = hiragana.index(after: i)
        }
        
        return romanized
    }
    
    // MARK: - Full-Text Search
    
    func searchDefinitions(_ query: String) async -> [WordAnalysis] {
        guard let db = await getDatabase() else { return [] }
        
        logger.info("Searching definitions for: '\(query)'")
        
        let sql = """
            SELECT DISTINCT 
                e.id,
                COALESCE(k.text, '') as kanji,
                r.text as kana,
                CASE WHEN k.is_common = 1 OR r.is_common = 1 THEN 1 ELSE 0 END as is_common,
                s.parts_of_speech,
                g.text as gloss
            FROM glosses_fts gfts
            JOIN glosses g ON gfts.rowid = g.id
            JOIN senses s ON g.sense_id = s.id
            JOIN entries e ON s.entry_id = e.id
            LEFT JOIN kanji_forms k ON e.id = k.entry_id
            JOIN kana_readings r ON e.id = r.entry_id
            WHERE glosses_fts MATCH ?
            ORDER BY is_common DESC
            LIMIT 20
        """
        
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            logger.error("Failed to prepare FTS query")
            return []
        }
        
        // FIXED: Use SQLITE_TRANSIENT for parameter binding
        sqlite3_bind_text(stmt, 1, query, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        var results: [WordAnalysis] = []
        var processedEntries: Set<Int> = []
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            let entryId = Int(sqlite3_column_int(stmt, 0))
            
            // Skip duplicates
            guard !processedEntries.contains(entryId) else { continue }
            processedEntries.insert(entryId)
            
            var kanjiText: String?
            if let kanjiPtr = sqlite3_column_text(stmt, 1) {
                let kanjiStr = String(cString: kanjiPtr)
                kanjiText = kanjiStr.isEmpty ? nil : kanjiStr
            }
            
            let kanaText = sqlite3_column_text(stmt, 2).map { String(cString: $0) } ?? ""
            let isCommon = sqlite3_column_int(stmt, 3) == 1
            let glossText = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
            
            var partOfSpeech: [String] = []
            if let posPtr = sqlite3_column_text(stmt, 4) {
                let posString = String(cString: posPtr)
                partOfSpeech = parseJSONArray(posString)
            }
            
            let surface = kanjiText ?? kanaText
            let definition = Definition(text: glossText, partOfSpeech: partOfSpeech)
            
            let analysis = WordAnalysis(
                surface: surface,
                reading: kanaText,
                romanized: romanizeHiragana(kanaText),
                definitions: [definition],
                partOfSpeech: partOfSpeech,
                isCommon: isCommon,
                confidence: 0.8,
                entryId: entryId
            )
            
            results.append(analysis)
        }
        
        logger.info("Found \(results.count) search results")
        return results
    }
    
    // MARK: - Cleanup
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
}
