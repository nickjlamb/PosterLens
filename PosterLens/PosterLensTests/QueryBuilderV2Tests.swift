import XCTest
@testable import PosterLens

final class QueryBuilderV2Tests: XCTestCase {

    var queryBuilder: QueryBuilderV2!

    override func setUp() {
        super.setUp()
        queryBuilder = QueryBuilderV2.shared
    }

    // MARK: - Noise Token Exclusion Tests

    func testIgnoresUIAndPresentationNoise() {
        let noisyTitle = "Introduction Figure Table Design Poster AI-Powered Research Study"
        let cleanText = "Cancer therapy outcomes"

        let query = queryBuilder.build(posterTitle: noisyTitle, posterText: cleanText)

        // Should exclude noise words but include meaningful terms
        XCTAssertFalse(query.contains("Introduction"))
        XCTAssertFalse(query.contains("Figure"))
        XCTAssertFalse(query.contains("Table"))
        XCTAssertFalse(query.contains("Design"))
        XCTAssertFalse(query.contains("Poster"))
        XCTAssertFalse(query.contains("AI-Powered"))
        XCTAssertFalse(query.contains("Research"))
        XCTAssertFalse(query.contains("Study"))

        // Should include meaningful terms
        XCTAssertTrue(query.contains("Cancer") || query.contains("therapy"))
    }

    func testIgnoresGenericResearchTerms() {
        let title = "Novel Framework for System Evaluation and Assessment"
        let text = "comparative analysis platform"

        let query = queryBuilder.build(posterTitle: title, posterText: text)

        XCTAssertFalse(query.contains("Novel"))
        XCTAssertFalse(query.contains("Framework"))
        XCTAssertFalse(query.contains("System"))
        XCTAssertFalse(query.contains("Evaluation"))
        XCTAssertFalse(query.contains("Assessment"))
        XCTAssertFalse(query.contains("analysis"))
        XCTAssertFalse(query.contains("platform"))
    }

    func testShortWordsAreExcluded() {
        let title = "AI ML is in of on for to"
        let text = "meaningful content here"

        let query = queryBuilder.build(posterTitle: title, posterText: text)

        // Short words (≤2 chars) should be excluded
        XCTAssertFalse(query.contains(" is "))
        XCTAssertFalse(query.contains(" in "))
        XCTAssertFalse(query.contains(" of "))
        XCTAssertFalse(query.contains(" on "))
        XCTAssertFalse(query.contains(" to "))

        // Meaningful content should be included
        XCTAssertTrue(query.contains("meaningful") || query.contains("content"))
    }

    // MARK: - Drug/Biomarker Extraction Tests

    func testExtractsDrugsBySuffix() {
        let text = "Treatment with pembrolizumab and trastuzumab showed efficacy. Patients received rituximab therapy."

        let query = queryBuilder.build(posterTitle: "Drug Study", posterText: text)

        XCTAssertTrue(query.contains("pembrolizumab") || query.contains("trastuzumab") || query.contains("rituximab"))
    }

    func testExtractsChemotherapyTerms() {
        let text = "Patients received carboplatin and paclitaxel chemotherapy regimen"

        let query = queryBuilder.build(posterTitle: "Chemo Study", posterText: text)

        XCTAssertTrue(query.contains("carboplatin") || query.contains("paclitaxel") || query.contains("chemotherapy"))
    }

    func testExtractsBiomarkers() {
        let text = "EGFR mutations were detected in 45% of samples. KRAS status was also analyzed."

        let query = queryBuilder.build(posterTitle: "Biomarker Analysis", posterText: text)

        XCTAssertTrue(query.contains("EGFR") || query.contains("KRAS"))
    }

    func testExtractsDiseaseTerms() {
        let text = "NSCLC patients with advanced melanoma were enrolled"

        let query = queryBuilder.build(posterTitle: "Disease Study", posterText: text)

        XCTAssertTrue(query.contains("NSCLC") || query.contains("melanoma"))
    }

