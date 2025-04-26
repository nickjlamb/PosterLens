import Foundation

/// A model representing an academic citation related to a scientific poster
struct Citation: Codable, Identifiable, Equatable {
    /// Unique identifier for the citation
    let id: UUID
    
    /// The complete title of the paper
    let title: String
    
    /// List of authors (typically in "Last, First Initial." format)
    let authors: [String]
    
    /// Journal or conference name where the paper was published
    let journal: String?
    
    /// Publication year
    let year: Int?
    
    /// Digital Object Identifier for the paper
    let doi: String?
    
    /// URL where the paper can be accessed
    let url: String?
    
    /// Brief abstract or summary of the paper
    let abstract: String?
    
    /// Brief explanation of how this paper relates to the poster
    let relevance: String?
    
    /// Initialize a new Citation
    /// - Parameters:
    ///   - id: Unique identifier (defaults to a new UUID)
    ///   - title: Complete paper title
    ///   - authors: List of authors
    ///   - journal: Journal or conference name (optional)
    ///   - year: Publication year (optional)
    ///   - doi: Digital Object Identifier (optional)
    ///   - url: URL to access the paper (optional)
    ///   - abstract: Brief abstract or summary (optional)
    ///   - relevance: How this paper relates to the poster (optional)
    init(id: UUID = UUID(), title: String, authors: [String], journal: String? = nil,
         year: Int? = nil, doi: String? = nil, url: String? = nil, abstract: String? = nil,
         relevance: String? = nil) {
        self.id = id
        self.title = title
        self.authors = authors
        self.journal = journal
        self.year = year
        self.doi = doi
        self.url = url
        self.abstract = abstract
        self.relevance = relevance
    }
    
    /// Returns a formatted citation string in APA style
    var formattedCitation: String {
        let authorText: String
        if authors.isEmpty {
            authorText = "Unknown"
        } else if authors.count == 1 {
            authorText = authors[0]
        } else if authors.count == 2 {
            authorText = "\(authors[0]) & \(authors[1])"
        } else {
            authorText = "\(authors[0]) et al."
        }
        
        let yearText = year != nil ? " (\(year!))" : ""
        let titleText = ". \(title)"
        let journalText = journal != nil ? ". \(journal!)" : ""
        
        return "\(authorText)\(yearText)\(titleText)\(journalText)"
    }
    
    /// Returns a URL that can be used to access the paper
    var accessURL: URL? {
        if let doi = doi {
            return URL(string: "https://doi.org/\(doi)")
        } else if let url = url {
            return URL(string: url)
        }
        return nil
    }
    
    // Add this static function for Equatable conformance right here
    public static func == (lhs: Citation, rhs: Citation) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Sample Data
extension Citation {
    /// Creates a sample citation for preview and testing purposes
    static var sample: Citation {
        Citation(
            title: "Machine Learning Approaches for Scientific Poster Analysis",
            authors: ["Smith, J. A.", "Johnson, R. B.", "Williams, T. C."],
            journal: "Journal of Computer Vision Applications",
            year: 2023,
            doi: "10.1234/jcva.2023.0123",
            abstract: "This paper presents novel machine learning techniques for extracting and analyzing information from scientific posters.",
            relevance: "Uses similar computer vision techniques to extract text from scientific posters."
        )
    }
    
    /// Creates an array of sample citations for preview and testing purposes
    static var samples: [Citation] {
        [
            Citation(
                title: "Machine Learning Approaches for Scientific Poster Analysis",
                authors: ["Smith, J. A.", "Johnson, R. B.", "Williams, T. C."],
                journal: "Journal of Computer Vision Applications",
                year: 2023,
                doi: "10.1234/jcva.2023.0123",
                abstract: "This paper presents novel machine learning techniques for extracting and analyzing information from scientific posters.",
                relevance: "Uses similar computer vision techniques to extract text from scientific posters."
            ),
            Citation(
                title: "Automated Summarization of Academic Literature Using Large Language Models",
                authors: ["Chen, L.", "Garcia, M."],
                journal: "Computational Linguistics Conference",
                year: 2024,
                url: "https://example.com/papers/cls2024",
                abstract: "An evaluation of large language models for creating concise summaries of academic papers.",
                relevance: "Demonstrates similar summarization techniques to those used in this poster."
            ),
            Citation(
                title: "The Future of Scientific Communication: AI-Assisted Research Tools",
                authors: ["Patel, S.", "Kim, H.", "Müller, J.", "Okafor, E."],
                journal: "Nature Digital Science",
                year: 2022,
                doi: "10.1038/nds.2022.789",
                abstract: "This review examines how AI tools are transforming scientific communication and knowledge dissemination.",
                relevance: "Discusses the broader impact of AI tools like the one presented in this poster."
            )
        ]
    }
}
