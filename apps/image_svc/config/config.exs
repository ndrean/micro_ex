import Config

# NOTE: Runtime configuration (ports, URLs, credentials) is in config/runtime.exs
# This file only contains compile-time configuration

# Logger configuration - uses Docker Loki driver for log shipping
config :logger,
  level: :info

# Add service name to all logs
config :logger, :default_formatter, metadata: [:service]

# File handler for Loki/Promtail - COMMENTED OUT (using Docker Loki driver instead)
# config :logger, :file_handler,
#   level: :info,
#   path: "../../logs/image_svc.log",
#   formatter:
#     {LoggerJSON.Formatters.Basic,
#      metadata: [
#        :request_id,
#        :service,
#        :trace_id,
#        :span_id,
#        :user_id,
#        :duration
#      ]}
