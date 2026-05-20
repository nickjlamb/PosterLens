import SwiftUI

// Preference key for tracking scroll position
struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Helper view for sharing files
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ImprovedHistoryView: View {
    @EnvironmentObject private var dataStore: DataStore
    @State private var showingDeleteAlert = false
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var exportURLs: [URL] = []
    @State private var gridColumns = [GridItem(.flexible(), spacing: 20)]
    @State private var isEditMode: EditMode = .inactive
    @State private var viewHeight: CGFloat = 0

    // Selection mode states
    @State private var isSelectionMode = false
    @State private var selectedScanIDs = Set<UUID>()
    @State private var showingBatchDeleteAlert = false
    @State private var showingExportOptions = false

    // Animation states
    @State private var scrollOffset: CGFloat = 0
    @State private var appeared = false

    // Binding to the selected tab in ContentView
    var selectedTab: Binding<Int>?
    
    // Initialize with optional binding to selectedTab
    init(selectedTab: Binding<Int>? = nil) {
        self.selectedTab = selectedTab
        
        // Set grid columns with more appropriate spacing for landscape posters
        self.gridColumns = [
            GridItem(.flexible(), spacing: 20)
        ]
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    // Clean white background
                    Color(.systemBackground)
                        .ignoresSafeArea()

                    ScrollView {
                        // Geometry reader to track scroll position
                        GeometryReader { scrollGeo in
                            Color.clear.preference(key: ScrollOffsetKey.self, 
                                                  value: scrollGeo.frame(in: .named("scrollSpace")).minY)
                        }
                        .frame(height: 0)

                        // Large dark left-aligned title (native iOS pattern)
                        HStack {
                            Text(isSelectionMode ? "\(selectedScanIDs.count) Selected" : "Scan History")
                                .font(.largeTitle.bold())
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        if dataStore.savedScans.isEmpty {
                            emptyStateView
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 20)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)
                        } else {
                            gridView
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)
                        }
                    }
                    .coordinateSpace(name: "scrollSpace")
                    .onPreferenceChange(ScrollOffsetKey.self) { offset in
                        scrollOffset = offset
                    }
                    .onAppear {
                        // Store the view height for placeholder calculations
                        viewHeight = geometry.size.height
                        
                        // Trigger appearance animations
                        withAnimation {
                            appeared = true
                        }
                    }
                    .onChange(of: geometry.size.height) { newHeight in
                        viewHeight = newHeight
                    }
                    
                    // Bottom toolbar for selection mode
                    if isSelectionMode && !selectedScanIDs.isEmpty {
                        selectionToolbar
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(.systemBackground), for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                // Leading items (left side)
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button("Cancel") {
                            // Exit selection mode
                            withAnimation {
                                isSelectionMode = false
                                selectedScanIDs.removeAll()
                            }
                        }
                    } else {
                        EditButton()
                            .disabled(dataStore.savedScans.isEmpty)
                            .environment(\.editMode, $isEditMode)
                    }
                }
                
                // Trailing items (right side)
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        if isSelectionMode {
                            Button(selectedScanIDs.count == dataStore.savedScans.count ? "Deselect All" : "Select All") {
                                withAnimation {
                                    if selectedScanIDs.count == dataStore.savedScans.count {
                                        // Deselect all
                                        selectedScanIDs.removeAll()
                                    } else {
                                        // Select all
                                        selectedScanIDs = Set(dataStore.savedScans.map { $0.id })
                                    }
                                }
                            }
                        } else {
                            // Only show Select button if there are scans
                            if !dataStore.savedScans.isEmpty {
                                Button("Select") {
                                    withAnimation {
                                        isSelectionMode = true
                                    }
                                }
                            }

                            Menu {
                                Button(action: {
                                    // Haptic feedback
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                    impactFeedback.impactOccurred()

                                    // Toggle between 1, 2 and 3 columns with spring animation
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        if gridColumns.count == 1 {
                                            // Switch to 2 columns
                                            gridColumns = [
                                                GridItem(.flexible(), spacing: 16),
                                                GridItem(.flexible(), spacing: 16)
                                            ]
                                        } else if gridColumns.count == 2 {
                                            // Switch to 3 columns
                                            gridColumns = [
                                                GridItem(.flexible(), spacing: 12),
                                                GridItem(.flexible(), spacing: 12),
                                                GridItem(.flexible(), spacing: 12)
                                            ]
                                        } else {
                                            // Back to 1 column - best for landscape posters
                                            gridColumns = [
                                                GridItem(.flexible(), spacing: 20)
                                            ]
                                        }
                                    }
                                }) {
                                    // Dynamic label based on current column count and next state
                                    Label(
                                        gridColumns.count == 1 ? "Two Columns" :
                                        (gridColumns.count == 2 ? "Three Columns" : "Single Column"),
                                        systemImage: gridColumns.count == 1 ? "square.grid.2x2" :
                                        (gridColumns.count == 2 ? "square.grid.3x2" : "rectangle")
                                    )
                                    .animation(.easeOut(duration: 0.2), value: gridColumns.count)
                                }

                                Button(action: {
                                    // Export all scans as PDF
                                    if let urls = dataStore.exportScansAsPDF() {
                                        exportURLs = urls
                                        showingExportSheet = true
                                    }
                                }) {
                                    Label("Export All as PDF", systemImage: "doc.richtext")
                                }

                                Button(action: {
                                    // Export all scans as JSON (legacy option)
                                    exportURL = dataStore.exportScans()
                                    if exportURL != nil {
                                        showingExportSheet = true
                                    }
                                }) {
                                    Label("Export All as JSON", systemImage: "square.and.arrow.up")
                                }

                                Divider()

                                Button(role: .destructive, action: {
                                    showingDeleteAlert = true
                                }) {
                                    Label("Clear All", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .imageScale(.large)
                                    .foregroundColor(DesignSystem.Colors.brandBlue)
                            }
                        }
                    }
                }
            }
            .alert("Clear All Scans?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear All", role: .destructive) {
                    dataStore.clearAllScans()
                }
            } message: {
                Text("This will permanently delete all saved scans. This action cannot be undone.")
            }
            .alert("Delete Selected Scans?", isPresented: $showingBatchDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    // Delete selected scans
                    dataStore.deleteScans(withIDs: Array(selectedScanIDs))
                    
                    // Exit selection mode
                    withAnimation {
                        isSelectionMode = false
                        selectedScanIDs.removeAll()
                    }
                }
            } message: {
                Text("This will permanently delete \(selectedScanIDs.count) selected scan\(selectedScanIDs.count == 1 ? "" : "s"). This action cannot be undone.")
            }
            .actionSheet(isPresented: $showingExportOptions) {
                ActionSheet(
                    title: Text("Export Options"),
                    message: Text("Choose an export format"),
                    buttons: [
                        .default(Text("Export as PDF")) {
                            if let urls = dataStore.exportScansAsPDF(withIDs: Array(selectedScanIDs)) {
                                exportURLs = urls
                                showingExportSheet = true
                                
                                // Exit selection mode after export
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation {
                                        isSelectionMode = false
                                        selectedScanIDs.removeAll()
                                    }
                                }
                            }
                        },
                        .default(Text("Export as JSON")) {
                            exportURL = dataStore.exportScans(withIDs: Array(selectedScanIDs))
                            if exportURL != nil {
                                showingExportSheet = true
                                
                                // Exit selection mode after export
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation {
                                        isSelectionMode = false
                                        selectedScanIDs.removeAll()
                                    }
                                }
                            }
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                } else if !exportURLs.isEmpty {
                    ShareSheet(items: exportURLs)
                }
            }
        }
    }
    
    // Bottom toolbar for selection mode
    private var selectionToolbar: some View {
        HStack(spacing: 30) {
            // Export button
            Button(action: {
                // Haptic feedback
                let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
                feedbackGenerator.impactOccurred()
                
                showingExportOptions = true
            }) {
                VStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                    Text("Export")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.brandBlue.opacity(0.7))
                )
            }
            .buttonStyle(PressableButtonStyle())
            
            // Delete button
            Button(action: {
                // Haptic feedback for destructive action
                let feedbackGenerator = UINotificationFeedbackGenerator()
                feedbackGenerator.notificationOccurred(.warning)
                
                showingBatchDeleteAlert = true
            }) {
                VStack {
                    Image(systemName: "trash")
                        .font(.system(size: 22))
                    Text("Delete")
                        .font(.caption)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.7))
                )
                .foregroundColor(.white)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                // Blurred background
                Rectangle()
                    .fill(Material.ultraThinMaterial)
                
                // Top divider line
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.white.opacity(0.3), .white.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(height: 1)
                    .offset(y: -18)
            }
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: -2)
        )
        // Improved transition with spring animation
        .transition(
            .asymmetric(
                insertion: .move(edge: .bottom)
                    .combined(with: .opacity)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7)),
                removal: .opacity
                    .combined(with: .scale(scale: 0.95))
                    .animation(.easeOut(duration: 0.2))
            )
        )
    }
    
    // Grid view for displaying scans
    private var gridView: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(Array(dataStore.savedScans.sorted(by: { $0.date > $1.date }).enumerated()), id: \.element.id) { index, scan in
                if isEditMode.isEditing && !isSelectionMode {
                    // Edit mode for deletion (original functionality)
                    ScanCardView(scan: scan, isHorizontal: gridColumns.count == 1)
                        .overlay(
                            deleteButton(for: scan),
                            alignment: .topTrailing
                        )
                        // Subtle scale effect when editing
                        .scaleEffect(appeared ? 1 : 0.95)
                        .opacity(appeared ? 1 : 0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.7)
                            .delay(0.05 * Double(index % 8)), 
                            value: appeared
                        )
                } else {
                    // Normal mode or selection mode
                    ScanCardView(
                        scan: scan,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedScanIDs.contains(scan.id),
                        onSelect: { isSelected in
                            handleSelection(scan: scan, isSelected: isSelected)
                        },
                        isHorizontal: gridColumns.count == 1
                    )
                    // Apply staggered entry animation
                    .offset(y: appeared ? 0 : 20)
                    .opacity(appeared ? 1 : 0)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.7)
                        .delay(0.05 * Double(index % 8)), 
                        value: appeared
                    )
                    // Add hover effect on scroll for a more dynamic feel
                    .modifier(ParallaxCard(scrollOffset: scrollOffset, itemIndex: index))
                }
            }
            
            // Add placeholders to fill the screen
            ForEach(0..<calculatePlaceholderCount(), id: \.self) { index in
                PlaceholderCardView(onTap: {
                    // First switch to camera tab
                    selectedTab?.wrappedValue = 0
                    
                    // Then post notification to trigger camera
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowCamera"), object: nil)
                    }
                })
                // Add staggered animations to placeholders too
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)
                .animation(
                    .spring(response: 0.4, dampingFraction: 0.7)
                    .delay(0.1 + 0.05 * Double(index % 4)), 
                    value: appeared
                )
            }
        }
        .padding()
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dataStore.savedScans.count)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedScanIDs.count)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: gridColumns.count)
    }
    
    // Handle selection of a scan
    private func handleSelection(scan: PosterScan, isSelected: Bool) {
        withAnimation {
            // If this is the first selection via long press, enter selection mode
            if !isSelectionMode {
                isSelectionMode = true
            }
            
            // Update selected scans
            if isSelected {
                selectedScanIDs.insert(scan.id)
            } else {
                selectedScanIDs.remove(scan.id)
            }
            
            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }
    }
    
    // Calculate how many placeholders to show to fill the screen
    private func calculatePlaceholderCount() -> Int {
        // If there are no saved scans, we'll show a different UI
        if dataStore.savedScans.isEmpty {
            return 0
        }
        
        // Calculate available height
        let cardHeight: CGFloat = 180 // Height of each card
        let verticalSpacing: CGFloat = 16 // Spacing between cards
        let topBottomPadding: CGFloat = 32 // Padding at top and bottom
        let tabBarHeight: CGFloat = 49 // Standard tab bar height
        let navBarHeight: CGFloat = 44 // Standard navigation bar height
        
        // Calculate available height for cards
        let availableHeight = viewHeight - navBarHeight - tabBarHeight - topBottomPadding
        
        // Calculate how many rows can fit
        let rowsCanFit = Int((availableHeight + verticalSpacing) / (cardHeight + verticalSpacing))
        
        // Calculate total cards that can fit
        let totalCardsCanFit = rowsCanFit * gridColumns.count
        
        // Calculate how many placeholders we need
        let existingCards = dataStore.savedScans.count
        let placeholdersNeeded = max(gridColumns.count, totalCardsCanFit - existingCards)
        
        return placeholdersNeeded
    }
    
    // Empty state view
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Icon with subtle floating animation
            Image(systemName: "doc.text.image")
                .font(.system(size: 70))
                .foregroundColor(.secondary.opacity(0.5))
                .modifier(FloatingAnimation(duration: 4, offset: 8))

            // Title with staggered animation
            Text("No Scans Yet")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .transition(.opacity.combined(with: .move(edge: .top)))

            // Description text
            Text("Tap the camera tab to scan your first scientific poster")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .transition(.opacity.combined(with: .scale))
            
            // Animated button with stronger visual cue
            Button(action: {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // First switch to camera tab
                selectedTab?.wrappedValue = 0
                
                // Then post notification to trigger camera
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowCamera"), object: nil)
                }
            }) {
                Text("Scan a Poster")
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(DesignSystem.Colors.brandBlue)
                            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                    )
                    .foregroundColor(.white)
            }
            .buttonStyle(PressableButtonStyle()) // Custom button style with press animation
            .padding(.top, 10)
            
            Spacer()
            
            // Visual guide for where scans will appear - fill the screen with placeholders
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(0..<calculateEmptyStatePlaceholderCount(), id: \.self) { index in
                    PlaceholderCardView(onTap: {
                        // First switch to camera tab
                        selectedTab?.wrappedValue = 0
                        
                        // Then post notification to trigger camera
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            NotificationCenter.default.post(name: NSNotification.Name("ShowCamera"), object: nil)
                        }
                    })
                    .opacity(0.4)
                    // Stagger the appearance of each placeholder
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(
                        .spring(response: 0.5, dampingFraction: 0.7)
                        .delay(0.1 + Double(index % 4) * 0.1), 
                        value: appeared
                    )
                }
            }
            .padding()
        }
        .padding(.vertical, 40)
    }
    
    // Calculate how many placeholders to show in empty state to fill the screen
    private func calculateEmptyStatePlaceholderCount() -> Int {
        // Calculate available height
        let cardHeight: CGFloat = 180 // Height of each card
        let verticalSpacing: CGFloat = 16 // Spacing between cards
        let topBottomPadding: CGFloat = 32 // Padding at top and bottom
        let tabBarHeight: CGFloat = 49 // Standard tab bar height
        let navBarHeight: CGFloat = 44 // Standard navigation bar height
        let emptyStateContentHeight: CGFloat = 300 // Approximate height of the empty state content
        
        // Calculate available height for cards
        let availableHeight = viewHeight - navBarHeight - tabBarHeight - topBottomPadding - emptyStateContentHeight
        
        // Calculate how many rows can fit
        let rowsCanFit = max(2, Int((availableHeight + verticalSpacing) / (cardHeight + verticalSpacing)))
        
        // Calculate total cards that can fit
        let totalCardsCanFit = rowsCanFit * gridColumns.count
        
        return totalCardsCanFit
    }
    
    // Delete button overlay for edit mode
    private func deleteButton(for scan: PosterScan) -> some View {
        Button(action: {
            withAnimation {
                dataStore.deleteScan(at: IndexSet(integer: dataStore.savedScans.firstIndex(where: { $0.id == scan.id }) ?? 0))
            }
        }) {
            Image(systemName: "minus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.red)
                .background(Circle().fill(Color.white))
                .padding(8)
        }
    }
}

