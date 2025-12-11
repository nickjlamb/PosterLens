# PosterLens Changelog

## Version 1.3 (Build 5) - 2024-12

### New Features
- **Perplexity Search API Integration** - Switched from Chat API to Search API for more accurate PubMed research discovery
- **Smart Categorisation** - Automatic detection and tagging of research categories with color-coded tags
- **Domain Filtering** - Only searches 14 trusted academic sources for Related Research

### Improvements
- Primary Endpoint extraction now only shows verbatim text when explicitly stated
- Enhanced FlowLayout for category tags
- Better UI/UX for tag display and organization
- Improved citation validation with PubMed metadata enrichment

### Under the Hood
- Added `CategoryExtractionService` for automatic research categorization
- Updated `PerplexityRelatedResearchService` to use Search API with domain filtering
- Enhanced error handling across all API services

---

## Version 1.2 (Build 4) - 2024-11

### New Features
- **Related Research Discovery** - Find similar academic papers using Perplexity API
- **PubMed Integration** - Automatic citation validation and enrichment
- **PDF Export** - Export poster summaries as PDF documents with images

### Improvements
- Enhanced citation formatting with Vancouver style
- Working PubMed links for all validated citations
- Better error recovery for failed API requests

### Under the Hood
- Added `PubMedAPI.swift` for citation validation
- Added `PDFExportService.swift` for document generation
- Implemented centralized error handling with `NetworkErrorHandler`

---

## Version 1.1 (Build 3) - 2023-10-05

### New Features
- Integrated OpenAI API for the Chat with AI feature
- Enhanced Related Research functionality with improved link handling
- Added PubMed integration for more reliable paper citations

### Improvements
- Fixed issue with broken links in Related Research
- Improved URL handling with PubMed fallback for DOI links
- Forced light mode to prevent random dark mode switching
- Enhanced loading animation for Related Research

### Under the Hood
- Added comprehensive error handling for API requests
- Implemented service caching for better performance
- Updated documentation with API integration details
- Improved debug logging for easier troubleshooting

## Version 1.0 (Build 2) - 2023-09-28

### Initial Features
- Scientific poster scanning and OCR
- AI-powered summary generation
- Question suggestions for authors
- Future research directions
- Basic history and scan management