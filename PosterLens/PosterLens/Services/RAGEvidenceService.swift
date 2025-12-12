import Foundation

final class RAGEvidenceService {
    static let shared = RAGEvidenceService()

    #if DEBUG
    private static let enableDebugLogs = false
    #else
    private static let enableDebugLogs = false
    #endif

    private let endpoint = Config.evidenceAPIURL
    private let apiKey = Config.evidenceAPIKey

    private init() {
        // Only log warnings (empty API key)
        if apiKey.isEmpty {
            print("[RAG] Warning: Evidence API key is empty")
        }
    }

    func fetchEvidence(for text: String) async throws -> EvidenceResult {
        guard FeatureFlags.usePubMedRAG else {
            throw NSError(domain: "RAGEvidenceService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "PubMed RAG feature is disabled."
            ])
        }

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30  // 30 second timeout for cold starts
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body = ["text": text]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "RAGEvidenceService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Server returned status \(http.statusCode)"
            ])
        }

        return try JSONDecoder().decode(EvidenceResult.self, from: data)
    }
}
