# PosterLens Architecture

This document provides an overview of the PosterLens app architecture and how different components interact.

## Overview

PosterLens follows the Model-View-ViewModel (MVVM) architecture pattern, with clear separation of concerns between data models, business logic, and UI components.

## Core Components

### Models

Located in the `Models` directory, these define the data structures and business logic:

- **PosterScan**: Represents a scanned poster with its image, extracted text, summary points, and author questions
- **DataStore**: Manages data persistence, saving and loading scans
- **OnboardingManager**: Handles the app's onboarding experience

### Views

Located in the `Views` directory, these define the UI components:

- **ContentView**: Main tab-based navigation structure
- **CameraView**: Camera interface for scanning posters
- **SummaryView**: Displays poster summaries with card-based layout
- **ImprovedHistoryView**: Grid-based history view with selection capabilities
- **ScanCardView**: Reusable card component for displaying scans

### Services

Located in the `Services` directory, these provide integration with external systems:

- **PerplexityService**: Handles communication with the Perplexity API
- **PDFExportService**: Generates PDF documents from scans

### Utils

Located in the `Utils` directory, these provide utility functions:

- **ImageProcessing**: Handles image manipulation and text extraction
- **UIHelpers**: Common UI utility functions

## Data Flow

1. User captures a poster image via CameraView
2. Text is extracted from the image
3. PerplexityService processes the text to generate summaries and questions
4. Results are displayed in SummaryView
5. User can save the scan to DataStore
6. Saved scans appear in ImprovedHistoryView
7. User can export scans as PDFs via PDFExportService

## Key Features Implementation

### Perplexity API Integration

The PerplexityService handles all communication with the Perplexity API:
- Constructs prompts for generating summaries and questions
- Makes API requests using the Sonar model
- Processes and formats responses for display

### Selection and Export

The ImprovedHistoryView implements:
- Multi-selection UI for scans
- Batch operations (export, delete)
- PDF generation for selected scans

### Camera and Text Extraction

The CameraView and related components handle:
- Camera preview and capture
- Image processing
- Text extraction from images

## Future Architecture Considerations

- Potential migration to Swift Concurrency for async operations
- Enhanced caching for improved performance
- Modularization for better code organization
- Unit and UI testing infrastructure
