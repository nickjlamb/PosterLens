# Perplexity API Integration in PosterLens

PosterLens uses the Perplexity Sonar Pro API for two primary functions:

1. Generating structured summaries of scientific posters
2. Providing interactive chat responses about poster content

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
You are analyzing a scientific poster with the following extracted text:
\(posterText)

Based on this content, provide a response to the following question:
\(userQuestion)

Reference specific details from the poster in your response.
"""
```

## Context Management

For the chat feature, we maintain a context cache to optimize API usage:

```swift
// Sample context caching implementation
private var contextCache: [UUID: String] = [:]

func generateResponse(for posterScan: PosterScan, to question: String, completion: @escaping (Result<String, Error>) -> Void) {
    // Check for cached context
    let posterContextPrompt: String
    if let cachedContext = contextCache[posterScan.id] {
        posterContextPrompt = cachedContext
    } else {
        posterContextPrompt = createPosterContext(posterScan: posterScan)
        contextCache[posterScan.id] = posterContextPrompt
    }
    
    // Create and send prompt to API
    // ...
}
```

## Simulated Responses for Hackathon

For the Perplexity Hackathon submission, we implemented a simulation layer that generates contextual responses based on the actual poster content without making API calls. This approach:

- Uses pattern matching to identify question intent
- References specific content from the poster
- Simulates typing indicators and response timing
- Creates a realistic chat experience for demonstration purposes

## API Response Handling

The application processes API responses and formats them for display in both the summary view and chat interface.