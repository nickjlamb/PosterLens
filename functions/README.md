# PosterLens Cloud Functions

Google Cloud Functions for the PosterLens backend API.

## Functions

### evidence_v2

Endpoint for retrieving evidence-based research papers related to scientific poster content.

- **URL**: `/v2/evidence`
- **Method**: `POST`
- **Content-Type**: `application/json`

#### Request

```json
{
  "text": "Scientific poster text content..."
}
```

#### Response

```json
{
  "status": "ok",
  "papers": [],
  "metadata": {
    "version": "2.0.0",
    "timestamp": "2024-01-15T10:30:00Z",
    "text_length": 1234
  }
}
```

#### Error Response

```json
{
  "status": "error",
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Description of what went wrong"
  }
}
```

## Local Development

### Prerequisites

- Python 3.9+
- Google Cloud SDK

### Setup

```bash
cd functions
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### Run Locally

```bash
functions-framework --target=evidence_v2 --debug
```

The function will be available at `http://localhost:8080/`

### Test Locally

```bash
curl -X POST http://localhost:8080/ \
  -H "Content-Type: application/json" \
  -d '{"text": "Sample poster text about cancer research..."}'
```

## Deployment

### Deploy to Google Cloud

```bash
gcloud functions deploy evidence_v2 \
  --gen2 \
  --runtime=python311 \
  --region=us-central1 \
  --source=. \
  --entry-point=evidence_v2 \
  --trigger-http \
  --allow-unauthenticated
```

### Environment Variables (Future)

When BigQuery and Vertex AI are integrated, you'll need:

```bash
--set-env-vars PROJECT_ID=your-project-id,DATASET_ID=pubmed_dataset
```

## Status

- [x] BigQuery vector search over the PubMed corpus (`pubmed_rag.papers`)
- [x] Vertex AI embeddings (`text-embedding-004`)
- [x] Deterministic re-ranking — recency, keyword overlap, specificity
- [x] `why_relevant` explanations per paper
- [x] API gateway with key authentication and rate limiting
- [ ] Corpus breadth beyond oncology and immunotherapy
- [ ] Retrieval evaluation set with a tracked precision@k

See [../ROADMAP.md](../ROADMAP.md) for the wider picture and
[../docs/EXAMPLES.md](../docs/EXAMPLES.md) for request and response shapes.
