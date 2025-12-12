"""
PosterLens Cloud Functions - Evidence V2 API

This module provides the evidenceV2 endpoint for retrieving evidence-based
research papers related to scientific poster content using RAG (Retrieval
Augmented Generation) with BigQuery vector search and Vertex AI embeddings.

Includes a lightweight, deterministic re-ranking layer that adjusts paper
ordering based on recency, keyword overlap, and specificity signals.
"""

import json
import logging
import re
from datetime import datetime
from functools import wraps

import functions_framework
from flask import jsonify, Request

# Vertex AI and BigQuery imports
import vertexai
from vertexai.language_models import TextEmbeddingModel
from google.cloud import bigquery

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# =============================================================================
# RAG Pipeline Configuration (initialized once for warm starts)
# =============================================================================

PROJECT_ID = "posterlens-backend"
LOCATION = "europe-west2"
DATASET_ID = "pubmed_rag"
TABLE_ID = "papers"
EMBEDDING_MODEL = "text-embedding-004"

# =============================================================================
# Re-Ranking Configuration
# =============================================================================
# These boosts are intentionally small so vector similarity remains dominant.
# All values are additive adjustments to the similarity score (0.0 - 1.0 range).

# Recency boost: papers from recent years get a small boost
RERANK_RECENCY_BOOST = 0.03          # Max boost for very recent papers
RERANK_RECENCY_WINDOW_YEARS = 5      # Papers within this window get full boost
RERANK_RECENCY_DECAY_YEARS = 10      # Papers older than this get no boost

# Keyword overlap boost: papers matching poster keywords get a boost
RERANK_KEYWORD_BOOST = 0.04          # Max boost for high keyword overlap
RERANK_KEYWORD_MIN_MATCHES = 2       # Minimum matches to trigger any boost
RERANK_KEYWORD_FULL_MATCHES = 5      # Matches needed for full boost

# Generic penalty: penalise papers with very generic review language
RERANK_GENERIC_PENALTY = -0.02       # Penalty for generic review papers

# Common scientific stopwords to exclude from keyword extraction
SCIENTIFIC_STOPWORDS = {
    "study", "studies", "research", "results", "analysis", "method", "methods",
    "conclusion", "conclusions", "objective", "objectives", "background",
    "introduction", "discussion", "patients", "patient", "treatment",
    "treatments", "therapy", "clinical", "trial", "trials", "data", "group",
    "groups", "effect", "effects", "significant", "significantly", "compared",
    "showed", "shown", "found", "associated", "using", "based", "including",
    "included", "reported", "observed", "performed", "evaluated", "assessed",
    "determined", "identified", "demonstrated", "indicate", "indicates",
    "suggest", "suggests", "present", "presented", "review", "reviewed",
    "article", "paper", "abstract", "figure", "table", "published"
}

# Phrases that indicate a generic review paper (lower specificity)
GENERIC_REVIEW_PHRASES = [
    "comprehensive review",
    "systematic review",
    "literature review",
    "narrative review",
    "overview of",
    "current landscape",
    "state of the art",
    "recent advances in",
    "emerging trends",
]

# =============================================================================
# Explanation Templates
# =============================================================================
# Templates for the "why_relevant" field. Each template is selected based on
# which heuristic signal is most prominent for the paper. Only one is used.

# High keyword overlap (≥3 matches)
EXPLAIN_KEYWORD_OVERLAP = "Matches key terms from the poster: {keywords}."

# Paper is a review article
EXPLAIN_REVIEW_ARTICLE = "Provides a review of concepts related to the poster topic."

# Strong semantic similarity but few keyword matches
EXPLAIN_SEMANTIC_SIMILARITY = "Strong semantic similarity to the poster content."

# Recency boost applied (for future use when year is available)
EXPLAIN_RECENT_STUDY = "Recent study closely aligned with the poster topic."

# Default fallback
EXPLAIN_DEFAULT = "Related to the poster's research area."

# Thresholds for explanation selection
EXPLAIN_KEYWORD_THRESHOLD = 3      # Min keyword matches to mention keywords
EXPLAIN_SIMILARITY_STRONG = 0.60   # Similarity score considered "strong"

