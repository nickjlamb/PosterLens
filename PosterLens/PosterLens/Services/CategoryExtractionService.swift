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
        Analyze this scientific poster and extract relevant research categories. Return the categories in a structured JSON format.

        CATEGORY TYPES:
        1. Cancer Types: Specific cancer types mentioned (e.g., "Lung Cancer", "Breast Cancer")
        2. Research Focus: Main research objectives (e.g., "Quality of Life", "Biomarkers", "Treatment Efficacy")
        3. Research Phases: Clinical trial phases or study type (e.g., "Phase II", "Phase III", "Meta-Analysis")
        4. Treatment Modalities: Types of treatments studied (e.g., "Chemotherapy", "Immunotherapy", "Targeted Therapy")

        INSTRUCTIONS:
        - Extract 1-3 categories per type (if applicable)
        - Use standardized terminology from oncology research
        - If a category type is not applicable, omit it from the response
        - Be specific but concise (e.g., "Non-Small Cell Lung Cancer" → "Lung Cancer")

        POSTER SUMMARY:
        \(summary.joined(separator: "\n"))

        POSTER TEXT SAMPLE:
        \(rawText.prefix(2000))

        Return ONLY a JSON object in this exact format:
        {
          "cancerTypes": ["Cancer Type 1", "Cancer Type 2"],
          "researchFocus": ["Focus Area 1", "Focus Area 2"],
          "researchPhases": ["Phase 1"],
          "treatmentModalities": ["Modality 1", "Modality 2"]
        }

        Omit any category type that is not applicable to this poster.
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

            // Parse cancer types
            if let cancerTypes = json["cancerTypes"] {
                for name in cancerTypes.prefix(3) { // Limit to 3
                    categories.append(PosterCategory(type: .cancerType, name: name))
                }
            }

            // Parse research focus
            if let researchFocus = json["researchFocus"] {
                for name in researchFocus.prefix(3) {
                    categories.append(PosterCategory(type: .researchFocus, name: name))
                }
            }

            // Parse research phases
            if let researchPhases = json["researchPhases"] {
                for name in researchPhases.prefix(2) { // Usually 1-2 phases
                    categories.append(PosterCategory(type: .researchPhase, name: name))
                }
            }

            // Parse treatment modalities
            if let treatmentModalities = json["treatmentModalities"] {
                for name in treatmentModalities.prefix(3) {
                    categories.append(PosterCategory(type: .treatmentModality, name: name))
                }
            }

        } catch {
            print("⚠️ Failed to parse category JSON: \(error)")
        }

        return categories
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
