import Config

# NOTE: Runtime configuration (ports, URLs, credentials, database path) is in config/runtime.exs
# This file only contains compile-time configuration

config :exqlite,
  force_build: true,
  default_chunk_size: 100

# Configure Ecto repos (database path is in runtime.exs)-------------------------
config :job_svc,
  ecto_repos: [JobService.Repo],
  adapter: Ecto.Adapters.SQLite3,
  default_transaction_mode: :immediate,
  show_sensitive_data_on_connection_error: true,
  pool_size: 5

# Configure Oban (repo connection is in runtime.exs)---------------------------------
# Memory optimization notes:
# - Lower concurrency reduces worker memory overhead (~5-10MB per worker)
# - Higher poll_interval reduces CPU/DB polling overhead
# - Fewer plugins = less background work
# - Image conversions are CPU-bound, so fewer workers with longer queues is fine
config :job_svc, Oban,
  repo: JobService.Repo,
  engine: Oban.Engines.Lite,
  # Changed from :debug to reduce log memory
  # log: :info,
  queues: [
    # Reduced from 10 (most jobs are just HTTP calls)
    default: 2,
    # Reduced from 10 (emails are fast, 3 is plenty)
    emails: 3,
    # Half of CPU cores
    images: max(10, System.schedulers_online())
  ],
  # Reduced from 100ms (less aggressive polling)
  poll_interval: 100,
  shutdown_grace_period: 30_000,
  plugins: [
    # Clean old jobs (keep this for DB maintenance)
    {Oban.Plugins.Pruner, max_age: 600},
    # Cron plugin for scheduled jobs
    {Oban.Plugins.Cron,
     crontab: [
       # Cleanup old images every 15 minutes (files older than 1 hour)
       {"*/15 * * * *", StorageCleanupWorker}
     ]}
  ]

# PromEx configuration for Prometheus metrics---------------------------
config :job_svc, JobService.PromEx,
  disabled: false,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: :disabled

# OpenTelemetry -------------------------------------------------------
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp,
  resource: %{service: "job_svc"}

config :opentelemetry_ecto, :tracer, repos: [JobService.Repo]

# Add service name to all logs
config :logger, :default_formatter, metadata: [:service]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
