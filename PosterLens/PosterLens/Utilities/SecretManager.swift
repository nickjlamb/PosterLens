import Foundation

/// Centralized manager for loading API keys and secrets from Secrets.plist
/// This consolidates duplicate secret-loading logic across services
class SecretManager {
    // MARK: - Singleton

    static let shared = SecretManager()

    private init() {}

    // MARK: - Public Methods

    /// Load an API key from Secrets.plist
    /// - Parameters:
    ///   - key: The key name in the plist (e.g., "OpenAI_API_Key")
    ///   - fallback: Optional fallback value if key is not found
    /// - Returns: The API key string, or empty string if not found and no fallback provided
    func loadAPIKey(for key: String, fallback: String? = nil) -> String {
        // Try to load from Secrets.plist
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
           let secretKey = dict[key] as? String, !secretKey.isEmpty {
            return secretKey
        }

        // Fall back to provided value if available
        if let fallback = fallback, !fallback.isEmpty {
            return fallback
        }

        // No key found
        print("⚠️ Warning: No value found for key '\(key)' in Secrets.plist")
        return ""
    }

    /// Check if an API key is valid (non-empty and not a placeholder)
    /// - Parameters:
    ///   - key: The API key to validate
    ///   - prefix: Optional required prefix (e.g., "sk-" for OpenAI)
    /// - Returns: True if the key is valid
    func isValid(apiKey key: String, requiredPrefix prefix: String? = nil) -> Bool {
        // Check if empty or placeholder
        guard !key.isEmpty, key != "YOUR_API_KEY_HERE" else {
            return false
        }

        // Check prefix if required
        if let prefix = prefix {
            return key.hasPrefix(prefix)
        }

        return true
    }
}
