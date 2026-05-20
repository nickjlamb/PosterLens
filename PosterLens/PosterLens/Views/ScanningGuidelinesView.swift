import SwiftUI

struct ScanningGuidelinesView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Scanning Guidelines")
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)

                        Text("Respect the work and privacy of poster authors.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 24) {
                        GuidelineItem(
                            icon: "person.2.fill",
                            iconColor: DesignSystem.Colors.brandBlue,
                            title: "Ask permission first",
                            description: "Always get the author's consent before photographing their poster."
                        )

                        GuidelineItem(
                            icon: "lock.shield.fill",
                            iconColor: .green,
                            title: "Respect their work",
                            description: "Posters are the authors' intellectual property. Keep scans for your own reference — don't share or publish them."
                        )

                        GuidelineItem(
                            icon: "exclamationmark.triangle.fill",
                            iconColor: .orange,
                            title: "Mind unpublished data",
                            description: "Take extra care with preliminary results that aren't published yet."
                        )

                        GuidelineItem(
                            icon: "bubble.left.and.bubble.right.fill",
                            iconColor: DesignSystem.Colors.brandBlue,
                            title: "Talk to the author",
                            description: "A short conversation often adds context the poster can't — and it's a courtesy."
                        )
                    }
                }
                .padding(24)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .tint(DesignSystem.Colors.brandBlue)
    }
}

struct GuidelineItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
            }

            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    ScanningGuidelinesView()
}
