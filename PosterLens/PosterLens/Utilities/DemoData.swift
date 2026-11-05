#if DEBUG
import UIKit

/// Debug-only demo content for App Store screenshots.
///
/// Launch the app with the argument `-PLDemoScans YES` (Xcode: Product > Scheme >
/// Edit Scheme > Run > Arguments, or `xcrun simctl launch ... -PLDemoScans YES`)
/// to replace History with three fictional example posters.
///
/// Everything here is compiled out of Release builds, so it can never ship.
/// The studies, authors and results are invented for illustration only.
@MainActor
enum DemoData {

    static let launchArgument = "-PLDemoScans"

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// Replaces all saved scans with the demo set and skips onboarding.
    static func seedIfRequested(dataStore: DataStore, onboarding: OnboardingManager) {
        guard isRequested else { return }

        // Remove existing scans (per-ID, so the new files can't be caught by the cleanup)
        dataStore.deleteScans(withIDs: dataStore.savedScans.map(\.id))

        let now = Date()
        for (index, poster) in posters.enumerated() {
            var scan = PosterScan(
                title: poster.title,
                rawText: poster.rawText,
                summaryPoints: poster.summary,
                image: renderPoster(title: poster.title, accent: poster.accent, seed: index),
                date: now.addingTimeInterval(TimeInterval(-index * 47 * 60)),
                authorQuestions: poster.questions,
                hasPermission: true,
                researchContext: ResearchContext(futureDirections: poster.directions),
                categories: poster.categories
            )
            scan.userNotes = nil
            dataStore.saveScan(scan)
        }

        if !onboarding.hasCompletedOnboarding {
            onboarding.completeOnboarding()
        }
        onboarding.showOnboarding = false
        print("🧪 DemoData: seeded \(posters.count) demo scans")
    }

    // MARK: - Content (fictional)

    private struct DemoPoster {
        let title: String
        let accent: UIColor
        let summary: [String]
        let questions: [String]
        let directions: [String]
        let categories: [PosterCategory]
        var rawText: String { ([title] + summary).joined(separator: "\n") }
    }

    private static let posters: [DemoPoster] = [
        DemoPoster(
            title: "Gut Microbiome Diversity Predicts Response to Immunotherapy in Advanced Melanoma",
            accent: UIColor(red: 0.17, green: 0.45, blue: 0.87, alpha: 1),
            summary: [
                "Objective: test whether baseline gut microbiome diversity predicts response to first-line checkpoint inhibitor therapy in advanced melanoma.",
                "Population: 212 patients with stage III–IV melanoma across 6 centres; median age 63; 41% female.",
                "Methods: stool samples collected before treatment and sequenced (16S rRNA); diversity measured with the Shannon index.",
                "Key result: patients in the highest diversity tertile had a 58% objective response rate versus 27% in the lowest (p<0.001).",
                "Safety: higher diversity was not associated with more immune-related adverse events.",
                "Conclusion: microbiome diversity is a promising, non-invasive biomarker that now needs prospective validation."
            ],
            questions: [
                "Did antibiotic use in the months before treatment affect diversity or response?",
                "Which bacterial taxa drove the association?",
                "Is diet being collected for the prospective validation cohort?"
            ],
            directions: [
                "Prospective validation in an independent multicentre cohort",
                "Trials of dietary or microbiome-modulating interventions alongside immunotherapy",
                "Shotgun metagenomics to identify functional pathways"
            ],
            categories: [
                PosterCategory(type: .field, name: "Oncology"),
                PosterCategory(type: .focus, name: "Biomarkers"),
                PosterCategory(type: .methods, name: "16S sequencing"),
                PosterCategory(type: .studyType, name: "Cohort study")
            ]
        ),
        DemoPoster(
            title: "Wearable Sensor Detection of Early Sepsis in Hospitalised Adults",
            accent: UIColor(red: 0.07, green: 0.60, blue: 0.53, alpha: 1),
            summary: [
                "Objective: assess whether continuous wrist-worn sensor data can flag sepsis earlier than standard ward observations.",
                "Population: 1,048 adults admitted to general medical wards over 14 months; 96 developed sepsis.",
                "Methods: heart rate, skin temperature and activity analysed by a gradient-boosted model, compared with NEWS2 scores.",
                "Key result: the model flagged sepsis a median of 6.2 hours before NEWS2 triggered, with an AUROC of 0.86.",
                "Limitations: single health system; 12% of sensor data lost to poor skin contact.",
                "Conclusion: wearable monitoring could support earlier escalation, pending a randomised implementation study."
            ],
            questions: [
                "How many false alerts per ward per day would the model generate?",
                "Did performance differ by skin tone or age?",
                "How would alerts fit into existing escalation pathways?"
            ],
            directions: [
                "Cluster-randomised trial of sensor-guided escalation",
                "External validation in a second hospital network",
                "Combining sensor data with routine laboratory results"
            ],
            categories: [
                PosterCategory(type: .field, name: "Critical care"),
                PosterCategory(type: .focus, name: "Early warning"),
                PosterCategory(type: .methods, name: "Machine learning"),
                PosterCategory(type: .studyType, name: "Prospective cohort")
            ]
        ),
        DemoPoster(
            title: "Sleep Duration and Ten-Year Cognitive Decline in Older Adults",
            accent: UIColor(red: 0.45, green: 0.30, blue: 0.80, alpha: 1),
            summary: [
                "Objective: examine the link between self-reported sleep duration in mid-to-late life and later cognitive decline.",
                "Population: 4,310 community-dwelling adults aged 55–75 at baseline, followed for 10 years.",
                "Methods: sleep duration by questionnaire; cognition assessed every 2 years with a standard test battery.",
                "Key result: both short (<6 h) and long (>9 h) sleep were linked to faster decline than 7–8 h of sleep.",
                "Adjustment: associations held after adjusting for depression, cardiovascular disease and education.",
                "Conclusion: sleep duration may be a modifiable risk marker for cognitive decline; causality is not established."
            ],
            questions: [
                "Was sleep measured objectively in any subgroup?",
                "Could early cognitive changes have altered sleep, rather than the reverse?",
                "Were sleep medications accounted for?"
            ],
            directions: [
                "Actigraphy sub-study to validate self-reported sleep",
                "Mendelian randomisation to test causality",
                "Sleep-improvement interventions with cognitive outcomes"
            ],
            categories: [
                PosterCategory(type: .field, name: "Neurology"),
                PosterCategory(type: .focus, name: "Cognitive ageing"),
                PosterCategory(type: .methods, name: "Longitudinal analysis"),
                PosterCategory(type: .studyType, name: "Cohort study")
            ]
        )
    ]

