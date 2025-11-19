data "aws_kms_secrets" "secrets" {
  secret {
    name    = "secrets"
    payload = file("secrets.yaml.encrypted")

    context = {
      target = "email-infra"
    }
  }
}

locals {
  secrets = yamldecode(data.aws_kms_secrets.secrets.plaintext["secrets"])
}
