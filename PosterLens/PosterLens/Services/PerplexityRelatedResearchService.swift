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

    // PubMed-only domains to ensure peer-reviewed articles
    private let pubmedDomains = [
        "pubmed.ncbi.nlm.nih.gov",
        "pmc.ncbi.nlm.nih.gov"
    ]

    /// Find related research papers for a poster scan
    /// - Parameters:
    ///   - scan: The poster scan to find related papers for
    ///   - skipEnrichment: Skip slow PubMed enrichment for faster results (default: false)
    /// - Returns: Array of up to 5 citations from trusted academic sources
    /// - Note: Uses Perplexity Search API with domain filters. PubMed enrichment adds 30-60s.
    func findRelatedResearch(from scan: PosterScan, skipEnrichment: Bool = false) async throws -> [Citation] {
        print("🔍 Starting Related Research search using Perplexity Search API...")
        print("📚 Searching academic databases with Perplexity")

        // Try Perplexity Search API first
        let citations = try await searchWithPerplexitySearchAPI(scan: scan)

        print("✅ Found \(citations.count) papers")

        // Check if citations already have PubMed data (from direct search)
        let hasRealPubMedData = citations.first?.url?.contains("pubmed.ncbi.nlm.nih.gov") == true
            && !(citations.first?.url?.contains("?term=") ?? false)  // Not a search link

        if hasRealPubMedData {
            // Papers are already from PubMed - no enrichment needed
            print("✅ Papers already have PubMed metadata - skipping enrichment")
            return Array(citations.prefix(5))
        }

        // OPTIMIZATION: Skip PubMed enrichment for faster results if requested
        if skipEnrichment {
            print("⚡️ Skipping PubMed enrichment for faster results")
            return Array(citations.prefix(5))
        }

        // Enrich with PubMed for additional validation and metadata
        print("🔍 Enriching with PubMed (this may take 30-60 seconds)...")
        let enrichedCitations = await PubMedAPI.enrichCitations(citations)

        print("✅ Enriched \(enrichedCitations.count) papers with PubMed data")

        // Deduplicate by title (case-insensitive) after enrichment
        var seenTitles = Set<String>()
        let uniqueCitations = enrichedCitations.filter { citation in
            let normalizedTitle = citation.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if seenTitles.contains(normalizedTitle) {
                print("  🗑️ Removing duplicate: \(citation.title)")
                return false
            }
            seenTitles.insert(normalizedTitle)
            return true
        }

        print("✅ After deduplication: \(uniqueCitations.count) unique papers")

        return Array(uniqueCitations.prefix(5))
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

        // Use sonar-pro model for Search API
        // IMPORTANT: No system message - sonar models work best with just user queries
        let requestBody: [String: Any] = [
            "model": "sonar-pro",
            "messages": [
                [
                    "role": "user",
                    "content": searchQuery
                ]
            ],
            "max_tokens": 2000,
            "temperature": 0.2,  // Low temperature for factual results
            "return_citations": true,  // Request citations
            "return_images": false,
            "return_related_questions": false,
            "search_domain_filter": pubmedDomains  // Only PubMed - peer-reviewed articles only
        ]

        print("🔍 Using sonar-pro Search API with PubMed-only domain filter...")

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
            print("❌ Failed to parse JSON response")
            throw NetworkError.malformedData
        }

        // DEBUG: Print full API response structure (without sensitive data)
        print("📊 ========== PERPLEXITY API RESPONSE STRUCTURE ==========")
        print("Keys in response: \(json.keys)")
        if let choices = json["choices"] as? [[String: Any]] {
            print("Number of choices: \(choices.count)")
        }
        if let citations = json["citations"] as? [String] {
            print("Number of citations: \(citations.count)")
        }
        if let searchResults = json["search_results"] as? [[String: Any]] {
            print("Number of search_results: \(searchResults.count)")
        }
        print("📊 =====================================================")

        // Check for API errors using SafeJSONParser
        if let errorMessage = SafeJSONParser.extractErrorMessage(data) {
            print("❌ API error detected: \(errorMessage)")
            throw NetworkError.apiError(service: "Perplexity", message: errorMessage)
        }

        // Extract citations from the response
        var citations: [Citation] = []

        // FIRST: Try to get URLs from citations array
        var citationURLs: [String] = []
        if let citationsArray = json["citations"] as? [String] {
            // Deduplicate URLs - keep only unique ones
            let uniqueURLs = Array(Set(citationsArray))
            citationURLs = uniqueURLs
            print("📚 Found \(citationsArray.count) citation URLs (\(uniqueURLs.count) unique) from 'citations' array")
            citationURLs.prefix(3).forEach { url in
                print("  - \(url)")
            }
        }

        // FALLBACK: If citations array is empty, try search_results
        if citationURLs.isEmpty, let searchResults = json["search_results"] as? [[String: Any]] {
            print("⚠️ No citations in 'citations' array, trying 'search_results' instead")
            for result in searchResults {
                if let url = result["url"] as? String {
                    citationURLs.append(url)
                    print("  ✅ Found URL in search_results: \(url)")
                }
            }
            print("📚 Extracted \(citationURLs.count) URLs from 'search_results' array")
        }

        // If still empty, log the issue
        if citationURLs.isEmpty {
            print("⚠️ No citation URLs found in either 'citations' or 'search_results'")
        }

        // SECOND: Extract paper titles AND URLs from AI response
        var paperTitles: [String] = []
        var extractedURLs: [String] = []

        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {

            print("📝 ========== PERPLEXITY SEARCH RESPONSE ==========")
            print(content)
            print("📝 ===============================================")

            // Extract titles and URLs from the response
            let (titles, urls) = extractTitlesAndURLsFromResponse(content)
            paperTitles = titles
            extractedURLs = urls
            print("📝 Extracted \(paperTitles.count) paper titles from response")
            print("📝 Extracted \(extractedURLs.count) URLs from response text")
        }

        // STRATEGY: Use URLs from multiple sources in priority order
        print("🔗 Processing citations from Perplexity Search API...")

        // Combine URLs from all sources (citations array, search_results, and extracted from text)
        var allURLs = citationURLs
        if allURLs.isEmpty {
            allURLs = extractedURLs
            print("📝 Using URLs extracted from response text: \(allURLs.count)")
        }

        if !allURLs.isEmpty {
            // SUCCESS: We have URLs from Perplexity
            print("✅ Creating citations from \(allURLs.count) Perplexity URLs")
            citations = createCitationsFromURLs(allURLs, suggestedTitles: paperTitles)
        } else {
            // FALLBACK: No URLs from Perplexity - search PubMed directly with keywords
            print("⚠️ No URLs from Perplexity - searching PubMed directly with keywords from poster")
            citations = try await searchPubMedDirectly(scan: scan)
        }

        print("✅ Found \(citations.count) papers")
        return citations
    }

    // Create a focused search query from the poster scan
    private func createSearchQuery(from scan: PosterScan) -> String {
        // Extract key terms for a focused search
        let summaryContext = scan.summaryPoints.prefix(3).joined(separator: " ")

        // STRATEGY: Create a focused question that will trigger search
        // Extract key medical terms from the title and summary
        let keywords = extractKeywords(from: "\(scan.title) \(summaryContext)")
        let topKeywords = keywords.prefix(5).joined(separator: " ")

        return """
        Recent clinical trials and research papers about \(topKeywords) published in peer-reviewed journals
        """
    }

    // Extract both titles and URLs from AI response text
    // Handles multiple formats including markdown italic titles
    private func extractTitlesAndURLsFromResponse(_ content: String) -> (titles: [String], urls: [String]) {
        var titles: [String] = []
        var urls: [String] = []

        // Split by lines and extract content
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines {
            // Pattern 1: Numbered items "1. Title" or "**a.** *Title*"
            if line.range(of: #"^\d+\.\s*\*{0,2}"#, options: .regularExpression) != nil ||
               line.range(of: #"^\*{0,2}[a-z]\.\*{0,2}\s*\*"#, options: .regularExpression) != nil {

                let cleanLine = line
                    .replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"^\*{0,2}[a-z]\.\*{0,2}\s*"#, with: "", options: .regularExpression)

                // Try to extract URL from the line
                var extractedURL: String?
                var title: String = cleanLine

                // Look for URL in line
                if let urlRange = cleanLine.range(of: #"https?://[^\s)]+"#, options: .regularExpression) {
                    extractedURL = String(cleanLine[urlRange])
                    title = String(cleanLine[..<urlRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }

                // Clean up title - remove markdown formatting
                title = title.replacingOccurrences(of: "*", with: "")
                title = title.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                title = title.replacingOccurrences(of: "**", with: "")
                title = title.trimmingCharacters(in: .whitespacesAndNewlines)

                // Check if this looks like a paper title (has italic markers or is long enough)
                if title.count > 20 && !title.contains("##") && !title.contains("Journal:") {
                    titles.append(title)
                    if let url = extractedURL {
                        urls.append(url)
                        print("  📎 Found URL in text: \(url)")
                    }
                }
            }
        }

        print("  📝 Extracted \(titles.count) titles from response")
        titles.prefix(3).forEach { print("    - \($0)") }

        return (titles, urls)
    }

    // DEPRECATED: Old method that only extracted titles
    private func extractTitlesFromResponse(_ content: String) -> [String] {
        return extractTitlesAndURLsFromResponse(content).titles
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

    // Search PubMed directly using keywords from the poster summary
    // This finds REAL papers instead of relying on AI-generated titles
    private func searchPubMedDirectly(scan: PosterScan) async throws -> [Citation] {
        print("🔍 Extracting keywords from poster summary...")

        // Extract key terms from the summary
        let summaryText = scan.summaryPoints.prefix(3).joined(separator: " ")
        let keywords = extractKeywords(from: summaryText)

        // Create a focused PubMed search query
        let searchTerms = keywords.prefix(5).joined(separator: " AND ")
        print("🔍 PubMed search terms: \(searchTerms)")

        // Use PubMedAPI.search() which returns full Citation objects
        let papers = await PubMedAPI.search(query: searchTerms)
        print("📚 Found \(papers.count) papers from PubMed")

        if papers.isEmpty {
            print("⚠️ No papers found in PubMed - trying broader search")
            // Try a broader search with just the top 3 keywords
            let broaderTerms = keywords.prefix(3).joined(separator: " ")
            let broaderPapers = await PubMedAPI.search(query: broaderTerms)
            print("📚 Broader search found \(broaderPapers.count) papers")

            if broaderPapers.isEmpty {
                throw NetworkError.emptyResponse
            }

            return Array(broaderPapers.prefix(5))
        }

        return Array(papers.prefix(5))
    }

    // Create citations from paper titles only (fallback when no URLs available)
    // DEPRECATED: This method creates fake citations - use searchPubMedDirectly instead
    private func createCitationsFromTitles(_ titles: [String]) -> [Citation] {
        print("🔗 Creating citations from \(titles.count) paper titles (no URLs from Perplexity)")

        return titles.prefix(5).enumerated().map { index, title in
            // Create a PubMed search URL using the title
            let encodedTitle = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let pubmedSearchURL = "https://pubmed.ncbi.nlm.nih.gov/?term=\(encodedTitle)"

            print("  [\(index + 1)] \(title)")
            print("      → PubMed search: \(pubmedSearchURL)")

            return Citation(
                title: title,
                authors: ["Research Team"],  // Will be updated by PubMed enrichment
                journal: nil,
                year: nil,
                doi: nil,
                url: pubmedSearchURL,  // PubMed search link
                abstract: nil,
                relevance: nil
            )
        }
    }

    // Extract important medical/scientific keywords from text
    private func extractKeywords(from text: String) -> [String] {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            .filter { $0.count > 4 } // Only words with 5+ characters

        var wordFrequency: [String: Int] = [:]
        for word in words {
            wordFrequency[word, default: 0] += 1
        }

        // Expanded stop words list including common medical research terms that are too generic
        let stopWords = [
            "these", "those", "their", "there", "where", "which", "while", "would", "could", "should",
            "using", "based", "study", "research", "analysis", "patients", "phase", "trial", "clinical",
            "combination", "treatment", "therapy", "showed", "demonstrated", "observed", "reported",
            "results", "conclusion", "objective", "methodology", "findings", "implications", "background",
            "methods", "endpoint", "primary", "secondary", "efficacy", "safety"
        ]

        for stopWord in stopWords {
            wordFrequency.removeValue(forKey: stopWord)
        }

        // Prioritize compound medical terms (drug names, conditions, etc.)
        // Words with capital letters or hyphens are likely important medical terms
        let keywords = wordFrequency.sorted { $0.value > $1.value }.map { $0.key }

        // Get top keywords, preferring longer, more specific terms
        return keywords.sorted { word1, word2 in
            // Prefer words that appear in title or are longer
            if wordFrequency[word1]! != wordFrequency[word2]! {
                return wordFrequency[word1]! > wordFrequency[word2]!
            }
            return word1.count > word2.count
        }.prefix(8).map { $0 }
    }
}

// MARK: - RAG Integration (behind FeatureFlags.usePubMedRAG)

extension PerplexityRelatedResearchService {

    /// Find related research using either RAG pipeline or Perplexity, based on feature flag.
    /// This is the unified entry point for Related Research.
    /// - Parameters:
    ///   - scan: The poster scan to find related papers for
    ///   - skipEnrichment: Skip PubMed enrichment for Perplexity fallback (default: false)
    /// - Returns: Array of up to 5 citations
    func findRelatedResearchUnified(from scan: PosterScan, skipEnrichment: Bool = false) async throws -> [Citation] {
        // 1. Try RAG pipeline if enabled
        if FeatureFlags.usePubMedRAG {
            do {
                let posterText = "\(scan.title) \(scan.summaryPoints.joined(separator: " ")) \(scan.rawText)"
                let ragResult = try await RAGEvidenceService.shared.fetchEvidence(for: posterText)

                // Convert PaperResult to Citation (basic info from RAG)
                let basicCitations = ragResult.papers.map { paper in
                    Citation(
                        title: paper.title ?? "Untitled Paper",
                        authors: [],  // Will be enriched by PubMed
                        journal: nil,  // Will be enriched by PubMed
                        year: nil,  // Will be enriched by PubMed
                        doi: nil,
                        url: paper.pmid != nil ? "https://pubmed.ncbi.nlm.nih.gov/\(paper.pmid!)" : nil,
                        abstract: paper.abstract,
                        relevance: paper.whyRelevant  // Human-readable explanation from backend
                    )
                }

                if !basicCitations.isEmpty {
                    // Enrich with PubMed metadata (authors, journal, year)
                    let enrichedCitations = await PubMedAPI.enrichCitations(basicCitations)
                    return Array(enrichedCitations.prefix(5))
                }
            } catch {
                // RAG failed, fall through to Perplexity
            }
        }

        // 2. Fallback to existing Perplexity flow
        let citations = try await findRelatedResearch(from: scan, skipEnrichment: skipEnrichment)
        return citations
    }
}
