# Contributing to PosterLens

Thank you for your interest in contributing to PosterLens! This document provides guidelines for reporting bugs, suggesting features, and submitting pull requests.

## Reporting Bugs

When reporting bugs, please create a GitHub issue with:
- A clear, descriptive title
- Detailed steps to reproduce the bug
- Expected behavior vs. actual behavior
- Screenshots, if applicable
- Your device and iOS version information

## Suggesting Features

To suggest new features, submit a GitHub issue with:
- A clear feature description
- A detailed explanation of the benefits
- Mockups or diagrams, if applicable

## Pull Request Process

1. Fork the repository
2. Create a new branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes
4. Test thoroughly on different iOS devices/simulators
5. Submit a pull request with a clear description of the changes

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/nickjlamb/PosterLens.git
   cd PosterLens
   ```
2. Open the project in Xcode:
   ```bash
   open PosterLens.xcodeproj
   ```
3. Follow the setup instructions in INSTALLATION.md

## Code Style Guidelines

- Follow Swift API Design Guidelines
- Use SwiftUI best practices
- Write self-documenting code with clear variable names
- Add comments for complex algorithms or business logic

## Working on the Chat Feature

When contributing to the chat functionality:

1. Understand the current implementation:
   - `ChatMessage.swift` defines the message data structure
   - `SimpleChatView.swift` contains the main chat interface
   - `ChatService.swift` handles message processing

2. Consider these areas for improvement:
   - Enhanced suggested questions based on poster content
   - Improved response generation algorithms
   - UI/UX enhancements for the chat interface
   - Performance optimizations for large conversations

3. Test chat functionality thoroughly:
   - Verify messages display correctly
   - Test with various types of questions
   - Ensure proper error handling
   - Check state management for UI updates