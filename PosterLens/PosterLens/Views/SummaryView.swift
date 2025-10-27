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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let image = scan.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                }
                
                Text(scan.title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
                    .padding(.horizontal)
                
                Text("Summary")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.top, 8)

                // Process summary points to extract headings and content
                ForEach(processedSummaryPoints(), id: \.title) { point in
                    SummaryCardView(title: point.title, content: point.content)
                }
                
                
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
