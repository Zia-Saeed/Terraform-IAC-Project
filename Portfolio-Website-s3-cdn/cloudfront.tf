# ______________ OAC CDN ____________ #
resource "aws_cloudfront_origin_access_control" "static_site" {
  name                              = "${var.bucket_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# _____________CloudFront Distribution______________ #
resource "aws_cloudfront_distribution" "static_site" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.s3_portfolio.bucket_domain_name
    origin_id                = "S3-${var.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.static_site.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${var.bucket_name}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
  tags = merge(local.tags_value, {
    Resource = "CDN-Portfolio-Distribution-${var.resource_name}"
  })
}
# ________________ CDN HEADER POLICY _______________ #
resource "aws_cloudfront_response_headers_policy" "portfolio_security" {
  name = "portfolio-security-headers"

  security_headers_config {
    content_security_policy {
      # Adjust if you later add Google Fonts, Analytics, or external CDNs
      content_security_policy = join("; ", [
        "default-src 'self'",
        "script-src 'self'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: https:",
        "font-src 'self'",
        "object-src 'none'",
        "frame-ancestors 'none'",
        "base-uri 'self'"
      ])
      override = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000 # 1 year
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    # permissions_policy {
    #   permissions_policy = "camera=(), microphone=(), geolocation=(), payment=()"
    #   override           = true
    # }
  }
}