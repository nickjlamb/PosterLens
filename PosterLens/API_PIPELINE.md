# PosterLens API Pipeline

## Overview

PosterLens uses **3 external APIs** to transform a poster photo into an interactive, AI-enhanced research assistant. Here's the complete pipeline from camera capture to final output.

---

## The Complete Pipeline

```
📷 Camera Capture
    ↓
🔍 Vision Framework (iOS native - no API)
    ↓
🤖 OpenAI API (GPT-3.5-turbo)
    ↓
🌐 Perplexity Search API (with domain filters)
    ↓
📚 PubMed E-Utilities API (validation)
    ↓
✨ Final Enhanced Poster Scan
```

---

## API #1: Vision Framework (iOS Native)

**Provider:** Apple (iOS native, no API key required)
**Service:** `OCRService.swift`
**Purpose:** Extract text from poster images

### What It Does:
- Takes a `UIImage` from the camera
- Uses Apple's Vision framework for on-device OCR
- Extracts all text with high accuracy
- Handles orientation and image preprocessing

### Input:
```swift
UIImage (poster photo)
```

### Output:
```swift
String (raw extracted text)
```

### Example:
```
Input: [Photo of research poster]
Output: "Novel Cancer Immunotherapy Approaches
Background: Recent advances in checkpoint inhibitors...
Methods: We conducted a Phase II trial...
Results: Significant improvement in survival rates..."
```

### Cost: **FREE** (iOS native)

---

## API #2: OpenAI API (GPT-3.5-turbo)

**Provider:** OpenAI
**Service:** `OpenAIService.swift`
**API Key:** Required (`OpenAI_API_Key` in Secrets.plist)
**Endpoint:** `https://api.openai.com/v1/chat/completions`

### What It Does:
PosterLens uses OpenAI for **3 distinct functions**:

#### 2A. **Structured Summarization** (Primary Use)
**Method:** `generateStructuredSummary(from:completion:)`

Takes the raw OCR text and generates a 4-point structured summary:

**Input:**
```swift
rawText: "Novel Cancer Immunotherapy Approaches\nBackground: Recent advances..."
```

**Prompt to OpenAI:**
```
Analyze the following text from a scientific poster and create a structured summary.
Provide EXACTLY 4 bullet points covering:
1. Main Research Question/Objective
2. Methodology Used
3. Key Results and Findings
4. Main Conclusions and Implications
```

**Output:**
```swift
[
  "**Research Question**: Evaluate checkpoint inhibitors in Stage IV cancer patients",
  "**Methodology**: Phase II randomized controlled trial with 200 patients over 12 months",
  "**Key Results**: 65% response rate with median survival improvement of 8.2 months",
  "**Conclusions**: Checkpoint inhibitors show significant promise for late-stage treatment"
]
```

#### 2B. **Author Questions Generation** (Secondary Use)
**Method:** Via `PerplexityService` integration

Generates thoughtful questions a researcher might ask the poster author:

**Output Example:**
```swift
[
  "What were the key exclusion criteria for patient selection?",
  "How did you account for confounding variables in survival analysis?",
  "What are the next steps for Phase III trials?"
]
```

#### 2C. **Interactive Chat** (Tertiary Use)
**Service:** `OpenAIChatService.swift`
**Method:** `generateResponse(for:to:previousMessages:completion:)`

Powers the chat feature where users can ask questions about the poster:

**User Question:**
```
"What was the sample size?"
```

**Context Provided to OpenAI:**
```
[Poster title, summary points, raw text, previous conversation]
```

**OpenAI Response:**
```
"The study included 200 patients with Stage IV cancer, randomized into
treatment (n=100) and control (n=100) groups."
```

### API Configuration:
```swift
"model": "gpt-3.5-turbo"
"max_tokens": 1024
"temperature": 0.3  // Low for factual responses
```

