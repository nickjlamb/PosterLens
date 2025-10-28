import SwiftUI
import UIKit


struct ScanCardView: View {
    let scan: PosterScan
    @State private var showingOptions = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @EnvironmentObject private var dataStore: DataStore
    
    // Selection mode properties
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelect: ((Bool) -> Void)? = nil
    
    var body: some View {
        ZStack {
            // Main card content
            NavigationLink(destination: SummaryView(scan: scan)) {
                ZStack(alignment: .bottom) {
                    // Thumbnail image - improved for landscape images
                    if let image = scan.image {
                        ZStack {
                            // Check if image is landscape
                            if image.size.width > image.size.height {
                                // Landscape image - contain within frame
                                ZStack {
                                    // Background for empty space
                                    Rectangle()
                                        .fill(Color.black)
                                        .frame(height: 180)
                                    
                                    // Image with contain mode to show entire image
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(height: 180)
                                    
                                    // Indicator for landscape view in corner
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "arrow.left.and.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                                .padding(6)
                                                .background(Color.black.opacity(0.6))
                                                .cornerRadius(6)
                                                .padding(8)
                                        }
                                        Spacer()
                                    }
                                }
                            } else {
                                // Portrait image - fill as before
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 180)
                                    .clipped()
                            }
                        }
                    } else {
                        // No image placeholder
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 180)
                            .overlay(
                                Image(systemName: "doc.text.image")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // Title overlay with categories - UX: Use DesignSystem spacing
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.tiny) {
                        Text(scan.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        Text(scan.dateFormatted)
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // Category tags
                        if let categories = scan.categories, !categories.isEmpty {
                            CategoryTagRow(categories: categories, maxVisible: 3, compact: true)
                                .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSystem.Spacing.extraSmall)
                    .background(Material.regularMaterial)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSelectionMode) // Disable navigation when in selection mode
            .contextMenu {
                Button(action: {
                    // Share action - Generate PDF and show share sheet
                    // Ensure the PDF is generated and shared
                    showingShareSheet = true
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Button(role: .destructive, action: {
                    // Delete action - Show confirmation alert
                    showingDeleteAlert = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            // Selection overlay - UX: Add haptic feedback
            if isSelectionMode {
                Button(action: {
                    HapticManager.shared.selection()
                    onSelect?(!isSelected)
                }) {
                    ZStack {
                        // Full-size transparent button area
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 180)
                        
                        // Selection indicator in top-right corner
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(isSelected ? .blue : .gray.opacity(0.8))
                                    .background(
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 22, height: 22)
                                    )
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .cornerRadius(DesignSystem.CornerRadius.large)  // UX: Use DesignSystem
        .shadowStyle(DesignSystem.Shadow.card)  // UX: Use DesignSystem shadow
        // Add selection highlight with smooth animation
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .stroke(isSelected ? DesignSystem.Colors.brandBlue : Color.clear, lineWidth: 3)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        )
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.large)
                .fill(isSelected ? DesignSystem.Colors.brandBlue.opacity(0.1) : Color.clear)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
        )
        // Add long press gesture to enter selection mode - UX: Add haptic feedback
        .onLongPressGesture {
            if !isSelectionMode {
                HapticManager.shared.mediumImpact()
                // Trigger selection mode with this item selected
                onSelect?(true)
            }
        }
        // Add alert for delete confirmation
        .alert("Delete Scan?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // Delete the scan
                dataStore.deleteScan(withID: scan.id)

                // UX: Use HapticManager for consistent feedback
                HapticManager.shared.success()
            }
        } message: {
            Text("This will permanently delete this scan. This action cannot be undone.")
        }
        // Add sheet for sharing
        .sheet(isPresented: $showingShareSheet) {
            if let pdfURLs = dataStore.exportScansAsPDF(withIDs: [scan.id]), !pdfURLs.isEmpty {
                CustomShareSheet(items: pdfURLs)
            } else {
                // Fallback in case PDF generation fails
                let text = "Poster Title: \(scan.title)\n\nSummary:\n" + scan.summaryPoints.joined(separator: "\n\n")
                CustomShareSheet(items: [text])
            }
        }
    }
}

struct PlaceholderCardView: View {
    // Add onTap action closure
    var onTap: (() -> Void)?
    @State private var isPressed = false
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.15))
                .frame(height: 180)
            
            VStack {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
                    // Add subtle pulsing animation to draw attention
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.2)
                            .repeatCount(1, autoreverses: true),
                        value: isPressed
                    )
                
                Text("Scan a Poster")
                    .font(.caption)
                    .fontWeight(.medium) // Make text slightly bolder
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        // Make the entire card tappable - UX: Use HapticManager
        .onTapGesture {
            // UX: Use HapticManager for consistent feedback
            HapticManager.shared.mediumImpact()

            // Visual feedback with smooth animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPressed = true
            }

            // Reset after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isPressed = false
                }

                // After visual feedback completes, directly show the camera
                if let onTap = onTap {
                    onTap()
                } else {
                    // If no custom action provided, try to show camera directly
                    NotificationCenter.default.post(name: NSNotification.Name("ShowCamera"), object: nil)
                }
            }
        }
        // Add hover effect for better interactivity
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}
