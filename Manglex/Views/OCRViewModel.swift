//
//  OCRViewModel.swift
//  RecManga
//
//  Created by Alan Ye on 7/30/25.
//

import SwiftUI
import VisionKit

@MainActor
class OCRViewModel: ObservableObject {
    @Published var selectedImage: UIImage?
    @Published var analysis: ImageAnalysis?
    @Published var isAnalyzing = false
    @Published var analyzedText: String = ""
    
    private let analyzer = ImageAnalyzer()
    
    func analyzeImage(_ image: UIImage) {
        isAnalyzing = true
        analysis = nil
        analyzedText = ""
        
        Task {
            do {
                let configuration = ImageAnalyzer.Configuration([.text])
                let analysis = try await analyzer.analyze(image, configuration: configuration)
                
                await MainActor.run {
                    self.analysis = analysis
                    self.isAnalyzing = false
                    self.analyzedText = analysis.transcript
                }
            } catch {
                await MainActor.run {
                    self.isAnalyzing = false
                    print("Failed to analyze image: \(error)")
                }
            }
        }
    }
}
