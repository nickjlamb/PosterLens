#!/usr/bin/env python3
"""
Embed and Load Script for PubMed RAG Pipeline

Loads papers from pubmed_subset.jsonl, generates embeddings using
Vertex AI text-embedding-004, and inserts them into BigQuery.

Usage:
    python embed_and_load.py --input pubmed_subset.jsonl
    python embed_and_load.py --input pubmed_subset.jsonl --batch-size 50 --dry-run

Requirements:
    pip install google-cloud-aiplatform google-cloud-bigquery

Environment:
    - GOOGLE_CLOUD_PROJECT must be set or --project specified
    - Must be authenticated with gcloud: gcloud auth application-default login
"""

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Optional

from google.cloud import bigquery
import vertexai
from vertexai.language_models import TextEmbeddingModel

# Configuration
PROJECT_ID = "posterlens-backend"
LOCATION = "europe-west2"
DATASET_ID = "pubmed_rag"
TABLE_ID = "papers"
EMBEDDING_MODEL = "text-embedding-004"
EMBEDDING_DIMENSION = 768

# Rate limiting for Vertex AI (requests per minute varies by quota)
EMBEDDING_BATCH_SIZE = 5  # Process 5 texts at a time
EMBEDDING_DELAY = 0.5  # Seconds between batches


