import Config

# Runtime configuration - loaded when the release starts
# This file is executed when the application starts, allowing
# environment variables to be read at runtime.

# Get environment with fallback to "dev"
env = System.get_env("MIX_ENV", "dev")

# HTTP Port
port = System.get_env("USER_SVC_PORT", "8081") |> String.to_integer()

config :user_svc,
  port: port,
  # Use *_URL from docker-compose or fallback to localhost for dev
  user_svc_base_url: System.get_env("USER_SVC_URL", "http://127.0.0.1:#{System.get_env("USER_SVC_PORT", "8081")}"),
  job_svc_base_url: System.get_env("JOB_SVC_URL", "http://127.0.0.1:#{System.get_env("JOB_SVC_PORT", "8082")}"),
  client_svc_base_url: System.get_env("CLIENT_SVC_URL", "http://127.0.0.1:#{System.get_env("CLIENT_SVC_PORT", "8085")}"),
  job_svc_endpoints: %{
    convert_image: "/job_svc/ConvertImage",
    enqueue_email: "/job_svc/EnqueueEmail"
  },
  client_svc_endpoints: %{
    pdf_ready: "/client_svc/PdfReady",
    receive_notification: "/client_svc/ReceiveNotification"
  },
  loki_chunks: System.get_env("LOKI_CHUNKS", "loki-chunks"),
  image_bucket: System.get_env("IMAGE_BUCKET", "msvc-images")

# MinIO / S3 Configuration
config :ex_aws,
  access_key_id: System.get_env("MINIO_ROOT_USER", "minioadmin"),
  secret_access_key: System.get_env("MINIO_ROOT_PASSWORD", "minioadmin"),
  region: System.get_env("AWS_REGION", "us-east-1"),
  json_codec: Jason

config :ex_aws, :s3,
  scheme: System.get_env("MINIO_SCHEME", "http://"),
  host: System.get_env("MINIO_HOST", "127.0.0.1"),
  port: System.get_env("MINIO_PORT", "9000") |> String.to_integer(),
  region: System.get_env("AWS_REGION", "us-east-1")

# OpenTelemetry Configuration
config :opentelemetry,
  service_name: System.get_env("OTEL_SERVICE_NAME", "user_svc"),
  traces_exporter: :otlp

# Determine OTLP protocol from environment variable
# Options: "http" (default) or "grpc" (production)
otlp_protocol =
  case System.get_env("OTEL_EXPORTER_OTLP_PROTOCOL", "http") do
    "grpc" ->
      :grpc

    "http" ->
      :http_protobuf

    other ->
      IO.warn("Unknown OTLP protocol '#{other}', defaulting to :http_protobuf")
      :http_protobuf
  end

config :opentelemetry_exporter,
  otlp_protocol: otlp_protocol,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://127.0.0.1:4318")

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
