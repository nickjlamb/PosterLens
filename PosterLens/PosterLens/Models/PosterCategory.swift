import Foundation
import SwiftUI

// MARK: - Category Type Enum
enum CategoryType: String, Codable, CaseIterable {
    case field = "Field"
    case focus = "Research Focus"
    case methods = "Methods"
    case studyType = "Study Type"

    // Tolerant decoding: map legacy oncology-specific rawValues to the general
    // buckets so scans saved before the broadening still load.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "Cancer Types": self = .field
        case "Treatment Modalities": self = .methods
        case "Research Phases": self = .studyType
        case "Research Focus": self = .focus
        default: self = CategoryType(rawValue: raw) ?? .focus
        }
    }

    var color: Color {
        switch self {
        case .field:
            return Color(red: 0.93, green: 0.26, blue: 0.39) // Red/Pink
        case .focus:
            return Color(red: 0.75, green: 0.22, blue: 0.85) // Purple
        case .methods:
            return Color(red: 0.20, green: 0.68, blue: 0.96) // Blue
        case .studyType:
            return Color(red: 0.40, green: 0.82, blue: 0.58) // Green
        }
    }

    var icon: String {
        switch self {
        case .field:
            return "books.vertical.fill"
        case .focus:
            return "target"
        case .methods:
            return "wrench.and.screwdriver.fill"
        case .studyType:
            return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - Category Model
struct PosterCategory: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let type: CategoryType
    let name: String

    init(type: CategoryType, name: String) {
        self.id = UUID()
        self.type = type
        self.name = name
    }

    // Hashable conformance for SwiftUI ForEach with id: \.self
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Categorized Poster Groups
struct CategorizedPosters: Identifiable {
    let id = UUID()
    let category: PosterCategory
    var scans: [PosterScan]
}
