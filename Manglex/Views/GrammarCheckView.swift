//
//  GrammarCheckView.swift
//  RecManga
//
//  Created by Alan Ye on 7/30/25.
//

import SwiftUI

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct GrammarCheckView: View {
    let selectedText: String
    
    var body: some View {
        MorphologyBreakdownView(selectedText: selectedText)
    }
}

// Legacy view - kept for compatibility
struct LegacyGrammarCheckView: View {
    let selectedText: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var analyzer = JMDictAnalyzer.shared
    @State private var analysisResult: [WordAnalysis] = []
    @State private var isAnalyzing = false
    @State private var selectedWord: WordAnalysis?
    @State private var showWordDetail = false
    @State private var showRomaji = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Enhanced header with controls
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sentence Breakdown")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Tap words for detailed analysis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Control buttons
                    HStack(spacing: 12) {
                        Button {
                            showRomaji.toggle()
                        } label: {
                            Image(systemName: showRomaji ? "textformat.characters.dottedunderline" : "textformat.characters.dottedunderline.ja")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(showRomaji ? .blue : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(
                Rectangle()
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if isAnalyzing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.9)
                            Text("Analyzing with JMDict...")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if !analysisResult.isEmpty {
                        VStack(spacing: 20) {
                            // Enhanced interactive word display
                            JMDictWordView(words: analysisResult, showRomaji: showRomaji) { word in
                                selectedWord = word
                                showWordDetail = true
                            }
                            .padding(.horizontal, 20)
                            
                            // Automatic word descriptions at bottom
                            if analysisResult.contains(where: { !$0.definitions.isEmpty }) {
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Word Descriptions")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 20)
                                    
                                    ForEach(Array(analysisResult.enumerated()), id: \.offset) { index, word in
                                        if !word.definitions.isEmpty {
                                            WordDescriptionRow(word: word)
                                                .padding(.horizontal, 20)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 12)
                    } else {
                        // Always show analyzing state initially, never "unavailable"
                        HStack {
                            ProgressView()
                                .scaleEffect(0.9)
                            Text("Initializing dictionary...")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground))
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            initializeAnalyzer()
        }
        .sheet(isPresented: $showWordDetail) {
            if let word = selectedWord {
                JMDictWordDetailView(word: word)
            }
        }
    }
    
    private func initializeAnalyzer() {
        isAnalyzing = true
        
        Task {
            if !analyzer.isReady {
                analyzer.initialize()
                
                // Wait for initialization with timeout
                let timeout = Date().addingTimeInterval(10)
                while !analyzer.isReady && Date() < timeout {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
            }
            
            if analyzer.isReady {
                let results = await analyzer.analyzeText(selectedText)
                await MainActor.run {
                    self.analysisResult = results
                    self.isAnalyzing = false
                }
            } else {
                await MainActor.run {
                    self.isAnalyzing = false
                }
            }
        }
    }
}

#Preview {
    GrammarCheckView(selectedText: "一覧は最高だぞ")
}

struct WordDescriptionRow: View {
    let word: WordAnalysis
    
    // Color scheme matching the word segments
    private var posColor: Color {
        switch word.primaryPOS {
        case "noun": return .blue
        case "verb": return .green
        case "adjective": return .orange
        case "adverb": return .purple
        case "particle": return .red
        case "auxiliary": return .pink
        case "prefix": return .cyan
        case "suffix": return .teal
        case "interjection": return .yellow
        case "other": return .indigo
        case "unknown": return .gray
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Word header with romanization and reading
            HStack(alignment: .top, spacing: 8) {
                // Colored indicator circle
                Circle()
                    .fill(posColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Word line: romanization + surface + reading + conjugation
                    HStack(spacing: 8) {
                        Text(word.romanized)
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(posColor)
                        
                        if word.surface != word.reading && !word.reading.isEmpty && containsKanji(word.surface) {
                            Text("\(word.surface) 【\(word.reading)】")
                                .font(.system(size: 14, weight: .medium))
                        } else {
                            Text(word.surface)
                                .font(.system(size: 14, weight: .medium))
                        }
                        
                        // Show conjugation indicator if word is conjugated
                        if let dictForm = word.dictionaryForm, dictForm != word.surface {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(dictForm)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    // Definitions (show first 2-3)
                    ForEach(Array(word.definitions.prefix(3).enumerated()), id: \.offset) { index, definition in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 16, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                if !definition.partOfSpeech.isEmpty {
                                    Text("[\(definition.partOfSpeech.prefix(2).joined(separator: ", "))]")
                                        .font(.caption)
                                        .foregroundColor(posColor)
                                        .fontWeight(.medium)
                                }
                                
                                Text(definition.text)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                        }
                    }
                    
                    // Show "more definitions" indicator if needed
                    if word.definitions.count > 3 {
                        Text("... and \(word.definitions.count - 3) more definitions")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 24)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    private func containsKanji(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FAF).contains(scalar.value)
        }
    }
}