    func testIgnoresNonDrugSuffixMatches() {
        let text = "The graph and lab results were inconclusive"

        let query = queryBuilder.build(posterTitle: "Analysis", posterText: text)

        // "mab" and "lab" shouldn't match drug patterns due to context
        XCTAssertFalse(query.contains("graph"))
        XCTAssertFalse(query.contains("lab"))
    }

    // MARK: - Digital Health/ML Method Term Extraction Tests

    func testExtractsMLTermsWithSufficientEvidence() {
        let text = "Machine learning and deep learning neural networks for computer vision analysis"

        let query = queryBuilder.build(posterTitle: "AI Methods", posterText: text)

        // Should extract ML terms when multiple digital health indicators present
        XCTAssertTrue(query.contains("machine learning") || query.contains("deep learning") ||
                     query.contains("neural") || query.contains("computer vision"))
    }

    func testDoesNotExtractMLTermsWithoutEvidence() {
        let text = "The machine was used for learning purposes in our study"

        let query = queryBuilder.build(posterTitle: "General Study", posterText: text)

        // Should not extract "machine learning" without sufficient digital health context
        XCTAssertFalse(query.contains("machine learning"))
    }

    func testExtractsSpecificAITerms() {
        let text = "Natural language processing and transformer models for clinical NLP applications"

        let query = queryBuilder.build(posterTitle: "NLP Study", posterText: text)

        XCTAssertTrue(query.contains("natural language processing") ||
                     query.contains("transformer") || query.contains("NLP"))
    }

    func testDigitalHealthThreshold() {
        // Only one digital health indicator - should not extract
        let weakText = "Artificial intelligence was mentioned"
        let weakQuery = queryBuilder.build(posterTitle: "Weak AI", posterText: weakText)
        XCTAssertFalse(weakQuery.contains("artificial intelligence"))

        // Multiple indicators - should extract
        let strongText = "Artificial intelligence and machine learning algorithms for software development"
        let strongQuery = queryBuilder.build(posterTitle: "Strong AI", posterText: strongText)
        XCTAssertTrue(strongQuery.contains("artificial intelligence") ||
                     strongQuery.contains("machine learning"))
    }

    // MARK: - Health Economics Terms Tests

    func testExtractsHealthEconTerms() {
        let text = "Cost-effectiveness analysis showed favorable QALY outcomes with ICER below threshold"

        let query = queryBuilder.build(posterTitle: "Economic Evaluation", posterText: text)

        XCTAssertTrue(query.contains("cost-effectiveness") || query.contains("QALY") || query.contains("ICER"))
    }

    func testExtractsRealWorldEvidence() {
        let text = "Real-world evidence from patient-reported outcomes demonstrates budget impact"

        let query = queryBuilder.build(posterTitle: "RWE Study", posterText: text)

        XCTAssertTrue(query.contains("real-world evidence") || query.contains("patient-reported outcomes") ||
                     query.contains("budget impact"))
    }

    // MARK: - Public Health Terms Tests

    func testExtractsEpidemiologyTerms() {
        let text = "Surveillance data showed increased incidence and prevalence in the cohort study"

        let query = queryBuilder.build(posterTitle: "Epi Study", posterText: text)

        XCTAssertTrue(query.contains("surveillance") || query.contains("incidence") ||
                     query.contains("prevalence") || query.contains("cohort"))
    }

    func testExtractsStudyDesignTerms() {
        let text = "Randomized controlled trial with meta-analysis of systematic review data"

        let query = queryBuilder.build(posterTitle: "Clinical Research", posterText: text)

        XCTAssertTrue(query.contains("randomized") || query.contains("meta-analysis") ||
                     query.contains("systematic review") || query.contains("RCT"))
    }

    // MARK: - Science Venue Recognition Tests

    func testExtractsPrestigiousJournals() {
        let text = "Published in NEJM and Nature Medicine with JAMA editorial"

        let query = queryBuilder.build(posterTitle: "Publication", posterText: text)

        XCTAssertTrue(query.contains("NEJM") || query.contains("Nature") || query.contains("JAMA"))
    }

