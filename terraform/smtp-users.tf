resource "aws_iam_group" "sendmail" {
  name = "sendmail"
  path = "/users/"
}

resource "aws_iam_policy" "send_email" {
  name = "sendmail"
  path = "/ses/"

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "ses:SendRawEmail"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_group_policy_attachment" "send_email" {
  group      = aws_iam_group.sendmail.name
  policy_arn = aws_iam_policy.send_email.arn
}

# Gmail - Melvyn
resource "aws_iam_user" "gmail_melvyn" {
  name = "gmail-melvyn"
  path = "/ses/"
}

resource "aws_iam_access_key" "gmail_melvyn" {
  user = aws_iam_user.gmail_melvyn.name
}

# Gmail - Karin
resource "aws_iam_user" "gmail_karin" {
  name = "gmail-karin"
  path = "/ses/"
}

resource "aws_iam_access_key" "gmail_karin" {
  user = aws_iam_user.gmail_karin.name
}

# Calibre
resource "aws_iam_user" "calibre" {
  name = "calibre"
  path = "/ses/"
}

resource "aws_iam_access_key" "calibre" {
  user = aws_iam_user.calibre.name
}

# Spotweb
resource "aws_iam_user" "spotweb" {
  name = "spotweb"
  path = "/ses/"
}

resource "aws_iam_access_key" "spotweb" {
  user = aws_iam_user.spotweb.name
}



resource "aws_iam_group_membership" "sendmail" {
  name  = "sendmail"
  group = aws_iam_group.sendmail.name
  users = [
    aws_iam_user.gmail_melvyn.name,
    aws_iam_user.gmail_karin.name,
    aws_iam_user.calibre.name,
    aws_iam_user.spotweb.name,
  ]
}
