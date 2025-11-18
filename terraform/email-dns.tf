# Email DNS records for all domains
resource "cloudflare_dns_record" "spf" {
  for_each = local.domains

  zone_id = each.value.zone_id
  name    = "@"
  type    = "TXT"
  ttl     = var.dns_ttl
  content = "v=spf1 include:_spf.mx.cloudflare.net ~all"
}

resource "cloudflare_dns_record" "dmarc" {
  for_each = local.domains

  zone_id = each.value.zone_id
  name    = "_dmarc"
  type    = "TXT"
  ttl     = var.dns_ttl
  content = "v=DMARC1;p=reject;rua=mailto:${var.dmarc_email};ruf=mailto:${var.dmarc_email};fo=1"
}

resource "cloudflare_dns_record" "bimi" {
  for_each = local.domains

  zone_id = each.value.zone_id
  name    = "default._bimi"
  type    = "TXT"
  ttl     = var.dns_ttl
  content = "v=BIMI1;l=https://mta-sts.mdekort.nl/bimi-${replace(each.key, ".", "-")}.svg;a="
}

# Simplified MX records using flattened structure
resource "cloudflare_dns_record" "mx" {
  for_each = {
    for record in local.mx_records : "${record.domain}-${record.route}" => record
  }

  zone_id  = each.value.zone_id
  name     = "@"
  type     = "MX"
  ttl      = var.dns_ttl
  content  = each.value.content
  priority = each.value.priority
}

# DMARC collection subdomain
resource "cloudflare_dns_record" "dmarc_subdomain" {
  zone_id  = local.domains["mdekort.nl"].zone_id
  name     = "dmarc"
  type     = "MX"
  ttl      = var.dns_ttl
  content  = "inbound-smtp.${var.aws_region}.amazonaws.com"
  priority = 10
}
