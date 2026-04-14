"""
Image Intelligence Processor
============================
A production-grade Lambda function that analyzes images using Amazon Rekognition
and generates structured intelligence reports for downstream applications.

Architecture: S3 → SQS → Lambda → Rekognition → S3 (reports) + CloudWatch

Author: [Your Name]
Date: 2024
"""

import json
import boto3
import urllib.parse
import logging
import os
import io
import time
from datetime import datetime, timezone
from typing import Optional
from PIL import Image

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION & INITIALIZATION
# ─────────────────────────────────────────────────────────────────────────────

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS Clients (initialized at module level for connection reuse)
rekognition = boto3.client("rekognition")
s3 = boto3.client("s3")
cloudwatch = boto3.client("cloudwatch")

# Environment-based configuration (allows deployment flexibility)
CONFIG = {
    "OUTPUT_BUCKET": os.environ.get("OUTPUT_BUCKET", "destination-bucket"),
    "OUTPUT_PREFIX": os.environ.get("OUTPUT_PREFIX", "intelligence-reports/"),
    "THUMBNAIL_ENABLED": os.environ.get("THUMBNAIL_ENABLED", "true").lower() == "true",
    "THUMBNAIL_SIZE": int(os.environ.get("THUMBNAIL_SIZE", "256")),
    "MAX_LABELS": int(os.environ.get("MAX_LABELS", "50")),
    "MIN_CONFIDENCE": float(os.environ.get("MIN_CONFIDENCE", "60.0")),
    "ENABLE_FACE_DETECTION": os.environ.get("ENABLE_FACE_DETECTION", "false").lower() == "true",
    "ENABLE_TEXT_DETECTION": os.environ.get("ENABLE_TEXT_DETECTION", "false").lower() == "true",
    "ENABLE_CONTENT_MODERATION": os.environ.get("ENABLE_CONTENT_MODERATION", "true").lower() == "true",
    "METRICS_NAMESPACE": os.environ.get("METRICS_NAMESPACE", "ImageIntelligence"),
}


# ─────────────────────────────────────────────────────────────────────────────
# MAIN ENTRY POINT
# ─────────────────────────────────────────────────────────────────────────────

def lambda_handler(event: dict, context) -> dict:
    """
    AWS Lambda entry point triggered by SQS events from S3 notifications.
    
    Processes a batch of image upload events, analyzes each image using
    Amazon Rekognition, and stores structured intelligence reports in S3.
    
    Args:
        event: SQS event containing S3 notification payloads
        context: Lambda context object
        
    Returns:
        dict: Standard Lambda response with processing summary
    """
    start_time = time.time()
    batch_id = context.aws_request_id if context else "unknown"
    
    logger.info(
        "Starting batch processing",
        extra={
            "batch_id": batch_id,
            "record_count": len(event.get("Records", [])),
            "function_version": context.function_version if context else "unknown",
        }
    )
    
    results = []
    metrics = {"processed": 0, "successful": 0, "failed": 0, "skipped": 0}
    
    for idx, record in enumerate(event.get("Records", []), 1):
        try:
            metrics["processed"] += 1  # Track total attempted
            # Parse and validate SQS message
            s3_event = _parse_sqs_message(record, idx)
            if not s3_event:
                metrics["skipped"] += 1
                continue
                
            # Process the S3 event
            result = _process_image_event(s3_event, batch_id)
            results.append(result)
            
            if result.get("status") == "success":
                metrics["successful"] += 1
            else:
                metrics["failed"] += 1
                
        except Exception as exc:
            logger.exception(
                "Unhandled error processing record %d", idx,
                extra={"batch_id": batch_id, "error": str(exc)}
            )
            metrics["failed"] += 1
            results.append({
                "record_index": idx,
                "status": "error",
                "error": f"Unhandled exception: {str(exc)}",
                "batch_id": batch_id,
            })
    
    # Emit CloudWatch metrics for observability
    _emit_batch_metrics(metrics, time.time() - start_time, batch_id)
    
    # Log batch summary
    logger.info(
        "Batch processing complete",
        extra={
            "batch_id": batch_id,
            "duration_seconds": round(time.time() - start_time, 2),
            **metrics,
        }
    )
    
    return {
        "statusCode": 200,
        "body": json.dumps({
            "batch_id": batch_id,
            "summary": metrics,
            "results": results,
        }),
    }


# ─────────────────────────────────────────────────────────────────────────────
# CORE PROCESSING LOGIC
# ─────────────────────────────────────────────────────────────────────────────

