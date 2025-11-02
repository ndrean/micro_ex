import Config

# NOTE: Runtime configuration (ports, URLs, credentials) is in config/runtime.exs
# This file only contains compile-time configuration

# Configure Email Service
config :email_svc,
  ecto_repos: []

# Configure Swoosh Mailer (adapter is in runtime.exs)
config :email_svc, EmailService.Mailer, adapter: Swoosh.Adapters.Local

# Disable Swoosh API client (not needed for Local adapter)
config :swoosh, :api_client, false
config :swoosh, :json_library, JSON

# Logger configuration - uses Docker Loki driver for log shipping
config :logger,
  level: :info

# Add service name to all logs
config :logger, :default_formatter, metadata: [:service]
