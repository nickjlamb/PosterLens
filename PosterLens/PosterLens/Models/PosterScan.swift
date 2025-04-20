import Foundation
import UIKit

struct PosterScan: Identifiable, Codable {
    let id: UUID
    let title: String
    let rawText: String
    let summaryPoints: [String]
    let date: Date
    var isSaved: Bool
    var authorQuestions: [String]?
    var hasPermission: Bool
    
    // UIImage can't be directly Codable, so we'll handle it separately
    // This is a transient property not stored in Codable representation
    var image: UIImage?
    
    // For storing the image data when encoding
    private var imageData: Data?
    
    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    init(title: String, rawText: String, summaryPoints: [String], image: UIImage?, date: Date, isSaved: Bool = false, authorQuestions: [String]? = nil, hasPermission: Bool = false) {
        self.id = UUID()
        self.title = title
        self.rawText = rawText
        self.summaryPoints = summaryPoints
        self.image = image
        self.date = date
        self.isSaved = isSaved
        self.authorQuestions = authorQuestions
        self.hasPermission = hasPermission
        
        // Convert UIImage to Data for storage
        if let image = image {
            self.imageData = image.jpegData(compressionQuality: 0.7)
        }
    }
    
    // Custom Codable implementation to handle UIImage
    enum CodingKeys: String, CodingKey {
        case id, title, rawText, summaryPoints, date, isSaved, imageData, authorQuestions, hasPermission
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        rawText = try container.decode(String.self, forKey: .rawText)
        summaryPoints = try container.decode([String].self, forKey: .summaryPoints)
        date = try container.decode(Date.self, forKey: .date)
        isSaved = try container.decode(Bool.self, forKey: .isSaved)
        authorQuestions = try container.decodeIfPresent([String].self, forKey: .authorQuestions)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        hasPermission = try container.decodeIfPresent(Bool.self, forKey: .hasPermission) ?? false
        
        // Convert Data back to UIImage
        if let imageData = imageData {
            image = UIImage(data: imageData)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(rawText, forKey: .rawText)
        try container.encode(summaryPoints, forKey: .summaryPoints)
        try container.encode(date, forKey: .date)
        try container.encode(isSaved, forKey: .isSaved)
        try container.encodeIfPresent(authorQuestions, forKey: .authorQuestions)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encode(hasPermission, forKey: .hasPermission)
    }
    
    // Create a new scan with updated questions
    func withQuestions(_ questions: [String]) -> PosterScan {
        return PosterScan(
            title: self.title,
            rawText: self.rawText,
            summaryPoints: self.summaryPoints,
            image: self.image,
            date: self.date,
            isSaved: self.isSaved,
            authorQuestions: questions,
            hasPermission: self.hasPermission
        )
    }
}
