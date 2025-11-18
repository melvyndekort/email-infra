variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}

variable "dmarc_email" {
  description = "Email address for DMARC reports"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for DMARC reports"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name for DMARC processing"
  type        = string
}

variable "report_retention_days" {
  description = "Number of days to retain DMARC reports"
  type        = number
}

variable "dns_ttl" {
  description = "TTL for DNS records"
  type        = number
}

variable "mta_sts_policy_id" {
  description = "MTA-STS policy ID for version tracking"
  type        = string
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda function"
  type        = number
}
