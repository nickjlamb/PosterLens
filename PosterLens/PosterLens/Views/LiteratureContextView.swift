import SwiftUI

struct LiteratureContextView: View {
    @Binding var citations: [Citation]?
    var onGenerateCitations: () -> Void
    
    @State private var isExpanded = false
    @State private var isGenerating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with icon and title
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                
                Text("What to Read Next")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.trailing, 8)
                }
                
                Button(action: {
                    if citations == nil {
                        isGenerating = true
                        onGenerateCitations()
                    } else {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
                }) {
                    Text(citations == nil ? "Generate" : (isExpanded ? "Hide" : "Show"))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isGenerating)
            }
            
            // Content based on state
            if isGenerating {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    
                    Text("Finding relevant papers...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }
                .padding(.top, 8)
            }
            else if isExpanded && citations != nil {
                if let citationList = citations, !citationList.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(citationList) { citation in
                                SimplifiedCitationCard(citation: citation)
                            }
                        }
                    }
                    .frame(maxHeight: 400)
                }
                else if citations?.isEmpty == true {
                    Text("No relevant papers found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6)) // Changed to match the other cards
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
        )
        .onChange(of: citations) { newCitations in
            // If we just got new citations, expand the view and stop loading
            if newCitations != nil {
                isGenerating = false
                isExpanded = true
            }
        }
    }
}

struct SimplifiedCitationCard: View {
    let citation: Citation
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(citation.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Journal and Year
            HStack {
                if let journal = citation.journal {
                    Text(journal)
                        .font(.subheadline)
                        .italic()
                        .foregroundColor(.secondary)
                }
                
                if let year = citation.year {
                    Text("(\(year))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Expandable content
            if isExpanded {
                if let abstract = citation.abstract {
                    Text("Abstract:")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.top, 4)
                    
                    Text(abstract)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                if let relevance = citation.relevance {
                    Text("Relevance:")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .padding(.top, 4)
                    
                    Text(relevance)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                if let url = citation.url {
                    Link("Access Paper", destination: URL(string: url)!)
                        .font(.subheadline)
                        .padding(.top, 4)
                }
            }
            
            // Expand/Collapse button
            Button(isExpanded ? "Show Less" : "Show More") {
                withAnimation {
                    isExpanded.toggle()
                }
            }
            .font(.caption)
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
        )
    }
}

// Preview provider for SwiftUI Canvas
struct LiteratureContextView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            LiteratureContextView(
                citations: .constant([
                    Citation(
                        title: "End-to-End Non-Small-Cell Lung Cancer Prognostication Using Deep Learning Applied to Computed Tomography",
                        authors: [],
                        journal: "Journal of Clinical Oncology",
                        year: 2023,
                        doi: "10.1200/JCO.2022.12.345",
                        url: "https://scholar.google.com/scholar?q=End-to-End+Non-Small-Cell+Lung+Cancer+Prognostication",
                        abstract: "This study demonstrates a novel deep learning approach for predicting survival in non-small cell lung cancer patients using CT images. The model outperforms traditional clinical staging methods.",
                        relevance: "Directly related to the poster's focus on deep learning for lung cancer prognostication."
                    ),
                    Citation(
                        title: "Automated Imaging-Based Prognostication for Stage I Non-Small Cell Lung Cancer",
                        authors: [],
                        journal: "Nature Medicine",
                        year: 2022,
                        doi: "10.1038/s41591-022-1234-5",
                        url: "https://scholar.google.com/scholar?q=Automated+Imaging-Based+Prognostication",
                        abstract: "This paper presents an automated approach for prognostication in early-stage lung cancer using deep learning on CT images.",
                        relevance: "Focuses on early-stage lung cancer, complementing the poster's research on prognostication."
                    )
                ]),
                onGenerateCitations: {}
            )
            .padding()
            
            LiteratureContextView(
                citations: .constant(nil),
                onGenerateCitations: {}
            )
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
