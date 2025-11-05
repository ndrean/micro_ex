import Config

# This file only contains compile-time configuration

# Logger configuration - uses Docker Loki driver for log shipping
config :logger,
  level: :info

# Add service name to all logs
config :logger, :default_formatter, metadata: [:service]
