# SES Domain Identities
resource "aws_ses_domain_identity" "domains" {
  for_each = local.domains
  domain   = each.key
}

# SES Domain DKIM
resource "aws_ses_domain_dkim" "domains" {
  for_each = local.domains
  domain   = aws_ses_domain_identity.domains[each.key].domain
}

# DKIM DNS Records
resource "cloudflare_dns_record" "ses_dkim" {
  for_each = {
    for combo in flatten([
      for domain, config in local.domains : [
        for i in range(3) : {
          domain  = domain
          zone_id = config.zone_id
          index   = i
          token   = aws_ses_domain_dkim.domains[domain].dkim_tokens[i]
        }
      ]
    ]) : "${combo.domain}-${combo.index}" => combo
  }

  zone_id = each.value.zone_id
  name    = "${each.value.token}._domainkey"
  type    = "CNAME"
  ttl     = var.dns_ttl
  content = "${each.value.token}.dkim.amazonses.com"
}

# SES Domain Mail From
resource "aws_ses_domain_mail_from" "domains" {
  for_each         = local.domains
  domain           = aws_ses_domain_identity.domains[each.key].domain
  mail_from_domain = "mail.${each.key}"
}

# Mail From MX Records
resource "cloudflare_dns_record" "ses_mail_from_mx" {
  for_each = local.domains

  zone_id  = each.value.zone_id
  name     = "mail"
  type     = "MX"
  ttl      = var.dns_ttl
  content  = "feedback-smtp.eu-west-1.amazonses.com"
  priority = 10
}

# Mail From SPF Records
resource "cloudflare_dns_record" "ses_mail_from_txt" {
  for_each = local.domains

  zone_id = each.value.zone_id
  name    = "mail"
  type    = "TXT"
  ttl     = var.dns_ttl
  content = "v=spf1 include:amazonses.com -all"
}
