import SwiftUI
import Combine

// PERFORMANCE: @MainActor ensures all @Published property updates happen on main thread
@MainActor
class CameraViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage = ""
    @Published var currentScan: PosterScan?
    
    private let ocrService = OCRService()
    private let openAIService = OpenAIService()
    private let categoryService = CategoryExtractionService.shared
    // Changed from private to public so it can be set directly
    var dataStore: DataStore?
    
    // Add initializer for dependency injection
    init(dataStore: DataStore? = nil) {
        self.dataStore = dataStore
    }
    
    func processImage(_ image: UIImage, hasPermission: Bool = false) {
        isLoading = true
        
        // Step 1: Extract text using OCR
        ocrService.recognizeText(from: image) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let extractedText):
                // Process the extracted text to clean up common OCR issues in scientific text
                let processedText = self.ocrService.processScientificPosterText(extractedText)

                // Step 2: Generate summary using OpenAI API
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
        print("🎯 CameraViewModel.generateSummary called with text length: \(text.count)")
        openAIService.generateStructuredSummary(from: text) { [weak self] result in
            guard let self = self else {
                print("❌ Self is nil in generateSummary callback")
                return
            }

            print("🎯 CameraViewModel received callback from OpenAI")

            DispatchQueue.main.async {
                self.isLoading = false

                switch result {
                case .success(let summary):
                    print("✅ CameraViewModel received successful summary with \(summary.count) points")

                    // Extract a title from the OCR text
                    let title = self.ocrService.extractPosterTitle(from: text)
                    print("📝 Extracted title: \(title)")

                    // Create a new scan with the results (without categories initially)
                    let newScan = PosterScan(
                        title: title,
                        rawText: text,
                        summaryPoints: summary,
                        image: image,
                        date: Date(),
                        hasPermission: hasPermission
                    )
                    self.currentScan = newScan
                    print("✅ Created new scan and set currentScan")

                    // Always save the scan to history
                    self.dataStore?.saveScan(newScan)
                    print("✅ Saved scan to dataStore")

                    // Step 3: Extract categories in the background (non-blocking)
                    self.extractCategories(for: newScan, rawText: text, summary: summary)

                case .failure(let error):
                    print("❌ CameraViewModel received error: \(error.localizedDescription)")
                    // Don't show an alarming alert: the scan is saved with its image and OCR
                    // text, and the summary screen offers a graceful "Generate summary" retry.

                    // Create a basic scan with just the OCR text so we don't lose the data
                    // This allows users to at least see what was captured even if summary generation failed
                    let title = self.ocrService.extractPosterTitle(from: text)
                    let fallbackScan = PosterScan(
                        title: title,
                        rawText: text,
                        summaryPoints: ["Unable to generate summary. Please try again later."],
                        image: image,
                        date: Date(),
                        hasPermission: hasPermission
                    )
                    self.currentScan = fallbackScan
                    print("⚠️ Created fallback scan due to error")

                    // Always save the fallback scan to history too
                    self.dataStore?.saveScan(fallbackScan)
                }
            }
        }
    }

    private func extractCategories(for scan: PosterScan, rawText: String, summary: [String]) {
        print("🏷️ Starting category extraction for scan: \(scan.id)")

        categoryService.extractCategories(from: rawText, summary: summary) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let categories):
                    print("✅ Extracted \(categories.count) categories: \(categories.map { $0.name })")

                    // Update the scan with categories
                    var updatedScan = scan
                    updatedScan.categories = categories

                    // Update currentScan if it's still the same scan
                    if self.currentScan?.id == scan.id {
                        self.currentScan = updatedScan
                        print("✅ Updated currentScan with categories")
                    }

                    // Update the scan in dataStore (saveScan handles updates by checking ID)
                    self.dataStore?.saveScan(updatedScan)
                    print("✅ Updated scan in dataStore with categories")

                case .failure(let error):
                    print("⚠️ Category extraction failed: \(error.localizedDescription)")
                    // Don't show error to user - categories are optional enhancement
                }
            }
        }
    }
}
