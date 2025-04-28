import SwiftUI

struct ContextButton: View {
    let title: String
    let iconName: String
    let action: () -> Void
    let gradient: LinearGradient
    @State private var isPressed: Bool = false
    @State private var isAnimating: Bool = false
    
    init(title: String, iconName: String, action: @escaping () -> Void) {
        self.title = title
        self.iconName = iconName
        self.action = action
        
        // Use different gradients based on button title
        switch title {
        case "What to Ask the Author":
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
        default:
            self.gradient = LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var body: some View {
        Button(action: {
            // Trigger haptic feedback
            if title == "What to Ask the Author" {
                HapticManager.shared.mediumImpact()
            } else {
                HapticManager.shared.selection()
            }
            
            // Trigger animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            // Reset after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    isPressed = false
                }
                // Call the actual action
                action()
            }
        }) {
            VStack(spacing: 12) {
                // Icon in a gradient circle
                ZStack {
                    Circle()
                        .fill(gradient)
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.black.opacity(isPressed ? 0.05 : 0.15), 
                                radius: isPressed ? 2 : 4, 
                                x: 0, 
                                y: isPressed ? 1 : 2)
                        .scaleEffect(isPressed ? 0.95 : 1.0)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 24))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                        .rotationEffect(isAnimating ? Angle(degrees: 5) : Angle(degrees: 0))
                        .animation(
                            Animation.easeInOut(duration: 0.2)
                                .repeatCount(1, autoreverses: true),
                            value: isAnimating
                        )
                        .onAppear {
                            // Small wiggle animation to attract attention
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isAnimating = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    isAnimating = false
                                }
                            }
                        }
                }
                .pulseEffect(enabled: !isPressed, duration: 2.0)
                
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
                    .shadow(color: Color.black.opacity(isPressed ? 0.03 : 0.08), 
                            radius: isPressed ? 2 : 3, 
                            x: 0, 
                            y: isPressed ? 0 : 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle()) // Use plain button style since we're handling animations manually
    }
}

struct ButtonRowView: View {
    let scan: PosterScan
    @EnvironmentObject private var dataStore: DataStore
    @State private var showQuestionsView: Bool = false
    @State private var showDirectionsView: Bool = false
    @State private var isGeneratingQuestions: Bool = false
    @State private var isGeneratingDirections: Bool = false
    @State private var questions: [String]?
    @State private var directions: [String]?
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
                    title: "What to Ask the Author",
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
                        .navigationTitle("Questions to Ask the Author")
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    Text("Generating questions... Please wait or try again.")
                        .padding()
                        .multilineTextAlignment(.center)
                        .navigationTitle("Questions to Ask the Author")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .sheet(isPresented: $showDirectionsView) {
            NavigationView {
                if let directions = scan.researchContext?.futureDirections ?? self.directions {
                    ResearchDirectionsView(directions: directions)
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
                    
                    // Provide success haptic feedback
                    HapticManager.shared.success()
                    
                    // Update the scan with the new questions
                    let updatedScan = scan.withQuestions(generatedQuestions)
                    dataStore.saveScan(updatedScan)
                    
                case .failure(let error):
                    errorMessage = "Failed to generate questions: \(error.localizedDescription)"
                    showingError = true
                    
                    // Provide error haptic feedback
                    HapticManager.shared.error()
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
                    
                    // Provide success haptic feedback
                    HapticManager.shared.success()
                    
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
                    
                    // Provide error haptic feedback
                    HapticManager.shared.error()
                }
            }
        }
    }
}

struct QuestionListView: View {
    let questions: [String]
    @State private var selectedQuestion: Int? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(processedQuestions().enumerated()), id: \.element.content) { index, processedQuestion in
                    QuestionCardView(
                        index: index + 1,
                        question: processedQuestion,
                        isSelected: selectedQuestion == index,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedQuestion == index {
                                    selectedQuestion = nil
                                } else {
                                    // Provide haptic feedback on selection
                                    HapticManager.shared.selection()
                                    selectedQuestion = index
                                }
                            }
                        }
                    )
                    .slideUpOnAppear(delay: Double(index) * 0.1)
                }
            }
            .padding()
        }
        .onAppear {
            // Auto-select the first question after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    selectedQuestion = 0
                }
            }
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
                var content = String(question[startIndex...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ":", with: "", options: .anchored)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove any leading numbers (e.g., "1. ", "2. ")
                if let numberRange = content.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                    content = String(content[numberRange.upperBound...])
                }
                
                return (title: heading, content: content)
            } else {
                // If no heading is found, remove any numbering and use as content
                var content = question.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove any leading numbers (e.g., "1. ", "2. ")
                if let numberRange = content.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                    content = String(content[numberRange.upperBound...])
                }
                
                return (title: "", content: content)
            }
        }
    }
}

