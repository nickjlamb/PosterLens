# Installation Guide for PosterLens

## Prerequisites

- Xcode 15.0 or later
- iOS 16.0 or later device or simulator
- OpenAI API key (required for summarization and chat)
- Perplexity API key (required for related research discovery)
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

3. Configure API Keys:
   Create a `Secrets.plist` file in the `PosterLens/PosterLens` directory with the following structure:
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

   **Important:** `Secrets.plist` is gitignored and should never be committed to version control.

4. Select your target device or simulator in Xcode

5. Build and run the project (Cmd+R)

## Getting API Keys

### OpenAI API Key
1. Visit [OpenAI Platform](https://platform.openai.com/)
2. Create an account or sign in
3. Navigate to API Keys section
4. Create a new API key
5. Add to `Secrets.plist` as `OpenAI_API_Key`

### Perplexity API Key
1. Visit [Perplexity AI](https://www.perplexity.ai/)
2. Sign up for API access
3. Generate an API key
4. Add to `Secrets.plist` as `Perplexity_API_Key`

## Testing Features

### Poster Scanning
1. Open the app and point your camera at a scientific poster
2. The app will automatically detect and capture the poster
3. View the AI-generated structured summary

### Chat Feature
1. From the summary screen, tap "Chat with AI"
2. Type questions or select from suggested questions
3. View AI-generated responses based on the poster content

### Related Research
1. From the summary screen, tap "Related Research"
2. View automatically discovered PubMed papers related to the poster
3. Tap any citation to open it in PubMed

## Troubleshooting

- **Camera Access**: Make sure to grant camera permissions when prompted
- **Build Errors**: Ensure you're using Xcode 15.0+ with Swift 5.7+
- **API Issues**: Verify your API keys are valid and have sufficient quota
- **Missing Secrets.plist**: Create the file as described in step 3 above
- **No Related Research**: Ensure your Perplexity API key is valid and has Search API access

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for details on the app's structure.

## API Pipeline

See [API_PIPELINE.md](API_PIPELINE.md) for details on how the 4-stage API pipeline works.