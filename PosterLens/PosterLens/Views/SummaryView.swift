import SwiftUI

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
    @State private var isGeneratingQuestions = false
    @State private var showingQuestions = false
    @State private var questions: [String]?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var scanSaved = false
    
    init(scan: PosterScan) {
        self.scan = scan
        _questions = State(initialValue: scan.authorQuestions)
        _showingQuestions = State(initialValue: scan.authorQuestions != nil)
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
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 4)
                
                Text("Summary")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .padding(.top, 8)
                
                // Process summary points to extract headings and content
                ForEach(processedSummaryPoints(), id: \.title) { point in
                    SummaryCardView(title: point.title, content: point.content)
                }
                
                // Questions Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Questions for Author")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if isGeneratingQuestions {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        
                        Button(action: {
                            if questions == nil {
                                generateQuestions()
                            } else {
                                showingQuestions.toggle()
                            }
                        }) {
                            Text(questions == nil ? "Generate" : (showingQuestions ? "Hide" : "Show"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .disabled(isGeneratingQuestions)
                    }
                    
                    if showingQuestions, let questions = questions {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(processedQuestions(questions).enumerated()), id: \.element.content) { index, processedQuestion in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Circle().fill(Color.blue))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        if !processedQuestion.title.isEmpty {
                                            Text(processedQuestion.title)
                                                .font(.subheadline)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                        }
                                        
                                        Text(processedQuestion.content)
                                            .font(.subheadline)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .padding(.vertical, 8)
                
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
    
    // Process questions to extract headings and content
    private func processedQuestions(_ questions: [String]) -> [(title: String, content: String)] {
        return questions.map { question in
            // Check if the question contains a heading (text between ** markers)
            if let range = question.range(of: "\\*\\*(.*?)\\*\\*", options: .regularExpression) {
                let heading = String(question[range])
                    .replacingOccurrences(of: "**", with: "")
                
                // Get the content after the heading
                let startIndex = question.index(range.upperBound, offsetBy: 0)
                let content = String(question[startIndex...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ":", with: "", options: .anchored)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                return (title: heading, content: content)
            } else {
                // If no heading is found, use the entire question as content with no title
                return (title: "", content: question)
            }
        }
    }
    
    private func generateQuestions() {
        isGeneratingQuestions = true
        
        let perplexityService = PerplexityService()
        perplexityService.generateAuthorQuestions(from: scan.summaryPoints, rawText: scan.rawText) { result in
            DispatchQueue.main.async {
                isGeneratingQuestions = false
                
                switch result {
                case .success(let generatedQuestions):
                    self.questions = generatedQuestions
                    self.showingQuestions = true
                    
                    // Update the scan with the new questions
                    let updatedScan = scan.withQuestions(generatedQuestions)
                    dataStore.saveScan(updatedScan)
                    
                case .failure(let error):
                    self.errorMessage = "Failed to generate questions: \(error.localizedDescription)"
                    self.showingError = true
                }
            }
        }
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
