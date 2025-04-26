# PosterLens

## Perplexity Hackathon 2025 Submission

PosterLens is an iOS application that uses computer vision and the Perplexity Sonar Pro API to transform scientific posters into easy-to-understand summaries and generate insightful questions for poster authors.

## 🌟 Features

- **Poster Scanning**: Capture scientific posters using your device camera
- **Text Extraction**: Automatically extract text content from poster images
- **AI-Powered Summaries**: Generate structured summaries of poster content using Perplexity API
- **Author Questions**: Create thoughtful questions to ask poster presenters
- **Future Directions**: App suggests new research studies 
- **History Management**: Save, organize, and revisit your scanned posters
- **PDF Export**: Export your scans and summaries as professionally formatted PDFs
- **Selection UI**: Select multiple scans for batch operations

## 🧠 Perplexity API Integration

PosterLens leverages the Perplexity Sonar Pro API to:

1. **Transform raw text** extracted from scientific posters into structured, easy-to-understand summaries
2. **Generate insightful questions** for poster authors based on the content
3. **Enhance scientific understanding** by making complex research more accessible

The integration uses carefully crafted prompts to ensure high-quality summaries and relevant questions. For detailed information about our Perplexity API implementation, see [PERPLEXITY_API.md](Documentation/PERPLEXITY_API.md).

## 📱 Screenshots

<table>
  <tr>
    <td><img src="Screenshots/camera_view.png" width="200"/></td>
    <td><img src="Screenshots/summary_view.png" width="200"/></td>
    <td><img src="Screenshots/history_view.png" width="200"/></td>
  </tr>
  <tr>
    <td align="center">Camera View</td>
    <td align="center">Summary View</td>
    <td align="center">History View</td>
  </tr>
</table>

## 🛠️ Technology Stack

- **Swift & SwiftUI**: Modern iOS development
- **AVFoundation**: Camera and image processing
- **Vision Framework**: Text recognition
- **Perplexity API**: AI-powered content analysis
- **Core Data**: Local data persistence
- **PDFKit**: PDF generation and export

## 🚀 Getting Started

See our [Installation Guide](Documentation/INSTALLATION.md) for detailed setup instructions.

## 🏗️ Architecture

PosterLens follows the MVVM (Model-View-ViewModel) architecture pattern. For more details about the app's architecture and component interactions, see [ARCHITECTURE.md](Documentation/ARCHITECTURE.md).

## 🤝 Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

PosterLens is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## 🙏 Acknowledgements

- [Perplexity API](https://www.perplexity.ai)  for powering the AI features
- The scientific community for inspiration
- All contributors and testers who helped improve the app
