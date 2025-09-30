//
//  RomajiConverter.swift
//  Manglex
//
//  Comprehensive romaji converter supporting hiragana and katakana
//

import Foundation

struct RomajiConverter {
    
    /// Convert Japanese text (hiragana/katakana) to romaji
    static func toRomaji(_ text: String) -> String {
        // First try converting katakana to hiragana for unified processing
        let hiraganaText = katakanaToHiragana(text)
        return hiraganaToRomaji(hiraganaText)
    }
    
    /// Convert katakana to hiragana
    private static func katakanaToHiragana(_ text: String) -> String {
        return text.unicodeScalars.map { scalar -> String in
            let value = scalar.value
            // Katakana range: 0x30A0-0x30FF → Hiragana range: 0x3040-0x309F
            if (0x30A1...0x30F6).contains(value) {
                let hiraganaValue = value - 0x0060
                return String(UnicodeScalar(hiraganaValue)!)
            }
            // Small katakana
            else if value == 0x30F7 { return "わ" } // ヷ
            else if value == 0x30F8 { return "ゐ" } // ヸ
            else if value == 0x30F9 { return "ゑ" } // ヹ
            else if value == 0x30FA { return "を" } // ヺ
            // Katakana middle dot and prolonged sound mark
            else if value == 0x30FB { return "・" } // ・
            else if value == 0x30FC { return "ー" } // ー
            else {
                return String(scalar)
            }
        }.joined()
    }
    
    /// Convert hiragana to romaji with proper handling of combinations
    private static func hiraganaToRomaji(_ hiragana: String) -> String {
        let mapping: [String: String] = [
            // Basic hiragana
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
            // Small kana
            "ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o",
            "ゃ": "ya", "ゅ": "yu", "ょ": "yo", "ゎ": "wa",
            // Special
            "ー": "", "っ": "", "・": "·"
        ]
        
        var result = ""
        var i = hiragana.startIndex
        
        while i < hiragana.endIndex {
            // Check for combinations (ki + ya = kya)
            if hiragana.index(after: i) < hiragana.endIndex {
                let current = String(hiragana[i])
                let next = String(hiragana[hiragana.index(after: i)])
                
                // Handle small tsu (っ) - double next consonant
                if current == "っ", let nextRomaji = mapping[next], let firstChar = nextRomaji.first {
                    result += String(firstChar)
                    i = hiragana.index(after: i)
                    continue
                }
                
                // Handle combinations like きゃ (kya), しゃ (sha), ちゃ (cha)
                if ["ゃ", "ゅ", "ょ"].contains(next) {
                    if let currentRomaji = mapping[current] {
                        let baseRomaji = currentRomaji.dropLast() // Remove 'i' sound
                        if let smallRomaji = mapping[next] {
                            result += baseRomaji + smallRomaji
                            i = hiragana.index(i, offsetBy: 2)
                            continue
                        }
                    }
                }
            }
            
            // Regular character
            let char = String(hiragana[i])
            result += mapping[char] ?? char
            i = hiragana.index(after: i)
        }
        
        return result
    }
}
