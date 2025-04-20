import Foundation
import Vision
import UIKit

class OCRService {
    // Enhanced implementation with more robust error handling and processing options
    
    enum OCRError: Error {
        case recognitionFailed
        case imageConversionFailed
        case noTextFound
        case processingCancelled
        
        var localizedDescription: String {
            switch self {
            case .recognitionFailed:
                return "Text recognition failed"
            case .imageConversionFailed:
                return "Failed to process the image"
            case .noTextFound:
                return "No text was found in the image"
            case .processingCancelled:
                return "Text recognition was cancelled"
            }
        }
    }
    
    struct OCROptions {
        var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
        var useLanguageCorrection: Bool = true
        var recognitionLanguages: [String]? = nil
        var minimumTextHeight: Float? = nil
        var customWords: [String]? = nil
        static let `default` = OCROptions()
        
        // Preset for scientific posters - optimized for mixed content
        static let scientificPoster = OCROptions(
            recognitionLevel: .accurate,
            useLanguageCorrection: true,
            recognitionLanguages: ["en-US"],
            minimumTextHeight: 0.01,  // Capture smaller text common in posters
            customWords: ["μg", "mL", "ng", "p-value", "ANOVA", "CRISPR", "PCR", "RNA", "DNA", 
                         "in vitro", "in vivo", "et al", "Fig.", "p<0.05", "p<0.01", "p<0.001"],
        )
    }
    
    // Main recognition method with options
    func recognizeText(from image: UIImage, 
                       options: OCROptions = .scientificPoster,
                       completion: @escaping (Result<String, Error>) -> Void) {
        
        guard let cgImage = image.cgImage else {
            completion(.failure(OCRError.imageConversionFailed))
            return
        }
        
        // Create a new image-request handler
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Create a new request to recognize text
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(OCRError.recognitionFailed))
                return
            }
            
            // Process the recognized text
            let recognizedText = observations.compactMap { observation in
                // Get the top candidate
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            if recognizedText.isEmpty {
                completion(.failure(OCRError.noTextFound))
            } else {
                completion(.success(recognizedText))
            }
        }
        
        // Configure the request based on options
        request.recognitionLevel = options.recognitionLevel
        request.usesLanguageCorrection = options.useLanguageCorrection
        
        if let languages = options.recognitionLanguages {
            request.recognitionLanguages = languages
        }
        
        if let minHeight = options.minimumTextHeight {
            request.minimumTextHeight = minHeight
        }
        
        if let customWords = options.customWords {
            request.customWords = customWords
        }
        
        do {
            // Perform the text-recognition request
            try requestHandler.perform([request])
        } catch {
            completion(.failure(error))
        }
    }
    
    // Additional method for processing scientific poster text
    func processScientificPosterText(_ text: String) -> String {
        // This method can be expanded to clean up and format the extracted text
        // from scientific posters, such as:
        // - Removing page numbers or irrelevant headers/footers
        // - Fixing common OCR errors in scientific notation
        // - Organizing text into sections if section headers are detected
        
        var processedText = text
        
        // Replace common OCR errors in scientific notation
        let replacements = [
            "µg": "μg",
            "uL": "μL",
            "ug/mL": "μg/mL",
            "u.g": "μg",
            "u.L": "μL",
            "p <": "p<",
            "p< ": "p<",
            "et. al": "et al",
            "et.al": "et al"
        ]
        
        for (incorrect, correct) in replacements {
            processedText = processedText.replacingOccurrences(of: incorrect, with: correct)
        }
        
        // Remove excessive whitespace
        processedText = processedText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Ensure paragraphs are properly separated
        processedText = processedText.replacingOccurrences(of: "\\.\\s+([A-Z])", with: ".\n$1", options: .regularExpression)
        
        return processedText
    }
    
    // Method to extract potential title from OCR text
    func extractPosterTitle(from text: String) -> String {
        // Scientific posters typically have the title at the beginning,
        // often in a larger font that OCR will capture first
        
        let lines = text.components(separatedBy: .newlines)
        
        // Try to find a good title candidate
        for line in lines.prefix(3) { // Check first 3 lines
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // If line is between 10 and 100 chars and doesn't look like an author list or affiliation
            if trimmed.count >= 10 && trimmed.count <= 100 &&
               !trimmed.contains("University of") &&
               !trimmed.contains("Department of") &&
               !trimmed.contains("et al") &&
               !trimmed.contains(",") && // Avoid author lists
               !trimmed.contains("Abstract") &&
               !trimmed.contains("Introduction") {
                return trimmed
            }
        }
        
        // Fallback: use first line if it's not too short
        if let firstLine = lines.first, firstLine.count >= 5 {
            return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Last resort
        return "Scientific Poster"
    }
}
