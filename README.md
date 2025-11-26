# Email Infrastructure

Comprehensive self-hosted email infrastructure with authentication, monitoring, and family email routing.

## Features

- **DMARC & TLS-RPT Collection**: AWS SES + S3 + Lambda for processing email security reports
- **DKIM Signing**: Full DKIM signing for all domains via AWS SES
- **Email DNS**: SPF, DMARC, DKIM, BIMI, MTA-STS, and TLS-RPT records for all domains
- **Email Routing**: Cloudflare Email Routing with family member addresses and catch-all rules
- **SMTP Services**: SES-based SMTP for applications (Calibre, Spotweb, Gmail forwarding)
- **Monitoring**: Grafana Cloud dashboard with DMARC metrics and alerting
- **Automated Deployment**: GitHub Actions with AWS OIDC for CI/CD
- **Cost-effective**: Serverless architecture with minimal costs

## Domains Managed

- melvyn.dev
- mdekort.nl  
- dekort.dev

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Email     │───▶│     SES     │───▶│     S3      │───▶│   Lambda    │
│  Providers  │    │  Receiver   │    │   Storage   │    │  Processor  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                           │                                      │
                           │                                      ▼
                           ▼                              ┌─────────────┐
                   ┌─────────────┐                       │   Grafana   │
                   │ Applications│                       │ Cloud Metrics│
                   │ (SMTP Send) │                       └─────────────┘
                   └─────────────┘
```

**Report Collection**
1. **SES** receives DMARC reports at `dmarc@dmarc.mdekort.nl`
2. **SES** receives TLS-RPT reports at `tlsrpt@dmarc.mdekort.nl`
3. **S3** stores raw reports with 90-day lifecycle (separate dmarc/ and tlsrpt/ prefixes)
4. **Lambda** processes DMARC reports and pushes metrics to Grafana Cloud

**Email Services**
- **SES** provides DKIM signing for all outbound emails
- **Applications** use SES SMTP for sending (Calibre, Spotweb, Gmail forwarding)
- **Cloudflare** routes incoming emails to family members

## Migration from EasyDMARC

This replaces EasyDMARC CNAME records with self-hosted DMARC collection:

- **Old**: `_dmarc.{domain}._d.easydmarc.pro`
- **New**: `v=DMARC1;p=reject;rua=mailto:dmarc@dmarc.mdekort.nl;...`

## Development

### Prerequisites

- Terraform ~> 1.10
- AWS CLI configured
- uv (Python package manager)
- Make (optional)

### Local Development

```bash
# Install dependencies
make install

# Run tests with coverage
make test-cov

# Lint code
make lint

# Initialize Terraform
make init

# Plan changes
make plan

# Apply changes
make apply

# Package Lambda function
make package-lambda

# Deploy Lambda function
make deploy-lambda

# Clean up
make clean
```

### Manual Commands

```bash
# Python development
uv sync --all-extras
uv run pytest --cov=email_infra --cov-report=html
uv run pylint email_infra tests

# Terraform
cd terraform
terraform init
terraform plan
terraform apply
```

## Deployment

Managed via GitHub Actions with AWS OIDC authentication. Changes are automatically deployed when pushed to `main` branch.

### GitHub Actions Workflows

- **Pipeline**: Build, test, and deploy Lambda function on push to main
- **Terraform**: Infrastructure deployment (separate workflow)
- **Authentication**: AWS OIDC (no long-lived credentials)
- **Steps**: Install dependencies → Test → Build → Deploy Lambda

## Monitoring

### Grafana Dashboard

Access the DMARC dashboard at: [mdekort.grafana.net](https://mdekort.grafana.net)

### Metrics Available

- `dmarc_email_count` - Total emails processed
- `dmarc_spf_result` - SPF authentication results  
- `dmarc_dkim_result` - DKIM authentication results
- `dmarc_policy_result` - DMARC policy evaluation results

### Alerting

- **DMARC Failures**: Alerts when DMARC failures exceed threshold over 7 days
- **Lambda Errors**: CloudWatch alarm for Lambda function errors
- **Notifications**: Sent via ntfy to configured endpoints

## Cost Estimation

- **SES**: ~$0.10 per 1,000 emails received + $0.10 per 1,000 emails sent
- **S3**: ~$0.023 per GB stored (90-day lifecycle)
- **Lambda**: ~$0.20 per 1M requests
- **Grafana Cloud**: Free tier (up to 10k metrics)

**Estimated monthly cost**: <$5 for typical email volumes

## Troubleshooting

### Lambda Errors

Check CloudWatch Logs: `/aws/lambda/dmarc-processor`

### Missing Reports

1. Verify SES receipt rules are active (DMARC and TLS-RPT)
2. Check S3 bucket permissions
3. Confirm DMARC record points to correct email
4. Verify domain verification status in SES

### SMTP Issues

1. Check SES sending statistics for bounces/complaints
2. Verify DKIM records are properly configured
3. Confirm application SMTP credentials are correct (Calibre, Spotweb, Gmail forwarding)
4. Check SES sandbox mode (if applicable)

### DNS Issues

```bash
# Check DMARC record
dig TXT _dmarc.yourdomain.com

# Check MX records  
dig MX yourdomain.com

# Check MTA-STS record
dig TXT _mta-sts.yourdomain.com

# Check DKIM records
dig TXT selector._domainkey.yourdomain.com
```

## Security

- S3 bucket is private with lifecycle policies
- Lambda has minimal IAM permissions
- SES only accepts from verified domains
- All resources use encryption at rest
- MTA-STS enforces TLS for email delivery
- TLS-RPT provides delivery failure reporting