struct QuestionCardView: View {
    let index: Int
    let question: (title: String, content: String)
    let isSelected: Bool
    let onTap: () -> Void
    
    private var gradient: LinearGradient {
        LinearGradient(
            colors: [Color.purple, Color.purple.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with number and title
            HStack(alignment: .center, spacing: 12) {
                Text("\(index)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(gradient))
                    .shadow(color: Color.purple.opacity(0.3), radius: 2, x: 0, y: 1)
                
                if !question.title.isEmpty {
                    Text(question.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                    )
                    .rotationEffect(isSelected ? Angle(degrees: 0) : Angle(degrees: 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            
            // Content
            if isSelected {
                Text(question.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.08), 
                        radius: isSelected ? 6 : 4, 
                        x: 0, 
                        y: isSelected ? 3 : 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
}

// Create a new view for displaying research directions with a similar card-based UI
struct ResearchDirectionsView: View {
    let directions: [String]
    @State private var selectedDirection: Int? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(processedDirections().enumerated()), id: \.element.content) { index, processedDirection in
                    DirectionCardView(
                        index: index + 1,
                        direction: processedDirection,
                        isSelected: selectedDirection == index,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedDirection == index {
                                    selectedDirection = nil
                                } else {
                                    // Provide haptic feedback on selection
                                    HapticManager.shared.selection()
                                    selectedDirection = index
                                }
                            }
                        }
                    )
                    .slideUpOnAppear(delay: Double(index) * 0.1)
                }
            }
            .padding()
        }
        .onAppear {
            // Auto-select the first direction after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    selectedDirection = 0
                }
            }
        }
    }
    
    // Process directions to extract headings and content
    private func processedDirections() -> [(title: String, content: String)] {
        return directions.map { direction in
            // Check if the direction contains a heading (text between ** markers)
            if let range = direction.range(of: "\\*\\*(.*?)\\*\\*", options: .regularExpression) {
                let heading = String(direction[range])
                    .replacingOccurrences(of: "**", with: "")
                
                // Get the content after the heading
                let startIndex = direction.index(range.upperBound, offsetBy: 0)
                var content = String(direction[startIndex...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ":", with: "", options: .anchored)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove any leading numbers (e.g., "1. ", "2. ")
                if let numberRange = content.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                    content = String(content[numberRange.upperBound...])
                }
                
                return (title: heading, content: content)
            } else {
                // If no heading is found, remove any numbering and use as content
                var content = direction.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove any leading numbers (e.g., "1. ", "2. ")
                if let numberRange = content.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                    content = String(content[numberRange.upperBound...])
                }
                
                return (title: "", content: content)
            }
        }
    }
}

struct DirectionCardView: View {
    let index: Int
    let direction: (title: String, content: String)
    let isSelected: Bool
    let onTap: () -> Void
    
    private var gradient: LinearGradient {
        LinearGradient(
            colors: [Color.blue, Color.blue.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with number and title
            HStack(alignment: .center, spacing: 12) {
                Text("\(index)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(gradient))
                    .shadow(color: Color.blue.opacity(0.3), radius: 2, x: 0, y: 1)
                
                if !direction.title.isEmpty {
                    Text(direction.title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                    )
                    .rotationEffect(isSelected ? Angle(degrees: 0) : Angle(degrees: 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            
            // Content
            if isSelected {
                Text(direction.content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.08), 
                        radius: isSelected ? 6 : 4, 
                        x: 0, 
                        y: isSelected ? 3 : 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture {
            onTap()
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
                literatureContext: nil
            )
        ))
        .padding()
        .previewLayout(.sizeThatFits)
        .environmentObject(DataStore())
    }
}