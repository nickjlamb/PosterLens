import SwiftUI
import Combine

class CameraViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var currentScan: PosterScan?
    
    private let ocrService = OCRService()
    private let perplexityService = PerplexityService()
    
    func processImage(_ image: UIImage, hasPermission: Bool = false) {
        isLoading = true
        
        // Step 1: Extract text using OCR
        ocrService.recognizeText(from: image) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let extractedText):
                // Process the extracted text to clean up common OCR issues in scientific text
                let processedText = self.ocrService.processScientificPosterText(extractedText)
                
                // Step 2: Generate summary using Perplexity API
                self.generateSummary(from: processedText, image: image, hasPermission: hasPermission)
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.showingError = true
                    self.errorMessage = "OCR failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func generateSummary(from text: String, image: UIImage, hasPermission: Bool) {
        perplexityService.generateSummary(from: text) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                switch result {
                case .success(let summary):
                    // Extract a title from the OCR text
                    let title = self.ocrService.extractPosterTitle(from: text)
                    
                    // Create a new scan with the results
                    let newScan = PosterScan(
                        title: title,
                        rawText: text,
                        summaryPoints: summary,
                        image: image,
                        date: Date(),
                        hasPermission: hasPermission
                    )
                    self.currentScan = newScan
                    
                case .failure(let error):
                    self.showingError = true
                    
                    // Handle specific API key errors
                    if case PerplexityError.missingAPIKey = error {
                        self.errorMessage = "Perplexity API key is missing. Please add your API key in the app settings."
                    } else if case PerplexityError.apiError(let message) = error,
                              message.contains("authentication") || message.contains("key") {
                        self.errorMessage = "Invalid Perplexity API key. Please check your API key in the app settings."
                    } else {
                        self.errorMessage = "Summary generation failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
