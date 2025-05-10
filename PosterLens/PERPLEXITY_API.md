# Perplexity API Integration in PosterLens

PosterLens uses the Perplexity Sonar Pro API for three primary functions:

1. Generating structured summaries of scientific posters
2. Providing interactive chat responses about poster content
3. Finding related research papers (via the Related Research feature)

## Poster Summary Generation

PosterLens extracts text from scientific posters using OCR and processes it through the Perplexity API to create structured, easy-to-understand summaries. The API transforms complex scientific language into accessible content organized into key sections:

- Research objectives
- Methodology
- Results
- Conclusions

## Interactive Chat Integration

The app's chat feature leverages the Perplexity API to provide contextual responses to user questions about the poster content. This implementation:

- Maintains conversation context across multiple messages
- Caches poster content for efficient API usage
- Provides suggested questions based on poster content
- Generates responses that reference specific poster details

## Prompt Engineering

Our implementation uses sophisticated prompt engineering to ensure accurate and useful responses:

```swift
let prompt = """
\(posterContextPrompt)

\(conversationHistory)

User Question: \(question)

Provide a concise, informative answer based specifically on the poster's content. If you're unsure or the question goes beyond the poster's scope, acknowledge this and suggest related topics the user might want to explore based on the poster's theme.
"""
```

## Context Management

For the chat feature, we maintain a context cache to optimize API usage:

```swift
// Context caching implementation
private var contextCache: [UUID: String] = [:]

func generateResponse(for posterScan: PosterScan, to question: String, previousMessages: [ChatMessage] = [], completion: @escaping (Result<String, Error>) -> Void) {
    // Check for cached context
    let posterContextPrompt: String
    if let cachedContext = contextCache[posterScan.id] {
        posterContextPrompt = cachedContext
    } else {
        posterContextPrompt = createPosterContext(posterScan: posterScan)
        contextCache[posterScan.id] = posterContextPrompt
    }
    
    // Create conversation history from previous messages
    let conversationHistory = createConversationContext(messages: previousMessages)
    
    // Create the full prompt with context, history, and current question
    let prompt = """
    \(posterContextPrompt)
    
    \(conversationHistory)
    
    User Question: \(question)
    
    Provide a concise, informative answer based specifically on the poster's content. If you're unsure or the question goes beyond the poster's scope, acknowledge this and suggest related topics the user might want to explore based on the poster's theme.
    """
    
    // Make the API call to Perplexity
    // ...
}
```

## API Configuration

The chat feature uses the following configuration for API calls:

```swift
let requestBody: [String: Any] = [
    "model": "sonar-pro", // Using Sonar Pro model for higher quality responses
    "messages": [
        ["role": "system", "content": "You are a helpful scientific assistant that specializes in answering questions about scientific posters. You provide clear, concise, and accurate information based on the poster's content."],
        ["role": "user", "content": prompt]
    ],
    "max_tokens": 1024,
    "temperature": 0.3 // Lower temperature for more focused, accurate responses
]
```

## Error Handling

The application implements comprehensive error handling for API interactions:

```swift
// Error types
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

// Error handling in API response
if let errorInfo = json["error"] as? [String: Any],
   let message = errorInfo["message"] as? String {
    completion(.failure(PerplexityError.apiError(message)))
    return
}
```

## Related Research Integration

The Related Research feature also uses the Perplexity API to find scientific papers related to the poster content, with additional validation through PubMed E-Utilities:

- Uses semantic search via Perplexity to find conceptually related papers
- Validates and enriches citations with PubMed metadata
- Ensures all returned papers have working links and complete citation information

## Live Implementation

The app now implements full API integration:

- Real-time responses from the Perplexity API
- Conversation history maintained across sessions
- Context caching for improved performance
- Error handling with user-friendly error messages
- Loading indicators with haptic feedback

## API Response Processing

The application processes API responses from Perplexity, extracting the relevant content and formatting it for display in both the summary view and chat interface. The implementation handles various edge cases and ensures consistent formatting across the application.