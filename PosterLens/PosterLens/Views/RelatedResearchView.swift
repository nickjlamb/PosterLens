import SwiftUI

struct RelatedResearchView: View {
    let posterScan: PosterScan
    @EnvironmentObject private var dataStore: DataStore
    
    // State variables for managing the search process
    @State private var isSearching = false
    @State private var relatedPapers: [Citation] = []
    @State private var errorMessage: String?
    @State private var showingError = false
    
    // Animation state variables
    @State private var animationValue: Double = 0
    @State private var dotOpacities: [Double] = [0.3, 0.3, 0.3]
    @State private var searchStepIndex: Int = 1
    
    // Service for API calls
    private let relatedResearchService = PerplexityRelatedResearchService()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Related Research")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    Text("Academic papers related to this poster")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Divider()
                        .padding(.vertical, 8)
                }
                .padding(.horizontal)
                
                // Poster title
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Poster:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(posterScan.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.bottom, 4)
                }
                .padding(.horizontal)
                
                // Content area - shows different views based on state
                Group {
                    if isSearching {
                        // Use a separate LoadingView to simplify the code
                        SearchingAnimationView(
                            animationValue: $animationValue,
                            dotOpacities: $dotOpacities,
                            searchStepIndex: searchStepIndex
                        )
                    } else if !relatedPapers.isEmpty {
                        // Results state
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Related Papers")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.top, 8)
                            
                            // Display each paper
                            ForEach(relatedPapers) { paper in
                                PaperCardView(paper: paper)
                                    .padding(.horizontal)
                                    .padding(.bottom, 8)
                            }
                            
                            // Refresh button
                            Button(action: {
                                searchForRelatedPapers()
                            }) {
                                Label("Refresh Results", systemImage: "arrow.clockwise")
                                    .font(.body)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 20)
                                    .background(Color.green)
                                    .cornerRadius(10)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 32)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                    } else {
                        // Initial or empty state
                        VStack(spacing: 20) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                                .opacity(0.8)
                                .padding(.top, 40)
                            
                            Text("Find Related Research")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Discover academic papers and articles related to this poster's content using the Perplexity Sonar Pro API.")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 32)
                            
                            Button(action: {
                                searchForRelatedPapers()
                            }) {
                                Text("Search Academic Databases")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 14)
                                    .padding(.horizontal, 24)
                                    .background(Color.green)
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                            }
                            .padding(.top, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Related Research")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showingError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "An unknown error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            // If the poster already has literature context, display it immediately
            if let researchContext = posterScan.researchContext,
               let literatureContext = researchContext.literatureContext,
               !literatureContext.isEmpty {
                relatedPapers = literatureContext
            } else {
                // Otherwise, auto-search on appear if we don't have results yet
                searchForRelatedPapers()
            }
        }
    }
    
    // Function to trigger the related papers search using async/await
    private func searchForRelatedPapers() {
        isSearching = true
        errorMessage = nil
        searchStepIndex = 1
        
        // Reset animation state
        animationValue = 0
        dotOpacities = [0.3, 0.3, 0.3]
        
        Task {
            // Start advancing the step indicator
            await advanceStepIndicator()
            
            do {
                // Use the unified method that routes through RAG or Perplexity based on FeatureFlags
                // RAG pipeline: BigQuery + Vertex AI embeddings (when enabled)
                // Perplexity fallback: Search API with PubMed enrichment
                let papers = try await relatedResearchService.findRelatedResearchUnified(from: posterScan, skipEnrichment: false)
                
                await MainActor.run {
                    // Ensure the animation completes
                    searchStepIndex = 4

                    // Delay to ensure the final step is visible for sufficient time
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isSearching = false
                        relatedPapers = papers

                        // Save the papers to the poster's research context
                        savePapersToContext(papers)
                        
                        // Provide success haptic feedback
                        HapticManager.shared.success()
                    }
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    errorMessage = "Failed to find related papers: \(error.localizedDescription)"
                    showingError = true
                    
                    // Provide error haptic feedback
                    HapticManager.shared.error()
                    
                    // If error occurs, show sample papers as fallback
                    relatedPapers = Citation.samples
                }
            }
        }
    }
    
    // Helper function to advance the step indicator asynchronously
    private func advanceStepIndicator() async {
        // NEW TIMING: Account for Perplexity Search + PubMed enrichment (~15-20 seconds total)
        try? await Task.sleep(nanoseconds: 4_000_000_000) // 4 seconds - Perplexity search

        await MainActor.run {
            searchStepIndex = 2
        }

        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds - parsing results

        await MainActor.run {
            searchStepIndex = 3
        }

        try? await Task.sleep(nanoseconds: 8_000_000_000) // 8 seconds - PubMed enrichment (faster now with PMIDs)

        await MainActor.run {
            searchStepIndex = 4
        }

        // The final step will remain visible until the search completes naturally
    }
    
    // These methods have been moved to the dedicated subviews
    
    // Save the found papers to the poster's research context
    private func savePapersToContext(_ papers: [Citation]) {
        var updatedPosterScan = posterScan
        
        // Create or update research context
        if updatedPosterScan.researchContext == nil {
            updatedPosterScan.researchContext = ResearchContext()
        }
        
        // Update the literature context
        updatedPosterScan.researchContext?.literatureContext = papers
        
        // Save the updated scan using the data store
        dataStore.saveScan(updatedPosterScan)
    }
}

