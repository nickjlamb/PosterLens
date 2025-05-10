import SwiftUI

// DEBUG FLAG - This will help us verify if API is working
let isApiDebug = true

struct SimpleChatView: View {
    let posterScan: PosterScan
    
    @EnvironmentObject private var dataStore: DataStore
    @State private var messageText: String = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading: Bool = false
    @State private var showMoreQuestions: Bool = false
    
    // Suggested questions based on the poster content
    private let suggestedQuestions = [
        "What are the key findings of this research?",
        "What methods were used in this study?",
        "What are the limitations of this research?",
        "How does this compare to other work in the field?",
        "What are the practical applications of this research?",
        "Who might benefit from these findings?",
        "What future research might follow this work?",
        "What are the main conclusions?",
        "Why is this research important?",
        "What problem does this research address?"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        // Welcome message if empty
                        if messages.isEmpty {
                            welcomeMessage
                        }
                        
                        // Message bubbles
                        ForEach(messages) { message in
                            messageView(for: message)
                        }
                        
                        // Loading indicator
                        if isLoading {
                            loadingBubble
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessageId = messages.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastMessageId, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isLoading) { _ in
                    if isLoading {
                        withAnimation {
                            if let lastView = messages.last?.id {
                                proxy.scrollTo(lastView, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .background(Color(.systemGray6))
            
            // Suggested questions chips
            // Always show suggested questions to allow continued conversation
            suggestedQuestionsView
            
            // Input area
            HStack(spacing: 12) {
                TextField("Ask a question about this poster...", text: $messageText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .disabled(isLoading)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading ? .gray : DesignSystem.Colors.brandBlue)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.white)
            .shadow(color: Color.black.opacity(0.1), radius: 5, y: -2)
        }
        .navigationTitle("Ask About Poster")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // Welcome message
    private var welcomeMessage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ask about \"\(posterScan.title)\"")
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            Text("I can answer questions about this poster based on its content. Tap a suggested question below or type your own.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Visual cue
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Text("Suggested questions below")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.brandBlue)
                        .fontWeight(.medium)
                    
                    Image(systemName: "arrow.down")
                        .foregroundColor(DesignSystem.Colors.brandBlue)
                        .font(.caption)
                }
                Spacer()
            }
            .padding(.top, 10)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
    }
    
    // Message view
    private func messageView(for message: ChatMessage) -> some View {
        HStack {
            if message.sender == .user {
                Spacer()
                Text(message.content)
                    .padding(12)
                    .background(DesignSystem.Colors.brandBlue)
                    .foregroundColor(.white)
                    .cornerRadius(18)
                    .padding(.leading, 60)
            } else {
                Text(message.content)
                    .padding(12)
                    .background(Color.white)
                    .foregroundColor(.primary)
                    .cornerRadius(18)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
                    .padding(.trailing, 60)
                Spacer()
            }
        }
    }
    
    // Loading animation
    private var loadingBubble: some View {
        HStack {
            LoadingAnimation()
                .padding(14)
                .background(Color.white)
                .cornerRadius(18)
                .shadow(color: Color.black.opacity(0.1), radius: 3, y: 2)
            Spacer()
        }
    }
    
    // Suggested questions in a multi-row grid layout
    private var suggestedQuestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested Questions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            // Grid layout for questions - adaptive column layout for better spacing
            let columns = [
                GridItem(.adaptive(minimum: 150, maximum: 300), spacing: 12)
            ]
            
            // First row of questions (always visible)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(suggestedQuestions.prefix(6), id: \.self) { question in
                    questionButton(for: question)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            // Show more button if we have more than 6 questions
            if suggestedQuestions.count > 6 {
                VStack {
                    Button(action: {
                        withAnimation(.spring()) {
                            showMoreQuestions.toggle()
                        }
                        // Add haptic feedback
                        HapticManager.shared.lightImpact()
                    }) {
                        HStack {
                            Text(showMoreQuestions ? "Show Less" : "More Questions")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.brandBlue)
                            
                            Image(systemName: showMoreQuestions ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.brandBlue)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    if showMoreQuestions {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(suggestedQuestions.dropFirst(6), id: \.self) { question in
                                questionButton(for: question)
                            }
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 10)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(.systemGray6))
    }
    
    // Helper function for question buttons to maintain consistent styling
    private func questionButton(for question: String) -> some View {
        Button(action: {
            messageText = question
            sendMessage()
        }) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.brandBlue)
                        .padding(.top, 2)
                    
                    Text(question)
                        .font(.callout)
                        .lineLimit(3) // Increased from 2 to 3 for longer questions
                        .fixedSize(horizontal: false, vertical: true) // Allow text to expand vertically
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 70) // Minimum height to ensure consistent button sizes
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(DesignSystem.Colors.brandBlue.opacity(0.3), lineWidth: 1)
            )
            .foregroundColor(DesignSystem.Colors.brandBlue)
        }
        .buttonStyle(PlainButtonStyle()) // Prevents default button style from interfering
        .disabled(isLoading)
    }
    
    // Send message
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        
        // Add user message
        let userMessage = ChatMessage(content: text, sender: .user)
        messages.append(userMessage)
        
        // Save to dataStore if needed
        if let conversation = dataStore.conversations.first(where: { $0.posterId == posterScan.id }) {
            dataStore.addMessage(userMessage, to: conversation.id)
        } else {
            let newConversation = dataStore.getOrCreateConversation(for: posterScan.id)
            dataStore.addMessage(userMessage, to: newConversation.id)
        }
        
        // Clear text field
        messageText = ""
        
        // Show loading
        isLoading = true
        
        // Haptic
        HapticManager.shared.mediumImpact()
        
        // Generate response after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            generateResponse(for: text)
        }
    }
    
    // Generate AI response
    private func generateResponse(for text: String) {
        // Generate an appropriate response based on the content
        let response: String
        let lowerText = text.lowercased()
        
        if lowerText.contains("method") || lowerText.contains("methodology") {
            response = "Based on the poster, this research used \(posterScan.summaryPoints.first(where: { $0.lowercased().contains("method") || $0.lowercased().contains("methodology") }) ?? "experimental methodology with controlled variables and data collection over time. The specific techniques included statistical analysis and comparative assessment.")."
        } else if lowerText.contains("finding") || lowerText.contains("result") {
            response = "The key findings from this poster indicate \(posterScan.summaryPoints.first(where: { $0.lowercased().contains("result") || $0.lowercased().contains("finding") }) ?? "significant outcomes that support the primary hypothesis. The data demonstrates consistent patterns across multiple test conditions.")."
        } else if lowerText.contains("conclusion") || lowerText.contains("implication") {
            response = "The researchers concluded that \(posterScan.summaryPoints.first(where: { $0.lowercased().contains("conclusion") || $0.lowercased().contains("implication") }) ?? "the results have important implications for future work in this field. The outcomes suggest several potential applications and directions for continued research.")."
        } else if lowerText.contains("limitation") {
            let limitationText = posterScan.authorQuestions?.first(where: { $0.lowercased().contains("limitation") }) ?? "potential sampling constraints, limited time frame for data collection, and the specific context in which the study was conducted. These factors should be considered when interpreting the results."
            response = "Some limitations of this research include \(limitationText)."
        } else if lowerText.contains("benefit") || lowerText.contains("who might benefit") {
            response = "This research could benefit \(posterScan.summaryPoints.first(where: { $0.lowercased().contains("application") || $0.lowercased().contains("benefit") || $0.lowercased().contains("impact") }) ?? "clinicians, researchers, and patients in this field. The findings have potential applications in improving diagnostic accuracy, treatment protocols, and patient outcomes.")."
        } else if lowerText.contains("future research") || lowerText.contains("follow this work") {
            let futureWorkText = posterScan.authorQuestions?.first(where: { $0.lowercased().contains("future") }) ?? "expanding the sample size, investigating additional variables, and applying the methodology to different populations or contexts."
            response = "Future research following this work could focus on \(futureWorkText)"
        } else if lowerText.contains("important") || lowerText.contains("why is this") {
            response = "This research is important because it \(posterScan.summaryPoints.first(where: { $0.lowercased().contains("important") || $0.lowercased().contains("significance") }) ?? "addresses a significant gap in current knowledge and provides evidence-based insights that could influence practice in this field. The findings contribute to our understanding of key mechanisms and relationships that have both theoretical and practical implications.")."
        } else if lowerText.contains("problem") || lowerText.contains("address") {
            response = "This research addresses the problem of \(posterScan.summaryPoints.first(where: { $0.lowercased().contains("problem") || $0.lowercased().contains("challenge") || $0.lowercased().contains("gap") }) ?? "existing limitations in our understanding of this topic. It aims to resolve contradictions in prior literature and provide more reliable evidence for decision-making in this domain.")."
        } else if lowerText.contains("compare") || lowerText.contains("other work") {
            response = "Compared to other work in the field, this research \(posterScan.summaryPoints.first(where: { $0.lowercased().contains("previous") || $0.lowercased().contains("other") || $0.lowercased().contains("existing") }) ?? "takes a novel approach by incorporating multidisciplinary perspectives and advanced analytical techniques. While previous studies have focused on isolated aspects, this work provides a more comprehensive understanding of the interrelated factors.")."
        } else if lowerText.contains("practical application") || lowerText.contains("applied") {
            response = "The practical applications of this research include \(posterScan.summaryPoints.first(where: { $0.lowercased().contains("application") || $0.lowercased().contains("practical") || $0.lowercased().contains("practice") }) ?? "informing evidence-based protocols, developing more effective interventions, and guiding policy decisions. These findings could be implemented in clinical settings to improve diagnostic accuracy and treatment outcomes.")."
        } else {
            response = "Based on the poster content, this research focused on \(posterScan.title). The study identified important findings related to this topic through careful methodology and analysis. The poster highlights several key points including \(posterScan.summaryPoints.first ?? "the main research questions and findings") which contribute to our understanding of this field."
        }
        
        // Create AI response message
        let aiMessage = ChatMessage(content: response, sender: .ai)
        
        // Save to dataStore if needed
        if let conversation = dataStore.conversations.first(where: { $0.posterId == posterScan.id }) {
            dataStore.addMessage(aiMessage, to: conversation.id)
        }
        
        // Add to local messages array
        messages.append(aiMessage)
        
        // End loading
        isLoading = false
        
        // Haptic feedback
        HapticManager.shared.success()
    }
}

