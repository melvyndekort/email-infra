locals {
  domains = {
    "melvyn.dev" = {
      zone_id = data.terraform_remote_state.tf_cloudflare.outputs.melvyn_dev_zone_id
      mx_priorities = {
        route1 = 43
        route2 = 83
        route3 = 2
      }
    }
    "mdekort.nl" = {
      zone_id = data.terraform_remote_state.tf_cloudflare.outputs.mdekort_zone_id
      mx_priorities = {
        route1 = 37
        route2 = 47
        route3 = 2
      }
    }
    "dekort.dev" = {
      zone_id = data.terraform_remote_state.tf_cloudflare.outputs.dekort_dev_zone_id
      mx_priorities = {
        route1 = 46
        route2 = 11
        route3 = 87
      }
    }
  }

  # Flatten MX records for cleaner iteration
  mx_records = flatten([
    for domain, config in local.domains : [
      for route, priority in config.mx_priorities : {
        domain   = domain
        zone_id  = config.zone_id
        route    = route
        priority = priority
        content  = "${route}.mx.cloudflare.net"
      }
    ]
  ])
}

data "aws_caller_identity" "current" {}
