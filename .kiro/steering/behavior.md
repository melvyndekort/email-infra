# email-infra

> For global standards, way-of-workings, and pre-commit checklist, see `~/.kiro/steering/behavior.md`

## Role

Python developer and AWS engineer.

## What This Does

Comprehensive email infrastructure: DMARC report collection and processing, email health checks, MTA-STS hosting, SES configuration, email routing for family domains, and Grafana monitoring dashboards.

## Lambda Deployment Pattern

Terraform creates Lambdas with dummy code and `ignore_changes` on `source_code_hash`. Actual code is deployed via `make deploy-lambda` using `aws lambda update-function-code`.

## Repository Structure

- `email_infra/` — Lambda handler source (DMARC processor, health checks)
- `tests/` — Test suite (uses moto for AWS mocking)
- `mta-sts/` — MTA-STS policy files (deployed to S3 via separate workflow)
- `terraform/` — Lambdas, SES, DNS, email routing, Grafana dashboards/alerts, monitoring
- `Makefile` — `install`, `test`, `test-cov`, `lint`, `package-lambda`, `deploy-lambda`, `init`, `plan`, `apply`, `decrypt`, `encrypt`

## Terraform Details

- Backend: S3 key `email-infra.tfstate` in `mdekort-tfstate-075673041815`
- Providers: AWS `~> 6.0`, Cloudflare `~> 5.0`, Grafana `~> 4.8`, Archive `~> 2.0`
- Secrets: KMS context `target=email-infra`

## CI/CD

Three workflows: `pipeline.yml` (code), `terraform.yml` (infra), `mta-sts.yml` (MTA-STS policy to S3)

## Related Repositories

- `~/src/melvyndekort/tf-cloudflare` — Provides Cloudflare API tokens and email for DNS management
- `~/src/melvyndekort/tf-grafana` — Provides Grafana URL and service account token
- `~/src/melvyndekort/tf-aws` — SES configuration and account info
