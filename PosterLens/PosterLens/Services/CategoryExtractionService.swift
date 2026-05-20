import Foundation

class CategoryExtractionService {
    static let shared = CategoryExtractionService()
    private let openAIService = OpenAIService()

    private init() {}

    /// Extract categories from poster text and summary using OpenAI
    func extractCategories(from rawText: String, summary: [String], completion: @escaping (Result<[PosterCategory], Error>) -> Void) {
        let prompt = createCategoryExtractionPrompt(rawText: rawText, summary: summary)

        openAIService.generateChatResponse(prompt: prompt) { [weak self] (result: Result<String, Error>) in
            switch result {
            case .success(let response):
                let categories = self?.parseCategories(from: response) ?? []
                completion(.success(categories))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Private Methods

    private func createCategoryExtractionPrompt(rawText: String, summary: [String]) -> String {
        return """
        Analyze this scientific or medical conference poster and extract relevant research categories as a structured JSON object. The poster could be from any field — do NOT assume oncology or any specific discipline.

        CATEGORY TYPES:
        1. Field: the discipline, subject area, or condition studied (e.g., "Oncology", "Cardiology", "Type 2 Diabetes", "Machine Learning", "Climate Science", "Neuroscience")
        2. Research Focus: the main objectives or topics (e.g., "Biomarkers", "Quality of Life", "Drug Efficacy", "Model Accuracy", "Prevalence")
        3. Methods: key methods, techniques, or interventions used (e.g., "Randomized Controlled Trial", "Immunotherapy", "Deep Learning", "Mass Spectrometry", "Surgery")
        4. Study Type: the study design or stage (e.g., "Phase III", "Meta-Analysis", "Cohort Study", "In Vitro", "Systematic Review", "Preclinical")

        INSTRUCTIONS:
        - Extract 1-3 items per type, only where clearly applicable
        - Use standard terminology appropriate to the poster's own field
        - Each item MUST be a short label of 1-3 words (max ~25 characters) — a tag, NOT a description or sentence. For example use "Treatment Efficacy", never "Efficacy Assessment of Tislelizumab in neoadjuvant treatment"
        - Omit any type that does not apply to this poster

        POSTER SUMMARY:
        \(summary.joined(separator: "\n"))

        POSTER TEXT SAMPLE:
        \(rawText.prefix(2000))

        Return ONLY a JSON object in this exact format (omit any inapplicable key):
        {
          "field": ["Field 1"],
          "researchFocus": ["Focus 1", "Focus 2"],
          "methods": ["Method 1", "Method 2"],
          "studyType": ["Study Type 1"]
        }
        """
    }

    private func parseCategories(from response: String) -> [PosterCategory] {
        var categories: [PosterCategory] = []

        // Try to extract JSON from the response
        guard let jsonData = extractJSON(from: response)?.data(using: .utf8) else {
            print("⚠️ Failed to extract JSON from category response")
            return categories
        }

        do {
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: [String]] ?? [:]

            // Parse field
            if let field = json["field"] {
                for name in field.prefix(3) {
                    if let clean = cleanCategoryName(name) {
                        categories.append(PosterCategory(type: .field, name: clean))
                    }
                }
            }

            // Parse research focus
            if let researchFocus = json["researchFocus"] {
                for name in researchFocus.prefix(3) {
                    if let clean = cleanCategoryName(name) {
                        categories.append(PosterCategory(type: .focus, name: clean))
                    }
                }
            }

            // Parse methods
            if let methods = json["methods"] {
                for name in methods.prefix(3) {
                    if let clean = cleanCategoryName(name) {
                        categories.append(PosterCategory(type: .methods, name: clean))
                    }
                }
            }

            // Parse study type
            if let studyType = json["studyType"] {
                for name in studyType.prefix(2) { // Usually 1-2
                    if let clean = cleanCategoryName(name) {
                        categories.append(PosterCategory(type: .studyType, name: clean))
                    }
                }
            }

        } catch {
            print("⚠️ Failed to parse category JSON: \(error)")
        }

        return categories
    }

    /// Normalize a category name to a short tag; drop sentence-like values the model
    /// occasionally returns instead of a concise label.
    private func cleanCategoryName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.count <= 40 else { return nil }
        return trimmed
    }

    private func extractJSON(from text: String) -> String? {
        // Try to find JSON object in the response
        if let range = text.range(of: #"\{[\s\S]*\}"#, options: .regularExpression) {
            return String(text[range])
        }

        // If no JSON found, return the whole text (might be valid JSON)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") && trimmed.hasSuffix("}") {
            return trimmed
        }

        return nil
    }
}
