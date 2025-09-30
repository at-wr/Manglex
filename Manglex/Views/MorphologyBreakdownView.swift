//
//  MorphologyBreakdownView.swift
//  Manglex
//
//  Advanced morphological breakdown view with Sudachi integration
//

import SwiftUI

struct MorphologyBreakdownView: View {
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
            // Header
            headerView
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if isAnalyzing {
                        loadingView
                    } else if !analysisResult.isEmpty {
                        analysisContentView
                    } else {
                        loadingView
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
                WordDetailView(word: word)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Morphological Breakdown")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if analyzer.sudachiReady {
                        Label("Powered by Sudachi", systemImage: "sparkles")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Tap words for detailed analysis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Romaji toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRomaji.toggle()
                    }
                } label: {
                    Image(systemName: showRomaji ? "textformat.abc" : "textformat.abc.dottedunderline")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(showRomaji ? .blue : .secondary)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(showRomaji ? Color.blue.opacity(0.1) : Color.clear)
                        )
                }
                .buttonStyle(PlainButtonStyle())
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
    }
    
    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.9)
            Text(isAnalyzing ? "Analyzing..." : "Initializing...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var analysisContentView: some View {
        VStack(spacing: 20) {
            // Interactive word tokens
            MorphemeTokenView(
                words: analysisResult,
                showRomaji: showRomaji,
                onWordTap: { word in
                    selectedWord = word
                    showWordDetail = true
                }
            )
            .padding(.horizontal, 20)
            
            // Word descriptions
            if analysisResult.contains(where: { !$0.definitions.isEmpty }) {
                Divider()
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Definitions")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)
                    
                    ForEach(Array(analysisResult.enumerated()), id: \.offset) { index, word in
                        if !word.definitions.isEmpty {
                            MorphemeDescriptionCard(word: word) {
                                selectedWord = word
                                showWordDetail = true
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .padding(.top, 12)
    }
    
    // MARK: - Logic
    
    private func initializeAnalyzer() {
        isAnalyzing = true
        
        Task {
            if !analyzer.isReady {
                analyzer.initialize()
                
                // Wait for initialization
                let timeout = Date().addingTimeInterval(10)
                while !analyzer.isReady && Date() < timeout {
                    try? await Task.sleep(nanoseconds: 100_000_000)
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

// MARK: - Morpheme Token View

struct MorphemeTokenView: View {
    let words: [WordAnalysis]
    let showRomaji: Bool
    let onWordTap: (WordAnalysis) -> Void
    
    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(words.indices, id: \.self) { index in
                let word = words[index]
                MorphemeToken(word: word, showRomaji: showRomaji, onTap: {
                    onWordTap(word)
                })
            }
        }
    }
}

struct MorphemeToken: View {
    let word: WordAnalysis
    let showRomaji: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            // Reading/Romaji annotation
            if showRomaji {
                Text(word.romanized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(minHeight: 16)
            } else if !word.reading.isEmpty && containsKanji(word.surface) {
                Text(word.reading)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(minHeight: 16)
            } else {
                Spacer()
                    .frame(height: 16)
            }
            
            // Word surface with color coding
            Text(word.surface)
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(POSColorScheme.fillColor(for: word))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(POSColorScheme.borderColor(for: word), lineWidth: 1.5)
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }
        }
    }
    
    private func containsKanji(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FAF).contains(scalar.value)
        }
    }
}

// MARK: - Morpheme Description Card

struct MorphemeDescriptionCard: View {
    let word: WordAnalysis
    let onTap: () -> Void
    
    private var posColor: Color {
        POSColorScheme.color(for: word)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    // POS indicator
                    Circle()
                        .fill(posColor)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        // Word header
                        wordHeader
                        
                        // Content based on whether we have definitions
                        if !word.definitions.isEmpty {
                            // Show definitions
                            definitionsContent
                        } else {
                            // No definitions available
                            noDefinitionsContent
                        }
                    }
                    
                    Spacer()
                    
                    // Detail indicator
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var wordHeader: some View {
        HStack(spacing: 8) {
            // Romaji
            Text(word.romanized)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(posColor)
            
            // Surface + Reading
            if word.surface != word.reading && !word.reading.isEmpty && containsKanji(word.surface) {
                Text("\(word.surface) 【\(word.reading)】")
                    .font(.system(size: 14, weight: .semibold))
            } else {
                Text(word.surface)
                    .font(.system(size: 14, weight: .semibold))
            }
            
            // Conjugation indicator (only if different from surface)
            if let dictForm = word.dictionaryForm, dictForm != word.surface {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(dictForm)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var definitionsContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Show first definition only
            if let firstDef = word.prioritizedDefinitions.first {
                Text(firstDef.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            // Additional definitions count (subtle, secondary color)
            if word.definitions.count > 1 {
                Text("+ \(word.definitions.count - 1) more")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var noDefinitionsContent: some View {
        Text("Tap for morphological details")
            .font(.caption)
            .foregroundColor(.secondary)
            .italic()
    }
    
    private func containsKanji(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FAF).contains(scalar.value)
        }
    }
}

#Preview {
    MorphologyBreakdownView(selectedText: "今日は良い天気です")
}
