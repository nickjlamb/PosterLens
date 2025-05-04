# Installation Guide for PosterLens

## Prerequisites

- Xcode 15.0 or later
- iOS 16.0 or later device or simulator
- Perplexity API key
- Git installed

## Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/nickjlamb/PosterLens.git
   cd PosterLens
   ```

2. Open the project in Xcode:
   ```bash
   open PosterLens.xcodeproj
   ```

3. Configure API Key:
   - In Xcode, create a new Swift file called `Config.swift` in the PosterLens directory
   - Add the following code, replacing `YOUR_API_KEY` with your Perplexity API key:
     ```swift
     struct Config {
         static let perplexityAPIKey = "YOUR_API_KEY"
     }
     ```

4. Select your target device or simulator in Xcode

5. Build and run the project (⌘+R)

## Testing the Chat Feature

To test the chat functionality:
1. Scan a scientific poster using the camera
2. View the summary screen
3. Tap the "Chat with AI" button in the Explore Further section
4. Type questions or select from suggested questions
5. View AI-generated responses based on the poster content

## Troubleshooting

- **Camera Access**: Make sure to grant camera permissions when prompted
- **Build Errors**: Ensure you're using the latest Swift and SwiftUI features compatible with your Xcode version
- **API Issues**: Verify your Perplexity API key is valid and has sufficient quota remaining

## Running Without API Key

For demo purposes, the app includes a simulated response mode for the chat feature. This allows testing without making actual API calls.