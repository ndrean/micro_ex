import Config

# This file only contains compile-time configuration

# PromEx configuration for Prometheus metrics
config :client_svc, ClientService.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [:phoenix_channel_event_metrics],
  # Disable PromEx Grafana upload - dashboards are provisioned via
  # docker volume mount: ./configs/grafana/dashboards:/var/lib/grafana/dashboards:ro
  grafana: :disabled,
  metrics_server: :disabled

# Logger configuration - uses Docker Loki driver for log shipping
config :logger,
  level: :info

# Add service name to all logs
config :logger, :default_formatter, metadata: [:service]

# OpenTelemetry Configuration
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp,
  resource: %{service: "client_svc"}
