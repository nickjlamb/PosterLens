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
        
        // Use different gradients based on button title/function
        switch title {
        case "Questions to Ask", "What to Ask the Author":
            self.gradient = LinearGradient(
                colors: [Color.purple, Color.purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "Research Directions", "Where it's Heading":
            self.gradient = LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "Chat with AI":
            self.gradient = LinearGradient(
                colors: [DesignSystem.Colors.brandBlue, DesignSystem.Colors.brandBlueDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "Related Research":
            self.gradient = LinearGradient(
                colors: [Color.green, Color.green.opacity(0.6)],
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
            VStack(spacing: 8) {
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
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .lineLimit(2) // Allow up to 2 lines
                    .fixedSize(horizontal: false, vertical: true) // Allow text to wrap naturally
                    .frame(maxWidth: .infinity, alignment: .center) // Center the text
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120) // Increased height for all buttons
            .frame(minWidth: 0, maxWidth: .infinity) // Ensure equal width distribution
            .padding(.vertical, 10)
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
    @State private var showChatView: Bool = false
    @State private var showOpenAIChatView: Bool = false  // New state for OpenAI chat view
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
            
            // Four columns of context buttons
            VStack(spacing: 8) {
                // First row of buttons
                HStack(spacing: 8) {
                    // First button: What to Ask the Author
                    ContextButton(
                        title: "Questions to Ask",
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
                    
                    // Second button: Research Directions
                    ContextButton(
                        title: "Research Directions",
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
                
                // Second row - single button
                HStack(spacing: 8) {
                    // Chat with AI (OpenAI)
                    ContextButton(
                        title: "Chat with AI",
                        iconName: "bubble.left.and.bubble.right.fill",
                        action: {
                            showOpenAIChatView = true
                        }
                    )
                }
            }
            .frame(maxWidth: .infinity) // Ensure HStack takes full width
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
        .navigationDestination(isPresented: $showChatView) {
            SimpleChatView(posterScan: scan)
                .environmentObject(dataStore)
        }
        .navigationDestination(isPresented: $showOpenAIChatView) {
            OpenAIChatView(posterScan: scan)
                .environmentObject(dataStore)
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
                    
                    // Update the scan with the new directions without creating a new object
                    var updatedScan = scan
                    
                    // Create or update research context
                    if updatedScan.researchContext == nil {
                        updatedScan.researchContext = ResearchContext()
                    }
                    
                    // Update the future directions
                    updatedScan.researchContext?.futureDirections = generatedDirections
                    
                    // Save the updated scan using the original ID
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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Introduction text
                Text("Based on this poster, here are some suggested questions you might want to ask the presenter:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .slideUpOnAppear(delay: 0.1)
                
                // Display all questions in a list format
                ForEach(Array(processedQuestions().enumerated()), id: \.element.content) { index, processedQuestion in
                    BulletPointView(
                        index: index + 1,
                        title: processedQuestion.title,
                        content: processedQuestion.content,
                        color: .purple
                    )
                    .slideUpOnAppear(delay: Double(index) * 0.05 + 0.2)
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
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Get the content after the heading
                let startIndex = question.index(range.upperBound, offsetBy: 0)
                var content = String(question[startIndex...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove leading colon if present - handle multiple colons
                while content.hasPrefix(":") {
                    content = String(content.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Remove any leading numbers (e.g., "1. ", "2. ")
                if let numberRange = content.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                    content = String(content[numberRange.upperBound...])
                }
                
                // Remove trailing numbers that might be references
                if let trailingNumberRange = content.range(of: "\\s+\\d+\\.?$", options: .regularExpression) {
                    content = String(content[..<trailingNumberRange.lowerBound])
                }
                
                // Remove references like [1], [2, 3], etc. using more comprehensive pattern
                content = content.replacingOccurrences(of: "\\s*\\[\\d+(?:[-,]\\s*\\d+)*\\]\\s*", with: " ", options: .regularExpression)
                
                return (title: heading, content: content)
            } else {
                // If no heading is found, remove any numbering and use as content
                var content = question.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove leading colon if present - handle multiple colons
                while content.hasPrefix(":") {
                    content = String(content.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Remove any leading numbers (e.g., "1. ", "2. ")
                if let numberRange = content.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                    content = String(content[numberRange.upperBound...])
                }
                
                // Remove trailing numbers that might be references
                if let trailingNumberRange = content.range(of: "\\s+\\d+\\.?$", options: .regularExpression) {
                    content = String(content[..<trailingNumberRange.lowerBound])
                }
                
                // Remove references like [1], [2, 3], etc. using more comprehensive pattern
                content = content.replacingOccurrences(of: "\\s*\\[\\d+(?:[-,]\\s*\\d+)*\\]\\s*", with: " ", options: .regularExpression)
                
                return (title: "", content: content)
            }
        }
    }
}

// Reusable component for displaying bullet points
struct BulletPointView: View {
    let index: Int
    let title: String
    let content: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title row with bullet point marker
            HStack(alignment: .top, spacing: 10) {
                // Number bullet
                Text("\(index)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(color))
                
                VStack(alignment: .leading, spacing: 4) {
                    // Title (if present)
                    if !title.isEmpty {
                        Text(title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    // Main content text
                    Text(content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.07), radius: 3, x: 0, y: 2)
        )
    }
}

// Create a new view for displaying research directions with a consistent design
struct ResearchDirectionsView: View {
    let directions: [String]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Introduction text
                Text("This research could lead to the following directions and developments:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .slideUpOnAppear(delay: 0.1)
                
                // Display all directions in a list format
                ForEach(Array(processedDirections().enumerated()), id: \.element.content) { index, processedDirection in
                    BulletPointView(
                        index: index + 1,
                        title: processedDirection.title,
                        content: processedDirection.content,
                        color: .blue
                    )
                    .slideUpOnAppear(delay: Double(index) * 0.05 + 0.2)
                }
            }
            .padding()
        }
    }
    
    // Process directions to extract headings and content
    private func processedDirections() -> [(title: String, content: String)] {
        return directions.map { direction in
            // Check if the direction contains a heading (text between ** markers)
            if let range = direction.range(of: "\\*\\*(.*?)\\*\\*", options: .regularExpression) {
                let heading = String(direction[range])
                    .replacingOccurrences(of: "**", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Get the content after the heading
                let startIndex = direction.index(range.upperBound, offsetBy: 0)
                var content = String(direction[startIndex...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove leading colon if present - handle multiple colons
                while content.hasPrefix(":") {
                    content = String(content.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Remove any leading numbers (e.g., "1. ", "2. ")
                if let numberRange = content.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                    content = String(content[numberRange.upperBound...])
                }
                
                // Remove trailing numbers that might be references
                if let trailingNumberRange = content.range(of: "\\s+\\d+\\.?$", options: .regularExpression) {
                    content = String(content[..<trailingNumberRange.lowerBound])
                }
                
                // Remove references like [1], [2, 3], etc. using more comprehensive pattern
                content = content.replacingOccurrences(of: "\\s*\\[\\d+(?:[-,]\\s*\\d+)*\\]\\s*", with: " ", options: .regularExpression)
                
                return (title: heading, content: content)
            } else {
                // If no heading is found, remove any numbering and use as content
                var content = direction.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove leading colon if present - handle multiple colons
                while content.hasPrefix(":") {
                    content = String(content.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Remove any leading numbers (e.g., "1. ", "2. ")
                if let numberRange = content.range(of: "^\\d+\\.\\s+", options: .regularExpression) {
                    content = String(content[numberRange.upperBound...])
                }
                
                // Remove trailing numbers that might be references
                if let trailingNumberRange = content.range(of: "\\s+\\d+\\.?$", options: .regularExpression) {
                    content = String(content[..<trailingNumberRange.lowerBound])
                }
                
                // Remove references like [1], [2, 3], etc. using more comprehensive pattern
                content = content.replacingOccurrences(of: "\\s*\\[\\d+(?:[-,]\\s*\\d+)*\\]\\s*", with: " ", options: .regularExpression)
                
                return (title: "", content: content)
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
                literatureContext: nil
            )
        ))
        .padding()
        .previewLayout(.sizeThatFits)
        .environmentObject(DataStore())
    }
}