// Preview provider
// Floating animation modifier
struct FloatingAnimation: ViewModifier {
    let duration: Double
    let offset: CGFloat
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .offset(y: isAnimating ? -offset/2 : offset/2)
            .animation(
                Animation.easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// Parallax effect for cards based on scroll position
struct ParallaxCard: ViewModifier {
    let scrollOffset: CGFloat
    let itemIndex: Int
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(calculateRotation()),
                axis: (x: 0.3, y: 0.3, z: 0),
                anchor: .center,
                anchorZ: 0,
                perspective: 0.5
            )
            .scaleEffect(calculateScale())
            .zIndex(calculateScale() * 10)  // Bring to front when hovering
    }
    
    // Calculate rotation based on scroll position and item index
    private func calculateRotation() -> Double {
        // Get an offset specific to this item's position
        let itemOffset = Double(scrollOffset / 100) + Double(itemIndex % 3)
        
        // Create a small rotation (-1.5 to 1.5 degrees) based on scroll
        return sin(itemOffset) * 1.5
    }
    
    // Calculate scale based on scroll position
    private func calculateScale() -> Double {
        // Get an offset specific to this item
        let itemOffset = Double(scrollOffset / 200) + Double(itemIndex % 4) * 0.25
        
        // Base scale
        let baseScale = 1.0
        
        // Add a small variation based on sin wave (between 0.98 and 1.02)
        return baseScale + sin(itemOffset) * 0.02
    }
}

// Pressable button style with animation
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? 0.1 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct ImprovedHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        ImprovedHistoryView()
            .environmentObject(DataStore())
    }
}
