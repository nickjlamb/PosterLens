import SwiftUI

// This file tests the colon removal functionality
struct TestColonRemoval: View {
    // Test cases with various colon formats
    let testSummaryPoints = [
        "**Main Research Question**: The poster focuses on molecular pathology in oncology.",
        "**Methodology Used**: : The methodology involves various testing modalities.",
        "**Key Results**: : : The findings highlight the role of biomarkers.",
        "**Main Conclusions** The conclusions emphasize the importance of testing.",
        "**Novel Techniques** : This introduces a new approach to data analysis."
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Colon Removal Test")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom)
                
                Group {
                    Text("Original Inputs (with colons)")
                        .font(.headline)
                    
                    ForEach(testSummaryPoints, id: \.self) { point in
                        Text(point)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.bottom)
                
                Group {
                    Text("After Processing (colons should be removed)")
                        .font(.headline)
                    
                    ForEach(processedPoints(), id: \.title) { point in
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
            }
            .padding()
        }
    }
    
    // Test our current processing function
    private func processedPoints() -> [(title: String, content: String)] {
        var result = [(title: String, content: String)]()
        
        for point in testSummaryPoints {
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
                
                // Add to results
                result.append((title: heading, content: content))
            } else {
                // If no heading is found, just use the point as content
                result.append((title: "Point", content: point))
            }
        }
        
        return result
    }
}

struct TestColonRemoval_Previews: PreviewProvider {
    static var previews: some View {
        TestColonRemoval()
    }
}