def _parse_sqs_message(record: dict, index: int) -> Optional[dict]:
    """
    Parse SQS message body and extract S3 event payload.
    
    Handles both direct S3 events and nested S3 events within SQS.
    """
    try:
        body = record.get("body", "")
        if not body:
            logger.warning("Record %d: Empty message body", index)
            return None
            
        s3_event = json.loads(body)
        
        # Handle nested S3 event structure
        if "Records" in s3_event and isinstance(s3_event["Records"], list):
            return s3_event["Records"][0] if s3_event["Records"] else None
            
        # Handle direct S3 event structure
        if "s3" in s3_event:
            return s3_event
            
        logger.warning("Record %d: Unrecognized event format", index)
        return None
        
    except json.JSONDecodeError as e:
        logger.error("Record %d: Failed to parse JSON: %s", index, e)
        return None
    except Exception as e:
        logger.error("Record %d: Error parsing message: %s", index, e)
        return None


def _process_image_event(s3_record: dict, batch_id: str) -> dict:
    """
    Process a single S3 image upload event end-to-end.
    
    Orchestrates: download → analyze → generate report → upload → thumbnail
    """
    # Extract S3 location
    try:
        source_bucket = s3_record["s3"]["bucket"]["name"]
        object_key = urllib.parse.unquote_plus(
            s3_record["s3"]["object"]["key"], encoding="utf-8"
        )
        object_size = s3_record["s3"]["object"].get("size", 0)
        event_time = s3_record.get("eventTime", datetime.now(timezone.utc).isoformat())
    except KeyError as e:
        return {"status": "error", "error": f"Missing required field: {e}"}
    
    logger.info(
        "Processing image",
        extra={
            "batch_id": batch_id,
            "source": f"s3://{source_bucket}/{object_key}",
            "size_bytes": object_size,
        }
    )
    
    start_time = time.time()
    
    try:
        # Step 1: Download and validate image
        image_data = _download_and_validate_image(source_bucket, object_key)
        if not image_data:
            raise ValueError("Failed to download or validate image")
        
        # Step 2: Run Rekognition analyses
        analysis_results = _run_rekognition_analyses(source_bucket, object_key, image_data)
        
        # Step 3: Generate structured intelligence report
        report = _generate_intelligence_report(
            source_bucket=source_bucket,
            object_key=object_key,
            object_size=object_size,
            event_time=event_time,
            analysis_results=analysis_results,
            batch_id=batch_id,
        )
        
        # Step 4: Upload report to destination bucket
        report_key = _upload_report(report, object_key)
        
        # Step 5: Generate and upload thumbnail (if enabled)
        thumbnail_key = None
        if CONFIG["THUMBNAIL_ENABLED"]:
            thumbnail_key = _generate_and_upload_thumbnail(
                image_data, object_key, CONFIG["THUMBNAIL_SIZE"]
            )
        
        processing_time = time.time() - start_time
        
        logger.info(
            "Successfully processed image",
            extra={
                "batch_id": batch_id,
                "source": f"s3://{source_bucket}/{object_key}",
                "report_key": report_key,
                "thumbnail_key": thumbnail_key,
                "processing_time_seconds": round(processing_time, 2),
                "labels_detected": len(analysis_results.get("labels", [])),
            }
        )
        
        return {
            "status": "success",
            "source": f"s3://{source_bucket}/{object_key}",
            "report": f"s3://{CONFIG['OUTPUT_BUCKET']}/{report_key}",
            "thumbnail": f"s3://{CONFIG['OUTPUT_BUCKET']}/{thumbnail_key}" if thumbnail_key else None,
            "labels_count": len(analysis_results.get("labels", [])),
            "processing_time_seconds": round(processing_time, 2),
            "batch_id": batch_id,
        }
        
    except Exception as exc:
        logger.exception(
            "Failed to process image",
            extra={
                "batch_id": batch_id,
                "source": f"s3://{source_bucket}/{object_key}",
                "error": str(exc),
            }
        )
        return {
            "status": "error",
            "source": f"s3://{source_bucket}/{object_key}",
            "error": str(exc),
            "batch_id": batch_id,
        }


# ─────────────────────────────────────────────────────────────────────────────
# REKOGNITION ANALYSIS FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────

