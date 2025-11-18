output "s3_bucket_name" {
  description = "Name of the S3 bucket storing DMARC reports"
  value       = aws_s3_bucket.dmarc_reports.bucket
}

output "lambda_function_name" {
  description = "Name of the Lambda function processing DMARC reports"
  value       = aws_lambda_function.dmarc_processor.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function processing DMARC reports"
  value       = aws_lambda_function.dmarc_processor.arn
}

output "ses_domain" {
  description = "SES domain identity for DMARC collection"
  value       = aws_ses_domain_identity.dmarc_reports.domain
}

output "dmarc_email" {
  description = "Email address for DMARC reports"
  value       = var.dmarc_email
}

output "grafana_dashboard_url" {
  description = "URL to the Grafana dashboard"
  value       = "https://mdekort.grafana.net"
}

output "managed_domains" {
  description = "List of domains managed by this infrastructure"
  value       = keys(local.domains)
}

# SMTP Users
output "gmail_melvyn_user" {
  description = "Gmail Melvyn SMTP username"
  value       = aws_iam_access_key.gmail_melvyn.id
}

output "gmail_melvyn_password" {
  description = "Gmail Melvyn SMTP password"
  value       = aws_iam_access_key.gmail_melvyn.ses_smtp_password_v4
  sensitive   = true
}

output "gmail_karin_user" {
  description = "Gmail Karin SMTP username"
  value       = aws_iam_access_key.gmail_karin.id
}

output "gmail_karin_password" {
  description = "Gmail Karin SMTP password"
  value       = aws_iam_access_key.gmail_karin.ses_smtp_password_v4
  sensitive   = true
}

output "calibre_user" {
  description = "Calibre SMTP username"
  value       = aws_iam_access_key.calibre.id
}

output "calibre_password" {
  description = "Calibre SMTP password"
  value       = aws_iam_access_key.calibre.ses_smtp_password_v4
  sensitive   = true
}

output "spotweb_user" {
  description = "Spotweb SMTP username"
  value       = aws_iam_access_key.spotweb.id
}

output "spotweb_password" {
  description = "Spotweb SMTP password"
  value       = aws_iam_access_key.spotweb.ses_smtp_password_v4
  sensitive   = true
}

output "nextcloud_user" {
  description = "Nextcloud SMTP username"
  value       = aws_iam_access_key.nextcloud.id
}

output "nextcloud_password" {
  description = "Nextcloud SMTP password"
  value       = aws_iam_access_key.nextcloud.ses_smtp_password_v4
  sensitive   = true
}

output "projectsend_user" {
  description = "ProjectSend SMTP username"
  value       = aws_iam_access_key.projectsend.id
}

output "projectsend_password" {
  description = "ProjectSend SMTP password"
  value       = aws_iam_access_key.projectsend.ses_smtp_password_v4
  sensitive   = true
}