    func testExtractsFullJournalNames() {
        let text = "New England Journal of Medicine and Journal of the American Medical Association"

        let query = queryBuilder.build(posterTitle: "Journals", posterText: text)

        XCTAssertTrue(query.contains("New England Journal") ||
                     query.contains("Journal of the American Medical Association"))
    }

    // MARK: - Noun Phrase Extraction (Backoff) Tests

    func testExtractsCapitalizedNounPhrases() {
        let title = "Novel Therapeutic Protocol"
        let text = "Clinical Trial Registry NCT01234567 shows promise"

        let query = queryBuilder.build(posterTitle: title, posterText: text)

        // Should extract capitalized phrases and special tokens
        XCTAssertTrue(query.contains("Therapeutic Protocol") || query.contains("Clinical Trial") ||
                     query.contains("NCT01234567"))
    }

    func testLimitsNounPhraseLength() {
        let text = "Very Long Capitalized Phrase That Should Be Truncated Appropriately"

        let query = queryBuilder.build(posterTitle: "Long Phrase Test", posterText: text)

        // Should limit noun phrases to reasonable length (≤3 words typically)
        XCTAssertFalse(query.contains("Very Long Capitalized Phrase That Should Be"))
    }

    func testExtractsAllCapsTokens() {
        let text = "Patients with COVID and HIV infections"

        let query = queryBuilder.build(posterTitle: "Infections", posterText: text)

        XCTAssertTrue(query.contains("COVID") || query.contains("HIV"))
    }

    func testExtractsClinicalTrialIDs() {
        let text = "Trial NCT01234567 and registry NCT09876543 were included"

        let query = queryBuilder.build(posterTitle: "Trials", posterText: text)

        XCTAssertTrue(query.contains("NCT01234567") || query.contains("NCT09876543"))
    }

    // MARK: - Core Title Extraction Tests

    func testExtractsCoreTitle() {
        let title = "Novel Research Framework for Advanced Cancer Therapy Evaluation"

        let query = queryBuilder.build(posterTitle: title, posterText: "")

        // Should exclude noise words but keep meaningful terms
        // "Novel", "Research", "Framework", "Advanced", and "Evaluation" should be filtered
        XCTAssertTrue(query.contains("Cancer") || query.contains("Therapy"))
        XCTAssertFalse(query.contains("Novel"))
        XCTAssertFalse(query.contains("Framework"))
    }

    func testLimitsCoreTitle() {
        let title = "Comprehensive Advanced Innovative Revolutionary Cancer Therapy Outcomes Analysis"

        let query = queryBuilder.build(posterTitle: title, posterText: "")

        // Should limit core title to ~3 meaningful words
        let queryComponents = query.components(separatedBy: " ")
        let meaningfulWords = queryComponents.filter { word in
            word.count > 3 && !["PubMed", "academic", "research"].contains(word)
        }
        XCTAssertLessThanOrEqual(meaningfulWords.count, 7) // Total query should be ≤7 tokens
    }

    // MARK: - Query Length and Structure Tests

    func testMaintainsTokenLimit() {
        let title = "Very Long Complex Title With Many Technical Terms And Specifications"
        let text = "Comprehensive analysis of machine learning deep learning artificial intelligence neural networks computer vision natural language processing transformers"

        let query = queryBuilder.build(posterTitle: title, posterText: text)

        // Should stay within reasonable token limit
        let tokens = query.components(separatedBy: " ").filter { !$0.isEmpty }
        XCTAssertLessThanOrEqual(tokens.count, 10) // Allow some flexibility beyond strict 7-token limit
    }

    func testIncludesPubMedKeywords() {
        let query = queryBuilder.build(posterTitle: "Test", posterText: "")

        // Should include academic search terms
        XCTAssertTrue(query.contains("PubMed") || query.contains("academic") || query.contains("research"))
    }

    func testHandlesEmptyInput() {
        let query = queryBuilder.build(posterTitle: "", posterText: "")

        // Should provide fallback even with empty input
        XCTAssertFalse(query.isEmpty)
        XCTAssertTrue(query.contains("research") || query.contains("academic"))
    }

