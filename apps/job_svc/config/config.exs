import Config

config :job_svc, JobService.Repo,
  database: Path.expand("../db/job_service_#{config_env()}.sql3", __DIR__),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# Configure Ecto repos
config :job_svc,
  ecto_repos: [JobService.Repo]

# Configure Oban
config :job_svc, Oban,
  repo: JobService.Repo,
  engine: Oban.Engines.Lite,
  queues: [
    default: 10,
    emails: 20,
    notifications: 5,
    # Image conversion jobs
    images: 10
  ],
  crontab: false

# External service URLs
config :job_svc,
  image_svc_base_url: "http://localhost:8084",
  job_svc_base_url: "http://localhost:8082",
  email_svc_base_url: "http://localhost:8083",
  user_svc_base_url: "http://localhost:8081",
  image_svc_endpoints: %{
    convert_image: "/image_svc/ConvertImage"
  },
  email_svc_endpoints: %{
    send_email: "/email_svc/SendEmail"
  },
  user_svc_endpoints: %{
    notify_email_sent: "/user_svc/NotifyEmailSent"
  },
  job_svc_endpoints: %{
    notify_email_delivery: "/job_svc/NotifyEmailDelivery"
  }

# OpenTelemetry configuration for distributed tracing
config :opentelemetry,
  service_name: "job_svc",
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://localhost:4318"

config :opentelemetry_ecto, :tracer, repos: [JobService.Repo]

config :logger, :default_handler,
  formatter:
    {LoggerJSON.Formatters.Basic,
     metadata: [
       :request_id,
       :service,
       :trace_id,
       :span_id,
       :user_id,
       :duration
     ]}

# Add service name to all logs
config :logger, :default_formatter, metadata: [:service]
