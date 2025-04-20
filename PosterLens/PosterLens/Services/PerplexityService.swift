import Foundation

enum PerplexityError: Error {
    case invalidURL
    case requestFailed
    case invalidResponse
    case apiError(String)
    case missingAPIKey
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .requestFailed:
            return "API request failed"
        case .invalidResponse:
            return "Invalid response from API"
        case .apiError(let message):
            return "API error: \(message)"
        case .missingAPIKey:
            return "Perplexity API key is missing"
        }
    }
}

class PerplexityService {
    private let apiKey: String
    private let baseURL = "https://api.perplexity.ai/chat/completions"
    
    // Initialize with API key from environment or configuration
    init(apiKey: String? = nil) {
        // Use provided key, or check environment, or use a default placeholder
        if let providedKey = apiKey, !providedKey.isEmpty {
            self.apiKey = providedKey
        } else if let envKey = ProcessInfo.processInfo.environment["PERPLEXITY_API_KEY"], !envKey.isEmpty {
            self.apiKey = envKey
        } else if let storedKey = UserDefaults.standard.string(forKey: "PerplexityAPIKey"), !storedKey.isEmpty {
            self.apiKey = storedKey
        } else {
            // In a real app, we would handle this more gracefully
            self.apiKey = "YOUR_API_KEY_HERE" // Placeholder that will trigger an error
        }
        
        // Print debug info
        print("DEBUG: PerplexityService initialized with API key length: \(self.apiKey.count)")
    }
    
    // Set API key (for use when user provides it later)
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "PerplexityAPIKey")
    }
    
    // Main method to generate summary from scientific poster text
    func generateSummary(from text: String, completion: @escaping (Result<[String], Error>) -> Void) {
        // Validate API key
        if apiKey == "YOUR_API_KEY_HERE" {
            print("DEBUG: API key validation failed - using placeholder key")
            completion(.failure(PerplexityError.missingAPIKey))
            return
        }
        
        // Ensure the URL is properly formatted
        let urlString = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        print("DEBUG: Using API URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("DEBUG: Failed to create URL from string: \(urlString)")
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
        
        // Create the request body with the correct model name
        let requestBody: [String: Any] = [
            "model": "sonar", // Using the correct Perplexity AI model
            "messages": [
                ["role": "system", "content": "You are a scientific assistant that specializes in summarizing scientific posters into clear, concise bullet points. Focus on extracting key findings, methodology, and conclusions."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1024,
            "temperature": 0.2 // Lower temperature for more focused, factual responses
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("DEBUG: Request body created successfully")
        } catch {
            print("DEBUG: Failed to create request body: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        print("DEBUG: Starting API request to Perplexity")
        
        // Create and start the data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("DEBUG: API request failed with error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG: API response status code: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("DEBUG: No data received from API")
                completion(.failure(PerplexityError.invalidResponse))
                return
            }
            
            print("DEBUG: Received \(data.count) bytes from API")
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Print the response for debugging
                    print("DEBUG: API response keys: \(json.keys.joined(separator: ", "))")
                    
                    // Check for API errors first
                    if let errorInfo = json["error"] as? [String: Any],
                       let message = errorInfo["message"] as? String {
                        print("DEBUG: API returned error: \(message)")
                        completion(.failure(PerplexityError.apiError(message)))
                        return
                    }
                    
                    // Process successful response
                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        
                        print("DEBUG: Successfully extracted content from API response")
                        
                        // Process the content into bullet points
                        let bulletPoints = self.processBulletPoints(from: content)
                        print("DEBUG: Processed \(bulletPoints.count) bullet points")
                        completion(.success(bulletPoints))
                    } else {
                        print("DEBUG: Failed to extract content from API response")
                        completion(.failure(PerplexityError.invalidResponse))
                    }
                } else {
                    print("DEBUG: Failed to parse API response as JSON")
                    completion(.failure(PerplexityError.invalidResponse))
                }
            } catch {
                print("DEBUG: JSON parsing error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
        print("DEBUG: API request task started")
    }
    
    // Method to generate questions to ask the poster author
    func generateAuthorQuestions(from summary: [String], rawText: String, completion: @escaping (Result<[String], Error>) -> Void) {
        // Validate API key
        if apiKey == "YOUR_API_KEY_HERE" {
            print("DEBUG: API key validation failed - using placeholder key")
            completion(.failure(PerplexityError.missingAPIKey))
            return
        }
        
        // Ensure the URL is properly formatted
        let urlString = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        print("DEBUG: Using API URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("DEBUG: Failed to create URL from string: \(urlString)")
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
        
        // Create the request body with the correct model name
        let requestBody: [String: Any] = [
            "model": "sonar", // Using the correct Perplexity AI model
            "messages": [
                ["role": "system", "content": "You are a scientific assistant that specializes in generating insightful questions about scientific research. Your questions should help researchers think critically about their work and consider future implications."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1024,
            "temperature": 0.7 // Slightly higher temperature for more creative questions
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("DEBUG: Request body created successfully")
        } catch {
            print("DEBUG: Failed to create request body: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }
        
        print("DEBUG: Starting API request to Perplexity for questions")
        
        // Create and start the data task
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("DEBUG: API request failed with error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("DEBUG: API response status code: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("DEBUG: No data received from API")
                completion(.failure(PerplexityError.invalidResponse))
                return
            }
            
            print("DEBUG: Received \(data.count) bytes from API")
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Print the response for debugging
                    print("DEBUG: API response keys: \(json.keys.joined(separator: ", "))")
                    
                    // Check for API errors first
                    if let errorInfo = json["error"] as? [String: Any],
                       let message = errorInfo["message"] as? String {
                        print("DEBUG: API returned error: \(message)")
                        completion(.failure(PerplexityError.apiError(message)))
                        return
                    }
                    
                    // Process successful response
                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        
                        print("DEBUG: Successfully extracted content from API response")
                        
                        // Process the content into questions
                        let questions = self.processQuestions(from: content)
                        print("DEBUG: Processed \(questions.count) questions")
                        completion(.success(questions))
                    } else {
                        print("DEBUG: Failed to extract content from API response")
                        completion(.failure(PerplexityError.invalidResponse))
                    }
                } else {
                    print("DEBUG: Failed to parse API response as JSON")
                    completion(.failure(PerplexityError.invalidResponse))
                }
            } catch {
                print("DEBUG: JSON parsing error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
        
        task.resume()
        print("DEBUG: API request task started for questions")
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
    
    // Method to check if API key is valid
    func validateAPIKey(completion: @escaping (Bool) -> Void) {
        // Simple validation request to check if the API key works
        let testPrompt = "Test API key validation"
        
        generateSummary(from: testPrompt) { result in
            switch result {
            case .success(_):
                completion(true)
            case .failure(let error):
                if case PerplexityError.apiError(let message) = error,
                   message.contains("authentication") || message.contains("invalid") || message.contains("key") {
                    completion(false)
                } else if case PerplexityError.missingAPIKey = error {
                    completion(false)
                } else {
                    // Other errors might not be related to the API key
                    completion(true)
                }
            }
        }
    }
}
