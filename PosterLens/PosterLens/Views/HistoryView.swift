import SwiftUI

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
    @State private var gridColumns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
    @State private var isEditMode: EditMode = .inactive
    @State private var viewHeight: CGFloat = 0
    
    // Selection mode states
    @State private var isSelectionMode = false
    @State private var selectedScanIDs = Set<UUID>()
    @State private var showingBatchDeleteAlert = false
    @State private var showingExportOptions = false
    
    // Binding to the selected tab in ContentView
    var selectedTab: Binding<Int>?
    
    // Initialize with optional binding to selectedTab
    init(selectedTab: Binding<Int>? = nil) {
        self.selectedTab = selectedTab
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    ScrollView {
                        if dataStore.savedScans.isEmpty {
                            emptyStateView
                        } else {
                            gridView
                        }
                    }
                    .onAppear {
                        // Store the view height for placeholder calculations
                        viewHeight = geometry.size.height
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
            .navigationTitle(isSelectionMode ? "\(selectedScanIDs.count) Selected" : "Scan History")
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
                    HStack {
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
                                    // Toggle between 2 and 3 columns
                                    withAnimation {
                                        gridColumns = gridColumns.count == 2 ?
                                            Array(repeating: GridItem(.flexible(), spacing: 12), count: 3) :
                                            Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
                                    }
                                }) {
                                    Label(
                                        gridColumns.count == 2 ? "Three Columns" : "Two Columns",
                                        systemImage: gridColumns.count == 2 ? "square.grid.3x2" : "square.grid.2x2"
                                    )
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
                                
                                Button(role: .destructive, action: {
                                    showingDeleteAlert = true
                                }) {
                                    Label("Clear All", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
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
                showingExportOptions = true
            }) {
                VStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22))
                    Text("Export")
                        .font(.caption)
                }
            }
            
            // Delete button
            Button(action: {
                showingBatchDeleteAlert = true
            }) {
                VStack {
                    Image(systemName: "trash")
                        .font(.system(size: 22))
                    Text("Delete")
                        .font(.caption)
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            Rectangle()
                .fill(Material.regularMaterial)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: -2)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // Grid view for displaying scans
    private var gridView: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(dataStore.savedScans.sorted(by: { $0.date > $1.date })) { scan in
                if isEditMode.isEditing && !isSelectionMode {
                    // Edit mode for deletion (original functionality)
                    ScanCardView(scan: scan)
                        .overlay(
                            deleteButton(for: scan),
                            alignment: .topTrailing
                        )
                } else {
                    // Normal mode or selection mode
                    ScanCardView(
                        scan: scan,
                        isSelectionMode: isSelectionMode,
                        isSelected: selectedScanIDs.contains(scan.id),
                        onSelect: { isSelected in
                            handleSelection(scan: scan, isSelected: isSelected)
                        }
                    )
                }
            }
            
            // Add placeholders to fill the screen
            ForEach(0..<calculatePlaceholderCount(), id: \.self) { index in
                PlaceholderCardView(onTap: {
                    // Switch to camera tab when placeholder is tapped
                    selectedTab?.wrappedValue = 0
                })
            }
        }
        .padding()
        .animation(.default, value: dataStore.savedScans.count)
        .animation(.default, value: selectedScanIDs.count)
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
            
            Image(systemName: "doc.text.image")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.7))
            
            Text("No Scans Yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Tap the camera tab to scan your first scientific poster")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                // Switch to camera tab
                selectedTab?.wrappedValue = 0
            }) {
                Text("Scan a Poster")
                    .fontWeight(.medium)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 10)
            
            Spacer()
            
            // Visual guide for where scans will appear - fill the screen with placeholders
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(0..<calculateEmptyStatePlaceholderCount(), id: \.self) { _ in
                    PlaceholderCardView(onTap: {
                        // Switch to camera tab when placeholder is tapped
                        selectedTab?.wrappedValue = 0
                    })
                    .opacity(0.5)
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
struct ImprovedHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        ImprovedHistoryView()
            .environmentObject(DataStore())
    }
}
