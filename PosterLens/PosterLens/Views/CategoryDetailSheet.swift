import SwiftUI

/// Sheet that displays all categories for a poster, grouped by type
struct CategoryDetailSheet: View {
    let scan: PosterScan
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Research Categories")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("All detected categories for this poster")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Group categories by type
                    if let categories = scan.categories, !categories.isEmpty {
                        ForEach(CategoryType.allCases, id: \.self) { categoryType in
                            let typeCategories = categories.filter { $0.type == categoryType }

                            if !typeCategories.isEmpty {
                                CategoryTypeSection(
                                    categoryType: categoryType,
                                    categories: typeCategories
                                )
                            }
                        }
                    } else {
                        // No categories
                        VStack(spacing: 16) {
                            Image(systemName: "tag.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))

                            Text("No categories detected")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("Categories will be automatically detected when you scan a poster")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}

/// Section displaying categories of a specific type
struct CategoryTypeSection: View {
    let categoryType: CategoryType
    let categories: [PosterCategory]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: categoryType.icon)
                    .font(.system(size: 16))
                    .foregroundColor(categoryType.color)

                Text(categoryType.rawValue)
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal)

            // Category tags
            FlowLayout(spacing: 8) {
                ForEach(categories) { category in
                    CategoryTagView(category: category, showIcon: false, compact: false)
                }
            }
            .padding(.horizontal)
        }
    }
}

/// Flow layout for wrapping category tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            let frame = result.frames[index]
            // Offset the position by bounds.origin to place correctly
            let position = CGPoint(
                x: bounds.origin.x + frame.origin.x,
                y: bounds.origin.y + frame.origin.y
            )
            subview.place(at: position, proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(
                    x: currentX,
                    y: currentY,
                    width: size.width,
                    height: size.height
                ))

                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(
                width: maxWidth,
                height: currentY + lineHeight
            )
        }
    }
}

// MARK: - Preview
struct CategoryDetailSheet_Previews: PreviewProvider {
    static var previews: some View {
        CategoryDetailSheet(scan: PosterScan(
            title: "Example Poster",
            rawText: "Sample text",
            summaryPoints: [],
            image: nil,
            date: Date(),
            categories: [
                PosterCategory(type: .field, name: "Oncology"),
                PosterCategory(type: .focus, name: "Quality of Life"),
                PosterCategory(type: .focus, name: "Biomarkers"),
                PosterCategory(type: .studyType, name: "Phase III"),
                PosterCategory(type: .methods, name: "Immunotherapy"),
                PosterCategory(type: .methods, name: "Targeted Therapy")
            ]
        ))
    }
}
