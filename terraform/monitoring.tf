# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "dmarc_processor" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14

  tags = {
    Purpose = "DMARC Processor Logs"
    Project = "Email Infrastructure"
  }
}

# CloudWatch Alarm for Lambda errors
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.lambda_function_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors lambda errors"
  alarm_actions       = [data.terraform_remote_state.tf_aws.outputs.notifications_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.dmarc_processor.function_name
  }

  tags = {
    Purpose = "Lambda Error Monitoring"
    Project = "Email Infrastructure"
  }
}