# Initialize Vertex AI
vertexai.init(project=PROJECT_ID, location=LOCATION)

# Initialize clients (warm-start optimization)
embedding_model = TextEmbeddingModel.from_pretrained(EMBEDDING_MODEL)
bq_client = bigquery.Client(project=PROJECT_ID)

logger.info(f"Initialized RAG pipeline: project={PROJECT_ID}, location={LOCATION}")


# =============================================================================
# Re-Ranking Functions
# =============================================================================

def extract_keywords(text: str, max_keywords: int = 20) -> set:
    """
    Extract meaningful keywords from text for re-ranking comparison.

    Strategy:
    - Tokenize and lowercase
    - Filter out stopwords and very short words
    - Keep words that look like scientific terms (longer, possibly hyphenated)

    Args:
        text: Input text (poster content)
        max_keywords: Maximum number of keywords to return

    Returns:
        Set of lowercase keyword strings
    """
    # Tokenize: split on whitespace and punctuation, keep hyphens within words
    words = re.findall(r'\b[a-zA-Z][-a-zA-Z]{2,}\b', text.lower())

    # Filter out stopwords and common scientific terms
    keywords = [
        w for w in words
        if w not in SCIENTIFIC_STOPWORDS
        and len(w) >= 4  # Skip very short words
    ]

    # Count frequency and take top N unique keywords
    from collections import Counter
    word_counts = Counter(keywords)
    top_keywords = {word for word, _ in word_counts.most_common(max_keywords)}

    return top_keywords


def compute_recency_boost(year: int) -> float:
    """
    Compute a recency boost for a paper based on publication year.

    Heuristic:
    - Papers within RERANK_RECENCY_WINDOW_YEARS get full boost
    - Papers between window and decay threshold get proportional boost
    - Papers older than RERANK_RECENCY_DECAY_YEARS get no boost

    Args:
        year: Publication year of the paper

    Returns:
        Boost value (0.0 to RERANK_RECENCY_BOOST)
    """
    if year is None or year <= 0:
        return 0.0

    current_year = datetime.utcnow().year
    age = current_year - year

    if age <= RERANK_RECENCY_WINDOW_YEARS:
        # Full boost for recent papers
        return RERANK_RECENCY_BOOST
    elif age <= RERANK_RECENCY_DECAY_YEARS:
        # Linear decay between window and cutoff
        decay_range = RERANK_RECENCY_DECAY_YEARS - RERANK_RECENCY_WINDOW_YEARS
        age_beyond_window = age - RERANK_RECENCY_WINDOW_YEARS
        decay_factor = 1.0 - (age_beyond_window / decay_range)
        return RERANK_RECENCY_BOOST * decay_factor
    else:
        # No boost for old papers
        return 0.0


def compute_keyword_boost(paper_text: str, poster_keywords: set) -> tuple:
    """
    Compute a keyword overlap boost based on shared terms.

    Heuristic:
    - Count how many poster keywords appear in the paper's title/abstract
    - Require minimum matches to avoid noise
    - Scale linearly up to full boost

    Args:
        paper_text: Combined title + abstract of the paper
        poster_keywords: Set of keywords extracted from poster

    Returns:
        Tuple of (boost_value, matched_keywords_list)
    """
    if not poster_keywords:
        return 0.0, []

    paper_lower = paper_text.lower()
    matched = [kw for kw in poster_keywords if kw in paper_lower]
    match_count = len(matched)

    if match_count < RERANK_KEYWORD_MIN_MATCHES:
        return 0.0, matched

    # Scale linearly from min to full matches
    effective_matches = min(match_count, RERANK_KEYWORD_FULL_MATCHES)
    match_range = RERANK_KEYWORD_FULL_MATCHES - RERANK_KEYWORD_MIN_MATCHES
    if match_range <= 0:
        return RERANK_KEYWORD_BOOST, matched

    progress = (effective_matches - RERANK_KEYWORD_MIN_MATCHES) / match_range
    return RERANK_KEYWORD_BOOST * progress, matched


