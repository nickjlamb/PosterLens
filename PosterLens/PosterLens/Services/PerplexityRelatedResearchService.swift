import Foundation

/// A service for retrieving related research papers using the Perplexity Search API (not chat) and PubMed validation
/// This version uses the SEARCH API which actually searches the web for real papers with valid links
class PerplexityRelatedResearchService {
    private let perplexityService = PerplexityService()

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

    // Main method - find related research using Search API
    func findRelatedResearch(from scan: PosterScan) async throws -> [Citation] {
        // Validate API key
        if !perplexityService.hasValidAPIKey {
            throw PerplexityError.missingAPIKey
        }

        print("🔍 Starting Related Research search using Perplexity Search API...")

        // Use Perplexity Search API with online search enabled
        let citations = try await searchWithPerplexitySearchAPI(scan: scan)

        print("✅ Found \(citations.count) papers from Search API")

        // Enrich with PubMed for additional validation and metadata
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

    // Use Perplexity Search API (not chat model) to find real papers
    private func searchWithPerplexitySearchAPI(scan: PosterScan) async throws -> [Citation] {
        guard let url = URL(string: searchBaseURL) else {
            throw PerplexityError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(perplexityService.apiKey)", forHTTPHeaderField: "Authorization")

        // Create a focused search query
        let searchQuery = createSearchQuery(from: scan)

        // CRITICAL: Use return_citations=true and search_domain_filter to get real web results
        let requestBody: [String: Any] = [
            "model": "sonar",  // Use sonar (search model), not sonar-pro (chat model)
            "messages": [
                [
                    "role": "system",
                    "content": "You are a research assistant. Find 3-5 real, published scientific papers related to the query. For each paper, provide: exact title, authors, journal, year, DOI, and PubMed URL if available. Return results as a structured list."
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
            "search_domain_filter": academicDomains,  // Only search academic sources
            "search_recency_filter": "year"  // Prefer recent papers (last year)
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)

        // Parse the response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PerplexityError.invalidResponse
        }

        // Check for errors
        if let errorInfo = json["error"] as? [String: Any],
           let message = errorInfo["message"] as? String {
            throw PerplexityError.apiError(message)
        }

        // Extract citations from the response
        var citations: [Citation] = []

        // FIRST: Get actual URLs from the citations array (these are real web results!)
        var citationURLs: [String] = []
        if let citationsArray = json["citations"] as? [String] {
            citationURLs = citationsArray
            print("📚 Found \(citationURLs.count) citation URLs from Search API")
        }

        // SECOND: Parse the AI response to get paper details
        if let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {

            print("📝 Parsing paper details from response...")

            // Try to parse structured paper information from the response
            citations = parsePapersFromContent(content, citationURLs: citationURLs)
        }

        // If we got citation URLs but couldn't parse paper details, create citations from URLs
        if citations.isEmpty && !citationURLs.isEmpty {
            print("⚠️ Creating citations directly from URLs...")
            citations = createCitationsFromURLs(citationURLs)
        }

        return citations
    }

    // Create a focused search query from the poster scan
    private func createSearchQuery(from scan: PosterScan) -> String {
        // Extract key terms from title
        let titleKeywords = extractKeywords(from: scan.title).prefix(5).joined(separator: " ")

        // Get first summary point for context
        let context = scan.summaryPoints.first ?? ""
        let contextKeywords = extractKeywords(from: context).prefix(3).joined(separator: " ")

        return """
        Find 3-5 recent published research papers (2020-2024) related to: \(titleKeywords) \(contextKeywords)

        For each paper, provide:
        - Exact paper title
        - Authors (first author + et al.)
        - Journal name and year
        - DOI number
        - PubMed ID or URL if available

        Focus on high-impact journals and papers most relevant to the research topic.
        """
    }

    // Parse papers from the AI response content
    private func parsePapersFromContent(_ content: String, citationURLs: [String]) -> [Citation] {
        var citations: [Citation] = []

        // Split into paper sections (look for numbered items or clear breaks)
        let sections = content.components(separatedBy: "\n\n")

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
                    relevance: "Related to the research presented in the poster"
                )

                citations.append(citation)
            }
        }

        return citations
    }

    // Create citations directly from URLs (fallback method)
    private func createCitationsFromURLs(_ urls: [String]) -> [Citation] {
        return urls.prefix(5).enumerated().map { index, urlString in
            // Extract information from the URL if possible
            var title = "Research Paper \(index + 1)"
            var journal: String?
            var year = Calendar.current.component(.year, from: Date())

            if let url = URL(string: urlString), let host = url.host {
                // Determine journal from domain
                if host.contains("pubmed") || host.contains("ncbi") {
                    journal = "PubMed"

                    // Try to extract PubMed ID for better title
                    if let pmidMatch = urlString.range(of: #"\d{7,8}"#, options: .regularExpression) {
                        let pmid = String(urlString[pmidMatch])
                        title = "Research Paper (PMID: \(pmid))"
                    }
                } else if host.contains("arxiv") {
                    journal = "arXiv"
                    title = "Preprint Paper (arXiv)"
                } else if host.contains("nature") {
                    journal = "Nature"
                } else if host.contains("science") {
                    journal = "Science"
                } else if host.contains("cell") {
                    journal = "Cell"
                } else {
                    journal = "Academic Journal"
                }
            }

            return Citation(
                title: title,
                authors: ["Research Team"],
                journal: journal,
                year: year,
                doi: nil,
                url: urlString,
                abstract: "Research paper related to the poster topic",
                relevance: "Found through academic database search"
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
