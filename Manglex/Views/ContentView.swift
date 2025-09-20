//
//  ContentView.swift
//  RecManga
//
//  Created by Alan Ye on 7/29/25.
//

import SwiftUI
import VisionKit
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = OCRViewModel()
    @State private var isImagePickerPresented = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    if let image = viewModel.selectedImage {
                        LiveTextView(
                            image: image,
                            analysis: viewModel.analysis
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        EmptyStateView()
                    }
                    
                    if viewModel.isAnalyzing {
                        LoadingOverlay()
                    }
                }
            }
            .navigationTitle("Manglex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isImagePickerPresented = true
                    }) {
                        Image(systemName: "plus.circle.dashed")
                    }
                }
            }
            .sheet(isPresented: $isImagePickerPresented) {
                ImagePicker(selectedImage: $viewModel.selectedImage) {
                    if let image = viewModel.selectedImage {
                        viewModel.analyzeImage(image)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}


#Preview {
    ContentView()
}
