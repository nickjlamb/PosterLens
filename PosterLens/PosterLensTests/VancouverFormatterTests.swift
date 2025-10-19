import XCTest
@testable import PosterLens

final class VancouverFormatterTests: XCTestCase {

    // MARK: - Missing Fields Tests

    func testMinimalFieldsOnly() {
        // Test citation with only title and PMID
        let citation = CanonicalCitation(
            title: "Minimal Test Paper",
            authors: [],
            journal: nil,
            year: nil,
            volume: nil,
            issue: nil,
            pages: nil,
            pmid: "12345678",
            doi: nil,
            nct: nil,
            url: "https://pubmed.ncbi.nlm.nih.gov/12345678/",
            sourceKind: .peerReviewed
        )

        let formatted = CitationFormatter.vancouver(citation)

        XCTAssertTrue(formatted.contains("Minimal Test Paper."))
        XCTAssertTrue(formatted.contains("PMID:12345678"))
        XCTAssertFalse(formatted.isEmpty)
    }

    func testMissingAuthors() {
        // Test citation without authors but with other fields
        let citation = CanonicalCitation(
            title: "Authorless Research Paper",
            authors: [],
            journal: "Anonymous Journal",
            year: 2023,
            volume: "10",
            issue: "2",
            pages: "45-67",
            pmid: "87654321",
            doi: nil,
            nct: nil,
            url: "https://pubmed.ncbi.nlm.nih.gov/87654321/",
            sourceKind: .peerReviewed
        )

        let formatted = CitationFormatter.vancouver(citation)

        // Should start with title since no authors
        XCTAssertTrue(formatted.hasPrefix("Authorless Research Paper."))
        XCTAssertTrue(formatted.contains("Anonymous Journal"))
        XCTAssertTrue(formatted.contains("2023"))
        XCTAssertTrue(formatted.contains("10(2):45-67"))
        XCTAssertTrue(formatted.contains("PMID:87654321"))
    }

    func testMissingJournal() {
        let citation = CanonicalCitation(
            title: "Unjournal Paper",
            authors: ["Smith JA"],
            journal: nil,
            year: 2024,
            volume: nil,
            issue: nil,
            pages: nil,
            pmid: "11111111",
            doi: nil,
            nct: nil,
            url: "https://pubmed.ncbi.nlm.nih.gov/11111111/",
            sourceKind: .peerReviewed
        )

        let formatted = CitationFormatter.vancouver(citation)

        XCTAssertTrue(formatted.contains("Smith JA"))
        XCTAssertTrue(formatted.contains("Unjournal Paper."))
        XCTAssertTrue(formatted.contains("2024"))
        XCTAssertTrue(formatted.contains("PMID:11111111"))
        XCTAssertFalse(formatted.contains(";;")) // No double separators
    }

    func testMissingVolumeAndPages() {
        // Online-first publication with no volume/issue/pages
        let citation = CanonicalCitation(
            title: "Early Online Publication",
            authors: ["Wilson CD", "Brown EF"],
            journal: "Future Medicine",
            year: 2024,
            volume: nil,
            issue: nil,
            pages: nil,
            pmid: "99999999",
            doi: "10.1234/early.2024.001",
            nct: nil,
            url: "https://pubmed.ncbi.nlm.nih.gov/99999999/",
            sourceKind: .peerReviewed
        )

        let formatted = CitationFormatter.vancouver(citation)

        XCTAssertTrue(formatted.contains("Wilson CD, Brown EF"))
        XCTAssertTrue(formatted.contains("Early Online Publication."))
        XCTAssertTrue(formatted.contains("Future Medicine"))
        XCTAssertTrue(formatted.contains("2024"))
        XCTAssertTrue(formatted.contains("PMID:99999999"))
        // Should prioritize PMID over DOI
        XCTAssertFalse(formatted.contains("doi:"))
    }

    // MARK: - Long Author Lists Tests