// Component to display an individual paper card
struct PaperCardView: View {
    let paper: Citation
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Paper title with metadata badge (if validated)
            HStack(alignment: .top) {
                Text(paper.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // If validated by PubMed, show badge
                if isPubMedValidated {
                    Spacer(minLength: 4)
                    
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            .padding(.bottom, 2)

            // Why relevant explanation (from RAG backend)
            if let relevance = paper.relevance, !relevance.isEmpty {
                Text(relevance)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }

            // Authors and publication info
            HStack(alignment: .top, spacing: 4) {
                Text(formatAuthors(paper.authors))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if paper.year != nil {
                    Text("•")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(formatYear(paper.year!))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Journal with DOI badge
            HStack(alignment: .center, spacing: 6) {
                if let journal = paper.journal {
                    Text(journal)
                        .font(.subheadline)
                        .italic()
                        .foregroundColor(.secondary)
                }
                
                // Show DOI badge if available
                if let doi = paper.doi, !doi.isEmpty {
                    Text("DOI")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                
                // Show PubMed badges
                if isPubMedValidated && !isPubMedSearch {
                    Text("PubMed")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                } else if isPubMedSearch {
                    Text("PubMed Search")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }
            
            // Expandable content
            VStack(alignment: .leading, spacing: 12) {
                if isExpanded {
                    // Abstract
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Abstract")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        if let abstract = paper.abstract, !abstract.isEmpty {
                            Text(abstract)
                                .font(.subheadline)
                                .foregroundColor(.primary.opacity(0.8))
                                .lineSpacing(4)
                        } else {
                            Text("No abstract available.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    .padding(.vertical, 4)

                    // Relevance
                    if let relevance = paper.relevance {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Relevance")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(relevance)
                                .font(.subheadline)
                                .foregroundColor(.primary.opacity(0.8))
                                .lineSpacing(4)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Citation metadata
                    VStack(alignment: .leading, spacing: 8) {
                        // DOI link if available
                        if let doi = paper.doi, !doi.isEmpty {
                            HStack {
                                Text("DOI:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    if let url = URL(string: "https://doi.org/\(doi)") {
                                        UIApplication.shared.open(url)
                                    }
                                }) {
                                    Text(doi)
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .underline()
                                }
                            }
                        }
                        
                        // PubMed ID if available
                        if let pmid = extractPMID(from: paper.url) {
                            HStack {
                                Text("PubMed ID:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Text(pmid)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else if isPubMedSearch, let url = paper.url {
                            HStack {
                                Text("PubMed Search:")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                // Extract and show terms
                                let terms = extractSearchTerms(from: url)
                                Text(terms)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Action buttons
                    HStack(spacing: 12) {
                        // View paper button - first try the accessURL property, then the url directly
                        if let accessURL = paper.accessURL {
                            Button(action: {
                                UIApplication.shared.open(accessURL)
                            }) {
                                HStack {
                                    Image(systemName: "doc.text.viewfinder")
                                    Text("View Paper")
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.green)
                                .cornerRadius(8)
                            }
                        } else if let urlString = paper.url, let url = URL(string: urlString) {
                            Button(action: {
                                UIApplication.shared.open(url)
                            }) {
                                HStack {
                                    Image(systemName: "doc.text.viewfinder")
                                    Text("View Paper")
                                }
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.green)
                                .cornerRadius(8)
                            }
                        }
                        
                        // Google Scholar search button as fallback
                        Button(action: {
                            let query = paper.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                            if let url = URL(string: "https://scholar.google.com/scholar?q=\(query)") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                Text("Scholar")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.top, 4)
            
            // Expand/collapse button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
                
                // Provide haptic feedback
                HapticManager.shared.selection()
            }) {
                HStack {
                    Text(isExpanded ? "Show Less" : "Show More")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundColor(.blue)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // Check if the paper has been validated by PubMed
    private var isPubMedValidated: Bool {
        if let url = paper.url {
            return url.contains("pubmed.ncbi.nlm.nih.gov") || url.contains("ncbi.nlm.nih.gov/pubmed")
        }
        return false
    }
    
    // Check if this is a PubMed search link (contains ?term=)
    private var isPubMedSearch: Bool {
        if let url = paper.url {
            return url.contains("pubmed.ncbi.nlm.nih.gov/?term=") || url.contains("&term=")
        }
        return false
    }
    
    // Extract PubMed ID from URL
    private func extractPMID(from urlString: String?) -> String? {
        guard let urlString = urlString else { return nil }
        
        // Match patterns like https://pubmed.ncbi.nlm.nih.gov/12345678/
        let pattern = "pubmed\\.ncbi\\.nlm\\.nih\\.gov\\/(\\d+)"
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(urlString.startIndex..., in: urlString)
            if let match = regex.firstMatch(in: urlString, range: range),
               let matchRange = Range(match.range(at: 1), in: urlString) {
                return String(urlString[matchRange])
            }
        } catch {
            print("Error extracting PMID: \(error)")
        }
        return nil
    }
    
    // Extract and format search terms from a PubMed search URL
    private func extractSearchTerms(from urlString: String) -> String {
        // Try to get the term parameter from the URL
        if let url = URL(string: urlString),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let termItem = queryItems.first(where: { $0.name == "term" }),
           let term = termItem.value {
            
            // Decode and clean up the term
            let decoded = term.removingPercentEncoding ?? term
            
            // Remove quotes, replace + with spaces
            let cleaned = decoded
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "+", with: " ")
                .replacingOccurrences(of: "%20", with: " ")
            
            if cleaned.count > 40 {
                // If too long, truncate and add ellipsis
                let truncated = String(cleaned.prefix(40))
                return "\(truncated)..."
            }
            
            return cleaned
        }
        
        // Fallback: just return a simple string
        return "Search for paper"
    }
    
    // Format authors for display
    private func formatAuthors(_ authors: [String]) -> String {
        // Filter out any "not specified" or "unknown" values
        let filteredAuthors = authors.filter { 
            !$0.isEmpty && 
            !$0.lowercased().contains("not specified") && 
            !$0.lowercased().contains("unknown")
        }
        
        if filteredAuthors.isEmpty {
            return "Research Team" // Better default than "Unknown Authors"
        } else if filteredAuthors.count == 1 {
            return filteredAuthors[0]
        } else if filteredAuthors.count == 2 {
            return "\(filteredAuthors[0]) & \(filteredAuthors[1])"
        } else {
            return "\(filteredAuthors[0]) et al."
        }
    }
    
    // Format year without comma
    private func formatYear(_ year: Int) -> String {
        // Use NumberFormatter to remove thousand separator (comma)
        let formatter = NumberFormatter()
        formatter.numberStyle = .none // No style means no grouping separators
        return formatter.string(from: NSNumber(value: year)) ?? "\(year)"
    }
}

// Dedicated view for the search animation
struct SearchingAnimationView: View {
    @Binding var animationValue: Double
    @Binding var dotOpacities: [Double]
    let searchStepIndex: Int

    private var isRAGEnabled: Bool {
        FeatureFlags.usePubMedRAG
    }

    var body: some View {
        VStack(spacing: 20) {
            // Animated search graphic
            ZStack {
                // Outer circle
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                // Animated arc
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.blue]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(Angle(degrees: animationValue))
                    .onAppear {
                        withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                            animationValue = 360
                        }
                    }

                // Icon - different for RAG vs Perplexity
                Image(systemName: isRAGEnabled ? "brain.head.profile" : "doc.text.magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundColor(.green)
            }
            .padding(.bottom, 10)

            Text(isRAGEnabled ? "Finding Related Research" : "Searching Academic Literature")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            // Animated ellipsis for "Searching" text
            AnimatedDotsView(dotOpacities: $dotOpacities)
                .padding(.bottom, 20)

            // Multi-step indicator - different steps for RAG vs Perplexity
            StepIndicatorView(searchStepIndex: searchStepIndex, isRAGMode: isRAGEnabled)
                .padding(.horizontal, 32)

            Text(isRAGEnabled
                 ? "Using AI to find semantically similar papers from PubMed"
                 : "Finding the most relevant papers from PubMed, arXiv, and academic journals")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 32)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, minHeight: 400) // Fixed minimum height to prevent layout shifts
        .padding(.vertical, 30)
    }
}

// Further breaking down into smaller components
struct AnimatedDotsView: View {
    @Binding var dotOpacities: [Double]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .opacity(dotOpacities[index])
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(0.2 * Double(index)),
                        value: dotOpacities[index]
                    )
                    .onAppear {
                        withAnimation(Animation.easeInOut(duration: 0.5).repeatForever().delay(0.2 * Double(index))) {
                            dotOpacities[index] = dotOpacities[index] == 0.3 ? 1.0 : 0.3
                        }
                    }
            }
        }
        .frame(height: 8) // Fixed height to prevent layout shifts
    }
}

// Step indicator component
struct StepIndicatorView: View {
    let searchStepIndex: Int
    var isRAGMode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isRAGMode {
                // RAG pipeline steps
                stepRow(number: 1, text: "Analyzing poster content", isActive: true)
                stepRow(number: 2, text: "Searching PubMed database", isActive: searchStepIndex >= 2)
                stepRow(number: 3, text: "Enriching paper metadata", isActive: searchStepIndex >= 3)
                stepRow(number: 4, text: "Preparing results", isActive: searchStepIndex >= 4)
            } else {
                // Perplexity fallback steps
                stepRow(number: 1, text: "Searching 14 academic databases", isActive: true)
                stepRow(number: 2, text: "Extracting paper URLs & metadata", isActive: searchStepIndex >= 2)
                stepRow(number: 3, text: "Validating with PubMed", isActive: searchStepIndex >= 3)
                stepRow(number: 4, text: "Finalizing citations", isActive: searchStepIndex >= 4)
            }
        }
    }
    
    // Helper function to create the step row
    private func stepRow(number: Int, text: String, isActive: Bool) -> some View {
        HStack(spacing: 14) {
            // Number circle
            ZStack {
                Circle()
                    .fill(isActive ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 28, height: 28)
                
                Text("\(number)")
                    .fontWeight(.bold)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            // Step text
            Text(text)
                .font(.subheadline)
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}

struct RelatedResearchView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RelatedResearchView(posterScan: PosterScan(
                title: "Impact of Molecular Pathology Testing on Cancer Treatment Decisions",
                rawText: "Sample poster text about molecular pathology and cancer research",
                summaryPoints: [
                    "**Research Question**: How does molecular pathology testing impact treatment decisions?",
                    "**Methodology**: Analysis of 500 patient cases using NGS and immunohistochemistry",
                    "**Results**: 72% of cases had treatment modifications based on molecular findings",
                    "**Conclusions**: Molecular testing significantly improves precision medicine approaches"
                ],
                image: nil,
                date: Date()
            ))
            .environmentObject(DataStore())
        }
    }
}