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
                .truncationMode(.tail)
                .frame(maxWidth: compact ? 130 : 180)
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
            CategoryTagView(category: PosterCategory(type: .field, name: "Oncology"))
            CategoryTagView(category: PosterCategory(type: .focus, name: "Quality of Life"))
            CategoryTagView(category: PosterCategory(type: .studyType, name: "Phase III"))
            CategoryTagView(category: PosterCategory(type: .methods, name: "Immunotherapy"))

            Divider()

            // Tag row
            CategoryTagRow(categories: [
                PosterCategory(type: .field, name: "Oncology"),
                PosterCategory(type: .focus, name: "Quality of Life"),
                PosterCategory(type: .studyType, name: "Phase III"),
                PosterCategory(type: .methods, name: "Immunotherapy")
            ])

            Divider()

            // Compact tags
            CategoryTagView(category: PosterCategory(type: .field, name: "Oncology"), compact: true)
            CategoryTagView(category: PosterCategory(type: .studyType, name: "Phase III"), showIcon: true)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
