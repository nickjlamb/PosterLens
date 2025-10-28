import Foundation

enum OpenAIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(String)
    case invalidResponse
    case apiError(String)
    case missingAPIKey
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .requestFailed(let message):
            return "API request failed: \(message)"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let message):
            return "API error: \(message)"
        case .missingAPIKey:
            return "OpenAI API key is missing"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

class OpenAIService {
    var apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    /// Initialize OpenAI service with optional API key
    /// - Parameter apiKey: Optional API key (loads from Secrets.plist if not provided)
    init(apiKey: String? = nil) {
        // Use SecretManager to load API key
        self.apiKey = SecretManager.shared.loadAPIKey(for: "OpenAI_API_Key", fallback: apiKey)

        print("🔑 OpenAIService initialized with API key: \(self.apiKey.prefix(8))...")
    }

    /// Check if the current API key is valid for OpenAI
    var hasValidAPIKey: Bool {
        return SecretManager.shared.isValid(apiKey: apiKey, requiredPrefix: "sk-")
    }
    
    /// Update the API key (useful for testing or key rotation)
    /// - Parameter key: The new API key to use
    func setAPIKey(_ key: String) {
        apiKey = key
    }
    
    /// Generate a chat response using OpenAI's GPT model
    /// - Parameters:
    ///   - prompt: The input prompt for the AI
    ///   - completion: Completion handler with Result containing the response string or error
    /// - Note: Uses automatic retry logic with exponential backoff for resilience
    func generateChatResponse(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Validate API key
        if !hasValidAPIKey {
            completion(.failure(NetworkError.missingAPIKey(service: "OpenAI")))
            return
        }

        guard let url = URL(string: baseURL) else {
            completion(.failure(NetworkError.badRequest("Invalid API URL")))
            return
        }

        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Create the request body
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo", // Using GPT-3.5 Turbo for better cost efficiency
            "messages": [
                ["role": "system", "content": "You are a helpful scientific assistant that specializes in answering questions about scientific posters. You provide clear, concise, and accurate information based on the poster's content."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1024,
            "temperature": 0.3 // Lower temperature for more focused, factual responses
        ]

        print("🚀 Using OpenAI API key: \(apiKey.prefix(8))...") // Only log prefix for security

        // Serialize the request body
        do {
            let requestData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = requestData

            // Debug logging - print request without sensitive data
            print("📤 API Request sent to OpenAI - model: gpt-3.5-turbo, max_tokens: 1024")
        } catch {
            print("❌ Serialization error: \(error.localizedDescription)")
            completion(.failure(NetworkError.malformedData))
            return
        }

        // Use NetworkRequestHelper with retry logic for resilient requests
        Task {
            do {
                let (data, _) = try await NetworkRequestHelper.makeRequest(
                    request,
                    config: .default
                )

                // Debug that data was received (without exposing full content)
                print("📥 API Response received (\(data.count) bytes)")

                // Check for API error in response
                if let errorMessage = SafeJSONParser.extractErrorMessage(data) {
                    print("❌ API returned error: \(errorMessage)")
                    completion(.failure(NetworkError.apiError(service: "OpenAI", message: errorMessage)))
                    return
                }

                // Safe JSON parsing using SafeJSONParser
                guard let content: String = SafeJSONParser.parse(data, keyPath: "choices.0.message.content") else {
                    print("❌ Failed to extract content from JSON structure")
                    completion(.failure(NetworkError.malformedData))
                    return
                }

                print("✅ Successfully extracted content from response (\(content.count) characters)")

                // Ensure the content is cleaned up and ready for display
                let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

                if cleanContent.isEmpty {
                    print("❌ Content is empty after cleaning")
                    completion(.failure(NetworkError.emptyResponse))
                } else {
                    print("✅ Calling completion with success")
                    completion(.success(cleanContent))
                }

            } catch let error as NetworkError {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
            } catch {
                print("❌ Unexpected error: \(error.localizedDescription)")
                completion(.failure(NetworkError.from(error)))
            }
        }
    }

    /// Generate a structured summary from OCR-extracted text
    /// - Parameters:
    ///   - text: The raw text extracted from a scientific poster
    ///   - completion: Completion handler with Result containing structured bullet points or error
    /// - Note: Returns 6 bullet points covering research question, patient population, primary endpoint, methodology, results, and conclusions
    func generateStructuredSummary(from text: String, completion: @escaping (Result<[String], Error>) -> Void) {
        // Validate API key
        if !hasValidAPIKey {
            completion(.failure(NetworkError.missingAPIKey(service: "OpenAI")))
            return
        }

        let summaryPrompt = """
        You are a scientific summarization assistant. Analyze the following text extracted from a scientific poster and create a structured summary.

        Please provide EXACTLY 6 bullet points covering:
        1. Main Research Question/Objective
        2. Patient Population (if applicable - include sample size, key inclusion/exclusion criteria, demographics)
        3. Primary Endpoint - IMPORTANT: Only include this if the poster explicitly uses the phrase "Primary Endpoint" or "primary endpoint". If found, copy the exact wording from the poster verbatim - do NOT paraphrase, infer, or rewrite it. If the poster does not explicitly mention "Primary Endpoint", write "Not applicable".
        4. Methodology Used
        5. Key Results and Findings
        6. Main Conclusions and Implications

        Format each point starting with "**[Category]**: " followed by the content.

        For Primary Endpoint specifically:
        - Search for the exact phrase "Primary Endpoint" or "primary endpoint" in the poster text
        - If found, extract and return the EXACT text that follows it (verbatim quote from the poster)
        - Do NOT infer, paraphrase, summarize, or rewrite the primary endpoint
        - If "Primary Endpoint" is not explicitly mentioned, return "Not applicable"

        If the poster is not a clinical study and patient population is not applicable, briefly state "Not applicable" or provide the most relevant information for that category (e.g., for basic science: sample characteristics).

        Text to summarize:
        \(text)
        """

        generateChatResponse(prompt: summaryPrompt) { result in
            switch result {
            case .success(let response):
                // DEBUG: Log the raw response from OpenAI
                print("📝 ========== RAW OPENAI SUMMARY RESPONSE ==========")
                print(response)
                print("📝 ================================================")

                // Split the response into bullet points
                let allLines = response.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                print("📝 Total non-empty lines: \(allLines.count)")

                // More flexible parsing: accept lines that start with **, numbers, or contain **
                let points = allLines.filter { line in
                    line.starts(with: "**") ||              // **Category**: text
                    line.starts(with: "1.") ||               // 1. text
                    line.starts(with: "2.") ||               // 2. text
                    line.starts(with: "3.") ||               // 3. text
                    line.starts(with: "4.") ||               // 4. text
                    line.starts(with: "5.") ||               // 5. text
                    line.starts(with: "6.") ||               // 6. text
                    line.starts(with: "-") ||                // - text (bullet points)
                    line.contains("**") ||                   // text with ** anywhere
                    line.range(of: "^\\d+\\.", options: .regularExpression) != nil  // Any numbered item
                }

                print("📝 Parsed points count: \(points.count)")
                points.enumerated().forEach { index, point in
                    print("  [\(index + 1)] \(point)")
                }

                if points.isEmpty {
                    // ERROR RECOVERY: If parsing fails, return the whole response as a single point
                    print("⚠️ Failed to parse bullet points, returning full response")
                    completion(.success([response]))
                } else if points.count < 6 {
                    // PARTIAL RECOVERY: Got some points but not all 6, still return them
                    print("⚠️ Expected 6 points but got \(points.count), returning what we have")
                    completion(.success(points))
                } else {
                    print("✅ Successfully parsed \(points.count) summary points")
                    completion(.success(points))
                }

            case .failure(let error):
                print("❌ Failed to generate summary: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
}

/// Service for poster-specific chat interactions using OpenAI
class OpenAIChatService {
    private let openAIService: OpenAIService
    private var contextCache: [UUID: String] = [:] // Cache poster context by ID

    /// Initialize chat service with optional OpenAI service instance
    /// - Parameter openAIService: Optional OpenAI service (creates new instance if not provided)
    init(openAIService: OpenAIService? = nil) {
        self.openAIService = openAIService ?? OpenAIService()
    }

    /// Generate a response for a user's question about a specific poster
    /// - Parameters:
    ///   - posterScan: The poster scan to answer questions about
    ///   - question: The user's question
    ///   - previousMessages: Previous conversation messages for context
    ///   - completion: Completion handler with Result containing the AI response or error
    func generateResponse(for posterScan: PosterScan, to question: String, previousMessages: [ChatMessage] = [], completion: @escaping (Result<String, Error>) -> Void) {
        print("🌟🌟🌟 OpenAIChatService.generateResponse CALLED - REAL API INTEGRATION 🌟🌟🌟")
        print("🌟 Poster ID: \(posterScan.id)")
        print("🌟 Question: \(question)")
        print("🌟 Previous messages count: \(previousMessages.count)")
        
        // First, check if we have a cached context for this poster
        let posterContextPrompt: String
        if let cachedContext = contextCache[posterScan.id] {
            // Use the cached context
            posterContextPrompt = cachedContext
            print("✅ Using cached context for poster")
        } else {
            // Create a new context from the poster data
            posterContextPrompt = createPosterContext(posterScan: posterScan)
            print("🔄 Created new context for poster")
            
            // Cache it for future use
            contextCache[posterScan.id] = posterContextPrompt
        }
        
        // Create conversation history
        let conversationHistory = createConversationContext(messages: previousMessages)
        
        // Create the full prompt
        let prompt = """
        \(posterContextPrompt)
        
        \(conversationHistory)
        
        User Question: \(question)
        
        Provide a concise, informative answer based specifically on the poster's content. If you're unsure or the question goes beyond the poster's scope, acknowledge this and suggest related topics the user might want to explore based on the poster's theme.
        """
        
        // Use OpenAI service to generate a response
        openAIService.generateChatResponse(prompt: prompt) { result in
            completion(result)
        }
    }
    
    // Create context from the poster scan data
    private func createPosterContext(posterScan: PosterScan) -> String {
        // Format the summary points in a readable way
        let formattedSummary = posterScan.summaryPoints.map { "- \($0)" }.joined(separator: "\n")
        
        // Format author questions if available
        let authorQuestions: String
        if let questions = posterScan.authorQuestions, !questions.isEmpty {
            authorQuestions = questions.map { "- \($0)" }.joined(separator: "\n")
        } else {
            authorQuestions = "No specific questions for the author were generated."
        }
        
        // Create a comprehensive context that includes all available poster information
        return """
        ### Scientific Poster Information
        
        **Title:** \(posterScan.title)
        
        **Date:** \(posterScan.dateFormatted)
        
        **Summary Points:**
        \(formattedSummary)
        
        **Suggested Questions for Author:**
        \(authorQuestions)
        
        **Full Poster Text:**
        \(posterScan.rawText)
        
        The above text represents the content of a scientific poster that has been scanned. Use this information to answer questions about the poster.
        """
    }
    
    // Create conversation context from previous messages
    private func createConversationContext(messages: [ChatMessage]) -> String {
        if messages.isEmpty {
            return "This is the beginning of your conversation about this scientific poster."
        }
        
        var conversationHistory = "Previous conversation:\n"
        
        for message in messages {
            let role = message.sender == .user ? "User" : "Assistant"
            conversationHistory += "\(role): \(message.content)\n"
        }
        
        return conversationHistory
    }
    
    // Clear the context cache for a specific poster
    func clearContextCache(for posterId: UUID) {
        contextCache.removeValue(forKey: posterId)
    }
    
    // Clear all context caches
    func clearAllContextCaches() {
        contextCache.removeAll()
    }
}