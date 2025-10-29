# PosterLens

An iOS app that transforms static scientific posters into interactive insights using OCR, AI, and advanced search capabilities.

[![App Store](https://img.shields.io/badge/Download%20on%20the-App%20Store-blue)](https://apps.apple.com/app/posterlens)
[![Swift](https://img.shields.io/badge/Swift-5.7+-orange)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-16.0+-blue)](https://www.apple.com/ios/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Featured in the [Perplexity AI Cookbook](https://docs.perplexity.ai/cookbook/showcase/posterlens)

## Overview

PosterLens helps researchers, medical science liaisons, and students quickly understand scientific posters at conferences. Simply scan any research poster with your camera and instantly get structured summaries, interactive chat, and related research discovery.

## Features

### 🔍 Advanced OCR & Text Extraction
- Automatic edge detection and poster capture
- High-accuracy text extraction using Apple Vision framework
- Specialized processing for scientific notation and terminology

### 🤖 AI-Powered Summarization
- Structured summaries using OpenAI GPT-3.5 Turbo
- Key information extraction:
  - Research Question/Objective
  - Patient Population
  - Primary Endpoint (verbatim extraction)
  - Methodology
  - Key Results
  - Conclusions & Implications

### 💬 Interactive Chat
- Ask questions about poster content
- Context-aware responses based on actual poster data
- Perfect for preparing questions for poster authors

### 🔬 Related Research Discovery
- **Perplexity Search API integration** for accurate research discovery
- PubMed-only domain filtering for high-quality citations
- Automatic citation validation and enrichment
- Link directly to PubMed articles

### 🏷️ Smart Categorisation
- Automatic research category detection
- Color-coded tags for easy organization:
  - **Cancer Types** (Red) - e.g., "Lung Cancer"
  - **Research Focus** (Purple) - e.g., "Quality of Life", "Biomarkers"
  - **Research Phases** (Green) - e.g., "Phase II", "Phase III"
  - **Treatment Modalities** (Blue) - e.g., "Chemotherapy", "Immunotherapy"

### 📚 Organization & Export
- Save multiple poster scans
- View scan history with category filtering
- Export summaries as PDF with poster images
- Share insights with colleagues

### 🔒 Privacy-Focused
- On-device OCR processing
- Secure API communications
- No account creation required
- No tracking or analytics

## Architecture

### Tech Stack
- **SwiftUI** - Modern declarative UI framework
- **MVVM** - Clean architecture pattern
- **Apple Vision** - OCR and text recognition
- **OpenAI API** - AI summarization and chat
- **Perplexity Search API** - Related research discovery
- **PubMed API** - Citation validation (no API key required)

### Key Components

#### Services Layer
- `OCRService` - Text extraction from images
- `OpenAIService` - AI summarization and chat
- `PerplexitySearchService` - Academic search via Search API
- `CategoryExtractionService` - Automatic category detection
- `PubMedAPI` - Citation enrichment and validation
- `PDFExportService` - Document generation

#### Data Models
- `PosterScan` - Core entity with text, summary, and metadata
- `PosterCategory` - Research categorization model
- `Citation` - Academic paper references
- `ResearchContext` - Author questions and future directions

#### Views
- `CameraView` - Live camera preview with scanning
- `SummaryView` - AI-generated content display
- `RelatedResearchView` - Academic paper discovery
- `SimpleChatView` - Poster-specific chat interface
- `CategoryDetailSheet` - Category organization

## Getting Started

### Prerequisites
- macOS with Xcode 14.0+
- iOS 16.0+ device or simulator
- API keys for:
  - OpenAI (required)
  - Perplexity (required)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/nickjlamb/PosterLens.git
cd PosterLens
```

2. Create `Secrets.plist` in the `PosterLens` directory:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>OpenAI_API_Key</key>
    <string>YOUR_OPENAI_API_KEY</string>
    <key>Perplexity_API_Key</key>
    <string>YOUR_PERPLEXITY_API_KEY</string>
</dict>
</plist>
```

3. Open `PosterLens.xcodeproj` in Xcode

4. Build and run on your device or simulator (Cmd+R)

### API Key Setup

#### OpenAI API Key
1. Visit [OpenAI Platform](https://platform.openai.com/)
2. Create an account or sign in
3. Navigate to API Keys section
4. Create a new API key
5. Add to `Secrets.plist` as `OpenAI_API_Key`

#### Perplexity API Key
1. Visit [Perplexity AI](https://www.perplexity.ai/)
2. Sign up for API access
3. Generate an API key
4. Add to `Secrets.plist` as `Perplexity_API_Key`

## Usage

1. **Scan a Poster**: Open the app and point your camera at a scientific poster
2. **Review Summary**: View AI-generated structured summary with key findings
3. **Ask Questions**: Use the chat feature to explore specific aspects
4. **Discover Research**: Find related PubMed articles automatically
5. **Organize**: Browse categorized posters with colored tags
6. **Export**: Share summaries as PDF with colleagues

## Recent Updates

### Version 1.3 (Current)
- 🔍 **Perplexity Search API Integration** - Switched from Chat API to Search API for more accurate PubMed research discovery
- 🏷️ **Smart Categorisation** - Automatic detection and tagging of research categories
- 📝 **Primary Endpoint Improvements** - Verbatim extraction only when explicitly stated
- 🎨 **UI/UX Enhancements** - Better layout, improved tag display, FlowLayout fixes
- 🐛 **Bug Fixes** - Various stability and performance improvements

### Version 1.2
- Related Research feature with PubMed integration
- Citation validation and enrichment
- PDF export functionality

### Version 1.1
- Interactive chat feature
- Author question generation
- Scan history organization

## Project Structure

```
PosterLens/
├── Models/              # Data models and view models
│   ├── PosterScan.swift
│   ├── PosterCategory.swift
│   ├── Citation.swift
│   └── CameraViewModel.swift
├── Views/               # SwiftUI views
│   ├── CameraView.swift
│   ├── SummaryView.swift
│   ├── CategoryTagView.swift
│   └── RelatedResearchView.swift
├── Services/            # Business logic and API integration
│   ├── OCRService.swift
│   ├── OpenAIService.swift
│   ├── PerplexitySearchService.swift
│   ├── CategoryExtractionService.swift
│   └── PubMedAPI.swift
├── Utilities/           # Helper classes
│   ├── NetworkRequestHelper.swift
│   ├── HapticManager.swift
│   └── Log.swift
└── CLAUDE.md           # Development guidelines for Claude Code
```

## Contributing

This project was developed with assistance from [Claude Code](https://claude.com/claude-code). When contributing, please follow the guidelines in `CLAUDE.md`.

## Privacy & Security

- All OCR processing happens on-device
- API communications use HTTPS/TLS encryption
- No user data is tracked or stored on external servers
- API keys are stored locally in `Secrets.plist` (not in version control)
- User scan history stored locally using iOS data persistence

## Requirements

- iOS 16.0+
- Xcode 14.0+
- Swift 5.7+
- Camera access permission

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- OCR powered by [Apple Vision](https://developer.apple.com/documentation/vision)
- AI by [OpenAI](https://openai.com/)
- Research discovery by [Perplexity AI Search API](https://www.perplexity.ai/)
- Citations from [PubMed](https://pubmed.ncbi.nlm.nih.gov/)
- Featured in [Perplexity AI Cookbook](https://docs.perplexity.ai/cookbook/showcase/posterlens)

## Contact

- Developer: Nick Lamb
- Email: info@pharmatools.ai
- Website: [pharmatools.ai](https://www.pharmatools.ai)
- App Store: [Download PosterLens](https://apps.apple.com/app/posterlens)

## Support

If you encounter any issues or have suggestions, please:
1. Check existing [GitHub Issues](https://github.com/nickjlamb/PosterLens/issues)
2. Create a new issue with detailed information
3. Contact support at info@pharmatools.ai

---

Made with ❤️ for the research community

🤖 README generated with [Claude Code](https://claude.com/claude-code)
