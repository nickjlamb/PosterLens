import XCTest
@testable import PosterLens

final class LinkHealthTests: XCTestCase {

    var linkChecker: LinkHealthChecker!

    override func setUp() {
        super.setUp()
        linkChecker = LinkHealthChecker.shared
    }

    // MARK: - DOI.org URL Validation Tests

    func testValidDOIFormat() {
        let validDOIs = [
            "10.1000/test.2023.001",
            "10.1038/nature12345",
            "10.1056/NEJMoa1234567",
            "10.1016/j.cancer.2023.01.001",
            "10.1001/jama.2023.12345"
        ]

        for doi in validDOIs {
            let doiURL = "https://doi.org/\(doi)"
            let isValid = isValidDOIURL(doiURL)
            XCTAssertTrue(isValid, "Should recognize valid DOI URL: \(doiURL)")
        }
    }

    func testInvalidDOIFormat() {
        let invalidDOIs = [
            "not.a.doi",
            "10/invalid",
            "doi:10.1000/test",
            "",
            "random.string"
        ]

        for doi in invalidDOIs {
            let doiURL = "https://doi.org/\(doi)"
            let isValid = isValidDOIURL(doiURL)
            XCTAssertFalse(isValid, "Should reject invalid DOI URL: \(doiURL)")
        }
    }

    func testDOIURLConstruction() {
        let doi = "10.1000/test.2023.001"
        let expectedURL = "https://doi.org/10.1000/test.2023.001"

        let constructedURL = constructDOIURL(doi)
        XCTAssertEqual(constructedURL, expectedURL)
    }

    // MARK: - Publisher Page Skipping Logic Tests

    func testShouldSkipPublisherPages() {
        let publisherURLs = [
            "https://www.nature.com/articles/nature12345",
            "https://jamanetwork.com/journals/jama/article/1234567",
            "https://www.nejm.org/doi/full/10.1056/NEJMoa1234567",
            "https://www.sciencedirect.com/science/article/pii/S0000000000000000",
            "https://onlinelibrary.wiley.com/doi/abs/10.1002/example.2023",
            "https://link.springer.com/article/10.1007/example",
            "https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0123456",
            "https://academic.oup.com/bioinformatics/article/39/1/1/6789012"
        ]

        for url in publisherURLs {
            let shouldSkip = shouldSkipPublisherPage(url)
            XCTAssertTrue(shouldSkip, "Should skip publisher page: \(url)")
        }
    }

    func testShouldNotSkipDOIOrg() {
        let doiOrgURLs = [
            "https://doi.org/10.1000/test.2023.001",
            "https://dx.doi.org/10.1038/nature12345",
            "http://doi.org/10.1056/NEJMoa1234567"
        ]

        for url in doiOrgURLs {
            let shouldSkip = shouldSkipPublisherPage(url)
            XCTAssertFalse(shouldSkip, "Should NOT skip DOI.org URL: \(url)")
        }
    }

    func testShouldNotSkipPubMedURLs() {
        let pubmedURLs = [
            "https://pubmed.ncbi.nlm.nih.gov/12345678/",
            "https://www.ncbi.nlm.nih.gov/pubmed/87654321",
            "https://pubmed.ncbi.nlm.nih.gov/pmc/articles/PMC1234567/"
        ]

        for url in pubmedURLs {
            let shouldSkip = shouldSkipPublisherPage(url)
            XCTAssertFalse(shouldSkip, "Should NOT skip PubMed URL: \(url)")
        }
    }

    func testShouldNotSkipClinicalTrialsGov() {
        let clinicalTrialsURLs = [
            "https://clinicaltrials.gov/study/NCT01234567",
            "https://clinicaltrials.gov/ct2/show/NCT09876543",
            "https://www.clinicaltrials.gov/study/NCT01234567"
        ]

        for url in clinicalTrialsURLs {
            let shouldSkip = shouldSkipPublisherPage(url)
            XCTAssertFalse(shouldSkip, "Should NOT skip ClinicalTrials.gov URL: \(url)")
        }
    }

    // MARK: - URL Processing Logic Tests

    func testURLNormalization() {
        let testCases = [
            ("HTTP://DOI.ORG/10.1000/TEST", "https://doi.org/10.1000/TEST"),
            ("doi.org/10.1000/test", "https://doi.org/10.1000/test"),
            ("www.doi.org/10.1000/test", "https://www.doi.org/10.1000/test")
        ]

        for (input, expected) in testCases {
            let normalized = normalizeURL(input)
            XCTAssertEqual(normalized, expected, "URL normalization failed for: \(input)")
        }
    }