def _run_rekognition_analyses(bucket: str, key: str, image_data: Image.Image) -> dict:
    """
    Execute comprehensive Rekognition analyses on the image.
    
    Returns consolidated results from all enabled analysis types.
    """
    results = {}
    s3_object = {"S3Object": {"Bucket": bucket, "Name": key}}
    
    # 1. Label Detection (always enabled)
    results["labels"] = _detect_labels(s3_object)
    
    # 2. Dominant Colors
    results["colors"] = _detect_colors(s3_object)
    
    # 3. Face Detection (optional)
    if CONFIG["ENABLE_FACE_DETECTION"]:
        results["faces"] = _detect_faces(s3_object)
    
    # 4. Text Detection / OCR (optional)
    if CONFIG["ENABLE_TEXT_DETECTION"]:
        results["text"] = _detect_text(s3_object)
    
    # 5. Content Moderation (optional)
    if CONFIG["ENABLE_CONTENT_MODERATION"]:
        results["moderation"] = _moderate_content(s3_object)
    
    return results


def _detect_labels(s3_object: dict) -> list:
    """Detect labels/objects in the image with confidence scores."""
    try:
        response = rekognition.detect_labels(
            Image=s3_object,
            MaxLabels=CONFIG["MAX_LABELS"],
            MinConfidence=CONFIG["MIN_CONFIDENCE"],
        )
        
        labels = []
        for label in response.get("Labels", []):
            labels.append({
                "name": label["Name"],
                "confidence": round(label["Confidence"], 2),
                "categories": [c["Name"] for c in label.get("Categories", [])],
                "instances": [
                    {
                        "bounding_box": {
                            "width": round(inst["BoundingBox"]["Width"], 4),
                            "height": round(inst["BoundingBox"]["Height"], 4),
                            "left": round(inst["BoundingBox"]["Left"], 4),
                            "top": round(inst["BoundingBox"]["Top"], 4),
                        },
                        "confidence": round(inst["Confidence"], 2),
                    }
                    for inst in label.get("Instances", [])
                ],
                "parents": [p["Name"] for p in label.get("Parents", [])],
            })
        
        # Sort by confidence descending
        return sorted(labels, key=lambda x: x["confidence"], reverse=True)
        
    except Exception as e:
        logger.warning("Label detection failed: %s", e)
        return []


def _detect_colors(s3_object: dict) -> list:
    """Detect dominant colors in the image."""
    try:
        response = rekognition.detect_labels(
            Image=s3_object,
            MaxLabels=10,
            MinConfidence=CONFIG["MIN_CONFIDENCE"],
        )
        
        # Extract color-related labels
        colors = []
        color_keywords = ["red", "blue", "green", "yellow", "orange", "purple", 
                         "pink", "brown", "black", "white", "gray", "color"]
        
        for label in response.get("Labels", []):
            if any(kw in label["Name"].lower() for kw in color_keywords):
                colors.append({
                    "name": label["Name"],
                    "confidence": round(label["Confidence"], 2),
                })
        
        return colors[:5]  # Top 5 colors
        
    except Exception as e:
        logger.warning("Color detection failed: %s", e)
        return []


def _detect_faces(s3_object: dict) -> list:
    """Detect faces and extract attributes."""
    try:
        response = rekognition.detect_faces(
            Image=s3_object,
            Attributes=["ALL"],
        )
        
        faces = []
        for face in response.get("FaceDetails", []):
            faces.append({
                "bounding_box": {
                    "width": round(face["BoundingBox"]["Width"], 4),
                    "height": round(face["BoundingBox"]["Height"], 4),
                    "left": round(face["BoundingBox"]["Left"], 4),
                    "top": round(face["BoundingBox"]["Top"], 4),
                },
                "confidence": round(face["Confidence"], 2),
                "attributes": {
                    "gender": face.get("Gender", {}),
                    "age_range": face.get("AgeRange", {}),
                    "emotions": [
                        {"type": e["Type"], "confidence": round(e["Confidence"], 2)}
                        for e in face.get("Emotions", [])[:3]
                    ],
                    "smile": face.get("Smile", {}),
                    "eyeglasses": face.get("Eyeglasses", {}),
                    "sunglasses": face.get("Sunglasses", {}),
                },
            })
        
        return faces
        
    except Exception as e:
        logger.warning("Face detection failed: %s", e)
        return []


def _detect_text(s3_object: dict) -> list:
    """Detect and extract text from the image (OCR)."""
    try:
        response = rekognition.detect_text(Image=s3_object)
        
        texts = []
        for item in response.get("TextDetections", []):
            if item["Type"] == "LINE":  # Only process full lines, not individual words
                texts.append({
                    "text": item["DetectedText"],
                    "confidence": round(item["Confidence"], 2),
                    "bounding_box": {
                        "width": round(item["Geometry"]["BoundingBox"]["Width"], 4),
                        "height": round(item["Geometry"]["BoundingBox"]["Height"], 4),
                        "left": round(item["Geometry"]["BoundingBox"]["Left"], 4),
                        "top": round(item["Geometry"]["BoundingBox"]["Top"], 4),
                    },
                })
        
        return texts[:20]  # Limit to top 20 text lines
        
    except Exception as e:
        logger.warning("Text detection failed: %s", e)
        return []


