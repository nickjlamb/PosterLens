import Foundation

/// Represents the sender of a chat message
enum MessageSender {
    case user
    case ai
}

/// Represents a single message in a conversation
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let content: String
    let sender: MessageSender
    let timestamp: Date
    
    init(id: UUID = UUID(), content: String, sender: MessageSender, timestamp: Date = Date()) {
        self.id = id
        self.content = content
        self.sender = sender
        self.timestamp = timestamp
    }
}

/// Represents a complete conversation about a poster
struct Conversation: Identifiable, Codable {
    let id: UUID
    let posterId: UUID
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    
    init(id: UUID = UUID(), posterId: UUID, messages: [ChatMessage] = [], createdAt: Date = Date()) {
        self.id = id
        self.posterId = posterId
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
    
    /// Adds a new message to the conversation and updates the timestamp
    mutating func addMessage(_ message: ChatMessage) {
        messages.append(message)
        updatedAt = Date()
    }
    
    /// Returns the most recent AI message
    func latestAIMessage() -> ChatMessage? {
        return messages.reversed().first(where: { $0.sender == .ai })
    }
    
    /// Returns the most recent user message
    func latestUserMessage() -> ChatMessage? {
        return messages.reversed().first(where: { $0.sender == .user })
    }
}

extension MessageSender: Codable {
    enum CodingKeys: CodingKey {
        case user
        case ai
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .user:
            try container.encodeNil(forKey: .user)
        case .ai:
            try container.encodeNil(forKey: .ai)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if container.contains(.user) {
            self = .user
        } else {
            self = .ai
        }
    }
}