# Cloudflare Pages project for MTA-STS policy hosting
resource "cloudflare_pages_project" "mta_sts" {
  account_id        = data.terraform_remote_state.tf_cloudflare.outputs.cloudflare_account_id
  name              = "mta-sts-mdekort-nl"
  production_branch = "main"

  lifecycle {
    ignore_changes = [
      build_config,
      deployment_configs,
    ]
  }
}

# Custom domains for MTA-STS on all domains
resource "cloudflare_pages_domain" "mta_sts" {
  for_each = local.domains

  account_id   = data.terraform_remote_state.tf_cloudflare.outputs.cloudflare_account_id
  project_name = cloudflare_pages_project.mta_sts.name
  name         = "mta-sts.${each.key}"

  depends_on = [cloudflare_pages_project.mta_sts]
}

# DNS CNAME records for MTA-STS subdomains
resource "cloudflare_dns_record" "mta_sts_cname" {
  for_each = local.domains

  zone_id = each.value.zone_id
  name    = "mta-sts"
  type    = "CNAME"
  ttl     = 1
  proxied = false
  content = "${cloudflare_pages_project.mta_sts.name}.pages.dev"
}
