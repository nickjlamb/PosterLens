#!/usr/bin/env python3
"""
Embed and Load Script for PubMed RAG Pipeline (Incremental)

Loads papers from pubmed_subset.jsonl, generates embeddings using
Vertex AI text-embedding-004, and APPENDS them to BigQuery.

INCREMENTAL INGESTION:
- Deduplicates by PMID (skips papers already in BigQuery)
- Filters by pub_year (only 2020-2025)
- Respects configurable MAX_PAPERS limit
- Handles errors per-paper without stopping the run
- Append-only: never deletes or modifies existing data

Usage:
    # Standard incremental run (default limit: 1000 papers)
    python embed_and_load.py --input pubmed_subset.jsonl

    # Larger batch with custom limit
    python embed_and_load.py --input pubmed_subset.jsonl --max-papers 5000

    # Dry run to test without loading
    python embed_and_load.py --input pubmed_subset.jsonl --dry-run

    # Just verify existing data
    python embed_and_load.py --verify-only

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

# Incremental ingestion settings
DEFAULT_MAX_PAPERS = 1000  # Conservative default to control costs
MIN_YEAR = 2020  # Only ingest papers from 2020 onwards
MAX_YEAR = 2025  # Up to and including 2025


def fetch_existing_pmids() -> set[str]:
    """
    Fetch all existing PMIDs from BigQuery.

    This enables deduplication: we skip any paper whose PMID
    is already in the database, avoiding duplicate embeddings
    and wasted API calls.

    Returns:
        Set of PMID strings already in BigQuery
    """
    print("Fetching existing PMIDs from BigQuery for deduplication...")
    client = bigquery.Client(project=PROJECT_ID)

    query = f"""
    SELECT pmid
    FROM `{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}`
    """

    results = client.query(query).result()
    existing_pmids = {row.pmid for row in results}

    print(f"  Found {len(existing_pmids)} existing PMIDs in database")
    return existing_pmids


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


def filter_papers(
    papers: list[dict],
    existing_pmids: set[str],
    max_papers: int,
    min_year: int = MIN_YEAR,
    max_year: int = MAX_YEAR,
) -> tuple[list[dict], dict]:
    """
    Filter papers for incremental ingestion.

    Applies three filters in order:
    1. Deduplication: skip papers already in BigQuery
    2. Year range: only include papers with valid pub_year in range
    3. Max limit: cap total papers to control costs

    Args:
        papers: Raw list of paper dictionaries
        existing_pmids: Set of PMIDs already in BigQuery
        max_papers: Maximum number of papers to process
        min_year: Minimum publication year (inclusive)
        max_year: Maximum publication year (inclusive)

    Returns:
        Tuple of (filtered_papers, stats_dict)
    """
    stats = {
        "total_input": len(papers),
        "skipped_duplicate": 0,
        "skipped_no_year": 0,
        "skipped_year_range": 0,
        "skipped_limit": 0,
        "eligible": 0,
    }

    filtered = []

    for paper in papers:
        pmid = paper.get("pmid")
        pub_year = paper.get("pub_year")

        # 1. Deduplication: skip if PMID already exists
        if pmid in existing_pmids:
            stats["skipped_duplicate"] += 1
            continue

        # 2. Year validation: skip if no year or invalid
        if pub_year is None:
            stats["skipped_no_year"] += 1
            continue

        # 3. Year range: only 2020-2025
        if not (min_year <= pub_year <= max_year):
            stats["skipped_year_range"] += 1
            continue

        # 4. Max limit: stop if we've hit the cap
        if len(filtered) >= max_papers:
            stats["skipped_limit"] += 1
            continue

        filtered.append(paper)

    stats["eligible"] = len(filtered)
    return filtered, stats


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
    Generate embeddings for papers with per-paper error handling.

    If embedding fails for a paper, it's skipped and ingestion
    continues. This ensures one bad record doesn't stop the run.

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
    failed_pmids = []

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
                    "pub_year": paper.get("pub_year"),
                }
                embedded_papers.append(embedded_paper)

        except Exception as e:
            # Per-batch error handling: log and continue
            # This ensures one bad batch doesn't stop the entire run
            print(f"  Warning: Error embedding batch at {i}: {e}")
            failed += len(batch)
            failed_pmids.extend([p.get("pmid", "unknown") for p in batch])

        # Progress update
        processed = min(i + batch_size, total)
        if processed % progress_interval == 0 or processed == total:
            print(f"  Processed {processed}/{total} papers ({processed * 100 // total}%)")

        # Rate limiting
        time.sleep(EMBEDDING_DELAY)

    print(f"\nEmbedding complete: {len(embedded_papers)} succeeded, {failed} failed")
    if failed_pmids:
        print(f"  Failed PMIDs: {failed_pmids[:10]}{'...' if len(failed_pmids) > 10 else ''}")

    return embedded_papers


def load_to_bigquery(
    papers: list[dict],
    batch_size: int = 500,
    dry_run: bool = False,
) -> int:
    """
    Append papers with embeddings to BigQuery.

    IMPORTANT: This is append-only. It never deletes or modifies
    existing data. Deduplication happens before this step.

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
    print(f"Appending {len(papers)} papers to {table_ref}...")

    total_inserted = 0
    total_errors = 0

    for i in range(0, len(papers), batch_size):
        batch = papers[i:i + batch_size]

        errors = client.insert_rows_json(table_ref, batch)

        if errors:
            print(f"  Errors inserting batch at {i}: {errors[:3]}")  # Show first 3 errors
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

    # Sample recent rows
    query = f"""
    SELECT pmid, title, pub_year, ARRAY_LENGTH(embedding) as embedding_dim
    FROM `{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}`
    ORDER BY pub_year DESC NULLS LAST
    LIMIT {limit}
    """

    results = client.query(query).result()

    print(f"\nSample rows from {TABLE_ID}:")
    for row in results:
        year_str = str(row.pub_year) if row.pub_year else "NULL"
        print(f"  PMID: {row.pmid}, Year: {year_str}, Dims: {row.embedding_dim}, Title: {row.title[:50]}...")

    # Summary statistics
    stats_query = f"""
    SELECT
        COUNT(*) AS total,
        COUNTIF(pub_year BETWEEN {MIN_YEAR} AND {MAX_YEAR}) AS recent,
        MIN(pub_year) AS oldest,
        MAX(pub_year) AS newest
    FROM `{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}`
    """

    stats_result = list(client.query(stats_query).result())[0]
    print(f"\nTable statistics:")
    print(f"  Total rows: {stats_result.total}")
    print(f"  Recent ({MIN_YEAR}-{MAX_YEAR}): {stats_result.recent}")
    print(f"  Year range: {stats_result.oldest} - {stats_result.newest}")


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
        description="Generate embeddings and append PubMed papers to BigQuery (incremental)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Incremental Ingestion Features:
  - Deduplication: skips PMIDs already in BigQuery
  - Year filtering: only processes papers from {MIN_YEAR}-{MAX_YEAR}
  - Safety limit: caps papers to --max-papers (default: {DEFAULT_MAX_PAPERS})
  - Error handling: continues if individual papers fail
  - Append-only: never deletes or modifies existing data