def compute_generic_penalty(title: str, abstract: str) -> tuple:
    """
    Apply a small penalty to papers with very generic review language.

    Heuristic:
    - Check for phrases that indicate a broad review rather than specific research
    - Only penalise if found in title (stronger signal) or prominently in abstract

    This helps surface specific studies over broad reviews when similarity is close.

    Args:
        title: Paper title
        abstract: Paper abstract

    Returns:
        Tuple of (penalty_value, is_review_bool)
    """
    title_lower = title.lower() if title else ""
    abstract_lower = abstract.lower() if abstract else ""

    # Check title first (stronger signal)
    for phrase in GENERIC_REVIEW_PHRASES:
        if phrase in title_lower:
            return RERANK_GENERIC_PENALTY, True

    # Check abstract (only first 200 chars where review type is usually stated)
    abstract_start = abstract_lower[:200]
    for phrase in GENERIC_REVIEW_PHRASES:
        if phrase in abstract_start:
            return RERANK_GENERIC_PENALTY, True

    return 0.0, False


def generate_why_relevant(
    similarity_score: float,
    matched_keywords: list,
    is_review: bool,
    has_recency_boost: bool
) -> str:
    """
    Generate a deterministic, human-readable explanation for why a paper was selected.

    The explanation is based on a priority order of signals:
    1. High keyword overlap → mention the matching terms
    2. Review article → acknowledge it provides overview context
    3. Strong similarity → note the semantic match
    4. Default → generic relevance statement

    Only one explanation is returned per paper to keep it concise.

    Args:
        similarity_score: Raw vector similarity (0.0 - 1.0)
        matched_keywords: List of poster keywords found in the paper
        is_review: Whether the paper was detected as a review article
        has_recency_boost: Whether the paper received a recency boost

    Returns:
        A short explanation string (max ~15 words)
    """
    keyword_count = len(matched_keywords)

    # Priority 1: High keyword overlap - most specific explanation
    if keyword_count >= EXPLAIN_KEYWORD_THRESHOLD:
        # Select top 3 keywords for display (prefer shorter, more readable ones)
        display_keywords = sorted(matched_keywords, key=len)[:3]
        keywords_str = ", ".join(display_keywords)
        return EXPLAIN_KEYWORD_OVERLAP.format(keywords=keywords_str)

    # Priority 2: Review article - useful context even if keywords are sparse
    if is_review:
        return EXPLAIN_REVIEW_ARTICLE

    # Priority 3: Strong semantic similarity
    if similarity_score >= EXPLAIN_SIMILARITY_STRONG:
        return EXPLAIN_SEMANTIC_SIMILARITY

    # Priority 4: Recent study (when recency data is available)
    if has_recency_boost:
        return EXPLAIN_RECENT_STUDY

    # Fallback: generic relevance
    return EXPLAIN_DEFAULT


def rerank_papers(papers: list, poster_text: str) -> list:
    """
    Apply deterministic re-ranking to a list of papers.

    The re-ranking applies small additive boosts/penalties to the base
    similarity score. Vector similarity remains the dominant signal.

    Boosts applied:
    1. Recency boost: favours papers from the last ~5 years
    2. Keyword overlap: favours papers matching poster terminology
    3. Generic penalty: slightly penalises broad review papers

    Also generates a "why_relevant" explanation for each paper.

    Args:
        papers: List of paper dicts with 'similarity_score', 'title', 'abstract'
        poster_text: Original poster text for keyword extraction

    Returns:
        Papers list sorted by rerank_score (descending), with scores and explanations
    """
    # Extract keywords from poster for overlap comparison
    poster_keywords = extract_keywords(poster_text)

    for paper in papers:
        similarity = paper.get("similarity_score", 0.0)

        # Combine title and abstract for text matching
        paper_text = f"{paper.get('title', '')} {paper.get('abstract', '')}"

        # Compute individual adjustments (now returning extra info for explanations)
        recency_boost = compute_recency_boost(paper.get("year"))
        keyword_boost, matched_keywords = compute_keyword_boost(paper_text, poster_keywords)
        generic_penalty, is_review = compute_generic_penalty(
            paper.get("title", ""),
            paper.get("abstract", "")
        )

        # Final re-rank score
        rerank_score = similarity + recency_boost + keyword_boost + generic_penalty

        # Store scores for transparency
        paper["rerank_score"] = round(rerank_score, 4)

        # Generate explanation based on signals
        paper["why_relevant"] = generate_why_relevant(
            similarity_score=similarity,
            matched_keywords=matched_keywords,
            is_review=is_review,
            has_recency_boost=(recency_boost > 0)
        )

    # Sort by rerank_score descending
    papers.sort(key=lambda p: p.get("rerank_score", 0), reverse=True)

    return papers


