resource "aws_s3_bucket" "main" {
    bucket = "demo-onaivi-bucket-123"
    

    tags = {
        Name = "Demo bucket"
        Environment = "Dev"
    }
}

# resource "aws_s3_bucket_ownership_controls" "main" {
#   bucket = aws_s3_bucket.main.id
#   rule {
#     object_ownership = "BucketOwnerPreferred"
#   }
# }

# resource "aws_s3_bucket_public_access_block" "main" {
#   bucket = aws_s3_bucket.main.id

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

resource "aws_s3_bucket_acl" "main" {
#   depends_on = [
#     aws_s3_bucket_ownership_controls.main,
#     aws_s3_bucket_public_access_block.main,
#   ]

  bucket = aws_s3_bucket.main.id
  acl    = "public-read"
}

locals {
  s3_origin_id = "myS3Origin"
}



resource "aws_s3_bucket_website_configuration" "main" {
  bucket = aws_s3_bucket.main.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  routing_rule {
    condition {
      key_prefix_equals = "docs/"
    }
    redirect {
      replace_key_prefix_with = "documents/"
    }
  }
  depends_on = [aws_s3_bucket.main]
}

resource "aws_s3_bucket_object" "object" {
  bucket = aws_s3_bucket.main.id
  key    = "index.html"
  source = "index.html"
  etag = filemd5("index.html")

  depends_on = [aws_s3_bucket.main]
}  

resource "aws_acm_certificate" "cert_us_east_1" {
  provider          = aws.useast1
  domain_name       = "*.senistone.co.uk" 
  validation_method = "DNS"
  subject_alternative_names = ["maintenance.senistone.co.uk"]

    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_route53_record" "usvalidation" {
    for_each = {
        for x in aws_acm_certificate.cert_us_east_1.domain_validation_options : x.domain_name => {
            name = x.resource_record_name
            record = x.resource_record_value
            type = x.resource_record_type
            zone_id = x.domain_name == "senistone.co.uk" ? data.aws_route53_zone.public.zone_id : data.aws_route53_zone.public.zone_id
        }
    }
    allow_overwrite = true 
    name = each.value.name
    records = [each.value.record]
    ttl = 300
    type = each.value.type
    zone_id = "Z05942591BBZANTS6XK8U"
}  

data "aws_acm_certificate" "us_cert_issued" {
    domain = "*.senistone.co.uk"
    statuses  = ["ISSUED"]
    types      = ["AMAZON_ISSUED"]
    most_recent = true

}


output "cert_issued" {
    value = data.aws_acm_certificate.us_cert_issued.arn
}


resource "aws_cloudfront_origin_access_identity" "main" {
  comment = "Access identity for S3 bucket"
}

resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id
  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "PolicyForCloudFrontPrivateContent",
    Statement = [
      {
        Sid       = "1"
        Effect    = "Allow"
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.main.id}"
        },
        Action   = "s3:GetObject",
        Resource = "arn:aws:s3:::${aws_s3_bucket.main.bucket}/*"
      }
    ]
  })
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.main.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.main.cloudfront_access_identity_path
    }
  }

  enabled             = true
  default_root_object = "index.html"
  aliases = ["*.senistone.co.uk"]#[aws_route53_record.maintenance_cname_secondary.fqdn] no need to do this cause its done in route53 record creation already
  
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    min_ttl = 0
    default_ttl = "300"
    max_ttl = "1200"
    
    forwarded_values {
      query_string = false
      headers      = ["Origin"]
      
      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
    # min_ttl                = 0
    # default_ttl            = 3600
    # max_ttl                = 86400
  }

    custom_error_response {
        error_caching_min_ttl = "0"
        error_code            = "403"
        response_code         = "503"
        response_page_path    = "/index.html"
    }

    custom_error_response {
        error_caching_min_ttl = "0"
        error_code            = "503"
        response_code         = "503"
        response_page_path    = "/index.html"
    }

    custom_error_response {
        error_caching_min_ttl = "0"
        error_code            = "404"
        response_code         = "503"
        response_page_path    = "/index.html"
    }  

  price_class                       = "PriceClass_200"
      viewer_certificate {
        acm_certificate_arn       = aws_acm_certificate.cert_us_east_1.arn
        ssl_support_method        = "sni-only"
        #minimum_protocol_version = "TLSv1"
    }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

output "cloudfront_distribution_domain" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

#Secondary record pointing to CloudFront distribution 
resource "aws_route53_record" "maintenance_cname_secondary" {
  zone_id = "Z05942591BBZANTS6XK8U"
  name    = "maintenance.senistone.co.uk"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }

  set_identifier = "maintenance-secondary"
  failover_routing_policy {
    type = "SECONDARY"
  }

  health_check_id = aws_route53_health_check.alb_health_check.id
}