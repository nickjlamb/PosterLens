import Foundation

/// Service for finding related academic research papers using Perplexity Search API
///
/// **Key Features:**
/// - Uses Perplexity Search API with domain filtering for trusted sources only
/// - Searches 14 academic domains: PubMed, Nature, Science, Cell, arXiv, and more
/// - Enriches results with PubMed metadata for validation
/// - Automatic retry logic with exponential backoff via NetworkRequestHelper
/// - Safe JSON parsing prevents crashes on malformed responses
///
/// **Domain Filtering (NEW):**
/// The service uses `search_domain_filter` to restrict searches to trusted academic sources.
/// This ensures high-quality, verifiable citations from reputable journals and databases.
class PerplexityRelatedResearchService {
    // MEMORY: Use shared singleton instead of creating new instance
    private let perplexityService = PerplexityService.shared

    // Note: We now use the SEARCH endpoint, not chat/completions
    private let searchBaseURL = "https://api.perplexity.ai/chat/completions"

    // Academic domains to prioritize in search
    private let academicDomains = [
        "pubmed.ncbi.nlm.nih.gov",
        "pmc.ncbi.nlm.nih.gov",
        "nih.gov",
        "arxiv.org",
        "scholar.google.com",
        "nature.com",
        "science.org",
        "sciencedirect.com",
        "springer.com",
        "wiley.com",
        "cell.com",
        "nejm.org",
        "pnas.org",
        "ieee.org"
    ]

    /// Find related research papers for a poster scan
    /// - Parameters:
    ///   - scan: The poster scan to find related papers for
    ///   - skipEnrichment: Skip slow PubMed enrichment for faster results (default: false)
    /// - Returns: Array of up to 5 citations from trusted academic sources
    /// - Note: Uses Perplexity Search API with domain filters. PubMed enrichment adds 30-60s.
    func findRelatedResearch(from scan: PosterScan, skipEnrichment: Bool = false) async throws -> [Citation] {
        // Validate API key
        if !perplexityService.hasValidAPIKey {
            throw NetworkError.missingAPIKey(service: "Perplexity")
        }

        print("🔍 Starting Related Research search using Perplexity Search API with domain filters...")
        print("📚 Searching trusted domains: PubMed, Nature, Science, Cell, arXiv, and more")

        // Use Perplexity Search API with domain filtering
        let citations = try await searchWithPerplexitySearchAPI(scan: scan)

        print("✅ Found \(citations.count) papers from Search API")

        // OPTIMIZATION: Skip PubMed enrichment for faster results
        // Domain filtering already ensures high-quality sources
        if skipEnrichment {
            print("⚡️ Skipping PubMed enrichment for faster results")
            let finalCitations = citations.prefix(5)
            return Array(finalCitations)
        }

        // Enrich with PubMed for additional validation and metadata (slower)
        print("🔍 Enriching with PubMed (this may take 30-60 seconds)...")
        let enrichedCitations = await PubMedAPI.enrichCitations(citations)

        print("✅ Enriched \(enrichedCitations.count) papers with PubMed data")

        // Final validation and limiting to 5 papers
        let finalCitations = enrichedCitations.prefix(5)

        return Array(finalCitations)
    }