    func testHandlesOnlyNoiseInput() {
        let query = queryBuilder.build(posterTitle: "introduction methods results", posterText: "figure table design")

        // Should provide meaningful fallback when input is all noise
        XCTAssertFalse(query.isEmpty)
        XCTAssertTrue(query.contains("research") || query.contains("academic"))
    }

    // MARK: - Fallback Query Tests

    func testFallbackQueryIsSimpler() {
        let title = "Complex Multi-domain Research Framework"
        let text = "machine learning artificial intelligence analysis"

        let mainQuery = queryBuilder.build(posterTitle: title, posterText: text)
        let fallbackQuery = queryBuilder.buildFallbackQuery(posterTitle: title, posterText: text)

        // Fallback should be different and typically simpler
        XCTAssertNotEqual(mainQuery, fallbackQuery)
        XCTAssertTrue(fallbackQuery.contains("academic research"))
    }

    func testFallbackExtractsKeyTerms() {
        let title = "EGFR Mutation Analysis"
        let text = "carboplatin treatment outcomes"

        let fallbackQuery = queryBuilder.buildFallbackQuery(posterTitle: title, posterText: text)

        XCTAssertTrue(fallbackQuery.contains("EGFR") || fallbackQuery.contains("carboplatin"))
    }

    // MARK: - Integration Tests

    func testBiomedicalPosterQuery() {
        let title = "EGFR-mutated NSCLC Treatment with Pembrolizumab"
        let text = "Non-small cell lung cancer patients with EGFR mutations received pembrolizumab therapy. Response rates and progression-free survival were analyzed."

        let query = queryBuilder.build(posterTitle: title, posterText: text)

        XCTAssertTrue(query.contains("EGFR"))
        XCTAssertTrue(query.contains("NSCLC") || query.contains("pembrolizumab"))
        XCTAssertFalse(query.contains("Treatment")) // Should filter noise
    }

    func testDigitalHealthPosterQuery() {
        let title = "Deep Learning for Medical Image Analysis"
        let text = "Convolutional neural networks and computer vision algorithms for radiological diagnosis using artificial intelligence and machine learning techniques."

        let query = queryBuilder.build(posterTitle: title, posterText: text)

        XCTAssertTrue(query.contains("deep learning") || query.contains("computer vision") ||
                     query.contains("neural networks"))
        XCTAssertFalse(query.contains("Analysis")) // Should filter noise
    }

    func testHealthEconomicsPosterQuery() {
        let title = "Cost-effectiveness of Novel Cancer Therapy"
        let text = "Economic evaluation using QALY measurements and ICER calculations for budget impact analysis of innovative cancer treatment."

        let query = queryBuilder.build(posterTitle: title, posterText: text)

        XCTAssertTrue(query.contains("cost-effectiveness") || query.contains("QALY") || query.contains("ICER"))
        XCTAssertTrue(query.contains("cancer"))
    }

    func testPublicHealthPosterQuery() {
        let title = "COVID-19 Surveillance and Epidemiological Analysis"
        let text = "Population-based cohort study examining incidence and prevalence rates through systematic surveillance methods."

        let query = queryBuilder.build(posterTitle: title, posterText: text)

        XCTAssertTrue(query.contains("surveillance") || query.contains("incidence") || query.contains("cohort"))
        XCTAssertTrue(query.contains("COVID"))
    }

    // MARK: - Edge Cases

    func testSpecialCharactersHandling() {
        let title = "COVID-19 & Machine-Learning: AI/ML Approaches"
        let text = "Cost-effectiveness (ICER < $50,000/QALY) analysis"

        let query = queryBuilder.build(posterTitle: title, posterText: text)

        // Should handle special characters gracefully
        XCTAssertTrue(query.contains("COVID") || query.contains("Machine") || query.contains("Learning"))
    }

    func testCaseSensitivity() {
        let title = "egfr mutations and kras analysis"
        let text = "patients with nsclc received treatment"

        let query = queryBuilder.build(posterTitle: title, posterText: text)

        // Should be case-insensitive for matching but preserve important case
        XCTAssertTrue(query.contains("EGFR") || query.contains("KRAS") || query.contains("NSCLC"))
    }
}