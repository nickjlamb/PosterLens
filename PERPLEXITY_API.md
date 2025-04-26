# Perplexity API Integration Documentation

This document provides detailed information about how PosterLens integrates with the Perplexity API to enhance scientific poster understanding.

## Overview

PosterLens uses the Perplexity Sonar Pro API to transform raw text extracted from scientific posters into structured, easy-to-understand summaries and generate insightful questions for poster authors. This integration enables users to quickly grasp complex scientific content and engage more meaningfully with researchers.

## API Implementation

The integration is implemented in the `PerplexityService.swift` file, which handles all communication with the Perplexity API.

### Key Components

1. **API Configuration**
   - API Key management
   - Endpoint configuration
   - Request headers setup

2. **Request Construction**
   - Prompt engineering for optimal results
   - Context formatting from extracted poster text
   - Model selection (using Sonar Pro model)

3. **Response Handling**
   - JSON parsing
   - Error handling
   - Response transformation into app-friendly formats

## Prompt Engineering

PosterLens uses carefully crafted prompts to generate high-quality summaries and questions:

### For Summaries

The summary generation prompt instructs the model to:
- Extract the main research question/objective
- Identify the methodology used
- Highlight key results and findings
- Summarize main conclusions and implications
- Note any novel techniques or innovations

### For Questions

The question generation prompt creates questions that:
- Address potential limitations of the research
- Explore future research directions
- Inquire about practical applications
- Ask about methodological choices
- Probe deeper into the results and their implications

## Example API Call

```swift
func generateSummary(from text: String, completion: @escaping (Result<[String], Error>) -> Void) {
    let prompt = """
    Analyze this scientific poster text and create a structured summary with these sections:
    1. Main Research Question/Objective
    2. Methodology Used
    3. Key Results and Findings
    4. Main Conclusions and Implications
    5. Novel Techniques or Innovations (if any)

    Format each section as "**Section Title**: Content"
    Keep the total summary concise but comprehensive.

    Poster Text:
    \(text)
    """
    
    // API request configuration
    let parameters: [String: Any] = [
        "model": "sonar-pro",
        "messages": [
            ["role": "system", "content": "You are a scientific assistant that specializes in summarizing scientific posters into clear, concise bullet points. Focus on extracting key findings, methodology, and conclusions."],
            ["role": "user", "content": prompt]
        ],
        "temperature": 0.2,
        "max_tokens": 1024
    ]
    
    // Make API request
    makeAPIRequest(with: parameters) { result in
        // Process result and extract summary points
        // ...
    }
}
