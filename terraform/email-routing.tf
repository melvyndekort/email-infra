# Cloudflare Email Routing Addresses
resource "cloudflare_email_routing_address" "melvyn" {
  account_id = data.terraform_remote_state.tf_cloudflare.outputs.cloudflare_account_id
  email      = "melvyndekort@gmail.com"
}

resource "cloudflare_email_routing_address" "karin" {
  account_id = data.terraform_remote_state.tf_cloudflare.outputs.cloudflare_account_id
  email      = "karindemaertelaere84@gmail.com"
}

resource "cloudflare_email_routing_address" "daan" {
  account_id = data.terraform_remote_state.tf_cloudflare.outputs.cloudflare_account_id
  email      = "daandekort2012@gmail.com"
}

resource "cloudflare_email_routing_address" "kaya" {
  account_id = data.terraform_remote_state.tf_cloudflare.outputs.cloudflare_account_id
  email      = "kaya.biberovic@gmail.com"
}

resource "cloudflare_email_routing_address" "nadia" {
  account_id = data.terraform_remote_state.tf_cloudflare.outputs.cloudflare_account_id
  email      = "nadia.biberovic@gmail.com"
}

# Catch-all rules for all domains
resource "cloudflare_email_routing_catch_all" "domains" {
  for_each = local.domains

  zone_id = each.value.zone_id
  name    = "catch all"
  enabled = true

  matchers = [{
    type = "all"
  }]

  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.melvyn.email]
  }]
}

# Specific routing rules for mdekort.nl
resource "cloudflare_email_routing_rule" "mdekort_melvyn" {
  zone_id = local.domains["mdekort.nl"].zone_id
  name    = "Melvyn"
  enabled = true

  matchers = [{
    type  = "literal"
    field = "to"
    value = "melvyn@mdekort.nl"
  }]

  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.melvyn.email]
  }]
}

resource "cloudflare_email_routing_rule" "mdekort_karin" {
  zone_id = local.domains["mdekort.nl"].zone_id
  name    = "Karin"
  enabled = true

  matchers = [{
    type  = "literal"
    field = "to"
    value = "karin@mdekort.nl"
  }]

  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.karin.email]
  }]
}

resource "cloudflare_email_routing_rule" "mdekort_daan" {
  zone_id = local.domains["mdekort.nl"].zone_id
  name    = "Daan"
  enabled = true

  matchers = [{
    type  = "literal"
    field = "to"
    value = "daan@mdekort.nl"
  }]

  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.daan.email]
  }]
}

resource "cloudflare_email_routing_rule" "mdekort_kaya" {
  zone_id = local.domains["mdekort.nl"].zone_id
  name    = "Kaya"
  enabled = true

  matchers = [{
    type  = "literal"
    field = "to"
    value = "kaya@mdekort.nl"
  }]

  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.kaya.email]
  }]
}

resource "cloudflare_email_routing_rule" "mdekort_nadia" {
  zone_id = local.domains["mdekort.nl"].zone_id
  name    = "Nadia"
  enabled = true

  matchers = [{
    type  = "literal"
    field = "to"
    value = "nadia@mdekort.nl"
  }]

  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.nadia.email]
  }]
}
