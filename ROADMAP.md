# Roadmap

Where PosterLens is going, and — just as usefully — where it is not. Everything below
reflects a single maintainer's capacity, so treat the later sections as intent rather than
commitment. Nothing here has a date attached, deliberately.

Discussion of any item belongs in an [issue](https://github.com/nickjlamb/PosterLens/issues).

---

## ✅ Shipped

**2.0 — the sync and export release**

- Per-scan storage in the user's iCloud container, with a safe migration from the old
  single-file store and a local-only fallback when iCloud is unavailable
- Foreground refresh of iCloud scans with data-safety guards
- Straight-to-PDF export covering summary, categories, research directions and related
  research, with proper pagination and markdown rendering
- Onboarding redesigned onto the 2.0 design system
- Categories broadened beyond oncology, with enforced short tag labels
- Search in Scan History
- Offline resilience with a summary retry path

**1.x — the foundations**

- On-device OCR via the Vision framework, with scientific-notation repair
- Structured six-field summaries
- Interactive chat grounded in captured poster text
- Related research with PubMed validation and Vancouver formatting
- Smart categorisation with colour-coded tags
- Centralised error handling: retry with exponential backoff, safe JSON parsing,
  user-facing messages

## 🔨 In progress

**PubMed RAG replacing search-API retrieval.** The Cloud Function (`evidence_v2`) is
deployed and live behind `FeatureFlags.usePubMedRAG`: Vertex AI embeddings over a BigQuery
corpus, then a deterministic re-ranking layer for recency, keyword overlap and specificity.
What remains is corpus breadth — the current index covers a subset of PubMed, and coverage
outside oncology and immunotherapy is thin.

**`why_relevant` explanations.** Each returned paper carries a short deterministic
explanation of why it surfaced. The templates work; the keyword extraction behind them still
occasionally surfaces terms that are biomedically uninteresting.

**Retrieval evaluation.** There is currently no systematic measure of whether retrieved
papers are actually the right ones. A labelled set of poster-to-paper pairs, and a
precision@k number that can be tracked across changes, is the prerequisite for tuning
anything else honestly.

## 🎯 Next

- **Move model calls behind the gateway.** The OpenAI key currently ships in the app bundle.
  Routing those calls through the same authenticated gateway the Evidence API uses removes
  the client-side key entirely. See [SECURITY.md](SECURITY.md).
- **Compare two posters.** Scanning competing readouts from the same session and getting a
  structured diff — population, endpoint, effect size — is the thing conference-goers ask
  for most.
- **Export beyond PDF.** Structured formats a reference manager or slide deck can ingest.
- **Accessibility pass.** VoiceOver labelling and Dynamic Type through the whole flow.
- **iPad refinements.** The split-view layout ships and works; multitasking and external
  keyboard support are the gaps.
- **Wire up the test target.** `PosterLensTests/` holds real tests for citation parsing,
  Vancouver formatting and query building, but no Xcode test target references them, so CI
  cannot run them. Small job, disproportionate payoff.

## 💭 Under consideration

Not committed to, listed so the thinking is visible:

- Batch capture — queue several posters, process them while you keep walking
- Session planning from a conference programme, so scanning has an itinerary
- A local model for summarisation, removing the network dependency entirely
- Shared scan collections for teams covering a congress together
- Poster-to-abstract matching against the congress abstract book

## ❌ Not planned

- **Sending the poster image to a vision API.** OCR stays on device. Photographs of
  embargoed posters are not ours to upload, and the on-device path is faster anyway.
- **Model-generated citations.** Papers come from retrieval and are validated against PubMed
  before display. A citation that cannot be validated is dropped, not shown with a
  disclaimer.
- **Paraphrasing the primary endpoint.** Verbatim when the poster states one, omitted when
  it does not. Clinicians read that field as if the poster said it.
- **An Android port.** Not without a second developer.
- **Analytics SDKs.** There are none in the app and none planned.
