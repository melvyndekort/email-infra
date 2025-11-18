# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability, please send an email to [melvyn@mdekort.nl](mailto:melvyn@mdekort.nl).

Please include the following information:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We will respond within 48 hours and work with you to resolve the issue promptly.

## Security Measures

- All AWS resources use encryption at rest
- Lambda functions have minimal IAM permissions
- S3 bucket is private with lifecycle policies
- SES only accepts from verified domains
