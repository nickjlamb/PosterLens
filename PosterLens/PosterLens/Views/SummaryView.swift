import SwiftUI
import Foundation

struct SummaryCardView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Color.primary)
                .padding(.bottom, 4)
            
            Text(content)
                .font(.body)
                .foregroundColor(Color.primary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

struct SummaryView: View {
    let scan: PosterScan
    @EnvironmentObject private var dataStore: DataStore
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var scanSaved = false
    
    init(scan: PosterScan) {
        self.scan = scan
    }
    
    @Environment(\.presentationMode) private var presentationMode
    @State private var showCamera = false
    @State private var showHistory = false
    @State private var showChat = false
    @State private var showCategories = false
    @State private var showImageViewer = false
    @State private var showNotesEditor = false
    @State private var showTitleEditor = false
    @State private var titleDraft = ""
    @State private var isGeneratingCategories = false
    @State private var categoryGenMessage: String? = nil
    @State private var isGeneratingSummary = false
    @State private var summaryGenFailed = false
    @State private var showingShareSheet = false

    private let openAIService = OpenAIService()

    private var currentScan: PosterScan {
        dataStore.getScan(withID: scan.id) ?? scan
    }

    // A scan whose summary couldn't be generated (e.g. offline at capture time)
    private var summaryNeedsGeneration: Bool {
        let points = currentScan.summaryPoints
        if points.isEmpty { return true }
        return points.count == 1 && points[0].lowercased().contains("unable to generate summary")
    }

    // Retry card shown when a scan's summary couldn't be generated (offline at capture)
    private var summaryRetryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: summaryGenFailed ? "wifi.exclamationmark" : "doc.text.magnifyingglass")
                    .font(.title2)
                    .foregroundColor(summaryGenFailed ? .orange : DesignSystem.Colors.brandBlue)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Summary not generated yet")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(summaryGenFailed
                         ? "Still couldn't connect. Check your connection and try again."
                         : "Your scan is saved. It looks like the summary couldn't be generated — you may have been offline.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button(action: { generateSummary() }) {
                HStack(spacing: 8) {
                    if isGeneratingSummary {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text("Generating summary…")
                    } else {
                        Image(systemName: "arrow.clockwise")
                        Text("Generate summary")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(DesignSystem.Colors.brandBlue)
                .cornerRadius(12)
            }
            .disabled(isGeneratingSummary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .padding(.top, 8)
    }

    private func generateSummary() {
        guard !isGeneratingSummary else { return }
        HapticManager.shared.mediumImpact()
        isGeneratingSummary = true
        summaryGenFailed = false

        let target = currentScan
        openAIService.generateStructuredSummary(from: target.rawText) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let points):
                    var updated = target
                    updated.summaryPoints = points
                    dataStore.saveScan(updated)
                    isGeneratingSummary = false
                    HapticManager.shared.success()

                    // Now that we have a summary, extract categories too
                    CategoryExtractionService.shared.extractCategories(from: target.rawText, summary: points) { catResult in
                        if case .success(let categories) = catResult, !categories.isEmpty {
                            DispatchQueue.main.async {
                                var latest = dataStore.getScan(withID: target.id) ?? updated
                                latest.categories = categories
                                dataStore.saveScan(latest)
                            }
                        }
                    }
                case .failure:
                    isGeneratingSummary = false
                    summaryGenFailed = true
                    HapticManager.shared.error()
                }
            }
        }
    }

    // Generate-categories action shown when a poster has no research categories yet
    private var generateCategoriesButton: some View {
        Button(action: { generateCategories() }) {
            HStack(spacing: 10) {
                if isGeneratingCategories {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating categories…")
                        .font(.headline)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "sparkles")
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.brandBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Generate research categories")
                            .font(.headline)
                            .foregroundColor(.primary)
                        if let message = categoryGenMessage {
                            Text(message)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isGeneratingCategories)
    }

    private func generateCategories() {
        guard !isGeneratingCategories else { return }
        HapticManager.shared.mediumImpact()
        isGeneratingCategories = true
        categoryGenMessage = nil

        let target = currentScan
        CategoryExtractionService.shared.extractCategories(from: target.rawText, summary: target.summaryPoints) { result in
            DispatchQueue.main.async {
                isGeneratingCategories = false
                switch result {
                case .success(let categories):
                    if categories.isEmpty {
                        categoryGenMessage = "No research categories found for this poster."
                    } else {
                        var updated = target
                        updated.categories = categories
                        dataStore.saveScan(updated)
                        HapticManager.shared.success()
                    }
                case .failure:
                    categoryGenMessage = "Couldn't generate categories — tap to try again."
                }
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let image = scan.image {
                    Button(action: {
                        HapticManager.shared.mediumImpact()
                        showImageViewer = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)

                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(10)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .fullScreenCover(isPresented: $showImageViewer) {
                        PosterImageViewer(image: image)
                    }
                }
                
                Button(action: {
                    titleDraft = currentScan.title
                    showTitleEditor = true
                }) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(currentScan.title)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)

                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.brandBlue)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.bottom, 8)
                .padding(.horizontal)
                .alert("Edit Title", isPresented: $showTitleEditor) {
                    TextField("Poster title", text: $titleDraft)
                    Button("Cancel", role: .cancel) {}
                    Button("Save") {
                        let trimmed = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        var updated = currentScan
                        updated.title = trimmed
                        dataStore.saveScan(updated)
                    }
                } message: {
                    Text("Fix the title if it was read incorrectly.")
                }

                if summaryNeedsGeneration {
                    summaryRetryCard
                } else {
                Text("Summary")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.top, 8)

                // Category tags with tap to see all
                if let categories = currentScan.categories, !categories.isEmpty {
                    Button(action: {
                        HapticManager.shared.mediumImpact()
                        showCategories = true
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Research Categories")
                                    .font(.headline)
                                    .foregroundColor(.primary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            CategoryTagRow(categories: categories, maxVisible: 4, compact: false)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    generateCategoriesButton
                }

                // Process summary points to extract headings and content
                ForEach(processedSummaryPoints(), id: \.title) { point in
                    SummaryCardView(title: point.title, content: point.content)
                }
                }

                NotesCard(
                    notes: currentScan.userNotes,
                    onTap: {
                        HapticManager.shared.mediumImpact()
                        showNotesEditor = true
                    },
                    onDelete: {
                        var updated = currentScan
                        updated.userNotes = nil
                        dataStore.saveScan(updated)
                    }
                )

                // Add ButtonRowView for the three interactive buttons
                ButtonRowView(scan: scan)
                
                // Original Text section removed as it's not useful for users
                
                // Add action buttons row - Only navigation buttons
                VStack(spacing: 16) {
                    Divider()
                        .padding(.vertical, 8)
                    
                    HStack(spacing: 16) {
                        // Scan Another Button
                        Button(action: {
                            HapticManager.shared.mediumImpact()
                            showCamera = true
                            // Dismiss this view to avoid a deep navigation stack
                            presentationMode.wrappedValue.dismiss()
                            
                            // Post notification to show camera
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                NotificationCenter.default.post(name: NSNotification.Name("ShowCamera"), object: nil)
                            }
                        }) {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                    .font(.headline)
                                Text("Scan Another")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(DesignSystem.Colors.brandBlue)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        
                        // View Scanned Posters Button
                        Button(action: {
                            HapticManager.shared.mediumImpact()
                            showHistory = true
                        }) {
                            HStack {
                                Image(systemName: "list.bullet")
                                    .font(.headline)
                                Text("View All Scans")
                                    .font(.headline)
                            }
                            .foregroundColor(DesignSystem.Colors.brandBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(DesignSystem.Colors.brandBlue, lineWidth: 2)
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Poster Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    HapticManager.shared.mediumImpact()
                    showingShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share this poster")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            Group {
                if let pdfURLs = dataStore.exportScansAsPDF(withIDs: [currentScan.id]), !pdfURLs.isEmpty {
                    CustomShareSheet(items: pdfURLs)
                } else {
                    let text = "Poster: \(currentScan.title)\n\nSummary:\n" + currentScan.summaryPoints.joined(separator: "\n\n")
                    CustomShareSheet(items: [text])
                }
            }
            .presentationDetents([.large])
            .ignoresSafeArea()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Always save the scan to history when the view appears
            if !scanSaved {
                dataStore.saveScan(scan)
                scanSaved = true
            }
        }
        .sheet(isPresented: $showNotesEditor) {
            NotesEditorSheet(initialNotes: currentScan.userNotes ?? "") { newNotes in
                var updated = currentScan
                updated.userNotes = newNotes.isEmpty ? nil : newNotes
                dataStore.saveScan(updated)
            }
        }
        .sheet(isPresented: $showHistory) {
            NavigationView {
                ImprovedHistoryView()
                    .environmentObject(dataStore)
            }
        }
        .sheet(isPresented: $showChat) {
            NavigationView {
                SimpleChatView(posterScan: scan)
                    .environmentObject(dataStore)
            }
        }
        .sheet(isPresented: $showCategories) {
            CategoryDetailSheet(scan: currentScan)
        }
    }
    
    // Process summary points to extract headings and content with deduplication
    private func processedSummaryPoints() -> [(title: String, content: String)] {
        // First, deduplicate summary points based on content
        var uniquePoints = [String: String]() // content: title
        var result = [(title: String, content: String)]()
        
        for (index, point) in scan.summaryPoints.enumerated() {
            // Check if the point contains a heading (text between ** markers)
            if let range = point.range(of: "\\*\\*(.*?)\\*\\*", options: .regularExpression) {
                let heading = String(point[range])
                    .replacingOccurrences(of: "**", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Get the content after the heading
                let startIndex = point.index(range.upperBound, offsetBy: 0)
                var content = String(point[startIndex...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove leading colon if present - handle multiple colons
                while content.hasPrefix(":") {
                    content = String(content.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Remove trailing numbers that might be references
                if let trailingNumberRange = content.range(of: "\\s+\\d+\\.?$", options: .regularExpression) {
                    content = String(content[..<trailingNumberRange.lowerBound])
                }
                
                // Remove references like [1], [2, 3], etc. using more comprehensive pattern
                content = content.replacingOccurrences(of: "\\s*\\[\\d+(?:[-,]\\s*\\d+)*\\]\\s*", with: " ", options: .regularExpression)
                
                // Only add if this content hasn't been seen before
                if uniquePoints[content] == nil {
                    uniquePoints[content] = heading
                    result.append((title: heading, content: content))
                }
            } else {
                // If no heading is found, use a more specific title
                var content = point.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove leading colon if present - handle multiple colons
                while content.hasPrefix(":") {
                    content = String(content.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Remove trailing numbers that might be references
                if let trailingNumberRange = content.range(of: "\\s+\\d+\\.?$", options: .regularExpression) {
                    content = String(content[..<trailingNumberRange.lowerBound])
                }
                
                // Remove references like [1], [2, 3], etc. using more comprehensive pattern
                content = content.replacingOccurrences(of: "\\s*\\[\\d+(?:[-,]\\s*\\d+)*\\]\\s*", with: " ", options: .regularExpression)
                
                // Only add if this content hasn't been seen before
                if uniquePoints[content] == nil {
                    // Generate a more specific title based on content
                    let title = "Key Point \(index + 1)"
                    uniquePoints[content] = title
                    result.append((title: title, content: content))
                }
            }
        }
        
        return result
    }
    
}

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SummaryView(scan: PosterScan(
                title: "Example Poster",
                rawText: "This is the raw text of the poster.",
                summaryPoints: [
                    "**Main Research Question/Objective**: The poster focuses on the importance of molecular pathology in oncology.",
                    "**Patient Population**: Adult patients with advanced solid tumors (n=250), ages 18-75, ECOG performance status 0-2.",
                    "**Primary Endpoint**: Overall response rate (ORR) to targeted therapy based on molecular profiling.",
                    "**Methodology Used**: The methodology involves various testing modalities such as Next-Generation Sequencing.",
                    "**Key Results and Findings**: Key findings highlight the role of biomarkers in guiding therapy.",
                    "**Main Conclusions and Implications**: The conclusions emphasize the importance of integrating molecular testing."
                ],
                image: nil,
                date: Date(),
                authorQuestions: [
                    "**Limitations**: What are the limitations of this approach?",
                    "**Future Work**: How do you plan to extend this research?"
                ]
            ))
            .environmentObject(DataStore())
        }
    }
}
