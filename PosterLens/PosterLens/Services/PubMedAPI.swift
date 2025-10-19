import Foundation

/// A service for interacting with the PubMed E-Utilities API
class PubMedAPI {
    // MARK: - Properties
    
    // API key for PubMed E-Utilities
    private static let apiKey = "f88bcf7aa0815d63cf2ac0dbe80767693908"
    
    // Tool name for PubMed E-Utilities
    private static let tool = "PosterLens/1.0"
    
    // Email for PubMed E-Utilities (required parameter)
    private static let email = "app@posterlens.com"
    
    // Base URL for PubMed E-Utilities
    private static let baseURL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
    
    // MARK: - Public API Methods
    
    /// Enrich citations with metadata from PubMed
    /// - Parameter citations: An array of citations to enrich
    /// - Returns: An array of enriched citations
    static func enrichCitations(_ citations: [Citation]) async -> [Citation] {
        await withTaskGroup(of: Citation?.self) { group in
            for citation in citations {
                group.addTask {
                    await enrichCitation(citation)
                }
            }
            
            var enrichedCitations: [Citation] = []
            for await enrichedCitation in group {
                if let enrichedCitation = enrichedCitation {
                    enrichedCitations.append(enrichedCitation)
                }
            }
            
            return enrichedCitations
        }
    }
    
    /// Search PubMed for papers related to a query
    /// - Parameter query: The search query
    /// - Returns: An array of citations matching the query
    static func search(query: String) async -> [Citation] {
        // Step 1: Search for PMIDs matching the query
        guard let pmids = await searchForPMIDs(query: query) else {
            return []
        }
        
        // Step 2: Fetch metadata for each PMID
        return await fetchMetadataForPMIDs(pmids)
    }
    
    /// Validate and enrich a PubMed ID
    /// - Parameter pmid: The PubMed ID to validate
    /// - Returns: A citation with enriched metadata if valid, nil otherwise
    static func validatePMID(_ pmid: String) async -> Citation? {
        await fetchMetadata(for: pmid)
    }
    
    // MARK: - Private Helper Methods
    
    /// Enrich a single citation with metadata from PubMed
    /// - Parameter citation: The citation to enrich
    /// - Returns: An enriched citation if successful, nil otherwise
    private static func enrichCitation(_ citation: Citation) async -> Citation? {
        print("📚 Enriching citation: \(citation.title)")

        // Strategy 1A: Try PubMed URL (direct PMID)
        if citation.url?.contains("pubmed.ncbi.nlm.nih.gov") == true,
           let pmid = extractPMID(from: citation.url ?? "") {
            print("  ✅ Found PMID: \(pmid) - fetching metadata...")
            if let enriched = await fetchMetadata(for: pmid) {
                print("  ✅ Enriched with PubMed data:")
                print("     Authors: \(enriched.authors.prefix(2).joined(separator: ", "))")
                print("     Journal: \(enriched.journal ?? "N/A")")
                print("     Year: \(enriched.year.map(String.init) ?? "N/A")")
                return createEnrichedCitation(original: citation, pubmed: enriched)
            } else {
                print("  ⚠️ Failed to fetch metadata for PMID: \(pmid)")
            }
        }

        // Strategy 1B: Try PubMed Central URL (convert PMCID to PMID)
        else if citation.url?.contains("pmc.ncbi.nlm.nih.gov") == true,
                let pmcid = extractPMCID(from: citation.url ?? "") {
            print("  ✅ Found PMCID: \(pmcid) - converting to PMID...")
            if let pmid = await convertPMCIDToPMID(pmcid) {
                print("  ✅ Fetching metadata for PMID: \(pmid)...")
                if let enriched = await fetchMetadata(for: pmid) {
                    print("  ✅ Enriched with PubMed data:")
                    print("     Authors: \(enriched.authors.prefix(2).joined(separator: ", "))")
                    print("     Journal: \(enriched.journal ?? "N/A")")
                    print("     Year: \(enriched.year.map(String.init) ?? "N/A")")
                    return createEnrichedCitation(original: citation, pubmed: enriched)
                } else {
                    print("  ⚠️ Failed to fetch metadata for PMID: \(pmid)")
                }
            } else {
                print("  ⚠️ Failed to convert PMCID to PMID")
            }
        }

        // Strategy 2: Try DOI
        else if let doi = citation.doi, !doi.isEmpty {
            print("  ✅ Found DOI: \(doi) - searching PubMed...")
            if let enriched = await fetchMetadataByDOI(doi) {
                print("  ✅ Enriched with PubMed data via DOI")
                return createEnrichedCitation(original: citation, pubmed: enriched)
            } else {
                print("  ⚠️ No PubMed record found for DOI: \(doi)")
            }
        }

        // Strategy 2: Search by title and first author
        print("  🔍 Searching PubMed by title...")
        let searchQuery = buildSearchQuery(for: citation)
        if let pmids = await searchForPMIDs(query: searchQuery), !pmids.isEmpty {
            // Take the first (most relevant) result
            if let firstPMID = pmids.first, let enriched = await fetchMetadata(for: firstPMID) {
                // Verify the match by comparing titles
                let similarity = calculateTitleSimilarity(citation.title, enriched.title)
                print("  📊 Title similarity: \(Int(similarity * 100))%")
                if similarity > 0.7 { // 70% similarity threshold
                    print("  ✅ Match confirmed - enriching with PubMed data")
                    return createEnrichedCitation(original: citation, pubmed: enriched)
                } else {
                    print("  ⚠️ Title similarity too low (\(Int(similarity * 100))%) - keeping original")
                }
            }
        } else {
            print("  ⚠️ No PubMed results found for title search")
        }

        // If all strategies fail, return the original citation
        print("  ⚠️ Returning original citation (no enrichment)")
        return citation
    }
    
