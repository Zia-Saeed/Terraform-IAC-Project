# ==============================================================================
# Amazon S3 Bucket Configuration for Backend Application
# ==============================================================================
# This file provisions a secure, versioned, and encrypted S3 bucket for 
# storing backend application files (e.g., user uploads, assets, exports).
# All security best practices are applied: encryption at rest, versioning, 
# and complete public access blocking.
# ==============================================================================

# ------------------------------------------------------------------------------
# S3 Bucket Resource
# ------------------------------------------------------------------------------
# Creates the foundational S3 bucket with naming and tagging standards.
# Note: Bucket names must be globally unique across all AWS accounts.
resource "aws_s3_bucket" "be_s3_bucket" {
  # Bucket name sourced from variable - ensure uniqueness with prefixes
  # Example: "${var.project_name}-${var.env_name}-be-files-uniqueid"
  bucket = var.s3_bucket_name
  
  # Explicitly set region for clarity and to avoid provider defaults confusion
  # Note: For cross-region replication, this becomes the source region
  region = "us-east-1"
  
  tags = {
    Name        = "${var.resource_name}-s3-bucket-for-be-file"
    Project     = var.project_name
    Environment = var.env_name
    # Consider adding: ManagedBy = "Terraform" for resource tracking
  }
}

# ------------------------------------------------------------------------------
# S3 Bucket Versioning
# ------------------------------------------------------------------------------
# Enables versioning to retain, retrieve, and restore every version of every 
# object. Critical for:
# • Recovery from accidental deletion or overwrite
# • Audit trails and compliance requirements
# • Supporting rollback strategies for application assets
resource "aws_s3_bucket_versioning" "s3_bucket_versioning" {
  bucket = aws_s3_bucket.be_s3_bucket.id
  
  versioning_configuration {
    # Variable-controlled: "Enabled", "Suspended", or dynamic based on environment
    # Recommended: Enable in all environments; suspend only for cost-limited dev
    status = var.aws_s3_bucket_versioning_status
  }
  
  # Optional enhancement: Add lifecycle rules to manage non-current versions
  # Example: Transition older versions to Glacier after 90 days to reduce costs
}

# ------------------------------------------------------------------------------
# Server-Side Encryption Configuration
# ------------------------------------------------------------------------------
# Enforces encryption at rest for all objects uploaded to the bucket.
# Protects sensitive data from unauthorized access at the storage layer.
resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encrypt" {
  bucket = aws_s3_bucket.be_s3_bucket.id
  
  rule {
    apply_server_side_encryption_by_default {
      # Encryption algorithm from variable:
      # • "AES256" = S3-managed keys (simple, no KMS costs)
      # • "aws:kms" = AWS KMS keys (audit trails, key rotation, fine-grained control)
      sse_algorithm = var.aws_s3_bucket_enrypt_algo  # NOTE: Typo "enrypt" → "encrypt"
      
      # If using aws:kms, specify your CMK:
      # kms_master_key_id = aws_kms_key.s3_key.arn
    }
  }
  
  # Optional: Add bucket_key_enabled = true when using aws:kms to reduce KMS API costs
  # for frequent object uploads (bucket-level key vs. per-object key)
}

# ------------------------------------------------------------------------------
# S3 Bucket Public Access Block
# ------------------------------------------------------------------------------
# ⚠️  CRITICAL SECURITY CONTROL: Blocks ALL public access to the bucket 
# regardless of bucket policies or ACLs. Prevents accidental data exposure.
#
# These settings should remain TRUE for any bucket containing private data.
# Only relax if you explicitly need public static website hosting (and then 
# use CloudFront with OAI/OAC instead of direct S3 public access).
resource "aws_s3_bucket_public_access_block" "public_access_s3_block" {
  bucket = aws_s3_bucket.be_s3_bucket.id
  
  # Block new public ACLs and uploading public objects
  block_public_acls = true
  
  # Block any bucket policy that grants public access
  block_public_policy = true
  
  # Ignore any public ACLs already on the bucket (defense in depth)
  ignore_public_acls = true
  
  # Restrict bucket access to only AWS accounts/orgs you explicitly allow
  restrict_public_buckets = true
}

# ==============================================================================
# Recommended Additions (Uncomment & Configure as Needed)
# ==============================================================================

# ------------------------------------------------------------------------------
# Lifecycle Rules for Cost Optimization
# ------------------------------------------------------------------------------
# resource "aws_s3_bucket_lifecycle_configuration" "be_bucket_lifecycle" {
#   bucket = aws_s3_bucket.be_s3_bucket.id
#   
#   rule {
#     id     = "archive-old-versions"
#     status = "Enabled"
#     
#     # Transition non-current versions to Glacier after 90 days
#     noncurrent_version_transition {
#       noncurrent_days = 90
#       storage_class   = "GLACIER"
#     }
#     
#     # Permanently delete non-current versions after 365 days
#     noncurrent_version_expiration {
#       noncurrent_days = 365
#     }
#   }
# }

# ------------------------------------------------------------------------------
# CORS Configuration (If bucket is accessed from web browsers)
# ------------------------------------------------------------------------------
# resource "aws_s3_bucket_cors_configuration" "be_bucket_cors" {
#   bucket = aws_s3_bucket.be_s3_bucket.id
#   
#   cors_rule {
#     allowed_headers = ["*"]
#     allowed_methods = ["GET", "PUT", "POST"]
#     allowed_origins = ["https://your-app.com", "https://admin.your-app.com"]
#     expose_headers  = ["ETag"]
#     max_age_seconds = 3000
#   }
# }

# ------------------------------------------------------------------------------
# Bucket Policy for ECS Task Access (Alternative to IAM Policy)
# ------------------------------------------------------------------------------
# resource "aws_s3_bucket_policy" "be_bucket_policy" {
#   bucket = aws_s3_bucket.be_s3_bucket.id
#   
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         AWS = aws_iam_role.ecs_task_role.arn  # Reference your ECS task role
#       }
#       Action = ["s3:GetObject", "s3:PutObject"]
#       Resource = "${aws_s3_bucket.be_s3_bucket.arn}/*"
#     }]
#   })
# }

# ==============================================================================
# Security & Cost Best Practices Checklist
# ==============================================================================
# ✅ Public access block enabled (all 4 settings = true)
# ✅ Server-side encryption enforced (AES256 or aws:kms)
# ✅ Versioning enabled for data recovery
# ✅ Bucket name follows naming convention (project-env-purpose)
# ✅ Tags applied for cost allocation and resource tracking
#
# 🔐 Additional Recommendations:
# • Use aws:kms with customer-managed keys for compliance workloads
# • Enable S3 access logs or integrate with CloudTrail for audit trails
# • Configure MFA Delete for highly sensitive buckets (requires root account)
# • Use S3 Object Lock for WORM (Write-Once-Read-Many) compliance needs
#
# 💰 Cost Optimization Tips:
# • Add lifecycle rules to transition old objects to Intelligent-Tiering/Glacier
# • Enable S3 Storage Lens to analyze usage patterns and identify savings
# • Consider S3 Batch Operations for bulk management tasks
#
# 🔄 Integration Notes:
# • ECS tasks access this bucket via the IAM task role (not bucket policies)
# • Ensure your application handles S3 throttling with exponential backoff
# • Use pre-signed URLs for secure, time-limited direct upload/download from clients
# ==============================================================================
