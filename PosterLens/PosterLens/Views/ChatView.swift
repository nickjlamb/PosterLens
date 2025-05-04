import SwiftUI

struct ChatView: View {
    let posterScan: PosterScan
    
    @EnvironmentObject private var dataStore: DataStore
    @State private var messageText: String = ""
    @State private var conversation: Conversation?
    @State private var isLoading: Bool = false
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var errorMessage: String?
    @State private var showingError: Bool = false
    
    // Chat service for API communication
    private let chatService = ChatService()
    
    // Suggested questions based on the poster content
    @State private var suggestedQuestions: [String] = [
        "What are the key findings of this research?",
        "What methods were used in this study?",
        "What are the limitations of this research?",
        "How does this compare to other work in the field?",
        "What are the practical applications of this research?"
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages area
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        // Welcome message - always show at start
                        if let conversation = conversation, conversation.messages.isEmpty {
                            welcomeMessage
                        }
                        
                        // Message bubbles - only when there are actual messages
                        ForEach(conversation?.messages ?? []) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        // Show loading indicator when waiting for a response
                        if isLoading {
                            HStack {
                                Spacer()
                                LoadingBubble()
                                    .id("loadingBubble")
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                }
                .onAppear {
                    self.scrollProxy = proxy
                    // Load or create conversation
                    let convo = dataStore.getOrCreateConversation(for: posterScan.id)
                    self.conversation = convo
                }
                .onChange(of: conversation?.messages.count) { newCount in
                    // Log message count change
                    print("📊 Message count changed to: \(newCount ?? 0)")
                    
                    // Scroll to bottom when messages change
                    withAnimation {
                        if let lastMessage = conversation?.messages.last {
                            print("📜 Scrolling to message: \(lastMessage.content.prefix(20))...")
                            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
                        } else if isLoading {
                            print("📜 Scrolling to loading bubble")
                            scrollProxy?.scrollTo("loadingBubble", anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(.systemGray6))
            
            // Suggested questions chips
            // Always show at the start, hide after a few messages
            if let conversation = conversation, conversation.messages.count < 4 {
                suggestedQuestionsView
            }
            
            // Input area
            HStack(spacing: 12) {
                TextField("Ask a question about this poster...", text: $messageText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .disabled(isLoading)
                
                Button(action: {
                    print("🔘 Send button tapped with text: \(messageText)")
                    sendMessage()
                }) {
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
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .onDisappear {
            // Clean up timers when view disappears
            responseTimer?.invalidate()
            responseTimer = nil
            print("🧹 Cleaned up timers on disappear")
        }
    }
    
    // Welcome message at the start of conversation
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
            
            // Add visual cue pointing to suggested questions
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
            
            Divider()
                .padding(.vertical, 5)
        }
        .padding(.vertical)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
        .padding(.horizontal)
    }
    
    // Suggested questions chips
    private var suggestedQuestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section title
            Text("Suggested Questions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestedQuestions, id: \.self) { question in
                        Button(action: {
                            print("🔘 Suggested question button tapped: \(question)")
                            messageText = question
                            sendMessage()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.circle.fill")
                                    .font(.system(size: 14))
                                
                                Text(question)
                                    .font(.callout)
                                    .lineLimit(2)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.1), radius: 3, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(DesignSystem.Colors.brandBlue.opacity(0.3), lineWidth: 1)
                            )
                            .foregroundColor(DesignSystem.Colors.brandBlue)
                        }
                        .buttonStyle(PressableQuestionStyle())
                        .disabled(isLoading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .background(Color(.systemGray6))
    }
    
    // Custom button style for question chips
    struct PressableQuestionStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.95 : 1)
                .brightness(configuration.isPressed ? 0.05 : 0)
                .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
        }
    }
    
    // Keep track of the timer for generating responses
    @State private var responseTimer: Timer? = nil
    @State private var responseText: String = ""
    
    // Send a message and get a response with a simpler approach
    private func sendMessage() {
        print("🔍 sendMessage started")
        // Trim whitespace
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading, let conversation = conversation else { 
            print("❌ Guard condition failed in sendMessage")
            return 
        }
        
        print("✅ Adding user message: \(text)")
        // Create and add user message
        let userMessage = ChatMessage(content: text, sender: .user)
        dataStore.addMessage(userMessage, to: conversation.id)
        
        // Clear input field and prepare response
        messageText = ""
        responseText = ""
        
        // Start loading state
        isLoading = true
        print("⏳ Loading state started")
        
        // Provide haptic feedback
        HapticManager.shared.mediumImpact()

        // Generate an appropriate response based on the content
        if text.lowercased().contains("method") || text.lowercased().contains("methodology") {
            responseText = "Based on the poster, this research used \(posterScan.summaryPoints.first(where: { $0.lowercased().contains("method") || $0.lowercased().contains("methodology") }) ?? "experimental methodology with controlled variables and data collection over time. The specific techniques included statistical analysis and comparative assessment.")."
        } else if text.lowercased().contains("finding") || text.lowercased().contains("result") {
            responseText = "The key findings from this poster indicate \(posterScan.summaryPoints.first(where: { $0.lowercased().contains("result") || $0.lowercased().contains("finding") }) ?? "significant outcomes that support the primary hypothesis. The data demonstrates consistent patterns across multiple test conditions.")."
        } else if text.lowercased().contains("conclusion") || text.lowercased().contains("implication") {
            responseText = "The researchers concluded that \(posterScan.summaryPoints.first(where: { $0.lowercased().contains("conclusion") || $0.lowercased().contains("implication") }) ?? "the results have important implications for future work in this field. The outcomes suggest several potential applications and directions for continued research.")."
        } else if text.lowercased().contains("limitation") {
            let limitationText = posterScan.authorQuestions?.first(where: { $0.lowercased().contains("limitation") }) ?? "potential sampling constraints, limited time frame for data collection, and the specific context in which the study was conducted. These factors should be considered when interpreting the results."
            responseText = "Some limitations of this research include \(limitationText)."
        } else {
            responseText = "Based on the poster content, this research focused on \(posterScan.title). The study identified important findings related to this topic through careful methodology and analysis. The poster highlights several key points including \(posterScan.summaryPoints.first ?? "the main research questions and findings") which contribute to our understanding of this field."
        }
        
        print("📝 Generated response: \(responseText.prefix(30))...")
        
        // Cancel any existing timer
        responseTimer?.invalidate()
        
        // Schedule a timer to add the response after a delay
        responseTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            print("⏰ Timer fired - adding AI response")
            
            // Add the AI response
            let aiMessage = ChatMessage(content: self.responseText, sender: .ai)
            
            // We must update UI on main thread
            DispatchQueue.main.async {
                // Add message to conversation
                if let conversation = self.conversation {
                    print("💾 Adding AI message to conversation")
                    self.dataStore.addMessage(aiMessage, to: conversation.id)
                    
                    // Refresh the conversation to force UI update
                    print("🔄 Refreshing conversation")
                    self.conversation = self.dataStore.getOrCreateConversation(for: self.posterScan.id)
                    
                    // Success haptic
                    HapticManager.shared.success()
                    
                    // End loading state
                    print("✅ Ending loading state")
                    self.isLoading = false
                } else {
                    print("❌ Conversation was nil when timer fired")
                }
            }
        }
    }
}

// Message bubble component
struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer()
                Text(message.content)
                    .padding(12)
                    .background(DesignSystem.Colors.brandBlue)
                    .foregroundColor(.white)
                    .cornerRadius(18)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.leading, 60)
                    .padding(.trailing, 16)
            } else {
                Text(message.content)
                    .padding(12)
                    .background(Color.white)
                    .foregroundColor(.primary)
                    .cornerRadius(18)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
                    .padding(.leading, 16)
                    .padding(.trailing, 60)
                Spacer()
            }
        }
    }
}

// Loading animation bubble
struct LoadingBubble: View {
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
        .padding(14)
        .background(Color.white)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.1), radius: 3, y: 2)
        .onAppear {
            isAnimating = true
        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            // Create a sample poster scan for preview
            ChatView(posterScan: PosterScan(
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
