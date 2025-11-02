import Config

# Runtime configuration - loaded when the release starts
# This file is executed when the application starts, allowing
# environment variables to be read at runtime.

# Get environment with fallback to "dev"
env = System.get_env("MIX_ENV", "dev")

# HTTP Port
port = System.get_env("PORT", "8081") |> String.to_integer()

config :user_svc,
  port: port,
  user_svc_base_url: System.get_env("USER_SVC_URL", "http://localhost:#{port}"),
  job_svc_base_url: System.get_env("JOB_SVC_URL", "http://localhost:8082"),
  client_svc_base_url: System.get_env("CLIENT_SVC_URL", "http://localhost:4000"),
  job_svc_endpoints: %{
    convert_image: "/job_svc/ConvertImage",
    enqueue_email: "/job_svc/EnqueueEmail"
  },
  client_svc_endpoints: %{
    pdf_ready: "/client_svc/PdfReady",
    receive_notification: "/client_svc/ReceiveNotification"
  }

# MinIO / S3 Configuration
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
  service_name: System.get_env("OTEL_SERVICE_NAME", "user_svc"),
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
