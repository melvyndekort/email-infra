resource "aws_ses_email_identity" "noreply_mdekort_nl" {
  email = "noreply@mdekort.nl"
}

resource "aws_ses_email_identity" "noreply_melvyn_dev" {
  email = "noreply@melvyn.dev"
}

resource "aws_ses_email_identity" "noreply_dekort_dev" {
  email = "noreply@dekort.dev"
}
