import Foundation

class ChatService {
    private let perplexityService: PerplexityService
    private var contextCache: [UUID: String] = [:] // Cache poster context by ID
    
    init(perplexityService: PerplexityService? = nil) {
        self.perplexityService = perplexityService ?? PerplexityService()
    }
    
    // Generate a response for a user's question about a poster
    func generateResponse(for posterScan: PosterScan, to question: String, previousMessages: [ChatMessage] = [], completion: @escaping (Result<String, Error>) -> Void) {
        // First, check if we have a cached context for this poster
        let posterContextPrompt: String
        if let cachedContext = contextCache[posterScan.id] {
            // Use the cached context
            posterContextPrompt = cachedContext
        } else {
            // Create a new context from the poster data
            posterContextPrompt = createPosterContext(posterScan: posterScan)
            
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
        
        // Set up the request to the Perplexity API
        guard let url = URL(string: "https://api.perplexity.ai/chat/completions") else {
            completion(.failure(PerplexityError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(perplexityService.apiKey)", forHTTPHeaderField: "Authorization")
        
        // Create the request body with the conversation
        let requestBody: [String: Any] = [
            "model": "sonar-pro", // Using Sonar Pro model for higher quality responses
            "messages": [
                ["role": "system", "content": "You are a helpful scientific assistant that specializes in answering questions about scientific posters. You provide clear, concise, and accurate information based on the poster's content."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1024,
            "temperature": 0.3 // Lower temperature for more focused, accurate responses
        ]
        
        // Debug logging - check API key
        print("🚀 Using API key: \(perplexityService.apiKey.prefix(8))...") // Only log prefix for security
        
        // Serialize the request body
        do {
            let requestData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = requestData
            
            // Debug logging - print request without sensitive data
            print("📤 API Request sent to Perplexity - model: sonar-pro, max_tokens: 1024")
        } catch {
            let errorMessage = "Failed to serialize request: \(error.localizedDescription)"
            print("❌ Serialization error: \(errorMessage)")
            completion(.failure(PerplexityError.requestFailed(errorMessage)))
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
                completion(.failure(PerplexityError.requestFailed(errorMessage)))
                return
            }
            
            guard let data = data else {
                print("❌ No data received from API")
                completion(.failure(PerplexityError.invalidResponse))
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
                        completion(.failure(PerplexityError.apiError(message)))
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
                            completion(.failure(PerplexityError.apiError("The API returned an empty response")))
                        } else {
                            completion(.success(cleanContent))
                        }
                    } else {
                        completion(.failure(PerplexityError.invalidResponse))
                    }
                } else {
                    completion(.failure(PerplexityError.invalidResponse))
                }
            } catch {
                let errorMessage = "JSON parsing error: \(error.localizedDescription)"
                completion(.failure(PerplexityError.requestFailed(errorMessage)))
            }
        }
        
        task.resume()
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