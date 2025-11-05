import Config

# NOTE: Runtime configuration (ports, URLs, credentials, database path) is in config/runtime.exs
# This file only contains compile-time configuration

# Configure Ecto repos (database path is in runtime.exs)
config :job_svc,
  ecto_repos: [JobService.Repo],
  adapter: Ecto.Adapters.SQLite3,
  default_transaction_mode: :immediate,
  show_sensitive_data_on_connection_error: true,
  pool_size: 5

# Configure Oban (repo connection is in runtime.exs)
config :job_svc, Oban,
  repo: JobService.Repo,
  engine: Oban.Engines.Lite,
  queues: [
    default: 10,
    emails: 10,
    images: 10,
    cleanup: 5
  ],
  plugins: [
    # Cron plugin for scheduled jobs
    {Oban.Plugins.Cron,
     crontab: [
       # Cleanup old images every 15 minutes (files older than 1 hour)
       {"*/15 * * * *", StorageCleanupWorker}
     ]}
  ]

# OpenTelemetry Ecto instrumentation
config :opentelemetry_ecto, :tracer, repos: [JobService.Repo]

# PromEx configuration for Prometheus metrics
config :job_svc, JobSvc.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

# Logger configuration - uses Docker Loki driver for log shipping
config :logger,
  level: :info

# Add service name to all logs
config :logger, :default_formatter, metadata: [:service]