    func testLongAuthorListWith6Authors() {
        let citation = CanonicalCitation(
            title: "Six Author Paper",
            authors: ["First A", "Second B", "Third C", "Fourth D", "Fifth E", "Sixth F"],
            journal: "Test Journal",
            year: 2023,
            pmid: "66666666",
            url: "https://pubmed.ncbi.nlm.nih.gov/66666666/",
            sourceKind: .peerReviewed
        )

        let formatted = CitationFormatter.vancouver(citation)

        // Should include all 6 authors (default max)
        XCTAssertTrue(formatted.contains("First A, Second B, Third C, Fourth D, Fifth E, Sixth F"))
        XCTAssertFalse(formatted.contains("et al."))
    }

    func testLongAuthorListWith7Authors() {
        let citation = CanonicalCitation(
            title: "Seven Author Paper",
            authors: ["First A", "Second B", "Third C", "Fourth D", "Fifth E", "Sixth F", "Seventh G"],
            journal: "Test Journal",
            year: 2023,
            pmid: "77777777",
            url: "https://pubmed.ncbi.nlm.nih.gov/77777777/",
            sourceKind: .peerReviewed
        )

        let formatted = CitationFormatter.vancouver(citation)

        // Should truncate to 6 authors + et al.
        XCTAssertTrue(formatted.contains("First A, Second B, Third C, Fourth D, Fifth E, Sixth F et al."))
        XCTAssertFalse(formatted.contains("Seventh G"))
    }

    func testCustomMaxAuthors() {
        let citation = CanonicalCitation(
            title: "Many Author Paper",
            authors: ["First A", "Second B", "Third C", "Fourth D"],
            journal: "Test Journal",
            year: 2023,
            pmid: "44444444",
            url: "https://pubmed.ncbi.nlm.nih.gov/44444444/",
            sourceKind: .peerReviewed
        )

        let formattedMax2 = CitationFormatter.vancouver(citation, maxAuthors: 2)

        XCTAssertTrue(formattedMax2.contains("First A, Second B et al."))
        XCTAssertFalse(formattedMax2.contains("Third C"))
    }

    // MARK: - DOI-only vs PMID-only Tests

    func testDOIOnlyNoPMID() {
        let citation = CanonicalCitation(
            title: "DOI Only Paper",
            authors: ["Doe JA"],
            journal: "DOI Journal",
            year: 2023,
            volume: "5",
            pmid: nil,
            doi: "10.1234/doi.only.2023",
            nct: nil,
            url: "https://doi.org/10.1234/doi.only.2023",
            sourceKind: .peerReviewed
        )

        let formatted = CitationFormatter.vancouver(citation)

        XCTAssertTrue(formatted.contains("Doe JA"))
        XCTAssertTrue(formatted.contains("DOI Only Paper."))
        XCTAssertTrue(formatted.contains("DOI Journal"))
        XCTAssertTrue(formatted.contains("doi:10.1234/doi.only.2023"))
        XCTAssertFalse(formatted.contains("PMID:"))
    }

    func testPMIDOnlyNoDOI() {
        let citation = CanonicalCitation(
            title: "PMID Only Paper",
            authors: ["Smith AB"],
            journal: "PubMed Journal",
            year: 2023,
            pmid: "55555555",
            doi: nil,
            nct: nil,
            url: "https://pubmed.ncbi.nlm.nih.gov/55555555/",
            sourceKind: .peerReviewed
        )

        let formatted = CitationFormatter.vancouver(citation)

        XCTAssertTrue(formatted.contains("Smith AB"))
        XCTAssertTrue(formatted.contains("PMID Only Paper."))
        XCTAssertTrue(formatted.contains("PubMed Journal"))
        XCTAssertTrue(formatted.contains("PMID:55555555"))
        XCTAssertFalse(formatted.contains("doi:"))
    }

