# Security Policy

## Reporting a vulnerability

Email **info@pharmatools.ai** with `SECURITY` in the subject line. Please do not open a
public issue for anything exploitable.

Include what you found, how to reproduce it, and what an attacker could do with it. You will
get an acknowledgement within 72 hours and an assessment within 7 days. If the report is
valid and you would like credit, you will be named in the release notes for the fix.

Please do not run automated scanners against the production Evidence API gateway. If you
need to test the backend, run it locally — see [`functions/README.md`](functions/README.md).

## Supported versions

| Version | Supported |
|---|---|
| 2.0.x | ✅ |
| 1.4.x | Security fixes only |
| < 1.4 | ❌ |

## What PosterLens does with your data

| Data | Where it goes |
|---|---|
| The poster photograph | **Stays on the device.** It is never uploaded to any API. |
| OCR text extraction | On device, via Apple's Vision framework. |
| Extracted poster text | Sent to OpenAI for summarisation and chat, and to the Evidence API or Perplexity for related-research retrieval. |
| Saved scans and notes | Your own iCloud container, with a local-only fallback. Not on any server the project controls. |
| Analytics | None. There is no analytics SDK in the app. |

The distinction that matters: the **image** never leaves the phone, the **text** does. A
poster at an embargoed session contains unpublished data, and photographs of it are not
something to hand to a third-party API.

## API keys

Keys live in `Secrets.plist`, which is gitignored (`**/Secrets.plist`) and has never been
committed to this repository. `Secrets.example.plist` is the tracked template and contains
no real values.

Keys ship inside the app bundle, which means a determined person with a copy of the IPA can
extract them. This is a known property of any client-side key, not a defect specific to
PosterLens. Two consequences:

- **If you fork this, use your own keys** and set spend limits on them.
- The Evidence API sits behind a gateway with its own key and rate limiting, so the
  server-side path can be revoked independently.

Moving the OpenAI calls behind the same gateway is on the [roadmap](ROADMAP.md) and is the
proper fix.

## If you leak a key

1. Revoke it at the provider immediately — that is the step that actually matters.
2. Issue a new one and update your local `Secrets.plist`.
3. Rewriting git history is not a substitute for revocation. Assume anything pushed to a
   public repository was scraped within minutes.