    /// Create an enriched citation by combining the original citation with PubMed metadata
    /// - Parameters:
    ///   - original: The original citation
    ///   - pubmed: The PubMed citation with enriched metadata
    /// - Returns: A combined citation with the best data from both sources
    private static func createEnrichedCitation(original: Citation, pubmed: Citation) -> Citation {
        return Citation(
            id: original.id,
            title: pubmed.title,  // Use PubMed's verified title
            authors: pubmed.authors.isEmpty ? original.authors : pubmed.authors, // Prefer PubMed authors
            journal: pubmed.journal ?? original.journal,
            year: pubmed.year ?? original.year,
            doi: nil, // Don't include DOI - we want PubMed links, not DOI.org links
            url: buildPubMedURL(pmid: extractPMID(from: pubmed.url ?? "") ?? ""), // Use proper PubMed URL
            abstract: pubmed.abstract ?? original.abstract,
            relevance: original.relevance // Keep original relevance explanation
        )
    }
    
    /// Calculate the similarity between two titles
    /// - Parameters:
    ///   - title1: The first title
    ///   - title2: The second title
    /// - Returns: A similarity score between 0 and 1
    private static func calculateTitleSimilarity(_ title1: String, _ title2: String) -> Double {
        // Normalize titles for comparison
        let normalized1 = normalizeTitle(title1)
        let normalized2 = normalizeTitle(title2)
        
        // Use Jaccard similarity for word sets
        let words1 = Set(normalized1.components(separatedBy: .whitespaces))
        let words2 = Set(normalized2.components(separatedBy: .whitespaces))
        
        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count
        
        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }
    
