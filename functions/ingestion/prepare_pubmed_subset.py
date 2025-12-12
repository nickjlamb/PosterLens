#!/usr/bin/env python3
"""
PubMed Subset Preparation Script

Queries PubMed E-utilities API to retrieve a targeted subset of papers
for testing the RAG pipeline. Outputs results to a JSONL file.

Usage:
    python prepare_pubmed_subset.py --query "cancer biomarkers" --max-results 1000
    python prepare_pubmed_subset.py --recent-days 730 --max-results 500
    python prepare_pubmed_subset.py --preset oncology --max-results 2000

Output:
    pubmed_subset.jsonl - One JSON object per line with pmid, title, abstract
"""

import argparse
import json
import time
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional
from urllib.parse import urlencode
import xml.etree.ElementTree as ET

import requests

# PubMed E-utilities base URLs
ESEARCH_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"
EFETCH_URL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"

# Preset search queries for common research areas
PRESET_QUERIES = {
    "oncology": "(cancer[Title/Abstract] OR oncology[Title/Abstract] OR tumor[Title/Abstract]) AND (biomarker[Title/Abstract] OR immunotherapy[Title/Abstract] OR treatment[Title/Abstract])",
    "immunotherapy": "immunotherapy[Title/Abstract] AND (cancer[Title/Abstract] OR checkpoint[Title/Abstract] OR PD-1[Title/Abstract] OR PD-L1[Title/Abstract])",
    "biomarkers": "biomarker[Title/Abstract] AND (diagnostic[Title/Abstract] OR prognostic[Title/Abstract] OR predictive[Title/Abstract])",
    "clinical_trials": "clinical trial[Publication Type] AND (phase 3[Title/Abstract] OR phase III[Title/Abstract])",
    "precision_medicine": "precision medicine[Title/Abstract] OR personalized medicine[Title/Abstract] OR targeted therapy[Title/Abstract]",
}

# Rate limiting: NCBI allows 3 requests/second without API key, 10 with key
REQUEST_DELAY = 0.35  # seconds between requests


def search_pubmed(query: str, max_results: int = 1000, api_key: Optional[str] = None) -> list[str]:
    """
    Search PubMed and return list of PMIDs.

    Args:
        query: PubMed search query
        max_results: Maximum number of results to retrieve
        api_key: Optional NCBI API key for higher rate limits

    Returns:
        List of PMID strings
    """
    params = {
        "db": "pubmed",
        "term": query,
        "retmax": max_results,
        "retmode": "json",
        "sort": "relevance",
    }

    if api_key:
        params["api_key"] = api_key

    print(f"Searching PubMed: {query[:100]}...")

    response = requests.get(ESEARCH_URL, params=params)
    response.raise_for_status()

    data = response.json()
    pmids = data.get("esearchresult", {}).get("idlist", [])

    total_count = int(data.get("esearchresult", {}).get("count", 0))
    print(f"Found {total_count} total results, retrieving {len(pmids)}")

    return pmids


def fetch_paper_details(pmids: list[str], api_key: Optional[str] = None, batch_size: int = 100) -> list[dict]:
    """
    Fetch paper details (title, abstract) for a list of PMIDs.

    Args:
        pmids: List of PubMed IDs
        api_key: Optional NCBI API key
        batch_size: Number of PMIDs to fetch per request

    Returns:
        List of paper dictionaries with pmid, title, abstract
    """
    papers = []
    total_batches = (len(pmids) + batch_size - 1) // batch_size

    for i in range(0, len(pmids), batch_size):
        batch = pmids[i:i + batch_size]
        batch_num = i // batch_size + 1

        print(f"Fetching batch {batch_num}/{total_batches} ({len(batch)} papers)...")

        params = {
            "db": "pubmed",
            "id": ",".join(batch),
            "retmode": "xml",
            "rettype": "abstract",
        }

        if api_key:
            params["api_key"] = api_key

        response = requests.get(EFETCH_URL, params=params)
        response.raise_for_status()

        # Parse XML response
        root = ET.fromstring(response.content)

        for article in root.findall(".//PubmedArticle"):
            paper = parse_article(article)
            if paper and paper.get("abstract"):  # Only include papers with abstracts
                papers.append(paper)

        # Rate limiting
        time.sleep(REQUEST_DELAY)

    return papers


def extract_pub_year(article: ET.Element) -> Optional[int]:
    """
    Extract publication year from PubMed article XML.

    Tries multiple date fields in order of preference:
    1. PubDate/Year (article publication date)
    2. PubDate/MedlineDate (fallback format like "2023 Jan-Feb")
    3. ArticleDate/Year (electronic publication date)

    Args:
        article: XML Element for a PubMed article

    Returns:
        Publication year as integer, or None if not found
    """
    import re

    # Try PubDate/Year first (most common)
    pub_date = article.find(".//PubDate")
    if pub_date is not None:
        year_elem = pub_date.find("Year")
        if year_elem is not None and year_elem.text:
            try:
                return int(year_elem.text)
            except ValueError:
                pass

        # Try MedlineDate (format: "2023 Jan-Feb" or "2023")
        medline_date = pub_date.find("MedlineDate")
        if medline_date is not None and medline_date.text:
            match = re.match(r"(\d{4})", medline_date.text)
            if match:
                try:
                    return int(match.group(1))
                except ValueError:
                    pass

    # Try ArticleDate (electronic publication)
    article_date = article.find(".//ArticleDate")
    if article_date is not None:
        year_elem = article_date.find("Year")
        if year_elem is not None and year_elem.text:
            try:
                return int(year_elem.text)
            except ValueError:
                pass

    return None


