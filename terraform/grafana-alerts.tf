# Get Prometheus datasource UID
data "grafana_data_source" "prometheus" {
  name = "grafanacloud-mdekort-prom"
}

# Define datasource UIDs
locals {
  prometheus_uid  = data.grafana_data_source.prometheus.uid
  expressions_uid = "-100" # Built-in expression datasource
}

# Notification channel for ntfy
resource "grafana_contact_point" "ntfy" {
  name = "ntfy-email-alerts"

  webhook {
    url                     = "https://ntfy.mdekort.nl/grafana"
    http_method             = "POST"
    max_alerts              = 0
    disable_resolve_message = false

    settings = {
      httpMethod                = "POST"
      url                       = "https://ntfy.mdekort.nl/grafana"
      title                     = "{{ .GroupLabels.alertname }}"
      authorization_scheme      = "Bearer"
      authorization_credentials = local.secrets.ntfy.token
      message                   = "{{ range .Alerts }}{{ .Annotations.summary }}{{ if .Annotations.description }}\n\n{{ .Annotations.description }}{{ end }}{{ end }}"
    }
  }
}

# Notification policy
resource "grafana_notification_policy" "email_infra" {
  contact_point = grafana_contact_point.ntfy.name

  group_by        = ["alertname"]
  group_wait      = "10s"
  group_interval  = "5m"
  repeat_interval = "12h"
}

# Alert: DMARC failure rate too high
resource "grafana_rule_group" "dmarc_alerts" {
  name             = "DMARC Alerts"
  folder_uid       = grafana_folder.email_infra.uid
  interval_seconds = 300

  rule {
    name      = "High DMARC Failure Rate"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 600
        to   = 0
      }
      datasource_uid = local.prometheus_uid
      model = jsonencode({
        expr          = "sum(rate(dmarc_email_count{dmarc_result!=\"pass\"}[5m])) / sum(rate(dmarc_email_count[5m])) * 100"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = local.expressions_uid
      model = jsonencode({
        conditions = [
          {
            evaluator = {
              params = [5]
              type   = "gt"
            }
            operator = {
              type = "and"
            }
            query = {
              params = ["A"]
            }
            reducer = {
              params = []
              type   = "last"
            }
            type = "query"
          }
        ]
        datasource = {
          type = "__expr__"
          uid  = local.expressions_uid
        }
        expression    = "A"
        hide          = false
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "C"
        type          = "threshold"
      })
    }

    for            = "5m"
    no_data_state  = "Alerting"
    exec_err_state = "Alerting"

    annotations = {
      summary     = "DMARC failure rate is {{ $value }}%"
      description = "DMARC authentication failure rate has exceeded 5% for the last 5 minutes"
    }

    labels = {
      severity = "warning"
      service  = "email-auth"
    }
  }

  rule {
    name      = "Lambda Function Errors"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 300
        to   = 0
      }
      datasource_uid = local.prometheus_uid
      model = jsonencode({
        expr          = "sum(rate(aws_lambda_errors_total{function_name=\"dmarc-processor\"}[5m]))"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = local.expressions_uid
      model = jsonencode({
        conditions = [
          {
            evaluator = {
              params = [0]
              type   = "gt"
            }
            operator = {
              type = "and"
            }
            query = {
              params = ["A"]
            }
            reducer = {
              params = []
              type   = "last"
            }
            type = "query"
          }
        ]
        datasource = {
          type = "__expr__"
          uid  = local.expressions_uid
        }
        expression    = "A"
        hide          = false
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "C"
        type          = "threshold"
      })
    }

    for            = "1m"
    no_data_state  = "Alerting"
    exec_err_state = "Alerting"

    annotations = {
      summary     = "DMARC processor Lambda errors detected"
      description = "The DMARC processor Lambda function is experiencing errors"
    }

    labels = {
      severity = "critical"
      service  = "dmarc-processor"
    }
  }

  rule {
    name      = "No DMARC Reports Received"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 604800
        to   = 0
      }
      datasource_uid = local.prometheus_uid
      model = jsonencode({
        expr          = "sum(increase(dmarc_email_count[7d]))"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = local.expressions_uid
      model = jsonencode({
        conditions = [
          {
            evaluator = {
              params = [1]
              type   = "lt"
            }
            operator = {
              type = "and"
            }
            query = {
              params = ["A"]
            }
            reducer = {
              params = []
              type   = "last"
            }
            type = "query"
          }
        ]
        datasource = {
          type = "__expr__"
          uid  = local.expressions_uid
        }
        expression    = "A"
        hide          = false
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "C"
        type          = "threshold"
      })
    }

    for            = "1h"
    no_data_state  = "Alerting"
    exec_err_state = "Alerting"

    annotations = {
      summary     = "No DMARC reports received in 7 days"
      description = "No DMARC reports have been processed in the last 7 days, which may indicate an issue with report collection"
    }

    labels = {
      severity = "warning"
      service  = "dmarc-collection"
    }
  }

  rule {
    name      = "SPF Authentication Failure Spike"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 1800
        to   = 0
      }
      datasource_uid = local.prometheus_uid
      model = jsonencode({
        expr          = "sum(rate(dmarc_spf_result{result!=\"pass\"}[5m])) / sum(rate(dmarc_spf_result[5m])) * 100"
        intervalMs    = 1000
        maxDataPoints = 43200
        refId         = "A"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = local.expressions_uid
      model = jsonencode({
        conditions = [
          {
            evaluator = {
              params = [10]
              type   = "gt"
            }
            operator = {
              type = "and"
            }
            query = {
              params = ["A"]
            }
            reducer = {
              params = []
              type   = "last"
            }
            type = "query"
          }
        ]
        datasource = {
          type = "__expr__"
          uid  = local.expressions_uid
        }
        expression    = "A"
        hide          = false
        intervalMs    = 1000
        maxDataPoints = 43200
        reducer       = "last"
        refId         = "C"
        type          = "threshold"
      })
    }

    for            = "10m"
    no_data_state  = "Alerting"
    exec_err_state = "Alerting"

    annotations = {
      summary     = "SPF failure rate is {{ $value }}%"
      description = "SPF authentication failure rate has exceeded 10% for the last 10 minutes"
    }

    labels = {
      severity = "warning"
      service  = "email-auth"
    }
  }
}

# Folder for organizing alerts
resource "grafana_folder" "email_infra" {
  title = "Email Infrastructure"
}