def load_papers(input_path: Path) -> list[dict]:
    """
    Load papers from a JSONL file.

    Args:
        input_path: Path to the JSONL file

    Returns:
        List of paper dictionaries
    """
    papers = []
    with open(input_path, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                paper = json.loads(line)
                papers.append(paper)
            except json.JSONDecodeError as e:
                print(f"Warning: Failed to parse line {line_num}: {e}")

    print(f"Loaded {len(papers)} papers from {input_path}")
    return papers


def generate_embeddings(
    texts: list[str],
    model: TextEmbeddingModel,
    task_type: str = "RETRIEVAL_DOCUMENT"
) -> list[list[float]]:
    """
    Generate embeddings for a batch of texts.

    Args:
        texts: List of texts to embed
        model: Vertex AI TextEmbeddingModel
        task_type: Embedding task type (RETRIEVAL_DOCUMENT for indexing)

    Returns:
        List of embedding vectors
    """
    embeddings_response = model.get_embeddings(
        texts,
        auto_truncate=True,  # Truncate long texts automatically
        output_dimensionality=EMBEDDING_DIMENSION,
    )

    return [emb.values for emb in embeddings_response]


def embed_papers(
    papers: list[dict],
    batch_size: int = EMBEDDING_BATCH_SIZE,
    progress_interval: int = 100,
) -> list[dict]:
    """
    Generate embeddings for all papers.

    Args:
        papers: List of paper dictionaries
        batch_size: Number of papers to embed at once
        progress_interval: Print progress every N papers

    Returns:
        List of papers with embeddings added
    """
    print(f"\nInitializing Vertex AI in {LOCATION}...")
    vertexai.init(project=PROJECT_ID, location=LOCATION)

    print(f"Loading embedding model: {EMBEDDING_MODEL}...")
    model = TextEmbeddingModel.from_pretrained(EMBEDDING_MODEL)

    embedded_papers = []
    total = len(papers)
    failed = 0

    print(f"\nGenerating embeddings for {total} papers...")

    for i in range(0, total, batch_size):
        batch = papers[i:i + batch_size]

        # Prepare texts for embedding (use abstract, fall back to title)
        texts = []
        for paper in batch:
            text = paper.get("abstract", "") or paper.get("title", "")
            # Prepend title to abstract for better context
            if paper.get("title") and paper.get("abstract"):
                text = f"{paper['title']}. {paper['abstract']}"
            texts.append(text)

        try:
            embeddings = generate_embeddings(texts, model)

            for paper, embedding in zip(batch, embeddings):
                embedded_paper = {
                    "pmid": paper["pmid"],
                    "title": paper.get("title", ""),
                    "abstract": paper.get("abstract", ""),
                    "embedding": embedding,
                }
                embedded_papers.append(embedded_paper)

        except Exception as e:
            print(f"Error embedding batch starting at {i}: {e}")
            failed += len(batch)

        # Progress update
        processed = min(i + batch_size, total)
        if processed % progress_interval == 0 or processed == total:
            print(f"  Processed {processed}/{total} papers ({processed * 100 // total}%)")

        # Rate limiting
        time.sleep(EMBEDDING_DELAY)

    print(f"\nEmbedding complete: {len(embedded_papers)} succeeded, {failed} failed")
    return embedded_papers


def load_to_bigquery(
    papers: list[dict],
    batch_size: int = 500,
    dry_run: bool = False,
) -> int:
    """
    Load papers with embeddings into BigQuery.

    Args:
        papers: List of papers with embeddings
        batch_size: Number of rows to insert per request
        dry_run: If True, don't actually insert data

    Returns:
        Number of rows successfully inserted
    """
    if dry_run:
        print(f"\n[DRY RUN] Would insert {len(papers)} rows into BigQuery")
        if papers:
            print(f"Sample row:")
            sample = papers[0].copy()
            sample["embedding"] = f"[{len(sample['embedding'])} floats]"
            print(json.dumps(sample, indent=2))
        return len(papers)

    print(f"\nConnecting to BigQuery...")
    client = bigquery.Client(project=PROJECT_ID)

    table_ref = f"{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}"
    print(f"Loading {len(papers)} papers into {table_ref}...")

    total_inserted = 0
    total_errors = 0

    for i in range(0, len(papers), batch_size):
        batch = papers[i:i + batch_size]

        errors = client.insert_rows_json(table_ref, batch)

        if errors:
            print(f"Errors inserting batch at {i}: {errors[:3]}")  # Show first 3 errors
            total_errors += len(errors)
        else:
            total_inserted += len(batch)

        # Progress update
        processed = min(i + batch_size, len(papers))
        print(f"  Inserted {processed}/{len(papers)} rows")

    print(f"\nBigQuery load complete: {total_inserted} inserted, {total_errors} errors")
    return total_inserted


def verify_data(limit: int = 5) -> None:
    """
    Verify data was loaded by querying BigQuery.

    Args:
        limit: Number of rows to display
    """
    print(f"\nVerifying data in BigQuery...")
    client = bigquery.Client(project=PROJECT_ID)

    query = f"""
    SELECT pmid, title, ARRAY_LENGTH(embedding) as embedding_dim
    FROM `{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}`
    LIMIT {limit}
    """

    results = client.query(query).result()

    print(f"\nSample rows from {TABLE_ID}:")
    for row in results:
        print(f"  PMID: {row.pmid}, Dims: {row.embedding_dim}, Title: {row.title[:60]}...")

    # Get total count
    count_query = f"SELECT COUNT(*) as total FROM `{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}`"
    count_result = list(client.query(count_query).result())[0]
    print(f"\nTotal rows in table: {count_result.total}")


def estimate_costs(num_papers: int, avg_abstract_length: int = 1500) -> dict:
    """
    Estimate costs for embedding and storage.

    Args:
        num_papers: Number of papers to process
        avg_abstract_length: Average abstract length in characters

    Returns:
        Dictionary with cost estimates
    """
    # Rough estimates based on GCP pricing (as of 2024)
    # Vertex AI text-embedding-004: ~$0.0001 per 1K characters
    # BigQuery storage: $0.02 per GB per month
    # BigQuery streaming inserts: $0.01 per 200MB

    total_chars = num_papers * avg_abstract_length
    embedding_cost = (total_chars / 1000) * 0.0001

    # Each row: ~1500 chars text + 768 floats * 8 bytes = ~8KB
    storage_gb = (num_papers * 8 * 1024) / (1024 ** 3)
    storage_cost_monthly = storage_gb * 0.02

    insert_mb = (num_papers * 8 * 1024) / (1024 ** 2)
    insert_cost = (insert_mb / 200) * 0.01

    return {
        "embedding_cost": round(embedding_cost, 4),
        "storage_cost_monthly": round(storage_cost_monthly, 4),
        "insert_cost": round(insert_cost, 4),
        "total_one_time": round(embedding_cost + insert_cost, 4),
    }


def main():
    parser = argparse.ArgumentParser(
        description="Generate embeddings and load PubMed papers into BigQuery",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Standard run
  python embed_and_load.py --input pubmed_subset.jsonl

  # Dry run to test without loading
  python embed_and_load.py --input pubmed_subset.jsonl --dry-run

  # Custom batch size for large datasets
  python embed_and_load.py --input pubmed_subset.jsonl --batch-size 100

  # Just verify existing data
  python embed_and_load.py --verify-only
        """
    )

    parser.add_argument(
        "--input", "-i",
        type=str,
        default="pubmed_subset.jsonl",
        help="Input JSONL file (default: pubmed_subset.jsonl)"
    )

    parser.add_argument(
        "--batch-size", "-b",
        type=int,
        default=EMBEDDING_BATCH_SIZE,
        help=f"Embedding batch size (default: {EMBEDDING_BATCH_SIZE})"
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Generate embeddings but don't load to BigQuery"
    )

    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="Only verify existing data in BigQuery"
    )

    parser.add_argument(
        "--estimate-only",
        action="store_true",
        help="Only estimate costs without processing"
    )

    parser.add_argument(
        "--project",
        type=str,
        default=PROJECT_ID,
        help=f"GCP project ID (default: {PROJECT_ID})"
    )

    args = parser.parse_args()

    # Update project ID if specified
    project_id = args.project

    # Verify-only mode
    if args.verify_only:
        verify_data()
        return

    # Load papers
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}")
        sys.exit(1)

    papers = load_papers(input_path)

    if not papers:
        print("No papers to process")
        sys.exit(0)

    # Estimate costs
    costs = estimate_costs(len(papers))
    print(f"\nEstimated costs:")
    print(f"  Embedding: ${costs['embedding_cost']}")
    print(f"  BigQuery insert: ${costs['insert_cost']}")
    print(f"  Storage (monthly): ${costs['storage_cost_monthly']}")
    print(f"  Total one-time: ${costs['total_one_time']}")

    if args.estimate_only:
        return

    # Generate embeddings
    embedded_papers = embed_papers(papers, args.batch_size)

    if not embedded_papers:
        print("No papers were successfully embedded")
        sys.exit(1)

    # Load to BigQuery
    inserted = load_to_bigquery(embedded_papers, dry_run=args.dry_run)

    if not args.dry_run and inserted > 0:
        verify_data()

    print("\nDone!")


if __name__ == "__main__":
    main()
