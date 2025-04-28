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
                
                if !scan.rawText.isEmpty {
                    DisclosureGroup {
                        Text(scan.rawText)
                            .font(.body)
                            .padding(.vertical)
                    } label: {
                        Text("Original Text")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
                    )
                }
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
                
                // Get the content after the heading
                let startIndex = point.index(range.upperBound, offsetBy: 0)
                let content = String(point[startIndex...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ":", with: "", options: .anchored)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Only add if this content hasn't been seen before
                if uniquePoints[content] == nil {
                    uniquePoints[content] = heading
                    result.append((title: heading, content: content))
                }
            } else {
                // If no heading is found, use a more specific title
                let content = point.trimmingCharacters(in: .whitespacesAndNewlines)
                
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
