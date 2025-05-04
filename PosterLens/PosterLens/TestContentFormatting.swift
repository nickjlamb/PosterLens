import SwiftUI

// This file is for testing content formatting functions
// You can run this code in a SwiftUI preview or a separate test target

struct TestContentFormatting: View {
    // Test cases for SummaryView
    let testSummaryPoints = [
        "**Main Research Question/Objective**: The poster focuses on the importance of molecular pathology in oncology. [1]",
        "**Methodology Used**: The methodology involves various testing modalities such as Next-Generation Sequencing. [2, 3]",
        ": **Key Results and Findings**: Key findings highlight the role of biomarkers in guiding therapy. 5",
        "**Main Conclusions and Implications**: : The conclusions emphasize the importance of integrating molecular testing 6.",
        "Plain bullet point with references [4, 5, 6]"
    ]
    
    // Test cases for questions
    let testQuestions = [
        "**Limitations**: : What are the limitations of this approach? [1]",
        "**Future Work**: How do you plan to extend this research? 3",
        ": Have you considered alternative methodologies? 4.",
        "1. What unexpected results did you find in your study? 5"
    ]
    
    // Test cases for research directions
    let testDirections = [
        "**Extended Data Collection**: : This research could benefit from expanding the dataset. [1, 2]",
        "**Methodology Refinement**: Further refinement of the experimental approach could... 3",
        ": **Clinical Translation**: These findings could be applied in clinical settings by... 4.",
        "1. **Collaboration Opportunities**: Partnering with other research teams could... 5"
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    Text("Original Summary Points")
                        .font(.headline)
                    
                    ForEach(testSummaryPoints, id: \.self) { point in
                        Text(point)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Divider()
                
                Group {
                    Text("Processed Summary Points")
                        .font(.headline)
                    
                    ForEach(processedSummaryPoints(), id: \.title) { point in
                        VStack(alignment: .leading) {
                            Text("Title: \(point.title)")
                                .fontWeight(.bold)
                            Text("Content: \(point.content)")
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Divider()
                
                Group {
                    Text("Original Questions")
                        .font(.headline)
                    
                    ForEach(testQuestions, id: \.self) { question in
                        Text(question)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Divider()
                
                Group {
                    Text("Processed Questions")
                        .font(.headline)
                    
                    ForEach(processedQuestions(), id: \.content) { question in
                        VStack(alignment: .leading) {
                            if !question.title.isEmpty {
                                Text("Title: \(question.title)")
                                    .fontWeight(.bold)
                            }
                            Text("Content: \(question.content)")
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                Divider()
                
                Group {
                    Text("Original Directions")
                        .font(.headline)
                    
                    ForEach(testDirections, id: \.self) { direction in
                        Text(direction)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Divider()
                
                Group {
                    Text("Processed Directions")
                        .font(.headline)
                    
                    ForEach(processedDirections(), id: \.content) { direction in
                        VStack(alignment: .leading) {
                            if !direction.title.isEmpty {
                                Text("Title: \(direction.title)")
                                    .fontWeight(.bold)
                            }
                            Text("Content: \(direction.content)")
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
    }
    
    // Copy of the function from SummaryView for testing
    private func processedSummaryPoints() -> [(title: String, content: String)] {
        // First, deduplicate summary points based on content
        var uniquePoints = [String: String]() // content: title
        var result = [(title: String, content: String)]()
        
        for (index, point) in testSummaryPoints.enumerated() {
            // Check if the point contains a heading (text between ** markers)
            if let range = point.range(of: "\\*\\*(.*?)\\*\\*", options: .regularExpression) {
                let heading = String(point[range])
                    .replacingOccurrences(of: "**", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Get the content after the heading
                let startIndex = point.index(range.upperBound, offsetBy: 0)
                var content = String(point[startIndex...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove leading colon if present
                if content.hasPrefix(":") {
                    content = String(content.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Remove trailing numbers that might be references
                if let trailingNumberRange = content.range(of: "\\s+\\d+\\.?$", options: .regularExpression) {
                    content = String(content[..<trailingNumberRange.lowerBound])
                }
                
                // Remove references like [1], [2, 3]
                content = content.replacingOccurrences(of: "\\s*\\[\\d+(?:[-,]\\s*\\d+)*\\]\\s*", with: " ", options: .regularExpression)
                
                // Only add if this content hasn't been seen before
                if uniquePoints[content] == nil {
                    uniquePoints[content] = heading
                    result.append((title: heading, content: content))
                }
            } else {
                // If no heading is found, use a more specific title
                var content = point.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove leading colon if present
                if content.hasPrefix(":") {
                    content = String(content.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Remove trailing numbers that might be references
                if let trailingNumberRange = content.range(of: "\\s+\\d+\\.?$", options: .regularExpression) {
                    content = String(content[..<trailingNumberRange.lowerBound])
                }
                
                // Remove references like [1], [2, 3]
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
    
    // Copy of the function from ButtonRowView for testing
    private func processedQuestions() -> [(title: String, content: String)] {
        return testQuestions.map { question in
            // Check if the question contains a heading (text between ** markers)
            if let range = question.range(of: "\\*\\*(.*?)\\*\\*", options: .regularExpression) {
                let heading = String(question[range])
                    .replacingOccurrences(of: "**", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Get the content after the heading
                let startIndex = question.index(range.upperBound, offsetBy: 0)
                var content = String(question[startIndex...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove leading colon if present
                if content.hasPrefix(":") {
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
                
                // Remove references like [1], [2, 3]
                content = content.replacingOccurrences(of: "\\s*\\[\\d+(?:[-,]\\s*\\d+)*\\]\\s*", with: " ", options: .regularExpression)
                
                return (title: heading, content: content)
            } else {
                // If no heading is found, remove any numbering and use as content
                var content = question.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove leading colon if present
                if content.hasPrefix(":") {
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
                
                // Remove references like [1], [2, 3]
                content = content.replacingOccurrences(of: "\\s*\\[\\d+(?:[-,]\\s*\\d+)*\\]\\s*", with: " ", options: .regularExpression)
                
                return (title: "", content: content)
            }
        }
    }
    
    // Copy of the function from ResearchDirectionsView for testing
    private func processedDirections() -> [(title: String, content: String)] {
        return testDirections.map { direction in
            // Check if the direction contains a heading (text between ** markers)
            if let range = direction.range(of: "\\*\\*(.*?)\\*\\*", options: .regularExpression) {
                let heading = String(direction[range])
                    .replacingOccurrences(of: "**", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Get the content after the heading
                let startIndex = direction.index(range.upperBound, offsetBy: 0)
                var content = String(direction[startIndex...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove leading colon if present
                if content.hasPrefix(":") {
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
                
                // Remove references like [1], [2, 3]
                content = content.replacingOccurrences(of: "\\s*\\[\\d+(?:[-,]\\s*\\d+)*\\]\\s*", with: " ", options: .regularExpression)
                
                return (title: heading, content: content)
            } else {
                // If no heading is found, remove any numbering and use as content
                var content = direction.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove leading colon if present
                if content.hasPrefix(":") {
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
                
                // Remove references like [1], [2, 3]
                content = content.replacingOccurrences(of: "\\s*\\[\\d+(?:[-,]\\s*\\d+)*\\]\\s*", with: " ", options: .regularExpression)
                
                return (title: "", content: content)
            }
        }
    }
}

struct TestContentFormatting_Previews: PreviewProvider {
    static var previews: some View {
        TestContentFormatting()
    }
}