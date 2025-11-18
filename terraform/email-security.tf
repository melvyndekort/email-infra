# MTA-STS records for all domains
resource "cloudflare_dns_record" "mta_sts" {
  for_each = local.domains

  zone_id = each.value.zone_id
  name    = "_mta-sts"
  type    = "TXT"
  ttl     = var.dns_ttl
  content = "v=STSv1; id=${var.mta_sts_policy_id};"
}

# TLS-RPT records for all domains - self-hosted
resource "cloudflare_dns_record" "tls_rpt" {
  for_each = local.domains

  zone_id = each.value.zone_id
  name    = "_smtp._tls"
  type    = "TXT"
  ttl     = var.dns_ttl
  content = "v=TLSRPTv1; rua=mailto:tlsrpt@${split("@", var.dmarc_email)[1]};"
}
