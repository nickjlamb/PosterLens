# PubMed RAG Data Ingestion Pipeline

Scripts for ingesting PubMed papers into BigQuery for the PosterLens RAG pipeline.

## Overview

The ingestion pipeline has two stages:

1. **Prepare** - Query PubMed E-utilities API to fetch papers and save to JSONL
2. **Embed & Load** - Generate Vertex AI embeddings and insert into BigQuery

## Prerequisites

### Python Dependencies

```bash
pip install requests google-cloud-aiplatform google-cloud-bigquery
```

### GCP Authentication

```bash
# Authenticate with Google Cloud
gcloud auth login
gcloud auth application-default login

# Set the project
gcloud config set project posterlens-backend
```

### NCBI API Key (Optional)

For higher rate limits (10 req/sec vs 3 req/sec), get a free API key from:
https://www.ncbi.nlm.nih.gov/account/settings/

## Quick Start

### 1. Prepare a small test subset

```bash
cd functions/ingestion

# Get 100 recent oncology papers for testing
python prepare_pubmed_subset.py \
  --preset oncology \
  --recent-days 365 \
  --max-results 100
```

### 2. Embed and load (dry run first)

```bash
# Test without loading
python embed_and_load.py --input pubmed_subset.jsonl --dry-run

# Actually load to BigQuery
python embed_and_load.py --input pubmed_subset.jsonl
```

### 3. Verify the data

```bash
python embed_and_load.py --verify-only

# Or query directly
bq query --use_legacy_sql=false \
  "SELECT COUNT(*) FROM pubmed_rag.papers"
```

## Selecting Subsets

### By Keywords

```bash
python prepare_pubmed_subset.py \
  --query "breast cancer HER2 targeted therapy" \
  --max-results 500
```

### By Preset

Available presets:
- `oncology` - Cancer, tumors, biomarkers, immunotherapy
- `immunotherapy` - Checkpoint inhibitors, PD-1, PD-L1
- `biomarkers` - Diagnostic, prognostic, predictive markers
- `clinical_trials` - Phase 3 trials
- `precision_medicine` - Personalized/targeted therapy

```bash
python prepare_pubmed_subset.py --preset immunotherapy --max-results 1000
```

### By Date Range

```bash
# Papers from the last 2 years
python prepare_pubmed_subset.py \
  --preset oncology \
  --recent-days 730 \
  --max-results 2000
```

### Combining Filters

```bash
python prepare_pubmed_subset.py \
  --query "lung cancer EGFR mutation" \
  --recent-days 365 \
  --max-results 500
```

## Embedding Configuration

The pipeline uses **Vertex AI text-embedding-004**:
- Dimensions: 768
- Max input: 3,072 tokens (~12,000 characters)
- Task type: `RETRIEVAL_DOCUMENT` for indexing

Papers are embedded using: `{title}. {abstract}`

## BigQuery Schema

```sql
CREATE TABLE pubmed_rag.papers (
  pmid STRING NOT NULL,
  title STRING,
  abstract STRING,
  embedding ARRAY<FLOAT64>  -- 768 dimensions
)
```

## Cost Estimates

| Papers | Embedding Cost | Storage/Month | Insert Cost | Total One-Time |
|--------|---------------|---------------|-------------|----------------|
| 100    | ~$0.02        | <$0.01        | <$0.01      | ~$0.02         |
| 1,000  | ~$0.15        | <$0.01        | <$0.01      | ~$0.16         |
| 10,000 | ~$1.50        | ~$0.01        | <$0.01      | ~$1.52         |
| 100,000| ~$15.00       | ~$0.08        | ~$0.04      | ~$15.12        |
| 1M     | ~$150.00      | ~$0.80        | ~$0.40      | ~$151.20       |

*Estimates based on GCP pricing as of 2024. Actual costs may vary.*

Run `--estimate-only` to see costs for your specific dataset:

```bash
python embed_and_load.py --input pubmed_subset.jsonl --estimate-only
```

## Scaling to Full PubMed

For the full PubMed baseline (~35M articles):

### Option 1: Batch Processing

1. Download baseline files from: https://ftp.ncbi.nlm.nih.gov/pubmed/baseline/
2. Extract and convert to JSONL in chunks
3. Process in batches of 10,000-100,000

### Option 2: BigQuery ML

Use BigQuery's native ML functions to generate embeddings:

```sql
-- Create a model connection to Vertex AI
CREATE OR REPLACE MODEL pubmed_rag.embedding_model
  REMOTE WITH CONNECTION `us.vertex-ai-connection`
  OPTIONS (endpoint = 'text-embedding-004');

-- Generate embeddings directly in BigQuery
SELECT
  pmid,
  title,
  abstract,
  ML.GENERATE_EMBEDDING(
    MODEL `pubmed_rag.embedding_model`,
    STRUCT(CONCAT(title, '. ', abstract) AS content)
  ).embedding AS embedding
FROM raw_pubmed_data;
```

### Option 3: Dataflow Pipeline

For production-scale ingestion, use Apache Beam/Dataflow:
- Parallel processing across workers
- Automatic retry and error handling
- Integration with Cloud Storage

## Troubleshooting

### Rate Limiting

If you see `429 Too Many Requests`:
- Add an NCBI API key: `--api-key YOUR_KEY`
- Reduce batch size in embed_and_load.py
- Increase delay between requests

### Vertex AI Quota

If embeddings fail:
- Check quota in GCP Console → APIs & Services → Vertex AI
- Request quota increase if needed
- Reduce `EMBEDDING_BATCH_SIZE` in embed_and_load.py

### BigQuery Errors

If insert fails:
- Verify table exists: `bq show pubmed_rag.papers`
- Check service account permissions
- Ensure embedding dimension matches schema (768)

## Files

```
functions/ingestion/
├── README.md                 # This file
├── prepare_pubmed_subset.py  # PubMed data fetcher
├── embed_and_load.py         # Embedding generator + BigQuery loader
└── pubmed_subset.jsonl       # Output data (gitignored)
```

## Next Steps

After loading data:

1. **Create vector index** for efficient similarity search:
   ```sql
   CREATE VECTOR INDEX papers_embedding_idx
   ON pubmed_rag.papers(embedding)
   OPTIONS(distance_type='COSINE', index_type='IVF');
   ```

2. **Update Cloud Function** to query BigQuery with vector search

3. **Test end-to-end** with the iOS app
