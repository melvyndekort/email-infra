resource "grafana_dashboard" "dmarc_reports" {
  config_json = jsonencode({
    id       = null
    title    = "DMARC Reports"
    tags     = ["email", "dmarc", "security"]
    timezone = "browser"

    panels = [
      {
        id    = 1
        title = "Email Count by DMARC Result"
        type  = "timeseries"
        targets = [
          {
            expr         = "sum by (dmarc_result) (dmarc_email_count)"
            legendFormat = "{{dmarc_result}}"
          }
        ]
        gridPos = { h = 8, w = 12, x = 0, y = 0 }
      },
      {
        id    = 2
        title = "SPF Results"
        type  = "timeseries"
        targets = [
          {
            expr         = "sum by (result) (dmarc_spf_result)"
            legendFormat = "{{result}}"
          }
        ]
        gridPos = { h = 8, w = 12, x = 12, y = 0 }
      },
      {
        id    = 3
        title = "DKIM Results"
        type  = "timeseries"
        targets = [
          {
            expr         = "sum by (result) (dmarc_dkim_result)"
            legendFormat = "{{result}}"
          }
        ]
        gridPos = { h = 8, w = 12, x = 0, y = 8 }
      },
      {
        id    = 4
        title = "Top Source IPs"
        type  = "table"
        targets = [
          {
            expr   = "topk(10, sum by (source_ip, organization) (dmarc_email_count))"
            format = "table"
          }
        ]
        gridPos = { h = 8, w = 12, x = 12, y = 8 }
      }
    ]

    time = {
      from = "now-24h"
      to   = "now"
    }
    refresh = "5m"
  })
}
