//
//  WordDetailView.swift
//  Manglex
//
//  Comprehensive word detail view with morphological analysis
//

import SwiftUI

struct WordDetailView: View {
    let word: WordAnalysis
    @Environment(\.dismiss) private var dismiss
    @State private var showAllDefinitions = false
    
    private var posColor: Color {
        POSColorScheme.color(for: word)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Main word display
                    mainWordSection
                    
                    // Morphological information
                    if hasMorphologicalInfo {
                        morphologyCard
                    }
                    
                    // Word properties
                    if hasWordProperties {
                        propertiesCard
                    }
                    
                    // Definitions
                    definitionsCard
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
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
    
    // MARK: - Main Word Section
    
    private var mainWordSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                // Reading (if different from surface)
                if word.surface != word.reading && !word.reading.isEmpty {
                    Text(word.reading)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                // Surface form
                Text(word.surface)
                    .font(.system(size: 38, weight: .bold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(POSColorScheme.fillColor(for: word).opacity(0.8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(posColor, lineWidth: 2)
                            )
                    )
            }
            
            // Romanization
            if !word.romanized.isEmpty {
                Text(word.romanized)
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
    
    // MARK: - Morphological Information
    
    private var hasMorphologicalInfo: Bool {
        // Only show if there's actual conjugation data AND it's different from surface
        if let dictForm = word.dictionaryForm, dictForm != word.surface {
            return true
        }
        if let conjType = word.conjugationType, !conjType.isEmpty {
            return true
        }
        if let conjForm = word.conjugationForm, !conjForm.isEmpty {
            return true
        }
        return false
    }
    
    private var morphologyCard: some View {
        InfoCard(
            title: "Morphology",
            icon: "text.word.spacing",
            color: .green
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let dictForm = word.dictionaryForm, dictForm != word.surface {
                    InfoRow(
                        icon: "arrow.triangle.branch",
                        title: "Base Form",
                        value: dictForm,
                        color: .green
                    )
                }
                
                if let conjType = word.conjugationType {
                    InfoRow(
                        icon: "text.append",
                        title: "Conjugation Type",
                        value: conjType,
                        color: .teal
                    )
                }
                
                if let conjForm = word.conjugationForm {
                    InfoRow(
                        icon: "text.alignleft",
                        title: "Conjugation Form",
                        value: conjForm,
                        color: .cyan
                    )
                }
            }
        }
    }
    
    // MARK: - Word Properties
    
    private var hasWordProperties: Bool {
        return !word.partOfSpeech.isEmpty || word.sudachiPOS != nil || word.isCommon
    }
    
    private var propertiesCard: some View {
        InfoCard(
            title: "Properties",
            icon: "info.circle",
            color: .blue
        ) {
            VStack(alignment: .leading, spacing: 14) {
                // Part of Speech
                if let sudachiPOS = word.sudachiPOS, !sudachiPOS.isEmpty {
                    InfoRow(
                        icon: "tag",
                        title: "Part of Speech",
                        value: sudachiPOS.prefix(3).filter { $0 != "*" }.joined(separator: " · "),
                        color: posColor
                    )
                } else if !word.partOfSpeech.isEmpty {
                    InfoRow(
                        icon: "tag",
                        title: "Part of Speech",
                        value: word.partOfSpeech.joined(separator: ", "),
                        color: posColor
                    )
                }
                
                // Frequency
                if word.isCommon {
                    InfoRow(
                        icon: "star.fill",
                        title: "Frequency",
                        value: "Common word",
                        color: .orange
                    )
                }
                
                // Reading (if not shown above)
                if word.surface == word.reading && !word.reading.isEmpty {
                    InfoRow(
                        icon: "textformat.alt",
                        title: "Reading",
                        value: word.reading,
                        color: .purple
                    )
                }
            }
        }
    }
    
    // MARK: - Definitions
    
    private var definitionsCard: some View {
        InfoCard(
            title: word.definitions.isEmpty ? "No Definitions Found" : "Definitions (\(word.definitions.count))",
            icon: word.definitions.isEmpty ? "exclamationmark.triangle" : "book",
            color: word.definitions.isEmpty ? .orange : .indigo
        ) {
            if word.definitions.isEmpty {
                noDefinitionsView
            } else {
                definitionsListView
            }
        }
    }
    
    private var noDefinitionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This word was not found in the dictionary.")
                .font(.body)
                .foregroundColor(.primary)
            
            Text("This might be:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 4) {
                BulletPoint("A proper noun or place name")
                BulletPoint("A specialized or technical term")
                BulletPoint("Written in non-standard orthography")
                
                if word.dictionaryForm != nil {
                    BulletPoint("Try looking up the base form: \(word.dictionaryForm!)")
                        .foregroundColor(.blue)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    private var definitionsListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(word.prioritizedDefinitions.prefix(showAllDefinitions ? word.definitions.count : 8).enumerated()), id: \.offset) { index, definition in
                DefinitionRow(
                    number: index + 1,
                    definition: definition,
                    accentColor: posColor
                )
                
                if index < min(showAllDefinitions ? word.definitions.count : 8, word.definitions.count) - 1 {
                    Divider()
                        .padding(.vertical, 4)
                }
            }
            
            // Show more button
            if word.definitions.count > 8 && !showAllDefinitions {
                Button(action: {
                    withAnimation {
                        showAllDefinitions = true
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.down.circle")
                        Text("Show \(word.definitions.count - 8) more definitions")
                    }
                    .font(.body)
                    .foregroundColor(.blue)
                    .padding(.top, 8)
                }
            }
        }
    }
}

// MARK: - Info Card

struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            content
        }
        .padding(18)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 22)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Definition Row

struct DefinitionRow: View {
    let number: Int
    let definition: Definition
    let accentColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Number badge
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(accentColor.opacity(0.8))
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // POS tags
                if !definition.partOfSpeech.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(definition.partOfSpeech.prefix(3), id: \.self) { pos in
                            POSTagView(text: pos)
                        }
                    }
                }
                
                // Definition text
                Text(definition.text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Additional tags
                if !definition.tags.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(definition.tags.prefix(5), id: \.self) { tag in
                            TagView(text: tag)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct POSTagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.blue.opacity(0.15))
            )
            .foregroundColor(.blue)
    }
}

struct TagView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
            )
            .foregroundColor(.secondary)
    }
}

struct BulletPoint: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
        }
    }
}

// MARK: - FlowLayout (if not already defined)

struct FlowLayout: Layout {
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

#Preview {
    WordDetailView(word: WordAnalysis(
        surface: "食べた",
        reading: "たべた",
        romanized: "tabeta",
        definitions: [
            Definition(text: "ate; consumed", partOfSpeech: ["verb"], tags: [], senseOrder: 0, glossOrder: 0),
            Definition(text: "to eat (past tense)", partOfSpeech: ["verb"], tags: ["past"], senseOrder: 1, glossOrder: 0)
        ],
        partOfSpeech: ["verb"],
        isCommon: true,
        confidence: 0.9,
        entryId: 1,
        dictionaryForm: "食べる",
        normalizedForm: "食べる",
        sudachiPOS: ["動詞", "*", "*", "*", "一段-バ行", "連用形-一般"],
        conjugationType: "一段-バ行",
        conjugationForm: "連用形-一般"
    ))
}
