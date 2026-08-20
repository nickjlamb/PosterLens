# Changelog

All notable changes to PosterLens are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html). App Store build numbers
are given alongside each version.

> Dates for 1.0 through 1.2 are taken from the commit history, which is the more reliable
> record; earlier revisions of this file carried dates that predate the repository.

## [Unreleased]

See [ROADMAP.md](ROADMAP.md) for what is being worked on.

---

## [2.0.0] — 2026-05-21 · Build 8

The sync and export release. Scans stop living on one device.

### Added
- **iCloud sync.** Scans are stored in the user's own iCloud container, with automatic
  fallback to local storage when iCloud is unavailable
- Foreground refresh of iCloud scans, with data-safety guards against clobbering local edits
- **Share and export from the poster summary**, straight to PDF
- Categories, research directions and related research now included in the exported PDF
- Search in Scan History, with keyboard dismissal
- "Generate categories" action for scans that were saved untagged
- Offline resilience: a retry path for summaries that failed while the network was down
- Image zoom, editable titles, and per-scan notes
- New app icon (P + viewfinder)

### Changed
- Onboarding redesigned onto the 2.0 design system
- Scans stored as per-scan files rather than one combined store, with a safe migration
- Home screen redesigned; solid tab bar, three-scan teaser, viewfinder scan icon
- Scan History and About page rebuilt on the white/native design language
- Categories broadened beyond oncology, with short tag labels enforced
- Scanning Guidelines simplified to fit one screen
- Raw OCR "Full Text Content" dropped from the exported PDF

### Fixed
- PDF sections now paginate instead of overlapping
- `**bold**` markdown renders correctly in exported PDFs
- Export goes straight to PDF; the glitchy intermediate modal and unused JSON export removed
- Dark navigation-bar chrome on white backgrounds; Related Research recoloured to brand blue
- iCloud entitlements committed — they were empty in the repository
- Xcode `UserInterfaceState.xcuserstate` no longer tracked

### Security
- `ITSAppUsesNonExemptEncryption=NO` declared for App Store submission

---

## [1.4.0] — 2025-12-12 · Build 6

The retrieval release. Related Research stops being a search wrapper and becomes a
retrieval pipeline.

### Added
- **PubMed RAG backend** behind `FeatureFlags.usePubMedRAG`: a Cloud Function
  (`evidence_v2`) doing Vertex AI embedding and BigQuery vector search over a PubMed corpus
- Deterministic re-ranking layer — recency, keyword overlap and specificity signals, kept
  small so semantic similarity stays dominant
- `why_relevant` explanations shown beneath each related paper
- Incremental corpus ingestion with PMID deduplication and year filtering

### Changed
- Explanation keywords filtered for biomedical relevance, so the reasons read naturally
- Project documentation updated to match the shipped state

---

## [1.3.0] — 2025-10-28 · Build 5

### Added
- **Smart categorisation** — automatic research-category detection with colour-coded tags,
  via a new `CategoryExtractionService`
- Domain filtering across 14 trusted academic sources for Related Research

### Changed
- **Perplexity Search API** replaces the Chat API for research discovery, which materially
  improved citation accuracy
- Primary endpoint is shown verbatim only when the poster explicitly states one
- `FlowLayout` improved for category tag display

### Fixed
- `FlowLayout` positioning in `CategoryDetailSheet`
- Citation validation and PubMed metadata enrichment made more robust

---

## [1.2.0] — 2025-10-16 · Build 4

### Added
- **Related Research discovery** with PubMed integration and PMC support
- **PDF export** of poster summaries, including images
- Centralised error handling: retry with exponential backoff, safe JSON parsing,
  user-facing messages
- Comprehensive API pipeline and error-handling documentation

### Changed
- Related Research response time cut from 60s+ to roughly 10s
- Citations formatted in Vancouver style, with preamble and stray markdown stripped
- Duplicate code consolidated across services

### Fixed
- Critical memory leaks; services moved to a singleton pattern
- Navigation-bar styling, sheet presentation and toolbar buttons aligned with iOS HIG
- Broken links in Related Research, with a PubMed fallback for unresolved DOIs

---

## [1.1.0] — 2025-05-04 · Build 3

### Added
- **Interactive chat** about poster content, with a suggested-questions grid
  (`SimpleChatView`)
- OpenAI integration powering chat responses
- PubMed integration for more reliable citations

### Changed
- Light mode forced, to stop unintended dark-mode switching
- Improved loading animation for Related Research

### Fixed
- Broken links in Related Research
- URL handling with a PubMed fallback for DOI links

---

## [1.0.0] — 2025-04-28 · Build 2

First working release.

### Added
- Scientific poster scanning with edge detection and on-device OCR via the Vision framework
- AI-generated structured summaries
- Suggested questions for poster authors
- Future research directions
- Scan history and management
- Launch screen and onboarding flow
- Haptic feedback and micro-interactions throughout

---

[Unreleased]: https://github.com/nickjlamb/PosterLens/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/nickjlamb/PosterLens/compare/v1.4.0...v2.0.0
[1.4.0]: https://github.com/nickjlamb/PosterLens/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/nickjlamb/PosterLens/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/nickjlamb/PosterLens/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/nickjlamb/PosterLens/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/nickjlamb/PosterLens/releases/tag/v1.0.0