class ValidationError(Exception):
    """Custom exception for request validation errors."""
    def __init__(self, message: str, status_code: int = 400):
        self.message = message
        self.status_code = status_code
        super().__init__(self.message)


def log_request(func):
    """Decorator to log all incoming requests."""
    @wraps(func)
    def wrapper(request: Request):
        request_id = datetime.utcnow().strftime('%Y%m%d%H%M%S%f')

        logger.info(
            f"[{request_id}] Incoming request: "
            f"method={request.method}, "
            f"path={request.path}, "
            f"remote_addr={request.remote_addr}, "
            f"user_agent={request.headers.get('User-Agent', 'unknown')}"
        )

        if request.method == 'POST':
            try:
                body = request.get_json(silent=True)
                text_preview = ""
                if body and 'text' in body:
                    text_preview = body['text'][:100] + '...' if len(body.get('text', '')) > 100 else body.get('text', '')
                logger.info(f"[{request_id}] Request body preview: {text_preview}")
            except Exception as e:
                logger.warning(f"[{request_id}] Could not parse request body: {e}")

        response = func(request)

        logger.info(f"[{request_id}] Response status: {response.status_code}")

        return response

    return wrapper


def validate_request(request: Request) -> dict:
    """
    Validate the incoming request.

    Args:
        request: The Flask request object

    Returns:
        The validated request data as a dictionary

    Raises:
        ValidationError: If validation fails
    """
    # Check HTTP method
    if request.method == 'OPTIONS':
        return {}

    if request.method != 'POST':
        raise ValidationError(
            f"Method {request.method} not allowed. Use POST.",
            status_code=405
        )

    # Check content type
    content_type = request.headers.get('Content-Type', '')
    if 'application/json' not in content_type:
        raise ValidationError(
            "Content-Type must be application/json",
            status_code=415
        )

    # Parse JSON body
    try:
        data = request.get_json(force=True)
    except Exception as e:
        raise ValidationError(f"Invalid JSON: {str(e)}")

    if not data:
        raise ValidationError("Request body is required")

    # Validate required fields
    if 'text' not in data:
        raise ValidationError("Missing required field: 'text'")

    text = data.get('text')
    if not isinstance(text, str):
        raise ValidationError("Field 'text' must be a string")

    if not text.strip():
        raise ValidationError("Field 'text' cannot be empty")

    # Validate text length (reasonable limit for poster text)
    max_length = 50000  # 50KB of text
    if len(text) > max_length:
        raise ValidationError(
            f"Field 'text' exceeds maximum length of {max_length} characters"
        )

    return data


def add_cors_headers(response):
    """Add CORS headers to the response."""
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
    response.headers['Access-Control-Max-Age'] = '3600'
    return response


