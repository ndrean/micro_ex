import Config

port = System.get_env("IMAGE_SVC_PORT", "8084") |> String.to_integer()

config :image_svc, ImageSvcWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  http: [
    ip: {0, 0, 0, 0},  # Bind to all interfaces for Docker networking
    port: port
  ],
  server: true,
  check_origin: false,
  secret_key_base: "lSELLkV2qXzO3PbrZjubtnS84cvDgItzZ3cuQMlmRrM/f5Iy0YHJgn/900qLm7/a"

# Database configuration (SQLite)------------------------
# In Docker: /app/db/service.db
# In dev: db/service.db

config :image_svc, ImageService.Repo,
  database: System.get_env("DATABASE_PATH", "db/conversion_cache.sql3"),
  pool_size: String.to_integer(System.get_env("DB_POOL_SIZE", "5"))

config :image_svc,
  port: port,
  user_svc_base_url:
    System.get_env("USER_SVC_URL", "http://127.0.0.1:#{System.get_env("USER_SVC_PORT", "8081")}"),
  user_svc_endpoints: %{
    store_image: "/user_svc/store_image/v1",
    notify_user: "/user_svc/notify_user/v1",
    image_loader: "/user_svc/image_loader/v1"
  },
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

# Determine OTLP protocol from environment variable------------------------
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

otlp_endpoint =
  case System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") do
    nil -> "http://127.0.0.1:4318"
    endpoint -> endpoint
  end

config :opentelemetry_exporter,
  otlp_protocol: otlp_protocol,
  otlp_endpoint: otlp_endpoint

# Logger configuration - uses Docker Loki driver for log shipping------------------------
config :logger,
  level: System.get_env("LOG_LEVEL", "info") |> String.to_atom()

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
