import SwiftUI

struct ResearchContextView: View {
    // Use a binding to ensure updates from parent view are reflected
    @Binding var futureDirections: [String]?
    @State private var isGeneratingDirections = false
    @State private var showingDirections = false
    var onGenerateDirections: () -> Void
    
    init(futureDirections: Binding<[String]?>, onGenerateDirections: @escaping () -> Void) {
        self._futureDirections = futureDirections
        self.onGenerateDirections = onGenerateDirections
        self._showingDirections = State(initialValue: futureDirections.wrappedValue != nil && !(futureDirections.wrappedValue?.isEmpty ?? true))
        
        print("ResearchContextView initialized with directions: \(String(describing: futureDirections.wrappedValue))")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Future Research Directions")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isGeneratingDirections {
                    ProgressView()
                        .padding(.trailing, 8)
                }
                
                Button(action: {
                    if futureDirections == nil || futureDirections!.isEmpty {
                        print("Generate button pressed, directions is empty")
                        isGeneratingDirections = true
                        onGenerateDirections()
                    } else {
                        print("Show/Hide button pressed, toggling directions visibility")
                        showingDirections.toggle()
                    }
                }) {
                    Text(futureDirections == nil || futureDirections!.isEmpty ? "Generate" : (showingDirections ? "Hide" : "Show"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isGeneratingDirections)
            }
            
            if showingDirections, let directions = futureDirections, !directions.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(processedDirections(directions).enumerated()), id: \.element.content) { index, processedDirection in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(Color.blue))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if !processedDirection.title.isEmpty {
                                    Text(processedDirection.title)
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                                
                                Text(processedDirection.content)
                                    .font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
                .transition(.opacity)
                .animation(.easeInOut, value: showingDirections)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
        .padding(.vertical, 8)
        .onChange(of: futureDirections) { newValue in
            print("Directions changed to: \(String(describing: newValue))")
            if let newDirections = newValue, !newDirections.isEmpty {
                showingDirections = true
            }
        }
    }
    
    // Process directions to extract headings and content
    private func processedDirections(_ directions: [String]) -> [(title: String, content: String)] {
        return directions.map { direction in
            // Check if the direction contains a heading (text between ** markers)
            if let range = direction.range(of: "\\*\\*(.*?)\\*\\*", options: .regularExpression) {
                let heading = String(direction[range])
                    .replacingOccurrences(of: "**", with: "")
                
                // Get the content after the heading
                let startIndex = direction.index(range.upperBound, offsetBy: 0)
                let content = String(direction[startIndex...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: ":", with: "", options: .anchored)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                return (title: heading, content: content)
            } else {
                // If no heading is found, use the entire direction as content with no title
                return (title: "", content: direction)
            }
        }
    }
    
    func setGenerating(_ isGenerating: Bool) {
        print("setGenerating called with: \(isGenerating)")
        self.isGeneratingDirections = isGenerating
    }
}

struct ResearchContextView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // Example with no directions yet
            StateWrapper(initialValue: nil as [String]?) { $directions in
                ResearchContextView(
                    futureDirections: $directions,
                    onGenerateDirections: { print("Generate action") }
                )
            }
            .padding()
            
            // Example with directions
            StateWrapper(initialValue: [
                "**Methodology Extension**: Explore the application of this methodology to other scientific domains",
                "**AI Integration**: Investigate the integration with machine learning algorithms for improved accuracy",
                "**Collaborative Platform**: Develop a collaborative platform for researchers to share and build upon findings",
                "**Longitudinal Validation**: Conduct longitudinal studies to validate the long-term impact of the approach",
                "**Ethical Guidelines**: Examine potential ethical implications and develop appropriate guidelines"
            ] as [String]?) { $directions in
                ResearchContextView(
                    futureDirections: $directions,
                    onGenerateDirections: { print("Generate action") }
                )
            }
            .padding()
        }
    }
}