// Loading animation
struct LoadingAnimation: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(DesignSystem.Colors.brandBlue.opacity(0.7))
                    .frame(width: 10, height: 10)
                    .scaleEffect(isAnimating ? 1.3 : 0.7)
                    .opacity(isAnimating ? 1.0 : 0.4)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(0.15 * Double(index)),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct SimpleChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SimpleChatView(posterScan: PosterScan(
                title: "Example Poster: Effects of Climate Change on Marine Ecosystems",
                rawText: "This is a sample poster about marine ecosystems and climate change impacts. It includes methodology, results, and conclusions.",
                summaryPoints: [
                    "**Main Research Question**: How do rising ocean temperatures affect coral reef ecosystems?",
                    "**Methodology**: Field observations and laboratory experiments were conducted over 3 years.",
                    "**Key Results**: Coral bleaching increased by 25% in areas with 1.5°C temperature rise.",
                    "**Main Conclusions**: Urgent conservation measures are needed to protect vulnerable marine ecosystems."
                ],
                image: nil,
                date: Date(),
                authorQuestions: [
                    "**Future Research**: What other marine species might serve as early indicators of climate change?",
                    "**Limitations**: How did seasonal variations affect your observations?"
                ]
            ))
            .environmentObject(DataStore())
        }
    }
}