### Error Handling:
- ✅ Automatic retry (3 attempts) via `NetworkRequestHelper`
- ✅ Exponential backoff (1s, 2s, 4s)
- ✅ Safe JSON parsing via `SafeJSONParser`
- ✅ User-friendly error messages via `NetworkError`

### Cost: **~$0.0015 per request** (GPT-3.5-turbo pricing)

---

## API #3: Perplexity Search API

**Provider:** Perplexity AI
**Service:** `PerplexityRelatedResearchService.swift`
**API Key:** Required (`Perplexity_API_Key` in Secrets.plist)
**Endpoint:** `https://api.perplexity.ai/chat/completions`
**Model:** `sonar` (search model, not chat)

### What It Does:
Finds 3-5 **related research papers** from trusted academic sources using real-time web search with domain filtering.

### Key Features:
- **Domain Filtering:** Only searches 14 trusted academic sources
- **Real Citations:** Returns actual URLs from search results
- **Recency Filter:** Prefers papers from the last year

### Input:
```swift
posterScan: PosterScan {
  title: "Novel Cancer Immunotherapy Approaches"
  summaryPoints: [...]
}
```

### Search Query Generated:
```
Find 3-5 recent published research papers (2020-2024) related to:
cancer immunotherapy checkpoint inhibitors treatment

CRITICAL FORMATTING RULES:
- NO preamble text
- Start IMMEDIATELY with: 1. Author A, Author B, et al.
- Use Vancouver citation style
- Include DOI and PMID when available
```

### API Configuration:
```swift
"model": "sonar"  // Search model, NOT sonar-pro
"temperature": 0.2  // Low for factual results
"return_citations": true  // ✅ Get real URLs!
"search_domain_filter": [  // ✅ NEW FEATURE
  "pubmed.ncbi.nlm.nih.gov",
  "nature.com",
  "science.org",
  "cell.com",
  "arxiv.org",
  // ... 14 domains total
]
"search_recency_filter": "year"  // Recent papers only
```

### Output:
```swift
citations: [Citation] = [
  Citation(
    title: "Checkpoint inhibitors in advanced cancer: 2023 update",
    authors: ["Smith J", "Johnson A"],
    journal: "Nature Medicine",
    year: 2023,
    doi: "10.1038/s41591-023-12345",
    url: "https://pubmed.ncbi.nlm.nih.gov/37123456/"
  ),
  // ... up to 5 citations
]
```

### Trusted Academic Domains (14):
1. `pubmed.ncbi.nlm.nih.gov` - PubMed (NIH)
2. `pmc.ncbi.nlm.nih.gov` - PubMed Central
3. `nih.gov` - National Institutes of Health
4. `arxiv.org` - Scientific preprints
5. `scholar.google.com` - Google Scholar
6. `nature.com` - Nature Publishing
7. `science.org` - Science Magazine
8. `sciencedirect.com` - Elsevier
9. `springer.com` - Springer Nature
10. `wiley.com` - Wiley Online Library
11. `cell.com` - Cell Press
12. `nejm.org` - New England Journal of Medicine
13. `pnas.org` - PNAS
14. `ieee.org` - IEEE

### Why Domain Filtering Matters:
- ❌ **Without filters:** Gets random blog posts, news articles, Wikipedia
- ✅ **With filters:** Only peer-reviewed journals, trusted databases

### Error Handling:
- ✅ Automatic retry (3 attempts)
- ✅ Exponential backoff
- ✅ Safe JSON parsing
- ✅ Graceful degradation if search fails

### Cost: **~$0.005 per search** (Perplexity API pricing)

---

## API #4: PubMed E-Utilities API

**Provider:** NCBI (National Center for Biotechnology Information)
**Service:** `PubMedAPI.swift`
**API Key:** Optional (has etiquette parameters)
**Endpoint:** `https://eutils.ncbi.nlm.nih.gov/entrez/eutils/`

### What It Does:
**Validates and enriches** citations from Perplexity with verified metadata.

### Three Main Functions:

#### 4A. **Search by Query** (`esearch.fcgi`)
Find PubMed IDs (PMIDs) matching a search query:

