# Email Infrastructure

Self-hosted email infrastructure with DMARC collection and DNS management.

## Features

- **DMARC Collection**: AWS SES + S3 + Lambda for processing DMARC reports
- **Email DNS**: SPF, DMARC, BIMI, MTA-STS, and TLS-RPT records for all domains
- **Email Routing**: Cloudflare Email Routing for family members
- **Monitoring**: Grafana Cloud dashboard with DMARC metrics
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
                                                                  │
                                                                  ▼
                                                          ┌─────────────┐
                                                          │   Grafana   │
                                                          │ Cloud Metrics│
                                                          └─────────────┘
```

1. **SES** receives DMARC reports at `dmarc@dmarc.mdekort.nl`
2. **S3** stores raw reports with 90-day lifecycle
3. **Lambda** processes reports and pushes metrics to Grafana Cloud
4. **Grafana** provides dashboards and alerting

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
# Initialize Terraform
make init

# Plan changes
make plan

# Apply changes
make apply

# Clean up
make clean
```

### Manual Commands

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Deployment

Managed via GitHub Actions with AWS OIDC authentication. Changes are automatically deployed when pushed to `main` branch.

### GitHub Actions Workflow

- **Trigger**: Push to main branch
- **Authentication**: AWS OIDC (no long-lived credentials)
- **Steps**: Init → Plan → Apply

## Monitoring

### Grafana Dashboard

Access the DMARC dashboard at: [mdekort.grafana.net](https://mdekort.grafana.net)

### Metrics Available

- `dmarc_email_count` - Total emails processed
- `dmarc_spf_result` - SPF authentication results  
- `dmarc_dkim_result` - DKIM authentication results
- `dmarc_policy_result` - DMARC policy evaluation results

### Email Routing

Cloudflare Email Routing handles incoming emails:
- Family member addresses route to personal Gmail accounts
- Catch-all rules forward unmatched emails to admin

## Cost Estimation

- **SES**: ~$0.10 per 1,000 emails received
- **S3**: ~$0.023 per GB stored (90-day lifecycle)
- **Lambda**: ~$0.20 per 1M requests
- **Grafana Cloud**: Free tier (up to 10k metrics)

**Estimated monthly cost**: <$3 for typical email volumes

## Troubleshooting

### Lambda Errors

Check CloudWatch Logs: `/aws/lambda/dmarc-processor`

### Missing Reports

1. Verify SES receipt rule is active
2. Check S3 bucket permissions
3. Confirm DMARC record points to correct email

### DNS Issues

```bash
# Check DMARC record
dig TXT _dmarc.yourdomain.com

# Check MX records  
dig MX yourdomain.com

# Check MTA-STS record
dig TXT _mta-sts.yourdomain.com
```

## Security

- S3 bucket is private with lifecycle policies
- Lambda has minimal IAM permissions
- SES only accepts from verified domains
- All resources use encryption at rest
- MTA-STS enforces TLS for email delivery
- TLS-RPT provides delivery failure reporting
