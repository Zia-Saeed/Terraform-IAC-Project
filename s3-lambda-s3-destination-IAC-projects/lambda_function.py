import json
import boto3
import urllib.parse
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

rekognition = boto3.client("rekognition")
s3 = boto3.client("s3")

# ── Config ────────────────────────────────────────────────────────────────────
OUTPUT_BUCKET = "destination-bucket-for-lambda-function-output"   # ← change this
OUTPUT_PREFIX = "detections/"               # folder inside the output bucket
MAX_LABELS    = 20
MIN_CONFIDENCE = 70.0                       # minimum confidence %
# ─────────────────────────────────────────────────────────────────────────────


def lambda_handler(event, context):
    """
    Triggered by an S3 PUT event.
    Detects objects in the uploaded image using Amazon Rekognition,
    then writes a structured JSON result to OUTPUT_BUCKET.
    """
    results = []

    for record in event.get("Records", []):
        source_bucket = record["s3"]["bucket"]["name"]
        object_key    = urllib.parse.unquote_plus(
            record["s3"]["object"]["key"], encoding="utf-8"
        )

        logger.info("Processing s3://%s/%s", source_bucket, object_key)

        try:
            labels = detect_objects(source_bucket, object_key)
            output = build_output(source_bucket, object_key, labels)
            output_key = save_to_s3(output, object_key)

            results.append({
                "source": f"s3://{source_bucket}/{object_key}",
                "output": f"s3://{OUTPUT_BUCKET}/{output_key}",
                "label_count": len(labels),
                "status": "success",
            })

        except Exception as exc:
            logger.exception("Failed to process %s: %s", object_key, exc)
            results.append({
                "source": f"s3://{source_bucket}/{object_key}",
                "status": "error",
                "error": str(exc),
            })

    return {
        "statusCode": 200,
        "body": json.dumps({"processed": len(results), "results": results}),
    }


# ── Helpers ───────────────────────────────────────────────────────────────────

def detect_objects(bucket: str, key: str) -> list[dict]:
    """Call Rekognition DetectLabels and return a cleaned list."""
    response = rekognition.detect_labels(
        Image={"S3Object": {"Bucket": bucket, "Name": key}},
        MaxLabels=MAX_LABELS,
        MinConfidence=MIN_CONFIDENCE,
    )

    labels = []
    for label in response.get("Labels", []):
        entry = {
            "name":       label["Name"],
            "confidence": round(label["Confidence"], 2),
            "categories": [c["Name"] for c in label.get("Categories", [])],
            "instances":  [],
        }

        # Bounding boxes for each instance of the label
        for instance in label.get("Instances", []):
            bbox = instance.get("BoundingBox", {})
            entry["instances"].append({
                "bounding_box": {
                    "width":  round(bbox.get("Width",  0), 4),
                    "height": round(bbox.get("Height", 0), 4),
                    "left":   round(bbox.get("Left",   0), 4),
                    "top":    round(bbox.get("Top",    0), 4),
                },
                "confidence": round(instance.get("Confidence", 0), 2),
            })

        labels.append(entry)

    # Sort by confidence descending
    labels.sort(key=lambda x: x["confidence"], reverse=True)
    return labels


def build_output(bucket: str, key: str, labels: list[dict]) -> dict:
    """Assemble the final JSON payload."""
    return {
        "metadata": {
            "source_bucket": bucket,
            "source_key":    key,
            "processed_at":  datetime.utcnow().isoformat() + "Z",
            "settings": {
                "max_labels":     MAX_LABELS,
                "min_confidence": MIN_CONFIDENCE,
            },
        },
        "summary": {
            "total_labels":     len(labels),
            "top_label":        labels[0]["name"] if labels else None,
            "top_confidence":   labels[0]["confidence"] if labels else None,
        },
        "labels": labels,
    }


def save_to_s3(output: dict, original_key: str) -> str:
    """Write JSON result to the output bucket and return the new key."""
    # Build output key:  detections/<original_stem>_<timestamp>.json
    stem      = original_key.rsplit(".", 1)[0].replace("/", "_")
    timestamp = datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    out_key   = f"{OUTPUT_PREFIX}{stem}_{timestamp}.json"

    s3.put_object(
        Bucket=OUTPUT_BUCKET,
        Key=out_key,
        Body=json.dumps(output, indent=2),
        ContentType="application/json",
    )

    logger.info("Saved result → s3://%s/%s", OUTPUT_BUCKET, out_key)
    return out_key