    func testPMIDPriorityOverDOI() {
        // When both PMID and DOI are present, PMID should be prioritized
        let citation = CanonicalCitation(
            title: "Both Identifiers Paper",
            authors: ["Both AB"],
            journal: "Dual ID Journal",
            year: 2023,
            pmid: "12121212",
            doi: "10.1234/should.not.appear",
            nct: nil,
            url: "https://pubmed.ncbi.nlm.nih.gov/12121212/",
            sourceKind: .peerReviewed
        )

        let formatted = CitationFormatter.vancouver(citation)

        XCTAssertTrue(formatted.contains("PMID:12121212"))
        XCTAssertFalse(formatted.contains("doi:10.1234/should.not.appear"))
    }

    // MARK: - Clinical Trial Tests

    func testClinicalTrialWithNCT() {
        let citation = CanonicalCitation(
            title: "Phase III Randomized Controlled Trial",
            authors: ["Trial Lead AB", "Co-Investigator CD"],
            journal: "Clinical Trials Journal",
            year: 2023,
            pmid: "33333333",
            doi: nil,
            nct: "NCT01234567",
            url: "https://pubmed.ncbi.nlm.nih.gov/33333333/",
            sourceKind: .trial
        )

        let formatted = CitationFormatter.vancouver(citation)

        XCTAssertTrue(formatted.contains("Trial Lead AB, Co-Investigator CD"))
        XCTAssertTrue(formatted.contains("Phase III Randomized Controlled Trial."))
        XCTAssertTrue(formatted.contains("PMID:33333333"))
        XCTAssertTrue(formatted.contains("NCT:NCT01234567"))
    }

    func testNCTOnlyNoOtherIdentifiers() {
        let citation = CanonicalCitation(
            title: "Registry Only Trial",
            authors: ["Principal Investigator EF"],
            journal: nil,
            year: 2024,
            pmid: nil,
            doi: nil,
            nct: "NCT09876543",
            url: "https://clinicaltrials.gov/study/NCT09876543",
            sourceKind: .trial
        )

        let formatted = CitationFormatter.vancouver(citation)

        XCTAssertTrue(formatted.contains("Principal Investigator EF"))
        XCTAssertTrue(formatted.contains("Registry Only Trial."))
        XCTAssertTrue(formatted.contains("NCT:NCT09876543"))
        XCTAssertFalse(formatted.contains("PMID:"))
        XCTAssertFalse(formatted.contains("doi:"))
    }

    // MARK: - Edge Cases

    func testEmptyTitle() {
        let citation = CanonicalCitation(
            title: "",
            authors: ["Author AB"],
            journal: "Test Journal",
            year: 2023,
            pmid: "22222222",
            url: "https://pubmed.ncbi.nlm.nih.gov/22222222/",
            sourceKind: .peerReviewed
        )

        let formatted = CitationFormatter.vancouver(citation)

        XCTAssertTrue(formatted.contains("Author AB"))
        XCTAssertTrue(formatted.contains("Test Journal"))
        XCTAssertTrue(formatted.contains("PMID:22222222"))
        XCTAssertFalse(formatted.contains("..")) // No empty title period
    }

    func testNonNumericPages() {
        // Test electronic pages like "e12345"
        let citation = CanonicalCitation(
            title: "Electronic Page Numbers",
            authors: ["Electronic AB"],
            journal: "Electronic Journal",
            year: 2023,
            volume: "10",
            issue: "3",
            pages: "e12345",
            pmid: "88888888",
            url: "https://pubmed.ncbi.nlm.nih.gov/88888888/",
            sourceKind: .peerReviewed
        )

        let formatted = CitationFormatter.vancouver(citation)

        XCTAssertTrue(formatted.contains("10(3):e12345"))
        XCTAssertTrue(formatted.contains("PMID:88888888"))
    }

    func testCompletelyEmpty() {
        // Test with minimal required fields only
        let citation = CanonicalCitation(
            title: "",
            authors: [],
            journal: nil,
            year: nil,
            pmid: nil,
            doi: nil,
            nct: nil,
            url: "https://example.com",
            sourceKind: .peerReviewed
        )

        let formatted = CitationFormatter.vancouver(citation)

        // Should not be completely empty, should at least have some structure
        XCTAssertFalse(formatted.trimmingCharacters(in: .whitespaces).isEmpty)
    }
}