@functions_framework.http
@log_request
def evidence_v2(request: Request):
    """
    HTTP Cloud Function for the /v2/evidence endpoint.

    Accepts poster text and returns related research papers.
    Currently returns a dummy response - will be connected to
    BigQuery and Vertex AI in future iterations.

    Args:
        request: The Flask request object

    Returns:
        JSON response with status and papers array

    Request format:
        POST /v2/evidence
        Content-Type: application/json

        {
            "text": "Scientific poster text content..."
        }

    Response format:
        {
            "status": "ok",
            "papers": [],
            "metadata": {
                "version": "2.0.0",
                "timestamp": "2024-01-15T10:30:00Z",
                "text_length": 1234
            }
        }
    """
    # Handle CORS preflight requests
    if request.method == 'OPTIONS':
        response = jsonify({})
        response.status_code = 204
        return add_cors_headers(response)

    try:
        # Validate request
        data = validate_request(request)

        text = data.get('text', '')

        # =================================================================
        # RAG Pipeline: Generate embedding and search BigQuery
        # =================================================================

        logger.info(f"Generating embedding for text ({len(text)} chars)...")

        # Step 1: Generate embedding for the input text
        try:
            embedding_response = embedding_model.get_embeddings(
                [text],
                auto_truncate=True,
                output_dimensionality=768,
            )
            query_embedding = embedding_response[0].values
            logger.info(f"Generated embedding with {len(query_embedding)} dimensions")
        except Exception as e:
            logger.error(f"Embedding generation failed: {e}")
            raise Exception(f"Failed to generate embedding: {str(e)}")

        # Step 2: Build vector search query
        # Fetch more candidates than needed for re-ranking, then trim to top 5
        vector_search_query = f"""
        SELECT
            pmid,
            title,
            abstract,
            ML.DISTANCE(embedding, @query_embedding, 'COSINE') AS distance
        FROM `{PROJECT_ID}.{DATASET_ID}.{TABLE_ID}`
        WHERE embedding IS NOT NULL
        ORDER BY distance ASC
        LIMIT 10
        """

        # Step 3: Execute BigQuery vector search
        logger.info("Executing BigQuery vector search...")
        try:
            job_config = bigquery.QueryJobConfig(
                query_parameters=[
                    bigquery.ArrayQueryParameter("query_embedding", "FLOAT64", query_embedding)
                ]
            )

            query_job = bq_client.query(vector_search_query, job_config=job_config)
            results = query_job.result()

        except Exception as e:
            logger.error(f"BigQuery search failed: {e}")
            # Fall back to empty results if table is empty or query fails
            results = []

        # Step 4: Transform results to paper format
        papers = []
        for row in results:
            # Convert distance to similarity score (1 - distance for cosine)
            similarity_score = 1.0 - float(row.distance) if row.distance is not None else 0.0

            papers.append({
                "pmid": row.pmid,
                "title": row.title,
                "abstract": row.abstract,
                "similarity_score": round(similarity_score, 4),
                # Year not currently in BigQuery schema; recency boost will be 0
                # TODO: Add year column to papers table for recency boosting
                "year": None,
            })

        logger.info(f"Found {len(papers)} candidate papers for re-ranking")

        # Step 5: Apply deterministic re-ranking
        # This adjusts ordering based on keyword overlap and specificity,
        # while keeping vector similarity as the dominant signal.
        papers = rerank_papers(papers, text)

        # Trim to top 5 after re-ranking
        papers = papers[:5]

        logger.info(f"Returning top {len(papers)} papers after re-ranking")

        # Step 6: Build response
        # Return both similarity_score (raw) and score (final rerank_score) for transparency
        # The 'score' field is used by the iOS app for display
        # The 'why_relevant' field provides a human-readable explanation
        response_papers = []
        for paper in papers:
            response_papers.append({
                "pmid": paper["pmid"],
                "title": paper["title"],
                "abstract": paper["abstract"],
                "score": paper["rerank_score"],           # Final score used for ordering
                "similarity_score": paper["similarity_score"],  # Raw vector similarity
                "why_relevant": paper["why_relevant"],    # Human-readable explanation
            })

        response_data = {
            "status": "ok",
            "papers": response_papers,
            "metadata": {
                "version": "2.3.0",
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "text_length": len(text),
                "results": len(response_papers),
                "mode": "rag",
                "reranking": "enabled",
            }
        }

        response = jsonify(response_data)
        response.status_code = 200
        return add_cors_headers(response)

    except ValidationError as e:
        logger.warning(f"Validation error: {e.message}")
        response = jsonify({
            "status": "error",
            "error": {
                "code": "VALIDATION_ERROR",
                "message": e.message
            }
        })
        response.status_code = e.status_code
        return add_cors_headers(response)

    except Exception as e:
        logger.exception(f"Unexpected error: {str(e)}")
        response = jsonify({
            "status": "error",
            "error": {
                "code": "INTERNAL_ERROR",
                "message": "An unexpected error occurred. Please try again later."
            }
        })
        response.status_code = 500
        return add_cors_headers(response)
