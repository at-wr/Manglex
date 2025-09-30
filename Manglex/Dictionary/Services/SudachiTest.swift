//
//  SudachiTest.swift
//  Manglex
//
//  Created by Sudachi Integration
//
//  Test file to verify Sudachi integration
//

import Foundation

/// Test utilities for Sudachi integration
struct SudachiTest {
    
    /// Test that Sudachi FFI is loaded and accessible
    static func testFFILoaded() {
        print("🦀 Testing Sudachi FFI...")
        
        if let versionPtr = sudachi_version() {
            let version = String(cString: versionPtr)
            print("✅ Sudachi FFI loaded! Version: \(version)")
        } else {
            print("❌ Failed to get Sudachi version")
        }
    }
    
    /// Test basic tokenization
    @MainActor
    static func testBasicTokenization() async {
        print("\n🧪 Testing basic tokenization...")
        
        let tokenizer = SudachiTokenizer()
        
        do {
            // Initialize
            try await tokenizer.initializeWithBundledDictionary()
            print("✅ Tokenizer initialized")
            
            // Test simple text
            let text = "今日は良い天気です"
            let tokens = try await tokenizer.tokenize(text)
            
            print("📝 Input: \(text)")
            print("🔤 Tokens (\(tokens.count)):")
            for (i, token) in tokens.enumerated() {
                print("  \(i+1). \(token.surface)")
                if let reading = token.reading, !reading.isEmpty {
                    print("     Reading: \(reading)")
                }
                if !token.partOfSpeech.isEmpty {
                    print("     POS: [\(token.partOfSpeech.joined(separator: ", "))]")
                }
            }
            
            print("✅ Basic tokenization test passed!")
            
        } catch {
            print("❌ Tokenization test failed: \(error.localizedDescription)")
        }
    }
    
    /// Test multi-granular tokenization
    @MainActor
    static func testMultiGranular() async {
        print("\n🧪 Testing multi-granular tokenization...")
        
        let tokenizer = SudachiTokenizer()
        
        do {
            try await tokenizer.initializeWithBundledDictionary()
            
            let text = "選挙管理委員会"
            
            print("📝 Input: \(text)")
            
            // Test all three modes
            for mode in [SudachiMode.short, SudachiMode.medium, SudachiMode.long] {
                let tokens = try await tokenizer.tokenize(text, mode: mode)
                let surfaces = tokens.map { $0.surface }
                
                let modeName: String
                switch mode {
                case .short: modeName = "Short (A)"
                case .medium: modeName = "Medium (B)"
                case .long: modeName = "Long (C)"
                }
                
                print("\(modeName): [\(surfaces.joined(separator: ", "))]")
            }
            
            print("✅ Multi-granular test passed!")
            
        } catch {
            print("❌ Multi-granular test failed: \(error.localizedDescription)")
        }
    }
    
    /// Test conjugation handling
    @MainActor
    static func testConjugation() async {
        print("\n🧪 Testing conjugation handling...")
        
        let tokenizer = SudachiTokenizer()
        
        do {
            try await tokenizer.initializeWithBundledDictionary()
            
            let testCases = [
                "食べた",     // ate → to eat
                "見ている",   // seeing → to see
                "読んだ",     // read (past) → to read
            ]
            
            for text in testCases {
                let tokens = try await tokenizer.tokenize(text)
                
                for token in tokens where token.primaryPOS == "動詞" {
                    print("Surface: \(token.surface)")
                    if let dictForm = token.dictionaryForm, dictForm != token.surface {
                        print("  → Base form: \(dictForm)")
                    }
                }
            }
            
            print("✅ Conjugation test passed!")
            
        } catch {
            print("❌ Conjugation test failed: \(error.localizedDescription)")
        }
    }
    
    /// Run all tests
    @MainActor
    static func runAllTests() async {
        print("═══════════════════════════════════════")
        print("   🧪 Sudachi Integration Test Suite")
        print("═══════════════════════════════════════\n")
        
        testFFILoaded()
        await testBasicTokenization()
        await testMultiGranular()
        await testConjugation()
        
        print("\n═══════════════════════════════════════")
        print("   ✅ All tests complete!")
        print("═══════════════════════════════════════\n")
    }
}
