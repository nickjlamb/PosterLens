"""
PosterLens Cloud Functions - Evidence V2 API

This module provides the evidenceV2 endpoint for retrieving evidence-based
research papers related to scientific poster content.
"""

import json
import logging
from datetime import datetime
from functools import wraps

import functions_framework
from flask import jsonify, Request

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


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

        # Build dummy response
        # TODO: Integrate with BigQuery for paper retrieval
        # TODO: Integrate with Vertex AI for semantic search
        response_data = {
            "status": "ok",
            "papers": [],
            "metadata": {
                "version": "2.0.0",
                "timestamp": datetime.utcnow().isoformat() + "Z",
                "text_length": len(text),
                "note": "This is a placeholder response. BigQuery and Vertex AI integration coming soon."
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
