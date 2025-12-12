import Foundation

/// Central configuration for PosterLens app
struct Config {

    // MARK: - RAG Evidence API

    /// Evidence API endpoint (API Gateway URL)
    static let evidenceAPIURL = "https://posterlens-gateway-173xx7rs.nw.gateway.dev/v2/evidence"

    /// Evidence API key (loaded from Secrets.plist)
    static let evidenceAPIKey: String = {
        SecretManager.shared.loadAPIKey(for: "Evidence_API_Key")
    }()
}
