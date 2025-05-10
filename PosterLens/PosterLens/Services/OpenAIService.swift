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
    // Developer-provided API key - replace with your actual OpenAI key
    private let defaultAPIKey = "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"  // Replace with your actual OpenAI API key
    var apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    // Initialize with the developer-provided API key
    init(apiKey: String? = nil) {
        // Use the default API key that the developer provides
        self.apiKey = defaultAPIKey
        
        // Optional override for testing or if key needs to be changed
        if let providedKey = apiKey, !providedKey.isEmpty {
            self.apiKey = providedKey
        }
        
        print("🔑 OpenAIService initialized with API key: \(self.apiKey.prefix(8))...")
    }
    
    // Check if API key is valid
    var hasValidAPIKey: Bool {
        return !apiKey.isEmpty && apiKey.hasPrefix("sk-")
    }
    
    // Set API key (for testing or if key needs to be rotated)
    func setAPIKey(_ key: String) {
        apiKey = key
    }
    
    // Generate a chat response based on a prompt
    func generateChatResponse(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Validate API key
        if !hasValidAPIKey {
            completion(.failure(OpenAIError.missingAPIKey))
            return
        }
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(OpenAIError.invalidURL))
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
            let errorMessage = "Failed to serialize request: \(error.localizedDescription)"
            print("❌ Serialization error: \(errorMessage)")
            completion(.failure(OpenAIError.requestFailed(errorMessage)))
            return
        }
        
        // Create and start the data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Debug HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("📥 API Response status: \(httpResponse.statusCode)")
            }
            
            if let error = error {
                let errorMessage = "Network error: \(error.localizedDescription)"
                print("❌ Network error: \(errorMessage)")
                completion(.failure(OpenAIError.requestFailed(errorMessage)))
                return
            }
            
            guard let data = data else {
                print("❌ No data received from API")
                completion(.failure(OpenAIError.invalidResponse))
                return
            }
            
            // Debug that data was received (without exposing full content)
            print("📥 API Response received (\(data.count) bytes)")
            
            // Process the response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check for API errors first
                    if let errorInfo = json["error"] as? [String: Any],
                       let message = errorInfo["message"] as? String {
                        completion(.failure(OpenAIError.apiError(message)))
                        return
                    }
                    
                    // Process successful response
                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        
                        // Ensure the content is cleaned up and ready for display
                        let cleanContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if cleanContent.isEmpty {
                            completion(.failure(OpenAIError.apiError("The API returned an empty response")))
                        } else {
                            completion(.success(cleanContent))
                        }
                    } else {
                        completion(.failure(OpenAIError.invalidResponse))
                    }
                } else {
                    completion(.failure(OpenAIError.invalidResponse))
                }
            } catch {
                let errorMessage = "JSON parsing error: \(error.localizedDescription)"
                completion(.failure(OpenAIError.requestFailed(errorMessage)))
            }
        }
        
        task.resume()
    }
}

class OpenAIChatService {
    private let openAIService: OpenAIService
    private var contextCache: [UUID: String] = [:] // Cache poster context by ID
    
    init(openAIService: OpenAIService? = nil) {
        self.openAIService = openAIService ?? OpenAIService()
    }
    
    // Generate a response for a user's question about a poster
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