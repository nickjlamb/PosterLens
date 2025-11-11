# PosterLens

PosterLens is an iOS application that uses computer vision and AI to extract and analyze text from scientific posters, helping users quickly understand complex research.

## Key Features

- **Scientific Poster Scanning**: Capture images of research posters with automatic edge detection
- **Text Extraction**: Use OCR to read and process poster contents
- **AI-powered Summaries**: Generate concise summaries of research posters via Perplexity API
- **Interactive Chat**: Ask specific questions about the poster content with AI-generated contextual responses
- **Author Questions**: Automatically generate insightful questions to ask the poster presenter
- **Future Research Directions**: AI-suggested areas for future research based on the poster
- **Scan History**: Save and organize multiple poster scans
- **Export Functionality**: Share or save information as PDF

## Technology Stack

- **Swift & SwiftUI**: Modern UI framework for iOS
- **AVFoundation**: Camera handling and image capture
- **Vision Framework**: Text recognition and extraction
- **Perplexity API**: AI-powered text analysis and chat responses
- **Core Data**: Local data persistence
- **PDFKit**: PDF generation for exports

## Architecture

PosterLens follows the MVVM (Model-View-ViewModel) architecture pattern. See [ARCHITECTURE.md](ARCHITECTURE.md) for more details.

## Installation

For setup and installation instructions, see [INSTALLATION.md](INSTALLATION.md).

## Perplexity API Integration

For details on how PosterLens uses the Perplexity API for both summary generation and conversational responses, see [PERPLEXITY_API.md](PERPLEXITY_API.md).

## Project Status

This application is a submission for the Perplexity Hackathon 2025.

## License
Educational and Non-Commercial Use Only  
See the [LICENSE](LICENSE) file for full terms.
