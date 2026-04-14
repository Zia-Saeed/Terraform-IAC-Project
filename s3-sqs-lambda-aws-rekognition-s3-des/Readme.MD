# AWS Image Processing Pipeline

Event-driven image analysis pipeline built on AWS and provisioned entirely with Terraform. Images uploaded to S3 are processed by Lambda + Rekognition, cropped by object category, and stored in a structured destination bucket — with zero idle compute cost.

---
## How It Works

```
Source S3  →  SQS Queue  →  Lambda (Python 3.12)  →  Rekognition  →  Destination S3
                  └──────────────────────────────────────────────────►  DLQ (on failure)
```

1. Image uploaded to source S3 triggers an `s3:ObjectCreated` event to SQS
2. Lambda consumes messages in batches of 10 (timeout 120s, memory 1024MB)
3. Rekognition `DetectLabels` returns labels + bounding boxes
4. Pillow crops each detected object and writes it to the destination bucket under `{label}/`
5. Failed messages retry 3× then land in the Dead Letter Queue — nothing is lost

---

## Project Structure

```
├── provider.tf         # AWS provider + Terraform version
├── backend.tf          # Remote state (S3 + locking)
├── variables.tf        # Input variables
├── locals.tf           # Shared tags
├── source-s3.tf        # Private, encrypted, versioned source bucket + SQS notifier
├── sqs.tf              # Main queue + DLQ + queue policy
├── lambda.tf           # Lambda function + Event Source Mapping
├── iam.tf              # Least-privilege execution role
├── destination-s3.tf   # Encrypted, versioned destination bucket
├── cloud-watch.tf      # CloudWatch log group
├── lambda_function.py  # Handler (Pillow + Boto3)
└── pillow.zip          # Lambda deployment package
```

---

## Deployment

```bash
# 1. Build the Lambda package (Linux-compatible Pillow)
pip install pillow --target ./package --platform manylinux2014_x86_64 \
  --implementation cp --python-version 3.12 --only-binary=:all:
cp lambda_function.py ./package/
cd package && zip -r ../pillow.zip . && cd ..

# 2. Deploy
terraform init
terraform plan
terraform apply

# 3. Test — upload an image and watch the logs
aws s3 cp test.jpg s3://<source-bucket>/
aws logs tail /aws/lambda/s3-upload-processor --follow
```

> Update `backend.tf` with your own S3 state bucket before running `terraform init`.

---

## Configuration

| Variable | Default | Description |
|---|---|---|
| `region` | `us-east-1` | Deployment region |
| `s3_source_name` | `bucket-for-lambda-source-event-sender` | Source bucket name |
| `des_bucket_name` | `bucket-for-des-objects-storage` | Destination bucket name |
| `resource` | `lambda-project-tf` | Name prefix for all resources |

---

## Security Highlights

- Source bucket is fully private (all public access blocked)
- Both buckets encrypted at rest with AES-256 and versioned
- Lambda role uses least-privilege — only the exact S3, SQS, and Rekognition actions needed
- SQS queue policy restricts `SendMessage` to the source S3 bucket ARN only
- Remote Terraform state is encrypted with state locking enabled

---

## Teardown

```bash
aws s3 rm s3://<source-bucket> --recursive
aws s3 rm s3://<destination-bucket> --recursive
terraform destroy
```

---

## Tech Stack

`Terraform` · `AWS Lambda` · `Amazon SQS` · `Amazon S3` · `Amazon Rekognition` · `Python 3.12` · `Pillow` · `CloudWatch`
