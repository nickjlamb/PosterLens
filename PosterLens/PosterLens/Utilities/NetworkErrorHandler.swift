import Foundation

// MARK: - User-Friendly Network Errors

/// Centralized network error handling with user-friendly messages
enum NetworkError: LocalizedError {
    // Connection errors
    case noInternetConnection
    case connectionTimeout
    case serverUnreachable

    // API errors
    case invalidAPIKey
    case rateLimitExceeded
    case serverError(Int)
    case badRequest(String)

    // Data errors
    case invalidResponse
    case emptyResponse
    case malformedData

    // Service-specific errors
    case missingAPIKey(service: String)
    case apiError(service: String, message: String)

    // Unknown
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        // Connection errors - user-friendly
        case .noInternetConnection:
            return "No internet connection. Please check your network settings and try again."
        case .connectionTimeout:
            return "The request took too long. Please check your connection and try again."
        case .serverUnreachable:
            return "Unable to reach the server. Please try again later."

        // API errors - user-friendly
        case .invalidAPIKey:
            return "API authentication failed. Please check your API key configuration."
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .badRequest(let message):
            return "Request error: \(message). Please try again."

        // Data errors - user-friendly
        case .invalidResponse:
            return "Received an unexpected response. Please try again."
        case .emptyResponse:
            return "No data received. Please try again."
        case .malformedData:
            return "Unable to process the response. Please try again."

        // Service-specific - user-friendly
        case .missingAPIKey(let service):
            return "\(service) is not configured. Please add your API key in Settings."
        case .apiError(let service, let message):
            return "\(service) error: \(message)"

        // Unknown - fallback
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }

    /// Map system errors to user-friendly NetworkError
    static func from(_ error: Error) -> NetworkError {
        let nsError = error as NSError

        // Check for common URLError codes
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return .noInternetConnection
            case NSURLErrorTimedOut:
                return .connectionTimeout
            case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                return .serverUnreachable
            default:
                return .unknown(error)
            }
        }

        return .unknown(error)
    }

    /// Map HTTP status codes to NetworkError
    static func from(statusCode: Int, data: Data? = nil) -> NetworkError {
        switch statusCode {
        case 200...299:
            // Success - not an error
            return .invalidResponse
        case 400:
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                return .badRequest(message)
            }
            return .badRequest("Invalid request")
        case 401, 403:
            return .invalidAPIKey
        case 429:
            return .rateLimitExceeded
        case 500...599:
            return .serverError(statusCode)
        default:
            return .badRequest("HTTP \(statusCode)")
        }
    }
}

// MARK: - Network Request Helper with Retry Logic

/// Helper class for making resilient network requests with automatic retry and timeout handling
class NetworkRequestHelper {

    /// Configuration for network requests
    struct Configuration {
        let maxRetries: Int
        let initialBackoffDelay: TimeInterval
        let maxBackoffDelay: TimeInterval
        let timeout: TimeInterval
        let shouldRetry: (NetworkError) -> Bool

        static let `default` = Configuration(
            maxRetries: 3,
            initialBackoffDelay: 1.0,
            maxBackoffDelay: 10.0,
            timeout: 30.0,
            shouldRetry: { error in
                // Retry on transient errors only
                switch error {
                case .connectionTimeout, .serverUnreachable, .rateLimitExceeded, .serverError:
                    return true
                default:
                    return false
                }
            }
        )

        static let noRetry = Configuration(
            maxRetries: 0,
            initialBackoffDelay: 0,
            maxBackoffDelay: 0,
            timeout: 30.0,
            shouldRetry: { _ in false }
        )
    }