def _moderate_content(s3_object: dict) -> dict:
    """Check image for unsafe/inappropriate content."""
    try:
        response = rekognition.detect_moderation_labels(
            Image=s3_object,
            MinConfidence=CONFIG["MIN_CONFIDENCE"],
        )
        
        return {
            "is_safe": len(response.get("ModerationLabels", [])) == 0,
            "labels": [
                {
                    "name": label["Name"],
                    "confidence": round(label["Confidence"], 2),
                    "parent": label.get("ParentName"),
                }
                for label in response.get("ModerationLabels", [])
            ],
        }
        
    except Exception as e:
        logger.warning("Content moderation failed: %s", e)
        return {"is_safe": None, "error": str(e)}


# ─────────────────────────────────────────────────────────────────────────────
# REPORT GENERATION & STORAGE
# ─────────────────────────────────────────────────────────────────────────────

def _generate_intelligence_report(
    source_bucket: str,
    object_key: str,
    object_size: int,
    event_time: str,
    analysis_results: dict,
    batch_id: str,
) -> dict:
    """Generate a comprehensive, structured intelligence report."""
    
    # Extract key insights for quick reference
    top_labels = analysis_results.get("labels", [])[:5]
    faces = analysis_results.get("faces", [])
    text = analysis_results.get("text", [])
    moderation = analysis_results.get("moderation", {})
    
    return {
        "metadata": {
            "report_version": "1.0",
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "batch_id": batch_id,
            "source": {
                "bucket": source_bucket,
                "key": object_key,
                "size_bytes": object_size,
                "upload_time": event_time,
            },
            "processing": {
                "analyzer": "amazon-rekognition",
                "config": {
                    "max_labels": CONFIG["MAX_LABELS"],
                    "min_confidence": CONFIG["MIN_CONFIDENCE"],
                    "face_detection": CONFIG["ENABLE_FACE_DETECTION"],
                    "text_detection": CONFIG["ENABLE_TEXT_DETECTION"],
                    "content_moderation": CONFIG["ENABLE_CONTENT_MODERATION"],
                },
            },
        },
        "summary": {
            "label_count": len(analysis_results.get("labels", [])),
            "top_labels": [l["name"] for l in top_labels],
            "face_count": len(faces),
            "text_snippets": [t["text"] for t in text[:3]],
            "is_content_safe": moderation.get("is_safe"),
            "dominant_colors": [c["name"] for c in analysis_results.get("colors", [])[:3]],
        },
        "details": {
            "labels": analysis_results.get("labels", []),
            "colors": analysis_results.get("colors", []),
            "faces": faces,
            "text": text,
            "moderation": moderation,
        },
        "tags": _generate_search_tags(analysis_results),
    }


def _generate_search_tags(analysis_results: dict) -> list:
    """Generate searchable tags from analysis results for indexing."""
    tags = set()
    
    # Add top labels as tags
    for label in analysis_results.get("labels", [])[:10]:
        tags.add(label["name"].lower().replace(" ", "_"))
        tags.extend([c.lower().replace(" ", "_") for c in label.get("categories", [])])
    
    # Add color tags
    for color in analysis_results.get("colors", []):
        tags.add(f"color_{color['name'].lower().replace(' ', '_')}")
    
    # Add content type tags
    if analysis_results.get("faces"):
        tags.add("contains_faces")
    if analysis_results.get("text"):
        tags.add("contains_text")
    
    # Add moderation tags
    moderation = analysis_results.get("moderation", {})
    if moderation.get("is_safe") is False:
        tags.add("flagged_content")
    elif moderation.get("is_safe") is True:
        tags.add("safe_content")
    
    return sorted(list(tags))


def _upload_report(report: dict, original_key: str) -> str:
    """Upload the intelligence report to the destination S3 bucket."""
    
    # Generate output key with timestamp for uniqueness
    stem = os.path.splitext(os.path.basename(original_key))[0].replace("/", "_")
    timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    report_key = f"{CONFIG['OUTPUT_PREFIX']}reports/{stem}_{timestamp}.json"
    
    # Upload with metadata for traceability
    s3.put_object(
        Bucket=CONFIG["OUTPUT_BUCKET"],
        Key=report_key,
        Body=json.dumps(report, indent=2),
        ContentType="application/json",
        Metadata={
            "source-key": original_key,
            "report-type": "intelligence-report",
            "generated-by": "image-intelligence-processor",
        },
    )
    
    logger.debug("Uploaded report: s3://%s/%s", CONFIG["OUTPUT_BUCKET"], report_key)
    return report_key


