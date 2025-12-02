# Folder for organizing alerts
resource "grafana_folder" "email_infra" {
  title = "Email Infrastructure"
}

# Get Prometheus datasource
data "grafana_data_source" "prometheus" {
  name = "grafanacloud-mdekort-prom"
}

# Contact point for notifications
resource "grafana_contact_point" "ntfy" {
  name = "ntfy-alerts"

  webhook {
    url                       = "https://ntfy.mdekort.nl/grafana"
    http_method               = "POST"
    authorization_scheme      = "Bearer"
    authorization_credentials = local.secrets.ntfy.token

    message = "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"

    headers = {
      "Title"    = "{{ .GroupLabels.alertname }}"
      "Priority" = "{{ if eq .Status \"firing\" }}high{{ else }}default{{ end }}"
      "Tags"     = "email,monitoring"
    }
  }
}

# Notification policy
resource "grafana_notification_policy" "default" {
  contact_point   = grafana_contact_point.ntfy.name
  group_by        = ["alertname"]
  group_wait      = "30s"
  group_interval  = "5m"
  repeat_interval = "4h"
}

# Alert rules
resource "grafana_rule_group" "email_alerts" {
  name             = "Email Infrastructure"
  folder_uid       = grafana_folder.email_infra.uid
  interval_seconds = 60

  rule {
    name      = "DMARC Failures"
    condition = "C"

    data {
      ref_id = "A"
      relative_time_range {
        from = 604800
        to   = 0
      }
      datasource_uid = data.grafana_data_source.prometheus.uid
      model = jsonencode({
        expr  = "sum(increase(dmarc_email_count{dmarc_result!=\"pass\"}[7d]))"
        refId = "A"
      })
    }

    data {
      ref_id = "B"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        expression = "A"
        reducer    = "last"
        type       = "reduce"
      })
    }

    data {
      ref_id = "C"
      relative_time_range {
        from = 0
        to   = 0
      }
      datasource_uid = "__expr__"
      model = jsonencode({
        conditions = [{
          evaluator = {
            params = [0]
            type   = "gt"
          }
          query = {
            params = ["B"]
          }
          reducer = {
            type = "last"
          }
          type = "query"
        }]
        expression = "B"
        type       = "threshold"
      })
    }

    for = "1h"
    annotations = {
      summary = "DMARC failures detected in the last 7 days"
    }
    labels = {
      severity = "warning"
    }
  }


}