Examples:
  # Standard incremental run
  python embed_and_load.py --input pubmed_subset.jsonl

  # Larger batch with custom limit
  python embed_and_load.py --input pubmed_subset.jsonl --max-papers 5000

  # Dry run to test without loading
  python embed_and_load.py --input pubmed_subset.jsonl --dry-run

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
        "--max-papers", "-m",
        type=int,
        default=DEFAULT_MAX_PAPERS,
        help=f"Maximum papers to process (default: {DEFAULT_MAX_PAPERS})"
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

    # Verify-only mode
    if args.verify_only:
        verify_data()
        return

    # Load papers from file
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"Error: Input file not found: {input_path}")
        sys.exit(1)

    papers = load_papers(input_path)

    if not papers:
        print("No papers to process")
        sys.exit(0)

    # Fetch existing PMIDs for deduplication
    existing_pmids = fetch_existing_pmids()

    # Filter papers (dedup, year range, max limit)
    filtered_papers, filter_stats = filter_papers(
        papers,
        existing_pmids,
        max_papers=args.max_papers,
        min_year=MIN_YEAR,
        max_year=MAX_YEAR,
    )

    # Print filter statistics
    print(f"\nFilter results:")
    print(f"  Total input: {filter_stats['total_input']}")
    print(f"  Skipped (duplicate): {filter_stats['skipped_duplicate']}")
    print(f"  Skipped (no year): {filter_stats['skipped_no_year']}")
    print(f"  Skipped (year out of range): {filter_stats['skipped_year_range']}")
    print(f"  Skipped (over limit): {filter_stats['skipped_limit']}")
    print(f"  Eligible for ingestion: {filter_stats['eligible']}")

    if not filtered_papers:
        print("\nNo new papers to process (all filtered out)")
        sys.exit(0)

    # Estimate costs
    costs = estimate_costs(len(filtered_papers))
    print(f"\nEstimated costs for {len(filtered_papers)} papers:")
    print(f"  Embedding: ${costs['embedding_cost']}")
    print(f"  BigQuery insert: ${costs['insert_cost']}")
    print(f"  Storage (monthly): ${costs['storage_cost_monthly']}")
    print(f"  Total one-time: ${costs['total_one_time']}")

    if args.estimate_only:
        return

    # Generate embeddings
    embedded_papers = embed_papers(filtered_papers, args.batch_size)

    if not embedded_papers:
        print("No papers were successfully embedded")
        sys.exit(1)

    # Load to BigQuery (append-only)
    inserted = load_to_bigquery(embedded_papers, dry_run=args.dry_run)

    if not args.dry_run and inserted > 0:
        verify_data()

    print("\nDone!")


if __name__ == "__main__":
    main()