# ─────────────────────────────────────────────────────────────────────────────
# IMAGE PROCESSING UTILITIES
# ─────────────────────────────────────────────────────────────────────────────

def _download_and_validate_image(bucket: str, key: str) -> Optional[Image.Image]:
    """Download image from S3 and validate it's a processable format."""
    try:
        response = s3.get_object(Bucket=bucket, Key=key)
        
        # Validate content type — also accept generic types and fall back to extension
        content_type = response.get("ContentType", "")
        valid_types = [
            "image/jpeg", "image/jpg", "image/png", "image/webp",
            "binary/octet-stream", "application/octet-stream",
        ]
        valid_extensions = (".jpg", ".jpeg", ".png", ".webp")
        is_valid_type = content_type in valid_types
        is_valid_ext = key.lower().endswith(valid_extensions)
        if not (is_valid_type or is_valid_ext):
            logger.warning("Unsupported content type: %s for key: %s", content_type, key)
            return None
        
        # Load and validate image
        image_data = response["Body"].read()
        image = Image.open(io.BytesIO(image_data))
        
        # Convert to RGB for consistent processing
        if image.mode in ("RGBA", "P", "LA"):
            image = image.convert("RGB")
        
        # Basic validation
        if image.width < 10 or image.height < 10:
            logger.warning("Image too small: %dx%d", image.width, image.height)
            return None
        
        return image
        
    except Exception as e:
        logger.error("Failed to download/validate image s3://%s/%s: %s", bucket, key, e)
        return None


def _generate_and_upload_thumbnail(
    image: Image.Image,
    original_key: str,
    max_size: int,
) -> Optional[str]:
    """Generate and upload a thumbnail version of the image."""
    try:
        # Create thumbnail maintaining aspect ratio
        image_copy = image.copy()
        image_copy.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
        
        # Generate output key
        stem = os.path.splitext(os.path.basename(original_key))[0].replace("/", "_")
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        thumbnail_key = f"{CONFIG['OUTPUT_PREFIX']}thumbnails/{stem}_{max_size}px_{timestamp}.jpg"
        
        # Upload thumbnail
        buffer = io.BytesIO()
        image_copy.save(buffer, format="JPEG", quality=85, optimize=True)
        buffer.seek(0)
        
        s3.put_object(
            Bucket=CONFIG["OUTPUT_BUCKET"],
            Key=thumbnail_key,
            Body=buffer,
            ContentType="image/jpeg",
            Metadata={
                "source-key": original_key,
                "thumbnail-size": str(max_size),
                "generated-by": "image-intelligence-processor",
            },
        )
        
        logger.debug("Uploaded thumbnail: s3://%s/%s", CONFIG["OUTPUT_BUCKET"], thumbnail_key)
        return thumbnail_key
        
    except Exception as e:
        logger.warning("Failed to generate thumbnail: %s", e)
        return None


# ─────────────────────────────────────────────────────────────────────────────
# OBSERVABILITY & METRICS
# ─────────────────────────────────────────────────────────────────────────────

def _emit_batch_metrics(metrics: dict, duration: float, batch_id: str):
    """Emit custom CloudWatch metrics for monitoring and alerting."""
    try:
        cloudwatch.put_metric_data(
            Namespace=CONFIG["METRICS_NAMESPACE"],
            MetricData=[
                {
                    "MetricName": "BatchProcessed",
                    "Value": 1,
                    "Unit": "Count",
                    "Dimensions": [
                        {"Name": "Status", "Value": "Completed"},
                        {"Name": "BatchId", "Value": batch_id[:8]},  # Truncate for dimension limit
                    ],
                },
                {
                    "MetricName": "ImagesProcessed",
                    "Value": metrics["processed"],
                    "Unit": "Count",
                },
                {
                    "MetricName": "ProcessingSuccess",
                    "Value": metrics["successful"],
                    "Unit": "Count",
                },
                {
                    "MetricName": "ProcessingFailure",
                    "Value": metrics["failed"],
                    "Unit": "Count",
                },
                {
                    "MetricName": "BatchDuration",
                    "Value": round(duration, 2),
                    "Unit": "Seconds",
                },
            ],
        )
    except Exception as e:
        logger.warning("Failed to emit CloudWatch metrics: %s", e)
        # Don't fail the batch for metrics emission errors