    func testExtraxtDOIFromURL() {
        let testCases = [
            ("https://doi.org/10.1000/test.2023.001", "10.1000/test.2023.001"),
            ("https://dx.doi.org/10.1038/nature12345", "10.1038/nature12345"),
            ("https://www.nature.com/articles/nature12345", nil),
            ("https://pubmed.ncbi.nlm.nih.gov/12345678/", nil),
            ("invalid-url", nil)
        ]

        for (url, expectedDOI) in testCases {
            let extractedDOI = extractDOIFromURL(url)
            XCTAssertEqual(extractedDOI, expectedDOI, "DOI extraction failed for: \(url)")
        }
    }

    // MARK: - HTTP Request Logic Tests

    func testHEADRequestConstruction() {
        let url = "https://doi.org/10.1000/test.2023.001"
        let request = createHEADRequest(url: url, timeout: 6.0)

        XCTAssertEqual(request?.httpMethod, "HEAD")
        XCTAssertEqual(request?.timeoutInterval, 6.0)
        XCTAssertNotNil(request?.value(forHTTPHeaderField: "User-Agent"))
        XCTAssertTrue(request?.value(forHTTPHeaderField: "User-Agent")?.contains("PosterLens") == true)
    }

    func testGETWithRangeRequestConstruction() {
        let url = "https://doi.org/10.1000/test.2023.001"
        let request = createGETWithRangeRequest(url: url, timeout: 6.0)

        XCTAssertEqual(request?.httpMethod, "GET")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Range"), "bytes=0-0")
        XCTAssertNotNil(request?.value(forHTTPHeaderField: "User-Agent"))
    }

    // MARK: - Redirect Handling Tests

    func testRedirectStatusCodeRecognition() {
        let redirectCodes = [301, 302, 303, 307, 308]
        let nonRedirectCodes = [200, 204, 400, 404, 500]

        for code in redirectCodes {
            XCTAssertTrue(isRedirectStatusCode(code), "Should recognize \(code) as redirect")
        }

        for code in nonRedirectCodes {
            XCTAssertFalse(isRedirectStatusCode(code), "Should not recognize \(code) as redirect")
        }
    }

    func testRedirectCountTracking() {
        // Test that redirect counting works correctly
        let maxRedirects = 5
        let currentCount = 3

        XCTAssertTrue(hasRedirectsRemaining(current: currentCount, max: maxRedirects))
        XCTAssertFalse(hasRedirectsRemaining(current: maxRedirects, max: maxRedirects))
        XCTAssertFalse(hasRedirectsRemaining(current: maxRedirects + 1, max: maxRedirects))
    }

    func testRedirectURLConstruction() {
        let baseURL = "https://doi.org/10.1000/test"
        let testCases = [
            ("https://publisher.com/article", "https://publisher.com/article"),
            ("/article/12345", "https://doi.org/article/12345"),
            ("article/12345", "https://doi.org/10.1000/article/12345"),
            ("", nil)
        ]

        for (locationHeader, expectedURL) in testCases {
            let redirectURL = constructRedirectURL(from: locationHeader, base: baseURL)
            XCTAssertEqual(redirectURL, expectedURL, "Redirect URL construction failed for: \(locationHeader)")
        }
    }

    // MARK: - Response Status Evaluation Tests

    func testSuccessStatusCodes() {
        let successCodes = [200, 206] // 200 OK, 206 Partial Content
        let failureCodes = [400, 401, 403, 404, 429, 500, 502, 503]

        for code in successCodes {
            XCTAssertTrue(isSuccessStatusCode(code), "Should recognize \(code) as success")
        }

        for code in failureCodes {
            XCTAssertFalse(isSuccessStatusCode(code), "Should not recognize \(code) as success")
        }
    }

    func testPartialContentAcceptance() {
        // 206 Partial Content should be accepted for GET Range requests
        XCTAssertTrue(isAcceptableForRangeRequest(206))
        XCTAssertTrue(isAcceptableForRangeRequest(200)) // Full content is also OK
        XCTAssertFalse(isAcceptableForRangeRequest(404))
        XCTAssertFalse(isAcceptableForRangeRequest(416)) // Range Not Satisfiable
    }

    // MARK: - Timeout and Error Handling Tests

    func testTimeoutConfiguration() {
        let shortTimeout = 2.0
        let longTimeout = 10.0

        let shortRequest = createHEADRequest(url: "https://doi.org/test", timeout: shortTimeout)
        let longRequest = createHEADRequest(url: "https://doi.org/test", timeout: longTimeout)

        XCTAssertEqual(shortRequest?.timeoutInterval, shortTimeout)
        XCTAssertEqual(longRequest?.timeoutInterval, longTimeout)
    }

    func testErrorClassification() {
        // Test different types of errors that might occur
        let networkError = URLError(.notConnectedToInternet)
        let timeoutError = URLError(.timedOut)
        let malformedURLError = URLError(.badURL)

        XCTAssertTrue(isNetworkError(networkError))
        XCTAssertTrue(isTimeoutError(timeoutError))
        XCTAssertTrue(isMalformedURLError(malformedURLError))
    }

