provider "google" {
  project = "your-project-id"
  region  = "your-region"
}

resource "google_monitoring_alert_policy" "nodes_per_cluster_quota" {
  display_name = "GKE Nodes Per Cluster Quota Alert"

  conditions {
    display_name = "NodesPerClusterV2 Quota Usage (MQL)"

    condition_monitoring_query_language {
      query = <<EOT
        fetch consumer_quota
        | metric 'serviceruntime.googleapis.com/quota/usage'
        | filter resource.service == 'container.googleapis.com'
        | filter metric.quota_metric == 'NodesPerClusterV2'
        | align rate(1m)
        | every 1m
        | group_by [], [value_usage: mean(value.usage)]
        | condition val() > 0.8
      EOT
      duration = "60s"
    }
  }

  combiner     = "OR"
  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
    auto_close = "86400s" # Auto-close after 1 day if resolved
  }

  documentation {
    content   = "Alert triggers when GKE Nodes Per Cluster Quota (NodesPerClusterV2) usage exceeds 80%."
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "Email Notification"
  type         = "email"

  labels = {
    email_address = "your-email@example.com"
  }
}
