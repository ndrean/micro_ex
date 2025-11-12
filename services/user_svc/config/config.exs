import Config

# This file only contains compile-time configuration

# Logger configuration - uses Docker Loki driver for log shipping
config :logger, level: :info

# Add service name to all logs
config :logger, :default_formatter, metadata: [:service]

config :phoenix, :json_library, Jason

# PromEx configuration for Prometheus metrics
config :user_svc, UserSvc.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

# OpenTelemetry Configuration
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp,
  resource: %{service: "user_svc"}

import_config "#{config_env()}.exs"
