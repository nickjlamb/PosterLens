# PosterLens Architecture

PosterLens follows the MVVM (Model-View-ViewModel) architecture pattern to ensure separation of concerns and maintainable code.

## Components

### Models

- **PosterScan**: Core data model representing a scanned poster, including extracted text, summary, and metadata
- **DataStore**: Main data persistence layer that handles saving and retrieving poster scans
- **OnboardingManager**: Manages the app's onboarding state
- **ChatMessage**: Represents individual messages in chat conversations
- **Conversation**: Contains collections of messages related to a specific poster

### Views

- **ContentView**: Main navigation container
- **CameraView**: Handles poster scanning with live preview
- **SummaryView**: Displays extracted content and AI-generated insights
- **HistoryView**: Shows saved poster scans
- **SimpleChatView**: Provides interactive chat interface for poster-specific questions
- **ButtonRowView**: Reusable component for navigation actions

### Services

- **OCRService**: Handles text extraction from images
- **PerplexityService**: Manages communication with Perplexity API for summaries
- **PDFExportService**: Generates PDF documents from poster data
- **ChatService**: Processes questions about posters and generates contextual responses

### Utilities

- **CitationEnhancer**: Improves citation formatting
- **HapticManager**: Provides tactile feedback throughout the app
- **DesignSystem**: Centralized styling and UI constants

## App Workflow

1. User captures a poster image via CameraView
2. OCRService extracts text from the image
3. PerplexityService processes the text to generate summaries and insights
4. SummaryView displays the results
5. User can interact via SimpleChatView to ask specific questions about the poster
6. ChatService processes questions and generates contextual responses
7. User can save the scan, which is stored via DataStore
8. Scans can be exported as PDF using PDFExportService

## Data Flow

```
Image Capture → Text Extraction → AI Processing → Display/Interaction → Storage/Export
```

## State Management

- **@State**: For local view state
- **@EnvironmentObject**: For shared app-wide state
- **@ObservableObject**: For reactive data models

## Future Considerations

- Implement Swift Concurrency for improved performance
- Enhanced caching mechanisms for offline use
- Further modularization for better testability
- Expand chat capabilities with more context awareness