    /// Normalize a title for comparison
    /// - Parameter title: The title to normalize
    /// - Returns: A normalized title
    private static func normalizeTitle(_ title: String) -> String {
        return title.lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !["the", "a", "an", "and", "or", "of", "in", "on", "for", "to", "with"].contains($0) }
            .joined(separator: " ")
    }
    
    /// Build a search query for a citation
    /// - Parameter citation: The citation to build a query for
    /// - Returns: A PubMed search query
    private static func buildSearchQuery(for citation: Citation) -> String {
        var components: [String] = []
        
        // Add title in quotes
        if !citation.title.isEmpty {
            let cleanTitle = citation.title
                .replacingOccurrences(of: "[^a-zA-Z0-9\\s]", with: " ", options: .regularExpression)
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 3 }  // Only include words longer than 3 characters
                .prefix(6)  // Limit to first 6 significant words
                .joined(separator: " ")
            
            components.append("\"\(cleanTitle)\"[Title]")
        }
        
        // Add first author if available
        if let firstAuthor = citation.authors.first, !firstAuthor.isEmpty {
            let cleanAuthor = firstAuthor
                .replacingOccurrences(of: "[^a-zA-Z]", with: " ", options: .regularExpression)
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .first ?? ""
            
            if !cleanAuthor.isEmpty {
                components.append("\(cleanAuthor)[Author]")
            }
        }
        
        // Add year if available
        if let year = citation.year {
            components.append("\(year)[Date - Publication]")
        }
        
        // Join components with AND
        return components.joined(separator: " AND ")
    }
    
    /// Search for PMIDs matching a query
    /// - Parameter query: The search query
    /// - Returns: An array of PMIDs matching the query
    private static func searchForPMIDs(query: String) async -> [String]? {
        // Construct the URL for the esearch endpoint
        var components = URLComponents(string: "\(baseURL)/esearch.fcgi")
        components?.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "retmax", value: "5"),  // Limit to 5 results
            URLQueryItem(name: "sort", value: "relevance"),
            URLQueryItem(name: "retmode", value: "json"),
            URLQueryItem(name: "tool", value: tool),
            URLQueryItem(name: "email", value: email)
        ]
        
        if !apiKey.isEmpty {
            components?.queryItems?.append(URLQueryItem(name: "api_key", value: apiKey))
        }
        
        guard let url = components?.url else {
            print("Invalid URL for PubMed search")
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Parse the JSON response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let esearchResult = json["esearchresult"] as? [String: Any],
               let idList = esearchResult["idlist"] as? [String] {
                return idList
            }
        } catch {
            print("Error searching PubMed: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Fetch metadata for a list of PMIDs
    /// - Parameter pmids: The PMIDs to fetch metadata for
    /// - Returns: An array of citations with metadata
    private static func fetchMetadataForPMIDs(_ pmids: [String]) async -> [Citation] {
        await withTaskGroup(of: Citation?.self) { group in
            for pmid in pmids {
                group.addTask {
                    await fetchMetadata(for: pmid)
                }
            }
            
            var citations: [Citation] = []
            for await citation in group {
                if let citation = citation {
                    citations.append(citation)
                }
            }
            
            return citations
        }
    }
    
    /// Fetch metadata for a specific PMID
    /// - Parameter pmid: The PMID to fetch metadata for
    /// - Returns: A citation with metadata if successful, nil otherwise
    private static func fetchMetadata(for pmid: String) async -> Citation? {
        // Construct the URL for the esummary endpoint
        var components = URLComponents(string: "\(baseURL)/esummary.fcgi")
        components?.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "id", value: pmid),
            URLQueryItem(name: "retmode", value: "json"),
            URLQueryItem(name: "tool", value: tool),
            URLQueryItem(name: "email", value: email)
        ]
        
        if !apiKey.isEmpty {
            components?.queryItems?.append(URLQueryItem(name: "api_key", value: apiKey))
        }
        
        guard let url = components?.url else {
            print("Invalid URL for PubMed metadata fetch")
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Parse the JSON response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let pmidData = result[pmid] as? [String: Any] {
                
                // Extract metadata
                let title = pmidData["title"] as? String ?? ""
                let doiValue = pmidData["elocationid"] as? String ?? ""
                let doi = doiValue.starts(with: "doi:") ? String(doiValue.dropFirst(4)) : nil
                
                // Extract publication date
                var year: Int? = nil
                if let pubDate = pmidData["pubdate"] as? String {
                    let yearRegex = try NSRegularExpression(pattern: "(19|20)\\d{2}")
                    let range = NSRange(pubDate.startIndex..., in: pubDate)
                    if let match = yearRegex.firstMatch(in: pubDate, options: [], range: range),
                       let matchRange = Range(match.range, in: pubDate) {
                        year = Int(pubDate[matchRange])
                    }
                }
                
                // Extract authors
                var authors: [String] = []
                if let authorList = pmidData["authors"] as? [[String: Any]] {
                    authors = authorList.compactMap { authorData in
                        guard let name = authorData["name"] as? String else { return nil }
                        return name
                    }
                }
                
                // Extract journal
                var journal: String? = nil
                if let source = pmidData["source"] as? String {
                    journal = source
                }
                
                // Extract abstract by making another API call to efetch
                let abstract = await fetchAbstract(for: pmid)
                
                // Create and return the citation
                return Citation(
                    title: title,
                    authors: authors,
                    journal: journal,
                    year: year,
                    doi: doi,
                    url: buildPubMedURL(pmid: pmid),
                    abstract: abstract,
                    relevance: nil
                )
            }
        } catch {
            print("Error fetching PubMed metadata: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Fetch metadata for a specific DOI
    /// - Parameter doi: The DOI to fetch metadata for
    /// - Returns: A citation with metadata if successful, nil otherwise
    private static func fetchMetadataByDOI(_ doi: String) async -> Citation? {
        // Search for the DOI in PubMed
        guard let pmids = await searchForPMIDs(query: "\(doi)[DOI]") else {
            return nil
        }
        
        // If we found a match, fetch the metadata
        if let firstPMID = pmids.first {
            return await fetchMetadata(for: firstPMID)
        }
        
        return nil
    }
    
    /// Fetch the abstract for a specific PMID
    /// - Parameter pmid: The PMID to fetch the abstract for
    /// - Returns: The abstract if available, nil otherwise
    private static func fetchAbstract(for pmid: String) async -> String? {
        // Construct the URL for the efetch endpoint
        var components = URLComponents(string: "\(baseURL)/efetch.fcgi")
        components?.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "id", value: pmid),
            URLQueryItem(name: "retmode", value: "xml"),
            URLQueryItem(name: "rettype", value: "abstract"),
            URLQueryItem(name: "tool", value: tool),
            URLQueryItem(name: "email", value: email)
        ]
        
        if !apiKey.isEmpty {
            components?.queryItems?.append(URLQueryItem(name: "api_key", value: apiKey))
        }
        
        guard let url = components?.url else {
            print("Invalid URL for PubMed abstract fetch")
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            // Convert data to string
            if let xmlString = String(data: data, encoding: .utf8) {
                // Extract abstract text using a simple regex
                // Note: A proper XML parser would be more robust for production code
                let abstractPattern = "<AbstractText[^>]*>(.*?)</AbstractText>"
                if let regex = try? NSRegularExpression(pattern: abstractPattern, options: [.dotMatchesLineSeparators]),
                   let match = regex.firstMatch(in: xmlString, options: [], range: NSRange(xmlString.startIndex..., in: xmlString)),
                   let matchRange = Range(match.range(at: 1), in: xmlString) {
                    return String(xmlString[matchRange])
                }
            }
        } catch {
            print("Error fetching PubMed abstract: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Build a PubMed URL for a specific PMID
    /// - Parameter pmid: The PMID
    /// - Returns: A PubMed URL string
    private static func buildPubMedURL(pmid: String) -> String {
        return "https://pubmed.ncbi.nlm.nih.gov/\(pmid)/"
    }
    
    /// Extract a PMID from a PubMed URL
    /// - Parameter url: The PubMed URL
    /// - Returns: The PMID if available, nil otherwise
    private static func extractPMID(from url: String) -> String? {
        // Match patterns like https://pubmed.ncbi.nlm.nih.gov/12345678/
        let pattern = "pubmed\\.ncbi\\.nlm\\.nih\\.gov\\/(\\d+)"
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(url.startIndex..., in: url)
            if let match = regex.firstMatch(in: url, range: range),
               let matchRange = Range(match.range(at: 1), in: url) {
                return String(url[matchRange])
            }
        } catch {
            print("Error extracting PMID: \(error.localizedDescription)")
        }
        return nil
    }

    /// Extract a PMCID from a PubMed Central URL
    /// - Parameter url: The PMC URL
    /// - Returns: The PMCID if available, nil otherwise
    private static func extractPMCID(from url: String) -> String? {
        // Match patterns like https://pmc.ncbi.nlm.nih.gov/articles/PMC12345678/
        let pattern = "PMC(\\d+)"
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(url.startIndex..., in: url)
            if let match = regex.firstMatch(in: url, range: range),
               let matchRange = Range(match.range(at: 1), in: url) {
                return "PMC" + String(url[matchRange])
            }
        } catch {
            print("Error extracting PMCID: \(error.localizedDescription)")
        }
        return nil
    }

    /// Convert PMCID to PMID using PubMed ID Converter API
    /// - Parameter pmcid: The PMCID (e.g., "PMC12345678")
    /// - Returns: The corresponding PMID if available, nil otherwise
    private static func convertPMCIDToPMID(_ pmcid: String) async -> String? {
        // Use PubMed ID Converter API
        var components = URLComponents(string: "https://www.ncbi.nlm.nih.gov/pmc/utils/idconv/v1.0/")
        components?.queryItems = [
            URLQueryItem(name: "ids", value: pmcid),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "tool", value: tool),
            URLQueryItem(name: "email", value: email)
        ]

        guard let url = components?.url else {
            print("  ❌ Invalid URL for PMCID conversion")
            return nil
        }

        print("  🔗 ID Converter URL: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("  📡 ID Converter HTTP Status: \(httpResponse.statusCode)")
            }

            // Debug: Print raw response
            if let responseString = String(data: data, encoding: .utf8) {
                print("  📄 ID Converter Response: \(responseString)")
            }

            // Parse JSON response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("  📋 Parsed JSON: \(json)")

                if let records = json["records"] as? [[String: Any]] {
                    print("  📚 Found \(records.count) records")

                    if let firstRecord = records.first {
                        print("  📖 First record: \(firstRecord)")

                        // PMID can be either String or Int in the response
                        var pmidString: String? = nil

                        if let pmidStr = firstRecord["pmid"] as? String {
                            pmidString = pmidStr
                        } else if let pmidInt = firstRecord["pmid"] as? Int {
                            pmidString = String(pmidInt)
                        }

                        if let pmid = pmidString {
                            print("  ✅ Converted \(pmcid) → PMID: \(pmid)")
                            return pmid
                        } else {
                            print("  ⚠️ No 'pmid' field in record (tried both String and Int)")
                        }
                    } else {
                        print("  ⚠️ Records array is empty")
                    }
                } else {
                    print("  ⚠️ No 'records' field in JSON")
                }
            } else {
                print("  ❌ Failed to parse JSON response")
            }
        } catch {
            print("  ❌ Error converting PMCID to PMID: \(error.localizedDescription)")
        }

        return nil
    }
}