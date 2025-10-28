import SwiftUI

/// A small colored tag displaying a category (e.g., "Lung Cancer", "Phase II")
struct CategoryTagView: View {
    let category: PosterCategory
    var showIcon: Bool = false
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 3 : 4) {
            if showIcon {
                Image(systemName: category.type.icon)
                    .font(.system(size: compact ? 10 : 12))
            }

            Text(category.name)
                .font(.system(size: compact ? 11 : 12, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 3 : 5)
        .background(category.type.color)
        .foregroundColor(.white)
        .cornerRadius(compact ? 8 : 10)
    }
}

/// Horizontal scrollable row of category tags (for ScanCardView)
struct CategoryTagRow: View {
    let categories: [PosterCategory]
    var maxVisible: Int = 3
    var compact: Bool = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categories.prefix(maxVisible)) { category in
                    CategoryTagView(category: category, compact: compact)
                }

                // Show "+N" indicator if there are more categories
                if categories.count > maxVisible {
                    Text("+\(categories.count - maxVisible)")
                        .font(.system(size: compact ? 11 : 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, compact ? 6 : 8)
                        .padding(.vertical, compact ? 3 : 5)
                        .background(Color.gray.opacity(0.7))
                        .cornerRadius(compact ? 8 : 10)
                }
            }
        }
    }
}

// MARK: - Preview
struct CategoryTagView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Individual tags
            CategoryTagView(category: PosterCategory(type: .cancerType, name: "Lung Cancer"))
            CategoryTagView(category: PosterCategory(type: .researchFocus, name: "Quality of Life"))
            CategoryTagView(category: PosterCategory(type: .researchPhase, name: "Phase II"))
            CategoryTagView(category: PosterCategory(type: .treatmentModality, name: "Chemotherapy"))

            Divider()

            // Tag row
            CategoryTagRow(categories: [
                PosterCategory(type: .cancerType, name: "Lung Cancer"),
                PosterCategory(type: .researchFocus, name: "Quality of Life"),
                PosterCategory(type: .researchPhase, name: "Phase II"),
                PosterCategory(type: .treatmentModality, name: "Chemotherapy")
            ])

            Divider()

            // Compact tags
            CategoryTagView(category: PosterCategory(type: .cancerType, name: "Lung Cancer"), compact: true)
            CategoryTagView(category: PosterCategory(type: .researchPhase, name: "Phase III"), showIcon: true)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
