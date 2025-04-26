import Foundation

// Make PerplexityError conform to LocalizedError for better error messages
enum PerplexityError: Error, LocalizedError {
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
            return "Perplexity API key is missing"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

class PerplexityService {
    // Hardcoded API key provided by the user
    private let defaultAPIKey = "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"
    private var apiKey: String
    private let baseURL = "https://api.perplexity.ai/chat/completions"
    
    // Initialize with API key from environment or configuration
    init(apiKey: String? = nil) {
        // Always use the default API key first
        self.apiKey = defaultAPIKey
        
        // If a specific key is provided, use that instead
        if let providedKey = apiKey, !providedKey.isEmpty {
            self.apiKey = providedKey
        }
    }
    
    // Check if API key is valid
    var hasValidAPIKey: Bool {
        return !apiKey.isEmpty && apiKey != "YOUR_API_KEY_HERE"
    }
    
    // Set API key (for internal use only, not exposed to users)
    func setAPIKey(_ key: String) {
        apiKey = key
        UserDefaults.standard.set(key, forKey: "PerplexityAPIKey")
    }
    
    // Main method to generate summary from scientific poster text
    func generateSummary(from text: String, completion: @escaping (Result<[String], Error>) -> Void) {
        // Validate API key
        if !hasValidAPIKey {
            completion(.failure(PerplexityError.missingAPIKey))
            return
        }
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(PerplexityError.invalidURL))
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Prepare the prompt with scientific context
        let prompt = createScientificPosterPrompt(text: text)
        
        // Create the request body
        let requestBody: [String: Any] = [
            "model": "sonar-pro", // Using Sonar Pro model for higher quality responses
            "messages": [
                ["role": "system", "content": "You are a scientific assistant that specializes in summarizing scientific posters into clear, concise bullet points. Focus on extracting key findings, methodology, and conclusions."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1024,
            "temperature": 0.2 // Lower temperature for more focused, factual responses
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            let errorMessage = "Failed to serialize request: \(error.localizedDescription)"
            completion(.failure(PerplexityError.requestFailed(errorMessage)))
            return
        }
        
        // Create and start the data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                let errorMessage = "Network error: \(error.localizedDescription)"
                completion(.failure(PerplexityError.requestFailed(errorMessage)))
                return
            }
            
            guard let data = data else {
                completion(.failure(PerplexityError.invalidResponse))
                return
            }
            
            // For debugging, print the raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("API Response: \(responseString)")
            }
            
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
                        
                        // Process the content into bullet points
                        let bulletPoints = self.processBulletPoints(from: content)
                        