    // MARK: - Poster thumbnail rendering

    /// Draws a generic academic-poster layout: title band, three text columns
    /// and two simple charts. No real figures or logos.
    private static func renderPoster(title: String, accent: UIColor, seed: Int) -> UIImage {
        let size = CGSize(width: 1200, height: 1600)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor(white: 0.98, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            // Title band
            accent.setFill()
            cg.fill(CGRect(x: 0, y: 0, width: size.width, height: 300))
            let titleStyle = NSMutableParagraphStyle()
            titleStyle.alignment = .center
            (title as NSString).draw(
                in: CGRect(x: 60, y: 50, width: size.width - 120, height: 190),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 54, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: titleStyle
                ])
            UIColor.white.withAlphaComponent(0.7).setFill()
            cg.fill(CGRect(x: 380, y: 255, width: 440, height: 14))

            // Three columns
            let columnWidth: CGFloat = 340
            let gap: CGFloat = 45
            for column in 0..<3 {
                let x = 60 + CGFloat(column) * (columnWidth + gap)
                var y: CGFloat = 350
                for section in 0..<2 {
                    accent.withAlphaComponent(0.9).setFill()
                    cg.fill(CGRect(x: x, y: y, width: 180, height: 26))
                    y += 50
                    UIColor(white: 0.72, alpha: 1).setFill()
                    let lines = 7 + (column + section + seed) % 3
                    for line in 0..<lines {
                        let width = line == lines - 1 ? columnWidth * 0.6 : columnWidth
                        cg.fill(CGRect(x: x, y: y, width: width, height: 12))
                        y += 26
                    }
                    y += 30

                    // A chart in each column's second block
                    if section == 0 {
                        let chart = CGRect(x: x, y: y, width: columnWidth, height: 230)
                        UIColor.white.setFill()
                        cg.fill(chart)
                        UIColor(white: 0.85, alpha: 1).setStroke()
                        cg.stroke(chart, width: 2)
                        if (column + seed) % 2 == 0 {
                            for bar in 0..<5 {
                                let h = CGFloat(60 + ((bar * 37 + seed * 23 + column * 11) % 140))
                                accent.withAlphaComponent(0.35 + 0.12 * CGFloat(bar)).setFill()
                                cg.fill(CGRect(x: chart.minX + 25 + CGFloat(bar) * 62,
                                               y: chart.maxY - 20 - h, width: 40, height: h))
                            }
                        } else {
                            accent.setStroke()
                            cg.setLineWidth(6)
                            cg.move(to: CGPoint(x: chart.minX + 20, y: chart.maxY - 40))
                            for point in 1...6 {
                                let px = chart.minX + 20 + CGFloat(point) * 50
                                let py = chart.maxY - 40 - CGFloat((point * 29 + seed * 17) % 150)
                                cg.addLine(to: CGPoint(x: px, y: py))
                            }
                            cg.strokePath()
                        }
                        y = chart.maxY + 40
                    }
                }
            }

            // Footer band
            accent.withAlphaComponent(0.15).setFill()
            cg.fill(CGRect(x: 0, y: size.height - 90, width: size.width, height: 90))
        }
    }
}
#endif
