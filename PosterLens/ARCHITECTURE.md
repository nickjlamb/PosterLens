# PosterLens Architecture

PosterLens follows the MVVM (Model-View-ViewModel) architecture pattern to ensure separation of concerns and maintainable code.

## Components

### Models

- **PosterScan**: Core data model representing a scanned poster, including extracted text, summary, categories, and metadata
- **PosterCategory**: Research categorization model with color-coded tags
- **Citation**: Academic paper references with validation status
- **ResearchContext**: Author questions and future research directions
- **DataStore**: Main data persistence layer that handles saving and retrieving poster scans
- **ChatMessage**: Represents individual messages in chat conversations
- **Conversation**: Contains collections of messages related to a specific poster

### Views

- **ContentView**: Main navigation container
- **CameraView**: Handles poster scanning with live preview and edge detection
- **SummaryView**: Displays extracted content and AI-generated insights
- **RelatedResearchView**: Shows discovered academic papers from PubMed
- **HistoryView**: Shows saved poster scans with category filtering
- **SimpleChatView**: Provides interactive chat interface for poster-specific questions
- **CategoryTagView**: Displays color-coded research category tags
- **CategoryDetailSheet**: Category organization and filtering

### Services

- **OCRService**: Handles text extraction from images using Apple Vision framework
- **OpenAIService**: Generates structured summaries and author questions via GPT-3.5-turbo
- **OpenAIChatService**: Powers interactive chat about poster content
- **PerplexityRelatedResearchService**: Discovers related papers using Perplexity Search API with domain filtering
- **CategoryExtractionService**: Automatic detection and tagging of research categories
- **PubMedAPI**: Validates and enriches citations with PubMed metadata
- **PDFExportService**: Generates PDF documents from poster data

### Utilities

- **NetworkErrorHandler**: Centralized error handling with user-friendly messages
- **NetworkRequestHelper**: Automatic retry logic with exponential backoff
- **SafeJSONParser**: Crash-safe JSON parsing utilities
- **SecretManager**: Secure API key management from Secrets.plist
- **CitationEnhancer**: Improves citation formatting
- **HapticManager**: Provides tactile feedback throughout the app
- **DesignSystem**: Centralized styling and UI constants
- **Log**: Debug logging utilities

## App Workflow

1. User captures a poster image via CameraView
2. OCRService extracts text from the image using on-device Vision framework
3. OpenAIService generates a structured 4-point summary
4. CategoryExtractionService detects research categories
5. SummaryView displays the results with category tags
6. User can discover related research via PerplexityRelatedResearchService
7. PubMedAPI validates and enriches citations
8. User can interact via SimpleChatView powered by OpenAIChatService
9. User can save the scan, which is stored via DataStore
10. Scans can be exported as PDF using PDFExportService

## API Pipeline

```
📷 Camera Capture
    ↓
🔍 Vision Framework (iOS native - on-device OCR)
    ↓
🤖 OpenAI API (GPT-3.5-turbo - summarization)
    ↓
🌐 Perplexity Search API (related research with domain filters)
    ↓
📚 PubMed E-Utilities API (citation validation)
    ↓
✨ Final Enhanced Poster Scan
```

See [API_PIPELINE.md](API_PIPELINE.md) for detailed API documentation.

## State Management

- **@State**: For local view state
- **@EnvironmentObject**: For shared app-wide state
- **@ObservableObject**: For reactive data models

## Error Handling

All network operations use the centralized error handling system:
- Automatic retry with exponential backoff (3 attempts)
- User-friendly error messages via NetworkError
- Safe JSON parsing to prevent crashes
- Graceful degradation on API failures

See [ERROR_HANDLING_GUIDE.md](ERROR_HANDLING_GUIDE.md) for migration patterns.

## Future Considerations

- Cloud Functions backend for RAG-based evidence retrieval (in progress)
- BigQuery integration for PubMed paper database
- Vertex AI for semantic search and embeddings
- Enhanced caching mechanisms for offline use
- Further modularization for better testability