                        // Ensure we have at least one bullet point
                        if bulletPoints.isEmpty {
                            completion(.failure(PerplexityError.apiError("No valid bullet points found in response")))
                        } else {
                            completion(.success(bulletPoints))
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
    
    // Method to generate questions to ask the poster author
    func generateAuthorQuestions(from summary: [String], rawText: String, completion: @escaping (Result<[String], Error>) -> Void) {
        // Validate API key
        if !hasValidAPIKey {
            completion(.failure(PerplexityError.missingAPIKey))
            return
        }
        
        guard let url = URL(string: baseURL) else {
            completion(.failure(PerplexityError.invalidURL))
            return
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Prepare the prompt for generating questions
        let prompt = createAuthorQuestionsPrompt(summary: summary, rawText: rawText)
        
        // Create the request body
        let requestBody: [String: Any] = [
            "model": "sonar-pro", // Using Sonar Pro model for higher quality responses
            "messages": [
                ["role": "system", "content": "You are a scientific assistant that specializes in generating insightful questions about scientific research. Your questions should help researchers think critically about their work and consider future implications."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1024,
            "temperature": 0.7 // Slightly higher temperature for more creative questions
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            let errorMessage = "Failed to serialize request: \(error.localizedDescription)"
            completion(.failure(PerplexityError.requestFailed(errorMessage)))
            return
        }
        
        // Create and start the data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                let errorMessage = "Network error: \(error.localizedDescription)"
                completion(.failure(PerplexityError.requestFailed(errorMessage)))
                return
            }
            
            guard let data = data else {
                completion(.failure(PerplexityError.invalidResponse))
                return
            }
            
            // For debugging, print the raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("API Response: \(responseString)")
            }
            
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
                        
                        // Process the content into questions
                        let questions = self.processQuestions(from: content)
                        
                        // Ensure we have at least one question
                        if questions.isEmpty {
                            completion(.failure(PerplexityError.apiError("No valid questions found in response")))
                        } else {
                            completion(.success(questions))
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
    
    // Create a specialized prompt for scientific poster summarization
    private func createScientificPosterPrompt(text: String) -> String {
        return """
        I have scanned a scientific poster with the following text. Please create a concise bullet-point summary of the key scientific information, focusing on:
        
        1. The main research question or objective
        2. The methodology used
        3. The key results and findings
        4. The main conclusions and implications
        5. Any novel techniques or innovations mentioned
        
        Here is the text from the scientific poster:
        
        \(text)
        
        Format your response as a list of bullet points only, with no introduction or conclusion. Each bullet point should be a complete, self-contained piece of information. Limit to 5-7 key points total.
        """
    }
    
    // Create a specialized prompt for generating questions to ask the poster author
    private func createAuthorQuestionsPrompt(summary: [String], rawText: String) -> String {
        let summaryText = summary.map { "• \($0)" }.joined(separator: "\n")
        
        return """
        I have scanned a scientific poster and generated the following summary:
        
        \(summaryText)
        
        Here is the full text from the poster:
        
        \(rawText)
        
        Based on this research, please generate 5 insightful questions that I could ask the poster author. The questions should:
        
        1. Address potential limitations or gaps in the study
        2. Explore future research directions or implications
        3. Inquire about methodological choices or alternative approaches
        4. Discuss connections to related research or broader scientific context
        5. Probe deeper into the most interesting or novel aspects of the findings
        
        Format your response as a numbered list of 5 questions only, with no introduction or conclusion. Each question should be thoughtful, specific to this research, and demonstrate understanding of the scientific content.
        """
    }
    
    // Process the API response into clean bullet points
    private func processBulletPoints(from content: String) -> [String] {
        // Split the content by lines
        let lines = content.components(separatedBy: .newlines)
        
        // Filter for bullet point lines and clean them up
        var bulletPoints = lines.compactMap { (line: String) -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if trimmed.isEmpty {
                return nil
            }
            
            // Check if line starts with a bullet point or dash
            if trimmed.hasPrefix("•") || trimmed.hasPrefix("-") || trimmed.hasPrefix("*") {
                // Remove the bullet character and trim again
                let bulletRemoved = trimmed.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
                return bulletRemoved.isEmpty ? nil : bulletRemoved
            } else if trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                // Handle numbered lists (e.g., "1. Item")
                if let dotRange = trimmed.range(of: ". ") {
                    let bulletRemoved = trimmed[dotRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                    return bulletRemoved.isEmpty ? nil : String(bulletRemoved)
                }
            }
            
            // If it's not a bullet point but not empty, include it anyway
            // This helps capture points that might not be properly formatted
            return trimmed
        }
        
        // If no bullet points were found, try to create them from paragraphs
        if bulletPoints.isEmpty {
            bulletPoints = lines.filter { (line: String) -> Bool in
                !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
        
        // Limit to a reasonable number of bullet points
        if bulletPoints.count > 10 {
            bulletPoints = Array(bulletPoints.prefix(10))
        }
        
        return bulletPoints
    }
    
    // Process the API response into clean questions
    private func processQuestions(from content: String) -> [String] {
        // Split the content by lines
        let lines = content.components(separatedBy: .newlines)
        
        // Filter for question lines and clean them up
        var questions = lines.compactMap { (line: String) -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if trimmed.isEmpty {
                return nil
            }
            
            // Check if line starts with a number (e.g., "1. Question")
            if trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) != nil {
                if let dotRange = trimmed.range(of: ". ") {
                    let questionText = trimmed[dotRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                    return questionText.isEmpty ? nil : String(questionText)
                }
            }
            
            // If it contains a question mark, it's probably a question
            if trimmed.contains("?") {
                return trimmed
            }
            
            return nil
        }
        
        // If no questions were found, try to extract sentences ending with question marks
        if questions.isEmpty {
            let fullText = content.trimmingCharacters(in: .whitespacesAndNewlines)
            let questionPattern = #"[^.!?]+\?"#
            
            if let regex = try? NSRegularExpression(pattern: questionPattern) {
                let range = NSRange(fullText.startIndex..., in: fullText)
                let matches = regex.matches(in: fullText, range: range)
                
                questions = matches.compactMap { (match: NSTextCheckingResult) -> String? in
                    if let range = Range(match.range, in: fullText) {
                        return String(fullText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    return nil
                }
            }
        }
        
        // Limit to exactly 5 questions if possible
        if questions.count > 5 {
            questions = Array(questions.prefix(5))
        } else if questions.count < 5 {
            // If we have fewer than 5 questions, add generic ones to reach 5
            let genericQuestions = [
                "What future research directions do you envision based on these findings?",
                "What were the main limitations of your study, and how might they be addressed in future work?",
                "How do your findings compare to previous research in this area?",
                "What practical applications do you see for your research findings?",
                "Were there any unexpected results during your research that might lead to new hypotheses?"
            ]
            
            let neededCount = 5 - questions.count
            questions.append(contentsOf: genericQuestions.prefix(neededCount))
        }
        
        return questions
    }
}
