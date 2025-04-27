import SwiftUI

struct ContextButton: View {
    let title: String
    let iconName: String
    let action: () -> Void
    let gradient: LinearGradient
    
    init(title: String, iconName: String, action: @escaping () -> Void) {
        self.title = title
        self.iconName = iconName
        self.action = action
        
        // Use different gradients based on button title
        switch title {
        case "What to Ask":
            self.gradient = LinearGradient(
                colors: [Color.purple, Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "Where it's Heading":
            self.gradient = LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "What to Read Next":
            self.gradient = LinearGradient(
                colors: [Color.indigo, Color.indigo.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            self.gradient = LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Icon in a gradient circle
                ZStack {
                    Circle()
                        .fill(gradient)
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 24))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                // Title text
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ButtonRowView: View {
    let scan: PosterScan
    @EnvironmentObject private var dataStore: DataStore
    @State private var showQuestionsView: Bool = false
    @State private var showDirectionsView: Bool = false
    @State private var showLiteratureView: Bool = false
    @State private var isGeneratingQuestions: Bool = false
    @State private var isGeneratingDirections: Bool = false
    @State private var isGeneratingLiterature: Bool = false
    @State private var questions: [String]?
    @State private var directions: [String]?
    @State private var citations: [Citation]?
    @State private var showingError: Bool = false
    @State private var errorMessage: String = ""
    
    // Service for API calls
    private let perplexityService = PerplexityService()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Explore Further")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                ContextButton(
                    title: "What to Ask",
                    iconName: "questionmark.circle",
                    action: {
                        if scan.authorQuestions != nil {
                            showQuestionsView = true
                        } else {
                            generateQuestions()
                        }
                    }
                )
                .overlay(
                    Group {
                        if isGeneratingQuestions {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding(8)
                                .background(Color(.systemBackground).opacity(0.8))
                                .cornerRadius(8)
                        }
                    }
                )
                
                ContextButton(
                    title: "Where it's Heading",
                    iconName: "arrow.up.forward.circle",
                    action: {
                        if scan.researchContext?.futureDirections != nil {
                            showDirectionsView = true
                        } else {
                            generateFutureDirections()
                        }
                    }
                )
                .overlay(
                    Group {
                        if isGeneratingDirections {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding(8)
                                .background(Color(.systemBackground).opacity(0.8))
                                .cornerRadius(8)
                        }
                    }
                )
                
                ContextButton(
                    title: "What to Read Next",
                    iconName: "book.fill",
                    action: {
                        if scan.researchContext?.literatureContext != nil {
                            showLiteratureView = true
                        } else {
                            generateLiteratureCitations()
                        }
                    }
                )
                .overlay(
                    Group {
                        if isGeneratingLiterature {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding(8)
                                .background(Color(.systemBackground).opacity(0.8))
                                .cornerRadius(8)
                        }
                    }
                )
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
        .padding(.vertical, 8)
        .sheet(isPresented: $showQuestionsView) {
            NavigationView {
                if let questions = scan.authorQuestions ?? self.questions {
                    QuestionListView(questions: questions)
                        .navigationTitle("Questions to Ask")
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    Text("Generating questions... Please wait or try again.")
                        .padding()
                        .multilineTextAlignment(.center)
                        .navigationTitle("Questions to Ask")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .sheet(isPresented: $showDirectionsView) {
            NavigationView {
                if let directions = scan.researchContext?.futureDirections ?? self.directions {
                    ResearchContextView(
                        futureDirections: .constant(directions),
                        onGenerateDirections: {}
                    )
                    .navigationTitle("Research Directions")
                    .navigationBarTitleDisplayMode(.inline)
                    .padding()
                } else {
                    Text("Generating research directions... Please wait or try again.")
                        .padding()
                        .multilineTextAlignment(.center)
                        .navigationTitle("Research Directions")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .sheet(isPresented: $showLiteratureView) {
            NavigationView {
                if let citations = scan.researchContext?.literatureContext ?? self.citations {
                    LiteratureContextView(
                        citations: .constant(citations),
                        onGenerateCitations: {}
                    )
                    .navigationTitle("Literature Context")
                    .navigationBarTitleDisplayMode(.inline)
                    .padding()
                } else {
                    Text("Generating literature context... Please wait or try again.")
                        .padding()
                        .multilineTextAlignment(.center)
                        .navigationTitle("Literature Context")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // Generate author questions
    private func generateQuestions() {
        isGeneratingQuestions = true
        
        // Use the PerplexityService to generate questions
        perplexityService.generateAuthorQuestions(from: scan.summaryPoints, rawText: scan.rawText) { result in
            DispatchQueue.main.async {
                isGeneratingQuestions = false
                
                switch result {
                case .success(let generatedQuestions):
                    self.questions = generatedQuestions
                    showQuestionsView = true
                    
                    // Update the scan with the new questions
                    let updatedScan = scan.withQuestions(generatedQuestions)
                    dataStore.saveScan(updatedScan)
                    
                case .failure(let error):
                    errorMessage = "Failed to generate questions: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    // Generate future research directions
    private func generateFutureDirections() {
        isGeneratingDirections = true
        
        perplexityService.generateFutureDirections(from: scan.summaryPoints, rawText: scan.rawText) { result in
            DispatchQueue.main.async {
                isGeneratingDirections = false
                
                switch result {
                case .success(let generatedDirections):
                    self.directions = generatedDirections
                    showDirectionsView = true
                    
                    // Update the scan with the new directions
                    var updatedResearchContext = scan.researchContext ?? ResearchContext()
                    updatedResearchContext = ResearchContext(
                        futureDirections: generatedDirections,
                        literatureContext: updatedResearchContext.literatureContext
                    )
                    
                    var updatedScan = scan
                    updatedScan.researchContext = updatedResearchContext
                    dataStore.saveScan(updatedScan)
                    
                case .failure(let error):
                    errorMessage = "Failed to generate research directions: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    // Generate literature citations
    private func generateLiteratureCitations() {
        isGeneratingLiterature = true
        
        perplexityService.generateLiteratureCitations(from: scan.summaryPoints, rawText: scan.rawText) { result in
            DispatchQueue.main.async {
                isGeneratingLiterature = false
                
                switch result {
                case .success(let generatedCitations):
                    self.citations = generatedCitations
                    showLiteratureView = true
                    
                    // Update the scan with the new citations
                    var updatedResearchContext = scan.researchContext ?? ResearchContext()
                    updatedResearchContext = ResearchContext(
                        futureDirections: updatedResearchContext.futureDirections,
                        literatureContext: generatedCitations
                    )
                    
                    var updatedScan = scan
                    updatedScan.researchContext = updatedResearchContext
                    dataStore.saveScan(updatedScan)
                    
                case .failure(let error):
                    errorMessage = "Failed to generate literature citations: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
}

struct QuestionListView: View {
    let questions: [String]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(processedQuestions().enumerated()), id: \.element.content) { index, processedQuestion in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.purple))
                        
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
            .padding()
        }
    }
    
    // Process questions to extract headings and content
    private func processedQuestions() -> [(title: String, content: String)] {
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
}

struct ButtonRowView_Previews: PreviewProvider {
    static var previews: some View {
        ButtonRowView(scan: PosterScan(
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
            ],
            researchContext: ResearchContext(
                futureDirections: [
                    "**Integration with Clinical Data**: Future work should focus on integrating molecular findings with clinical data."
                ],
                literatureContext: [
                    Citation(
                        title: "The Role of Molecular Pathology in Cancer Diagnosis",
                        authors: ["Smith J", "Johnson A"],
                        journal: "Journal of Oncology",
                        year: 2022,
                        doi: "10.1000/xyz123",
                        url: "https://example.com",
                        abstract: "This review discusses the importance of molecular pathology in cancer diagnosis and treatment planning.",
                        relevance: "Directly related to the poster's focus on molecular pathology in oncology."
                    )
                ]
            )
        ))
        .padding()
        .previewLayout(.sizeThatFits)
    }
}