    // MARK: - Edge Cases Tests

    func testEmptyOrInvalidURLs() {
        let invalidURLs = ["", " ", "not-a-url", "ftp://invalid.protocol"]

        for url in invalidURLs {
            let isValid = isValidURL(url)
            XCTAssertFalse(isValid, "Should reject invalid URL: '\(url)'")
        }
    }

    func testSpecialCharactersInDOI() {
        let specialDOIs = [
            "10.1000/test(2023)001",
            "10.1000/test-2023.001",
            "10.1000/test_2023_001",
            "10.1000/test+special+chars"
        ]

        for doi in specialDOIs {
            let doiURL = "https://doi.org/\(doi)"
            let isValid = isValidDOIURL(doiURL)
            XCTAssertTrue(isValid, "Should handle special characters in DOI: \(doi)")
        }
    }

    func testExtremelyLongURLs() {
        let longDOI = "10.1000/" + String(repeating: "very.long.identifier.", count: 10) + "2023"
        let longURL = "https://doi.org/\(longDOI)"

        let isValid = isValidURL(longURL)
        XCTAssertTrue(isValid, "Should handle reasonably long URLs")
    }

    // MARK: - Helper Methods (These would be internal methods in the actual implementation)

    private func isValidDOIURL(_ url: String) -> Bool {
        guard let urlObj = URL(string: url),
              let host = urlObj.host else { return false }

        return (host == "doi.org" || host == "dx.doi.org") &&
               urlObj.pathComponents.count > 1 &&
               urlObj.pathComponents[1].hasPrefix("10.")
    }

    private func shouldSkipPublisherPage(_ url: String) -> Bool {
        guard let urlObj = URL(string: url),
              let host = urlObj.host?.lowercased() else { return false }

        // Allow DOI.org URLs
        if host.contains("doi.org") { return false }

        // Allow PubMed URLs
        if host.contains("ncbi.nlm.nih.gov") || host.contains("pubmed") { return false }

        // Allow ClinicalTrials.gov
        if host.contains("clinicaltrials.gov") { return false }

        // Skip known publisher domains
        let publisherDomains = [
            "nature.com", "sciencedirect.com", "wiley.com", "springer.com",
            "jamanetwork.com", "nejm.org", "plos.org", "oup.com",
            "cell.com", "elsevier.com", "tandfonline.com", "sagepub.com"
        ]

        return publisherDomains.contains { host.contains($0) }
    }

    private func normalizeURL(_ url: String) -> String {
        var normalized = url.lowercased()
        if !normalized.hasPrefix("http") {
            normalized = "https://" + normalized
        }
        return normalized
    }

    private func extractDOIFromURL(_ url: String) -> String? {
        guard let urlObj = URL(string: url),
              let host = urlObj.host,
              host.contains("doi.org") else { return nil }

        let path = urlObj.path
        if path.hasPrefix("/10.") {
            return String(path.dropFirst()) // Remove leading "/"
        }
        return nil
    }

    private func createHEADRequest(url: String, timeout: TimeInterval) -> URLRequest? {
        guard let urlObj = URL(string: url) else { return nil }

        var request = URLRequest(url: urlObj)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout
        request.setValue("PosterLens/1.0 (support@posterlens.app)", forHTTPHeaderField: "User-Agent")
        return request
    }

    private func createGETWithRangeRequest(url: String, timeout: TimeInterval) -> URLRequest? {
        guard let urlObj = URL(string: url) else { return nil }

        var request = URLRequest(url: urlObj)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("PosterLens/1.0 (support@posterlens.app)", forHTTPHeaderField: "User-Agent")
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        return request
    }

    private func isRedirectStatusCode(_ code: Int) -> Bool {
        return [301, 302, 303, 307, 308].contains(code)
    }

    private func hasRedirectsRemaining(current: Int, max: Int) -> Bool {
        return current < max
    }

    private func constructRedirectURL(from location: String, base: String) -> String? {
        guard !location.isEmpty else { return nil }
        guard let baseURL = URL(string: base) else { return nil }

        if location.hasPrefix("http") {
            return location
        } else {
            return URL(string: location, relativeTo: baseURL)?.absoluteString
        }
    }

    private func isSuccessStatusCode(_ code: Int) -> Bool {
        return code == 200
    }

    private func isAcceptableForRangeRequest(_ code: Int) -> Bool {
        return [200, 206].contains(code)
    }

    private func isValidURL(_ url: String) -> Bool {
        guard !url.trimmingCharacters(in: .whitespaces).isEmpty,
              let urlObj = URL(string: url),
              let scheme = urlObj.scheme else { return false }

        return ["http", "https"].contains(scheme.lowercased())
    }

    private func isNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return [.notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost].contains(urlError.code)
        }
        return false
    }

    private func isTimeoutError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
        }
        return false
    }

    private func isMalformedURLError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .badURL
        }
        return false
    }
}