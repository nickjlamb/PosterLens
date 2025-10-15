# Error Handling Migration Guide

## Overview

This guide explains how to migrate existing services to use the new centralized error handling system in `NetworkErrorHandler.swift`.

## What We've Built

### 1. NetworkError Enum
User-friendly error messages for all network and API errors:
```swift
NetworkError.noInternetConnection // "No internet connection. Please check..."
NetworkError.missingAPIKey(service: "OpenAI") // "OpenAI is not configured..."
NetworkError.rateLimitExceeded // "Too many requests. Please wait..."
```

### 2. NetworkRequestHelper
Automatic retry logic with exponential backoff:
```swift
// Simple usage with defaults (3 retries, exponential backoff)
let (data, response) = try await NetworkRequestHelper.makeRequest(request)

// Custom configuration
let config = NetworkRequestHelper.Configuration(
    maxRetries: 5,
    initialBackoffDelay: 2.0,
    maxBackoffDelay: 30.0,
    timeout: 60.0,
    shouldRetry: { error in
        // Custom retry logic
        return true
    }
)
let (data, response) = try await NetworkRequestHelper.makeRequest(request, config: config)
```

### 3. SafeJSONParser
Crash-safe JSON parsing:
```swift
// Extract nested values without crashes
let content: String? = SafeJSONParser.parse(data, keyPath: "choices.0.message.content")

// Parse to dictionary
let json = SafeJSONParser.parseToDictionary(data)

// Extract error messages
let errorMessage = SafeJSONParser.extractErrorMessage(data)
```

### 4. ErrorPresenter
UI-friendly error presentation:
```swift
let title = ErrorPresenter.title(for: error) // "No Internet Connection"
let suggestion = ErrorPresenter.recoverySuggestion(for: error) // "Check your Wi-Fi..."
```

## Migration Examples

### Example 1: OpenAIService (COMPLETED)

**Before:**
```swift
func generateChatResponse(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
    // Manual error handling
    guard let url = URL(string: baseURL) else {
        completion(.failure(OpenAIError.invalidURL))
        return
    }

    // Manual JSON serialization
    do {
        let requestData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = requestData
    } catch {
        completion(.failure(OpenAIError.requestFailed(error.localizedDescription)))
        return
    }

    // Manual URLSession with no retry
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        // Manual error checking
        if let error = error {
            completion(.failure(OpenAIError.requestFailed(error.localizedDescription)))
            return
        }

        // Manual JSON parsing (can crash!)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let content = json["choices"]?[0]?["message"]?["content"] as? String {
            completion(.success(content))
        }
    }
    task.resume()
}
```

**After:**
```swift
func generateChatResponse(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
    // Validate API key with user-friendly error
    if !hasValidAPIKey {
        completion(.failure(NetworkError.missingAPIKey(service: "OpenAI")))
        return
    }

    guard let url = URL(string: baseURL) else {
        completion(.failure(NetworkError.badRequest("Invalid API URL")))
        return
    }

    // Request setup (unchanged)
    var request = URLRequest(url: url)
    // ... configure request ...

    // Use NetworkRequestHelper with automatic retry
    Task {
        do {
            let (data, _) = try await NetworkRequestHelper.makeRequest(
                request,
                config: .default // 3 retries with exponential backoff
            )

            // Check for API-specific errors
            if let errorMessage = SafeJSONParser.extractErrorMessage(data) {
                completion(.failure(NetworkError.apiError(service: "OpenAI", message: errorMessage)))
                return
            }

            // Safe JSON parsing (no crashes!)
            guard let content: String = SafeJSONParser.parse(data, keyPath: "choices.0.message.content") else {
                completion(.failure(NetworkError.malformedData))
                return
            }

            completion(.success(content))

        } catch let error as NetworkError {
            // NetworkError already has user-friendly messages
            completion(.failure(error))
        } catch {
            // Map unknown errors to NetworkError
            completion(.failure(NetworkError.from(error)))
        }
    }
}
```

### Example 2: PerplexityService (TODO)

