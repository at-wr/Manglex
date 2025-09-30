//
//  JMDictCheckView.swift
//  RecManga
//
//  Created by Alan Ye on 7/31/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct JMDictCheckView: View {
    let selectedText: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var analyzer = JMDictAnalyzer.shared
    @State private var analysisResult: [WordAnalysis] = []
    @State private var isAnalyzing = false
    @State private var selectedWord: WordAnalysis?
    @State private var showWordDetail = false
    @State private var showRomaji = false
    @State private var searchQuery = ""
    @State private var searchResults: [WordAnalysis] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Enhanced header with search capability
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dictionary Analysis")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Tap words for detailed definitions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Control buttons
                    HStack(spacing: 12) {
                        Button {
                            showRomaji.toggle()
                        } label: {
                            Image(systemName: showRomaji ? "text.cursor.ja" : "character.magnify.ja")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(showRomaji ? .blue : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search definitions...", text: $searchQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchQuery.isEmpty {
                        Button("Clear") {
                            searchQuery = ""
                            searchResults = []
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(
                Rectangle()
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Search results section
                    if !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search Results")
                                .font(.headline)
                                .padding(.horizontal, 20)
                            
                            LazyVStack(spacing: 8) {
                                ForEach(Array(searchResults.enumerated()), id: \.offset) { index, word in
                                    SearchResultCard(word: word) { selectedWord in
                                        self.selectedWord = selectedWord
                                        showWordDetail = true
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Divider()
                            .padding(.horizontal, 20)
                    }
                    
                    // Text analysis section
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
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Text Analysis")
                                .font(.headline)
                                .padding(.horizontal, 20)
                            
                            // Enhanced interactive word display
                            JMDictWordView(words: analysisResult, showRomaji: showRomaji) { word in
                                selectedWord = word
                                showWordDetail = true
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        }
                    } else {
                        // Always show analyzing state initially
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
        .background(Color(UIColor.systemGroupedBackground))
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
    
    private func performSearch() {
        guard !searchQuery.isEmpty, analyzer.isReady else { return }
        
        Task {
            let results = await analyzer.searchDefinitions(searchQuery)
            await MainActor.run {
                self.searchResults = results
            }
        }
    }
}

// MARK: - Search Result Card

struct SearchResultCard: View {
    let word: WordAnalysis
    let onTap: (WordAnalysis) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(word.surface)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        if !word.reading.isEmpty && word.reading != word.surface {
                            Text("(\(word.reading))")
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        
                        if word.isCommon {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if !word.partOfSpeech.isEmpty {
                        Text(word.partOfSpeech.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(UIColor.systemGray6))
                            )
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let firstDefinition = word.definitions.first {
                Text(firstDefinition.text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap(word)
        }
    }
}

struct JMDictWordView: View {
    let words: [WordAnalysis]
    let showRomaji: Bool
    let onWordTap: (WordAnalysis) -> Void
    
    var body: some View {
        LegacyFlowLayout(spacing: 4) {
            ForEach(words.indices, id: \.self) { index in
                let word = words[index]
                VStack(spacing: 4) {
                    // Furigana or Romaji - only show reading if surface contains kanji
                    if showRomaji {
                        Text(word.romanized)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(minHeight: 18)
                    } else if !word.reading.isEmpty && containsKanji(word.surface) {
                        Text(word.reading)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(minHeight: 18)
                    } else {
                        Spacer()
                            .frame(height: 18)
                    }
                    
                    Text(word.surface)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(wordTypeColor(word))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(wordTypeBorderColor(word), lineWidth: 1.5)
                                )
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onWordTap(word)
                        }
                        .hoverEffect(.lift)
                }
            }
        }
    }
    
    private func wordTypeColor(_ word: WordAnalysis) -> Color {
        // One color per part-of-speech type
        switch word.primaryPOS {
        case "noun":
            return Color.blue.opacity(0.15)
        case "verb":
            return Color.green.opacity(0.15)
        case "adjective":
            return Color.orange.opacity(0.15)
        case "adverb":
            return Color.purple.opacity(0.15)
        case "particle":
            return Color.red.opacity(0.12)
        case "auxiliary":
            return Color.pink.opacity(0.15)
        case "prefix":
            return Color.cyan.opacity(0.15)
        case "suffix":
            return Color.teal.opacity(0.15)
        case "interjection":
            return Color.yellow.opacity(0.15)
        case "other":
            return Color.indigo.opacity(0.12)
        case "unknown":
            return Color.gray.opacity(0.08)
        default:
            return Color.gray.opacity(0.08)
        }
    }
    
    private func wordTypeBorderColor(_ word: WordAnalysis) -> Color {
        // One color per part-of-speech type
        switch word.primaryPOS {
        case "noun":
            return Color.blue.opacity(0.4)
        case "verb":
            return Color.green.opacity(0.4)
        case "adjective":
            return Color.orange.opacity(0.4)
        case "adverb":
            return Color.purple.opacity(0.4)
        case "particle":
            return Color.red.opacity(0.3)
        case "auxiliary":
            return Color.pink.opacity(0.4)
        case "prefix":
            return Color.cyan.opacity(0.4)
        case "suffix":
            return Color.teal.opacity(0.4)
        case "interjection":
            return Color.yellow.opacity(0.4)
        case "other":
            return Color.indigo.opacity(0.3)
        case "unknown":
            return Color.gray.opacity(0.2)
        default:
            return Color.gray.opacity(0.2)
        }
    }
    
    private func containsKanji(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FAF).contains(scalar.value)
        }
    }
}

struct JMDictWordDetailView: View {
    let word: WordAnalysis
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Main word display
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            if word.surface != word.reading && !word.reading.isEmpty {
                                Text(word.reading)
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(word.surface)
                                .font(.system(size: 36, weight: .bold))
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(highlighterColor(for: word))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(highlighterBorderColor(for: word), lineWidth: 2)
                                        )
                                )
                        }
                        
                        // Romanization display
                        if !word.romanized.isEmpty {
                            VStack(spacing: 4) {
                                Text(word.romanized)
                                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray5))
                                    )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    
                    // Word Information card
                    if !word.partOfSpeech.isEmpty || word.isCommon || word.dictionaryForm != nil {
                        VStack(alignment: .leading, spacing: 16) {
                            AnalysisCard(
                                title: "Word Information",
                                backgroundColor: Color.green.opacity(0.1),
                                borderColor: Color.green.opacity(0.3)
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    // Conjugation/Dictionary Form (if available)
                                    if let dictForm = word.dictionaryForm, dictForm != word.surface {
                                        InfoRow(
                                            icon: "arrow.triangle.branch",
                                            title: "Dictionary Form",
                                            value: dictForm,
                                            color: .green
                                        )
                                    }
                                    
                                    // Conjugation details (Sudachi)
                                    if let conjType = word.conjugationType {
                                        InfoRow(
                                            icon: "text.word.spacing",
                                            title: "Conjugation Type",
                                            value: conjType,
                                            color: .teal
                                        )
                                    }
                                    
                                    if let conjForm = word.conjugationForm {
                                        InfoRow(
                                            icon: "text.append",
                                            title: "Conjugation Form",
                                            value: conjForm,
                                            color: .cyan
                                        )
                                    }
                                    
                                    // Part of Speech
                                    if let sudachiPOS = word.sudachiPOS, !sudachiPOS.isEmpty {
                                        InfoRow(
                                            icon: "text.badge.checkmark",
                                            title: "Part of Speech (Sudachi)",
                                            value: sudachiPOS.prefix(3).joined(separator: " / "),
                                            color: .blue
                                        )
                                    } else if !word.partOfSpeech.isEmpty {
                                        InfoRow(
                                            icon: "text.badge.checkmark",
                                            title: "Part of Speech",
                                            value: word.partOfSpeech.joined(separator: ", "),
                                            color: .blue
                                        )
                                    }
                                    
                                    if word.isCommon {
                                        InfoRow(
                                            icon: "star.fill",
                                            title: "Frequency",
                                            value: "Common word",
                                            color: .orange
                                        )
                                    }
                                    
                                    if word.surface != word.reading && !word.reading.isEmpty {
                                        InfoRow(
                                            icon: "textformat.alt",
                                            title: "Reading",
                                            value: word.reading,
                                            color: .purple
                                        )
                                    }
                                    
                                    InfoRow(
                                        icon: "globe",
                                        title: "Romanization",
                                        value: word.romanized,
                                        color: .indigo
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Detailed definitions card
                    if !word.definitions.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            AnalysisCard(
                                title: "Definitions (\(word.definitions.count))",
                                backgroundColor: Color.blue.opacity(0.1),
                                borderColor: Color.blue.opacity(0.3)
                            ) {
                                VStack(alignment: .leading, spacing: 16) {
                                    ForEach(Array(word.definitions.prefix(15).enumerated()), id: \.offset) { index, definition in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack(alignment: .top, spacing: 12) {
                                                Text("\(index + 1)")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                                    .frame(width: 24, height: 24)
                                                    .background(Circle().fill(Color.blue.opacity(0.7)))
                                                
                                                VStack(alignment: .leading, spacing: 6) {
                                                    if !definition.partOfSpeech.isEmpty {
                                                        HStack {
                                                            ForEach(definition.partOfSpeech, id: \.self) { pos in
                                                                Text(pos)
                                                                    .font(.caption2)
                                                                    .fontWeight(.medium)
                                                                    .padding(.horizontal, 6)
                                                                    .padding(.vertical, 2)
                                                                    .background(
                                                                        RoundedRectangle(cornerRadius: 4)
                                                                            .fill(partOfSpeechColor(pos))
                                                                    )
                                                                    .foregroundColor(partOfSpeechTextColor(pos))
                                                            }
                                                            Spacer()
                                                        }
                                                    }
                                                    
                                                    Text(definition.text)
                                                        .font(.body)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                        .foregroundColor(.primary)
                                                    
                                                    if !definition.tags.isEmpty {
                                                        HStack {
                                                            ForEach(definition.tags, id: \.self) { tag in
                                                                Text(tag)
                                                                    .font(.caption2)
                                                                    .padding(.horizontal, 4)
                                                                    .padding(.vertical, 1)
                                                                    .background(
                                                                        RoundedRectangle(cornerRadius: 3)
                                                                            .fill(Color.gray.opacity(0.2))
                                                                    )
                                                                    .foregroundColor(.secondary)
                                                            }
                                                            Spacer()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.vertical, 4)
                                        
                                        if index < word.definitions.prefix(15).count - 1 {
                                            Divider()
                                                .padding(.vertical, 4)
                                        }
                                    }
                                    
                                    if word.definitions.count > 15 {
                                        Text("... and \(word.definitions.count - 15) more definitions")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.top, 8)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // No definitions found
                        VStack(alignment: .leading, spacing: 16) {
                            AnalysisCard(
                                title: "Word Not Found",
                                backgroundColor: Color.orange.opacity(0.1),
                                borderColor: Color.orange.opacity(0.3)
                            ) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("This word was not found in the JMDict dictionary.")
                                            .font(.body)
                                    }
                                    
                                    Text("This might be:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 4)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("• A proper noun or place name")
                                        Text("• A conjugated form of a verb or adjective")
                                        Text("• A compound word or specialized term")
                                        Text("• Written in non-standard orthography")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Word Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func partOfSpeechColor(_ pos: String) -> Color {
        let lowercased = pos.lowercased()
        switch lowercased {
        case let x where x.contains("noun"):
            return Color.blue.opacity(0.3)
        case let x where x.contains("verb"):
            return Color.green.opacity(0.3)
        case let x where x.contains("adj"):
            return Color.orange.opacity(0.3)
        case let x where x.contains("adv"):
            return Color.purple.opacity(0.3)
        case let x where x.contains("prt"):
            return Color.red.opacity(0.3)
        case let x where x.contains("pref"), let x where x.contains("suf"):
            return Color.cyan.opacity(0.3)
        case let x where x.contains("cop"), let x where x.contains("aux"):
            return Color.pink.opacity(0.3)
        case let x where x.contains("int"):
            return Color.yellow.opacity(0.3)
        default:
            return Color.gray.opacity(0.2)
        }
    }
    
    private func partOfSpeechTextColor(_ pos: String) -> Color {
        let lowercased = pos.lowercased()
        switch lowercased {
        case let x where x.contains("noun"):
            return Color.blue
        case let x where x.contains("verb"):
            return Color.green
        case let x where x.contains("adj"):
            return Color.orange
        case let x where x.contains("adv"):
            return Color.purple
        case let x where x.contains("prt"):
            return Color.red
        case let x where x.contains("pref"), let x where x.contains("suf"):
            return Color.cyan
        case let x where x.contains("cop"), let x where x.contains("aux"):
            return Color.pink
        case let x where x.contains("int"):
            return Color.yellow.opacity(0.8)
        default:
            return Color.gray
        }
    }
    
    private func highlighterColor(for word: WordAnalysis) -> Color {
        // Use primaryPOS for consistent coloring
        switch word.primaryPOS {
        case "noun":
            return Color.blue.opacity(0.2)
        case "verb":
            return Color.green.opacity(0.2)
        case "adjective":
            return Color.orange.opacity(0.2)
        case "adverb":
            return Color.purple.opacity(0.2)
        case "particle":
            return Color.red.opacity(0.15)
        case "auxiliary":
            return Color.pink.opacity(0.2)
        case "prefix":
            return Color.cyan.opacity(0.2)
        case "suffix":
            return Color.teal.opacity(0.2)
        case "interjection":
            return Color.yellow.opacity(0.2)
        case "other":
            return Color.indigo.opacity(0.15)
        case "unknown":
            return Color.gray.opacity(0.1)
        default:
            return Color.gray.opacity(0.1)
        }
    }
    
    private func highlighterBorderColor(for word: WordAnalysis) -> Color {
        // Use primaryPOS for consistent coloring
        switch word.primaryPOS {
        case "noun":
            return Color.blue.opacity(0.5)
        case "verb":
            return Color.green.opacity(0.5)
        case "adjective":
            return Color.orange.opacity(0.5)
        case "adverb":
            return Color.purple.opacity(0.5)
        case "particle":
            return Color.red.opacity(0.4)
        case "auxiliary":
            return Color.pink.opacity(0.5)
        case "prefix":
            return Color.cyan.opacity(0.5)
        case "suffix":
            return Color.teal.opacity(0.5)
        case "interjection":
            return Color.yellow.opacity(0.5)
        case "other":
            return Color.indigo.opacity(0.4)
        case "unknown":
            return Color.gray.opacity(0.3)
        default:
            return Color.gray.opacity(0.3)
        }
    }
}

// Flow layout to arrange tokens naturally like text
struct LegacyFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions(by: CGSize(width: 10000, height: 10000)),
            subviews: subviews,
            spacing: spacing
        )
        return result.bounds
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: proposal.replacingUnspecifiedDimensions(by: bounds.size), subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: ProposedViewSize(result.frames[index].size))
        }
    }
    
    struct FlowResult {
        var bounds = CGSize.zero
        var frames: [CGRect] = []
        
        init(in bounds: CGSize, subviews: Subviews, spacing: CGFloat) {
            var origin = CGPoint.zero
            var lineHeight: CGFloat = 0
            var lineFrames: [CGRect] = []
            
            for subview in subviews {
                let size = subview.sizeThatFits(ProposedViewSize(bounds))
                
                if origin.x + size.width > bounds.width && !lineFrames.isEmpty {
                    // Move to next line
                    origin.x = 0
                    origin.y += lineHeight + spacing
                    lineHeight = 0
                }
                
                let frame = CGRect(origin: origin, size: size)
                lineFrames.append(frame)
                frames.append(frame)
                
                origin.x += size.width + spacing
                lineHeight = max(lineHeight, size.height)
                self.bounds.width = max(self.bounds.width, origin.x - spacing)
            }
            
            self.bounds.height = origin.y + lineHeight
        }
    }
}

struct AnalysisCard<Content: View>: View {
    let title: String
    let backgroundColor: Color
    let borderColor: Color
    let content: Content
    
    init(
        title: String,
        backgroundColor: Color,
        borderColor: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            content
        }
        .padding(16)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

#Preview {
    JMDictCheckView(selectedText: "一覧は最高だぞ")
}
