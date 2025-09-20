//
//  LiveTextView.swift
//  RecManga
//
//  Created by Alan Ye on 7/30/25.
//

import SwiftUI
import VisionKit

class CustomImageView: UIImageView {
    weak var coordinator: LiveTextImageView.Coordinator?
}

struct LiveTextView: View {
    let image: UIImage
    let analysis: ImageAnalysis?
    @State private var grammarSheetData: String? = nil
    
    var body: some View {
        LiveTextImageView(
            image: image,
            analysis: analysis,
            grammarSheetData: $grammarSheetData
        )
        .sheet(item: Binding<GrammarSheetItem?>(
            get: { grammarSheetData.map { GrammarSheetItem(text: $0) } },
            set: { grammarSheetData = $0?.text }
        )) { item in
            GrammarCheckView(selectedText: item.text)
        }
    }
}

struct GrammarSheetItem: Identifiable {
    let id = UUID()
    let text: String
}

struct LiveTextImageView: UIViewRepresentable {
    let image: UIImage
    let analysis: ImageAnalysis?
    @Binding var grammarSheetData: String?
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let imageView = CustomImageView()
        let interaction = ImageAnalysisInteraction()
        
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.coordinator = context.coordinator
        
        // Configure Live Text interaction
        interaction.preferredInteractionTypes = .automatic
        interaction.delegate = context.coordinator
        interaction.isSupplementaryInterfaceHidden = false
        
        imageView.addInteraction(interaction)
        
        // Add long press gesture for JMDict analysis
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.6
        imageView.addGestureRecognizer(longPressGesture)
        
        scrollView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        
        context.coordinator.imageView = imageView
        context.coordinator.interaction = interaction
        context.coordinator.parent = self
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if let analysis = analysis {
            context.coordinator.interaction?.analysis = analysis
        }
        context.coordinator.imageView?.image = image
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate, ImageAnalysisInteractionDelegate {
        var imageView: CustomImageView?
        var interaction: ImageAnalysisInteraction?
        var parent: LiveTextImageView?
        private var lastSelectedText: String = ""
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }
        
        // MARK: - ImageAnalysisInteractionDelegate  
        func textSelectionDidChange(_ interaction: ImageAnalysisInteraction) {
            lastSelectedText = interaction.selectedText
        }
        
        func highlightSelectedItemsDidChange(_ interaction: ImageAnalysisInteraction) {
            // Handle highlight changes if needed
        }
        
        func presentingViewControllerForImageAnalysisInteraction(_ interaction: ImageAnalysisInteraction) -> UIViewController? {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                return window.rootViewController
            }
            return nil
        }
        
        func interaction(_ interaction: ImageAnalysisInteraction, shouldBeginAt point: CGPoint, for interactionType: ImageAnalysisInteraction.InteractionTypes) -> Bool {
            return true
        }
        
        func showGrammarCheck(for text: String) {
            guard let parent = parent else { return }
            
            Task { @MainActor in
                parent.grammarSheetData = text
            }
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            
            guard let interaction = interaction else { return }
            
            let currentSelectedText = interaction.selectedText
            let textToUse = currentSelectedText.isEmpty ? lastSelectedText : currentSelectedText
            
            guard !textToUse.isEmpty else { return }
            
            showGrammarCheck(for: textToUse)
        }
    }
}

#Preview {
    if let image = UIImage(systemName: "photo") {
        LiveTextView(image: image, analysis: nil)
    }
}