def parse_article(article: ET.Element) -> Optional[dict]:
    """
    Parse a PubmedArticle XML element into a dictionary.

    Args:
        article: XML Element for a PubMed article

    Returns:
        Dictionary with pmid, title, abstract, pub_year or None if parsing fails
    """
    try:
        # Extract PMID
        pmid_elem = article.find(".//PMID")
        if pmid_elem is None:
            return None
        pmid = pmid_elem.text

        # Extract title
        title_elem = article.find(".//ArticleTitle")
        title = title_elem.text if title_elem is not None else ""

        # Extract abstract - may have multiple sections
        abstract_parts = []
        abstract_elem = article.find(".//Abstract")
        if abstract_elem is not None:
            for abstract_text in abstract_elem.findall(".//AbstractText"):
                # Handle labeled sections (Background, Methods, Results, etc.)
                label = abstract_text.get("Label", "")
                text = abstract_text.text or ""

                # Also get any nested text
                if abstract_text.tail:
                    text += abstract_text.tail

                # Get text from child elements
                for child in abstract_text:
                    if child.text:
                        text += child.text
                    if child.tail:
                        text += child.tail

                if label and text:
                    abstract_parts.append(f"{label}: {text}")
                elif text:
                    abstract_parts.append(text)

        abstract = " ".join(abstract_parts).strip()

        # Skip papers without abstracts
        if not abstract:
            return None

        # Extract publication year
        pub_year = extract_pub_year(article)

        return {
            "pmid": pmid,
            "title": title,
            "abstract": abstract,
            "pub_year": pub_year,
        }

    except Exception as e:
        print(f"Warning: Failed to parse article: {e}")
        return None


def build_date_query(days: int) -> str:
    """
    Build a PubMed date range query for recent papers.

    Args:
        days: Number of days to look back

    Returns:
        PubMed date range query string
    """
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)

    start_str = start_date.strftime("%Y/%m/%d")
    end_str = end_date.strftime("%Y/%m/%d")

    return f'("{start_str}"[Date - Publication] : "{end_str}"[Date - Publication])'


def save_to_jsonl(papers: list[dict], output_path: Path) -> None:
    """
    Save papers to a JSONL file.

    Args:
        papers: List of paper dictionaries
        output_path: Path to output file
    """
    with open(output_path, "w", encoding="utf-8") as f:
        for paper in papers:
            f.write(json.dumps(paper, ensure_ascii=False) + "\n")

    print(f"Saved {len(papers)} papers to {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Prepare a PubMed subset for RAG testing",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Search by keywords
  python prepare_pubmed_subset.py --query "cancer biomarkers immunotherapy" --max-results 1000

  # Get recent papers (last 2 years)
  python prepare_pubmed_subset.py --recent-days 730 --max-results 500

  # Use a preset query
  python prepare_pubmed_subset.py --preset oncology --max-results 2000

  # Combine preset with date filter
  python prepare_pubmed_subset.py --preset immunotherapy --recent-days 365 --max-results 1000

Available presets: oncology, immunotherapy, biomarkers, clinical_trials, precision_medicine
        """
    )

    parser.add_argument(
        "--query", "-q",
        type=str,
        help="Custom PubMed search query"
    )

    parser.add_argument(
        "--preset", "-p",
        type=str,
        choices=list(PRESET_QUERIES.keys()),
        help="Use a preset search query"
    )

    parser.add_argument(
        "--recent-days", "-d",
        type=int,
        help="Only include papers from the last N days"
    )

    parser.add_argument(
        "--max-results", "-n",
        type=int,
        default=1000,
        help="Maximum number of papers to retrieve (default: 1000)"
    )

    parser.add_argument(
        "--output", "-o",
        type=str,
        default="pubmed_subset.jsonl",
        help="Output file path (default: pubmed_subset.jsonl)"
    )

    parser.add_argument(
        "--api-key",
        type=str,
        help="NCBI API key for higher rate limits (optional)"
    )

    args = parser.parse_args()

    # Build the search query
    query_parts = []

    if args.preset:
        query_parts.append(f"({PRESET_QUERIES[args.preset]})")
        print(f"Using preset: {args.preset}")

    if args.query:
        query_parts.append(f"({args.query})")

    if args.recent_days:
        date_query = build_date_query(args.recent_days)
        query_parts.append(date_query)
        print(f"Filtering to last {args.recent_days} days")

    if not query_parts:
        print("Error: Please specify --query, --preset, or --recent-days")
        sys.exit(1)

    # Combine query parts with AND
    final_query = " AND ".join(query_parts)

    # Add filter for papers with abstracts
    final_query = f"({final_query}) AND hasabstract[text]"

    print(f"\nFinal query: {final_query}\n")

    # Search PubMed
    pmids = search_pubmed(final_query, args.max_results, args.api_key)

    if not pmids:
        print("No papers found matching the query")
        sys.exit(0)

    # Fetch paper details
    papers = fetch_paper_details(pmids, args.api_key)

    print(f"\nRetrieved {len(papers)} papers with abstracts")

    # Save to JSONL
    output_path = Path(args.output)
    save_to_jsonl(papers, output_path)

    # Print summary statistics
    total_chars = sum(len(p["abstract"]) for p in papers)
    avg_chars = total_chars // len(papers) if papers else 0

    print(f"\nSummary:")
    print(f"  Total papers: {len(papers)}")
    print(f"  Average abstract length: {avg_chars} characters")
    print(f"  Total abstract text: {total_chars:,} characters")
    print(f"  Estimated embedding tokens: ~{total_chars // 4:,}")


if __name__ == "__main__":
    main()
