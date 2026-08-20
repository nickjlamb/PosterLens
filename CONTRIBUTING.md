# Contributing to PosterLens

PosterLens is maintained by one person. That shapes what is useful: a well-written bug
report is worth more than a large unsolicited pull request, and a small focused PR is worth
more than a big one.

## Before anything else: the licence

PosterLens is **source-available, not open source**. The code is published so it can be
read, studied and learned from; it is not licensed for commercial use or redistribution.
See [LICENSE](LICENSE).

By submitting a contribution you agree that it is licensed to the project under those same
terms. If that does not work for you, please open an issue to discuss rather than sending
code.

## Good first contributions

Ranked by how much they actually help:

1. **Scans that go wrong.** A poster that OCR'd badly, a summary that missed the primary
   endpoint, a citation that did not validate. This is the highest-value feedback there is,
   because it is the part that cannot be caught by unit tests.
2. **Documentation that lies.** Anything in `docs/` that no longer matches the code.
3. **Test coverage** for `PosterLensTests/` — citation parsing, Vancouver formatting and
   query building are all pure functions and easy to test.
4. **Accessibility and iPad layout** fixes.
5. **Features from the [roadmap](ROADMAP.md)**, discussed in an issue first.

## Reporting a bad scan

This is the one report type with a specific format, because the details matter:

- The poster photo, if you are able to share it (crop or redact anything unpublished)
- What the app produced, and what it should have produced
- Which field was wrong — summary, category, citation, chat answer
- iOS version and device

If the poster is embargoed or otherwise not yours to share, describe it instead: layout,
font size, column count, whether it was glossy or matte, lighting. Those are usually the
variables that matter for OCR.

## Reporting a bug

Open a [bug report](https://github.com/nickjlamb/PosterLens/issues/new?template=bug_report.yml)
with reproduction steps, expected vs actual behaviour, and device/iOS version. Screenshots
or a screen recording save a great deal of back and forth.

**Never paste an API key into an issue**, even a revoked one. If you have leaked one, see
[SECURITY.md](SECURITY.md).

## Proposing a feature

Open a [feature request](https://github.com/nickjlamb/PosterLens/issues/new?template=feature_request.yml).
The most persuasive framing is the conference moment it solves — "standing in front of a
poster at ESMO, I need to ..." — rather than the implementation.

Check [ROADMAP.md](ROADMAP.md) first; it also lists things that have been considered and
deliberately not done, with reasons.

## Development setup

```bash
git clone https://github.com/nickjlamb/PosterLens.git
cd PosterLens
cp PosterLens/PosterLens/Secrets.example.plist PosterLens/PosterLens/Secrets.plist
open PosterLens/PosterLens.xcodeproj
```

Add your OpenAI key to `Secrets.plist` and press `⌘R`.
[docs/INSTALLATION.md](docs/INSTALLATION.md) has the long version.

Build and check nothing has regressed:

```bash
xcodebuild build \
  -project PosterLens/PosterLens.xcodeproj \
  -scheme PosterLens \
  -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'
```

**A note on the test suite.** `PosterLensTests/` contains real tests — citation parsing,
Vancouver formatting, query building, PubMed link health — but they are not yet wired into
an Xcode test target, so `⌘U` will not run them. Adding that target is a genuinely useful
first contribution and would let CI run the suite on every push.

## Pull requests

1. Branch from `main`: `git checkout -b feat/short-description`
2. Keep the change focused. One concern per PR.
3. Make sure the app builds clean — no new warnings.
4. Test on a real device if the change touches the camera, haptics or iCloud. The simulator
   will not tell you the truth about any of those.
5. Fill in the PR template.

### Commit messages

Conventional Commits, with the platform as scope:

```
feat(ios): add search to History with keyboard dismissal
fix(ios): paginate PDF sections to stop overlapping text
feat(rag): add heuristic re-ranking for related research
docs: correct the evidence endpoint contract
chore: bump version to 2.0 (build 8)
```

The changelog is assembled from these, so a clear subject line pays for itself.

## Code style

- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- Views stay dumb. Anything that makes a network call, parses a response or holds state
  belongs in `Services/` or `Models/`, not in a SwiftUI view body.
- Use `DesignSystem` for colours, spacing and typography. No hard-coded hex values in views.
- Every network call goes through the error-handling layer described in
  [docs/ERROR_HANDLING_GUIDE.md](docs/ERROR_HANDLING_GUIDE.md) — retry with backoff, safe
  JSON parsing, a user-facing message that says what to do next.
- Prefer graceful degradation to an error dialog. If Related Research fails, the summary is
  still useful; show the summary.

## Things to know before touching the pipeline

- **Never send the poster image off device.** OCR is on-device by design, for a reason that
  is explained in the README. A PR that routes images to a vision API will not be merged.
- **Models do not supply citations.** Related papers come from retrieval and are validated
  against PubMed E-utilities before display. Anything that cannot be validated is dropped
  rather than shown with a caveat.
- **The primary endpoint is quoted verbatim or omitted.** It is never paraphrased, inferred
  or reconstructed. Clinicians read that field as if the poster said it, so it has to be
  something the poster actually said.

## Code of conduct

By participating you agree to the [Code of Conduct](CODE_OF_CONDUCT.md).
