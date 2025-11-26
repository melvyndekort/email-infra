# Lambda function to send daily health check emails
resource "aws_lambda_function" "email_health_check" {
  function_name = "email-health-check"
  role          = aws_iam_role.email_health_check.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  architectures = ["arm64"]
  timeout       = 30

  filename         = data.archive_file.email_health_check.output_path
  source_code_hash = data.archive_file.email_health_check.output_base64sha256

  environment {
    variables = {
      FROM_EMAIL = "noreply@mdekort.nl"
      TO_EMAIL   = "melvyndekort@gmail.com"
    }
  }
}

data "archive_file" "email_health_check" {
  type        = "zip"
  output_path = "email-health-check.zip"

  source {
    filename = "index.py"
    content  = <<EOF
import boto3
import os
from datetime import datetime

def handler(event, context):
    ses = boto3.client('ses')
    
    response = ses.send_email(
        Source=os.environ['FROM_EMAIL'],
        Destination={'ToAddresses': [os.environ['TO_EMAIL']]},
        Message={
            'Subject': {'Data': 'DMARC Health Check'},
            'Body': {'Text': {'Data': f'Daily health check - {datetime.now().strftime("%Y-%m-%d %H:%M UTC")}'}}
        }
    )
    
    return {'statusCode': 200, 'body': f'Health check sent: {response["MessageId"]}'}
EOF
  }
}

resource "aws_iam_role" "email_health_check" {
  name = "email-health-check-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "email_health_check" {
  name = "email-health-check-policy"
  role = aws_iam_role.email_health_check.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail"]
        Resource = "*"
      }
    ]
  })
}

# Schedule to run daily at 10:00 UTC
resource "aws_cloudwatch_event_rule" "daily_health_check" {
  name                = "daily-email-health-check"
  description         = "Send daily DMARC health check email"
  schedule_expression = "cron(0 10 * * ? *)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_health_check.name
  target_id = "EmailHealthCheckTarget"
  arn       = aws_lambda_function.email_health_check.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.email_health_check.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_health_check.arn
}
