# Parameter Store for Grafana token
resource "aws_ssm_parameter" "grafana_token" {
  name  = "/grafana/token"
  type  = "SecureString"
  value = local.secrets.grafana.metrics_token

  tags = {
    Purpose = "Grafana Cloud Authentication"
    Project = "Email Infrastructure"
  }
}

# S3 bucket for DMARC reports
resource "aws_s3_bucket" "dmarc_reports" {
  bucket = var.s3_bucket_name

  tags = {
    Purpose = "DMARC Reports"
    Project = "Email Infrastructure"
  }
}

resource "aws_s3_bucket_versioning" "dmarc_reports" {
  bucket = aws_s3_bucket.dmarc_reports.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dmarc_reports" {
  bucket = aws_s3_bucket.dmarc_reports.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "dmarc_reports" {
  bucket = aws_s3_bucket.dmarc_reports.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "dmarc_reports" {
  bucket = aws_s3_bucket.dmarc_reports.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSESPuts"
        Effect = "Allow"
        Principal = {
          Service = "ses.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.dmarc_reports.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.dmarc_reports]
}

resource "aws_s3_bucket_lifecycle_configuration" "dmarc_reports" {
  bucket = aws_s3_bucket.dmarc_reports.id

  rule {
    id     = "delete_old_reports"
    status = "Enabled"

    expiration {
      days = var.report_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# SES configuration for receiving DMARC reports
resource "aws_ses_domain_identity" "dmarc_reports" {
  domain = split("@", var.dmarc_email)[1]
}

resource "aws_ses_receipt_rule_set" "dmarc" {
  rule_set_name = "dmarc-reports"
}

resource "aws_ses_active_receipt_rule_set" "dmarc" {
  rule_set_name = aws_ses_receipt_rule_set.dmarc.rule_set_name
}

resource "aws_ses_receipt_rule" "dmarc_reports" {
  name          = "dmarc-reports"
  rule_set_name = aws_ses_receipt_rule_set.dmarc.rule_set_name
  enabled       = true
  scan_enabled  = true

  recipients = [var.dmarc_email]

  s3_action {
    bucket_name       = aws_s3_bucket.dmarc_reports.bucket
    object_key_prefix = "dmarc/"
    position          = 1
  }

  depends_on = [aws_s3_bucket_policy.dmarc_reports]
}

resource "aws_ses_receipt_rule" "tlsrpt_reports" {
  name          = "tlsrpt-reports"
  rule_set_name = aws_ses_receipt_rule_set.dmarc.rule_set_name
  enabled       = true
  scan_enabled  = true

  recipients = ["tlsrpt@${split("@", var.dmarc_email)[1]}"]

  s3_action {
    bucket_name       = aws_s3_bucket.dmarc_reports.bucket
    object_key_prefix = "tlsrpt/"
    position          = 1
  }

  depends_on = [aws_s3_bucket_policy.dmarc_reports]
}

# Lambda function for processing DMARC reports
data "archive_file" "placeholder_lambda" {
  type        = "zip"
  output_path = "${var.lambda_function_name}.zip"

  source {
    filename = "handler.py"
    content  = <<EOF
def handler(event, context):
  raise NotImplementedError("Deployed via CI/CD pipeline")
EOF
  }
}

resource "aws_lambda_function" "dmarc_processor" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.dmarc_processor.arn
  handler       = "email_infra.handler.handler"
  runtime       = "python3.12"
  timeout       = 60
  memory_size   = var.lambda_memory_size

  filename         = data.archive_file.placeholder_lambda.output_path
  source_code_hash = data.archive_file.placeholder_lambda.output_base64sha256

  environment {
    variables = {
      S3_BUCKET        = aws_s3_bucket.dmarc_reports.bucket
      GRAFANA_PUSH_URL = "${data.terraform_remote_state.tf_grafana.outputs.prometheus_url}/api/prom/push"
      GRAFANA_USER_ID  = "1552545"
    }
  }

  tags = {
    Purpose = "DMARC Processing"
    Project = "Email Infrastructure"
  }

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash,
    ]
  }

  depends_on = [aws_iam_role_policy.dmarc_processor]
}

resource "aws_iam_role" "dmarc_processor" {
  name = "${var.lambda_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Purpose = "DMARC Processing"
    Project = "Email Infrastructure"
  }
}

resource "aws_iam_role_policy" "dmarc_processor" {
  name = "${var.lambda_function_name}-policy"
  role = aws_iam_role.dmarc_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.lambda_function_name}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.dmarc_reports.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "${aws_s3_bucket.dmarc_reports.arn}"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/grafana/token"
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "dmarc_reports" {
  bucket = aws_s3_bucket.dmarc_reports.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.dmarc_processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "dmarc/"
  }

  depends_on = [aws_lambda_permission.dmarc_processor]
}

resource "aws_lambda_permission" "dmarc_processor" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dmarc_processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.dmarc_reports.arn
}
