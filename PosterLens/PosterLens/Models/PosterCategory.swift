import Foundation
import SwiftUI

// MARK: - Category Type Enum
enum CategoryType: String, Codable, CaseIterable {
    case cancerType = "Cancer Types"
    case researchFocus = "Research Focus"
    case researchPhase = "Research Phases"
    case treatmentModality = "Treatment Modalities"

    var color: Color {
        switch self {
        case .cancerType:
            return Color(red: 0.93, green: 0.26, blue: 0.39) // Red/Pink
        case .researchFocus:
            return Color(red: 0.75, green: 0.22, blue: 0.85) // Purple
        case .researchPhase:
            return Color(red: 0.40, green: 0.82, blue: 0.58) // Green
        case .treatmentModality:
            return Color(red: 0.20, green: 0.68, blue: 0.96) // Blue
        }
    }

    var icon: String {
        switch self {
        case .cancerType:
            return "heart.text.square"
        case .researchFocus:
            return "target"
        case .researchPhase:
            return "chart.line.uptrend.xyaxis"
        case .treatmentModality:
            return "cross.case"
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

    // Predefined common categories for better UX
    static let commonCategories: [CategoryType: [String]] = [
        .cancerType: [
            "Lung Cancer",
            "Breast Cancer",
            "Colorectal Cancer",
            "Prostate Cancer",
            "Melanoma",
            "Lymphoma",
            "Leukemia",
            "Brain Tumor",
            "Ovarian Cancer",
            "Pancreatic Cancer"
        ],
        .researchFocus: [
            "Quality of Life",
            "Survival Analysis",
            "Biomarkers",
            "Treatment Efficacy",
            "Safety & Toxicity",
            "Patient-Reported Outcomes",
            "Pharmacokinetics",
            "Immunotherapy Response",
            "Resistance Mechanisms",
            "Diagnosis & Screening"
        ],
        .researchPhase: [
            "Preclinical",
            "Phase I",
            "Phase II",
            "Phase III",
            "Phase IV",
            "Real-World Evidence",
            "Meta-Analysis",
            "Systematic Review"
        ],
        .treatmentModality: [
            "Chemotherapy",
            "Immunotherapy",
            "Targeted Therapy",
            "Radiation Therapy",
            "Surgery",
            "CAR-T Cell Therapy",
            "Hormone Therapy",
            "Combination Therapy",
            "Supportive Care"
        ]
    ]

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
