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

                        Text("Follow these tips to get the best results when scanning scientific posters")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)

                    // Guideline items
                    GuidelineItem(
                        icon: "camera.fill",
                        iconColor: DesignSystem.Colors.brandBlue,
                        title: "Good Lighting",
                        description: "Ensure the poster is well-lit and avoid shadows. Natural light or even artificial lighting works best."
                    )

                    GuidelineItem(
                        icon: "rectangle.center.inset.filled",
                        iconColor: .green,
                        title: "Frame the Entire Poster",
                        description: "Try to capture the entire poster in the frame. The app works best when it can see all the content at once."
                    )

                    GuidelineItem(
                        icon: "eye.slash.fill",
                        iconColor: .orange,
                        title: "Avoid Glare",
                        description: "Be mindful of reflective surfaces. Adjust your angle to minimize glare from lights or windows."
                    )

                    GuidelineItem(
                        icon: "hand.raised.fill",
                        iconColor: .red,
                        title: "Hold Steady",
                        description: "Keep your device steady when taking the photo. Blurry images can affect text recognition accuracy."
                    )

                    GuidelineItem(
                        icon: "textformat",
                        iconColor: .purple,
                        title: "Clear Text",
                        description: "Make sure the text is clearly visible and in focus. The OCR works best with sharp, high-contrast text."
                    )

                    GuidelineItem(
                        icon: "arrow.up.left.and.arrow.down.right",
                        iconColor: .blue,
                        title: "Optimal Distance",
                        description: "Stand at a distance where the poster fills most of the frame, but all content is visible."
                    )

                    // Tips section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.title3)
                            Text("Pro Tips")
                                .font(.headline)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            TipItem(text: "Portrait mode works best for most posters")
                            TipItem(text: "Tap to focus on the poster before capturing")
                            TipItem(text: "If the first scan isn't perfect, try again with better positioning")
                            TipItem(text: "The app works better in well-lit conference halls")
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