**Input:**
```
query: "cancer immunotherapy checkpoint inhibitors 2023"
```

**Output:**
```swift
["37123456", "36789012", "38456789"]  // PMIDs
```

#### 4B. **Fetch Metadata** (`esummary.fcgi`)
Get citation metadata for a PMID:

**Input:**
```
pmid: "37123456"
```

**Output:**
```swift
{
  title: "Checkpoint inhibitors in advanced cancer: 2023 update",
  authors: ["Smith J", "Johnson A", "Brown K"],
  journal: "Nature Medicine",
  year: 2023,
  doi: "10.1038/s41591-023-12345"
}
```

#### 4C. **Fetch Abstract** (`efetch.fcgi`)
Get the full abstract text:

**Input:**
```
pmid: "37123456"
```

**Output:**
```swift
"Background: Immune checkpoint inhibitors have revolutionized cancer treatment...
Methods: We conducted a systematic review...
Results: Analysis of 45 trials showed...
Conclusions: Checkpoint inhibitors demonstrate significant efficacy..."
```

### How It Validates Perplexity Results:

**Step 1:** Perplexity returns citation with URL:
```
url: "https://pubmed.ncbi.nlm.nih.gov/37123456/"
```

**Step 2:** PubMedAPI extracts PMID and validates:
```swift
extractPMID(from: url) → "37123456"
fetchMetadata(for: "37123456") → verified metadata
```

**Step 3:** Compare titles for accuracy:
```swift
calculateTitleSimilarity(perplexityTitle, pubmedTitle)
// If similarity > 70%, citation is validated
```

**Step 4:** Replace with verified metadata:
```swift
Citation(
  title: pubmedTitle,  // ✅ Verified
  authors: pubmedAuthors,  // ✅ Verified
  journal: pubmedJournal,  // ✅ Verified
  url: "https://pubmed.ncbi.nlm.nih.gov/37123456/"  // ✅ Working link
)
```

### API Configuration:
```swift
"tool": "PosterLens/1.0"  // Etiquette parameter
"email": "app@posterlens.com"  // Etiquette parameter
"retmax": "5"  // Limit results
```

### Cost: **FREE** (NCBI public API)

---

## The Complete Data Flow

### 1. **Capture Stage**
```
User taps camera button
    ↓
CameraView captures UIImage
    ↓
OCRService (Vision Framework) extracts text
```

### 2. **AI Processing Stage**
```
Raw OCR text → OpenAI GPT-3.5-turbo
    ↓
Returns structured summary:
  • Research Question
  • Methodology
  • Results
  • Conclusions
```

### 3. **Research Enhancement Stage**
```
Summary + Title → Perplexity Search API
    ↓
Searches 14 academic domains with filters
    ↓
Returns 3-5 citations with URLs
    ↓
Each citation → PubMed API for validation
    ↓
Returns verified, enriched citations
```

### 4. **User Interaction Stage**
```
User asks question → OpenAIChatService
    ↓
Context: [poster text + summary + previous messages]
    ↓
OpenAI returns conversational answer
```

---

## API Cost Breakdown (Per Poster Scan)

| API | Operation | Estimated Cost |
|-----|-----------|----------------|
| **Vision Framework** | OCR text extraction | $0.00 (free) |
| **OpenAI** | Structured summary | $0.0015 |
| **OpenAI** | Author questions (via Perplexity) | $0.0010 |
| **Perplexity** | Related research search | $0.0050 |
| **PubMed** | Citation validation (5 papers) | $0.00 (free) |
| **OpenAI** | Chat interaction (per message) | $0.0015 |
| | |
| **Total per scan** | (without chat) | **~$0.0075** |
| **Total per chat message** | | **+$0.0015** |

### Monthly Cost Estimates:

**For 1,000 scans/month:**
- Base scanning: $7.50
- Average 2 chat messages/scan: $3.00
- **Total: ~$10.50/month**