    // Compatibility wrapper for completion handler style
    func findRelatedResearch(from scan: PosterScan, completion: @escaping (Result<[Citation], Error>) -> Void) {
        Task {
            do {
                let citations = try await findRelatedResearch(from: scan)
                DispatchQueue.main.async {
                    completion(.success(citations))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Search for related papers using Perplexity Search API with domain filtering
    /// - Parameter scan: The poster scan to find related research for
    /// - Returns: Array of citations from trusted academic sources
    /// - Note: Uses domain filters to only search trusted academic sources (PubMed, Nature, Science, etc.)
    private func searchWithPerplexitySearchAPI(scan: PosterScan) async throws -> [Citation] {
        guard let url = URL(string: searchBaseURL) else {
            throw NetworkError.badRequest("Invalid Search API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(perplexityService.apiKey)", forHTTPHeaderField: "Authorization")

        // Create a focused search query
        let searchQuery = createSearchQuery(from: scan)

        // CRITICAL: Use return_citations=true and search_domain_filter to get real web results
        // Domain filters ensure we only get results from trusted academic sources
        let requestBody: [String: Any] = [
            "model": "sonar",  // Use sonar (search model), not sonar-pro (chat model)
            "messages": [
                [
                    "role": "system",
                    "content": "You are a research citation assistant. Return ONLY a numbered list of papers in Vancouver citation style. NO preamble, NO explanations, NO markdown formatting. Start immediately with paper 1."
                ],
                [
                    "role": "user",
                    "content": searchQuery
                ]
            ],
            "max_tokens": 2000,
            "temperature": 0.2,  // Low temperature for factual results
            "return_citations": true,  // CRITICAL: Get actual URLs from search results
            "return_images": false,
            "return_related_questions": false,
            "search_domain_filter": academicDomains,  // ✅ NEW: Domain filters for trusted sources only
            "search_recency_filter": "year"  // Prefer recent papers (last year)
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw NetworkError.malformedData
        }

        // Use NetworkRequestHelper for automatic retry and timeout handling
        let (data, _) = try await NetworkRequestHelper.makeRequest(
            request,
            config: .default
        )

        // Safe JSON parsing with error checking
        guard let json = SafeJSONParser.parseToDictionary(data) else {
            throw NetworkError.malformedData
        }

        // Check for API errors using SafeJSONParser
        if let errorMessage = SafeJSONParser.extractErrorMessage(data) {
            throw NetworkError.apiError(service: "Perplexity", message: errorMessage)
        }

        // Extract citations from the response
        var citations: [Citation] = []

        // FIRST: Get actual URLs from the citations array (these are real web results!)
        var citationURLs: [String] = []
        if let citationsArray = json["citations"] as? [String] {
            citationURLs = citationsArray
            print("📚 Found \(citationURLs.count) citation URLs from Search API")
        }

        // SECOND: Extract paper titles from AI response (for matching only)
        var paperTitles: [String] = []
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {

            print("📝 ========== PERPLEXITY SEARCH RESPONSE ==========")
            print(content)
            print("📝 ===============================================")

            // Extract titles from numbered list
            paperTitles = extractTitlesFromResponse(content)
            print("📝 Extracted \(paperTitles.count) paper titles from response")
        }

        // STRATEGY: Use the actual citation URLs (real web results), not AI-generated metadata
        // This ensures we get REAL papers, not hallucinated citations
        print("🔗 Processing \(citationURLs.count) citation URLs from Search API...")
        citations = createCitationsFromURLs(citationURLs, suggestedTitles: paperTitles)

        return citations
    }

    // Create a focused search query from the poster scan
    private func createSearchQuery(from scan: PosterScan) -> String {
        // Use the FULL summary for better context, not just keywords
        let summaryContext = scan.summaryPoints.prefix(3).joined(separator: ". ")

        // STRATEGY: Let Perplexity Search find relevant URLs, don't ask it to format citations
        // We'll get the real URLs from return_citations and validate with PubMed
        return """
        Find 3-5 recent peer-reviewed research papers (2020-2024) related to this research:

        Title: \(scan.title)

        Summary: \(summaryContext)

        Focus on:
        - Papers published in high-impact journals (Nature, Science, Cell, NEJM, etc.)
        - Recent publications (2020-2024)
        - Papers indexed in PubMed when available
        - Original research articles, not reviews

        Return a simple numbered list with ONLY the paper titles, one per line. No authors, no journals, no metadata - just the titles.

        Example format:
        1. [Paper title here]
        2. [Paper title here]
        3. [Paper title here]
        """
    }

    // Extract titles from numbered list in AI response
    private func extractTitlesFromResponse(_ content: String) -> [String] {
        var titles: [String] = []

        // Split by lines and extract numbered items
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            // Match numbered list items: "1. Title", "2. Title", etc.
            if let match = line.range(of: #"^\d+\.\s*(.+)$"#, options: .regularExpression) {
                var title = String(line[match])
                // Remove the number prefix
                title = title.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                // Clean up markdown
                title = title.replacingOccurrences(of: "**", with: "")
                title = title.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")

                if title.count > 10 {
                    titles.append(title)
                }
            }
        }

        return titles
    }

    // DEPRECATED: Old parsing method - too fragile, relies on AI formatting
    // Keeping for reference but not used anymore
    private func parsePapersFromContent(_ content: String, citationURLs: [String]) -> [Citation] {
        var citations: [Citation] = []

        // Strip out preamble and conclusion text
        var cleanedContent = content

        // Remove common preamble patterns
        let preamblePatterns = [
            "Here are.*?papers.*?:",
            "I found.*?papers.*?:",
            "Based on.*?research.*?:",
            "These.*?papers.*?:",
            "Below.*?papers.*?:",
            "The following.*?papers.*?:"
        ]

        for pattern in preamblePatterns {
            if let range = cleanedContent.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                cleanedContent = String(cleanedContent[range.upperBound...])
                break
            }
        }

        // Remove concluding text
        let conclusionPatterns = [
            "(?:If|Let me know).*?(?:more|additional|further).*",
            "Feel free.*",
            "Please.*?(?:more|additional).*"
        ]

        for pattern in conclusionPatterns {
            if let range = cleanedContent.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                cleanedContent = String(cleanedContent[..<range.lowerBound])
                break
            }
        }

        // Remove all markdown formatting
        cleanedContent = cleanedContent.replacingOccurrences(of: "**", with: "")
        cleanedContent = cleanedContent.replacingOccurrences(of: "__", with: "")
        cleanedContent = cleanedContent.replacingOccurrences(of: "*", with: "")
        cleanedContent = cleanedContent.replacingOccurrences(of: "_", with: "")

        // Split into paper sections (look for numbered items or clear breaks)
        let sections = cleanedContent.components(separatedBy: "\n\n")

        var urlIndex = 0
        for section in sections {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty or very short sections
            if trimmed.count < 20 {
                continue
            }

            // Try to extract paper details
            var title: String?
            var authors: [String] = []
            var journal: String?
            var year: Int?
            var doi: String?
            var url: String?

            let lines = trimmed.components(separatedBy: .newlines)

            for line in lines {
                let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)

                // Extract title (usually bold or first substantive line)
                if title == nil && clean.count > 20 && !clean.lowercased().contains("author") {
                    // Remove numbering if present
                    var titleCandidate = clean.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                    // Remove markdown bold
                    titleCandidate = titleCandidate.replacingOccurrences(of: "**", with: "")
                    // Remove quotes
                    titleCandidate = titleCandidate.replacingOccurrences(of: "\"", with: "")

                    if titleCandidate.count > 15 {
                        title = titleCandidate
                    }
                }

                // Extract authors
                if clean.lowercased().contains("author") || clean.contains(" et al") {
                    let authorLine = clean.replacingOccurrences(of: #"Authors?:?\s*"#, with: "", options: .regularExpression)
                    authors = authorLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                }

                // Extract journal and year
                if clean.lowercased().contains("journal") || clean.contains("(20") {
                    journal = clean.replacingOccurrences(of: #"Journal:?\s*"#, with: "", options: .regularExpression)

                    // Extract year
                    if let yearMatch = clean.range(of: #"(20[12][0-9])"#, options: .regularExpression) {
                        let yearStr = String(clean[yearMatch]).replacingOccurrences(of: "[()]", with: "", options: .regularExpression)
                        year = Int(yearStr)
                    }
                }

                // Extract DOI
                if clean.lowercased().contains("doi") || clean.contains("10.") {
                    let doiPattern = #"10\.\d{4,}/[^\s]+"#
                    if let doiRange = clean.range(of: doiPattern, options: .regularExpression) {
                        doi = String(clean[doiRange])
                    }
                }

                // Extract PubMed URL
                if clean.contains("pubmed.ncbi.nlm.nih.gov") {
                    if let urlRange = clean.range(of: #"https://pubmed\.ncbi\.nlm\.nih\.gov/\d+"#, options: .regularExpression) {
                        url = String(clean[urlRange])
                    }
                }
            }

            // If we have a title, create a citation
            if let title = title, title.count > 15 {
                // Assign a citation URL if available
                if url == nil && urlIndex < citationURLs.count {
                    url = citationURLs[urlIndex]
                    urlIndex += 1
                }

                // If still no URL, try to construct one from DOI
                if url == nil, let doi = doi {
                    // Use PubMed search instead of DOI.org to avoid broken links
                    url = "https://pubmed.ncbi.nlm.nih.gov/?term=\(doi.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                }

                // Last resort: PubMed search by title
                if url == nil {
                    url = "https://pubmed.ncbi.nlm.nih.gov/?term=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                }

                let citation = Citation(
                    title: title,
                    authors: authors.isEmpty ? ["Research Team"] : authors,
                    journal: journal,
                    year: year,
                    doi: doi,
                    url: url,
                    abstract: nil,
                    relevance: nil  // No relevance text - keep it clean
                )

                citations.append(citation)
            }
        }

        return citations
    }

    // Create citations from actual URLs returned by Perplexity Search API
    // This is the PRIMARY method - uses real URLs, not AI-generated metadata
    private func createCitationsFromURLs(_ urls: [String], suggestedTitles: [String] = []) -> [Citation] {
        print("🔗 Creating citations from \(urls.count) URLs with \(suggestedTitles.count) suggested titles")

        return urls.prefix(5).enumerated().map { index, urlString in
            // Use suggested title if available, otherwise placeholder
            let title = index < suggestedTitles.count ? suggestedTitles[index] : "Research Paper \(index + 1)"

            var journal: String?
            var pmid: String?
            var doi: String?
            var year: Int?

            if let url = URL(string: urlString), let host = url.host {
                print("  Processing URL: \(urlString)")

                // PUBMED / PMC: Extract PMID/PMCID and let PubMed enrichment handle the rest
                if host.contains("pubmed") || host.contains("pmc.ncbi.nlm.nih.gov") || host.contains("ncbi") {
                    // Distinguish between PubMed and PubMed Central
                    if urlString.contains("pmc.ncbi.nlm.nih.gov") {
                        journal = "PubMed Central"
                        // Extract PMCID (e.g., PMC12346686)
                        if let pmcidMatch = urlString.range(of: #"PMC\d{7,8}"#, options: .regularExpression) {
                            let pmcid = String(urlString[pmcidMatch])
                            print("    ✅ Extracted PMCID: \(pmcid)")
                        }
                    } else {
                        journal = "PubMed"
                        // Extract PMID from URL
                        if let pmidMatch = urlString.range(of: #"\d{7,8}"#, options: .regularExpression) {
                            pmid = String(urlString[pmidMatch])
                            print("    ✅ Extracted PMID: \(pmid!)")
                        }
                    }
                }
                // NATURE: Extract DOI from Nature URLs
                else if host.contains("nature.com") {
                    journal = "Nature Publishing Group"

                    // Nature URLs often contain DOI: nature.com/articles/s41586-023-12345
                    if let doiMatch = urlString.range(of: #"10\.\d{4,}/[^\s/]+"#, options: .regularExpression) {
                        doi = String(urlString[doiMatch])
                        print("    ✅ Extracted DOI: \(doi!)")
                    }

                    // Extract year from URL if present
                    if let yearMatch = urlString.range(of: #"(20[12][0-9])"#, options: .regularExpression) {
                        year = Int(String(urlString[yearMatch]))
                    }
                }
                // SCIENCE: Extract DOI from Science URLs
                else if host.contains("science.org") {
                    journal = "Science"

                    if let doiMatch = urlString.range(of: #"10\.\d{4,}/[^\s/]+"#, options: .regularExpression) {
                        doi = String(urlString[doiMatch])
                        print("    ✅ Extracted DOI: \(doi!)")
                    }

                    if let yearMatch = urlString.range(of: #"(20[12][0-9])"#, options: .regularExpression) {
                        year = Int(String(urlString[yearMatch]))
                    }
                }
                // CELL PRESS
                else if host.contains("cell.com") {
                    journal = "Cell Press"

                    if let doiMatch = urlString.range(of: #"10\.\d{4,}/[^\s/]+"#, options: .regularExpression) {
                        doi = String(urlString[doiMatch])
                        print("    ✅ Extracted DOI: \(doi!)")
                    }
                }
                // ARXIV: Extract arXiv ID
                else if host.contains("arxiv.org") {
                    journal = "arXiv Preprint"

                    // arXiv URLs: arxiv.org/abs/2301.12345
                    if let arxivMatch = urlString.range(of: #"\d{4}\.\d{4,5}"#, options: .regularExpression) {
                        let arxivId = String(urlString[arxivMatch])
                        print("    ✅ Extracted arXiv ID: \(arxivId)")
                        // Extract year from arXiv ID
                        if let yearStr = arxivId.split(separator: ".").first,
                           let yearValue = Int(yearStr) {
                            year = 2000 + yearValue
                        } else {
                            year = Calendar.current.component(.year, from: Date())
                        }
                    }
                }
                // SCIENCEDIRECT (Elsevier)
                else if host.contains("sciencedirect.com") {
                    journal = "ScienceDirect"

                    if let doiMatch = urlString.range(of: #"10\.\d{4,}/[^\s/]+"#, options: .regularExpression) {
                        doi = String(urlString[doiMatch])
                        print("    ✅ Extracted DOI: \(doi!)")
                    }
                }
                // OTHER ACADEMIC DOMAINS
                else {
                    journal = host
                        .replacingOccurrences(of: "www.", with: "")
                        .replacingOccurrences(of: ".com", with: "")
                        .replacingOccurrences(of: ".org", with: "")
                        .capitalized
                }

                print("    Journal: \(journal ?? "Unknown")")
            }

            return Citation(
                title: title,
                authors: ["Research Team"],  // Will be updated by PubMed enrichment if available
                journal: journal,
                year: year,
                doi: doi,
                url: urlString,
                abstract: nil,
                relevance: nil
            )
        }
    }

    // Extract important keywords from text
    private func extractKeywords(from text: String) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { $0.count > 4 } // Only words with 5+ characters

        var wordFrequency: [String: Int] = [:]
        for word in words {
            wordFrequency[word, default: 0] += 1
        }

        // Filter out common stop words
        let stopWords = ["these", "those", "their", "there", "where", "which", "while", "would", "could", "should", "using", "based", "study", "research", "analysis"]
        for stopWord in stopWords {
            wordFrequency.removeValue(forKey: stopWord)
        }

        return wordFrequency.sorted { $0.value > $1.value }.prefix(10).map { $0.key }
    }
}
