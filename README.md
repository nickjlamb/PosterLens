# PosterLens

PosterLens is an iOS application that uses computer vision and AI to extract and analyze text from scientific posters, helping users quickly understand complex research.

## Key Features

- **Scientific Poster Scanning**: Capture images of research posters with automatic edge detection
- **Text Extraction**: Use OCR to read and process poster contents
- **AI-powered Summaries**: Generate structured summaries via OpenAI GPT-3.5
- **Interactive Chat**: Ask specific questions about the poster content with AI-generated contextual responses
- **Related Research Discovery**: Find similar PubMed papers using Perplexity Search API
- **Smart Categorisation**: Automatic research category detection with color-coded tags
- **Author Questions**: Automatically generate insightful questions to ask the poster presenter
- **Scan History**: Save and organize multiple poster scans with category filtering
- **Export Functionality**: Share or save information as PDF

## Technology Stack

- **Swift & SwiftUI**: Modern UI framework for iOS
- **AVFoundation**: Camera handling and image capture
- **Vision Framework**: On-device text recognition and extraction
- **OpenAI API**: AI-powered summarization and chat (GPT-3.5-turbo)
- **Perplexity Search API**: Related research discovery with domain filtering
- **PubMed E-Utilities API**: Citation validation and enrichment
- **PDFKit**: PDF generation for exports

## Architecture

PosterLens follows the MVVM (Model-View-ViewModel) architecture pattern. See [PosterLens/ARCHITECTURE.md](PosterLens/ARCHITECTURE.md) for more details.

## Installation

For setup and installation instructions, see [PosterLens/INSTALLATION.md](PosterLens/INSTALLATION.md).

## API Pipeline

PosterLens uses a 4-stage API pipeline to transform poster photos into interactive insights. See [PosterLens/API_PIPELINE.md](PosterLens/API_PIPELINE.md) for the complete technical documentation.

## Documentation

- [ARCHITECTURE.md](PosterLens/ARCHITECTURE.md) - App structure and components
- [API_PIPELINE.md](PosterLens/API_PIPELINE.md) - Complete API flow documentation
- [API_INTEGRATION.md](PosterLens/API_INTEGRATION.md) - API integration details
- [ERROR_HANDLING_GUIDE.md](PosterLens/ERROR_HANDLING_GUIDE.md) - Error handling patterns
- [CHANGELOG.md](PosterLens/CHANGELOG.md) - Version history

## Project Status

Featured in the [Perplexity AI Cookbook](https://docs.perplexity.ai/cookbook/showcase/posterlens).

Available on the [App Store](https://apps.apple.com/app/posterlens).

## License

See the [LICENSE](LICENSE) file for full terms.