**For 10,000 scans/month:**
- Base scanning: $75.00
- Average 2 chat messages/scan: $30.00
- **Total: ~$105/month**

---

## Error Handling Pipeline

All APIs use the centralized `NetworkErrorHandler.swift`:

```
API Request
    ↓
NetworkRequestHelper (retry logic)
    ↓
If fails → Retry 1 (wait 1s)
    ↓
If fails → Retry 2 (wait 2s)
    ↓
If fails → Retry 3 (wait 4s)
    ↓
If still fails → NetworkError with user-friendly message
    ↓
User sees: "Unable to reach the server. Please try again later."
```

### Error Examples:

| Technical Error | User-Friendly Message |
|----------------|----------------------|
| `NSURLErrorNotConnectedToInternet` | "No internet connection. Please check your network settings." |
| `NSURLErrorTimedOut` | "The request took too long. Please check your connection." |
| `HTTP 429` | "Too many requests. Please wait a moment and try again." |
| `HTTP 401` | "API authentication failed. Please check your API key." |
| Invalid JSON | "Unable to process the response. Please try again." |

---

## API Key Management

**Location:** `Secrets.plist` (gitignored)

**Loaded by:** `SecretManager.swift`

```swift
// OpenAI Key
SecretManager.shared.loadAPIKey(for: "OpenAI_API_Key")

// Perplexity Key
SecretManager.shared.loadAPIKey(for: "Perplexity_API_Key")

// PubMed (optional)
// No key required, uses etiquette parameters
```

---

## API Rate Limits

| API | Free Tier | Rate Limit |
|-----|-----------|------------|
| **Vision Framework** | Unlimited | Device-limited |
| **OpenAI GPT-3.5** | Pay-as-you-go | 3,500 requests/min |
| **Perplexity Search** | Pay-as-you-go | 1,000 requests/hour |
| **PubMed** | Free | 3 requests/sec (no key) |

---

## Which API Does What?

| Feature | API Used | Purpose |
|---------|----------|---------|
| **Text Extraction** | Vision Framework | Extract text from poster image |
| **Structured Summary** | OpenAI GPT-3.5 | Generate 4-point summary |
| **Author Questions** | OpenAI GPT-3.5 | Generate thoughtful questions |
| **Related Research** | Perplexity Search | Find similar academic papers |
| **Citation Validation** | PubMed | Verify and enrich citations |
| **Interactive Chat** | OpenAI GPT-3.5 | Answer user questions |
| **Error Handling** | All APIs | NetworkRequestHelper + SafeJSONParser |

---

## API Reliability Features

✅ **Automatic Retry Logic**
- 3 attempts per request
- Exponential backoff (1s, 2s, 4s)
- Only retries transient errors

✅ **Safe JSON Parsing**
- Never crashes on malformed data
- Graceful degradation
- Error recovery strategies

✅ **Timeout Management**
- 30-second default timeout
- Configurable per API
- Clear timeout error messages

✅ **Domain Filtering** (Perplexity)
- Only trusted academic sources
- 14 verified domains
- High-quality citations guaranteed

---

## Future API Enhancements

**Potential additions:**
1. **Semantic Scholar API** - Additional academic paper validation
2. **arXiv API** - Direct preprint access
3. **Crossref API** - DOI resolution and metadata
4. **OpenAlex API** - Open citation data

**Current status:** Not needed - current 3-API pipeline provides comprehensive coverage.

---

## Summary

PosterLens uses a **3-stage API pipeline**:

1. **Vision Framework** (free) - Extract text from image
2. **OpenAI GPT-3.5** (~$0.0015/request) - AI summarization and chat
3. **Perplexity Search** (~$0.005/search) - Find related papers with domain filtering
4. **PubMed** (free) - Validate and enrich citations

**Total cost per scan:** ~$0.0075
**With error handling:** Automatic retry, safe parsing, user-friendly messages
**Result:** A fully enhanced, interactive research assistant from a single photo!
