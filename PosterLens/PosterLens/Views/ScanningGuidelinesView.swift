import SwiftUI

struct ScanningGuidelinesView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Scanning Guidelines")
                            .font(.largeTitle.bold())
                            .foregroundColor(.primary)

                        Text("Please respect the intellectual property and privacy of poster authors")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)

                    // Important notice
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Always Ask Permission First")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Text("Before photographing any scientific poster, you must obtain explicit permission from the poster author or presenter. Their research represents months or years of work and may contain unpublished data.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)

                    // Guideline items
                    GuidelineItem(
                        icon: "person.2.fill",
                        iconColor: DesignSystem.Colors.brandBlue,
                        title: "Seek Consent",
                        description: "Approach the author politely and explain that you'd like to capture their poster for personal study. Respect their decision if they decline."
                    )

                    GuidelineItem(
                        icon: "lock.shield.fill",
                        iconColor: .green,
                        title: "Respect Intellectual Property",
                        description: "Poster content is the intellectual property of the authors. Do not share, publish, or distribute scanned content without permission."
                    )

                    GuidelineItem(
                        icon: "doc.text.fill",
                        iconColor: .purple,
                        title: "Personal Use Only",
                        description: "Use scanned posters only for your own learning and reference. This app is intended for note-taking during conferences, not for data extraction or reproduction."
                    )

                    GuidelineItem(
                        icon: "camera.badge.ellipsis",
                        iconColor: .orange,
                        title: "Unpublished Data",
                        description: "Be especially careful with preliminary or unpublished results. Authors may not want their work photographed until it's officially published."
                    )

                    GuidelineItem(
                        icon: "bubble.left.and.bubble.right.fill",
                        iconColor: .blue,
                        title: "Engage with Authors",
                        description: "Consider having a conversation with the author instead of just photographing. They can provide context and insights not visible on the poster."
                    )

                    GuidelineItem(
                        icon: "hand.raised.fill",
                        iconColor: .red,
                        title: "When in Doubt, Ask",
                        description: "If you're unsure about whether it's appropriate to photograph a poster, ask the author or conference organizers for guidance."
                    )

                    // Best practices section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                            Text("Best Practices")
                                .font(.headline)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            TipItem(text: "Introduce yourself and explain your interest in their work")
                            TipItem(text: "Ask if there are any parts of the poster they'd prefer not to be photographed")
                            TipItem(text: "Offer to share your contact information for future questions")
                            TipItem(text: "Thank the author for their time and permission")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
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

struct TipItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.footnote)

            Text(text)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ScanningGuidelinesView()
}