    /// Make a network request with automatic retry and exponential backoff
    /// - Parameters:
    ///   - request: The URLRequest to execute
    ///   - config: Configuration for retry behavior
    /// - Returns: The response data and HTTP response
    static func makeRequest(
        _ request: URLRequest,
        config: Configuration = .default
    ) async throws -> (Data, HTTPURLResponse) {
        var currentRequest = request

        // Set timeout if not already set
        if currentRequest.timeoutInterval == 60.0 { // URLRequest default
            currentRequest.timeoutInterval = config.timeout
        }

        var lastError: NetworkError?

        for attempt in 0...config.maxRetries {
            do {
                // Make the request
                let (data, response) = try await URLSession.shared.data(for: currentRequest)

                // Validate HTTP response
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                // Check for HTTP errors
                guard (200...299).contains(httpResponse.statusCode) else {
                    let error = NetworkError.from(statusCode: httpResponse.statusCode, data: data)

                    // Should we retry this error?
                    if attempt < config.maxRetries && config.shouldRetry(error) {
                        lastError = error

                        // Calculate exponential backoff delay
                        let delay = min(
                            config.initialBackoffDelay * pow(2.0, Double(attempt)),
                            config.maxBackoffDelay
                        )

                        print("⚠️ Request failed (attempt \(attempt + 1)/\(config.maxRetries + 1)): \(error.localizedDescription)")
                        print("⏳ Retrying after \(delay) seconds...")

                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }

                    throw error
                }

                // Validate data is not empty
                guard !data.isEmpty else {
                    throw NetworkError.emptyResponse
                }

                // Success!
                if attempt > 0 {
                    print("✅ Request succeeded after \(attempt + 1) attempts")
                }

                return (data, httpResponse)

            } catch let error as NetworkError {
                // Should we retry?
                if attempt < config.maxRetries && config.shouldRetry(error) {
                    lastError = error

                    // Calculate exponential backoff delay
                    let delay = min(
                        config.initialBackoffDelay * pow(2.0, Double(attempt)),
                        config.maxBackoffDelay
                    )

                    print("⚠️ Request failed (attempt \(attempt + 1)/\(config.maxRetries + 1)): \(error.localizedDescription)")
                    print("⏳ Retrying after \(delay) seconds...")

                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                throw error
            } catch {
                // Map to NetworkError
                let networkError = NetworkError.from(error)

                // Should we retry?
                if attempt < config.maxRetries && config.shouldRetry(networkError) {
                    lastError = networkError

                    // Calculate exponential backoff delay
                    let delay = min(
                        config.initialBackoffDelay * pow(2.0, Double(attempt)),
                        config.maxBackoffDelay
                    )

                    print("⚠️ Request failed (attempt \(attempt + 1)/\(config.maxRetries + 1)): \(networkError.localizedDescription)")
                    print("⏳ Retrying after \(delay) seconds...")

                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                throw networkError
            }
        }

        // If we get here, we exhausted all retries
        throw lastError ?? NetworkError.unknown(NSError(domain: "NetworkRequestHelper", code: -1))
    }

    /// Make a request and decode JSON response safely
    /// - Parameters:
    ///   - request: The URLRequest to execute
    ///   - config: Configuration for retry behavior
    /// - Returns: Decoded JSON object
    static func makeRequestAndDecodeJSON(
        _ request: URLRequest,
        config: Configuration = .default
    ) async throws -> [String: Any] {
        let (data, _) = try await makeRequest(request, config: config)

        // Safe JSON parsing
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NetworkError.malformedData
            }
            return json
        } catch {
            // Check if the error is because data is not JSON
            if let dataString = String(data: data, encoding: .utf8) {
                print("⚠️ Response is not valid JSON. Data: \(dataString.prefix(200))...")
            }
            throw NetworkError.malformedData
        }
    }
}

// MARK: - Safe JSON Parsing

/// Safe JSON parsing utilities with error recovery
struct SafeJSONParser {

    /// Safely parse JSON data and extract nested values
    /// - Parameters:
    ///   - data: The data to parse
    ///   - keyPath: Dot-separated key path (e.g., "choices.0.message.content")
    /// - Returns: The value at the key path, or nil if not found
    static func parse<T>(_ data: Data, keyPath: String) -> T? {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }

            return extractValue(from: json, keyPath: keyPath)
        } catch {
            print("⚠️ JSON parsing failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Safely parse JSON data to dictionary
    /// - Parameter data: The data to parse
    /// - Returns: Dictionary or nil if parsing fails
    static func parseToDictionary(_ data: Data) -> [String: Any]? {
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            print("⚠️ JSON parsing failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Extract a value from a nested dictionary using dot notation
    /// - Parameters:
    ///   - dictionary: The source dictionary
    ///   - keyPath: Dot-separated key path (e.g., "user.profile.name")
    /// - Returns: The value at the key path, or nil if not found
    static func extractValue<T>(from dictionary: [String: Any], keyPath: String) -> T? {
        let keys = keyPath.components(separatedBy: ".")
        var current: Any? = dictionary

        for key in keys {
            if let dict = current as? [String: Any] {
                current = dict[key]
            } else if let array = current as? [Any], let index = Int(key), index < array.count {
                current = array[index]
            } else {
                return nil
            }
        }

        return current as? T
    }

    /// Safely extract an array of values from JSON
    /// - Parameters:
    ///   - data: The data to parse
    ///   - keyPath: Dot-separated key path to the array
    /// - Returns: Array of values, or empty array if not found
    static func parseArray<T>(_ data: Data, keyPath: String) -> [T] {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return []
            }

            guard let array: [T] = extractValue(from: json, keyPath: keyPath) else {
                return []
            }

            return array
        } catch {
            print("⚠️ JSON parsing failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Check if JSON contains an error field
    /// - Parameter data: The data to check
    /// - Returns: Error message if present, nil otherwise
    static func extractErrorMessage(_ data: Data) -> String? {
        guard let json = parseToDictionary(data) else {
            return nil
        }

        // Check common error patterns
        if let errorDict = json["error"] as? [String: Any] {
            // OpenAI/Perplexity format: { "error": { "message": "..." } }
            if let message = errorDict["message"] as? String {
                return message
            }
            // Alternative format: { "error": { "error": "..." } }
            if let message = errorDict["error"] as? String {
                return message
            }
        }

        // Direct error field: { "error": "..." }
        if let message = json["error"] as? String {
            return message
        }

        // Message field: { "message": "..." }
        if let message = json["message"] as? String {
            return message
        }

        return nil
    }
}

// MARK: - Error Presentation Helper

/// Helper for presenting errors to the user
struct ErrorPresenter {

    /// Get a user-friendly title for an error
    static func title(for error: Error) -> String {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .noInternetConnection:
                return "No Internet Connection"
            case .connectionTimeout:
                return "Connection Timeout"
            case .serverUnreachable:
                return "Server Unreachable"
            case .invalidAPIKey, .missingAPIKey:
                return "Configuration Error"
            case .rateLimitExceeded:
                return "Rate Limit Exceeded"
            case .serverError:
                return "Server Error"
            case .badRequest, .invalidResponse, .emptyResponse, .malformedData:
                return "Request Error"
            case .apiError:
                return "API Error"
            case .unknown:
                return "Unexpected Error"
            }
        }

        return "Error"
    }

    /// Get recovery suggestions for an error
    static func recoverySuggestion(for error: Error) -> String? {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .noInternetConnection:
                return "Check your Wi-Fi or cellular connection and try again."
            case .connectionTimeout:
                return "Make sure you have a stable internet connection."
            case .serverUnreachable:
                return "The service may be temporarily unavailable. Try again in a few minutes."
            case .invalidAPIKey:
                return "Check your API key configuration in Settings."
            case .rateLimitExceeded:
                return "Wait a few moments before making another request."
            case .serverError:
                return "The service is experiencing issues. Try again later."
            case .malformedData:
                return "The response format was unexpected. Try updating the app."
            case .missingAPIKey:
                return "Add your API key in the app settings to use this feature."
            default:
                return "Try again. If the problem persists, contact support."
            }
        }

        return nil
    }
}
