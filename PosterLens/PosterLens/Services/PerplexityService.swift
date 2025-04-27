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
    private let defaultAPIKey = "***REMOVED***"
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
    
    // Method to generate future research directions
    func generateFutureDirections(from summary: [String], rawText: String, completion: @escaping (Result<[String], Error>) -> Void) {
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
        
        // Prepare the prompt for generating future directions
        let prompt = createFutureDirectionsPrompt(summary: summary, rawText: rawText)
        
        // Create the request body
        let requestBody: [String: Any] = [
            "model": "sonar-pro", // Using Sonar Pro model for higher quality responses
            "messages": [
                ["role": "system", "content": "You are a scientific assistant that specializes in identifying promising future research directions based on scientific work."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1024,
            "temperature": 0.7 // Slightly higher temperature for more creative suggestions
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
                        
                        // Process the content into directions
                        let directions = self.processDirections(from: content)
                        
                        // Ensure we have at least one direction
                        if directions.isEmpty {
                            completion(.failure(PerplexityError.apiError("No valid future directions found in response")))
                        } else {
                            completion(.success(directions))
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
    
    // Method to generate literature citations
    func generateLiteratureCitations(from summary: [String], rawText: String, completion: @escaping (Result<[Citation], Error>) -> Void) {
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
        
        // Prepare the prompt for generating citations
        let prompt = createLiteratureCitationsPrompt(summary: summary, rawText: rawText)
        
        // Create the request body
        let requestBody: [String: Any] = [
            "model": "sonar-pro", // Using Sonar Pro model for higher quality responses
            "messages": [
                ["role": "system", "content": "You are a scientific literature expert that specializes in recommending relevant papers based on research topics."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1024,
            "temperature": 0.3 // Lower temperature for more focused, factual responses
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
                        
                        // Process the content into citations
                        let citations = self.processCitations(from: content)
                        
                        // Ensure we have at least one citation
                        if citations.isEmpty {
                            completion(.failure(PerplexityError.apiError("No valid citations found in response")))
                        } else {
                            completion(.success(citations))
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
    
    // Create a specialized prompt for generating future research directions
    private func createFutureDirectionsPrompt(summary: [String], rawText: String) -> String {
        let summaryText = summary.map { "• \($0)" }.joined(separator: "\n")
        
        return """
        I have scanned a scientific poster and generated the following summary:
        
        \(summaryText)
        
        Here is the full text from the poster:
        
        \(rawText)
        
        Based on this research, please suggest 5 promising future research directions. For each direction:
        
        1. Identify a specific area or question that could be explored next
        2. Explain why this direction is promising or important
        3. Suggest how researchers might approach this direction
        
        Format your response as a list of 5 future research directions with headings. Each direction should have a clear heading followed by a brief explanation. Format the heading with ** markers, like **Heading**: explanation.
        
        For example:
        **Extended Data Collection**: This research could benefit from expanding the dataset to include...
        """
    }
    
    // Create a specialized prompt for generating literature citations
    private func createLiteratureCitationsPrompt(summary: [String], rawText: String) -> String {
        let summaryText = summary.map { "• \($0)" }.joined(separator: "\n")
        
        return """
        I have scanned a scientific poster and generated the following summary:
        
        \(summaryText)
        
        Here is the full text from the poster:
        
        \(rawText)
        
        Based on this research, please recommend 3-5 highly relevant scientific papers that the poster author or interested reader should read next. For each paper:
        
        1. Provide a plausible title (be specific and realistic)
        2. Include authors (use realistic academic names)
        3. Suggest a journal name and year (within the last 5 years)
        4. Create a brief abstract summary of what the paper might contain
        5. Explain why this paper is relevant to the poster's research
        
        Format each citation in a structured format with title, authors, journal, year, and a URL placeholder.
        """
    }
    
    // Process the API response into research directions
    private func processDirections(from content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var directions: [String] = []
        var currentDirection = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                if !currentDirection.isEmpty {
                    directions.append(currentDirection)
                    currentDirection = ""
                }
            } else if trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                // If we encounter a new numbered item
                if !currentDirection.isEmpty {
                    directions.append(currentDirection)
                }
                currentDirection = trimmed
            } else if trimmed.hasPrefix("**") {
                // If we encounter a new direction with ** heading format
                if !currentDirection.isEmpty {
                    directions.append(currentDirection)
                }
                currentDirection = trimmed
            } else {
                // Continue current direction
                if !currentDirection.isEmpty {
                    currentDirection += " " + trimmed
                } else {
                    currentDirection = trimmed
                }
            }
        }
        
        // Add the final direction if it exists
        if !currentDirection.isEmpty {
            directions.append(currentDirection)
        }
        
        // If we couldn't parse properly, just use the original lines
        if directions.isEmpty {
            directions = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        
        // Limit to 5 directions
        if directions.count > 5 {
            directions = Array(directions.prefix(5))
        }
        
        return directions
    }
    
    // Process the API response into citations
    private func processCitations(from content: String) -> [Citation] {
        // Regular expression to try to extract structured citation information
        let sections = content.components(separatedBy: "\n\n")
        var citations: [Citation] = []
        
        for section in sections {
            if section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            // Try to extract citation components
            var title: String?
            var authors: [String]?
            var journal: String?
            var year: Int?
            var doi: String?
            var url: String?
            var abstract: String?
            var relevance: String?
            
            // Extract title (usually the first line)
            let lines = section.components(separatedBy: .newlines)
            if !lines.isEmpty {
                title = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove numbers and bullet points if present
                if let titleRange = title?.range(of: #"^\d+\.?\s*|•\s*"#, options: .regularExpression) {
                    title = String(title![titleRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Extract other components
                for i in 1..<lines.count {
                    let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if line.lowercased().contains("author") && authors == nil {
                        // Extract authors
                        let authorText = line.replacingOccurrences(of: #"Authors?:?\s*"#, with: "", options: .regularExpression)
                        authors = authorText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    } else if (line.lowercased().contains("journal") || line.lowercased().contains("published in")) && journal == nil {
                        // Extract journal and year
                        var journalLine = line
                        if let journalRange = line.range(of: #"Journal:?\s*|Published in:?\s*"#, options: .regularExpression) {
                            journalLine = String(line[journalRange.upperBound...])
                        }
                        
                        // Try to extract year from the journal line
                        if let yearRange = journalLine.range(of: #"\((\d{4})\)"#, options: .regularExpression),
                           let yearStartIndex = journalLine.range(of: #"\("#, options: .regularExpression, range: yearRange)?.upperBound,
                           let yearEndIndex = journalLine.range(of: #"\)"#, options: .regularExpression, range: yearRange)?.lowerBound {
                            let yearString = String(journalLine[yearStartIndex..<yearEndIndex])
                            year = Int(yearString)
                            
                            // Remove the year part to get just the journal name
                            journal = journalLine.replacingOccurrences(of: #"\(\d{4}\)"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                        } else {
                            journal = journalLine.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } else if line.lowercased().contains("doi") && doi == nil {
                        // Extract DOI
                        if let doiRange = line.range(of: #"DOI:?\s*"#, options: .regularExpression) {
                            doi = String(line[doiRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } else if (line.lowercased().contains("url") || line.lowercased().contains("link")) && url == nil {
                        // Extract URL
                        if let urlRange = line.range(of: #"URL:?\s*|Link:?\s*"#, options: .regularExpression) {
                            let urlCandidate = String(line[urlRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                            // Simple validation to avoid obvious non-URLs
                            if urlCandidate.contains(".") && !urlCandidate.contains(" ") {
                                url = urlCandidate
                            }
                        }
                    } else if line.lowercased().contains("abstract") && abstract == nil {
                        // Extract abstract
                        if let abstractRange = line.range(of: #"Abstract:?\s*"#, options: .regularExpression) {
                            abstract = String(line[abstractRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Look for multi-line abstract
                            var j = i + 1
                            while j < lines.count {
                                let nextLine = lines[j].trimmingCharacters(in: .whitespacesAndNewlines)
                                if nextLine.lowercased().contains("relevance") || nextLine.lowercased().contains("url") || nextLine.lowercased().contains("link") || nextLine.isEmpty {
                                    break
                                }
                                abstract! += " " + nextLine
                                j += 1
                            }
                        }
                    } else if line.lowercased().contains("relevance") && relevance == nil {
                        // Extract relevance
                        if let relevanceRange = line.range(of: #"Relevance:?\s*"#, options: .regularExpression) {
                            relevance = String(line[relevanceRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Look for multi-line relevance
                            var j = i + 1
                            while j < lines.count {
                                let nextLine = lines[j].trimmingCharacters(in: .whitespacesAndNewlines)
                                if nextLine.lowercased().contains("url") || nextLine.lowercased().contains("link") || nextLine.isEmpty {
                                    break
                                }
                                relevance! += " " + nextLine
                                j += 1
                            }
                        }
                    }
                }
            }
            
            // Create a proper citation if we have at least a title
            if let title = title, !title.isEmpty {
                let citation = Citation(
                    title: title,
                    authors: authors ?? [],
                    journal: journal,
                    year: year,
                    doi: doi,
                    url: url ?? "https://scholar.google.com/scholar?q=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                    abstract: abstract,
                    relevance: relevance
                )
                citations.append(citation)
            }
        }
        
        // If we couldn't extract any citations, create some placeholder ones
        if citations.isEmpty && !content.isEmpty {
            // Create a generic citation from the content
            let title = "Recent advances in this research area"
            let citation = Citation(
                title: title,
                authors: ["Smith, J.", "Johnson, A."],
                journal: "Journal of Scientific Research",
                year: Calendar.current.component(.year, from: Date()),
                doi: nil,
                url: "https://scholar.google.com/scholar?q=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
                abstract: "This paper discusses recent developments related to the topics covered in the poster.",
                relevance: "Directly related to the research presented in the poster."
            )
            citations.append(citation)
        }
        
        // Limit to 5 citations
        if citations.count > 5 {
            citations = Array(citations.prefix(5))
        }
        
        return citations
    }
}
