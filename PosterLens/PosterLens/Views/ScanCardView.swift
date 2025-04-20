import SwiftUI

struct ScanCardView: View {
    let scan: PosterScan
    @State private var showingOptions = false
    
    // Selection mode properties
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onSelect: ((Bool) -> Void)? = nil
    
    var body: some View {
        ZStack {
            // Main card content
            NavigationLink(destination: SummaryView(scan: scan)) {
                ZStack(alignment: .bottom) {
                    // Thumbnail image
                    if let image = scan.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 180)
                            .overlay(
                                Image(systemName: "doc.text.image")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // Title overlay
                    VStack(alignment: .leading, spacing: 2) {
                        Text(scan.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        
                        Text(scan.dateFormatted)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Material.regularMaterial)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isSelectionMode) // Disable navigation when in selection mode
            .contextMenu {
                Button(action: {
                    // Share action
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                
                Button(role: .destructive, action: {
                    // Delete action
                }) {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            // Selection overlay
            if isSelectionMode {
                Button(action: {
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
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
        // Add selection highlight
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        // Add long press gesture to enter selection mode
        .onLongPressGesture {
            if !isSelectionMode {
                // Trigger selection mode with this item selected
                onSelect?(true)
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
                .fill(Color.gray.opacity(0.1))
                .frame(height: 180)
            
            VStack {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24))
                    .foregroundColor(.gray.opacity(0.5))
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
                    .foregroundColor(.gray.opacity(0.7))
            }
        }
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        // Make the entire card tappable
        .onTapGesture {
            // Provide haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Visual feedback
            withAnimation {
                isPressed = true
            }
            
            // Reset after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    isPressed = false
                }
            }
            
            // Call the onTap action if provided
            onTap?()
        }
        // Add hover effect for better interactivity
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}
