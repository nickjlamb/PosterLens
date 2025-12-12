struct PaperResult: Decodable {
    let title: String?
    let abstract: String?
    let pmid: String?
    let score: Double?
    let whyRelevant: String?

    enum CodingKeys: String, CodingKey {
        case title
        case abstract
        case pmid
        case score
        case whyRelevant = "why_relevant"
    }
}

struct EvidenceResult: Decodable {
    let status: String
    let papers: [PaperResult]
    let metadata: Metadata?

    struct Metadata: Decodable {
        let version: String?
        let timestamp: String?
        let textLength: Int?
        let note: String?

        enum CodingKeys: String, CodingKey {
            case version
            case timestamp
            case textLength = "text_length"
            case note
        }
    }
}