**Pattern to apply:**
```swift
func generateSummary(from text: String, completion: @escaping (Result<[String], Error>) -> Void) {
    // 1. Validate API key
    if !hasValidAPIKey {
        completion(.failure(NetworkError.missingAPIKey(service: "Perplexity")))
        return
    }

    // 2. Build request
    guard let url = URL(string: baseURL) else {
        completion(.failure(NetworkError.badRequest("Invalid URL")))
        return
    }

    var request = URLRequest(url: url)
    // ... configure request ...

    // 3. Use NetworkRequestHelper
    Task {
        do {
            let (data, _) = try await NetworkRequestHelper.makeRequest(request)

            // 4. Check for API errors
            if let errorMessage = SafeJSONParser.extractErrorMessage(data) {
                completion(.failure(NetworkError.apiError(service: "Perplexity", message: errorMessage)))
                return
            }

            // 5. Safe JSON parsing
            guard let json = SafeJSONParser.parseToDictionary(data) else {
                completion(.failure(NetworkError.malformedData))
                return
            }

            // 6. Process response with error recovery
            let bulletPoints = processBulletPoints(from: json)
            if bulletPoints.isEmpty {
                // Graceful degradation
                if let rawContent: String = SafeJSONParser.parse(data, keyPath: "choices.0.message.content") {
                    completion(.success([rawContent]))
                } else {
                    completion(.failure(NetworkError.emptyResponse))
                }
            } else {
                completion(.success(bulletPoints))
            }

        } catch let error as NetworkError {
            completion(.failure(error))
        } catch {
            completion(.failure(NetworkError.from(error)))
        }
    }
}
```

### Example 3: ChatService (TODO)

Similar pattern - replace direct URLSession usage with NetworkRequestHelper.

### Example 4: PerplexityRelatedResearchService (TODO)

Async/await pattern already in use, just need to wrap requests with NetworkRequestHelper.

## Key Principles

### 1. Always Validate API Keys First
```swift
if !hasValidAPIKey {
    completion(.failure(NetworkError.missingAPIKey(service: "ServiceName")))
    return
}
```

### 2. Use NetworkRequestHelper for All Network Calls
```swift
// Don't use URLSession.shared directly anymore
❌ URLSession.shared.dataTask(with: request) { ... }

// Use NetworkRequestHelper instead
✅ let (data, _) = try await NetworkRequestHelper.makeRequest(request)
```

### 3. Always Check for API Errors Before Processing
```swift
if let errorMessage = SafeJSONParser.extractErrorMessage(data) {
    completion(.failure(NetworkError.apiError(service: "ServiceName", message: errorMessage)))
    return
}
```

### 4. Use SafeJSONParser for All JSON Operations
```swift
// Don't parse JSON manually
❌ let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

// Use SafeJSONParser
✅ let json = SafeJSONParser.parseToDictionary(data)
✅ let content: String? = SafeJSONParser.parse(data, keyPath: "choices.0.message.content")
```

### 5. Implement Error Recovery
```swift
// Don't fail immediately - try to recover
if points.isEmpty {
    // ERROR RECOVERY: Return full response as fallback
    print("⚠️ Failed to parse bullet points, returning full response")
    completion(.success([rawContent]))
} else {
    completion(.success(points))
}
```

### 6. Always Map Errors to NetworkError
```swift
} catch let error as NetworkError {
    completion(.failure(error))
} catch {
    completion(.failure(NetworkError.from(error)))
}
```

## Testing Error Scenarios

### 1. No Internet Connection
- Turn off Wi-Fi and cellular
- Expected: "No internet connection. Please check your network settings..."

### 2. API Key Missing
- Remove API key from Secrets.plist
- Expected: "OpenAI is not configured. Please add your API key in Settings."

### 3. Rate Limit
- Make rapid requests
- Expected: "Too many requests. Please wait a moment and try again."

### 4. Malformed JSON
- Mock response with invalid JSON
- Expected: "Unable to process the response. Please try again."

### 5. Empty Response
- Mock response with empty data
- Expected: "No data received. Please try again."

## Benefits

✅ **User Experience:**
- Clear, actionable error messages
- No technical jargon
- Consistent error presentation

✅ **Reliability:**
- Automatic retry on transient failures
- Exponential backoff prevents overwhelming servers
- Graceful degradation

✅ **Maintainability:**
- Centralized error handling logic
- Easy to update error messages
- Consistent patterns across all services

✅ **Crash Prevention:**
- Safe JSON parsing
- Proper error propagation
- No force unwrapping or force casting

## Next Steps

1. ✅ OpenAIService - COMPLETED
2. ⏳ PerplexityService - TODO
3. ⏳ ChatService - TODO
4. ⏳ PerplexityRelatedResearchService - TODO
5. ⏳ CitationEnhancer - TODO
6. ⏳ PubMedAPI - Already uses async/await, minimal changes needed

## Questions?

Check the implementation in:
- `PosterLens/Utilities/NetworkErrorHandler.swift` - Core infrastructure
- `PosterLens/Services/OpenAIService.swift` - Reference implementation
