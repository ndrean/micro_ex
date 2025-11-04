import Config

# Runtime configuration for job_svc

# HTTP Port
port = System.get_env("PORT", "8082") |> String.to_integer()

config :job_svc,
  port: port,
  image_svc_base_url: System.get_env("IMAGE_SVC_URL", "http://localhost:8084"),
  email_svc_base_url: System.get_env("EMAIL_SVC_URL", "http://localhost:8083"),
  user_svc_base_url: System.get_env("USER_SVC_URL", "http://localhost:8081"),
  job_svc_base_url: System.get_env("JOB_SVC_URL", "http://localhost:#{port}"),
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
  },
  image_bucket: System.get_env("IMAGE_BUCKET", "msvc-images"),
  image_bucket_max_age: System.get_env("IMAGE_BUCKET_MAX_AGE", "3600")

# Database configuration (SQLite)
# In Docker: /app/db/job_service.db
# In dev: apps/job_svc/db/job_service.db
database_path = System.get_env("DATABASE_PATH", "/app/db/job_service.db")

config :job_svc, JobService.Repo,
  database: database_path,
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "5")),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# MinIO / S3 Configuration (for storage cleanup worker)
config :ex_aws,
  access_key_id: System.get_env("MINIO_ACCESS_KEY", "minioadmin"),
  secret_access_key: System.get_env("MINIO_SECRET_KEY", "minioadmin"),
  region: System.get_env("AWS_REGION", "us-east-1"),
  json_codec: Jason

config :ex_aws, :s3,
  scheme: System.get_env("MINIO_SCHEME", "http://"),
  host: System.get_env("MINIO_HOST", "localhost"),
  port: System.get_env("MINIO_PORT", "9000") |> String.to_integer(),
  region: System.get_env("AWS_REGION", "us-east-1")

# OpenTelemetry Configuration
config :opentelemetry,
  service_name: System.get_env("OTEL_SERVICE_NAME", "job_svc"),
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318")

# Logger Configuration
log_level = System.get_env("LOG_LEVEL", "info") |> String.to_atom()

config :logger,
  level: log_level

# Optionally configure JSON logging
if System.get_env("LOG_FORMAT") == "json" do
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
end
